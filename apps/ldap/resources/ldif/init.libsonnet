local helper = import '../../../lib/helper.libsonnet';

{
  ldapBase:: error 'need to provide ldap base',
  ldapMailDomains:: [],

  _00root: {
    local t = std.split($.ldapBase, ','),
    dn: $.ldapBase,
    objectClass: ['dcObject', 'organization'],
    dc: std.split(t[1], '=')[1],
    o: std.split(t[0], '=')[1],
  },

  _01mailOU: {
    dn: 'ou=Mail,%s' % [$.ldapBase],
    ou: 'Mail',
    description: 'Mail',
    objectClass: 'organizationalUnit',
  },

  _02mailDomainOU: {
    dn: 'ou=Domain,ou=Mail,%s' % [$.ldapBase],
    ou: 'Domain',
    description: 'Mail domains',
    objectClass: 'organizationalUnit',
  },

  _03mailDomain: [
    {
      dn: 'dc=%s,ou=Domain,ou=Mail,%s' % [vdomain, $.ldapBase],
      dc: '%s' % [vdomain],
      objectClass: 'dNSDomain',
    }
    for vdomain in $.ldapMailDomains
  ],

  _04serviceAccount: {
    dn: 'ou=ServiceAccount,%s' % [$.ldapBase],
    ou: 'ServiceAccount',
    description: 'Service accounts',
    objectClass: 'organizationalUnit',
  },

  _05people: {
    dn: 'ou=People,%s' % [$.ldapBase],
    ou: 'People',
    description: 'Users in Directory, manageable in Keycloak',
    objectClass: 'organizationalUnit',
  },

  _06group: {
    dn: 'ou=Group,%s' % [$.ldapBase],
    ou: 'Group',
    description: 'Groups for People in Directory',
    objectClass: 'organizationalUnit',
  },

  // XXX: finish this after testing
  //
  // _07nextcloudAdminGroup: {
  //   dn: 'cn=Nextcloud Admin,ou=Group,%s' % [$.ldapBase],
  //   description: 'Nextcloud Admin Group',
  //   gidNumber: 2501,
  //   objectClass: ['top', 'groupOfNames', 'posixGroup', 'nextcloudGroup'],
  // },

  // _08nextcloudUserGroup: {
  //   dn: 'cn=Nextcloud User,ou=Group,%s' % [$.ldapBase],
  //   description: 'Nextcloud User Group',
  //   gidNumber: 2502,
  //   objectClass: ['top', 'posixGroup', 'nextcloudGroup'],
  // },

  // _09nextcloudViewerGroup: {
  //   dn: 'cn=Nextcloud Viewer,ou=Group,%s' % [$.ldapBase],
  //   description: 'Nextcloud Viewer Group',
  //   gidNumber: 2503,
  //   objectClass: ['top', 'posixGroup', 'nextcloudGroup'],
  // },

  // _10KeycloakRole: {
  //   dn: 'ou=Role,%s' % [$.ldapBase],
  //   ou: 'Role',
  //   description: 'Role assignable by Keycloak mapper',
  //   objectClass: 'organizationalUnit',
  // },
}
