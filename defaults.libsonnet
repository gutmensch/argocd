{
  app: {
    repoURL: 'https://github.com/gutmensch/argocd.git',
    targetRevision: 'HEAD',
    tenant: ['staging', 'lts'],
    region: 'helsinki',
    directory: 'app',
  },
  crd: {
    repoURL: 'https://github.com/gutmensch/argocd.git',
    targetRevision: 'HEAD',
    directory: 'lib/crds',
  },
  project: {
    clusterResourceAllowList: [{ group: '', kind: 'Namespace' }],
  },

  withApp(map): $.app + map,
  withCRD(map): $.crd + map,
  withProject(map): $.project + map,
}
