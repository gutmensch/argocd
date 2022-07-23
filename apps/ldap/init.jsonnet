local kube = import '../../lib/kube.libsonnet';
local base = import 'resources/base.libsonnet';
// generated with script to seal from bitwarden
local secrets = import 'resources/sealedSecrets.libsonnet';

function(name, namespace, project, tenant, region)
  local resources = base.generate(name, namespace) + secrets[tenant];

  kube.List() {
    items_+: resources,
  }
