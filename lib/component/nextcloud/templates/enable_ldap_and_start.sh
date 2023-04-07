#!/bin/sh
set -eu

exec 1>&2

# configuration of user_ldap plugin injected between entrypoint install and starting php-fpm process
# source and example of entrypoint.sh are here https://github.com/nextcloud/docker/blob/master/25/fpm/Dockerfile#L152
# leverage environment variables defined for container

run_as() {
	if [ "$(id -u)" = "0" ]; then
		su -p "www-data" -s /bin/sh -c "PHP_MEMORY_LIMIT=512M ${1}"
	else
		sh -c "PHP_MEMORY_LIMIT=512M ${1}"
	fi
}

enable_plugin_ldap() {
	find /var/www -type f -exec ls -la {} \;
	echo "enabling user_ldap app."
	run_as 'php /var/www/html/occ app:enable user_ldap'
}

disable_plugin_ldap() {
	echo "disabling user_ldap app."
	run_as 'php /var/www/html/occ app:disable user_ldap'
}

enable_config_ldap() {
	echo "creating new empty ldap configuration."
	run_as 'php /var/www/html/occ ldap:create-empty-config'

}

check_plugin_ldap() {
	run_as 'php /var/www/html/occ app:list' | sed -n "/Enabled:/,/Disabled:/p" | grep -q 'user_ldap:'
}

check_config_ldap() {
	run_as 'php /var/www/html/occ ldap:show-config'
	run_as 'php /var/www/html/occ ldap:show-config' >/dev/null 2>&1
}

test_ldap() {
	run_as 'php /var/www/html/occ ldap:test-config s01' | grep -q 'The configuration is valid and the connection could be established!'
}

configure_ldap() {
	run_as "php /var/www/html/occ ldap:set-config s01 ldapTLS ${LDAP_TLS}"
	run_as "php /var/www/html/occ ldap:set-config s01 ldapUserFilter \"${LDAP_USER_FILTER}\""
	run_as "php /var/www/html/occ ldap:set-config s01 ldapGroupFilter \"${LDAP_GROUP_FILTER}\""
	run_as "php /var/www/html/occ ldap:set-config s01 ldapLoginFilter \"${LDAP_LOGIN_FILTER}\""
	run_as "php /var/www/html/occ ldap:set-config s01 ldapHost ${LDAP_HOST}"
	run_as "php /var/www/html/occ ldap:set-config s01 ldapPort ${LDAP_PORT}"
	run_as "php /var/www/html/occ ldap:set-config s01 ldapBase ${LDAP_BASE_DN}"
	run_as "php /var/www/html/occ ldap:set-config s01 ldapBaseUsers ${LDAP_BASE_USERS_DN}"
	run_as "php /var/www/html/occ ldap:set-config s01 ldapBaseGroups ${LDAP_BASE_GROUPS_DN}"
	run_as "php /var/www/html/occ ldap:set-config s01 ldapGroupMemberAssocAttr ${LDAP_GROUP_MEMBER_ASSOC_ATTR}"
	run_as "php /var/www/html/occ ldap:set-config s01 ldapEmailAttribute ${LDAP_EMAIL_ATTRIBUTE}"
	run_as "php /var/www/html/occ ldap:set-config s01 ldapAgentName \"${LDAP_AGENT_NAME}\""
	run_as "php /var/www/html/occ ldap:set-config s01 ldapAgentPassword \"${LDAP_AGENT_PASSWORD}\""
	run_as "php /var/www/html/occ ldap:set-config s01 ldapUserFilterObjectclass inetOrgPerson"
	run_as "php /var/www/html/occ ldap:set-config s01 ldapUserDisplayName cn"
	run_as "php /var/www/html/occ ldap:set-config s01 ldapGroupDisplayName cn"
	run_as "php /var/www/html/occ ldap:set-config s01 hasMemberOfFilterSupport 1"
	run_as "php /var/www/html/occ ldap:set-config s01 turnOffCertCheck 1"
}

sync_admins_from_ldap() {
	users=$(run_as "php /var/www/html/occ group:list --output json" | sed -e 's%.*NextcloudAdmin":\[\([^]]*\)\].*%\1%' | tr -d '"' | tr ',' ' ')
	for u in $users; do
		echo "adding user ${u} to nextcloud admin group"
		run_as "php /var/www/html/occ group:adduser admin ${u}"
	done
}

# run ldap integration functions
if ! check_plugin_ldap; then
	enable_plugin_ldap
fi

if ! check_config_ldap; then
	enable_config_ldap
fi

configure_ldap

for try in 1 2 3 4 5; do
	if ! test_ldap; then
		echo "testing ldap failed (${try})."
		sleep 1
	else
		echo "testing ldap succeeded (${try})."
		sync_admins_from_ldap
		break
	fi
	disable_plugin_ldap
done

# run original docker container command
exec php-fpm
