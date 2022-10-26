local kube = import 'kube.libsonnet';
{
  clusterkopfpeering_mysql_operator: kube.ClusterKopfPeering('mysql-operator'): {
    metadata: {
      namespace: namespace,
    },
  },
  clusterrole_mysql_operator: kube.ClusterRole('mysql-operator'): {
    metadata: {
      namespace: namespace,
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
  clusterrole_mysql_sidecar: kube.ClusterRole('mysql-sidecar'): {
    metadata: {
      namespace: namespace,
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
  clusterrolebinding_mysql_operator_rolebinding: kube.ClusterRoleBinding('mysql-operator-rolebinding'): {
    metadata: {
      namespace: namespace,
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'ClusterRole',
      name: 'mysql-operator',
    },
    subjects: [
      {
        kind: 'ServiceAccount',
        name: 'mysql-operator-sa',
        namespace: 'mysql-operator',
      },
    ],
  },
  deployment_mysql_operator: kube.Deployment('mysql-operator'): {
    metadata: {
      labels: {
        'app.kubernetes.io/component': 'controller',
        'app.kubernetes.io/created-by': 'mysql-operator',
        'app.kubernetes.io/instance': 'mysql-operator',
        'app.kubernetes.io/managed-by': 'mysql-operator',
        'app.kubernetes.io/name': 'mysql-operator',
        'app.kubernetes.io/version': '8.0.31-2.0.7',
        version: '1.0',
      },
      namespace: namespace,
    },
    spec: {
      replicas: 1,
      selector: {
        matchLabels: {
          name: 'mysql-operator',
        },
      },
      template: {
        metadata: {
          labels: {
            name: 'mysql-operator',
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
              env: [
                {
                  name: 'MYSQLSH_USER_CONFIG_HOME',
                  value: '/mysqlsh',
                },
              ],
              image: 'mysql/mysql-operator:8.0.31-2.0.7',
              imagePullPolicy: 'IfNotPresent',
              name: 'mysql-operator',
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
            },
          ],
          serviceAccountName: 'mysql-operator-sa',
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
      },
    },
  },
  namespace_mysql_operator: kube.Namespace('mysql-operator'): {
    metadata: {
      namespace: namespace,
    },
  },
  serviceaccount_mysql_operator_sa: kube.ServiceAccount('mysql-operator-sa'): {
    metadata: {
      namespace: namespace,
    },
  },
}
