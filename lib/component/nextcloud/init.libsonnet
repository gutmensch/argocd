local helper = import '../../helper.libsonnet';
local kube = import '../../kube.libsonnet';

{
  generate(
    name, namespace, region, tenant, appConfig, defaultConfig={
      imageRegistryMirror: '',
      imageRegistry: '',
      imageRef: 'library/nextcloud',
      imageVersion: '26.0.0-fpm-alpine',
      replicas: 1,
      mysqlHost: 'mysql',
      mysqlDatabaseUsers: [],
      mysqlDatabase: 'nextcloud',
      mysqlUser: 'nextcloud',
      mysqlPassword: 'changeme',
      adminUser: 'nextcloud',
      adminPassword: 'changeme',
      publicFQDN: 'cloud.example.com',
      s3Host: 'minio',
      s3Bucket: 'nextcloud',
      s3Port: 9000,
      s3UseSSL: false,
      s3UsePathStyle: true,
      s3AutoCreate: false,
      s3AccessKey: 'changeme',
      s3SecretKey: 'changeme',
      smtpUser: null,
      smtpPassword: null,
      redisHost: 'redis',
      redisPort: 6379,
      redisPassword: null,
      trustedDomains: [],
      dataDir: '/var/www/html/data',
      mailFromAddress: 'noreply',
      mailDomain: 'example.com',
      smtpHost: 'mailserver',
      smtpSecure: 'ssl',
      smtpPort: 25,
      smtpAuthType: 'None',
      storageSize: '10Gi',
      storageClass: 'default',
    }
  ):: helper.uniquify({

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    local appName = name,
    local componentName = 'nextcloud',

    local dbCreds = helper.lookupUserCredentials(config.mysqlDatabaseUsers, config.mysqlUser, config.mysqlPassword, config.mysqlDatabase),

    configmap_nextcloud_config: kube.ConfigMap('%s-config' % [componentName]) {
      data: {
        'apcu.config.php': importstr 'templates/apcu.config.php.tmpl',
        'apps.config.php': importstr 'templates/apps.config.php.tmpl',
        'autoconfig.php': importstr 'templates/autoconfig.php.tmpl',
        'redis.config.php': importstr 'templates/redis.config.php.tmpl',
        'smtp.config.php': importstr 'templates/smtp.config.php.tmpl',
      },
      metadata+: {
        labels+: config.labels,
        namespace: namespace,
      },
    },

    secret_nextcloud_env: kube.Secret('%s-env' % [componentName]) {
      metadata+: {
        labels+: config.labels,
        namespace: namespace,
      },
      stringData: {
        MYSQL_USER: dbCreds.user,
        MYSQL_PASSWORD: dbCreds.password,
        NEXTCLOUD_ADMIN_USER: config.adminUser,
        NEXTCLOUD_ADMIN_PASSWORD: config.adminPassword,
        OBJECTSTORE_S3_KEY: config.s3AccessKey,
        OBJECTSTORE_S3_SECRET: config.s3SecretKey,
        [if config.smtpUser != null then 'SMTP_NAME']: config.smtpUser,
        [if config.smtpPassword != null then 'SMTP_PASSWORD']: config.smtpPassword,
        [if config.redisPassword != null then 'REDIS_HOST_PASSWORD']: config.redisPassword,
      },
    },

    configmap_nextcloud_env: kube.ConfigMap('%s-env' % [componentName]) {
      data: {
        MYSQL_HOST: config.mysqlHost,
        MYSQL_DATABASE: dbCreds.database,
        NEXTCLOUD_TRUSTED_DOMAINS: std.join(',', config.trustedDomains + [config.publicFQDN]),
        NEXTCLOUD_DATA_DIR: '/var/www/html/data',
        MAIL_FROM_ADDRESS: config.mailFromAddress,
        MAIL_DOMAIN: config.mailDomain,
        SMTP_HOST: config.smtpHost,
        SMTP_SECURE: config.smtpSecure,
        SMTP_PORT: std.toString(config.smtpPort),
        SMTP_AUTHTYPE: config.smtpAuthType,
        OBJECTSTORE_S3_HOST: config.s3Host,
        OBJECTSTORE_S3_BUCKET: config.s3Bucket,
        OBJECTSTORE_S3_PORT: std.toString(config.s3Port),
        OBJECTSTORE_S3_SSL: std.toString(config.s3UseSSL),
        OBJECTSTORE_S3_USEPATH_STYLE: std.toString(config.s3UsePathStyle),
        OBJECTSTORE_S3_AUTOCREATE: std.toString(config.s3AutoCreate),
        REDIS_HOST: config.redisHost,
        REDIS_HOST_PORT: std.toString(config.redisPort),
      },
      metadata+: {
        labels+: config.labels,
        namespace: namespace,
      },
    },

    configmap_nextcloud_nginxconfig: kube.ConfigMap('%s-nginx-config' % [componentName]) {
      data: {
        'nginx.conf': importstr 'templates/nginx.conf.tmpl',
      },
      metadata+: {
        labels+: config.labels,
        namespace: namespace,
      },
    },

    statefulset_nextcloud: kube.StatefulSet(componentName) {
      metadata+: {
        labels+: config.labels,
        namespace: namespace,
      },
      spec: {
        serviceName: '%s-headless' % [componentName],
        replicas: 1,
        selector: {
          matchLabels: config.labels,
        },
        template: {
          metadata: {
            annotations: {
              'checksum/nextcloud-env': std.md5(std.toString(this.configmap_nextcloud_env)),
              'checksum/nextcloud-secret-env': std.md5(std.toString(this.secret_nextcloud_env)),
              'nginx-config-hash': std.md5(std.toString(this.configmap_nextcloud_nginxconfig)),
              // 'php-config-hash': '44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a',
            },
            labels: config.labels,
          },
          spec: {
            containers: [
              {
                envFrom: [
                  {
                    configMapRef: {
                      name: '%s-env' % [componentName],
                    },
                  },
                  {
                    secretRef: {
                      name: '%s-env' % [componentName],
                    },
                  },
                ],
                image: helper.getImage(config.imageRegistryMirror, config.imageRegistry, config.imageRef, config.imageVersion),
                imagePullPolicy: 'IfNotPresent',
                name: componentName,
                resources: {},
                volumeMounts: [
                  {
                    mountPath: '/var/www/',
                    name: '%s-main' % [componentName],
                    subPath: 'root',
                  },
                ] + [
                  {
                    mountPath: '/var/www/%s' % [f],
                    name: '%s-main' % [componentName],
                    subPath: std.split(f, '/')[std.length(std.split(f, '/')) - 1],
                  }
                  for f in ['html', 'html/themes', 'tmp', 'html/custom_apps', 'html/config', 'html/data']
                ] + [
                  {
                    mountPath: '/var/www/html/config/%s' % [f],
                    name: '%s-config' % [componentName],
                    subPath: f,
                  }
                  for f in ['redis.config.php', 'smtp.config.php', 'autoconfig.php', 'apps.config.php', 'apcu.config.php']
                ],
              },
              {
                image: helper.getImage(config.imageRegistryMirror, config.imageRegistry, config.imageRef, config.imageVersion),
                imagePullPolicy: 'IfNotPresent',
                livenessProbe: {
                  failureThreshold: 3,
                  httpGet: {
                    httpHeaders: [
                      {
                        name: 'Host',
                        value: 'cloud.bln.space',
                      },
                    ],
                    path: '/status.php',
                    port: 'http',
                  },
                  initialDelaySeconds: 10,
                  periodSeconds: 10,
                  successThreshold: 1,
                  timeoutSeconds: 5,
                },
                name: 'nginx',
                ports: [
                  {
                    containerPort: 80,
                    name: 'http',
                    protocol: 'TCP',
                  },
                ],
                readinessProbe: {
                  failureThreshold: 3,
                  httpGet: {
                    httpHeaders: [
                      {
                        name: 'Host',
                        value: 'cloud.bln.space',
                      },
                    ],
                    path: '/status.php',
                    port: 'http',
                  },
                  initialDelaySeconds: 10,
                  periodSeconds: 10,
                  successThreshold: 1,
                  timeoutSeconds: 5,
                },
                resources: {},
                volumeMounts: [
                  {
                    mountPath: '/var/www/',
                    name: '%s-main' % [componentName],
                    subPath: 'root',
                  },
                ] + [
                  {
                    mountPath: '/var/www/%s' % [f],
                    name: '%s-main' % [componentName],
                    subPath: std.split(f, '/')[std.length(std.split(f, '/')) - 1],
                  }
                  for f in ['html', 'html/themes', 'tmp', 'html/custom_apps', 'html/config', 'html/data']
                ] + [
                  {
                    mountPath: '/etc/nginx/nginx.conf',
                    name: '%s-nginx-cfg' % [componentName],
                    subPath: 'nginx.conf',
                  },
                ],
              },
            ],
            securityContext: {
              fsGroup: 82,
            },
            volumes: [
              {
                emptyDir: {},
                name: '%s-main' % [componentName],
              },
              {
                configMap: {
                  name: '%s-cfg' % [componentName],
                },
                name: '%s-cfg' % [componentName],
              },
              {
                configMap: {
                  name: '%s-nginx-cfg' % [componentName],
                },
                name: '%s-nginx-cfg' % [componentName],
              },
            ],
          },
        },
        updateStrategy: {
          type: 'RollingUpdate',
        },
        volumeClaimTemplates: [
          {
            metadata: {
              annotations: null,
              name: '%s-main' % [componentName],
            },
            spec: {
              accessModes: [
                'ReadWriteOnce',
              ],
              resources: {
                requests: {
                  storage: config.storageSize,
                },
              },
              storageClassName: config.storageClass,
            },
          },
        ],
      },
    },

    serviceheadless: kube.Service('%s-headless' % [componentName]) {
      apiVersion: 'v1',
      kind: 'Service',
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      spec: {
        clusterIP: 'None',
        ports: [
          {
            name: 'http',
            port: 8080,
            targetPort: 'http',
          },
        ],
        selector: config.labels,
        sessionAffinity: 'None',
        type: 'ClusterIP',
      },
    },

    ingress_nextcloud: kube.Ingress(componentName, false) {
      metadata+: {
        annotations: {
          'cert-manager.io/cluster-issuer': 'letsencrypt-prod',
          'nginx.ingress.kubernetes.io/proxy-body-size': '5000m',
        },
        labels: config.labels,
        namespace: namespace,
      },
      spec: {
        ingressClassName: 'nginx',
        rules: [
          {
            host: config.publicFQDN,
            http: {
              paths: [
                {
                  backend: {
                    service: {
                      name: 'nextcloud',
                      port: {
                        number: 8080,
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
        tls: [
          {
            hosts: [
              'cloud.bln.space',
            ],
            secretName: 'nextcloud-ingress-cert',
          },
        ],
      },
    },
    service_nextcloud: kube.Service(componentName) {
      metadata+: {
        labels: config.labels,
        namespace: namespace,
      },
      spec: {
        ports: [
          {
            name: 'http',
            port: 8080,
            protocol: 'TCP',
            targetPort: 'http',
          },
        ],
        selector: config.labels,
        type: 'ClusterIP',
      },
    },
  }),
}
