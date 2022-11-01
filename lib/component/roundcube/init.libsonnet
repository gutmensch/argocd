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
      imageRef: 'gutmensch/roundcube',
      imageVersion: '1.6.0',
      replicas: 1,
      memcachedHost: 'memcached:11211',
      dbHost: 'mysql',
      dbUser: 'roundcube',
      dbPassword: 'changeme',
      dbDatabase: 'roundcubemail',
      dbOpts: {
        //certificate: '/etc/ssl/certs/server.crt',
        //key: '/etc/ssl/certs/server.key',
        //ca_certificate: '/etc/ssl/certs/ca.crt',
        verify_server_cert: 'false',
      },
      imapHost: 'mailer',
      smtpHost: 'mailer',
      managesieveHost: 'mailer',
      logLogins: 'true',
      logDriver: 'stdout',
      sessionLifetime: '20160',
      desKey: 'changeme',
      certIssuer: 'letsencrypt-prod',
    },
  ):: helper.uniquify({

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    local appName = name,
    local componentName = 'roundcube',

    configmap: kube.ConfigMap(componentName) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      data: {
        ROUNDCUBE_IMAP_HOST: config.imapHost,
        ROUNDCUBE_SMTP_HOST: config.smtpHost,
        ROUNDCUBE_MANAGESIEVE_HOST: config.managesieveHost,
        MEMCACHED_SERVER: config.memcachedHost,
        ROUNDCUBE_SESSION_LIFETIME: config.sessionLifetime,
        ROUNDCUBE_LOG_DRIVER: config.logDriver,
        ROUNDCUBE_LOG_LOGINS: config.logLogins,
      },
    },

    secret: kube.Secret(componentName) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      stringData: {
        ROUNDCUBE_DB_DSNW: 'mysql://%s:%s@%s/%s?%s' % [
          config.dbUser,
          config.dbPassword,
          config.dbHost,
          config.dbDatabase,
          std.join('&', [std.join('=', [i, config.dbOpts[i]]) for i in std.objectFields(config.dbOpts)]),
        ],
        ROUNDCUBE_DES_KEY: config.desKey,
      },
    },

    deployment: argo.SimpleRollout(componentName, componentName, 8080, '/', config) {
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

    // canaryservice: kube.Service('%s-canary' % componentName) {
    //   metadata+: {
    //     namespace: namespace,
    //     labels+: config.labels,
    //   },
    //   spec: {
    //     ports: [
    //       {
    //         name: 'http',
    //         port: 80,
    //         protocol: 'TCP',
    //         targetPort: 'http',
    //       },
    //     ],
    //     selector: config.labels,
    //     type: 'ClusterIP',
    //   },
    // },

    ingress: if std.get(config, 'ingress') != null then kube.Ingress(componentName) {
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
