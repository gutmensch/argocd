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
        path: std.join('/', [app.directory, app.path]),
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
        syncOptions: ['Validate=true', 'CreateNamespace=true', 'PrunePropagationPolicy=background', 'PruneLast=true'],
      },
    },
  },

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
              image: '%s:%s' % [if std.get(c, 'imageRegistry') != null then std.join('/', [c.imageRegistry, c.imageRef]) else c.imageRef, c.imageVersion],
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
