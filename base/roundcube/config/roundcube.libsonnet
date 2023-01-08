{
  default: {
    imageRegistry: 'registry.lan:5000',
  },

  staging: {
    ingress: 'mail.stg.bln.space',
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
