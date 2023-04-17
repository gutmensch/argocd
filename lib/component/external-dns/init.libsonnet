// external dns deployment for google cloud dns
// https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/gke.md#deploy-externaldns
local helper = import '../../helper.libsonnet';
local kube = import '../../kube.libsonnet';

{
  generate(
    name, namespace, region, tenant, appConfig, defaultConfig={
      imageRegistryMirror: '',
      imageRegistry: 'registry.k8s.io',
      imageRef: 'external-dns/external-dns',
      imageVersion: '0.13.4',
      sources: ['service', 'ingress'],
      provider: null,
      managedDomains: [],
      googleProjectID: null,
      googleServiceAccount: {},
      replicas: 1,
      logLevel: 'debug',
    }
  ):: helper.uniquify({

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    local appName = name,
    local componentName = 'external-dns',
    local prov = config.provider,

    assert std.length(config.managedDomains) > 0 : error 'managedDomains must not be empty',
    assert config.provider != null : error 'provider must not be null',
    assert config.provider == 'google' && std.length(std.objectFields(config.googleServiceAccount.cloudDNS)) > 0 : error 'google service account must be valid json',
    assert config.provider == 'google' && config.googleProjectID != null : error 'google project must not be null',

    service_account: kube.ServiceAccount('%s-%s' % [componentName, config.provider]) {
      metadata+: {
        labels: config.labels,
        namespace: namespace,
      },
    },

    secret_google_credentials: if config.provider == 'google' then kube.Secret('%s-%s' % [componentName, 'google-credentials']) {
      metadata+: {
        labels: config.labels,
        namespace: namespace,
      },
      stringData: {
        'key.json': std.toString(config.googleServiceAccount.cloudDNS),
      },
    } else null,

    deployment: kube.Deployment('%s-%s' % [componentName, config.provider]) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      spec+: {
        replicas: config.replicas,
        selector: {
          matchLabels: config.labels,
        },
        strategy: {
          rollingUpdate: {
            maxUnavailable: 1,
          },
          type: 'RollingUpdate',
        },
        template: {
          metadata+: {
            labels+: config.labels,
            annotations+: {
              [if config.provider == 'google' then 'checksum/googlesecret']: std.md5(std.toString(this.secret_google_credentials)),
            },
          },
          spec: {
            nodeSelector: {
              'topology.kubernetes.io/region': region,
            },
            securityContext: {
              fsGroup: 65534,
              fsGroupChangePolicy: 'OnRootMismatch',
              runAsGroup: 65534,
              runAsUser: 65534,
            },
            containers: [
              {
                env: std.prune([
                  if config.provider == 'google' then {
                    name: 'GOOGLE_APPLICATION_CREDENTIALS',
                    value: '/etc/google/key.json',
                  } else {},
                ]),
                image: helper.getImage(config.imageRegistryMirror, config.imageRegistry, config.imageRef, 'v%s' % [config.imageVersion]),
                imagePullPolicy: 'IfNotPresent',
                args: std.prune([
                  '--log-level=%s' % [config.logLevel],
                  '--log-format=text',
                  '--interval=1m',
                  '--policy=upsert-only',
                  '--registry=txt',
                  '--publish-internal-services',
                  '--provider=%s' % [config.provider],
                  if config.provider == 'google' then '--google-project=%s' % [config.googleProjectID] else null,
                  '--txt-owner-id=%s' % [namespace],
                ] + [
                  '--domain-filter=%s' % [domain]
                  for domain in config.managedDomains
                ] + [
                  '--source=%s' % [source]
                  for source in config.sources
                ]),
                readinessProbe: {
                  failureThreshold: 6,
                  httpGet: {
                    path: '/healthz',
                    port: 'http',
                  },
                  initialDelaySeconds: 5,
                  successThreshold: 1,
                  periodSeconds: 10,
                  timeoutSeconds: 5,
                },
                livenessProbe: {
                  failureThreshold: 2,
                  httpGet: {
                    path: '/healthz',
                    port: 'http',
                  },
                  initialDelaySeconds: 10,
                  successThreshold: 1,
                  periodSeconds: 10,
                  timeoutSeconds: 5,
                },
                name: 'external-dns',
                ports: [
                  {
                    name: 'http',
                    containerPort: 7979,
                  },
                ],
                volumeMounts: std.prune([
                  if config.provider == 'google' then {
                    name: this.secret_google_credentials.metadata.name,
                    mountPath: '/etc/google/',
                  } else {},
                ]),
              },
            ],
            serviceAccountName: this.service_account.metadata.name,
            resources: {},
            volumes: [
              {
                name: this.secret_google_credentials.metadata.name,
                secret: {
                  secretName: this.secret_google_credentials.metadata.name,
                  defaultMode: std.parseOctal('0600'),
                },
              },
            ],
          },
        },
      },
    },

    role: kube.ClusterRole('%s-%s' % [componentName, config.provider]) {
      metadata+: {
        labels: config.labels,
        namespace: namespace,
      },
      rules: [
        {
          apiGroups: [''],
          resources: ['nodes'],
          verbs: ['watch', 'list'],
        },
        {
          apiGroups: [''],
          resources: ['pods'],
          verbs: ['watch', 'list', 'get'],
        },
        {
          apiGroups: [''],
          resources: ['services', 'endpoints'],
          verbs: ['watch', 'list', 'get'],
        },
        {
          apiGroups: ['extensions', 'networking.k8s.io'],
          resources: ['ingresses'],
          verbs: ['watch', 'list', 'get'],
        },
      ],
    },

    role_binding: kube.ClusterRoleBinding('%s-%s' % [componentName, config.provider]) {
      metadata+: {
        labels: config.labels,
        namespace: namespace,
      },
      subjects_:: [
        this.service_account,
      ],
      roleRef_:: this.role,
    },

  }),
}
