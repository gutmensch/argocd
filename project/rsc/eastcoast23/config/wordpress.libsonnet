{
  default: {},

  staging: {},

  lts: {
    imageVersion: '6.3.1-fpm',
    ingress: 'eastcoast23.schumann.link',
    dbHost: 'mysql.base-mysqldb-lts.svc.cluster.local',
    publicFQDN: 'eastcoast23.schumann.link',
    storageSize: '100Gi',
    mysqlHost: 'mysql.base-mysqldb-lts.svc.cluster.local',
    mysqlPort: 3306,
    mailFromAddress: 'nextcloud',
    mailDomain: 'bln.space',
    smtpHost: 'mailserver.base-mx-lts.svc.cluster.local',
    smtpSecure: 'tls',
    smtpPort: 587,
    smtpAuthType: 'LOGIN',

  },
}
