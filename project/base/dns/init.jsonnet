local dns = import '../../../lib/component/dnsinwx/init.libsonnet';
local helper = import '../../../lib/helper.libsonnet';
local kube = import '../../../lib/kube.libsonnet';

function(name, namespace, project, tenant, region)

  local componentConfigs = {
    dns: helper.configMerge(
      name,
      'dnsinwx',
      project,
      tenant,
      import 'secret/dnsinwx.libsonnet',
      import 'config/dnsinwx.libsonnet',
      import 'config/shared.libsonnet',
      import 'cd/dnsinwx.json',
    ),
  };

  // XXX: prune is expensive and slow, but otherwise many
  // null resources :-/
  local resources = std.prune(
    dns.generate(
      name,
      namespace,
      region,
      tenant,
      componentConfigs.dns,
    )
  );

  kube.List() {
    items_+: resources.jobs + resources.configmaps + resources.configmapjobs + resources.secrets,
  }
