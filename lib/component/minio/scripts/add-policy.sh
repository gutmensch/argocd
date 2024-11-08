#!/bin/sh
set -e # Have script exit in the event of a failed command.
MC_CONFIG_DIR="/etc/minio/mc/"
MC="/usr/bin/mc --insecure --config-dir ${MC_CONFIG_DIR}"

# connectToMinio
# Use a check-sleep-check loop to wait for MinIO service to be available
connectToMinio() {
	SCHEME=$1
	ATTEMPTS=0
	LIMIT=29 # Allow 30 attempts
	#set -e ; # fail if we can't read the keys.
	#ACCESS=$(cat /config/rootUser) ; SECRET=$(cat /config/rootPassword) ;
	set +e # The connections to minio are allowed to fail.
	echo "Connecting to MinIO server: $SCHEME://$MINIO_ENDPOINT:$MINIO_PORT"
	#MC_COMMAND="${MC} alias set myminio $SCHEME://$MINIO_ENDPOINT:$MINIO_PORT $ACCESS $SECRET" ;
	MC_COMMAND="${MC} alias set myminio $SCHEME://$MINIO_ENDPOINT:$MINIO_PORT $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD"
	$MC_COMMAND
	STATUS=$?
	until [ $STATUS = 0 ]; do
		ATTEMPTS=$(expr $ATTEMPTS + 1)
		echo \"Failed attempts: $ATTEMPTS\"
		if [ $ATTEMPTS -gt $LIMIT ]; then
			exit 1
		fi
		sleep 2 # 1 second intervals between attempts
		$MC_COMMAND
		STATUS=$?
	done
	set -e # reset `e` as active
	return 0
}

# checkPolicyExists ($policy)
# Check if the policy exists, by using the exit code of `mc admin policy info`
checkPolicyExists() {
	POLICY=$1
	CMD=$(${MC} admin policy info myminio $POLICY >/dev/null 2>&1)
	return $?
}

# createPolicy($name, $filename)
createPolicy() {
	NAME=$1
	FILENAME=$2
	LDAPGROUP=$3

	# Create the name if it does not exist
	echo "Checking policy: $NAME (in $FILENAME)"
	if ! checkPolicyExists $NAME; then
		echo "Creating policy '$NAME'"
		${MC} admin policy create myminio $NAME $FILENAME
		sleep 2
	else
		echo "Policy '$NAME' already exists."
	fi
	sleep 2
	if ! ${MC} idp ldap policy entities myminio/ --policy $NAME | /toolbox/grep -q $LDAPGROUP; then
		echo Attaching LDAP group $LDAPGROUP to policy $NAME
		${MC} idp ldap policy attach myminio/ $NAME --group $LDAPGROUP
	else
		echo LDAP group $LDAPGROUP is already attached to $NAME policy
	fi
}

# Try connecting to MinIO instance
scheme=https
connectToMinio $scheme
