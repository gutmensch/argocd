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
      imageVersion: '11.2.0',
      replicas: 1,
      storageClass: 'standard',
      mailStorageSize: '5Gi',
      stateStorageSize: '1Gi',
      messageSizeLimitMB: 100,
      mailboxSizeLimitMB: 25000,
      certIssuer: 'letsencrypt-prod',
      publicFQDN: '',
      publicHostnames: [],
      trustedPublicNetworks: [],
      postmasterAddress: '',
      clamavEnable: true,
      spamAssassinEnable: true,
      spamAssassinSpamSubject: '[SPAM] ',
      spamAssassinTag: '-100000.0',
      spamAssassinTag2: '4.5',
      spamAssassinKill: '100000.0',
      spamAssassinSpamToInbox: '1',
      moveSpamToJunk: '1',
      dnsBlockListEnable: '1',
      postgreyEnable: true,
      fail2banEnable: false,
      saslAuthdEnable: false,
      accountProvisioner: 'FILE',
      ldapHost: '',
      ldapBaseDN: '',
      ldapServiceAccountBindDN: 'uid=mx,ou=ServiceAccount,%s' % [this.ldapBaseDN],
      ldapServiceAccountPassword: 'changeme',
      opendkimTrustedHosts: ['127.0.0.1', 'localhost'],
      extraAnnotations: {},
      fetchmailAccounts: [],
      reportEnable: false,
    }
  ):: helper.uniquify({

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    assert config.publicFQDN != '' : error 'publicFQDN must be provided',
    assert (config.accountProvisioner == 'FILE') || (config.accountProvisioner == 'LDAP' && config.ldapServiceAccountPassword != 'changeme') : error '"changeme" is an invalid bind password when ldap is enabled',
    assert (config.accountProvisioner == 'FILE') || (config.accountProvisioner == 'LDAP' && config.ldapHost != '') : error 'ldap host cannot be empty when ldap is enabled',
    assert (config.accountProvisioner == 'FILE') || (config.accountProvisioner == 'LDAP' && config.ldapBaseDN != '') : error 'ldap base dn cannot be empty when ldap is enabled',

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
        LOG_LEVEL: 'info',
        POSTMASTER_ADDRESS: config.postmasterAddress,
        ENABLE_AMAVIS: '1',
        ENABLE_MANAGESIEVE: '1',
        ENABLE_SPAMASSASSIN: helper.boolToStrInt(config.spamAssassinEnable),
        SA_SPAM_SUBJECT: config.spamAssassinSpamSubject,
        SA_TAG: config.spamAssassinTag,
        SA_TAG2: config.spamAssassinTag2,
        SA_KILL: config.spamAssassinKill,
        SPAMASSASSIN_SPAM_TO_INBOX: config.spamAssassinSpamToInbox,
        MOVE_SPAM_TO_JUNK: config.moveSpamToJunk,
        ENABLE_DNSBL: config.dnsBlockListEnable,
        ENABLE_CLAMAV: helper.boolToStrInt(config.clamavEnable),
        ENABLE_FAIL2BAN: helper.boolToStrInt(config.fail2banEnable),
        ENABLE_POSTGREY: helper.boolToStrInt(config.postgreyEnable),
        POSTGREY_AUTO_WHITELIST_CLIENTS: '3',
        ENABLE_QUOTAS: '1',
        POSTFIX_MESSAGE_SIZE_LIMIT: '%d' % [config.messageSizeLimitMB * 1000 * 1000],
        POSTFIX_MAILBOX_SIZE_LIMIT: '%d' % [config.mailboxSizeLimitMB * 1000 * 1000],
        ENABLE_FETCHMAIL: if std.length(config.fetchmailAccounts) > 0 then '1' else '0',
        FETCHMAIL_POLL: '300',
        FETCHMAIL_PARALLEL: '1',
        // XXX: OIDC could be later option
        // >>> Postfix LDAP Integration
        ACCOUNT_PROVISIONER: config.accountProvisioner,
        // https://github.com/docker-mailserver/docker-mailserver/blob/efed7d9e447a64f67dee06decec087999b92ee07/target/scripts/startup/setup-stack.sh#L319
        LDAP_SERVER_HOST: std.get(config, 'ldapHost'),
        // XXX: search base is not configurable per filter, so we need to use the root here
        LDAP_SEARCH_BASE: std.get(config, 'ldapBaseDN'),
        LDAP_START_TLS: 'yes',
        LDAPTLS_REQCERT: 'never',
        LDAP_QUERY_FILTER_DOMAIN: '(&(ObjectClass=dNSDomain)(dc=%s))',
        LDAP_QUERY_FILTER_USER: '(&(objectClass=mailUser)(mailEnabled=TRUE)(|(mailDrop=%s)(mailAlias=%s)))',
        LDAP_QUERY_FILTER_ALIAS: '(&(objectClass=mailUser)(mailEnabled=TRUE)(mailAlias=%s))',
        LDAP_QUERY_FILTER_GROUP: '(&(objectClass=mailUser)(mailEnabled=TRUE)(mailGroupMember=%s))',
        LDAP_QUERY_FILTER_SENDERS: '(&(objectClass=mailUser)(mailEnabled=TRUE)(|(mailDrop=%s)(mailAlias=%s)))',
        SPOOF_PROTECTION: '1',
        // <<< Postfix LDAP Integration
        // >>> Dovecot LDAP Integration
        // https://github.com/docker-mailserver/docker-mailserver/blob/efed7d9e447a64f67dee06decec087999b92ee07/target/scripts/startup/setup-stack.sh#L331
        // ref: https://github.com/dovecot/core/blob/main/doc/example-config/dovecot-ldap.conf.ext
        DOVECOT_DEFAULT_PASS_SCHEME: 'SHA512-CRYPT',
        DOVECOT_TLS: 'yes',
        DOVECOT_AUTH_BIND: 'yes',
        DOVECOT_USER_FILTER: '(&(objectClass=mailUser)(mailEnabled=TRUE)(uid=%n))',
        DOVECOT_PASS_FILTER: '(&(objectClass=mailUser)(mailEnabled=TRUE)(uid=%n))',
        DOVECOT_PASS_ATTRS: '=user=%{ldap:uid},=password=%{ldap:userPassword}',
        // 5000 is the docker image uid/gid, setting as fallback in case not recorded in LDAP
        DOVECOT_USER_ATTRS: '=home=/var/mail/%{ldap:uid},=mail=maildir:~/Maildir,=uid=%{ldap:mailUidNumber:5000},=gid=%{ldap:mailGidNumber:5000},=quota_rule=*:storage=%{ldap:mailQuota:10G}',
        // set to -1 for verbose ldap output
        DOVECOT_DEBUG_LEVEL: '0',
        // <<< Dovecot LDAP Integration
        // >>> SASL LDAP Authentication
        ENABLE_SASLAUTHD: helper.boolToStrInt(config.saslAuthdEnable),
        SASLAUTHD_MECHANISMS: 'ldap',
        SASLAUTHD_LDAP_FILTER: '(&(mailEnabled=TRUE)(mailDrop=%u)(objectClass=mailUser))',
        // <<< SASL LDAP Authentication
        OPENDKIM_TRUSTED_HOSTS: std.join(' ', config.opendkimTrustedHosts),
        ONE_DIR: '1',
        SSL_TYPE: 'manual',
        PERMIT_DOCKER: 'none',
        [if config.reportEnable then 'PFLOGSUMM_TRIGGER']: 'daily_cron',
        [if config.reportEnable then 'LOGWATCH_INTERVAL']: 'daily',
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
        ] + config.publicHostnames,
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
              'checksum/secretfiles': std.md5(std.toString(this.secretfiles)),
              'checksum/credentials': std.md5(std.toString(this.secret)),
            } + config.extraAnnotations,
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
                  initialDelaySeconds: 60,
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
                  initialDelaySeconds: 60,
                  periodSeconds: 10,
                  successThreshold: 1,
                  tcpSocket: {
                    port: 'smtp-port',
                  },
                  timeoutSeconds: 2,
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
                    name: 'config',
                    subPath: '%s' % [mailserverConfigFile],
                  }
                  for mailserverConfigFile in std.filter(function(key) !std.member(mailserverConfig.confidential, key), std.objectFields(mailserverConfig))
                ] + [
                  {
                    mountPath: '/tmp/docker-mailserver/%s' % [mailserverConfigFile],
                    name: 'confidential',
                    subPath: '%s' % [mailserverConfigFile],
                  }
                  for mailserverConfigFile in std.filter(function(key) std.member(mailserverConfig.confidential, key), std.objectFields(mailserverConfig))
                ],
              },
            ],
            initContainers: [],
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
                name: 'confidential',
                secret: {
                  secretName: '%s-files' % [componentName],
                },
              },
              {
                name: 'config',
                configMap: {
                  name: '%s-cfg' % [componentName],
                },
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

    secretfiles: kube.Secret('%s-files' % [componentName]) {
      metadata+: {
        namespace: namespace,
        labels: config.labels,
      },
      stringData: {
        [if std.member(mailerConfigFileDefinitions.confidential, cfg) then cfg]: mailerConfigFileDefinitions { mailerConfig+: config }[cfg]
        for cfg in std.objectFields(mailerConfigFileDefinitions { mailerConfig+: config })
      },
    },

    configmapfiles: kube.ConfigMap('%s-cfg' % [componentName]) {
      metadata+: {
        namespace: namespace,
        labels: config.labels,
      },
      data: {
        [if !std.member(mailerConfigFileDefinitions.confidential, cfg) then cfg]: mailerConfigFileDefinitions { mailerConfig+: config }[cfg]
        for cfg in std.objectFields(mailerConfigFileDefinitions { mailerConfig+: config })
      },
    },

  }),
}
