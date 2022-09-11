{
  default: {
    imageRegistry: 'registry.lan:5000',
    storageClass: 'fast',
    ldapRoot: 'o=auth,dc=local',
  },

  staging: {
    ldapInitMailDomains: ['stg.kubectl.me'],
  },

  lts: {
    mailStorageSize: '150Gi',
    stateStorageSize: '5Gi',
    ldapEnable: true,
    publicFQDN: 'mx.bln.space',
  },
}
