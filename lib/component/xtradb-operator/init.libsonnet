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
      imageRef: 'perconalab/percona-xtradb-cluster-operator',
      // imageVersion: 'main',
      // 2022-10-28
      imageVersion: 'sha256:80ec5a58332e3d427420cb0d65d44d2078cfbd93fb4e2ed8cf096a76e7c64a74',
      replicas: 1,
    }
  ):: helper.uniquify({

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    local appName = name,
    local componentName = 'xtradb-operator',

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
              'checksum/configmapenv': std.md5(std.toString(this.configmap)),
            },
          },
          spec: {
            containers: [
              {
                env: [
                  {
                    name: 'WATCH_NAMESPACE',
                    valueFrom: {
                      fieldRef: {
                        apiVersion: 'v1',
                        fieldPath: 'metadata.namespace',
                      },
                    },
                  },
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
                command: [
                  'percona-xtradb-cluster-operator',
                ],
                envFrom: [
                  {
                    configMapRef: {
                      name: componentName,
                    },
                  },
                ],
                image: '%s:%s' % [if config.imageRegistry != '' then std.join('/', [config.imageRegistry, config.imageRef]) else config.imageRef, config.imageVersion],
                imagePullPolicy: 'IfNotPresent',
                livenessProbe: {
                  failureThreshold: 3,
                  httpGet: {
                    path: '/metrics',
                    port: 'metrics',
                    scheme: 'HTTP',
                  },
                },
                name: componentName,
                ports: [
                  {
                    containerPort: 8080,
                    name: 'metrics',
                    protocol: 'TCP',
                  },
                ],
              },
            ],
            resources: {},
            serviceAccountName: componentName,
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
        OPERATOR_NAME: componentName,
        DISABLE_TELEMETRY: 'false',
      },
    },

    role: kube.Role(componentName) {
      metadata+: {
        namespace: namespace,
        labels: config.labels,
      },
      rules: [
        {
          apiGroups: [
            'pxc.percona.com',
          ],
          resources: [
            'perconaxtradbclusters',
            'perconaxtradbclusters/status',
            'perconaxtradbclusterbackups',
            'perconaxtradbclusterbackups/status',
            'perconaxtradbclusterrestores',
            'perconaxtradbclusterrestores/status',
          ],
          verbs: [
            'get',
            'list',
            'watch',
            'create',
            'update',
            'patch',
            'delete',
          ],
        },
        {
          apiGroups: [
            '',
          ],
          resources: [
            'pods',
            'pods/exec',
            'pods/log',
            'configmaps',
            'services',
            'persistentvolumeclaims',
            'secrets',
          ],
          verbs: [
            'get',
            'list',
            'watch',
            'create',
            'update',
            'patch',
            'delete',
          ],
        },
        {
          apiGroups: [
            'apps',
          ],
          resources: [
            'deployments',
            'replicasets',
            'statefulsets',
          ],
          verbs: [
            'get',
            'list',
            'watch',
            'create',
            'update',
            'patch',
            'delete',
          ],
        },
        {
          apiGroups: [
            'batch',
          ],
          resources: [
            'jobs',
            'cronjobs',
          ],
          verbs: [
            'get',
            'list',
            'watch',
            'create',
            'update',
            'patch',
            'delete',
          ],
        },
        {
          apiGroups: [
            'policy',
          ],
          resources: [
            'poddisruptionbudgets',
          ],
          verbs: [
            'get',
            'list',
            'watch',
            'create',
            'update',
            'patch',
            'delete',
          ],
        },
        {
          apiGroups: [
            'coordination.k8s.io',
          ],
          resources: [
            'leases',
          ],
          verbs: [
            'get',
            'list',
            'watch',
            'create',
            'update',
            'patch',
            'delete',
          ],
        },
        {
          apiGroups: [
            '',
          ],
          resources: [
            'events',
          ],
          verbs: [
            'create',
            'patch',
          ],
        },
        {
          apiGroups: [
            'certmanager.k8s.io',
            'cert-manager.io',
          ],
          resources: [
            'issuers',
            'certificates',
          ],
          verbs: [
            'get',
            'list',
            'watch',
            'create',
            'update',
            'patch',
            'delete',
            'deletecollection',
          ],
        },
      ],
    },

    rolebinding: kube.RoleBinding(componentName) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'Role',
        name: componentName,
      },
      subjects: [
        {
          kind: 'ServiceAccount',
          name: componentName,
          namespace: namespace,
        },
      ],
    },

    serviceaccount: kube.ServiceAccount(componentName) {
      metadata+: {
        namespace: namespace,
        labels: config.labels,
      },
    },
  }),
}
