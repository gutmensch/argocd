local kube = import '../../lib/kube.libsonnet';
local base = import 'resources/base.libsonnet';
local phpldapadmin = import 'resources/phpldapadmin.libsonnet';
// generated with script to seal from bitwarden
local secrets = import 'resources/sealedSecrets.libsonnet';

function(name, namespace, project, tenant, region)

  local ldapRoot = 'o=auth,dc=local';

  local resources = std.prune(
    base.generate(
      name,
      namespace,
      root=ldapRoot,
      initMailDomains=['bln.space', 'schumann.link', 'n-os.org', 'robattix.com', 'kubectl.me'],
    ) +
    phpldapadmin.generate(
      name,
      namespace,
      ingress='ldapadmin.kubectl.me',
      ldapRoot=ldapRoot,
      ldapAdmin='admin',
      ldapSvc='%s.%s.svc.cluster.local' % [name, namespace],
    ) +
    secrets[tenant]
  );

  kube.List() {
    items_+: resources,
  }
