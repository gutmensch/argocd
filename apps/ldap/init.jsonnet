local kube = import '../../lib/kube.libsonnet';
local base = import 'resources/base.libsonnet';
local phpldapadmin = import 'resources/phpldapadmin.libsonnet';
// generated with script to seal from bitwarden
local secrets = import 'resources/sealedSecrets.libsonnet';

function(name, namespace, project, tenant, region)
  local resources = std.prune(
    base.generate(
      name,
      namespace,
      base='o=auth,dc=local',
      schemas=['virtualmail', 'nextcloud'],
      mailDomains=['bln.space', 'schumann.link', 'n-os.org', 'robattix.com', 'kubectl.me'],
    ) +
    phpldapadmin.generate(
      name,
      namespace,
      ingress='ldapadmin.kubectl.me',
      ldapBase='o=auth,dc=local',
      ldapAdmin='configadmin',
      ldapSvc='%s.%s.svc.cluster.local' % [name, namespace],
    ) +
    secrets[tenant]
  );

  kube.List() {
    items_+: resources,
  }
