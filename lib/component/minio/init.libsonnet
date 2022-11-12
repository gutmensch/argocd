local helper = import '../../helper.libsonnet';
local kube = import '../../kube.libsonnet';

{
  generate(
    name, namespace, region, tenant, appConfig, defaultConfig={
      imageRegistry: '',
      imageRef: 'quay.io/minio/minio',
      imageVersion: 'RELEASE.2022-10-24T18-35-07Z',
      imageConsoleRef: 'quay.io/minio/mc',
      imageConsoleVersion: 'RELEASE.2022-10-20T23-26-33Z',
      rootUser: 'root',
      rootPassword: 'changeme',
      storageClass: 'default',
      storageSize: '20Gi',
      replicas: 1,
    }
  ):: helper.uniquify({

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    assert config.rootPassword != 'changeme' : error '"changeme" is an invalid password',

    local appName = name,
    local componentName = 'minio',

    configmap: kube.ConfigMap(componentName) {
      data: {
        'add-policy': importstr 'scripts/add-policy.sh',
        'add-user': importstr 'scripts/add-user.sh',
        'custom-command': importstr 'scripts/custom-command.sh',
        initialize: importstr 'scripts/initialize.sh',
      },
      metadata+: {
        labels+: config.labels,
        namespace: namespace,
      },
    },

    job_users: kube.Job('%s-user-mgmt' % [componentName]) {
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
            containers: [
              {
                command: [
                  '/bin/sh',
                  '/config/add-user',
                ],
                env: [
                  {
                    name: 'MINIO_ENDPOINT',
                    value: componentName,
                  },
                  {
                    name: 'MINIO_PORT',
                    value: '9000',
                  },
                ],
                image: helper.getImage(config.imageRegistry, config.imageConsoleRef, config.imageConsoleVersion),  // orig: 'quay.io/minio/mc:RELEASE.2022-10-20T23-26-33Z',
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
                        name: componentName,
                      },
                    },
                    {
                      secret: {
                        name: componentName,
                      },
                    },
                  ],
                },
              },
            ],
          },
        },
      },
    },

    service_minio: kube.Service(componentName) {
      metadata: {
        labels: config.labels,
        namespace: namespace,
      },
      spec: {
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
      metadata: {
        labels: config.labels,
        namespace: namespace,
      },
      spec: {
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

    service_sfs: kube.Service('%s-headless' % [componentName]) {
      metadata: {
        labels: config.labels,
        namespace: namespace,
      },
      spec: {
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
      metadata: {
        labels: config.labels,
        namespace: namespace,
      },
    },

    statefulset: kube.StatefulSet(componentName) {
      metadata: {
        labels: config.labels,
        namespace: namespace,
      },
      spec: {
        podManagementPolicy: 'Parallel',
        replicas: config.replicas,
        selector: {
          matchLabels: config.labels,
        },
        serviceName: '%s-headless' % [componentName],
        template: {
          metadata: {
            annotations: {
              'checksum/config': std.md5(std.toString(this.configmap)),
              'checksum/secrets': std.md5(std.toString(this.secret)),
            },
            labels: config.labels,
            name: 'minio',
          },
          spec: {
            containers: [
              {
                command: [
                  '/bin/sh',
                  '-ce',
                  '/usr/bin/docker-entrypoint.sh minio server http://minio-0.%s.svc.cluster.local/export -S /etc/minio/certs/ --address :9000 --console-address :9001' % [namespace],
                ],
                env: [
                  {
                    name: 'MINIO_ROOT_USER',
                    valueFrom: {
                      secretKeyRef: {
                        key: 'rootUser',
                        name: componentName,
                      },
                    },
                  },
                  {
                    name: 'MINIO_ROOT_PASSWORD',
                    valueFrom: {
                      secretKeyRef: {
                        key: 'rootPassword',
                        name: componentName,
                      },
                    },
                  },
                  {
                    name: 'MINIO_PROMETHEUS_AUTH_TYPE',
                    value: 'public',
                  },
                ],
                image: helper.getImage(config.imageRegistry, config.imageRef, config.imageVersion),  // orig: 'quay.io/minio/minio:RELEASE.2022-10-24T18-35-07Z',
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
                    mountPath: '/export',
                    name: 'export',
                  },
                ],
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
                name: 'minio-user',
                secret: {
                  secretName: componentName,
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
              name: 'export',
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
        ],
      },
    },

    secret: kube.Secret(componentName) {
      metadata: {
        labels: config.labels,
        namespace: namespace,
      },
      stringData: {
        rootPassword: config.rootPassword,
        rootUser: config.rootUser,
      },
      type: 'Opaque',
    },

  }),
}
