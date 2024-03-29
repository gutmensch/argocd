#!/bin/sh
set -e # Have script exit in the event of a failed command.
MC_CONFIG_DIR="/etc/minio/mc/"
MC="/usr/bin/mc --insecure --config-dir ${MC_CONFIG_DIR}"

# AccessKey and secretkey credentials file are added to prevent shell execution errors caused by special characters.
# Special characters for example : ',",<,>,{,}
MINIO_ACCESSKEY_SECRETKEY_TMP="/tmp/accessKey_and_secretKey_tmp"

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

# checkUserExists ()
# Check if the user exists, by using the exit code of `mc admin user info`
checkUserExists() {
	CMD=$(${MC} admin user info myminio $(head -1 $MINIO_ACCESSKEY_SECRETKEY_TMP) >/dev/null 2>&1)
	return $?
}

# createUser ($policy)
createUser() {
	POLICY=$1
	#check accessKey_and_secretKey_tmp file
	if [[ ! -f $MINIO_ACCESSKEY_SECRETKEY_TMP ]]; then
		echo "credentials file does not exist"
		return 1
	fi
	if [[ $(cat $MINIO_ACCESSKEY_SECRETKEY_TMP | wc -l) -ne 2 ]]; then
		echo "credentials file is invalid"
		rm -f $MINIO_ACCESSKEY_SECRETKEY_TMP
		return 1
	fi
	USER=$(head -1 $MINIO_ACCESSKEY_SECRETKEY_TMP)
	# Create the user if it does not exist
	if ! checkUserExists; then
		echo "Creating user '$USER'"
		cat $MINIO_ACCESSKEY_SECRETKEY_TMP | ${MC} admin user add myminio
	else
		echo "User '$USER' already exists."
	fi
	#clean up credentials files.
	rm -f $MINIO_ACCESSKEY_SECRETKEY_TMP

	# set policy for user
	if [ ! -z $POLICY -a $POLICY != " " ]; then
		echo "Adding policy '$POLICY' for '$USER'"
		${MC} admin policy attach myminio $POLICY --user $USER
	else
		echo "User '$USER' has no policy attached."
	fi
}

# Try connecting to MinIO instance
scheme=https
connectToMinio $scheme

# Create the users
# echo console > $MINIO_ACCESSKEY_SECRETKEY_TMP
# echo console123 >> $MINIO_ACCESSKEY_SECRETKEY_TMP
# createUser consoleAdmin
