local helper = import 'helper.libsonnet';
local kube = import 'kube.libsonnet';

{
  Project(name, namespaces, description, clusterResourceAllowList): kube._Object('argoproj.io/v1alpha1', 'AppProject', name) {
    metadata: {
      namespace: 'argo-cd-system',
      name: name,
      finalizers: ['resources-finalizer.argocd.argoproj.io'],
      labels: {
        'app.kubernetes.io/managed-by': 'ArgoCD',
      },
    },
    spec: {
      description: description,
      sourceRepos: ['*'],
      orphanedResources: {
        warn: true,
      },
      destinations: [
        { namespace: ns, server: 'https://kubernetes.default.svc' }
        for ns in namespaces
      ],
      clusterResourceWhitelist: clusterResourceAllowList,
    },
  },

  Application(tenant, app): kube._Object('argoproj.io/v1alpha1', 'Application', app.name) {
    local full_name = '%s-%s-%s' % [app.project, app.name, tenant],
    metadata: {
      namespace: 'argo-cd-system',
      name: full_name,
      finalizers: ['resources-finalizer.argocd.argoproj.io'],
      labels: {
        'app.kubernetes.io/name': app.name,
        'app.kubernetes.io/instance': full_name,
        'app.kubernetes.io/managed-by': 'ArgoCD',
      },
    },
    spec: {
      project: app.project,
      source: {
        repoURL: app.repoURL,
        targetRevision: app.targetRevision,
        path: std.join('/', [app.project, app.path]),
        directory: {
          recurse: false,
          jsonnet: {
            tlas: std.prune([
              { code: false, name: 'name', value: app.name },
              { code: false, name: 'namespace', value: full_name },
              { code: false, name: 'project', value: app.project },
              { code: false, name: 'tenant', value: tenant },
              { code: false, name: 'region', value: app.region },
            ]),
            extVars:: [],
          },
        },
      },
      [if std.length(app.ignoreDiff) > 0 then 'ignoreDifferences']: app.ignoreDiff,
      destination: {
        server: 'https://kubernetes.default.svc',
        namespace: full_name,
      },
      syncPolicy: {
        automated: {
          prune: true,
          selfHeal: true,
          allowEmpty: true,
        },
        retry: {
          limit: 5,
          backoff: {
            duration: '5s',
            factor: 2,
            maxDuration: '5m',
          },
        },
        // XXX: https://github.com/argoproj/argo-cd/issues/7383
        syncOptions: std.prune([
          'Validate=true',
          'CreateNamespace=true',
          'PrunePropagationPolicy=background',
          if std.length(app.ignoreDiff) > 0 then 'RespectIgnoreDifferences=true' else null,
        ]),
      },
    },
  },

  YamlApplication(app): kube._Object('argoproj.io/v1alpha1', 'Application', '%s-%s' % [app.name, app.type]) {
    metadata: {
      namespace: 'argo-cd-system',
      name: '%s-%s' % [app.name, app.type],
      finalizers: if app.protect then null else ['resources-finalizer.argocd.argoproj.io'],
      labels: {
        'app.kubernetes.io/name': '%s-%s' % [app.name, app.type],
        'app.kubernetes.io/instance': '%s-%s' % [app.name, app.type],
        'app.kubernetes.io/managed-by': 'ArgoCD',
      },
    },
    spec: {
      project: 'default',
      source: {
        repoURL: app.repoURL,
        targetRevision: app.targetRevision,
        path: app.path,
        directory: {
          recurse: false,
          include: '{%s}' % [std.join(',', app.files)],
        },
      },
      destination: {
        server: 'https://kubernetes.default.svc',
        namespace: app.namespace,
      },
      syncPolicy: {
        automated: {
          prune: true,
          selfHeal: true,
          allowEmpty: true,
        },
        retry: {
          limit: 5,
          backoff: {
            duration: '5s',
            factor: 2,
            maxDuration: '5m',
          },
        },
        syncOptions: ['Validate=true', 'CreateNamespace=true', 'PrunePropagationPolicy=foreground'],
      },
    },
  },

  CanaryRollout(name, secret, httpPort, httpPath, config): kube._Object('argoproj.io/v1alpha1', 'Rollout', name) {
    local c = config,
    metadata: {
      name: name,
      labels: c.labels,
    },
    spec: {
      replicas: std.get(c, 'replicas', default=1),
      revisionHistoryLimit: 5,
      selector: {
        matchLabels: c.labels,
      },
      template: {
        metadata: {
          labels: c.labels + c.containerImageLabels,
        },
        spec: {
          containers: [
            {
              name: name,
              image: helper.getImage(c.imageRegistry, c.imageRef, c.imageVersion),
              imagePullPolicy: 'Always',
              envFrom: [
                {
                  configMapRef: {
                    name: name,
                  },
                },
              ] + if secret != null then [
                {
                  secretRef: {
                    name: secret,
                  },
                },
              ] else [],
              livenessProbe: {
                httpGet: {
                  path: httpPath,
                  port: 'http',
                },
              },
              ports: [
                {
                  containerPort: httpPort,
                  name: 'http',
                  protocol: 'TCP',
                },
              ],
              readinessProbe: {
                httpGet: {
                  path: httpPath,
                  port: 'http',
                },
              },
            },
          ],
        },
      },
      strategy: {
        canary: {
          canaryService: '%s-canary' % [name],
          stableService: name,
          trafficRouting: {
            nginx: {
              stableIngress: name,
            },
          },
          steps: [
            { setWeight: 20 },
            { pause: { duration: '1m' } },
            { setWeight: 40 },
            { pause: { duration: '1m' } },
            { setWeight: 60 },
            { pause: { duration: '1m' } },
            { setWeight: 80 },
            { pause: { duration: '1m' } },
          ],

          // analysis: {
          //   templates: [
          //     { templateName: success-rate }
          //   ],
          //   startingStep: 2 # delay starting analysis run until setWeight: 40%
          //   args: [
          //     {
          //       name: service-name,
          //       value: guestbook-svc.default.svc.cluster.local,
          //     }
          //   ],
          // }
        },
      },
    },
  },

  // apiVersion: argoproj.io/v1alpha1
  // kind: AnalysisTemplate
  // metadata:
  //   name: success-rate
  // spec:
  //   args:
  //   - name: service-name
  //   - name: prometheus-port
  //     value: 9090
  //   metrics:
  //   - name: success-rate
  //     successCondition: result[0] >= 0.95
  //     provider:
  //       prometheus:
  //         address: "http://prometheus.example.com:{{args.prometheus-port}}"
  //         query: |
  //           sum(irate(
  //             istio_requests_total{reporter="source",destination_service=~"{{args.service-name}}",response_code!~"5.*"}[5m]
  //           )) /
  //           sum(irate(
  //             istio_requests_total{reporter="source",destination_service=~"{{args.service-name}}"}[5m]
  //           ))

  SimpleRollout(name, secret, httpPort, httpPath, config): kube._Object('argoproj.io/v1alpha1', 'Rollout', name) {
    local c = config,
    metadata: {
      name: name,
      labels: c.labels,
    },
    spec: {
      replicas: std.get(c, 'replicas', default=1),
      revisionHistoryLimit: 5,
      selector: {
        matchLabels: c.labels,
      },
      template: {
        metadata: {
          labels: c.labels + c.containerImageLabels,
        },
        spec: {
          containers: [
            {
              name: name,
              image: helper.getImage(c.imageRegistry, c.imageRef, c.imageVersion),
              imagePullPolicy: 'Always',
              envFrom: [
                {
                  configMapRef: {
                    name: name,
                  },
                },
              ] + if secret != null then [
                {
                  secretRef: {
                    name: secret,
                  },
                },
              ] else [],
              livenessProbe: {
                httpGet: {
                  path: httpPath,
                  port: 'http',
                },
              },
              ports: [
                {
                  containerPort: httpPort,
                  name: 'http',
                  protocol: 'TCP',
                },
              ],
              readinessProbe: {
                httpGet: {
                  path: httpPath,
                  port: 'http',
                },
              },
            },
          ],
        },
      },
      strategy: {
        canary: {
          maxSurge: 1,
          maxUnavailable: 1,
        },
      },
    },
  },

}
