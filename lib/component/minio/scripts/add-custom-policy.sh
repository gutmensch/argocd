#!/bin/sh

source /config/add-policy

# Adjust admin policy to ldap group
${MC} admin policy set --consoleAdmin group='__MINIO_ADMIN_LDAP_GROUP_DN__'
