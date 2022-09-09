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

# copy postscreen access file
cp /tmp/docker-mailserver/postscreen-access.cidr /etc/postfix/postscreen-access.cidr

# add options to dovecot ldap
echo "tls_require_cert = never" >> /etc/dovecot/dovecot-ldap.conf.ext
# set to -1 for verbose ldap output
echo "debug_level = ${DOVECOT_DEBUG_LEVEL}" >> /etc/dovecot/dovecot-ldap.conf.ext
