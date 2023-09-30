local mailserver = import '../../../lib/component/mailserver/init.libsonnet';
local protection = import '../../../lib/component/pod-network-protection/init.libsonnet';
local helper = import '../../../lib/helper.libsonnet';
local kube = import '../../../lib/kube.libsonnet';

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
    // protection: helper.configMerge(
    //   name,
    //   'pod-network-protection',
    //   project,
    //   tenant,
    //   {},
    //   import 'config/pod-network-protection.libsonnet',
    //   {},
    //   {},
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
                    );
                    // protection.generate(
                    //   name,
                    //   namespace,
                    //   region,
                    //   tenant,
                    //   componentConfigs.protection {
                    //     podSelector: componentConfigs.mailserver.labels,
                    //   },
                    // );

  kube.List() {
    items_+: resources,
  }
