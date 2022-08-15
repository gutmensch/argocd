local helper = import '../../../lib/helper.libsonnet';
local kube = import '../../../lib/kube.libsonnet';
local ca = import '../../../lib/localca.libsonnet';
local configDefinitions = import 'ldif/config.libsonnet';
local initDefinitions = import 'ldif/init.libsonnet';
local schemaDefinitions = import 'schema/definitions.libsonnet';
local secrets = import 'secrets.libsonnet';

{
  _openldapLabels:: {
    'app.kubernetes.io/component': 'openldap',
  },

  generate(
    name,
    namespace,
    tenant,
    version='2.6.3',
    root='',
    initModules=['memberof'],
    initSchemas=['rfc2307bis', 'virtualmail', 'nextcloud'],
    providedSchemas=['cosine', 'inetorgperson'],
    initMailDomains=[],
    storageClass='fast',
    replicas=1,
    labels={},
  ):: {

    assert root != '' : error 'parameter root needs to be set, e.g. root="o=auth,dc=local"',

    local this = self,

    local openldapLabels = labels + $._openldapLabels,

    local ldapConfig = configDefinitions {
      ldapModules: initModules,
    },

    local ldapBootstrap = initDefinitions {
      ldapBase: root,
      ldapMailDomains: initMailDomains,
    },

    local certCRDs = ca.serverCert(
      name=name,
      namespace=namespace,
      createIssuer=true,
      dnsNames=['%s.%s.svc.cluster.local' % [name, namespace]],
      labels=openldapLabels,
    ),
    localrootcacert: certCRDs.localrootcacert,
    localcertissuer: certCRDs.localcertissuer,
    servercert: certCRDs.localservercert,

    configmapenv: kube.ConfigMap(name) {
      metadata+: {
        name: '%s-env' % [name],
        namespace: namespace,
        labels+: openldapLabels,
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
        // unused, we mount schemas in directory and ref as extra
        LDAP_CUSTOM_SCHEMA_FILE: '/schema/custom.ldif',
        LDAP_ENABLE_TLS: 'yes',
        LDAP_EXTRA_SCHEMAS: std.join(',', providedSchemas + initSchemas),
        LDAP_GROUP: 'Readers',
        LDAP_LDAPS_PORT_NUMBER: '1636',
        LDAP_LOGLEVEL: '64',
        LDAP_PASSWORDS: '',
        LDAP_PORT_NUMBER: '1389',
        LDAP_ROOT: root,
        LDAP_ULIMIT_NOFILES: '1024',
        LDAP_USERS: '',
        LDAP_USER_DC: 'Users',
      },
    },

    servicecluster: kube.Service(name) {
      metadata+: {
        name: name,
        namespace: namespace,
        labels+: openldapLabels,
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
        selector: helper.removeVersion(openldapLabels),
        sessionAffinity: 'None',
        type: 'ClusterIP',
      },
    },

    serviceheadless: kube.Service('%s-headless' % [name]) {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: '%s-headless' % [name],
        namespace: namespace,
        labels+: openldapLabels,
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
        selector: helper.removeVersion(openldapLabels),
        sessionAffinity: 'None',
        type: 'ClusterIP',
      },
    },

    statefulset: kube.StatefulSet(name) {
      metadata+: {
        name: name,
        namespace: namespace,
      },
      spec: {
        replicas: replicas,
        selector: {
          matchLabels: helper.removeVersion(openldapLabels),
        },
        serviceName: '%s-headless' % [name],
        template: {
          metadata+: {
            annotations+: {
              'checksum/configmapenv': std.md5(std.toString(this.configmapenv)),
            },
            labels: openldapLabels,
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
                        matchLabels: helper.removeVersion(openldapLabels),
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
                      name: 'ldap-env',
                    },
                  },
                  {
                    secretRef: {
                      name: 'ldap',
                    },
                  },
                ],
                image: 'registry.lan:5000/bitnami/openldap:%s' % [version],
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
                name: 'openldap-stack-ha',
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
                    name: '%s-config-ldif' % [name],
                    subPath: 'add.ldif',
                  },
                  {
                    mountPath: '/config/mod.ldif',
                    name: '%s-config-ldif' % [name],
                    subPath: 'mod.ldif',
                  },
                  {
                    mountPath: '/docker-entrypoint-initdb.d/config-apply.sh',
                    name: '%s-config-ldif' % [name],
                    subPath: 'config-apply.sh',
                  },
                  {
                    mountPath: '/ldifs/init.ldif',
                    name: '%s-init-ldif' % [name],
                    subPath: 'init.ldif',
                  },
                ] + [
                  {
                    mountPath: '/opt/bitnami/openldap/etc/schema/%s.ldif' % [schema],
                    name: 'ldap-schema-%s' % [schema],
                    subPath: '%s.ldif' % [schema],
                  }
                  for schema in initSchemas
                ],
              },
            ],
            initContainers: null,
            nodeSelector: {
              'topology.kubernetes.io/region': 'helsinki',
            },
            securityContext: {
              fsGroup: 1001,
            },
            volumes: [
              {
                name: 'certificate',
                secret: {
                  secretName: 'ldap-server-cert',
                },
              },
              {
                configMap: {
                  name: '%s-config-ldif' % [name],
                  // =0755
                  defaultMode: 493,
                },
                name: '%s-config-ldif' % [name],
              },
              {
                configMap: {
                  name: '%s-init-ldif' % [name],
                },
                name: '%s-init-ldif' % [name],
              },
            ] + [
              {
                configMap: {
                  name: 'ldap-schema-%s' % [schema],
                },
                name: 'ldap-schema-%s' % [schema],
              }
              for schema in initSchemas
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
                  storage: '8Gi',
                },
              },
              storageClassName: storageClass,
            },
          },
        ],
      },
    },

    configmapconfig: kube.ConfigMap('%s-config-ldif' % [name]) {
      metadata+: {
        namespace: namespace,
        labels: openldapLabels,
      },
      data: {
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

    configmapldapinit: kube.ConfigMap('%s-init-ldif' % [name]) {
      metadata+: {
        namespace: namespace,
        labels: openldapLabels,
      },
      data: {
        'init.ldif': helper.manifestLdif(ldapBootstrap),
      },
    },

  } + {
    local openldapLabels = labels {
      'app.kubernetes.io/component': 'openldap',
    },

    ['ldap-schema-%s' % [schema]]: kube.ConfigMap('ldap-schema-%s' % [schema]) {
      metadata+: {
        namespace: namespace,
        labels: openldapLabels,
      },
      data: {
        [schemaDefinitions[schema].file]: schemaDefinitions[schema].content,
      },
    }
    for schema in initSchemas

  } + secrets.generate(labels + $._openldapLabels)[tenant],
}
