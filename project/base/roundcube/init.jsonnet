local memcached = import '../../../lib/component/memcached/init.libsonnet';
local roundcube = import '../../../lib/component/roundcube/init.libsonnet';
local helper = import '../../../lib/helper.libsonnet';
local kube = import '../../../lib/kube.libsonnet';

function(name, namespace, project, tenant, region)

  local componentConfigs = {
    memcached: helper.configMerge(
      name,
      'memcached',
      project,
      tenant,
      {},
      {},
      {},
      {},
    ),
    roundcube: helper.configMerge(
      name,
      'roundcube',
      project,
      tenant,
      // inheriting user secrets directly from mysql definition
      import '../mysqldb/secret/shared.libsonnet',
      import 'secret/roundcube.libsonnet',
      import 'config/roundcube.libsonnet',
      import 'cd/roundcube.json',
    ),
  };

  local resources = std.prune(
    memcached.generate(
      name,
      namespace,
      region,
      tenant,
      componentConfigs.memcached,
    ) +
    roundcube.generate(
      name,
      namespace,
      region,
      tenant,
      componentConfigs.roundcube,
    )
  );

  kube.List() {
    items_+: resources,
  }
