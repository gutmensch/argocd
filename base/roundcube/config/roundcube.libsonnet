{
  default: {
    imageRegistry: 'registry.lan:5000',
  },

  staging: {
    ingress: 'mail.stg.bln.space',
  },

  lts: {
    ingress: 'mail.bln.space',
    dbHost: 'mysql-cluster-haproxy.base-mysqldb-lts.svc.cluster.local',
    imapHost: 'tls://mailserver.base-mx-lts.svc.cluster.local',
    smtpHost: 'tls://mailserver.base-mx-lts.svc.cluster.local',
    managesieveHost: 'tls://mailserver.base-mx-lts.svc.cluster.local',
  },
}
