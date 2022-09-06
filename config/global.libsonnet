{
  common: {
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
