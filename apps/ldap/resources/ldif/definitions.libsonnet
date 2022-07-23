local helper = import '../../../lib/helper.libsonnet';

{
  ldapBase:: error 'need to provide ldap base',
  ldapMailDomains:: [],

  _01mailOU: {
    dn: 'ou=Mail,%s' % [$.ldapBase],
    ou: 'Mail',
    description: 'Mail',
    objectClass: 'organizationalUnit',
  },

  _02mailDomainOU: {
    dn: 'ou=Domains,ou=Mail,%s' % [$.ldapBase],
    ou: 'Domains',
    description: 'Mail domains',
    objectClass: 'organizationalUnit',
  },

  _03mailDomains: [
    {
      dn: 'dc=%s,ou=Domains,ou=Mail,%s' % [vdomain, $.ldapBase],
      dc: '%s' % [vdomain],
      objectClass: 'dNSDomain',
    }
    for vdomain in $.ldapMailDomains
  ],
}
