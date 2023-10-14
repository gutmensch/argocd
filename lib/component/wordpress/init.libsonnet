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
      imageRegistryMirror: '',
      imageRegistry: '',
      imageRef: 'bitnami/wordpress',
      imageVersion: '6.3.2',
      replicas: 1,
      mysqlDatabaseUsers: [],
      blogName: 'my wordpress',
      ingress: '',
      dbHost: 'mysql',
      dbUser: 'wordpress',
      dbPassword: 'changeme',
      dbDatabase: 'wordpress',
      dbOpts: {
        // certificate: '/etc/ssl/certs/server.crt',
        // key: '/etc/ssl/certs/server.key',
        // ca_certificate: '/etc/ssl/certs/ca.crt',
        verify_server_cert: 'false',
      },
      certIssuer: 'letsencrypt-prod',
      smtpHost: 'localhost',
      smtpPort: 25,
      smtpUser: 'anonymous',
      smtpPassword: 'anon',
      memoryLimitMB: 512,
      outputBuffering: 8196,
      postMaxSizeMB: 256,
      uploadMaxFileSize: 256,
    },
  ):: helper.uniquify({

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    local appName = name,
    local componentName = 'wordpress',
    local ingressRestricted = if tenant == 'lts' then false else true,
    local dbCreds = helper.lookupUserCredentials(config.mysqlDatabaseUsers, config.dbUser, config.dbPassword, config.dbDatabase),

    assert tenant == 'staging' || (tenant == 'lts' && dbCreds.password != 'changeme') : error 'please change the database password for lts tenant',

    secret: kube.Secret(componentName) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      stringData: {
        WORDPRESS_USERNAME: config.user,
        WORDPRESS_PASSWORD: config.password
        WORDPRESS_EMAIL: config.email,
        WORDPRESS_FIRST_NAME: config.firstName,
        WORDPRESS_LAST_NAME: config.lastName,
        WORDPRESS_BLOG_NAME: config.blogName,

        WORDPRESS_DATABASE_HOST: config.dbHost,
        WORDPRESS_DATABASE_USER: dbCreds.user,
        WORDPRESS_DATABASE_PASSWORD: dbCreds.password,
        WORDPRESS_DATABASE_NAME: dbCreds.database,
        WORDPRESS_ENABLE_REVERSE_PROXY: 'yes',
        WORDPRESS_CONFIG_EXTRA: |||
        |||,
        PHP_MEMORY_LIMIT: std.toString(config.memoryLimitMB),
        PHP_POST_MAX_SIZE: std.toString(config.postMaxSizeMB),
        PHP_UPLOAD_MAX_FILESIZE: std.toString(config.uploadMaxFileSize),
        PHP_OUTPUT_BUFFERING: std.toString(config.outputBuffering),
        WORDPRESS_SMTP_HOST: config.smtpHost,
        WORDPRESS_SMTP_PORT: std.toString(config.smtpPort),
        WORDPRESS_SMTP_USER: config.smtpUser,
        WORDPRESS_SMTP_PASSWORD: config.smtpPassword,
        PHP_ENABLE_OPCACHE: 'yes',
        PHP_EXPOSE_PHP: 'no',

        WORDPRESS_PLUGINS: 'all',
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
            nodeSelector: {
              'topology.kubernetes.io/region': region,
            },
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
                image: helper.getImage(config.imageRegistryMirror, config.imageRegistry, config.imageRef, config.imageVersion),
                imagePullPolicy: 'Always',
                livenessProbe: {
                  exec: {
                    command: [
                      '/bin/bash',
                      '/usr/local/bin/probe.sh',
                    ],
                  },
                  initialDelaySeconds: 10,
                  periodSeconds: 30,
                },
                readinessProbe: {
                  exec: {
                    command: [
                      '/bin/bash',
                      '/usr/local/bin/probe.sh',
                    ],
                  },
                  initialDelaySeconds: 10,
                  periodSeconds: 10,
                },
                ports: [
                  {
                    containerPort: 8080,
                    name: 'http',
                    protocol: 'TCP',
                  },
                ],
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

    ingress: if std.get(config, 'ingress') != null then kube.Ingress(componentName, ingressRestricted) {
      local ing = self,
      metadata+: {
        namespace: namespace,
        annotations+: {
          'cert-manager.io/cluster-issuer': config.certIssuer,
          'kubernetes.io/ingress.class': 'nginx',
          'nginx.ingress.kubernetes.io/proxy-body-size': '%sm' % [config.postMaxSizeMB],
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
