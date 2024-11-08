local helper = import '../../helper.libsonnet';
local kube = import '../../kube.libsonnet';
local ca = import '../../localca.libsonnet';
local policy = import 'templates/policy.libsonnet';

{
  generate(
    name, namespace, region, tenant, appConfig, defaultConfig={
      imageRegistryMirror: '',
      // imageRegistry: 'quay.io',
      imageRegistry: '',
      imageRef: 'minio/minio',
      imageVersion: 'RELEASE.2024-10-29T16-01-48Z',
      imageConsoleRef: 'minio/mc',
      imageConsoleVersion: 'RELEASE.2024-10-29T15-34-59Z',
      // imageKesRegistry: 'quay.io',
      imageKesRegistry: '',
      imageKesRef: 'minio/kes',
      imageKesVersion: '2024-10-31T07-42-41Z',
      rootUser: 'root',
      rootPassword: 'changeme',
      storageClass: 'default',
      storageSize: '20Gi',
      cacheStorageClass: 'default',
      cacheStorageSize: '1Gi',
      toolboxStorageClass: 'default',
      toolboxStorageSize: '1Gi',
      ldapServiceAccountBindDN: '',
      ldapServiceAccountPassword: '',
      ldapHost: '',
      ldapBaseDN: 'o=auth,dc=local',
      ldapUsernameFormat: 'uid=%%s,ou=People,%s,uid=%%s,ou=ServiceAccount,%s' % [self.ldapBaseDN, self.ldapBaseDN],
      ldapUserDNSearchFilter: '(&(objectclass=inetOrgPerson)(uid=%s))',
      ldapGroupSearchFilter: '(&(objectclass=groupOfNames)(|(member=uid=%%s,ou=People,%s)(member=uid=%%s,ou=ServiceAccount,%s)))' % [self.ldapBaseDN, self.ldapBaseDN],
      ldapAdminGroupDN: 'cn=MinIOAdmin,ou=Group,%s' % [self.ldapBaseDN],
      ldapTlsSkipVerify: true,
      ldapStartTls: true,
      replicas: 1,
      prometheusAuthType: 'public',
      buckets: {
        // example: { locks: false, versioning: true, quota: '10Gi' },
      },
      policies: {
        // examplerw: { bucket: 'example', actions: ['list', 'write', 'read', 'delete'], group: 'cn=BackupRW,ou=Groups,o=auth,dc=local' },
      },
      consoleIngress: null,
      consoleCertIssuer: 'letsencrypt-prod',
      kesRootCAPath: '/opt/certs/ca.crt',
      kesServerKeyPath: '/opt/certs/kes-server.key',
      kesServerCertPath: '/opt/certs/kes-server.cert',
      minioKesClientCertPath: '/opt/certs/minio-kes-client.cert',
      minioKesClientKeyPath: '/opt/certs/minio-kes-client.key',
      kesAuth: 'on',
      kesAdminOperations: true,
    }
  ):: {

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    assert config.rootPassword != 'changeme' : error '"changeme" is an invalid password',
    assert config.ldapHost != '' : error 'ldapHost must be set',

    local appName = name,
    local componentName = 'minio',
    local ingressRestricted = true,
    local minioPodFQDN = '%s-0.%s-headless.%s.svc.cluster.local' % [componentName, componentName, namespace],

    local kesRoot = ca.serverCert(
      name='kes-server',
      namespace=namespace,
      createIssuer=true,
      dnsNames=['kes-server.local', minioPodFQDN],
      labels=config.labels,
    ),
    kesRootCA: kesRoot.localrootcacert,
    kesRootCAIssuer: kesRoot.localcertissuer,

    kesServerCert: std.prune(kesRoot.localservercert),

    minioKesClientCert: std.prune(ca.serverCert(
      name='minio-kes-client',
      namespace=namespace,
      createIssuer=false,
      dnsNames=['minio-kes-client.local'],
      labels=config.labels,
    ).localservercert),

    service_certificate: kube._Object('cert-manager.io/v1', 'Certificate', '%s-svc-cert' % [componentName]) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      spec: {
        secretName: '%s-svc-cert' % [componentName],
        issuerRef: {
          name: config.servicePublicCertIssuer,
          kind: 'ClusterIssuer',
        },
        dnsNames: [
          std.join('.', [componentName, namespace, config.servicePublicDomain]),
        ],
      },
    },

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
          'if ! ${MC} idp ldap policy entities myminio/ --policy consoleAdmin | /toolbox/grep -q %s; then' % [config.ldapAdminGroupDN],
          '  echo adding ldapGroup:%s to minioPolicy:%s via idp ldap' % [config.ldapAdminGroupDN, 'consoleAdmin'],
          '  ${MC} idp ldap policy attach myminio/ consoleAdmin --group %s' % [config.ldapAdminGroupDN],
          'else',
          '  echo ldap group %s is already attached to consoleAdmin policy' % [config.ldapAdminGroupDN],
          'fi',
        ] + this.policies),
      } + this.policyFiles,
      metadata+: {
        labels+: config.labels,
        annotations+: {
          'argocd.argoproj.io/sync-options': 'Replace=true',
        },
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
        MINIO_KMS_KES_ENDPOINT: 'https://kes-server.local:7373',
        MINIO_KMS_KES_CERT_FILE: config.minioKesClientCertPath,
        MINIO_KMS_KES_KEY_FILE: config.minioKesClientKeyPath,
        MINIO_KMS_KES_CAPATH: config.kesRootCAPath,
        MINIO_KMS_KES_KEY_NAME: '%s-default' % [namespace],
        MINIO_KMS_KES_ENCLAVE: namespace,
      },
      metadata+: {
        labels+: config.labels,
        namespace: namespace,
      },
    },

    secret_kes: kube.Secret('%s-kes-config' % [componentName]) {
      stringData: {
        'entrypoint.sh': std.join('\n', [
          '#!/bin/sh',
          'export PATH=/:$PATH',
          // the identity should stay the same even after cert rotation
          // ref. https://github.com/minio/kes/issues/184
          'export MINIO_CLIENT_IDENTITY_HASH=$(kes identity of %s | cut -d: -f2 | tr -d " " | tr -d "\n")' % [config.minioKesClientCertPath],
          'exec "$@"',
        ]),
        'config.yml': std.manifestYamlDoc({
          version: 'v1',
          admin: {
            identity: 'disabled',
          },
          log: {
            'error': 'on',
            audit: 'off',
          },
          tls: {
            key: config.kesServerKeyPath,
            cert: config.kesServerCertPath,
            ca: config.kesRootCAPath,
          },
          cache: {
            expiry: {
              any: '5m0s',
              unused: '20s',
              offline: '0s',
            },
          },
          api: {
            '/v1/status': {
              skip_auth: true,
              timeout: '15s',

            },
            '/v1/metrics': {
              skip_auth: true,
              timeout: '15s',
            },
            '/v1/ready': {
              skip_auth: true,
              timeout: '15s',
            },
          },
          policy: {
            minio: {
              allow: [
                '/v1/key/create/*',
                '/v1/key/generate/*',
                '/v1/key/decrypt/*',
                '/v1/key/bulk/decrypt',
                '/v1/key/list/*',
                '/v1/status',
                '/v1/metrics',
                '/v1/log/audit',
                '/v1/log/error',
              ] + if config.kesAdminOperations then [
                '/v1/key/delete/*',
              ] else [],
              identities: [
                '${MINIO_CLIENT_IDENTITY_HASH}',
              ],
            },
          },
          keystore: {
            gcp: {
              secretmanager: {
                // endpoint: 'https://secretmanager.googleapis.com:443',
                project_id: config.googleProjectID,
                credentials: {
                  client_email: config.googleServiceAccount.secretManager.client_email,
                  client_id: config.googleServiceAccount.secretManager.client_id,
                  private_key_id: config.googleServiceAccount.secretManager.private_key_id,
                  private_key: config.googleServiceAccount.secretManager.private_key,
                },
              },
            },
          },
        }),
      },
      metadata+: {
        labels+: config.labels,
        namespace: namespace,
      },
    },

    manage_bucket_script(bucket, obj)::
      local _versioning = if std.get(obj, 'versioning', false) then '--with-versioning' else '';
      local _locks = if std.get(obj, 'locks', false) then '--with-locks' else '';
      local infoMsg = 'echo ===== bucket configuration: %s =====' % [bucket];
      local createCmd = '${MC} mb --ignore-existing %s %s myminio/%s' % [_versioning, _locks, bucket];
      local createKeyCmd = if std.get(obj, 'encrypt', false) then
        '/toolbox/curl -s -XPOST -d "enclave=%s" https://${MINIO_ENDPOINT}:7373/v1/key/create/%s-%s --cert %s --key %s --cacert %s; echo' % [namespace, namespace, bucket, config.minioKesClientCertPath, config.minioKesClientKeyPath, config.kesRootCAPath] else '';
      local setKeyCmd = if std.get(obj, 'encrypt', false) then '${MC} encrypt set sse-kms %s-%s myminio/%s' % [namespace, bucket, bucket] else '';
      local setExpiryCmd = if std.get(obj, 'expiry', 0) > 0 then 'if ! ${MC} ilm ls myminio/%s 2>/dev/null; then echo "Adding lifecycle for bucket."; ${MC} ilm add myminio/%s --expiry-days %s; else echo "Lifecycle for bucket exists."; fi' % [bucket, bucket, obj.expiry] else '';
      local setQuotaCmd = if std.get(obj, 'quota', null) != null then 'echo "Setting quota of %s on bucket %s"; ${MC} quota set myminio/%s --size %s' % [obj.quota, bucket, bucket, obj.quota] else '';
      std.join('\n', std.prune([
        infoMsg,
        createCmd,
        createKeyCmd,
        setKeyCmd,
        setExpiryCmd,
        setQuotaCmd,
      ])),

    buckets:: [
      this.manage_bucket_script(b, config.buckets[b])
      for b in std.objectFields(config.buckets)
    ],

    job_buckets_toolbox: kube.PersistentVolumeClaim('job-buckets-toolbox') {
      metadata+: {
        labels: config.labels,
        namespace: namespace,
      },
      spec: {
        storageClassName: config.toolboxStorageClass,
        accessModes: ['ReadWriteOnce'],
        resources: {
          requests: {
            storage: config.toolboxStorageSize,
          },
        },
      },
    },

    job_buckets: kube.Job('%s-bucket-mgmt-%s' % [componentName, std.substr(std.md5(
      std.toString(this.buckets) + helper.getImage(config.imageRegistryMirror, config.imageRegistry, config.imageConsoleRef, config.imageConsoleVersion)
    ), 23, 8)]) {
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
            nodeSelector: {
              'topology.kubernetes.io/region': region,
            },
            containers: [
              {
                command: [
                  '/bin/sh',
                  '/config/add-custom-bucket.sh',
                ],
                env: [
                  {
                    name: 'MINIO_ENDPOINT',
                    value: minioPodFQDN,
                  },
                  {
                    name: 'MINIO_PORT',
                    value: '9000',
                  },
                ],
                envFrom: [
                  {
                    secretRef: {
                      name: this.secret.metadata.name,
                    },
                  },
                ],
                image: helper.getImage(config.imageRegistryMirror, config.imageRegistry, config.imageConsoleRef, config.imageConsoleVersion),
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
                  {
                    mountPath: config.minioKesClientCertPath,
                    name: this.minioKesClientCert.metadata.name,
                    subPath: 'tls.crt',
                  },
                  {
                    mountPath: config.minioKesClientKeyPath,
                    name: this.minioKesClientCert.metadata.name,
                    subPath: 'tls.key',
                  },
                  {
                    mountPath: config.kesRootCAPath,
                    name: this.minioKesClientCert.metadata.name,
                    subPath: 'ca.crt',
                  },
                  {
                    mountPath: '/toolbox',
                    name: 'toolbox',
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
                        name: this.configmap.metadata.name,
                      },
                    },
                  ],
                },
              },
              {
                name: this.minioKesClientCert.metadata.name,
                secret: {
                  secretName: this.minioKesClientCert.spec.secretName,
                },
              },
              {
                name: 'toolbox',
                persistentVolumeClaim: {
                  claimName: 'job-buckets-toolbox',
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

    job_policies_toolbox: kube.PersistentVolumeClaim('job-policies-toolbox') {
      metadata+: {
        labels: config.labels,
        namespace: namespace,
      },
      spec: {
        storageClassName: config.toolboxStorageClass,
        accessModes: ['ReadWriteOnce'],
        resources: {
          requests: {
            storage: config.toolboxStorageSize,
          },
        },
      },
    },

    job_policies: kube.Job('%s-policy-mgmt-%s' % [componentName, std.substr(std.md5(
      std.toString(this.policies) + helper.getImage(config.imageRegistryMirror, config.imageRegistry, config.imageConsoleRef, config.imageConsoleVersion)
    ), 23, 8)]) {
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
            nodeSelector: {
              'topology.kubernetes.io/region': region,
            },
            containers: [
              {
                command: [
                  '/bin/sh',
                  '/config/add-custom-policy.sh',
                ],
                env: [
                  {
                    name: 'MINIO_ENDPOINT',
                    value: '%s-0.%s-headless.%s.svc.cluster.local' % [componentName, componentName, namespace],
                  },
                  {
                    name: 'MINIO_PORT',
                    value: '9000',
                  },
                ],
                envFrom: [
                  {
                    secretRef: {
                      name: this.secret.metadata.name,
                    },
                  },
                ],
                image: helper.getImage(config.imageRegistryMirror, config.imageRegistry, config.imageConsoleRef, config.imageConsoleVersion),  // orig: 'quay.io/minio/mc:RELEASE.2022-10-20T23-26-33Z',
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
                  {
                    mountPath: '/toolbox',
                    name: 'toolbox',
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
                        name: this.configmap.metadata.name,
                      },
                    },
                  ],
                },
              },
              {
                name: 'toolbox',
                persistentVolumeClaim: {
                  claimName: 'job-policies-toolbox',
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
        annotations: {
          'external-dns.alpha.kubernetes.io/internal-hostname': std.join('.', [componentName, namespace, config.servicePublicDomain]),
        },
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

    ingress: if std.get(config, 'consoleIngress') != null then kube.Ingress('%s-console' % [componentName], ingressRestricted) {
      local ing = self,
      metadata+: {
        namespace: namespace,
        annotations+: {
          'cert-manager.io/cluster-issuer': config.consoleCertIssuer,
          'kubernetes.io/ingress.class': 'nginx',
          'nginx.ingress.kubernetes.io/backend-protocol': 'HTTPS',
        },
        labels+: config.labels,
      },
      spec: {
        tls: [
          {
            hosts: [
              config.consoleIngress,
            ],
            secretName: '%s-console-ingress-cert' % [componentName],
          },
        ],
        rules: [
          {
            host: config.consoleIngress,
            http: {
              paths: [
                {
                  backend: {
                    service: {
                      name: this.service_console.metadata.name,
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
              'checksum/kes': std.md5(std.toString(this.secret_kes)),
            },
            labels: config.labels,
            name: 'minio',
          },
          spec: {
            hostAliases: [
              {
                ip: '127.0.0.1',
                hostnames: ['kes-server.local', 'minio-kes-client.local'],
              },
            ],
            containers: [
              {
                // wait for kes container
                command: [
                  '/bin/sh',
                  '-ce',
                  '/bin/sleep 20; /usr/bin/docker-entrypoint.sh minio server /storage --certs-dir /etc/minio/certs/ --address :9000 --console-address :9001',
                ],
                envFrom: [
                  {
                    configMapRef: {
                      name: this.configmapcfg.metadata.name,
                    },
                  },
                  {
                    secretRef: {
                      name: componentName,
                    },
                  },
                ],
                image: helper.getImage(config.imageRegistryMirror, config.imageRegistry, config.imageRef, config.imageVersion),
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
                  {
                    mountPath: '/etc/minio/certs/public.crt',
                    name: this.service_certificate.metadata.name,
                    subPath: 'tls.crt',
                  },
                  {
                    mountPath: '/etc/minio/certs/private.key',
                    name: this.service_certificate.metadata.name,
                    subPath: 'tls.key',
                  },
                  {
                    mountPath: '/etc/minio/certs/ca.crt',
                    name: this.service_certificate.metadata.name,
                    subPath: 'ca.crt',
                  },
                  {
                    mountPath: config.minioKesClientCertPath,
                    name: this.minioKesClientCert.metadata.name,
                    subPath: 'tls.crt',
                  },
                  {
                    mountPath: config.minioKesClientKeyPath,
                    name: this.minioKesClientCert.metadata.name,
                    subPath: 'tls.key',
                  },
                  {
                    mountPath: config.kesRootCAPath,
                    name: this.minioKesClientCert.metadata.name,
                    subPath: 'ca.crt',
                  },
                ],
                readinessProbe: {
                  failureThreshold: 3,
                  httpGet: {
                    path: '/minio/health/live',
                    port: 'http',
                    scheme: 'HTTPS',
                  },
                  initialDelaySeconds: 30,
                  successThreshold: 1,
                  periodSeconds: 15,
                  timeoutSeconds: 5,
                },
                livenessProbe: {
                  failureThreshold: 3,
                  httpGet: {
                    path: '/minio/health/live',
                    port: 'http',
                    scheme: 'HTTPS',
                  },
                  initialDelaySeconds: 30,
                  successThreshold: 1,
                  periodSeconds: 30,
                  timeoutSeconds: 5,
                },
              },
              {
                command: [
                  '/bin/sh',
                  '-ce',
                  '/entrypoint.sh kes server --config /config.yml --addr 0.0.0.0:7373 --auth %s' % [config.kesAuth],
                ],
                image: helper.getImage(config.imageRegistryMirror, config.imageKesRegistry, config.imageKesRef, config.imageKesVersion),
                imagePullPolicy: 'IfNotPresent',
                name: 'kes',
                securityContext: {
                  // allowPrivilegeEscalation: true,
                  runAsNonRoot: false,
                  runAsUser: 0,
                  // XXX: this needs setcap cap_ipc_lock+ep /kes on original app container otherwise
                  // use root user
                  capabilities: {
                    add: ['IPC_LOCK'],
                    drop: ['ALL'],
                  },
                },
                ports: [
                  {
                    containerPort: 7373,
                    name: 'http-kes',
                  },
                ],
                resources: {},
                volumeMounts: [
                  {
                    mountPath: '/config.yml',
                    name: this.secret_kes.metadata.name,
                    subPath: 'config.yml',
                  },
                  {
                    mountPath: '/entrypoint.sh',
                    name: this.secret_kes.metadata.name,
                    subPath: 'entrypoint.sh',
                  },
                  {
                    mountPath: config.kesServerCertPath,
                    name: this.kesServerCert.metadata.name,
                    subPath: 'tls.crt',
                  },
                  {
                    mountPath: config.kesServerKeyPath,
                    name: this.kesServerCert.metadata.name,
                    subPath: 'tls.key',
                  },
                  {
                    mountPath: config.minioKesClientCertPath,
                    name: this.minioKesClientCert.metadata.name,
                    subPath: 'tls.crt',
                  },
                  {
                    mountPath: config.minioKesClientKeyPath,
                    name: this.minioKesClientCert.metadata.name,
                    subPath: 'tls.key',
                  },
                  {
                    mountPath: config.kesRootCAPath,
                    name: this.kesServerCert.metadata.name,
                    subPath: 'ca.crt',
                  },
                ],
                readinessProbe: {
                  failureThreshold: 3,
                  httpGet: {
                    path: '/v1/ready',
                    port: 'http-kes',
                    scheme: 'HTTPS',
                  },
                  initialDelaySeconds: 30,
                  successThreshold: 1,
                  periodSeconds: 10,
                  timeoutSeconds: 5,
                },
                livenessProbe: {
                  failureThreshold: 3,
                  httpGet: {
                    path: '/v1/ready',
                    port: 'http-kes',
                    scheme: 'HTTPS',
                  },
                  initialDelaySeconds: 30,
                  successThreshold: 1,
                  periodSeconds: 20,
                  timeoutSeconds: 5,
                },
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
              {
                name: this.service_certificate.metadata.name,
                secret: {
                  secretName: this.service_certificate.spec.secretName,
                },
              },
              {
                name: this.minioKesClientCert.metadata.name,
                secret: {
                  secretName: this.minioKesClientCert.spec.secretName,
                },
              },
              {
                name: this.kesServerCert.metadata.name,
                secret: {
                  secretName: this.kesServerCert.spec.secretName,
                },
              },
              {
                name: this.secret_kes.metadata.name,
                secret: {
                  secretName: this.secret_kes.metadata.name,
                  defaultMode: std.parseOctal('0770'),
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
