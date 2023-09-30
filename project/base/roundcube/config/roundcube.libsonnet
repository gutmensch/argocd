{
  default: {},

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
    imageVersion: '1.6.1-php74-1',
    ingress: 'mail.bln.space',
    dbWriteHost: 'mysql.base-mysqldb-lts.svc.cluster.local',
    dbReadHost: 'mysql.base-mysqldb-lts.svc.cluster.local',
    imapHost: 'tls://mailserver.base-mx-lts.svc.cluster.local:143',
    smtpHost: 'tls://mailserver.base-mx-lts.svc.cluster.local:587',
    managesieveHost: 'tls://mailserver.base-mx-lts.svc.cluster.local:4190',
    // following is a result of ldap setup (main mail attr) and to reduce different username
    loginUsernameFilter: '/^[a-z]+$/',
    usernameDomain: 'bln.space',
    usernameDomainForced: true,
  },
}
