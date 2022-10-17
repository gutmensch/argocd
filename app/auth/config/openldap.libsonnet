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
    ldapInitMailDomains: ['bln.space', 'schumann.link', 'n-os.org', 'remembrance.de', 'robattix.com', 'robattix.gmbh', 'robattix.de', 'kubectl.me', 'stairbud.de', 'stairbud.com'],
  },
}
