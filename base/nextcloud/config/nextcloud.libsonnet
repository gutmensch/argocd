{
  default: {
    storageClass: 'zfs-fast-xfs',
  },

  staging: {
  },

  lts: {
    publicFQDN: 'cloud.bln.space',
    storageSize: '20Gi',
    mysqlHost: 'mysql.base-mysqldb-lts.svc.cluster.local',
    mysqlPort: 3306,
    mailDomain: 'bln.space',
    smtpHost: 'mailserver.base-mx-lts.svc.cluster.local',
    smtpSecure: 'ssl',
    smtpPort: 25,
    smtpAuthType: 'None',
    s3Host: 'minio.base-minio-lts.svc.cluster.local',
    s3Bucket: 'nextcloud',
    s3Port: 9000,
    s3UseSSL: false,
    s3UsePathStyle: true,
    s3AutoCreate: false,
  },
}
