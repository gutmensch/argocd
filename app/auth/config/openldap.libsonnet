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
    ldapInitMailDomains: ['bln.space', 'id.bln.space', 'schumann.link', 'n-os.org', 'robattix.com', 'robattix.gmbh', 'kubectl.me', 'remembrance.de'],
  },
}
