local kube = import 'kube.libsonnet';

{
  // self signed cluster issuer created on cluster bootstrapping
  local selfSignedIssuer = 'selfsigned',
  local localIssuer = 'local-root-ca',

  serverCert(name, namespace, createIssuer, dnsNames, labels, ipAddresses=[], keySize=2048, duration='2160h', renewBefore='360'): {

    [if createIssuer then 'localrootcacert']: kube._Object('cert-manager.io/v1', 'Certificate', localIssuer) {
      metadata+: {
        namespace: namespace,
        labels+: labels,
      },
      spec+: {
        commonName: localIssuer,
        isCA: true,
        issuerRef: {
          group: 'cert-manager.io',
  	kind: 'ClusterIssuer',
  	name: selfSignedIssuer,
        },
        privateKey: {
          algorithm: 'ECDSA',
          size: 256,
        },
        secretName: localIssuer,
      }
    },
  
    [if createIssuer then 'localcertissuer']: kube._Object('cert-manager.io/v1', 'Issuer', localIssuer) {
      metadata+: {
        namespace: namespace,
        labels+: labels,
      },
      spec: {
        ca: {
          secretName: localIssuer,
        },
      },
    },
  
    assert std.length(dnsNames) > 0: 'server certificate needs at least one dnsNames list entry',
  
    localservercert: kube._Object('cert-manager.io/v1', 'Certificate', '%s-server-cert' % [name]) {
      metadata+: {
        namespace: namespace,
        labels+: labels,
      },
      spec+: {
        commonName: dnsNames[0],
        dnsNames: dnsNames,
        duration: duration,
        ipAddresses: ipAddresses,
        isCA: false,
        issuerRef: {
          group: 'cert-manager.io',
          kind: 'Issuer',
          name: localIssuer,
        },
        privateKey: {
          algorithm: 'RSA',
          encoding: 'PKCS1',
          size: keySize,
        },
        renewBefore: renewBefore,
        secretName: '%s-server-cert' % [name],
        secretTemplate: {
          annotations: {},
          labels: {},
        },
        subject: {
          organizations: [
            'ArgoCD',
          ],
        },
        uris: [],
        usages: [
          'server auth',
          'client auth',
        ],
      },
    }
  }
}
