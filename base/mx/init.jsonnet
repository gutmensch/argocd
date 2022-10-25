// local dmarcreport = import '../../lib/component/dmarc-report/init.libsonnet';
local mailserver = import '../../lib/component/mailserver/init.libsonnet';
local helper = import '../../lib/helper.libsonnet';
local kube = import '../../lib/kube.libsonnet';

function(name, namespace, project, tenant, region)

  local componentConfigs = {
    mailserver: helper.configMerge(
      name,
      'mailserver',
      project,
      tenant,
      import 'secret/mailserver.libsonnet',
      import 'config/mailserver.libsonnet',
      import 'config/shared.libsonnet',
      import 'cd/mailserver.json',
    ),
    // dmarcreport: helper.configMerge(
    //   name,
    //   'dmarc-report',
    //   project,
    //   tenant,
    //   import 'secret/dmarcreport.libsonnet',
    //   import 'config/dmarcreport.libsonnet',
    //   import 'config/shared.libsonnet',
    //   import 'cd/dmarcreport.json',
    // ),
  };

  // XXX: prune is expensive and slow, but otherwise many
  // null resources :-/
  local resources = std.prune(
    mailserver.generate(
      name,
      namespace,
      region,
      tenant,
      componentConfigs.mailserver,
    )
    // dmarcreport.generate(
    //   name,
    //   namespace,
    //   region,
    //   tenant,
    //   componentConfigs.dmarcreport,
    // )
  );

  kube.List() {
    items_+: resources,
  }
