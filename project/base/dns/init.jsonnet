local dns = import '../../../lib/component/dnsinwx/init.libsonnet';
local helper = import '../../../lib/helper.libsonnet';
local kube = import '../../../lib/kube.libsonnet';

function(name, namespace, project, tenant, region)

  // import mta sts policy content to generate id from it for DNS record (see https://datatracker.ietf.org/doc/html/rfc8461#section-3.1)
  local policyId = helper.strToRandInt(
    std.toString(std.get(std.get(import '../mtasts/config/mtasts.libsonnet', 'default'), 'defaultPolicy'))
  );
  local dnsConfig = import '../dns/config/dnsinwx.libsonnet';

  local _dnsConfig = dnsConfig {
    lts+: {
      domains+: {
        defaultRecords:: dnsConfig.lts.domains.defaultRecords + [
          { name: '_mta-sts', rtype: 'TXT', content: 'v=STSv1; id=%d;' % [policyId] },
        ],
      },
    },
  };

  local componentConfigs = {
    dns: helper.configMerge(
      name,
      'dnsinwx',
      project,
      tenant,
      import 'secret/dnsinwx.libsonnet',
      _dnsConfig,
      import 'config/shared.libsonnet',
      import 'cd/dnsinwx.json',
    ),
  };

  // XXX: prune is expensive and slow, but otherwise many
  // null resources :-/
  local resources = std.prune(
    dns.generate(
      name,
      namespace,
      region,
      tenant,
      componentConfigs.dns,
    )
  );

  kube.List() {
    items_+: resources.jobs + resources.configmaps + resources.configmapjobs + resources.secrets,
  }
