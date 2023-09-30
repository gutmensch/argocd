local mysqlBackup = import '../../../lib/component/mysql-backup/init.libsonnet';
local mysqlSingleNode = import '../../../lib/component/mysql-single-node/init.libsonnet';
local mysqlUser = import '../../../lib/component/mysql-user/init.libsonnet';
local helper = import '../../../lib/helper.libsonnet';
local kube = import '../../../lib/kube.libsonnet';

function(name, namespace, project, tenant, region)

  local componentConfigs = {
    mysqlSingleNode: helper.configMerge(
      name,
      'mysql-single-node',
      project,
      tenant,
      import 'secret/shared.libsonnet',
      import 'config/mysql-single-node.libsonnet',
      {},
      {},
    ),
    mysqlUser: helper.configMerge(
      name,
      'mysql-user',
      project,
      tenant,
      import 'config/mysql-user.libsonnet',
      import 'secret/shared.libsonnet',
      {},
      {},
    ),
    mysqlBackup: helper.configMerge(
      name,
      'mysql-backup',
      project,
      tenant,
      import 'secret/shared.libsonnet',
      import 'config/mysql-single-node.libsonnet',
      {},
      {},
    ),
  };

  local resources = std.prune(
    mysqlSingleNode.generate(
      name,
      namespace,
      region,
      tenant,
      componentConfigs.mysqlSingleNode,
    ) +
    mysqlUser.generate(
      name,
      namespace,
      region,
      tenant,
      componentConfigs.mysqlUser,
    ) +
    mysqlBackup.generate(
      name,
      namespace,
      region,
      tenant,
      componentConfigs.mysqlBackup,
    ).backupJobs
  );

  kube.List() {
    items_+: resources,
  }
