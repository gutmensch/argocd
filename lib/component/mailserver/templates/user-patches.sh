#!/bin/bash

# replace opendkim config keys with ldap queries
sed -i "s%^SigningTable.*$%SigningTable            ldap://${LDAP_SERVER_HOST}/${LDAP_SEARCH_BASE}?DKIMSelector?sub?(DKIMIdentity=\$d)%" /etc/opendkim.conf
sed -i "s%^KeyTable.*$%KeyTable                ldap://${LDAP_SERVER_HOST}/${LDAP_SEARCH_BASE}?DKIMDomain,DKIMSelector,DKIMKey,?sub?(DKIMSelector=\$d)%" /etc/opendkim.conf
echo "LDAPBindUser            ${LDAP_BIND_DN}" >>/etc/opendkim.conf
echo "LDAPBindPassword        ${LDAP_BIND_PW}" >>/etc/opendkim.conf
echo "LDAPUseTLS              true" >>/etc/opendkim.conf

# create local trustedHosts file
>/etc/opendkim/TrustedHosts
for h in $OPENDKIM_TRUSTED_HOSTS; do
	echo $h >>/etc/opendkim/TrustedHosts
done

# copy postscreen access file
cp /tmp/docker-mailserver/postscreen_access.cidr /etc/postfix/postscreen_access.cidr

# add options to dovecot ldap
echo "tls_require_cert = never" >>/etc/dovecot/dovecot-ldap.conf.ext
# set to -1 for verbose ldap output
echo "debug_level = ${DOVECOT_DEBUG_LEVEL}" >>/etc/dovecot/dovecot-ldap.conf.ext

# discard messages from kubernetes liveness probes in mail logs
RSYSLOG_CONF=/etc/rsyslog.d/01-discard-kubernetes-probe-messages.conf
echo ":msg, contains, \"from unknown[10.244.\"    stop" >>$RSYSLOG_CONF
echo ":msg, contains, \"CONNECT from [10.244.\"    stop" >>$RSYSLOG_CONF
echo ":msg, contains, \"WHITELISTED [10.244.\"    stop" >>$RSYSLOG_CONF

# fix logrotate directory handling even though fsGroup is set (but syslog user and root group?!)
chmod o-w /var/log/mail

# fix for cron mail sending to root@mx.bln.space => root@localhost
sed -i "s%SHELL=%MAILTO=root@localhost\nSHELL=%" /etc/crontab

# generate IP based whitelist for postgrey based on spf records
# and remove upstream whitelist clients domain_list
rm -v /etc/postgrey/whitelist_recipients
apt update && apt install -y dnsutils
domain_list=/tmp/docker-mailserver/postgrey_whitelist_domains.txt
spf_results=$(mktemp -t spfresult.XXX)
postgrey_whitelist_clients=/etc/postgrey/whitelist_clients.local

spf_lookup() {
	for e in $(dig TXT +short $1 | grep -i v=spf); do
		if [[ $e =~ ^include: ]]; then
			spf_lookup ${e#*:} $2
		elif [[ $e =~ ^ip(4|6): ]]; then
			echo ${e#*:} >>$2
		elif [[ $e =~ ^a$ ]]; then
			for record in a aaaa; do
				dig $record $1 +short
			done >>$2
		elif [[ $e =~ ^mx$ ]]; then
			for h in $(dig mx $1 +short | awk '{print $NF}'); do
				dig a $h +short
				dig aaaa $h +short
			done >>$2
		fi
	done
}

# parallelize lookup to save time
for domain in $(cat $domain_list); do
	echo "Adding domain ${domain}'s spf records to postgrey whitelist."
	spf_lookup $domain $spf_results &
done
wait
# XXX: fix for occasional incomplete entries with quotes (:shrug:)
sed -i '/"/d' $spf_results

# v4
cat $spf_results | grep '\.' | sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n | uniq >$postgrey_whitelist_clients
# v6
cat $spf_results | grep '\:' | sort -t : -k 1,1 -k 2,2 -k 3,3 -k 4,4 | uniq >>$postgrey_whitelist_clients

rm -v $spf_results
apt autoremove -y dnsutils
