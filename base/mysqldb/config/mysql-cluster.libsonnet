{
  default: {
    imageRegistry: 'registry.lan:5000',
  },

  staging: {},

  lts: {
    storageClass: 'fast',
    storageSize: '30Gi',
    backupStorageClass: 'slow',
    backupStorageSize: '100Gi',
  },
}
