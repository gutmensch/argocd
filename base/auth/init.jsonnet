local cronjob = import '../../lib/component/container-cronjob//init.libsonnet';
local openldap = import '../../lib/component/openldap/init.libsonnet';
local phpldapadmin = import '../../lib/component/phpldapadmin/init.libsonnet';
local helper = import '../../lib/helper.libsonnet';
local kube = import '../../lib/kube.libsonnet';

function(name, namespace, project, tenant, region)

  local componentConfigs = {
    openldap: helper.configMerge(
      name,
      'openldap',
      project,
      tenant,
      import 'secret/openldap.libsonnet',
      import 'config/openldap.libsonnet',
      import 'config/shared.libsonnet',
      import 'cd/openldap.json',
    ),
    phpldapadmin: helper.configMerge(
      name,
      'phpldapadmin',
      project,
      tenant,
      {},
      import 'config/phpldapadmin.libsonnet',
      import 'config/shared.libsonnet',
      import 'cd/phpldapadmin.json',
    ),
    cronjob: helper.configMerge(
      name,
      'cronjob',
      project,
      tenant,
      {},
      import 'config/openldap.libsonnet',
      {},
      {},
    ),
  };

  local resources = std.prune(
    openldap.generate(
      name,
      namespace,
      region,
      tenant,
      componentConfigs.openldap,
    ) +
    phpldapadmin.generate(
      name,
      namespace,
      region,
      tenant,
      componentConfigs.phpldapadmin,
    ) +
    cronjob.generate(
      name,
      namespace,
      region,
      tenant,
      componentConfigs.cronjob,
    )
  );

  kube.List() {
    items_+: resources,
  }
