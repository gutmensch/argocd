{
  app: {
    repoURL: 'https://github.com/gutmensch/argocd.git',
    targetRevision: 'HEAD',
    tenant: ['staging', 'lts'],
    region: 'helsinki',
    ignoreDiff: [],
  },
  yaml: {
    name: 'default',
    namespace: 'default',
    repoURL: 'https://github.com/gutmensch/argocd.git',
    targetRevision: 'HEAD',
    protect: true,
  },
  project: {
    clusterResourceAllowList: [{ group: '', kind: 'Namespace' }],
  },

  withApp(map): $.app + map,
  withYaml(map): $.yaml + map,
  withProject(map): $.project + map,
}
