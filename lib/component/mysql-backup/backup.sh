#!/bin/sh

TARGET=/var/backup

prepare_mysqldump_credentials() {
  umask 077
  cat <<EOF> $HOME/.my.cnf
[mysqldump]
user=root
password=$MYSQL_ROOT_PASSWORD
EOF
}

dump_database() {
  prepare_mysqldump_credentials
  date=$(date +%s)
  backup_file=$TARGET/mysql_$1_$date.sql.gz
  mysqldump --single-transaction $1 | gzip -9 > $backup_file
  if [ $? -eq 0 ]; then
	  echo $backup_file
  else
	  exit 1
  fi
}

upload_file() {
  # about the file
  file_to_upload=$1
  bucket=$BUCKET
  filepath="/${bucket}/$(basename $file_to_upload)"
  
  # metadata
  contentType="application/x-compressed-tar"
  dateValue=`date -R`
  signature_string="PUT\n\n${contentType}\n${dateValue}\n${filepath}"
  
  #s3 keys
  s3_access_key=$ACCESS_KEY
  s3_secret_key=$SECRET_KEY
  
  #prepare signature hash to be sent in Authorization header
  signature_hash=`echo -en ${signature_string} | openssl sha1 -hmac ${s3_secret_key} -binary | base64`
  
  # actual curl command to do PUT operation on s3
  curl -v -X PUT -T "${file_to_upload}" \
    -H "Host: ${ENDPOINT}" \
    -H "Date: ${dateValue}" \
    -H "Content-Type: ${contentType}" \
    -H "Authorization: AWS ${s3_access_key}:${signature_hash}" \
    $ENDPOINT/${filepath}
}

backup=$(dump_database $1)
upload $backup
