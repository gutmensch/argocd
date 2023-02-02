{
  default: {
    imageRegistry: 'registry.lan:5000',
  },

  staging: {
    imageVersion: '1.6.1-php74-1',
    ingress: 'mail.staging.bln.space',
    dbWriteHost: 'mysql.base-mysqldb-staging.svc.cluster.local',
    dbReadHost: 'mysql.base-mysqldb-staging.svc.cluster.local',
    imapHost: 'tls://mailserver.base-mx-lts.svc.cluster.local:143',
    smtpHost: 'tls://mailserver.base-mx-lts.svc.cluster.local:587',
    managesieveHost: 'tls://mailserver.base-mx-lts.svc.cluster.local:4190',
  },

  lts: {
    ingress: 'mail.bln.space',
    dbWriteHost: 'mysql.base-mysqldb-lts.svc.cluster.local',
    dbReadHost: 'mysql.base-mysqldb-lts.svc.cluster.local',
    imapHost: 'tls://mailserver.base-mx-lts.svc.cluster.local:143',
    smtpHost: 'tls://mailserver.base-mx-lts.svc.cluster.local:587',
    managesieveHost: 'tls://mailserver.base-mx-lts.svc.cluster.local:4190',
  },
}
