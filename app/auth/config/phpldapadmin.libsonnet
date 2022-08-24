{
  default: {
    imageRegistry: 'registry.lan:5000',
    imageRef: 'gutmensch/phpldapadmin',
    imageVersion: '1.2.6.3-4',
    ldapAdmin: 'admin',
    ldapSvc: 'openldap.base-auth-lts.svc.cluster.local',
    ldapRoot: 'o=auth,dc=local',
    certIssuer: 'letsencrypt-prod',
  },

  staging: {
    ingress: 'ldapadmin.stg.kubectl.me',
  },

  lts: {
    ingress: 'ldapadmin.kubectl.me',
  },
}
