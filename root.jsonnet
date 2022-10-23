local def = import 'defaults.libsonnet';
local argo = import 'lib/argo.libsonnet';

// --- app of app pattern, define all projects and apps
local projectList = [
  def.withProject({
    name: 'base',
    desc: 'This project hosts base applications like Jenkins, Backstage, MX, roundcube, dmarc frontend, Nextcloud, etc.',
    clusterResourceAllowList: [
      { group: '', kind: 'Namespace' },
    ],
  }),
];

// --- manage CRDs seperately from apps, comment dependency only
local crdList = [
  def.withCRD({
    name: 'default',
    crds: [
      // app: mysql
      'mysql-operator_20221023.yaml',
    ],
  }),
];

local appList = [
  def.withApp({ name: 'dns', project: 'base', path: 'dns', tenant: ['lts'] }),
  def.withApp({ name: 'auth', project: 'base', path: 'auth', tenant: ['lts'] }),
  def.withApp({ name: 'mx', project: 'base', path: 'mx', tenant: ['lts'] }),
  // withAppDef({ name: 'mysql', project: 'base', path: 'mysql', tenant: ['lts'] }),
  //  withAppDef({ name: 'keycloak', project: 'base', path: 'keycloak', tenant: ['lts'] ingressRoot: 'bln.space', ingressPrefix: 'auth' }),
  //  withAppDef({ name: 'jenkins', project: 'base', path: 'jenkins', ingressRoot: 'bln.space' }),
  //  withAppDef({ name: 'guestbook', project: 'base', path: 'guestbook', ingressRoot 'schumann.link' }),
  //  withAppDef({ name: 'foobar', project: 'base', path: 'foobar', ingressRoot: 'schumann.link' }),
];


// --- generate resources for ArgoCD
local projects = [
  argo.Project(proj.name,
               [
                 '%s-%s-%s' % [proj.name, app.name, tenant]
                 for app in appList
                 for tenant in app.tenant
                 for proj in projectList
               ],
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
