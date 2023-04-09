local helper = import '../../helper.libsonnet';
local kube = import '../../kube.libsonnet';
local policies = import 'policies.libsonnet';

{
  generate(
    name,
    namespace,
    region,
    tenant,
    appConfig,
    // override below values in the specific app/$name/config/, app/$name/secret or app/$name/cd
    // directories app instantiation and configuration and pass as appConfig parameter above
    defaultConfig={
      imageRegistryMirror: '',
      imageRegistry: '',
      imageRef: 'gutmensch/toolbox',
      imageVersion: '0.0.6',
      updateInterval: '*/30',
      podSelector: {},
      portsInternal: [],
      portsExternal: [],
      outboundPorts: [],
      outboundNetworks: [],
      ingress: {},
      egress: {},
      // map of escaped python style regex with defined groups for IP addresses, e.g.
      // 'bruteForceLogin': '^login failed from: ([\\.0-9])+$'
      // the matched groups will be added to network policy ingress object except clause
      // for blocking
      filterRegexes: {},
    }
  ):: helper.uniquify(
    {
      local this = self,
      local appName = name,
      local componentName = 'pod-network-protection',
      local prefix = '%s-%s' % [componentName, config.podSelector['app.kubernetes.io/component']],

      local config = std.mergePatch(defaultConfig, appConfig),

      local netpol = policies {
        servicePortsInternal: config.portsInternal,
        servicePortsExternal: config.portsExternal,
        outboundPorts: config.outboundPorts,
        outboundNetworks: config.outboundNetworks,
        ldapServiceNamespace: 'base-auth-lts',
        minioServiceNamespace: 'base-minio-lts',
      },

      ingressNetworkPolicy: kube.NetworkPolicy('%s-ingress' % [prefix]) {
        metadata+: {
          namespace: namespace,
          labels+: config.labels,
        },
        spec+: {
          podSelector: {
            matchLabels: config.podSelector,
          },
          ingress_: netpol.ingress + config.ingress,
        },
      },

      egressNetworkPolicy: kube.NetworkPolicy('%s-egress' % [prefix]) {
        metadata+: {
          namespace: namespace,
          labels+: config.labels,
        },
        spec+: {
          podSelector: {
            matchLabels: config.podSelector,
          },
          egress_: netpol.egress + config.egress,
        },
      },

      configmap: kube.ConfigMap('%s-config' % [prefix]) {
        metadata+: {
          namespace: namespace,
          labels: config.labels,
        },
        data: {
          NETWORK_POLICY: '%s-ingress' % [prefix],
          LOG_POD_NAME: std.toString(config.podSelector),
          LOG_CONTAINER_NAME: std.toString(config.podSelector),
          FILTER_REGEX: std.join('|', std.objectValues(config.filterRegexes)),
        },
      },

      role: kube.Role(componentName) {
        metadata+: {
          namespace: namespace,
          labels: config.labels,
        },
        rules: [
          {
            apiGroups: [
              '',
            ],
            resources: [
              'pods',
              'pods/log',
            ],
            verbs: [
              'get',
              'list',
            ],
          },
          {
            apiGroups: [
              'networking.k8s.io',
            ],
            resources: [
              'networkpolicies',
            ],
            verbs: [
              'get',
              'list',
              'update',
              'patch',
            ],
          },
        ],
      },

      serviceaccount: kube.ServiceAccount(componentName) {
        metadata+: {
          namespace: namespace,
          labels: config.labels,
        },
      },

      rolebinding: kube.RoleBinding(componentName) {
        metadata+: {
          labels: config.labels,
          namespace: namespace,
        },
        subjects_:: [
          this.serviceaccount,
        ],
        roleRef_:: this.role,
      },

      cronjob: kube.CronJob('netpol-filter-update-%s' % [config.podSelector['app.kubernetes.io/component']]) {
        metadata+: {
          namespace: namespace,
          labels: config.labels { 'app.kubernetes.io/component': componentName, 'app.kubernetes.io/instance': config.podSelector['app.kubernetes.io/component'] },
        },
        spec+: {
          schedule: '%s * * * *' % [config.updateInterval],
          jobTemplate+: {
            metadata+: {
              annotations+: {
              },
              labels: config.labels { 'app.kubernetes.io/component': componentName, 'app.kubernetes.io/instance': config.podSelector['app.kubernetes.io/component'] },
            },
            spec+: {
              backoffLimit: 3,
              completions: 1,
              template+: {
                spec+: {
                  serviceAccountName: componentName,
                  containers_+: {
                    backup: {
                      args: [
                        '/usr/bin/network_policy_by_filter.py',
                      ],
                      envFrom: [
                        {
                          configMapRef: {
                            name: '%s-config' % [prefix],
                          },
                        },
                      ],
                      image: '%s:%s' % [if config.imageRegistry != '' then std.join('/', [config.imageRegistry, config.imageRef]) else config.imageRef, config.imageVersion],
                      imagePullPolicy: 'Always',
                      name: componentName,
                    },
                  },
                },
              },
            },
          },
        },
      },
    }
  ),
}
