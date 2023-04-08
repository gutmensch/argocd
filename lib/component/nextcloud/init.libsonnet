// debugging
// su - www-data -s /bin/sh -c "PHP_MEMORY_LIMIT=512M php /var/www/html/occ app:list"

local helper = import '../../helper.libsonnet';
local kube = import '../../kube.libsonnet';

{
  generate(
    name, namespace, region, tenant, appConfig, defaultConfig={
      imageRegistryMirror: '',
      imageRegistry: '',
      imageRef: 'library/nextcloud',
      imageVersion: '25.0.5-fpm-alpine',
      cronjobImageRef: 'gutmensch/toolbox',
      cronjobImageVersion: '0.0.12',
      nginxImageRef: 'library/nginx',
      nginxImageVersion: '1.23.4-alpine',
      replicas: 1,
      mysqlHost: 'mysql',
      mysqlPort: 3306,
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
      redisHost: 'redis.%s.svc.cluster.local' % [namespace],
      redisPort: 6379,
      redisUser: null,
      redisPassword: null,
      trustedDomains: [],
      dataDir: '/var/www/html/data',
      mailFromAddress: 'noreply',
      mailDomain: 'example.com',
      smtpHost: 'mailserver',
      smtpUser: null,
      smtpPassword: null,
      smtpSecure: 'tls',
      smtpPort: 25,
      smtpAuthType: null,
      storageSize: '10Gi',
      storageClass: 'default',
      ldapHost: 'openldap',
      ldapPort: 636,
      ldapTLS: true,
      ldapBaseDN: 'o=auth,dc=local',
      ldapBaseUsersDN: 'ou=People,o=auth,dc=local',
      ldapBaseGroupsDN: 'ou=Group,o=auth,dc=local',
      ldapLoginFilter: '(&(objectclass=inetOrgPerson)(uid=%uid)(nextcloudEnabled=TRUE))',
      ldapUserFilter: '(&(objectclass=inetOrgPerson)(nextcloudEnabled=TRUE))',
      ldapGroupFilter: '(cn=Nextcloud*)',
      ldapGroupMemberAssocAttr: 'member',
      ldapEmailAttribute: 'mail',
    }
  ):: helper.uniquify({

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    local appName = name,
    local componentName = 'nextcloud',

    local dbCreds = helper.lookupUserCredentials(config.mysqlDatabaseUsers, config.mysqlUser, config.mysqlPassword, config.mysqlDatabase),

    configmap_nextcloud_config: kube.ConfigMap('%s-cfg' % [componentName]) {
      data: {
        'apcu.config.php': importstr 'templates/apcu.config.php.tmpl',
        'apps.config.php': importstr 'templates/apps.config.php.tmpl',
        'autoconfig.php': importstr 'templates/autoconfig.php.tmpl',
        'redis.config.php': importstr 'templates/redis.config.php.tmpl',
        'smtp.config.php': importstr 'templates/smtp.config.php.tmpl',
        'objectstore.config.php': importstr 'templates/objectstore.config.php.tmpl',
        'settings.config.php': importstr 'templates/settings.config.php.tmpl',
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
        LDAP_AGENT_NAME: config.ldapServiceAccountBindDN,
        LDAP_AGENT_PASSWORD: config.ldapServiceAccountPassword,
        [if config.smtpUser != null then 'SMTP_NAME']: config.smtpUser,
        [if config.smtpPassword != null then 'SMTP_PASSWORD']: config.smtpPassword,
        [if config.redisUser != null then 'REDIS_HOST_USER']: config.redisUser,
        [if config.redisPassword != null then 'REDIS_HOST_PASSWORD']: config.redisPassword,
      },
    },

    configmap_nextcloud_env: kube.ConfigMap('%s-env' % [componentName]) {
      data: {
        MYSQL_HOST: config.mysqlHost,
        MYSQL_PORT: std.toString(config.mysqlPort),
        MYSQL_DATABASE: dbCreds.database,
        NEXTCLOUD_TRUSTED_DOMAINS: std.join(',', config.trustedDomains + [config.publicFQDN]),
        NEXTCLOUD_DATA_DIR: '/var/www/html/data',
        NEXTCLOUD_UPDATE: std.toString(1),
        MAIL_FROM_ADDRESS: config.mailFromAddress,
        MAIL_DOMAIN: config.mailDomain,
        SMTP_HOST: config.smtpHost,
        SMTP_SECURE: config.smtpSecure,
        SMTP_PORT: std.toString(config.smtpPort),
        [if config.smtpAuthType != null then 'SMTP_AUTHTYPE']: std.toString(config.smtpAuthType),
        OBJECTSTORE_S3_HOST: config.s3Host,
        OBJECTSTORE_S3_BUCKET: config.s3Bucket,
        OBJECTSTORE_S3_PORT: std.toString(config.s3Port),
        OBJECTSTORE_S3_USE_SSL: std.toString(config.s3UseSSL),
        OBJECTSTORE_S3_USE_PATH_STYLE: std.toString(config.s3UsePathStyle),
        OBJECTSTORE_S3_AUTOCREATE: std.toString(config.s3AutoCreate),
        REDIS_HOST: config.redisHost,
        REDIS_HOST_PORT: std.toString(config.redisPort),
        TLS_REQCERT: 'never',
        LDAP_TLS: helper.boolToStrInt(config.ldapTLS),
        LDAP_USER_FILTER: config.ldapUserFilter,
        LDAP_GROUP_FILTER: config.ldapGroupFilter,
        LDAP_LOGIN_FILTER: config.ldapLoginFilter,
        LDAP_HOST: 'ldaps://%s' % [config.ldapHost],
        LDAP_PORT: std.toString(config.ldapPort),
        LDAP_BASE_DN: config.ldapBaseDN,
        LDAP_BASE_USERS_DN: config.ldapBaseUsersDN,
        LDAP_BASE_GROUPS_DN: config.ldapBaseGroupsDN,
        LDAP_GROUP_MEMBER_ASSOC_ATTR: config.ldapGroupMemberAssocAttr,
        LDAP_EMAIL_ATTRIBUTE: config.ldapEmailAttribute,
      },
      metadata+: {
        labels+: config.labels,
        namespace: namespace,
      },
    },

    configmap_nextcloud_nginxconfig: kube.ConfigMap('%s-nginx-cfg' % [componentName]) {
      data: {
        'nginx.conf': std.strReplace(importstr 'templates/nginx.conf.tmpl', '__PUBLIC_FQDN__', 'https://%s' % [config.publicFQDN]),
      },
      metadata+: {
        labels+: config.labels,
        namespace: namespace,
      },
    },

    configmap_nextcloud_ldap_integration: kube.ConfigMap('%s-ldap-cfg' % [componentName]) {
      data: {
        'enable_ldap_and_start.sh': importstr 'templates/enable_ldap_and_start.sh',
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
        replicas: config.replicas,
        selector: {
          matchLabels: config.labels,
        },
        template: {
          metadata: {
            annotations: {
              'checksum/nextcloud-env': std.md5(std.toString(this.configmap_nextcloud_env)),
              'checksum/nextcloud-secret-env': std.md5(std.toString(this.secret_nextcloud_env)),
              'checksum/nginx-config-hash': std.md5(std.toString(this.configmap_nextcloud_nginxconfig)),
              'checksum/ldap-config-hash': std.md5(std.toString(this.configmap_nextcloud_ldap_integration)),
            },
            labels: config.labels,
          },
          spec: {
            // www-data
            securityContext: {
              fsGroup: 82,
              // XXX: nextcloud image not prepared to run as unprivilged user
              //   fsGroupChangePolicy: 'OnRootMismatch',
              //   runAsGroup: 82,
              //   runAsUser: 82,
            },
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
                // the fpm image runs php-fpm as arg for entrypoint, we inject ldap configuration before
                // and then exec php-fpm as last step in our script
                args: ['/bin/sh', '/usr/local/bin/enable_ldap_and_start.sh'],
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
                    name: '%s-cfg' % [componentName],
                    subPath: f,
                  }
                  for f in ['redis.config.php', 'smtp.config.php', 'autoconfig.php', 'apps.config.php', 'apcu.config.php', 'objectstore.config.php', 'settings.config.php']
                ] + [
                  {
                    mountPath: '/usr/local/bin/enable_ldap_and_start.sh',
                    name: '%s-ldap-cfg' % [componentName],
                    subPath: 'enable_ldap_and_start.sh',
                  },
                ],
              },
              {
                image: helper.getImage(config.imageRegistryMirror, config.imageRegistry, config.nginxImageRef, config.nginxImageVersion),
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
                    containerPort: 8080,
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
            volumes: [
              {
                emptyDir: {},
                name: '%s-main' % [componentName],
              },
              {
                configMap: {
                  name: '%s-cfg' % [componentName],
                  defaultMode: std.parseOctal('0640'),
                },
                name: '%s-cfg' % [componentName],
              },
              {
                configMap: {
                  name: '%s-ldap-cfg' % [componentName],
                  defaultMode: std.parseOctal('0750'),
                },
                name: '%s-ldap-cfg' % [componentName],
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
