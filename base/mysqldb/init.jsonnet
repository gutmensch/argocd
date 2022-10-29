local mysqlCluster = import '../../lib/component/mysql-cluster/init.libsonnet';
local mysqlUser = import '../../lib/component/mysql-user/init.libsonnet';
local helper = import '../../lib/helper.libsonnet';
local kube = import '../../lib/kube.libsonnet';

function(name, namespace, project, tenant, region)

  local componentConfigs = {
    mysqlCluster: helper.configMerge(
      name,
      'mysql-cluster',
      project,
      tenant,
      import 'secret/shared.libsonnet',
      import 'config/mysql-cluster.libsonnet',
      {},
      {},
    ),
    mysqlUser: helper.configMerge(
      name,
      'mysql-user',
      project,
      tenant,
      import 'secret/mysql-user.libsonnet',
      import 'config/mysql-user.libsonnet',
      import 'secret/shared.libsonnet',
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
    ) +
    mysqlUser.generate(
      name,
      namespace,
      region,
      tenant,
      componentConfigs.mysqlUser,
    )
  );

  kube.List() {
    items_+: resources,
  }
