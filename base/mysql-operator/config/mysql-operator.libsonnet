{
  default: {
    imageRegistry: 'registry.lan:5000',
  },

  staging: {
  },

  lts: {
    // allow kopf sidecars in other namespaces to assume
    // clusterrole too
    clusterRoleNamespaceServiceAccounts: {
      'base-mysqldb-lts': 'mysql-cluster',
    },
  },
}
