local helper = import '../../../lib/helper.libsonnet';

// add config: ldapadd -Y EXTERNAL -Q -H ldapi:/// -f memberof.ldif
// modify: LDAPTLS_REQCERT=never ldapmodify -ZZ -D "cn=admin,cn=config" -w "$LDAP_CONFIG_ADMIN_PASSWORD" -H ldap://ldap.base-ldap-lts.svc.cluster.local -f /tmp/index.ldif
// check modules: slapcat -n 0 -F /bitnami/openldap/slapd.d | grep olcModuleLoad
// https://tylersguides.com/guides/openldap-memberof-overlay/#configuration_tag

{
  ldapModules:: [],

  local this = self,

  add: {
    _01modules: [
      {
        dn: 'cn=module,cn=config',
        cn: 'module',
        objectClass: 'olcModuleList',
        olcModulePath: '/opt/bitnami/openldap/lib/openldap',
        olcModuleLoad: module,
      }
      for module in this.ldapModules
    ],

    [if std.member(this.ldapModules, 'memberof') then '_02memberOfOverlay']: {
      dn: 'olcOverlay=memberof,olcDatabase={2}mdb,cn=config',
      objectClass: ['olcOverlayConfig', 'olcMemberOf'],
      olcOverlay: 'memberof',
      olcMemberOfRefint: 'TRUE',
    },
  },

  modify: {
    _03indexMailAlias: {
      dn: 'olcDatabase={2}mdb,cn=config',
      add: 'olcdbindex',
      olcdbindex: 'mailAlias eq,sub',
    },

    _04indexMailDrop: {
      dn: 'olcDatabase={2}mdb,cn=config',
      add: 'olcdbindex',
      olcdbindex: 'mailAlias eq,sub',
    },

    _05indexVirtualDomains: {
      dn: 'olcDatabase={2}mdb,cn=config',
      add: 'olcdbindex',
      olcdbindex: 'dc eq',
    },
  },
}
