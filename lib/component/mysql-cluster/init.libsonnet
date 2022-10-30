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
      crVersion: '1.11.0',
      mysqlImageRef: 'percona/percona-xtradb-cluster',
      mysqlImageVersion: '8.0.27-18.1',
      baseImageRef: 'percona/percona-xtradb-cluster-operator',
      baseImageVersion: self.crVersion,
      pmmImageRef: 'percona/pmm-client',
      pmmImageVersion: '2.28.0',

      replicas: 2,
      storageClass: 'default',
      storageSize: '10Gi',

      haproxyEnable: true,
      haproxyReplicas: 1,

      proxySqlEnable: false,
      proxySqlReplicas: 0,
      proxySqlStorageSize: '2Gi',

      pmmEnable: false,
      logcollectorEnable: false,

      backupStorageClass: 'default',
      backupStorageSize: '50Gi',

      // system user passwords
      rootPassword: 'changeme',
      backupPassword: 'changeme',
      monitorPassword: 'changeme',
      clusterCheckPassword: 'changeme',
      proxyAdminPassword: 'changeme',
      pmmServerPassword: 'changeme',
      operatorPassword: 'changeme',
      replicationPassword: 'changeme',
    },
  ):: helper.uniquify({

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    local appName = name,
    local componentName = 'mysql-cluster',

    assert config.rootPassword != 'changeme' : error '"changeme" is an invalid password',

    systemuserssecret: kube.Secret('%s-system-users' % [componentName]) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      stringData: {
        root: config.rootPassword,
        xtrabackup: config.backupPassword,
        monitor: config.monitorPassword,
        clustercheck: config.clusterCheckPassword,
        proxyadmin: config.proxyAdminPassword,
        pmmserver: config.pmmServerPassword,
        operator: config.operatorPassword,
        replication: config.replicationPassword,
      },
    },

    // backuppvc: kube.PersistentVolumeClaim('%s-backup' % [componentName]) {
    //   storage: config.backupStorageSize,
    //   storageClass: config.backupStorageClass,
    // },

    xtradbcluster: kube._Object('pxc.percona.com/v1', 'PerconaXtraDBCluster', componentName) {
      metadata+: {
        finalizers: [
          'delete-pxc-pods-in-order',
        ],
        labels+: config.labels,
        namespace: namespace,
      },
      spec+: {
        secretsName: '%s-system-users' % [componentName],
        allowUnsafeConfigurations: true,
        enableCRValidationWebhook: true,
        backup: {
          image: helper.getImage(config.imageRegistry, config.baseImageRef, '%s-pxc8.0-backup' % [config.baseImageVersion]),
          pitr: {
            enabled: true,
            storageName: 'fs-pvc',
            timeBetweenUploads: 60,
          },
          schedule: [
            {
              keep: 10,
              name: 'daily-backup',
              schedule: '0 1 * * *',
              storageName: 'fs-pvc',
            },
          ],
          storages: {
            'fs-pvc': {
              type: 'filesystem',
              volume: {
                persistentVolumeClaim: {
                  storageClassName: config.backupStorageClass,
                  accessModes: [
                    'ReadWriteOnce',
                  ],
                  resources: {
                    requests: {
                      storage: config.backupStorageSize,
                    },
                  },
                },
              },
            },
          },
        },
        crVersion: config.crVersion,
        haproxy: {
          affinity: {
            antiAffinityTopologyKey: 'kubernetes.io/hostname',
          },
          enabled: config.haproxyEnable,
          gracePeriod: 30,
          image: helper.getImage(config.imageRegistry, config.baseImageRef, '%s-haproxy' % [config.baseImageVersion]),
          podDisruptionBudget: {
            maxUnavailable: 1,
          },
          size: config.haproxyReplicas,
        },
        logcollector: {
          enabled: config.logcollectorEnable,
          image: helper.getImage(config.imageRegistry, config.baseImageRef, '%s-logcollector' % [config.baseImageVersion]),
        },
        pmm: {
          enabled: config.pmmEnable,
          image: helper.getImage(config.imageRegistry, config.pmmImageRef, config.pmmImageVersion),
          serverHost: 'monitoring-service',
        },
        proxysql: {
          affinity: {
            antiAffinityTopologyKey: 'kubernetes.io/hostname',
          },
          enabled: config.proxySqlEnable,
          gracePeriod: 30,
          image: helper.getImage(config.imageRegistry, config.baseImageRef, '%s-proxysql' % [config.baseImageVersion]),
          podDisruptionBudget: {
            maxUnavailable: 1,
          },
          size: config.proxySqlReplicas,
          volumeSpec: {
            persistentVolumeClaim: {
              storageClassName: config.storageClass,
              resources: {
                requests: {
                  storage: config.proxySqlStorageSize,
                },
              },
            },
          },
        },
        pxc: {
          affinity: {
            antiAffinityTopologyKey: 'kubernetes.io/hostname',
          },
          autoRecovery: true,
          gracePeriod: 600,
          image: helper.getImage(config.imageRegistry, config.mysqlImageRef, config.mysqlImageVersion),
          podDisruptionBudget: {
            maxUnavailable: 1,
          },
          size: config.replicas,
          volumeSpec: {
            persistentVolumeClaim: {
              storageClassName: config.storageClass,
              resources: {
                requests: {
                  storage: config.storageSize,
                },
              },
            },
          },
        },
        updateStrategy: 'SmartUpdate',
        upgradeOptions: {
          apply: 'disabled',
          schedule: '0 4 * * *',
          versionServiceEndpoint: 'https://check.percona.com',
        },
      },
    },
  }),
}
