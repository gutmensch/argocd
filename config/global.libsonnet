{
  common: {
    // only applied to images without own registry definition (i.e. docker hub images)
    // local registry is pull through mirror for docker hub
    imageRegistryMirror: 'registry.lan:5000',
    allowList: [
      // Telekom DSL
      '79.192.0.0/10',
      '46.80.0.0/12',
      '46.78.0.0/15',
      '80.128.0.0/11',
      '84.128.0.0/10',
      '87.128.0.0/11',
      '87.160.0.0/11',
      '91.0.0.0/10',
      '93.192.0.0/10',
      '217.0.0.0/13',
      '217.80.0.0/12',
      '217.224.0.0/11',
      // Hetzner
      '65.108.70.29',
      '65.108.70.42',
      '46.4.71.17',
    ],
  },
  staging: {
    ldapHost: 'openldap.base-auth-staging.svc.cluster.local',
    ldapBaseDN: 'o=auth,dc=local',
    mxInternalHost: 'mx.base-mx-staging.svc.cluster.local',
    mxPublicHost: 'mxstg.bln.space',
  },
  lts: {
    ldapHost: 'openldap.base-auth-lts.svc.cluster.local',
    ldapBaseDN: 'o=auth,dc=local',
    mxInternalHost: 'mx.base-mx-lts.svc.cluster.local',
    mxPublicHost: 'mx.bln.space',
  },
}
