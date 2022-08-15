local helper = import '../../../lib/helper.libsonnet';
local kube = import '../../../lib/kube.libsonnet';
local secrets = import 'secrets.libsonnet';

{
  _adminLabels:: {
    'app.kubernetes.io/component': 'phpldapadmin',
  },

  generate(
    name,
    namespace,
    tenant,
    registry='registry.lan:5000',
    // origin: osixia/phpldapadmin, version 0.9.0 contains =phpLDAPadmin 1.2.5
    image='gutmensch/phpldapadmin',
    version='1.2.6.3-4',
    ingress='',
    ldapSvc='',
    ldapAdmin='',
    ldapRoot='',
    replicas=1,
    labels={},
  ):: {

    assert ldapSvc != '' : error 'ldap service address needed for setup',

    local this = self,
    local adminName = '%s-admin' % [name],
    local adminLabels = labels + $._adminLabels,

    configmap: kube.ConfigMap(adminName) {
      metadata+: {
        namespace: namespace,
        labels+: adminLabels,
      },
      data: {
        PHPLDAPADMIN_HTTPS: 'false',
        PHPLDAPADMIN_LDAP_CLIENT_TLS_REQCERT: 'never',
        PHPLDAPADMIN_LDAP_HOSTS: "#PYTHON2BASH:[{'%s': [{'server': [{'tls': True},{'port':389}]},{'login': [{'bind_id': 'cn=%s,%s' }]}]}]" % [ldapSvc, ldapAdmin, ldapRoot],
        PHPLDAPADMIN_TRUST_PROXY_SSL: 'true',
      },
    },

    deployment: kube.Deployment(adminName) {
      local depl = self,
      metadata+: {
        namespace: namespace,
        labels+: adminLabels,
      },
      spec: {
        replicas: replicas,
        selector: {
          matchLabels: helper.removeVersion(adminLabels),
        },
        template: {
          metadata+: {
            labels+: adminLabels,
            annotations+: {
              'checksum/configmapenv': std.md5(std.toString(this.configmap)),
            },
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

    service: kube.Service(adminName) {
      metadata+: {
        namespace: namespace,
        labels+: adminLabels,
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
        selector: helper.removeVersion(adminLabels),
        type: 'ClusterIP',
      },
    },

    [if ingress != '' then 'ingress']: kube.Ingress(adminName) {
      local ing = self,
      metadata+: {
        namespace: namespace,
        annotations+: {
          'cert-manager.io/cluster-issuer': 'letsencrypt-prod',
          'kubernetes.io/ingress.class': 'nginx',
          'nginx.ingress.kubernetes.io/auth-type': 'basic',
          'nginx.ingress.kubernetes.io/auth-secret': 'phpldapadmin-basic-auth',
          'nginx.ingress.kubernetes.io/auth-realm': 'Authentication Required',
        },
        labels+: adminLabels,
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
  } + secrets.generate(labels + $._adminLabels)[tenant],

  //  {
  //    local adminLabels = labels {
  //      'app.kubernetes.io/component': 'phpldapadmin',
  //    },
  //    labels: adminLabels,
  //  },
}
