{
  default: {
    imageRegistry: 'registry.lan:5000',
    ldapAdmin: 'foobar',
    ldapSvc: 'openldap.base-auth-lts.svc.cluster.local',
    ldapRoot: 'o=auth,dc=local',
  },

  staging: {
    ingress: 'ldapadmin.stg.kubectl.me',
  },

  lts: {
    ingress: 'ldapadmin.kubectl.me',
  },
}
