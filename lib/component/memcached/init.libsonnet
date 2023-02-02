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
      imageRegistry: '',
      imageRef: 'memcached',
      imageVersion: '1.6.17-alpine',
      replicas: 1,
    }
  ):: helper.uniquify({

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    local appName = name,
    local componentName = 'memcached',

    deployment: kube.Deployment(componentName) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      spec+: {
        nodeSelector: {
          'topology.kubernetes.io/region': region,
        },
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
              'checksum/configmapenv': std.md5(std.toString(this.configmap)),
            },
          },
          spec: {
            containers: [
              {
                envFrom: [
                  {
                    configMapRef: {
                      name: componentName,
                    },
                  },
                ],
                image: helper.getImage(config.imageRegistry, config.imageRef, config.imageVersion),
                imagePullPolicy: 'IfNotPresent',
                readinessProbe: {
                  tcpSocket: {
                    port: 11211,
                  },
                  initialDelaySeconds: 5,
                  periodSeconds: 10,
                },
                livenessProbe: {
                  failureThreshold: 3,
                  tcpSocket: {
                    port: 11211,
                  },
                  initialDelaySeconds: 15,
                  periodSeconds: 20,
                },
                name: 'memcached',
                ports: [
                  {
                    containerPort: 11211,
                  },
                ],
              },
            ],
            resources: {},
            volumes: [],
          },
        },
      },
    },

    configmap: kube.ConfigMap(componentName) {
      metadata+: {
        namespace: namespace,
        labels: config.labels,
      },
      data: {
        CONFIGMAP_UNUSED: 'true',
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
            port: 11211,
            protocol: 'TCP',
            targetPort: 11211,
          },
        ],
        selector: config.labels,
        type: 'ClusterIP',
      },
    },
  }),
}
