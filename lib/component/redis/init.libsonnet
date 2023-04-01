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
      imageRef: 'redis',
      imageVersion: '7.0.7-alpine',
      replicas: 1,
      redisPassword: 'changeme',
      dbdumpPath: '/dbdump',
      dbdumpSizeLimit: '1Gi',
      memoryLimit: '1Gi',
    }
  ):: helper.uniquify({

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    assert config.redisPassword != 'changeme' : error 'please change the redis password',

    local appName = name,
    local componentName = 'redis',

    deployment: kube.Deployment(componentName) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      spec: {
        replicas: config.replicas,
        selector: {
          matchLabels: config.labels,
        },
        strategy: {
          rollingUpdate: {
            maxUnavailable: 1,
          },
          type: 'RollingUpdate',
        },
        template: {
          metadata+: {
            labels+: config.labels,
            annotations+: {
              'checksum/secretconf': std.md5(std.toString(this.secret)),
            },
          },
          spec: {
            containers: [
              {
                resources: {
                  limits: {
                    memory: config.memoryLimit,
                  },
                },
                image: helper.getImage(config.imageRegistryMirror, config.imageRegistry, config.imageRef, config.imageVersion),
                imagePullPolicy: 'IfNotPresent',
                readinessProbe: {
                  tcpSocket: {
                    port: 6379,
                  },
                  initialDelaySeconds: 5,
                  periodSeconds: 10,
                },
                livenessProbe: {
                  failureThreshold: 3,
                  tcpSocket: {
                    port: 6379,
                  },
                  initialDelaySeconds: 15,
                  periodSeconds: 20,
                },
                name: 'redis',
                ports: [
                  {
                    containerPort: 6379,
                  },
                ],
                volumeMounts: [
                  {
                    name: 'config',
                    mountPath: '/usr/local/etc/redis/redis.conf',
                    readOnly: true,
                  },
                  {
                    name: 'dbdump',
                    mountPath: config.dbdumpPath,
                  },
                ],
              },
            ],
            volumes: [
              {
                name: 'dbdump',
                emptyDir: {
                  sizeLimit: config.dbdumpSizeLimit,
                },
              },
            ],
          },
        },
      },
    },

    secret: kube.Secret(componentName) {
      metadata+: {
        namespace: namespace,
        labels: config.labels,
      },
      stringData: {
        // https://raw.githubusercontent.com/redis/redis/7.0/redis.conf
        'redis.conf': std.join('\n', [
          'save 3600 1 300 100 60 10000',
          'dbfilename dump.rdb',
          'dir %s' % [config.dbdumpPath],
          'requirepass %s' % [config.redisPassword],
        ]),
      },
    },

    service: kube.Service(componentName) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      spec: {
        ports: [
          {
            port: 6379,
            protocol: 'TCP',
            targetPort: 6379,
          },
        ],
        selector: config.labels,
        type: 'ClusterIP',
      },
    },
  }),
}
