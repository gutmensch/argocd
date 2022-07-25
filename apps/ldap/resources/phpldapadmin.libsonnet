local kube = import '../../../lib/kube.libsonnet';
local helper = import '../../../lib/helper.libsonnet';

{
  generate(
    name,
    namespace,
    registry='registry.lan:5000',
    version='0.9.0',
    ingress='',
    base='dc=ldap,dc=local',
  ):: {

    assert base != '': error 'base DN needed for setup',

    _name:: '%s-admin' % [name],

    local this = self,

    local defaultLabels = {
      'app.kubernetes.io/name': this._name,
      'app.kubernetes.io/version': version,
      'app.kubernetes.io/component': 'phpldapadmin',
      'app.kubernetes.io/managed-by': 'ArgoCD',
    },

    configmap: kube.ConfigMap(self._name) {
      metadata+: {
        namespace: namespace,
        labels+: defaultLabels,
      },
      data: {
        PHPLDAPADMIN_HTTPS: 'false',
        PHPLDAPADMIN_LDAP_CLIENT_TLS_REQCERT: 'never',
        PHPLDAPADMIN_LDAP_HOSTS: "#PYTHON2BASH:[{ 'ldap.default'  : [{'server': [{'tls': True},{'port':389}]},{'login': [{'bind_id': 'cn=configadmin,%s' }]}]}]" % [base],
        PHPLDAPADMIN_TRUST_PROXY_SSL: 'true',
      },
    },

    deployment: kube.Deployment(self._name) {
      local this = self,
      metadata+: {
        namespace: namespace,
        labels+: defaultLabels,
      },
      spec: {
        replicas: 1,
        selector: {
          matchLabels: helper.removeVersion(defaultLabels),
        },
        template: {
          metadata+: {
            labels+: defaultLabels,
          },
          spec: {
            containers: [
              {
                envFrom: [
                  {
                    configMapRef: {
                      name: this.metadata.name,
                    },
                  },
                ],
                // version 0.9.0 is from docker image with =phpLDAPadmin 1.2.5
                local upstream = 'osixia/phpldapadmin:%s' % [version],
                image: if registry != '' then std.join('/', [registry, upstream]) else upstream,
                imagePullPolicy: 'IfNotPresent',
                livenessProbe: {
                  httpGet: {
                    path: '/',
                    port: 'http',
                  },
                },
                name: 'phpldapadmin',
                ports: [
                  {
                    containerPort: 80,
                    name: 'http',
                    protocol: 'TCP',
                  },
                ],
                readinessProbe: {
                  httpGet: {
                    path: '/',
                    port: 'http',
                  },
                },
                resources: {},
              },
            ],
          },
        },
      },
    },

    service: kube.Service(self._name) {
      metadata+: {
        namespace: namespace,
        labels+: defaultLabels,
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
        selector: helper.removeVersion(defaultLabels),
        type: 'ClusterIP',
      },
    },

    [if ingress != '' then 'ingress']: kube.Ingress(self._name) {
      local this = self,
      metadata+: {
        namespace: namespace,
        annotations+: {
          'cert-manager.io/cluster-issuer': 'letsencrypt-staging',
          'kubernetes.io/ingress.class': 'nginx',
          'nginx.ingress.kubernetes.io/auth-type': 'basic',
          'nginx.ingress.kubernetes.io/auth-secret': 'phpldapadmin-basic-auth',
          'nginx.ingress.kubernetes.io/auth-realm': 'Authentication Required',
        },
        labels+: defaultLabels,
      },
      spec: {
        tls: [ {
            hosts: [
              ingress,
            ], secretName: 'ldap-admin-cert' },
        ],
        rules: [
          {
            host: ingress,
            http: {
              paths: [
                {
                  backend: {
                    service: {
                      name: this.metadata.name,
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
  },
}
