//
// app of app pattern, define all projects and apps here
//
local def = import 'defaults.libsonnet';

{
  // --- projects for segregation
  projectList: [
    def.withProject({
      name: 'base',
      desc: 'Base applications like Backstage, MX, roundcube, Nextcloud, etc.',
      clusterResourceAllowList: [
        { group: '', kind: 'Namespace' },
      ],
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
        // app: mysql
        'percona-xtradb-cluster_20221030.yaml',
      ],
    }),
  ],

  appList: [
    def.withApp({ name: 'dns', project: 'base', path: 'dns', tenant: ['lts'] }),
    def.withApp({ name: 'auth', project: 'base', path: 'auth', tenant: ['lts'] }),
    def.withApp({ name: 'minio', project: 'base', path: 'minio', tenant: ['lts'] }),
    //def.withApp({ name: 'mx', project: 'base', path: 'mx', tenant: ['lts'] }),
    //def.withApp({ name: 'minio', project: 'base', path: 'minio', tenant: ['lts'] }),
    //def.withApp({ name: 'mysqldb', project: 'base', path: 'mysqldb', region: 'falkenstein', tenant: ['lts'] }),
    def.withApp({ name: 'roundcube', project: 'base', path: 'roundcube', tenant: ['lts'] }),
  ],
}