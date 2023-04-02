local nextcloud = import '../../lib/component/nextcloud/init.libsonnet';
local redis = import '../../lib/component/redis/init.libsonnet';
local helper = import '../../lib/helper.libsonnet';
local kube = import '../../lib/kube.libsonnet';

function(name, namespace, project, tenant, region)

  local componentConfigs = {
    redis: helper.configMerge(
      name,
      'redis',
      project,
      tenant,
      import 'secret/shared.libsonnet',
      import 'config/redis.libsonnet',
      {},
      {},
    ),
    nextcloud: helper.configMerge(
      name,
      'nextcloud',
      project,
      tenant,
      import 'secret/nextcloud.libsonnet',
      import 'config/nextcloud.libsonnet',
      // inheriting user secrets directly from mysql definition
      import '../mysqldb/secret/shared.libsonnet',
      import 'secret/shared.libsonnet',
    ),
  };

  // XXX: prune is expensive and slow, but otherwise many
  // null resources :-/
  local resources = std.prune(
    redis.generate(
      name,
      namespace,
      region,
      tenant,
      componentConfigs.redis,
    ) +
    nextcloud.generate(
      name,
      namespace,
      region,
      tenant,
      componentConfigs.nextcloud,
    )
  );

  kube.List() {
    items_+: resources,
  }
