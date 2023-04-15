//
// app of app pattern, define all projects and apps here
//
local custom = import 'custom.libsonnet';
local def = import 'defaults.libsonnet';

{
  // --- projects for segregation
  projectList: [
    def.withProject({
      name: 'base',
      desc: 'Base applications like Backstage, MX, roundcube, Nextcloud, etc.',
      clusterResourceAllowList: [
        { group: '', kind: 'Namespace' },
        { group: 'rbac.authorization.k8s.io', kind: 'ClusterRole' },
        { group: 'rbac.authorization.k8s.io', kind: 'ClusterRoleBinding' },
        { group: 'cert-manager.io', kind: 'ClusterIssuer' },
      ],
      // XXX: cert manager is installed via ansible in bootstrap but we need
      // to create secrets from argocd for google dns too
      additionalNamespaces: ['cert-manager-system'],
    }),
  ],

  // --- manage global cluster resources like storage classes, clusterroles, etc.
  resourceList: [
    def.withYaml({
      type: 'resource',
      path: 'resource',
      files: [
        'storage-class-zfs-fast-xfs.yaml',
        'storage-class-zfs-slow-xfs.yaml',
      ],
    }),
  ],

  // --- manage CRDs seperately from apps, comment dependency only
  crdList: [
    def.withYaml({
      type: 'crd',
      path: 'lib/crds',
      files: [
      ],
    }),
  ],

  appList: [
    def.withApp({ name: 'dns', project: 'base', path: 'dns', tenant: ['lts'] }),
    def.withApp({ name: 'googledns', project: 'base', path: 'googledns', tenant: ['lts'] }),
    def.withApp({ name: 'auth', project: 'base', path: 'auth', tenant: ['lts'] }),
    def.withApp({ name: 'minio', project: 'base', path: 'minio', tenant: ['lts'] }),
    def.withApp({ name: 'mx', project: 'base', path: 'mx', tenant: ['lts'], ignoreDiff: custom.ignoreDiff.networkPolicy }),
    def.withApp({ name: 'mysqldb', project: 'base', path: 'mysqldb', region: 'falkenstein', tenant: ['staging', 'lts'] }),
    def.withApp({ name: 'roundcube', project: 'base', path: 'roundcube', region: 'falkenstein', tenant: ['lts'] }),
    def.withApp({ name: 'nextcloud', project: 'base', path: 'nextcloud', region: 'falkenstein', tenant: ['lts'] }),
  ],
}
