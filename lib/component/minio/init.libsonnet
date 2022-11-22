local helper = import '../../helper.libsonnet';
local kube = import '../../kube.libsonnet';
local policy = import 'templates/policy.libsonnet';

{
  generate(
    name, namespace, region, tenant, appConfig, defaultConfig={
      imageRegistry: '',
      imageRef: 'quay.io/minio/minio',
      imageVersion: 'RELEASE.2022-10-24T18-35-07Z',
      imageConsoleRef: 'quay.io/minio/mc',
      imageConsoleVersion: 'RELEASE.2022-10-20T23-26-33Z',
      rootUser: 'root',
      rootPassword: 'changeme',
      storageClass: 'default',
      storageSize: '20Gi',
      cacheStorageClass: 'default',
      cacheStorageSize: '1Gi',
      ldapServiceAccountBindDN: '',
      ldapServiceAccountPassword: '',
      ldapHost: '',
      ldapBaseDN: 'o=auth,dc=local',
      ldapUsernameFormat: 'uid=%%s,ou=People,%s,uid=%%s,ou=ServiceAccount,%s' % [self.ldapBaseDN, self.ldapBaseDN],
      ldapUserDNSearchFilter: '(&(objectclass=inetOrgPerson)(uid=%s))',
      ldapGroupSearchFilter: '(&(objectclass=groupOfNames)(member=%s))',
      ldapAdminGroupDN: 'cn=MinIOAdmin,ou=Group,%s' % [self.ldapBaseDN],
      ldapTlsSkipVerify: true,
      ldapStartTls: true,
      replicas: 1,
      prometheusAuthType: 'public',
      buckets: {
        // example: { locks: false, versioning: true },
      },
      policies: {
        // examplerw: { bucket: 'example', actions: ['list', 'write', 'read', 'delete'], group: 'cn=BackupRW,ou=Groups,o=auth,dc=local' },
      },
    }
  ):: {

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    assert config.rootPassword != 'changeme' : error '"changeme" is an invalid password',
    assert config.ldapHost != '' : error 'ldapHost must be set',

    local appName = name,
    local componentName = 'minio',

    configmap: kube.ConfigMap(componentName) {
      data: {
        'add-policy.sh': importstr 'scripts/add-policy.sh',
        'add-user.sh': importstr 'scripts/add-user.sh',
        'custom-command.sh': importstr 'scripts/custom-command.sh',
        initialize: importstr 'scripts/initialize.sh',
        // manage buckets and resources
        'add-custom-bucket.sh': std.join('\n', [
          '#!/bin/sh',
          'source /config/custom-command.sh',
        ] + this.buckets),
        'add-custom-policy.sh': std.join('\n', [
          '#!/bin/sh',
          'source /config/add-policy.sh',
          '${MC} admin policy set myminio consoleAdmin group="%s"' % [config.ldapAdminGroupDN],
        ] + this.policies),
      } + this.policyFiles,
      metadata+: {
        labels+: config.labels,
        namespace: namespace,
      },
    },

    configmapcfg: kube.ConfigMap('%s-config' % [componentName]) {
      data: {
        MINIO_PROMETHEUS_AUTH_TYPE: config.prometheusAuthType,
        MINIO_IDENTITY_LDAP_SERVER_ADDR: if std.endsWith(config.ldapHost, ':389') then config.ldapHost else '%s:389' % [config.ldapHost],
        MINIO_IDENTITY_LDAP_USER_DN_SEARCH_BASE_DN: config.ldapBaseDN,
        MINIO_IDENTITY_LDAP_USER_DN_SEARCH_FILTER: config.ldapUserDNSearchFilter,
        MINIO_IDENTITY_LDAP_GROUP_SEARCH_BASE_DN: config.ldapBaseDN,
        MINIO_IDENTITY_LDAP_GROUP_SEARCH_FILTER: config.ldapGroupSearchFilter,
        MINIO_IDENTITY_LDAP_TLS_SKIP_VERIFY: std.toString(config.ldapTlsSkipVerify),
        MINIO_IDENTITY_LDAP_SERVER_STARTTLS: std.toString(config.ldapStartTls),
      },
      metadata+: {
        labels+: config.labels,
        namespace: namespace,
      },
    },

    buckets:: [
      '${MC} mb --ignore-existing %s %s myminio/%s' % [if config.buckets[b].locks then '--with-locks' else '', if config.buckets[b].versioning then '--with-versioning' else '', b]
      for b in std.objectFields(config.buckets)
    ],

    job_buckets: kube.Job('%s-bucket-mgmt-%s' % [componentName, std.substr(std.md5(std.toString(this.buckets)), 23, 8)]) {
      metadata+: {
        labels: config.labels,
        namespace: namespace,
      },
      spec: {
        template: {
          metadata: {
            labels: config.labels,
          },
          spec: {
            containers: [
              {
                command: [
                  '/bin/sh',
                  '/config/add-custom-bucket.sh',
                ],
                env: [
                  {
                    name: 'MINIO_ENDPOINT',
                    value: componentName,
                  },
                  {
                    name: 'MINIO_PORT',
                    value: '9000',
                  },
                ],
                envFrom: [
                  {
                    secretRef: {
                      name: componentName,
                    },
                  },
                ],
                image: helper.getImage(config.imageRegistry, config.imageConsoleRef, config.imageConsoleVersion),  // orig: 'quay.io/minio/mc:RELEASE.2022-10-20T23-26-33Z',
                imagePullPolicy: 'IfNotPresent',
                name: 'minio-mc',
                resources: {
                  requests: {
                    memory: '128Mi',
                  },
                },
                volumeMounts: [
                  {
                    mountPath: '/config',
                    name: 'minio-configuration',
                  },
                ],
              },
            ],
            restartPolicy: 'OnFailure',
            serviceAccountName: componentName,
            volumes: [
              {
                name: 'minio-configuration',
                projected: {
                  sources: [
                    {
                      configMap: {
                        name: componentName,
                      },
                    },
                    // {
                    //   secret: {
                    //     name: componentName,
                    //   },
                    // },
                  ],
                },
              },
            ],
          },
        },
      },
    },

    policyFiles:: {
      ['policy-%s.json' % [p]]: std.manifestJsonMinified(policy { Bucket: config.policies[p].bucket, Actions: config.policies[p].actions })
      for p in std.objectFields(config.policies)
    },

    policies:: [
      'createPolicy %s /config/policy-%s.json "%s"' % [p, p, config.policies[p].group]
      for p in std.objectFields(config.policies)
    ],

    job_policies: kube.Job('%s-policy-mgmt-%s' % [componentName, std.substr(std.md5(std.toString(this.policies)), 23, 8)]) {
      metadata+: {
        labels: config.labels,
        namespace: namespace,
      },
      spec: {
        template: {
          metadata: {
            labels: config.labels,
          },
          spec: {
            containers: [
              {
                command: [
                  '/bin/sh',
                  '/config/add-custom-policy.sh',
                ],
                env: [
                  {
                    name: 'MINIO_ENDPOINT',
                    value: componentName,
                  },
                  {
                    name: 'MINIO_PORT',
                    value: '9000',
                  },
                ],
                envFrom: [
                  {
                    secretRef: {
                      name: componentName,
                    },
                  },
                ],
                image: helper.getImage(config.imageRegistry, config.imageConsoleRef, config.imageConsoleVersion),  // orig: 'quay.io/minio/mc:RELEASE.2022-10-20T23-26-33Z',
                imagePullPolicy: 'IfNotPresent',
                name: 'minio-mc',
                resources: {
                  requests: {
                    memory: '128Mi',
                  },
                },
                volumeMounts: [
                  {
                    mountPath: '/config',
                    name: 'minio-configuration',
                  },
                ],
              },
            ],
            restartPolicy: 'OnFailure',
            serviceAccountName: componentName,
            volumes: [
              {
                name: 'minio-configuration',
                projected: {
                  sources: [
                    {
                      configMap: {
                        name: componentName,
                      },
                    },
                    // {
                    //   secret: {
                    //     name: componentName,
                    //   },
                    // },
                  ],
                },
              },
            ],
          },
        },
      },
    },

    service_minio: kube.Service(componentName) {
      metadata+: {
        labels: config.labels,
        namespace: namespace,
      },
      spec+: {
        ports: [
          {
            name: 'http',
            port: 9000,
            protocol: 'TCP',
            targetPort: 9000,
          },
        ],
        selector: config.labels,
        type: 'ClusterIP',
      },
    },

    service_console: kube.Service('%s-console' % [componentName]) {
      metadata+: {
        labels: config.labels,
        namespace: namespace,
      },
      spec+: {
        ports: [
          {
            name: 'http',
            port: 9001,
            protocol: 'TCP',
            targetPort: 9001,
          },
        ],
        selector: config.labels,
        type: 'ClusterIP',
      },
    },

    service_sfs: kube.Service('%s-headless' % [componentName]) {
      metadata+: {
        labels: config.labels,
        namespace: namespace,
      },
      spec+: {
        clusterIP: 'None',
        ports: [
          {
            name: 'http',
            port: 9000,
            protocol: 'TCP',
            targetPort: 9000,
          },
        ],
        publishNotReadyAddresses: true,
        selector: config.labels,
      },
    },

    serviceaccount: kube.ServiceAccount(componentName) {
      metadata+: {
        labels: config.labels,
        namespace: namespace,
      },
    },

    statefulset: kube.StatefulSet(componentName) {
      metadata+: {
        labels: config.labels,
        namespace: namespace,
      },
      spec+: {
        podManagementPolicy: 'Parallel',
        replicas: config.replicas,
        selector: {
          matchLabels: config.labels,
        },
        serviceName: '%s-headless' % [componentName],
        template: {
          metadata: {
            annotations: {
              'checksum/config': std.md5(std.toString(this.configmapcfg)),
              'checksum/secrets': std.md5(std.toString(this.secret)),
            },
            labels: config.labels,
            name: 'minio',
          },
          spec: {
            containers: [
              {
                command: [
                  '/bin/sh',
                  '-ce',
                  '/usr/bin/docker-entrypoint.sh minio server /storage -S /etc/minio/certs/ --address :9000 --console-address :9001',
                ],
                envFrom: [
                  {
                    configMapRef: {
                      name: '%s-config' % [componentName],
                    },
                  },
                  {
                    secretRef: {
                      name: componentName,
                    },
                  },
                ],
                image: helper.getImage(config.imageRegistry, config.imageRef, config.imageVersion),  // orig: 'quay.io/minio/minio:RELEASE.2022-10-24T18-35-07Z',
                imagePullPolicy: 'IfNotPresent',
                name: 'minio',
                ports: [
                  {
                    containerPort: 9000,
                    name: 'http',
                  },
                  {
                    containerPort: 9001,
                    name: 'http-console',
                  },
                ],
                resources: {
                  // requests: {
                  //   memory: '16Gi',
                  // },
                },
                volumeMounts: [
                  {
                    mountPath: '/storage',
                    name: 'storage',
                  },
                  {
                    mountPath: '/cache',
                    name: 'cache',
                  },
                ],
              },
            ],
            securityContext: {
              fsGroup: 1000,
              fsGroupChangePolicy: 'OnRootMismatch',
              runAsGroup: 1000,
              runAsUser: 1000,
            },
            serviceAccountName: componentName,
            volumes: [
              // XXX: not in use?!
              //  {
              //    name: 'minio-user',
              //    secret: {
              //      secretName: componentName,
              //    },
              //  },
            ],
          },
        },
        updateStrategy: {
          type: 'RollingUpdate',
        },
        volumeClaimTemplates: [
          {
            metadata: {
              labels: config.labels,
              name: 'storage',
            },
            spec: {
              storageClassName: config.storageClass,
              accessModes: [
                'ReadWriteOnce',
              ],
              resources: {
                requests: {
                  storage: config.storageSize,
                },
              },
            },
          },
          {
            metadata: {
              labels: config.labels,
              name: 'cache',
            },
            spec: {
              storageClassName: config.cacheStorageClass,
              accessModes: [
                'ReadWriteOnce',
              ],
              resources: {
                requests: {
                  storage: config.cacheStorageSize,
                },
              },
            },
          },

        ],
      },
    },

    secret: kube.Secret(componentName) {
      metadata+: {
        labels: config.labels,
        namespace: namespace,
      },
      stringData: {
        MINIO_ROOT_PASSWORD: config.rootPassword,
        MINIO_ROOT_USER: config.rootUser,
        MINIO_IDENTITY_LDAP_LOOKUP_BIND_DN: config.ldapServiceAccountBindDN,
        MINIO_IDENTITY_LDAP_LOOKUP_BIND_PASSWORD: config.ldapServiceAccountPassword,
      },
      type: 'Opaque',
    },

  },
}
