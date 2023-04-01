{
  default: {
    ldapAdmin: 'admin',
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
