local argo = import '../../argo.libsonnet';
local helper = import '../../helper.libsonnet';
local kube = import '../../kube.libsonnet';

{
  generate(
    name,
    namespace,
    region,
    tenant,
    appConfig,
    defaultConfig={
      local this = self,
      imageRef: 'library/nginx',
      imageVersion: '1.27.0',
      replicas: 1,
      certIssuer: 'letsencrypt-prod',
      inboundDomainPolicyMap: {
        // either use default policy or own, will be merged
        // 'example.com': this.defaultPolicy,
      },
      defaultPolicy: {
        // version: 'STSv1',
        // mode: 'testing',
        // mx: 'mx.example.com',
        // max_age: 604800,
      },
    },
  ):: helper.uniquify({

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    local appName = name,
    local componentName = 'mta-sts',

    local nginxConfServers = [
      |||
        server {
            listen 8080;
            server_name mta-sts.%s;
            location /.well-known/mta-sts.txt {
              default_type text/plain;
              return 200 "%s";
            }
        }
      ||| % [domain, helper.manifestMtaSts(std.mergePatch(config.defaultPolicy, config.inboundDomainPolicyMap[domain]))]
      for domain in std.objectFields(config.inboundDomainPolicyMap)
    ],

    configmap: kube.ConfigMap(componentName) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      data: {
        'nginx.conf': 'events {}\n\nhttp {\ninclude mime.types;\n default_type application/octet-stream;\n' + std.join('\n\n', nginxConfServers) + '\n}\n',
      },
    },

    local volumeMounts = [
      {
        mountPath: '/etc/nginx/nginx.conf',
        name: componentName,
        subPath: 'nginx.conf',
      },
    ],

    deployment: argo.SimpleRollout(componentName, null, 80, '/', std.mergePatch(config, { volumeMounts: volumeMounts })) {
      spec+: {
        template+: {
          metadata+: {
            annotations+: {
              'checksum/nginx-config-hash': std.md5(std.toString(this.configmap)),
            },
          },
          spec+: {
            volumes: [
              {
                configMap: {
                  name: componentName,
                },
                name: componentName,
              },
            ],
          },
        },
      },
    },

    service: kube.Service(componentName) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      spec: {
        ports: [
          {
            name: 'http',
            port: 80,
            protocol: 'TCP',
            targetPort: 'http',
          },
        ],
        selector: config.labels,
        type: 'ClusterIP',
      },
    },

    ingress: kube.Ingress(componentName, false) {
      local ing = self,
      metadata+: {
        namespace: namespace,
        annotations+: {
          'cert-manager.io/cluster-issuer': config.certIssuer,
          'kubernetes.io/ingress.class': 'nginx',
        },
        labels+: config.labels,
      },
      spec: {
        tls: [
          {
            hosts: [
              'mta-sts.%s' % [domain]
              for domain in std.objectFields(config.inboundDomainPolicyMap)
            ],
            secretName: '%s-ingress-cert' % [componentName],
          },
        ],
        rules: [
          {
            host: 'mta-sts.%s' % [domain],
            http: {
              paths: [
                {
                  backend: {
                    service: {
                      name: ing.metadata.name,
                      port: {
                        name: 'http',
                      },
                    },
                  },
                  path: '/.well-known/mta-sts.txt',
                  pathType: 'Exact',
                },
              ],
            },
          }
          for domain in std.objectFields(config.inboundDomainPolicyMap)
        ],
      },
    },

  }),
}
