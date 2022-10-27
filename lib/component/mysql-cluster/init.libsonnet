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
      mysqlVersion: '8.0.31',
      replicas: 2,
      routers: 1,
      storageClass: 'default',
      storageSize: '10Gi',
      backupStorageClass: 'default',
      backupStorageSize: '50Gi',
      rootUser: 'root',
      rootHost: '%',
      rootPassword: 'changeme',
    },
  ):: helper.uniquify({

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    local appName = name,
    local componentName = 'mysql-cluster',

    assert config.rootPassword != 'changeme' : error '"changeme" is an invalid password',

    rootusersecret: kube.Secret(componentName) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      stringData: {
        rootUser: config.rootUser,
        rootHost: config.rootHost,
        rootPassword: config.rootPassword,
      },
    },

    innodbcluster: kube._Object('mysql.oracle.com/v2', 'InnoDBCluster', componentName) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      spec+: {
        instances: config.replicas,
        tlsUseSelfSigned: true,
        router: {
          instances: config.routers,
        },
        secretName: componentName,
        imagePullPolicy: 'IfNotPresent',
        baseServerId: 1000,
        version: config.mysqlVersion,
        edition: 'community',
        serviceAccountName: componentName,

        datadirVolumeClaimTemplate: {
          storageClassName: config.storageClass,
          accessModes: ['ReadWriteOnce'],
          resources: {
            requests: {
              storage: config.storageSize,
            },
          },
        },

        backupProfiles: [
          {
            name: '%s-backup' % [componentName],
            snapshot: {
              storage: {
                persistentVolumeClaim: {
                  // operator mounts at /mnt/storage into backup pod
                  claimName: '%s-backup' % [componentName],
                },
              },
            },
          },
        ],

        backupSchedules: [
          {
            name: 'schedule-ref',
            schedule: '10 1 * * *',
            deleteBackupData: true,
            backupProfileName: '%s-backup' % [componentName],
          },
        ],
      },
    },

    backuppvc: kube.PersistentVolumeClaim('%s-backup' % [componentName]) {
      storage: config.backupStorageSize,
      storageClass: config.backupStorageClass,
    },

    serviceaccount: kube.ServiceAccount(componentName) {
      metadata+: {
        namespace: namespace,
        labels: config.labels,
      },
    },

  }),
}
