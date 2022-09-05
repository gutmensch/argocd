local helper = import '../../../lib/helper.libsonnet';
local kube = import '../../../lib/kube.libsonnet';
local mxConfig = import 'config.libsonnet';

{
  generate(
    name,
    namespace,
    version='11.1.0',
    fqdn='',
    ldapServer='',
    ldapBase='',
    postmasterAddress='',
    trustedPublicNetworks=[],
    storageClass='fast',
    replicas=1,
  ):: {

    assert fqdn != '' : error 'parameter fqdn needs to be set, e.g. fqdn="mx.local"',
    assert postmasterAddress != '' : error 'parameter postmasterAddress needs to be set"',
    assert ldapServer != '' && ldapUserBase != '' : error 'parameter ldapServer and ldapBase need to be set',

    local res = self,

    local defaultLabels = {
      'app.kubernetes.io/name': name,
      'app.kubernetes.io/version': version,
      'app.kubernetes.io/component': 'openldap',
      'app.kubernetes.io/managed-by': 'ArgoCD',
    },

    local config = mxConfig {
      postmasterAddress: postmasterAddress,
      trustedPublicNetworks: [],
    },

    local configFiles = ['foo'],

    configmapenv: kube.ConfigMap(name) {
      metadata+: {
        name: '%s-env' % [name],
        namespace: namespace,
        labels+: defaultLabels,
      },
      data: {
        ENABLE_MANAGESIEVE: 1,
        ENABLE_CLAMAV: 1,
        ENABLE_POSTGREY: 1,
        POSTGREY_AUTO_WHITELIST_CLIENTS: 3,
        POSTGREY_TEXT: '"Welcome\\ stranger,\\ you\\ have\\ been\\ greylisted.\\ Please\\ retry\\ in\\ a\\ few\\ minutes"',
        ENABLE_FETCHMAIL: 1,
        FETCHMAIL_PARALLEL: 1,
        ENABLE_SPAMASSASSIN: 1,
        SA_SPAM_SUBJECT: '[SPAM] ',
        SA_TAG: '-100000.0',
        SA_TAG2: '4.5',
        SA_KILL: '100000.0',
        // 100M
        POSTFIX_MESSAGE_SIZE_LIMIT: 100000000,
        // 25G
        POSTFIX_MAILBOX_SIZE_LIMIT: 25000000000,
        ENABLE_QUOTAS: 1,
        SPAMASSASSIN_SPAM_TO_INBOX: 1,
        MOVE_SPAM_TO_JUNK: 1,
        SSL_TYPE: 'letsencrypt',
        ONE_DIR: 1,
        DMS_DEBUG: 1,
        POSTMASTER_ADDRESS: 'postmaster@bln.space',
        // --- ldap related ---
        ENABLE_LDAP: 1,
        LDAP_START_TLS: 'yes',
        LDAP_SERVER_HOST: ldapServer,
        LDAP_SEARCH_BASE: 'ou=People,%s' % [ldapBase],
        LDAP_QUERY_FILTER_USER: '(&(mail=%s)(mailEnabled=TRUE))',
        LDAP_QUERY_FILTER_GROUP: '(&(mailGroupMember=%s)(mailEnabled=TRUE))',
        LDAP_QUERY_FILTER_ALIAS: '(|(&(mailAlias=%s)(objectClass=PostfixBookMailForward))(&(mailAlias=%s)(objectClass=PostfixBookMailAccount)(mailEnabled=TRUE)))',
        LDAP_QUERY_FILTER_DOMAIN: '(|(&(mail=*@%s)(objectClass=PostfixBookMailAccount)(mailEnabled=TRUE))(&(mailGroupMember=*@%s)(objectClass=PostfixBookMailAccount)(mailEnabled=TRUE))(&(mailalias=*@%s)(objectClass=PostfixBookMailForward)))',
        DOVECOT_TLS: 'yes',
        DOVECOT_PASS_FILTER: '(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%n))',
        DOVECOT_USER_FILTER: '(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%n))',
        ENABLE_SASLAUTHD: 1,
        SASLAUTHD_MECHANISMS: 'ldap',
        SASLAUTHD_LDAP_SERVER: 'ldap',
        SASLAUTHD_LDAP_SEARCH_BASE: 'ou=People,%s' % [ldapBase],
        SASLAUTHD_LDAP_FILTER: '(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%U))',
      },
    },

    configmapconf: kube.ConfigMap('mail-config') {
      metadata+: {
        name: '%s-conf' % [name],
        namespace: namespace,
        labels+: defaultLabels,
      },
      data: {
        'amavis.cf': |||
          @mynetworks = qw ( 176.9.37.138/32 [2a01:4f8:161:3442::]/64 127.0.0.0/8 [::1]/128 [fe80::]/64 [fd00:dead:beef::]/48 10.0.0.0/8 192.168.0.0/16 );
          $clean_quarantine_to = "postmaster\@schumann.link";
          $virus_quarantine_to = "postmaster\@schumann.link";
          $banned_quarantine_to = "postmaster\@schumann.link";
          $bad_header_quarantine_to = "postmaster\@schumann.link";
          $spam_quarantine_to = "postmaster\@schumann.link";
          $policy_bank{'MYNETS'} = {  # clients in @mynetworks
            bypass_spam_checks_maps   => [1],  # don't spam-check internal mail
            bypass_banned_checks_maps => [1],  # don't banned-check internal mail
            bypass_header_checks_maps => [1],  # don't header-check internal mail
          };
        |||,

        'dovecot.cf': |||
          lmtp_save_to_detail_mailbox = yes
          postmaster_address = postmaster@%d
          quota_full_tempfail = yes
        |||,


      },
    },

    servicecluster: kube.Service(name) {
      metadata+: {
        name: name,
        namespace: namespace,
        labels+: defaultLabels,
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
        selector: helper.removeVersion(defaultLabels),
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
          matchLabels: helper.removeVersion(defaultLabels),
        },
        template: {
          metadata+: {
            annotations+: {
              'checksum/configmapenv': std.md5(std.toString(res.configmapenv)),
            },
            labels: defaultLabels,
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
                        matchLabels: helper.removeVersion(defaultLabels),
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
                    name: 'TLS_LEVEL',
                    value: 'modern',
                  },
                  {
                    name: 'SSL_TYPE',
                    value: 'manual',
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
                      name: name,
                    },
                  },
                  {
                    secretRef: {
                      name: 'mxldap',
                    },
                  },
                ],
                image: 'registry.lan:5000/mailserver/docker-mailserver:%s' % [version],
                imagePullPolicy: 'Always',
                livenessProbe: {
                  failureThreshold: 10,
                  initialDelaySeconds: 30,
                  periodSeconds: 10,
                  successThreshold: 1,
                  tcpSocket: {
                    port: 'smtp-port',
                  },
                  timeoutSeconds: 1,
                },
                name: 'mail',
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
                    containerPort: 143,
                    name: 'submission-port',
                  },
                ],
                readinessProbe: {
                  failureThreshold: 10,
                  initialDelaySeconds: 30,
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
                  //runAsNonRoot: true,
                  //runAsUser: 1001,
                },
                volumeMounts: [
                  {
                    mountPath: '/var/mail',
                    name: 'mail-data',
                  },
                  {
                    mountPath: '/var/mail-state',
                    name: 'mail-state',
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
                    mountPath: '/tmp/docker-mailserver/%s' % [mailConfig],
                    name: '%s-config' % [name],
                    subPath: mailConfig,
                  }
                  for mailConfig in configFiles
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
                  secretName: 'mx-server-cert',
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
            ],
            //+ [
            //  {
            //    configMap: {
            //      name: 'ldap-schema-%s' % [schema],
            //    },
            //    name: 'ldap-schema-%s' % [schema],
            //  }
            //  for schema in initSchemas
            //],
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
        labels: defaultLabels,
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
        labels: defaultLabels,
      },
      data: {
        'init.ldif': helper.manifestLdif(ldapBootstrap),
      },
    },
  } + {

    local res = self,

    local defaultLabels = {
      'app.kubernetes.io/name': name,
      'app.kubernetes.io/version': version,
      'app.kubernetes.io/component': 'auth',
      'app.kubernetes.io/managed-by': 'ArgoCD',
    },

    ['ldap-schema-%s' % [schema]]: kube.ConfigMap('ldap-schema-%s' % [schema]) {
      metadata+: {
        namespace: namespace,
        labels: defaultLabels,
      },
      data: {
        [schemaDefinitions[schema].file]: schemaDefinitions[schema].content,
      },
    }
    for schema in initSchemas
  },
}
