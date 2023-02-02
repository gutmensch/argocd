{
  default: {
    imageRegistry: 'registry.lan:5000',
  },

  staging: {
    storageClass: 'zfs-fast-xfs',
    storageSize: '10Gi',
    backupEnable: false,
  },

  lts: {
    storageClass: 'zfs-fast-xfs',
    storageSize: '30Gi',
    backupMinioEnable: true,
    backupMinioEndpoint: 'http://minio.base-minio-lts.svc.cluster.local:9000',
    backupMinioBucket: 'mysql-backup',
  },
}
