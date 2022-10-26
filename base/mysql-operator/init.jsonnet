local mysqlOperator = import '../../lib/component/mysql-operator/init.libsonnet';
local helper = import '../../lib/helper.libsonnet';
local kube = import '../../lib/kube.libsonnet';

function(name, namespace, project, tenant, region)

  local componentConfigs = {
    mysqlOperator: helper.configMerge(
      name,
      'mysql-operator',
      project,
      tenant,
      {},
      import 'config/mysql-operator.libsonnet',
      {},
      {},
    ),
  };

  local resources = std.prune(
    mysqlOperator.generate(
      name,
      namespace,
      region,
      tenant,
      componentConfigs.mysqlOperator,
    )
  );

  kube.List() {
    items_+: resources,
  }
