local memcached = import '../../../lib/component/memcached/init.libsonnet';
local wordpress = import '../../../lib/component/wordpress/init.libsonnet';
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
    wordpress: helper.configMerge(
      name,
      'eastcoast23',
      project,
      tenant,
      // inheriting user secrets directly from mysql definition
      import '../../base/mysqldb/secret/shared.libsonnet',
      import 'secret/wordpress.libsonnet',
      import 'config/wordpress.libsonnet',
      {},
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
    wordpress.generate(
      name,
      namespace,
      region,
      tenant,
      componentConfigs.wordpress,
    )
  );

  kube.List() {
    items_+: resources,
  }
