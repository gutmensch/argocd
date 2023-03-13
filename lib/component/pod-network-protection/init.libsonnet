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
      imageRegistry: '',
      imageRef: 'gutmensch/toolbox',
      imageVersion: '0.0.6',
      updateInterval: '*/30',
      podSelector: {},
      portsInternal: [],
      portsExternal: [],
      ingress: {},
      egress: {},
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
        ldapServiceNamespace: 'base-auth-lts',
      },

      ingressNetworkPolicy: kube.NetworkPolicy('%s-ingress' % [prefix]) {
        metadata+: {
          namespace: namespace,
          labels+: config.labels,
        },
        spec+: {
          podSelector: config.podSelector,
          ingress_: netpol.ingress + config.ingress,
        },
      },

      egressNetworkPolicy: kube.NetworkPolicy('%s-egress' % [prefix]) {
        metadata+: {
          namespace: namespace,
          labels+: config.labels,
        },
        spec+: {
          podSelector: config.podSelector,
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
          POD_SELECTOR: std.toString(config.podSelector),
          FILTER_REGEXES: std.toString(config.filterRegexes),
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

      rolebinding: kube.RoleBinding(componentName) {
        metadata+: {
          namespace: namespace,
          labels+: config.labels,
        },
        roleRef: {
          apiGroup: 'rbac.authorization.k8s.io',
          kind: 'Role',
          name: componentName,
        },
        subjects: [
          {
            kind: 'ServiceAccount',
            name: componentName,
            namespace: namespace,
          },
        ],
      },

      serviceaccount: kube.ServiceAccount(componentName) {
        metadata+: {
          namespace: namespace,
          labels: config.labels,
        },
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
