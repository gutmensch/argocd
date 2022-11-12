local def = import 'defaults.libsonnet';
local argo = import 'lib/argo.libsonnet';

// --- app of app pattern, define all projects and apps
local projectList = [
  def.withProject({
    name: 'base',
    desc: 'Base applications like Backstage, MX, roundcube, Nextcloud, etc.',
    clusterResourceAllowList: [
      { group: '', kind: 'Namespace' },
    ],
  }),
];

// --- manage CRDs seperately from apps, comment dependency only
local crdList = [
  def.withCRD({
    name: 'default',
    path: 'lib/crds',
    crds: [
      // app: mysql
      'percona-xtradb-cluster_20221030.yaml',
    ],
  }),
];

local appList = [
  def.withApp({ name: 'dns', project: 'base', path: 'dns', tenant: ['lts'] }),
  def.withApp({ name: 'auth', project: 'base', path: 'auth', tenant: ['lts'] }),
  def.withApp({ name: 'mx', project: 'base', path: 'mx', tenant: ['lts'] }),
  def.withApp({ name: 'minio', project: 'base', path: 'minio', tenant: ['lts'] }),
  def.withApp({ name: 'mysqldb', project: 'base', path: 'mysqldb', tenant: ['lts'] }),
  def.withApp({ name: 'roundcube', project: 'base', path: 'roundcube', tenant: ['lts'] }),
];


// --- generate resources for ArgoCD
local projects = [
  argo.Project(proj.name,
               std.prune([
                 if app.project == proj.name then '%s-%s-%s' % [proj.name, app.name, tenant] else null
                 for app in appList
                 for tenant in app.tenant
               ]),
               proj.desc,
               proj.clusterResourceAllowList)
  for proj in projectList
];

local crds = [
  argo.CRDApplication(crdColl)
  for crdColl in crdList
];

local apps = [
  argo.Application(tenant, app)
  for app in appList
  for tenant in app.tenant
];

projects + crds + apps
