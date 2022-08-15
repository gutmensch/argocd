local kube = import '../../lib/kube.libsonnet';
local base = import 'base/init.libsonnet';
local phpldapadmin = import 'phpldapadmin/init.libsonnet';

function(name, namespace, project, tenant, region, ingress)

  local ldapRoot = 'o=auth,dc=local';
  local version = '2.6.3';
  local labels = {
    'app.kubernetes.io/name': name,
    'app.kubernetes.io/version': version,
    'app.kubernetes.io/managed-by': 'ArgoCD',
  };

  local resources = std.prune(

    base.generate(
      name,
      namespace,
      tenant,
      root=ldapRoot,
      initMailDomains=['bln.space', 'schumann.link', 'n-os.org', 'robattix.com', 'kubectl.me'],
      version=version,
      labels=labels,
    ) +

    phpldapadmin.generate(
      name,
      namespace,
      tenant,
      // TODO: generated list reference from root.jsonnet
      ingress=ingress[0],
      ldapRoot=ldapRoot,
      ldapAdmin='admin',
      ldapSvc='%s.%s.svc.cluster.local' % [name, namespace],
      labels=labels,
    )

  );

  kube.List() {
    items_+: resources,
  }
