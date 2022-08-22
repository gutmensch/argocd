local argo = import '../../../../argo.libsonnet';
local helper = import '../../../../helper.libsonnet';
local kube = import '../../../../kube.libsonnet';

{
  generate(
    name,
    namespace,
    region,
    tenant,
    appConfig,
    defaultConfig={
      imageRef: 'gutmensch/phpldapadmin',
      imageVersion: '1.2.6.3-4',
      replicas: 1,
      ldapRoot: 'o=auth,dc=local',
      ldapAdmin: 'admin',
      ldapSvc: 'ldap.%s.svc.cluster.local' % [namespace],
      certIssuer: 'letsencrypt-prod',
    },
  ):: helper.uniquify({

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    local appName = name,
    local componentName = 'phpldapadmin',

    configmap: kube.ConfigMap(componentName) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      data: {
        PHPLDAPADMIN_HTTPS: 'false',
        PHPLDAPADMIN_LDAP_CLIENT_TLS_REQCERT: 'never',
        PHPLDAPADMIN_LDAP_HOSTS: "#PYTHON2BASH:[{'%s': [{'server': [{'tls': True},{'port':389}]},{'login': [{'bind_id': 'cn=%s,%s' }]}]}]" % [config.ldapSvc, config.ldapAdmin, config.ldapRoot],
        PHPLDAPADMIN_TRUST_PROXY_SSL: 'true',
      },
    },

    deployment: argo.SimpleRollout(componentName, null, 80, '/', config) {
      spec+: {
        template+: {
          metadata+: {
            annotations+: {
              'checksum/env': std.md5(std.toString(this.configmap)),
            },
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

    basicauthsecret: kube.Secret('%s-basic-auth' % [componentName]) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      stringData: {
        auth: config.httpBasicAuth,
      },
    },

    ingress: if std.get(config, 'ingress') != null then kube.Ingress(componentName) {
      local ing = self,
      metadata+: {
        namespace: namespace,
        annotations+: {
          'cert-manager.io/cluster-issuer': config.certIssuer,
          'kubernetes.io/ingress.class': 'nginx',
          'nginx.ingress.kubernetes.io/auth-type': 'basic',
          'nginx.ingress.kubernetes.io/auth-secret': '%s-basic-auth' % [componentName],
          'nginx.ingress.kubernetes.io/auth-realm': 'Authentication Required',
        },
        labels+: config.labels,
      },
      spec: {
        tls: [
          {
            hosts: [
              config.ingress,
            ],
            secretName: '%s-ingress-cert' % [componentName],
          },
        ],
        rules: [
          {
            host: config.ingress,
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
                  path: '/',
                  pathType: 'Prefix',
                },
              ],
            },
          },
        ],
      },
    },

  }),
}
