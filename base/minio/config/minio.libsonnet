{
  default: {
  },

  staging: {
  },

  lts: {
    storageClass: 'zfs-slow-xfs',
    storageSize: '250Gi',
    cacheStorageClass: 'zfs-fast-xfs',
    cacheStorageSize: '25Gi',
    buckets: {
      'mysql-backup': { locks: false, versioning: true },
      'openldap-backup': { locks: false, versioning: true },
      nextcloud: { locks: false, versioning: true },
    },
    policies: {
      mysqlBackup: { bucket: 'mysql-backup', actions: ['list', 'write', 'read'], group: 'cn=MinIOMysqlBackup,ou=Group,o=auth,dc=local' },
      openldapBackup: { bucket: 'openldap-backup', actions: ['list', 'write', 'read'], group: 'cn=MinIOOpenLDAPBackup,ou=Group,o=auth,dc=local' },
      nextcloud: { bucket: 'nextcloud', actions: ['*'], group: 'cn=MinIONextcloud,ou=Group,o=auth,dc=local' },
    },
  },
}
