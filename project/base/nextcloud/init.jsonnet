local cronjob = import '../../../lib/component/container-cronjob/init.libsonnet';
local nextcloud = import '../../../lib/component/nextcloud/init.libsonnet';
local redis = import '../../../lib/component/redis/init.libsonnet';
local helper = import '../../../lib/helper.libsonnet';
local kube = import '../../../lib/kube.libsonnet';

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
    cronjob: helper.configMerge(
      name,
      'cronjob',
      project,
      tenant,
      {},
      import 'config/nextcloud.libsonnet',
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
    cronjob.generate(
      name,
      namespace,
      region,
      tenant,
      componentConfigs.cronjob,
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
