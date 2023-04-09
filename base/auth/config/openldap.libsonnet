{
  default: {
    storageClass: 'zfs-fast-xfs',
    ldapRoot: 'o=auth,dc=local',
    cronjobCommand: 'sleep 7150',
    cronjobTargetContainerCommand: 'echo foo',
    cronjobTargetContainerName: 'openldap',
    cronjobTargetPodSelector: {
      'app.kubernetes.io/name': 'openldap',
      'app.kubernetes.io/component': 'openldap',
    },
    cronjobInterval: '45 */2 * * *',
  },

  staging: {
    ldapInitMailDomains: ['stg.kubectl.me'],
  },

  lts: {
    ldapInitMailDomains: ['bln.space', 'schumann.link', 'n-os.org', 'remembrance.de', 'robattix.com', 'robattix.gmbh', 'robattix.de', 'kubectl.me', 'stairbud.de', 'stairbud.com'],
  },
}
