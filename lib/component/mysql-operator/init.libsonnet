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
      imageRef: 'mysql/mysql-operator',
      imageVersion: '8.0.31-2.0.7',
      replicas: 1,
    }
  ):: helper.uniquify({

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    local appName = name,
    local componentName = 'mysql-operator',

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
                args: [
                  'mysqlsh',
                  '--log-level=@INFO',
                  '--pym',
                  'mysqloperator',
                  'operator',
                ],
                securityContext: {
                  allowPrivilegeEscalation: false,
                  privileged: false,
                  readOnlyRootFilesystem: true,
                  runAsUser: 2,
                },
                volumeMounts: [
                  {
                    mountPath: '/mysqlsh',
                    name: 'mysqlsh-home',
                  },
                  {
                    mountPath: '/tmp',
                    name: 'tmpdir',
                  },
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
                name: componentName,
                resources: {},
                serviceAccountName: componentName,
                volumes: [
                  {
                    emptyDir: {},
                    name: 'mysqlsh-home',
                  },
                  {
                    emptyDir: {},
                    name: 'tmpdir',
                  },
                ],
              },
            ],
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
        MYSQLSH_USER_CONFIG_HOME: '/mysqlsh',
      },
    },

    clusterkopfpeering: kube._Object('zalando.org/v1', 'ClusterKopfPeering', componentName) {
      metadata+: {
        namespace: namespace,
        labels: config.labels,
      },
    },

    clusterrole: kube.ClusterRole(componentName) {
      metadata+: {
        namespace: namespace,
        labels: config.labels,
      },
      rules: [
        {
          apiGroups: [
            '',
          ],
          resources: [
            'pods',
          ],
          verbs: [
            'get',
            'list',
            'watch',
            'patch',
          ],
        },
        {
          apiGroups: [
            '',
          ],
          resources: [
            'pods/status',
          ],
          verbs: [
            'get',
            'patch',
            'update',
            'watch',
          ],
        },
        {
          apiGroups: [
            '',
          ],
          resources: [
            'secrets',
          ],
          verbs: [
            'get',
            'create',
            'list',
            'watch',
            'patch',
          ],
        },
        {
          apiGroups: [
            '',
          ],
          resources: [
            'configmaps',
          ],
          verbs: [
            'get',
            'create',
            'list',
            'watch',
            'patch',
          ],
        },
        {
          apiGroups: [
            '',
          ],
          resources: [
            'services',
          ],
          verbs: [
            'get',
            'create',
          ],
        },
        {
          apiGroups: [
            '',
          ],
          resources: [
            'serviceaccounts',
          ],
          verbs: [
            'get',
            'create',
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
            'update',
          ],
        },
        {
          apiGroups: [
            'rbac.authorization.k8s.io',
          ],
          resources: [
            'rolebindings',
          ],
          verbs: [
            'get',
            'create',
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
            'create',
          ],
        },
        {
          apiGroups: [
            'batch',
          ],
          resources: [
            'jobs',
          ],
          verbs: [
            'create',
          ],
        },
        {
          apiGroups: [
            'batch',
          ],
          resources: [
            'cronjobs',
          ],
          verbs: [
            'create',
            'update',
            'delete',
          ],
        },
        {
          apiGroups: [
            'apps',
          ],
          resources: [
            'deployments',
            'statefulsets',
          ],
          verbs: [
            'get',
            'create',
            'patch',
            'watch',
            'delete',
          ],
        },
        {
          apiGroups: [
            'mysql.oracle.com',
          ],
          resources: [
            '*',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            'zalando.org',
          ],
          resources: [
            '*',
          ],
          verbs: [
            'get',
            'patch',
            'list',
            'watch',
          ],
        },
        {
          apiGroups: [
            'apiextensions.k8s.io',
          ],
          resources: [
            'customresourcedefinitions',
          ],
          verbs: [
            'list',
            'watch',
          ],
        },
        {
          apiGroups: [
            '',
          ],
          resources: [
            'namespaces',
          ],
          verbs: [
            'list',
            'watch',
          ],
        },
      ],
    },

    // cluster role for server side car
    clusterrolemysqlsidecar: kube.ClusterRole('mysql-sidecar') {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      rules: [
        {
          apiGroups: [
            '',
          ],
          resources: [
            'pods',
          ],
          verbs: [
            'get',
            'list',
            'watch',
            'patch',
          ],
        },
        {
          apiGroups: [
            '',
          ],
          resources: [
            'pods/status',
          ],
          verbs: [
            'get',
            'patch',
            'update',
            'watch',
          ],
        },
        {
          apiGroups: [
            '',
          ],
          resources: [
            'secrets',
          ],
          verbs: [
            'get',
            'create',
            'list',
            'watch',
            'patch',
          ],
        },
        {
          apiGroups: [
            '',
          ],
          resources: [
            'configmaps',
          ],
          verbs: [
            'get',
            'create',
            'list',
            'watch',
            'patch',
          ],
        },
        {
          apiGroups: [
            '',
          ],
          resources: [
            'services',
          ],
          verbs: [
            'get',
            'create',
          ],
        },
        {
          apiGroups: [
            '',
          ],
          resources: [
            'serviceaccounts',
          ],
          verbs: [
            'get',
            'create',
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
            'update',
          ],
        },
        {
          apiGroups: [
            'apps',
          ],
          resources: [
            'deployments',
          ],
          verbs: [
            'get',
            'patch',
          ],
        },
        {
          apiGroups: [
            'mysql.oracle.com',
          ],
          resources: [
            'innodbclusters',
          ],
          verbs: [
            'get',
            'watch',
            'list',
          ],
        },
        {
          apiGroups: [
            'mysql.oracle.com',
          ],
          resources: [
            'mysqlbackups',
          ],
          verbs: [
            'create',
            'get',
            'list',
            'patch',
            'update',
            'watch',
            'delete',
          ],
        },
        {
          apiGroups: [
            'mysql.oracle.com',
          ],
          resources: [
            'mysqlbackups/status',
          ],
          verbs: [
            'get',
            'patch',
            'update',
            'watch',
          ],
        },
      ],
    },

    clusterrolebinding: kube.ClusterRoleBinding(componentName) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'ClusterRole',
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
