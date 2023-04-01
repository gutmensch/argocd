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
      imageRef: 'library/percona',
      imageVersion: '8.0.29-21',
      storageClass: 'standard',
      storageSize: '20Gi',
      myCnf: {
        main: {},
        sections: {
          mysqld: {
            skip_name_resolve: 'ON',
            ssl_ca: '/ssl/ca.pem',
            ssl_cert: '/ssl/server-cert.pem',
            ssl_key: '/ssl/server-key.pem',
            require_secure_transport: 'OFF',
            default_authentication_plugin: 'mysql_native_password',
          },
        },
      },
    }
  ):: helper.uniquify({

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    local appName = name,
    local componentName = 'mysql-single-node',

    local certCRDs = ca.serverCert(
      name=componentName,
      namespace=namespace,
      createIssuer=true,
      dnsNames=['mysql', 'mysql.%s.svc.cluster.local' % [namespace], '%s.%s.svc.cluster.local' % [componentName, namespace]],
      labels=config.labels,
    ),
    localrootcacert: certCRDs.localrootcacert,
    localcertissuer: certCRDs.localcertissuer,
    servercert: certCRDs.localservercert,

    configmap: kube.ConfigMap(componentName) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      data: {
        // currently empty, because no options needed, see
        // https://hub.docker.com/_/percona
      },
    },

    configmapcnf: kube.ConfigMap('%s-server-cnf' % [componentName]) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      data: {
        'server.cnf': std.manifestIni(config.myCnf),
      },
    },

    servicecluster: kube.Service('mysql') {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      spec: {
        ports: [
          {
            name: 'mysql-port',
            nodePort: null,
            port: 3306,
            protocol: 'TCP',
            targetPort: 'mysql-port',
          },
        ],
        selector: config.labels,
        sessionAffinity: 'None',
        type: 'ClusterIP',
      },
    },

    serviceheadless: kube.Service('mysql-headless') {
      apiVersion: 'v1',
      kind: 'Service',
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      spec: {
        clusterIP: 'None',
        ports: [
          {
            name: 'mysql-port',
            port: 3306,
            targetPort: 'mysql-port',
          },
        ],
        selector: config.labels,
        sessionAffinity: 'None',
        type: 'ClusterIP',
      },
    },

    statefulset: kube.StatefulSet(componentName) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      spec: {
        // hardcoded to avoid potential dual master problems
        replicas: 1,
        selector: {
          matchLabels: config.labels,
        },
        serviceName: '%s-headless' % [componentName],
        template: {
          metadata+: {
            annotations+: {
              'checksum/env': std.md5(std.toString(this.configmap)),
              'checksum/cnf': std.md5(std.toString(this.configmapcnf)),
              'checksum/credentials': std.md5(std.toString(this.secret)),
            },
            labels: config.labels,
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
                        matchLabels: config.labels,
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
                ],
                envFrom: [
                  {
                    configMapRef: {
                      name: componentName,
                    },
                  },
                  {
                    secretRef: {
                      name: componentName,
                    },
                  },
                ],
                image: helper.getImage(config.mirrorImageRegistry, config.imageRegistry, config.imageRef, config.imageVersion),
                imagePullPolicy: 'Always',
                livenessProbe: {
                  failureThreshold: 10,
                  initialDelaySeconds: 20,
                  periodSeconds: 10,
                  successThreshold: 1,
                  tcpSocket: {
                    port: 'mysql-port',
                  },
                  timeoutSeconds: 1,
                },
                name: componentName,
                ports: [
                  {
                    containerPort: 3306,
                    name: 'mysql-port',
                  },
                ],
                readinessProbe: {
                  failureThreshold: 10,
                  initialDelaySeconds: 20,
                  periodSeconds: 10,
                  successThreshold: 1,
                  tcpSocket: {
                    port: 'mysql-port',
                  },
                  timeoutSeconds: 1,
                },
                resources: {
                  limits: {},
                  requests: {},
                },
                securityContext: {
                  runAsNonRoot: true,
                  runAsUser: 1001,
                },
                volumeMounts: [
                  {
                    mountPath: '/var/lib/mysql',
                    name: 'data',
                  },
                  {
                    mountPath: '/etc/my.cnf.d',
                    name: '%s-server-cnf' % [componentName],
                  },

                  {
                    mountPath: config.myCnf.sections.mysqld.ssl_cert,
                    name: 'certificate',
                    subPath: 'tls.crt',
                  },
                  {
                    mountPath: config.myCnf.sections.mysqld.ssl_key,
                    name: 'certificate',
                    subPath: 'tls.key',
                  },
                  {
                    mountPath: config.myCnf.sections.mysqld.ssl_ca,
                    name: 'certificate',
                    subPath: 'ca.crt',
                  },
                ],
              },
            ],
            initContainers: null,
            nodeSelector: {
              'topology.kubernetes.io/region': region,
            },
            securityContext: {
              fsGroup: 1001,
            },
            volumes: [
              {
                name: 'certificate',
                secret: {
                  secretName: '%s-server-cert' % [componentName],
                },
              },
              {
                configMap: {
                  name: '%s-server-cnf' % [componentName],
                },
                name: '%s-server-cnf' % [componentName],
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
              annotations: null,
              name: 'data',
            },
            spec: {
              accessModes: [
                'ReadWriteOnce',
              ],
              resources: {
                requests: {
                  storage: config.storageSize,
                },
              },
              storageClassName: config.storageClass,
            },
          },
        ],
      },
    },

    secret: kube.Secret(componentName) {
      metadata+: {
        namespace: namespace,
        labels: config.labels,
      },
      stringData: {
        MYSQL_ROOT_PASSWORD: config.rootPassword,
      },
    },
  }),
}
