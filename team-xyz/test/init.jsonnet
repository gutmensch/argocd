local phpldapadmin = import '../../lib/component/phpldapadmin/init.libsonnet';
local helper = import '../../lib/helper.libsonnet';
local kube = import '../../lib/kube.libsonnet';

function(name, namespace, project, tenant, region)

  local componentConfigs = {
    phpldapadmin: helper.configMerge(
      name,
      'phpldapadmin',
      project,
      tenant,
      import 'secret/phpldapadmin.libsonnet',
      import 'config/phpldapadmin.libsonnet',
      import 'config/shared.libsonnet',
      import 'cd/phpldapadmin.json',
    ),
  };

  local resources = std.prune(
    phpldapadmin.generate(
      name,
      namespace,
      region,
      tenant,
      componentConfigs.phpldapadmin,
    )
  );

  kube.List() {
    items_+: resources,
  }
