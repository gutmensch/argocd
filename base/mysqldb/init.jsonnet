local mysqlCluster = import '../../lib/component/mysql-cluster/init.libsonnet';
local helper = import '../../lib/helper.libsonnet';
local kube = import '../../lib/kube.libsonnet';

function(name, namespace, project, tenant, region)

  local componentConfigs = {
    mysqlCluster: helper.configMerge(
      name,
      'mysql-cluster',
      project,
      tenant,
      import 'secret/mysql-cluster.libsonnet',
      import 'config/mysql-cluster.libsonnet',
      {},
      {},
    ),
  };

  local resources = std.prune(
    mysqlCluster.generate(
      name,
      namespace,
      region,
      tenant,
      componentConfigs.mysqlCluster,
    )
  );

  kube.List() {
    items_+: resources,
  }
