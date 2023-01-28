{
  default: {
  },

  staging: {
  },

  lts: {
    consoleIngress: 'minio.kubectl.me',
    storageClass: 'zfs-slow-xfs',
    storageSize: '250Gi',
    cacheStorageClass: 'zfs-fast-xfs',
    cacheStorageSize: '25Gi',
    buckets: {
      'mysql-backup': {
        locks: false,
        versioning: false,
        expiry: 60,
      },
      'openldap-backup': {
        locks: false,
        versioning: false,
        expiry: 180,
      },
      nextcloud: {
        locks: false,
        versioning: false,
      },
    },
    policies: {
      mysqlBackup: {
        bucket: 'mysql-backup',
        actions: ['list', 'write', 'read'],
        group: 'cn=MinIOMysqlBackup,ou=Group,o=auth,dc=local',
      },
      openldapBackup: {
        bucket: 'openldap-backup',
        actions: ['list', 'write', 'read'],
        group: 'cn=MinIOOpenLDAPBackup,ou=Group,o=auth,dc=local',
      },
      nextcloud: {
        bucket: 'nextcloud',
        actions: ['*'],
        group: 'cn=MinIONextcloud,ou=Group,o=auth,dc=local',
      },
    },
  },
}
