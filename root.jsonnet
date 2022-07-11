local argo = import 'lib/argo.libsonnet';

local defaults = {
  app: {
    repoURL: 'https://github.com/gutmensch/argocd.git',
    targetRevision: 'HEAD',
    tenant: ['staging', 'lts'],
    region: 'helsinki',
    directory: 'apps',
    ingressRoot: null,
    ingressDomain: null,
  },
  project: {
    clusterResourceAllowList: [{ group: '', kind: 'Namespace' }],
  },
};
local withAppDef(map) = defaults.app + map;
local withProjDef(map) = defaults.project + map;

//
// --- root projects and apps definitions - app of app pattern
//
local projectList = [
  withProjDef({
    name: 'base',
    desc: 'This project hosts base applications like Jenkins, Backstage, MX, roundcube, dmarc frontend, Nextcloud, etc.',
    clusterResourceAllowList: [
      { group: '', kind: 'Namespace' },
      { group: '', kind: 'ClusterIssuer' },
    ],
  }),
];

local appList = [
  withAppDef({ name: 'internal-root-ca', project: 'base', path: 'internal-root-ca', tenant: ['lts'] }),
//  withAppDef({ name: 'openldap', project: 'base', path: 'openldap', tenant: ['lts'] }),
//  withAppDef({ name: 'keycloak', project: 'base', path: 'keycloak', ingressRoot: 'bln.space', ingressDomain: 'auth' }),
//  withAppDef({ name: 'jenkins', project: 'base', path: 'jenkins', ingressRoot: 'bln.space' }),
//  withAppDef({ name: 'guestbook', project: 'base', path: 'guestbook', ingressRoot 'schumann.link' }),
//  withAppDef({ name: 'foobar', project: 'base', path: 'foobar', ingressRoot: 'schumann.link' }),
];


//
// --- generate resources for ArgoCD
//
local projects = [
  argo.Project(proj.name, [
    if tenant == 'lts' then '%s-%s' % [proj.name, app.name] else '%s-%s-%s' % [proj.name, app.name, tenant]
    for app in appList
    for tenant in app.tenant
    for proj in projectList
  ], proj.desc, proj.clusterResourceAllowList)
  for proj in projectList
];

local apps = [
  argo.Application(tenant, app)
  for app in appList
  for tenant in app.tenant
];

projects + apps
