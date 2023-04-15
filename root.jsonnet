local argo = import 'lib/argo.libsonnet';
local vars = import 'vars.libsonnet';

// --- generate resources for ArgoCD
local projects = [
  argo.Project(proj.name,
               std.prune([
                 if app.project == proj.name then '%s-%s-%s' % [proj.name, app.name, tenant] else null
                 for app in vars.appList
                 for tenant in app.tenant
               ] + proj.additionalNamespaces),
               proj.desc,
               proj.clusterResourceAllowList)
  for proj in vars.projectList
];

local crds = std.prune([
  argo.YamlApplication(crdColl)
  for crdColl in vars.crdList
]);

local resources = std.prune([
  argo.YamlApplication(resourceColl)
  for resourceColl in vars.resourceList
]);

local apps = [
  argo.Application(tenant, app)
  for app in vars.appList
  for tenant in app.tenant
];

projects + crds + resources + apps
