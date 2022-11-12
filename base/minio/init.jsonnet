local minio = import '../../lib/component/minio/init.libsonnet';
local helper = import '../../lib/helper.libsonnet';
local kube = import '../../lib/kube.libsonnet';

function(name, namespace, project, tenant, region)

  local componentConfigs = {
    minio: helper.configMerge(
      name,
      'minio',
      project,
      tenant,
      import 'secret/minio.libsonnet',
      import 'config/minio.libsonnet',
      {},
      import 'cd/minio.json',
    ),
  };

  local resources = std.prune(
    minio.generate(
      name,
      namespace,
      region,
      tenant,
      componentConfigs.minio,
    )
  );

  kube.List() {
    items_+: resources,
  }
