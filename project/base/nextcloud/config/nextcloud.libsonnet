{
  default: {
    storageClass: 'zfs-fast-xfs',
    // https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/background_jobs_configuration.html#cron
    cronjobTargetContainerCommand: 'su -p www-data -s /bin/sh -c "php -f /var/www/html/cron.php"',
    cronjobTargetContainerName: 'nextcloud',
    cronjobInstance: 'nextcloud-task-cron',
    cronjobTargetPodSelector: {
      'app.kubernetes.io/name': 'nextcloud',
      'app.kubernetes.io/component': 'nextcloud',
    },
  },

  staging: {
  },

  lts: {
    publicFQDN: 'cloud.bln.space',
    storageSize: '60Gi',
    mysqlHost: 'mysql.base-mysqldb-lts.svc.cluster.local',
    mysqlPort: 3306,
    mailFromAddress: 'nextcloud',
    mailDomain: 'bln.space',
    smtpHost: 'mailserver.base-mx-lts.svc.cluster.local',
    smtpSecure: 'tls',
    smtpPort: 587,
    smtpAuthType: 'LOGIN',
    s3Host: 'minio.base-minio-lts.svc.kubectl.me',
    s3Bucket: 'nextcloud',
    s3Port: 9000,
    s3UseSSL: true,
    s3UsePathStyle: true,
    s3AutoCreate: false,
  },
}
