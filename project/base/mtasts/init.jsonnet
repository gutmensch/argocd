local mtasts = import '../../../lib/component/mta-sts/init.libsonnet';
local helper = import '../../../lib/helper.libsonnet';
local kube = import '../../../lib/kube.libsonnet';

function(name, namespace, project, tenant, region)

  local componentConfigs = {
    mtasts: helper.configMerge(
      name,
      'mtasts',
      project,
      tenant,
      // inheriting user secrets directly from mysql definition
      {},
      import 'config/mtasts.libsonnet',
      {},
      {},
    ),
  };

  local resources = std.prune(
    mtasts.generate(
      name,
      namespace,
      region,
      tenant,
      componentConfigs.mtasts,
    )
  );

  kube.List() {
    items_+: resources,
  }
