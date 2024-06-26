local helper = import '../../helper.libsonnet';
local kube = import '../../kube.libsonnet';

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
      imageRegistryMirror: '',
      imageRegistry: '',
      imageRef: 'willhallonline/ansible',
      imageVersion: '2.13-alpine-3.16',
      rootUser: 'root',
      rootPassword: 'changeme',
      mysqlHost: 'mysql',
      mysqlDatabaseUsers: [],
      mysqlSystemUsers: [],
    }
  ):: helper.uniquify({

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    local appName = name,
    local componentName = 'mysql-user',
    local jobVersion = std.substr(std.md5(std.toString([config.mysqlDatabaseUsers, config.mysqlSystemUsers])), 15, 16),

    // new simple job will be created when content of zone changes
    job: kube.Job('job-%s-%s' % [componentName, jobVersion]) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      spec+: {
        backoffLimit: 3,
        completions: 1,
        template+: {
          metadata+: {
            annotations+: {
            },
            labels: config.labels,
          },
          spec+: {
            containers: [
              {
                args: [
                  '/bin/sh',
                  '/ansible/run.sh',
                ],
                env: [],
                envFrom: [
                  {
                    secretRef: {
                      name: componentName,
                    },
                  },
                ],
                image: helper.getImage(config.imageRegistryMirror, config.imageRegistry, config.imageRef, config.imageVersion),
                imagePullPolicy: 'Always',
                name: componentName,
                volumeMounts: [
                  {
                    mountPath: '/ansible/playbook.yml',
                    name: '%s-config' % [componentName],
                    subPath: 'playbook.yml',
                  },
                  {
                    mountPath: '/ansible/run.sh',
                    name: '%s-config' % [componentName],
                    subPath: 'run.sh',
                  },
                  {
                    mountPath: '/vars',
                    name: '%s-data' % [componentName],
                    readOnly: true,
                  },
                ],
              },
            ],
            volumes: [
              {
                configMap: {
                  name: '%s-config' % [componentName],
                },
                name: '%s-config' % [componentName],
              },
              {
                secret: {
                  secretName: '%s-data' % [componentName],
                },
                name: '%s-data' % [componentName],
              },
            ],
          },
        },
      },
    },

    configmap: kube.ConfigMap('%s-config' % [componentName]) {
      metadata+: {
        namespace: namespace,
        labels: config.labels,
        annotations+: {
          'argocd.argoproj.io/sync-options': 'Replace=true',
        },
      },
      data: {
        'playbook.yml': importstr 'playbook.yml',
        'run.sh': importstr 'run.sh',
      },
    },

    secretmysqlconn: kube.Secret(componentName) {
      metadata+: {
        namespace: namespace,
        labels: config.labels,
      },
      stringData: {
        MYSQL_HOST: config.mysqlHost,
        MYSQL_ADMIN_USERNAME: config.rootUser,
        MYSQL_ADMIN_PASSWORD: config.rootPassword,
      },
    },

    secretdata: kube.Secret('%s-data' % [componentName]) {
      metadata+: {
        namespace: namespace,
        labels: config.labels,
      },
      stringData: {
        'data.yml': std.manifestYamlDoc({ mysql_database_users: config.mysqlDatabaseUsers, mysql_system_users: config.mysqlSystemUsers }),
      },
    },

  }),
}
