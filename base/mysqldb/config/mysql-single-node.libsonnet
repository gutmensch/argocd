{
  default: {},

  staging: {
    storageClass: 'zfs-fast-xfs',
    storageSize: '10Gi',
    backupEnable: false,
  },

  lts: {
    storageClass: 'zfs-fast-xfs',
    storageSize: '30Gi',
    backupMinioEnable: true,
    backupMinioEndpoint: 'https://minio.base-minio-lts.svc.kubectl.me:9000',
    backupMinioBucket: 'mysql-backup',
  },
}
