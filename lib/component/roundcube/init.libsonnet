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
      imageRegistry: '',
      imageRef: 'gutmensch/roundcube',
      imageVersion: '1.6.0-5',
      replicas: 1,
      memcachedHosts: ['memcached:11211'],
      dbWriteHost: 'mysql',
      dbReadHost: 'mysql',
      mysqlDatabaseUsers: [],
      dbUser: 'roundcube',
      dbPassword: 'changeme',
      dbDatabase: 'roundcubemail',
      dbOpts: {
        // certificate: '/etc/ssl/certs/server.crt',
        // key: '/etc/ssl/certs/server.key',
        // ca_certificate: '/etc/ssl/certs/ca.crt',
        verify_server_cert: 'false',
      },
      imapCache: 'memcached',
      imapCacheTTL: '10d',
      messagesCache: 'db',
      messagesCacheTTL: '10d',
      messagesCacheThreshold: 500,
      imapHost: 'mailer',
      smtpHost: 'mailer',
      managesieveHost: 'mailer',
      logLogins: true,
      logDriver: 'stdout',
      // minutes - 2 weeks
      sessionLifetime: 20160,
      desKey: 'changeme',
      loginUsernameFilter: 'email',
      certIssuer: 'letsencrypt-prod',
    },
  ):: helper.uniquify({

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    local appName = name,
    local componentName = 'roundcube',

    // mysql user/db definition takes precedence is username found in definitions
    local _lookup(userList, user, pass, db) =
      local mysqlUserDef = [x for x in userList if (x.user == user && x.database == db)];
      local appUserDef = {
        user: user,
        password: pass,
        database: db,
      };
      local res = if std.length(mysqlUserDef) > 0 then mysqlUserDef[0] else appUserDef;
      res,
    local _user = _lookup(config.mysqlDatabaseUsers, config.dbUser, config.dbPassword, config.dbDatabase),

    secret: kube.Secret(componentName) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      stringData: {
        // XXX: double base64 encoded in secret, decoded by entrypoint
        RCCONFIG: std.base64(helper.manifestPhpConfig({
          db_dsnw: 'mysql://%s:%s@%s/%s?%s' % [
            _user.user,
            _user.password,
            config.dbWriteHost,
            _user.database,
            std.join('&', [std.join('=', [i, config.dbOpts[i]]) for i in std.objectFields(config.dbOpts)]),
          ],
          db_dsnr: 'mysql://%s:%s@%s/%s?%s' % [
            _user.user,
            _user.password,
            config.dbReadHost,
            _user.database,
            std.join('&', [std.join('=', [i, config.dbOpts[i]]) for i in std.objectFields(config.dbOpts)]),
          ],
          memcache_hosts: config.memcachedHosts,
          des_key: config.desKey,
          imap_cache: config.imapCache,
          imap_cache_ttl: config.imapCacheTTL,
          messages_cache: config.messagesCache,
          messages_cache_ttl: config.messagesCacheTTL,
          messages_cache_threshold: config.messagesCacheThreshold,
          imap_host: config.imapHost,
          smtp_host: config.smtpHost,
          managesieve_host: config.managesieveHost,
          session_lifetime: config.sessionLifetime,
          log_driver: config.logDriver,
          log_logins: config.logLogins,
          login_username_filter: config.loginUsernameFilter,
        })),
      },
    },

    deployment: kube._Object('argoproj.io/v1alpha1', 'Rollout', componentName) {
      metadata+: {
        name: name,
        labels+: config.labels,
      },
      spec+: {
        replicas: std.get(config, 'replicas', default=1),
        revisionHistoryLimit: 5,
        selector: {
          matchLabels: config.labels,
        },
        template+: {
          metadata+: {
            annotations+: {
              'checksum/config': std.md5(std.toString(this.secret)),
            },
            labels+: config.labels + config.containerImageLabels,
          },
          spec: {
            containers: [
              {
                envFrom: [
                  {
                    secretRef: {
                      name: componentName,
                    },
                  },
                ],
                name: name,
                image: helper.getImage(config.imageRegistry, config.imageRef, config.imageVersion),
                imagePullPolicy: 'Always',
                livenessProbe: {
                  httpGet: {
                    path: '/',
                    port: 'http',
                  },
                },
                ports: [
                  {
                    containerPort: 8080,
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
