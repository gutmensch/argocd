{
  default: {
    imageRegistry: 'registry.lan:5000',
    ldapAdmin: 'admin',
    ldapSvc: 'openldap.base-auth-lts.svc.cluster.local',
    ldapRoot: 'o=auth,dc=local',
  },

  staging: {
    ingress: 'ldapadmin-test.stg.kubectl.me',
  },

  lts: {
    ingress: 'ldapadmin-test.kubectl.me',
  },
}
