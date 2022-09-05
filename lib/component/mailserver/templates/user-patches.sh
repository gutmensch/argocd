#!/bin/bash

# replace opendkim config keys with ldap queries
sed -i "s%^SigningTable.*$%SigningTable ldap://${LDAP_SERVER_HOST}/${LDAP_SEARCH_BASE}?DKIMSelector?sub?(DKIMIdentity=\$d)%" /etc/opendkim.conf
sed -i "s%^KeyTable.*$%KeyTable ldap://${LDAP_SERVER_HOST}/${LDAP_SEARCH_BASE}?DKIMDomain,DKIMSelector,DKIMKey,?sub?(DKIMSelector=\$d)%" /etc/opendkim.conf
echo "LDAPBindUser ${LDAP_BIND_DN}" >> /etc/opendkim.conf
echo "LDAPBindPassword ${LDAP_BIND_PW}" >> /etc/opendkim.conf
echo "LDAPUseTLS true" >> /etc/opendkim.conf

# create local trustedHosts file
> /etc/opendkim/TrustedHosts
for h in $OPENDKIM_TRUSTED_HOSTS; do
  echo $h >> /etc/opendkim/TrustedHosts
done
