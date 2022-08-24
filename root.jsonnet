local argo = import 'lib/argo.libsonnet';

local defaults = {
  app: {
    repoURL: 'https://github.com/gutmensch/argocd.git',
    targetRevision: 'HEAD',
    tenant: ['staging', 'lts'],
    region: 'helsinki',
    directory: 'app',
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
    ],
  }),
];

local appList = [
  //withAppDef({ name: 'auth', project: 'base', path: 'auth', tenant: ['lts'] }),
  //  withAppDef({ name: 'mx', project: 'base', path: 'mx', tenant: ['lts'], ingressRoot: 'bln.space', ingressPrefix: ['mx', 'dmarc'] }),
  //  withAppDef({ name: 'keycloak', project: 'base', path: 'keycloak', tenant: ['lts'] ingressRoot: 'bln.space', ingressPrefix: 'auth' }),
  //  withAppDef({ name: 'jenkins', project: 'base', path: 'jenkins', ingressRoot: 'bln.space' }),
  //  withAppDef({ name: 'guestbook', project: 'base', path: 'guestbook', ingressRoot 'schumann.link' }),
  //  withAppDef({ name: 'foobar', project: 'base', path: 'foobar', ingressRoot: 'schumann.link' }),
];


//
// --- generate resources for ArgoCD
//
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

local apps = [
  argo.Application(tenant, app)
  for app in appList
  for tenant in app.tenant
];

projects + apps
