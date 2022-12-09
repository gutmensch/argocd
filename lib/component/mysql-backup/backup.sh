#!/bin/sh

TARGET=/var/backup
_ACCESS_KEY=
_SECRET_KEY=

cleanup() {
  echo
  rm -vf $TARGET/.my.cnf
  rm -vf $TARGET/*.sql.gz
}

get_api_keys() {
  # using STS api to get keys for actual use from ldap credentials
  # https://github.com/minio/minio/blob/master/docs/sts/ldap.md
  if [ -z "${_ACCESS_KEY}" -o -z "${_SECRET_KEY}" ]; then
    response=$(curl -o - -s -XPOST $ENDPOINT -d "Action=AssumeRoleWithLDAPIdentity&LDAPUsername=${ACCESS_KEY}&LDAPPassword=${SECRET_KEY}&Version=2011-06-15&DurationSeconds=3600")
  fi
  if echo $response | grep '<Error>'; then
    echo $response
    exit 1
  fi
  _ACCESS_KEY=$(echo $response | sed -r 's%.*<AccessKeyId>(.*)</AccessKeyId>.*%\1%')
  _SECRET_KEY=$(echo $response | sed -r 's%.*<SecretAccessKey>(.*)</SecretAccessKey>.*%\1%')
  echo "Response: ${response}"
  echo "Access Key: ${_ACCESS_KEY}"
  echo "Secret Key: ${_SECRET_KEY}"
}

prepare_mysqldump_credentials() {
  umask 077
  cat <<EOF> $TARGET/.my.cnf
[mysqldump]
host=$MYSQL_HOST
user=root
password=$MYSQL_ROOT_PASSWORD
verbose=TRUE
single-transaction=TRUE
EOF
}

dump_database() {
  prepare_mysqldump_credentials
  date=$(date +%s)
  backup_file=$TARGET/mysql_$1_$date.sql.gz
  mysqldump --defaults-file=$TARGET/.my.cnf $1 | gzip -9 > $backup_file
  if [ $? -eq 0 ]; then
    echo $backup_file
  else
    exit 1
  fi
}

upload() {
  # about the file
  file_to_upload=$1
  bucket=$BUCKET
  filepath="/${bucket}/$(basename $file_to_upload)"
  
  # metadata
  contentType="application/octet-stream"
  dateValue=`date -R`
  signature_string="PUT\n\n${contentType}\n${dateValue}\n${filepath}"

  get_api_keys
  
  #prepare signature hash to be sent in Authorization header
  signature_hash=$(echo -en ${signature_string} | openssl sha1 -hmac ${_SECRET_KEY} -binary | base64)

  hostValue=$(echo $ENDPOINT | sed 's%http://%%')
  # actual curl command to do PUT operation on s3
  curl -s -v -X PUT -T "${file_to_upload}" \
    -H "Host: ${hostValue}" \
    -H "Date: ${dateValue}" \
    -H "Content-Type: ${contentType}" \
    -H "Authorization: AWS ${_ACCESS_KEY}:${signature_hash}" \
    ${ENDPOINT}${filepath}
}

trap cleanup EXIT
backup=$(dump_database $1)
upload $backup
