local mysqlOperator = import '../../lib/component/xtradb-operator/init.libsonnet';
local helper = import '../../lib/helper.libsonnet';
local kube = import '../../lib/kube.libsonnet';

function(name, namespace, project, tenant, region)

  local componentConfigs = {
    xtradbOperator: helper.configMerge(
      name,
      'xtradb-operator',
      project,
      tenant,
      {},
      import 'config/xtradb-operator.libsonnet',
      {},
      {},
    ),
  };

  local resources = std.prune(
    xtradbOperator.generate(
      name,
      namespace,
      region,
      tenant,
      componentConfigs.xtradbOperator,
    )
  );

  kube.List() {
    items_+: resources,
  }
