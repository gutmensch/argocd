local helper = import '../../helper.libsonnet';
local kube = import '../../kube.libsonnet';
local mailerConfigFileDefinitions = import 'config.libsonnet';
local componentName = 'mailserver';
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
      local this = self,
      imageRegistry: '',
      imageRef: 'mailserver/docker-mailserver',
      imageVersion: '11.1.0',
      replicas: 1,
      storageClass: 'standard',
      mailStorageSize: '5Gi',
      stateStorageSize: '1Gi',
      certIssuer: 'letsencrypt-prod',
      publicFQDN: '',
      postmasterAddress: '',
      clamavEnable: true,
      spamAssassinEnable: true,
      postgreyEnable: true,
      fail2banEnable: false,
      trustedPublicNetworks: [],
      principalMailDomain: '',
      ldapEnable: false,
      ldapHost: '',
      ldapBaseDN: '',
      ldapServiceAccountBindDN: 'uid=mx,ou=ServiceAccount,%s' % [this.ldapBaseDN],
      ldapServiceAccountPassword: 'changeme',
      opendkimTrustedHosts: ['127.0.0.1', 'localhost'],
    }
  ):: helper.uniquify({

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    assert config.publicFQDN != '' : error 'publicFQDN must be provided',
    assert config.principalMailDomain != '' : error 'principalMailDomain must be provided',
    assert (!config.ldapEnable) || (config.ldapEnable && config.ldapServiceAccountPassword != 'changeme') : error '"changeme" is an invalid bind password when ldap is enabled',
    assert (!config.ldapEnable) || (config.ldapEnable && config.ldapHost != '') : error 'ldap host cannot be empty when ldap is enabled',
    assert (!config.ldapEnable) || (config.ldapEnable && config.ldapBaseDN != '') : error 'ldap base dn cannot be empty when ldap is enabled',

    local appName = name,

    local mailserverConfig = mailerConfigFileDefinitions {
      mailerConfig+: config,
    },

    configmap: kube.ConfigMap(componentName) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      data: std.prune({
        ENABLE_AMAVIS: '1',
        ENABLE_SPAMASSASSIN: helper.boolToStrInt(config.spamAssassinEnable),
        ENABLE_CLAMAV: helper.boolToStrInt(config.clamavEnable),
        ENABLE_FAIL2BAN: helper.boolToStrInt(config.fail2banEnable),
        ENABLE_POSTGREY: helper.boolToStrInt(config.postgreyEnable),
        ENABLE_LDAP: helper.boolToStrInt(config.ldapEnable),
        // XXX: OIDC could be later option
        // >>> Postfix LDAP Integration
        ACCOUNT_PROVISIONER: if config.ldapEnable then 'LDAP' else 'FILE',
        // https://github.com/docker-mailserver/docker-mailserver/blob/efed7d9e447a64f67dee06decec087999b92ee07/target/scripts/startup/setup-stack.sh#L319
        LDAP_SERVER_HOST: std.get(config, 'ldapHost'),
        // XXX: search base is not configurable per filter, so we need to use the root here
        LDAP_SEARCH_BASE: std.get(config, 'ldapBaseDN'),
        LDAP_START_TLS: 'yes',
        LDAPTLS_REQCERT: 'never',
        LDAP_QUERY_FILTER_DOMAIN: '(&(ObjectClass=dNSDomain)(dc=%s))',
        LDAP_QUERY_FILTER_USER: '(&(objectClass=mailUser)(mailEnabled=TRUE)(mailDrop=%s))',
        LDAP_QUERY_FILTER_ALIAS: '(&(objectClass=mailUser)(mailEnabled=TRUE)(mailAlias=%s))',
        LDAP_QUERY_FILTER_GROUP: '(&(objectClass=mailUser)(mailEnabled=TRUE)(mailGroupMember=%s))',
        LDAP_QUERY_FILTER_SENDERS: '(&(objectClass=mailUser)(mailEnabled=TRUE)(|(mailDrop=%s)(mailAlias=%s)))',
        SPOOF_PROTECTION: '1',
        // <<< Postfix LDAP Integration
        // >>> Dovecot LDAP Integration
        // https://github.com/docker-mailserver/docker-mailserver/blob/efed7d9e447a64f67dee06decec087999b92ee07/target/scripts/startup/setup-stack.sh#L331
        DOVECOT_USER_FILTER: '(&(objectClass=mailUser)(mailDrop=%u))',
        DOVECOT_PASS_ATTRS: 'uid=user,userPassword=password',
        DOVECOT_USER_ATTRS: '=home=/var/mail/%{ldap:uid},=mail=maildir:~/Maildir,uidNumber=mailUidNumber,gidNumber=mailGidNumber',
        // <<< Dovecot LDAP Integration
        // >>> SASL LDAP Authentication
        ENABLE_SASLAUTHD: helper.boolToStrInt(config.ldapEnable),
        SASLAUTHD_MECHANISMS: 'ldap',
        SASLAUTHD_LDAP_FILTER: '(&(mailEnabled=TRUE)(mailDrop=%U@' + config.principalMailDomain + ')(objectClass=inetOrgPerson))',
        // <<< SASL LDAP Authentication
        OPENDKIM_TRUSTED_HOSTS: std.join(' ', config.opendkimTrustedHosts),
        ONE_DIR: '1',
        SSL_TYPE: 'manual',
        PERMIT_DOCKER: 'none',
      }),
    },

    servicecluster: kube.Service(componentName) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      spec: {
        ports: [
          {
            name: 'smtp-port',
            nodePort: null,
            port: 25,
            protocol: 'TCP',
            targetPort: 'smtp-port',
          },
          {
            name: 'imap-port',
            nodePort: null,
            port: 143,
            protocol: 'TCP',
            targetPort: 'imap-port',
          },
          {
            name: 'submission-port',
            nodePort: null,
            port: 587,
            protocol: 'TCP',
            targetPort: 'submission-port',
          },
        ],
        selector: config.labels,
        sessionAffinity: 'None',
        type: 'ClusterIP',
      },
    },

    certificate: kube._Object('cert-manager.io/v1', 'Certificate', componentName) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      spec: {
        secretName: '%s-cert' % [componentName],
        issuerRef: {
          name: config.certIssuer,
          kind: 'ClusterIssuer',
        },
        dnsNames: [
          config.publicFQDN,
        ],
      },
    },

    statefulset: kube.StatefulSet(componentName) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      spec: {
        serviceName: componentName,
        replicas: config.replicas,
        selector: {
          matchLabels: config.labels,
        },
        template: {
          metadata+: {
            annotations+: {
              'checksum/env': std.md5(std.toString(this.configmap)),
              'checksum/files': std.md5(std.toString(this.configmapfiles)),
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
                    name: 'SSL_CERT_PATH',
                    value: '/ssl/server.crt',
                  },
                  {
                    name: 'SSL_KEY_PATH',
                    value: '/ssl/server.key',
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
                image: '%s:%s' % [if config.imageRegistry != '' then std.join('/', [config.imageRegistry, config.imageRef]) else config.imageRef, config.imageVersion],
                imagePullPolicy: 'Always',
                livenessProbe: {
                  failureThreshold: 10,
                  initialDelaySeconds: 20,
                  periodSeconds: 10,
                  successThreshold: 1,
                  tcpSocket: {
                    port: 'smtp-port',
                  },
                  timeoutSeconds: 2,
                },
                name: componentName,
                ports: [
                  {
                    containerPort: 25,
                    name: 'smtp-port',
                  },
                  {
                    containerPort: 143,
                    name: 'imap-port',
                  },
                  {
                    containerPort: 587,
                    name: 'submission-port',
                  },
                ],
                readinessProbe: {
                  failureThreshold: 10,
                  initialDelaySeconds: 20,
                  periodSeconds: 10,
                  successThreshold: 1,
                  tcpSocket: {
                    port: 'smtp-port',
                  },
                  timeoutSeconds: 1,
                },
                resources: {
                  limits: {},
                  requests: {},
                },
                securityContext: {
                  runAsNonRoot: false,
                  // runAsNonRoot: true,
                  // runAsUser: 1001,
                },
                volumeMounts: [
                  {
                    mountPath: '/var/mail-state',
                    name: 'state',
                  },
                  {
                    mountPath: '/var/mail',
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
                ] + [
                  {
                    mountPath: '/tmp/docker-mailserver/%s' % [mailserverConfigFile],
                    name: '%s-cfg' % [componentName],
                    subPath: '%s' % [mailserverConfigFile],
                  }
                  for mailserverConfigFile in std.objectFields(mailserverConfig)
                ],
              },
            ],
            initContainers: [],
            //  {
            //    name: 'prepare-mailserver-config',
            //    image: 'busybox:1.28',
            //    command: ['wget', '-O', '/work-dir/index.html', 'http://info.cern.ch'],
            //    volumeMounts: [
            //      {
            //        mountPath: '/config',
            //        name: 'config-dir',
            //      },
            //    ] + [
            //      {
            //        mountPath: '/tmp/config/%s' % [mailserverConfigFile],
            //        name: '%s-%s' % [componentName, std.strReplace(mailserverConfigFile, '.', '-')],
            //        subPath: '%s' % [mailserverConfigFile],
            //      }
            //      for mailserverConfigFile in std.objectFields(mailserverConfig)
            //    ],
            //  },
            //],
            nodeSelector: {
              'topology.kubernetes.io/region': region,
            },
            securityContext: {
              fsGroup: 5000,
            },
            volumes: [
              {
                name: 'certificate',
                secret: {
                  secretName: '%s-cert' % [componentName],
                },
              },
              {
                configMap: {
                  name: '%s-cfg' % [componentName],
                },
                name: '%s-cfg' % [componentName],
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
                  storage: config.mailStorageSize,
                },
              },
              storageClassName: config.storageClass,
            },
          },
          {
            metadata: {
              annotations: null,
              name: 'state',
            },
            spec: {
              accessModes: [
                'ReadWriteOnce',
              ],
              resources: {
                requests: {
                  storage: config.stateStorageSize,
                },
              },
              storageClassName: config.storageClass,
            },
          },

        ],
      },
    },

    secret: kube.Secret(componentName) {
      metadata+: {
        namespace: namespace,
        labels: config.labels,
      },
      stringData: {
        LDAP_BIND_DN: config.ldapServiceAccountBindDN,
        LDAP_BIND_PW: config.ldapServiceAccountPassword,
      },
    },

    configmapfiles: kube.ConfigMap('%s-cfg' % [componentName]) {
      metadata+: {
        namespace: namespace,
        labels: config.labels,
      },
      data: {
        [cfg]: mailerConfigFileDefinitions { mailerConfig+: config }[cfg]
        for cfg in std.objectFields(mailerConfigFileDefinitions { mailerConfig+: config })
      },
    },

  }),
}
