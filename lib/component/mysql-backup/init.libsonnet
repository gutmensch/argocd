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
      imageRef: 'gutmensch/toolbox',
      imageVersion: '0.0.3',
      mysqlHost: 'mysql',
      mysqlSystemUsers: [],
      backupMinioEnable: false,
      backupMinioEndpoint: 'http://minio:9000',
      backupMinioBucket: 'mysql-backup',
      backupMinioAccessKey: '',
      backupMinioSecretKey: '',
      backupMinioUser: '',
      backupMinioPassword: '',
      backupDir: '/var/backup',
    }
    //):: helper.uniquify({
  ):: {

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    local appName = name,
    local componentName = 'mysql-backup',

    // lookup backup user from system user list
    local _backupUser = [x for x in config.mysqlSystemUsers if x.user == 'backup'][0],

    backupJobs: {
      ['backup-%s' % [user.database]]: kube.CronJob('backup-%s' % [user.database]) {
        metadata+: {
          namespace: namespace,
          labels: config.labels { 'app.kubernetes.io/component': 'backup', 'app.kubernetes.io/instance': user.database },
        },
        spec+: {
          schedule: '%s %s * * *' % [helper.strToRandInt(user.database, 60), helper.strToRandInt(user.database, 6)],
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
                        '/usr/bin/mysql_backup.py',
                      ],
                      env: [
                        { name: 'BACKUP_DIR', value: config.backupDir },
                        { name: 'MYSQL_DB', value: user.database },
                      ],
                      envFrom: [
                        {
                          secretRef: {
                            name: '%s-config' % [componentName],
                          },
                        },
                      ],
                      image: '%s:%s' % [if config.imageRegistry != '' then std.join('/', [config.imageRegistry, config.imageRef]) else config.imageRef, config.imageVersion],
                      imagePullPolicy: 'Always',
                      name: componentName,
                      volumeMounts: [
                        {
                          mountPath: config.backupDir,
                          name: '%s-dump' % [componentName],
                          readOnly: false,
                        },
                      ],
                    },
                  },
                  volumes_+: {
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
      for user in config.mysqlDatabaseUsers
    } + {
      secret: kube.Secret('%s-config' % [componentName]) {
        metadata+: {
          namespace: namespace,
          labels+: config.labels,
        },
        data_: {
          S3_HOST: config.backupMinioEndpoint,
          S3_BUCKET: config.backupMinioBucket,
          S3_LDAP_USER: config.backupMinioUser,
          S3_LDAP_PASS: config.backupMinioPassword,
          MYSQL_HOST: config.mysqlHost,
          MYSQL_USER: _backupUser.user,
          MYSQL_PASS: _backupUser.password,
        },
      },
    },
  },
}
