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

  _05People: {
    dn: 'ou=People,%s' % [$.ldapBase],
    ou: 'People',
    description: 'Users in Directory, manageable in Keycloak',
    objectClass: 'organizationalUnit',
  },

  _06Groups: {
    dn: 'ou=Group,%s' % [$.ldapBase],
    ou: 'Group',
    description: 'Groups in Directory, manageable in Keycloak',
    objectClass: 'organizationalUnit',
  },

}
