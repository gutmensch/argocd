{
  lts: {
    mxldapcredentials: {
      apiVersion: 'v1',
      kind: 'Secret',
      metadata: {
        creationTimestamp: null,
        name: 'mxldap',
        namespace: 'base-mx-lts',
      },
      stringData: {
        LDAP_BIND_DN: 'uid=mx,ou=ServiceAccount,o=auth,dc=local',
        LDAP_BIND_PW: 'ENF2gk362bvDgVD5czK2',
        SASLAUTHD_LDAP_BIND_DN: 'uid=mx,ou=ServiceAccount,o=auth,dc=local',
        SASLAUTHD_LDAP_PASSWORD: 'ENF2gk362bvDgVD5czK2',
      },
    },
  },
  staging: {},
}
