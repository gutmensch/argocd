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

# runCommand ($@)
# Run custom mc command
runCommand() {
	${MC} "$@"
	return $?
}

# Try connecting to MinIO instance
scheme=https
connectToMinio $scheme
