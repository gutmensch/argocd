local helper = import '../../helper.libsonnet';
local kube = import '../../kube.libsonnet';
local ca = import '../../localca.libsonnet';
local configDefinitions = import 'ldif/config.libsonnet';
local initDefinitions = import 'ldif/init.libsonnet';
local schemaDefinitions = import 'schema/definitions.libsonnet';

{
  generate(
    name,
    namespace,
    region,
    tenant,
    appConfig,
    // override below values in the specific app/$name/config/, app/$name/secret or app/$name/cd
    // directories app instantiation and configuration and pass as appConfig parameter above
    defaultConfig={
      imageRegistry: '',
      imageRef: 'bitnami/openldap',
      imageVersion: '2.6.3',
      replicas: 1,
      storageClass: 'standard',
      storageSize: '8Gi',
      ldapRoot: 'o=auth,dc=local',
      ldapInitModules: ['memberof', 'refint'],
      ldapInitMailDomains: [],
      ldapIncludeProvidedSchemas: ['cosine', 'inetorgperson'],
      ldapIncludeManagedSchemas: ['rfc2307bis', 'virtualmail', 'nextcloud', 'opendkim', 'openssh-lpk'],
      // example secrets (errors out if unchanged)
      ldapAdminUsername: 'admin',
      ldapAdminPassword: 'changeme',
      ldapConfigAdminUsername: 'configadmin',
      ldapConfigAdminPassword: 'changeme',
    }
  ):: helper.uniquify({

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    assert config.ldapAdminPassword != 'changeme' && config.ldapConfigAdminPassword != 'changeme' : error '"changeme" is an invalid password',

    local appName = name,
    local componentName = 'openldap',

    local ldapConfig = configDefinitions {
      ldapModules: std.get(config, 'ldapInitModules', []),
    },

    local ldapBootstrap = initDefinitions {
      ldapBase: config.ldapRoot,
      ldapMailDomains: std.get(config, 'ldapInitMailDomains', []),
    },

    local certCRDs = ca.serverCert(
      name=componentName,
      namespace=namespace,
      createIssuer=true,
      dnsNames=['%s.%s.svc.cluster.local' % [componentName, namespace], '%s.%s.svc.cluster.local' % [name, namespace]],
      labels=config.labels,
    ),
    localrootcacert: certCRDs.localrootcacert,
    localcertissuer: certCRDs.localcertissuer,
    servercert: certCRDs.localservercert,

    configmap: kube.ConfigMap(componentName) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      data: {
        LDAP_ADD_SCHEMAS: 'yes',
        LDAP_ADMIN_PASSWORD_FILE: '',
        LDAP_ALLOW_ANON_BINDING: 'no',
        LDAP_CONFIG_ADMIN_ENABLED: 'yes',
        LDAP_CONFIG_ADMIN_PASSWORD_FILE: '',
        // skip default tree, use our provided /ldifs/init.ldif
        LDAP_SKIP_DEFAULT_TREE: 'yes',
        LDAP_CUSTOM_LDIF_DIR: '/ldifs',
        LDAP_ENABLE_TLS: 'yes',
        LDAP_EXTRA_SCHEMAS: std.join(',', config.ldapIncludeProvidedSchemas + config.ldapIncludeManagedSchemas),
        LDAP_LDAPS_PORT_NUMBER: '1636',
        LDAP_LOGLEVEL: '256',
        LDAP_PORT_NUMBER: '1389',
        LDAP_ROOT: config.ldapRoot,
        LDAP_ULIMIT_NOFILES: '1024',
        // unused, we skip default tree and mount schemas in directory and ref as extra
        LDAP_GROUP: 'Readers',
        LDAP_USER_DC: 'Users',
        LDAP_USERS: '',
        LDAP_PASSWORDS: '',
        LDAP_CUSTOM_SCHEMA_FILE: '/schema/custom.ldif',
      },
    },

    servicecluster: kube.Service(componentName) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      spec: {
        ports: [
          {
            name: 'ldap-port',
            nodePort: null,
            port: 389,
            protocol: 'TCP',
            targetPort: 'ldap-port',
          },
          {
            name: 'ldaps-port',
            nodePort: null,
            port: 636,
            protocol: 'TCP',
            targetPort: 'ldaps-port',
          },
        ],
        selector: config.labels,
        sessionAffinity: 'None',
        type: 'ClusterIP',
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
            name: 'ldap-port',
            port: 389,
            targetPort: 'ldap-port',
          },
        ],
        selector: config.labels,
        sessionAffinity: 'None',
        type: 'ClusterIP',
      },
    },

    statefulset: kube.StatefulSet(componentName) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      spec: {
        replicas: config.replicas,
        selector: {
          matchLabels: config.labels,
        },
        serviceName: '%s-headless' % [componentName],
        template: {
          metadata+: {
            annotations+: {
              // configmaps ldap init and schemas only used at bootstrap, so not added here
              'checksum/env': std.md5(std.toString(this.configmap)),
              'checksum/credentials': std.md5(std.toString(this.secret)),
            },
            labels: config.labels,
          },
          spec: {
            affinity: {
              nodeAffinity: null,
              podAffinity: null,
              podAntiAffinity: {
                preferredDuringSchedulingIgnoredDuringExecution: [
                  {
                    podAffinityTerm: {
                      labelSelector: {
                        matchLabels: config.labels,
                      },
                      namespaces: [
                        namespace,
                      ],
                      topologyKey: 'kubernetes.io/hostname',
                    },
                    weight: 1,
                  },
                ],
              },
            },
            containers: [
              {
                args: [],
                env: [
                  {
                    name: 'POD_NAME',
                    valueFrom: {
                      fieldRef: {
                        apiVersion: 'v1',
                        fieldPath: 'metadata.name',
                      },
                    },
                  },
                  {
                    name: 'LDAP_TLS_CERT_FILE',
                    value: '/ssl/server.crt',
                  },
                  {
                    name: 'LDAP_TLS_KEY_FILE',
                    value: '/ssl/server.key',
                  },
                  {
                    name: 'LDAP_TLS_CA_FILE',
                    value: '/ssl/ca.crt',
                  },
                ],
                envFrom: [
                  {
                    configMapRef: {
                      name: componentName,
                    },
                  },
                  {
                    secretRef: {
                      name: componentName,
                    },
                  },
                ],
                image: helper.getImage(config.imageRegistry, config.imageRef, config.imageVersion),
                imagePullPolicy: 'Always',
                livenessProbe: {
                  failureThreshold: 10,
                  initialDelaySeconds: 20,
                  periodSeconds: 10,
                  successThreshold: 1,
                  tcpSocket: {
                    port: 'ldap-port',
                  },
                  timeoutSeconds: 1,
                },
                name: componentName,
                ports: [
                  {
                    containerPort: 1389,
                    name: 'ldap-port',
                  },
                  {
                    containerPort: 1636,
                    name: 'ldaps-port',
                  },
                ],
                readinessProbe: {
                  failureThreshold: 10,
                  initialDelaySeconds: 20,
                  periodSeconds: 10,
                  successThreshold: 1,
                  tcpSocket: {
                    port: 'ldap-port',
                  },
                  timeoutSeconds: 1,
                },
                resources: {
                  limits: {},
                  requests: {},
                },
                securityContext: {
                  runAsNonRoot: true,
                  runAsUser: 1001,
                },
                volumeMounts: [
                  {
                    mountPath: '/bitnami/openldap',
                    name: 'data',
                  },
                  {
                    mountPath: '/ssl/server.crt',
                    name: 'certificate',
                    subPath: 'tls.crt',
                  },
                  {
                    mountPath: '/ssl/server.key',
                    name: 'certificate',
                    subPath: 'tls.key',
                  },
                  {
                    mountPath: '/ssl/ca.crt',
                    name: 'certificate',
                    subPath: 'ca.crt',
                  },
                  {
                    mountPath: '/config/add.ldif',
                    name: '%s-config-init' % [componentName],
                    subPath: 'add.ldif',
                  },
                  {
                    mountPath: '/config/mod.ldif',
                    name: '%s-config-init' % [componentName],
                    subPath: 'mod.ldif',
                  },
                  {
                    mountPath: '/docker-entrypoint-initdb.d/config-apply.sh',
                    name: '%s-config-init' % [componentName],
                    subPath: 'config-apply.sh',
                  },
                  {
                    mountPath: '/ldifs/init.ldif',
                    name: '%s-config-init' % [componentName],
                    subPath: 'init.ldif',
                  },
                ] + [
                  {
                    mountPath: '/opt/bitnami/openldap/etc/schema/%s.ldif' % [schema],
                    name: '%s-schemas' % [componentName],
                    subPath: '%s.ldif' % [schema],
                  }
                  for schema in config.ldapIncludeManagedSchemas
                ],
              },
            ],
            initContainers: null,
            nodeSelector: {
              'topology.kubernetes.io/region': region,
            },
            securityContext: {
              fsGroup: 1001,
            },
            volumes: [
              {
                name: 'certificate',
                secret: {
                  secretName: '%s-server-cert' % [componentName],
                },
              },
              {
                configMap: {
                  name: '%s-config-init' % [componentName],
                  defaultMode: std.parseOctal('0755'),
                },
                name: '%s-config-init' % [componentName],
              },
              {
                configMap: {
                  name: '%s-schemas' % [componentName],
                },
                name: '%s-schemas' % [componentName],
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
              name: 'data',
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

    configmapldapinit: kube.ConfigMap('%s-config-init' % [componentName]) {
      metadata+: {
        namespace: namespace,
        labels: config.labels,
      },
      data: {
        'init.ldif': helper.manifestLdif(ldapBootstrap),
        'add.ldif': helper.manifestLdif(ldapConfig.add),
        'mod.ldif': helper.manifestLdif(ldapConfig.modify),
        'config-apply.sh': |||
          #!/bin/bash
          export LDAPTLS_REQCERT=never
          source /opt/bitnami/scripts/libopenldap.sh
          ldap_start_bg
          sleep 5
          ldapmodify -a -Y EXTERNAL -H "ldapi:///" -f /config/add.ldif
          sleep 2
          ldapmodify -Y EXTERNAL -H "ldapi:///" -f /config/mod.ldif
          sleep 5
          ldap_stop
        |||,
      },
    },

    configmapschemas: kube.ConfigMap('%s-schemas' % [componentName]) {
      metadata+: {
        namespace: namespace,
        labels: config.labels,
      },
      data: {
        [schemaDefinitions[schema].file]: schemaDefinitions[schema].content
        for schema in config.ldapIncludeManagedSchemas
      },
    },

    secret: kube.Secret(componentName) {
      metadata+: {
        namespace: namespace,
        labels: config.labels,
      },
      stringData: {
        LDAP_ADMIN_PASSWORD: config.ldapAdminPassword,
        LDAP_ADMIN_USERNAME: config.ldapAdminUsername,
        LDAP_CONFIG_ADMIN_PASSWORD: config.ldapConfigAdminPassword,
        LDAP_CONFIG_ADMIN_USERNAME: config.ldapConfigAdminUsername,
      },
    },
  }),
}
