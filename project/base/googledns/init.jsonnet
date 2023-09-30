local certIssuer = import '../../../lib/component/cert-issuer/init.libsonnet';
local externalDNS = import '../../../lib/component/external-dns/init.libsonnet';
local helper = import '../../../lib/helper.libsonnet';
local kube = import '../../../lib/kube.libsonnet';

function(name, namespace, project, tenant, region)

  local componentConfigs = {
    externalDNS: helper.configMerge(
      name,
      'external-dns',
      project,
      tenant,
      {},
      {},
      import 'config/external-dns.libsonnet',
      {},
    ),
    certIssuer: helper.configMerge(
      name,
      'cert-issuer',
      project,
      tenant,
      {},
      {},
      import 'config/cert-issuer.libsonnet',
      {},
    ),
  };

  local resources = std.prune(
    externalDNS.generate(
      name,
      namespace,
      region,
      tenant,
      componentConfigs.externalDNS,
    ) +
    certIssuer.generate(
      name,
      namespace,
      region,
      tenant,
      componentConfigs.certIssuer,
    )
  );

  kube.List() {
    items_+: resources,
  }
