local kube = import '../../../lib/kube.libsonnet';
local helper = import '../../../lib/helper.libsonnet';

{
  generate(
    name,
    namespace,
    registry='registry.lan:5000',
    image='gutmensch/phpldapadmin',
    version='1.2.6.3-4',
    // image='osixia/phpldapadmin',
    // version 0.9.0 contains =phpLDAPadmin 1.2.5
    // version='0.9.0',
    ingress='',
    ldapSvc='',
    ldapAdmin='',
    ldapRoot='',
    replicas=1,
  ):: {

    assert ldapSvc != '': error 'ldap service address needed for setup',

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
        PHPLDAPADMIN_LDAP_HOSTS: "#PYTHON2BASH:[{'%s': [{'server': [{'tls': True},{'port':389}]},{'login': [{'bind_id': 'cn=%s,%s' }]}]}]" % [ldapSvc, ldapAdmin, ldapRoot],
        PHPLDAPADMIN_TRUST_PROXY_SSL: 'true',
      },
    },

    deployment: kube.Deployment(self._name) {
      local depl = self,
      metadata+: {
        namespace: namespace,
        labels+: defaultLabels,
      },
      spec: {
        replicas: replicas,
        selector: {
          matchLabels: helper.removeVersion(defaultLabels),
        },
        template: {
          metadata+: {
            labels+: defaultLabels,
            annotations+: {
              'checksum/configmapenv': std.md5(std.toString(this.configmap)),
            }
          },
          spec: {
            volumes: [],
            containers: [
              {
                envFrom: [
                  {
                    configMapRef: {
                      name: depl.metadata.name,
                    },
                  },
                ],
                image: '%s:%s' % [if registry != '' then std.join('/', [registry, image]) else '', version],
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
		volumeMounts: [],
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
          'cert-manager.io/cluster-issuer': 'letsencrypt-prod',
          'kubernetes.io/ingress.class': 'nginx',
          'nginx.ingress.kubernetes.io/auth-type': 'basic',
          'nginx.ingress.kubernetes.io/auth-secret': 'phpldapadmin-basic-auth',
          'nginx.ingress.kubernetes.io/auth-realm': 'Authentication Required',
        },
        labels+: defaultLabels,
      },
      spec: {
        tls: [
	  {
            hosts: [
              ingress,
            ],
	    secretName: 'ldap-admin-cert',
	  },
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
