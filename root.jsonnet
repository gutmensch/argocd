local kube = import 'lib/kube.libsonnet';
local argo = import 'lib/argo.libsonnet';
local utils = import 'lib/utils.libsonnet';

local projectList = [
  { name: 'schumann', desc: 'tbd' },
];

local appList = [
  { name: 'guestbook', project: 'schumann', tenant: ['test', 'main'], ingress_domain: 'schumann.link', namespace: 'guestbook', location: 'helsinki', storage: 'ssd' },
  { name: 'foobar', project: 'schumann', tenant: ['test', 'main'], ingress_domain: 'schumann.link', namespace: 'guestbook', location: 'helsinki', storage: 'ssd' },
];

local projects = [
  argo.Project(proj.name, proj.desc)
  for proj in projectList
];

local apps = [
  argo.Application(app.name, app.project, 'guestbook')
  for app in appList
];

projects + apps
