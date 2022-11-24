{
  default: {
    imageRegistry: 'registry.lan:5000',
  },

  staging: {},

  lts: {
    storageClass: 'zfs-fast-xfs',
    storageSize: '30Gi',
    backupMinioEnable: true,
    backupMinioEndpoint: 'http://minio.base-minio-lts.svc.cluster.local:9000',
    backupMinioBucket: 'mysql-backup',
    // XXX: start with 1 and node selector region to for pxc-0 in region
    replicas: 2,
  },
}
