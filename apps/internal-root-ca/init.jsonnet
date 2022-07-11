local kube = import '../../lib/kube.libsonnet';
local defaults = {
  local ca = self,
};

function(name, namespace, project, tenant, region)
  local resources = {
    selfsignedclusterissuer: kube._Object('cert-manager.io/v1', 'ClusterIssuer', name) {
      metadata+: {
        name: 'selfsigned-issuer',
	namespace: namespace,
      },
      spec+: {
        selfSigned: {},
      },
    },

    rootcacertificate: kube._Object('cert-manager.io/v1', 'Certificate', name) {
      metadata+: {
        name: name,
	namespace: namespace,
      },
      spec+: {
        isCA: true,
        commonName: name,
        secretName: 'root-ca',
        privateKey: {
          algorithm: 'ECDSA',
          size: 256,
	},
        issuerRef: {
          name: 'selfsigned-issuer',
          kind: 'ClusterIssuer',
          group: 'cert-manager.io',
	},
      },
    },

    rootcaclusterissuer: kube._Object('cert-manager.io/v1', 'ClusterIssuer', name) {
      metadata+: {
        name: name,
	namespace: namespace,
      },
      spec+: {
        ca: {
	  secretName: 'root-ca',
	}
      },
    },
  };

  kube.List() {
    items_+: resources,
  }
