local helper = import '../../helper.libsonnet';
local kube = import '../../kube.libsonnet';
local ca = import '../../localca.libsonnet';

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
      imageRef: 'percona',
      imageVersion: '8.0.29-21',
      rootSecretRef: 'mysql-single-node',
      mysqlUsers: {},
      backupMinioEnable: false,
      backupMinioEndpoint: 'http://minio:9000',
      backupMinioBucket: 'mysql-backup',
      backupMinioAccessKey: '',
      backupMinioSecretKey: '',
    }
    //):: helper.uniquify({
  ):: {

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    local appName = name,
    local componentName = 'mysql-backup',

    backupJobs: {
      ['backup-%s' % [user.database]]: kube.CronJob('backup-%s' % [user.database]) {
        metadata+: {
          namespace: namespace,
          labels: config.labels { 'app.kubernetes.io/component': 'backup', 'app.kubernetes.io/instance': user.database },
        },
        spec+: {
          //containers_+: { foo: { image: 'foobar' } },
          schedule: '15 1 * * *',
          jobTemplate+: {
            metadata+: {
              annotations+: {
              },
              labels: config.labels { 'app.kubernetes.io/component': 'backup', 'app.kubernetes.io/instance': user.database },
            },
            spec+: {
              backoffLimit: 10,
              completions: 1,
              template+: {
                spec+: {
                  containers_+: {
                    backup: {
                      args: [
                        '/bin/sh',
                        '/backup.sh',
                        user.database,
                      ],
                      env: [],
                      envFrom: [
                        {
                          secretRef: {
                            name: config.rootSecretRef,
                          },
                        },
                        {
                          secretRef: {
                            name: '%s-minio' % [componentName],
                          },
                        },
                      ],
                      image: '%s:%s' % [if config.imageRegistry != '' then std.join('/', [config.imageRegistry, config.imageRef]) else config.imageRef, config.imageVersion],
                      imagePullPolicy: 'Always',
                      name: componentName,
                      volumeMounts: [
                        {
                          mountPath: '/backup.sh',
                          name: '%s-config' % [componentName],
                          subPath: 'backup.sh',
                        },
                        {
                          mountPath: '/var/backup',
                          name: '%s-dump' % [componentName],
                          readOnly: false,
                        },
                      ],
                    },
                  },
                  volumes_+: {
                    config: {
                      configMap: {
                        name: '%s-config' % [componentName],
                      },
                      name: '%s-config' % [componentName],
                    },
                    dump: {
                      emptyDir: {
                        sizeLimit: '2Gi',
                      },
                      name: '%s-dump' % [componentName],
                    },
                  },
                },
              },
            },
          },

        },
      }
      for user in config.mysqlUsers
    } + {
      secret: kube.Secret('%s-minio' % [componentName]) {
        metadata+: {
          namespace: namespace,
          labels: config.labels,
        },
        stringData: {
          ENDPOINT: config.backupMinioEndpoint,
          BUCKET: config.backupMinioBucket,
          ACCESS_KEY: config.backupMinioUser,
          SECRET_KEY: config.backupMinioPassword,
        },
      },
    } + {
      configmap: kube.ConfigMap('%s-config' % [componentName]) {
        metadata+: {
          namespace: namespace,
          labels: config.labels,
        },
        data: {
          'backup.sh': importstr 'backup.sh',
        },
      },
    },
  },
}
