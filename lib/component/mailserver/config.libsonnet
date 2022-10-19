local helper = import '../../helper.libsonnet';

{
  local this = self,

  mailerConfig:: {},

  mynetworks:: {
    private: [
      '127.0.0.0/8',
      '10.0.0.0/8',
      '172.16.0.0/12',
      '192.168.0.0/16',
      '[::1]/128',
      '[fe80::]/10',
      '[fd00::]/8',
    ],
    public:: this.mailerConfig.trustedPublicNetworks,
  },

  postscreenAccess:: {
    reject: [
      '45.125.65.0/24',  // teleasia hk
      '45.125.66.0/24',  // teleasia hk
      '46.173.211.0/24',  // gpi ru
      '62.173.128.0/19',  // spacenet ru
      '93.189.40.0/21',  // ntcom ru
      '5.188.206.0/24',  // fastvps / hk /ru
      '141.98.10.0/24',  // hostbaltic lt
      '141.98.11.0/24',  // hostbaltic lt
      '77.247.110.0/24',  // PEENQ.NL
      '106.75.0.0/16',  // ucloud shanghai china
    ],
    permit: [],
  },

  postgreyWhitelistClients:: [
    'amazon.com',
    'amazon.de',
    'amazonses.com',
    'aol.com',
    'artifacthub.io',
    'authy.com',
    'bitwarden.com',
    'booking.com',
    'cloudfiltering.com',
    'cloudflare.com',
    'codeberg.org',
    'deutschepost.de',
    'dhl.de',
    'dkb.de',
    'docker.com',
    'doctolib.fr',
    'ebay.com',
    'epost.de',
    'etrade.com',
    'facebook.com',
    'facebookmail.com',
    'fbmta.com',
    'freenet.de',
    'github.com',
    'gmx.com',
    'gmx.de',
    'gmx.net',
    'google.com',
    'googlemail.com',
    'hetzner.com',
    'hotmail.com',
    'icloud.com',
    'immobilienscout24.de',
    'linkedin.com',
    'live.de',
    'mail.com',
    'mailjet.com',
    'microsoft.com',
    'mobile.de',
    'outlook.com',
    'paypal.com',
    'paypal.de',
    'pinterest.com',
    'reddit.com',
    'serverfault.com',
    'shareworks.com',
    'share-now.com',
    'stackoverflow.com',
    'steampowered.com',
    'telekom.de',
    't-online.de',
    'traderepublic.com',
    'tumblr.com',
    'twitter.com',
    'yahoo.com',
    'wargaming.net',
    'web.de',
    'zendesk.com',
  ],

  confidential:: ['fetchmail.cf'],

  //
  // below real file entries, above is only helpers and config
  //

  'amavis.cf': std.strReplace(
    std.strReplace(importstr 'templates/amavis.cf', '__AMAVIS_MYNETWORKS__', std.join(' ', this.mynetworks.private + this.mynetworks.public)),
    '__AMAVIS_POSTMASTER_ADDRESS__',
    std.strReplace(this.mailerConfig.postmasterAddress, '@', '\\@')
  ),

  'dovecot.cf': helper.manifestPostConf({
    lmtp_save_to_detail_mailbox: 'yes',
    postmaster_address: this.mailerConfig.postmasterAddress,
    quota_full_tempfail: 'yes',
  }),

  'postfix-main.cf': helper.manifestPostConf({
    smtpd_banner: '$myhostname ESMTP $mail_name ($mail_version)',
    mynetworks: this.mynetworks.private + this.mynetworks.public,
    lmtp_host_lookup: 'native',
    smtp_host_lookup: 'native',
    smtpd_client_restrictions: ['permit_mynetworks', 'permit_sasl_authenticated', 'reject_unauth_destination', 'reject_unauth_pipelining'],
    smtpd_recipient_restrictions: [
      'permit_sasl_authenticated',
      'permit_mynetworks',
      'reject_unauth_destination',
      'check_policy_service unix:private/policyd-spf',
      'reject_unauth_pipelining',
      'reject_invalid_helo_hostname',
      'reject_non_fqdn_helo_hostname',
      'reject_unknown_recipient_domain',
      'reject_rhsbl_helo dbl.spamhaus.org',
      'reject_rhsbl_reverse_client dbl.spamhaus.org',
      'reject_rhsbl_sender dbl.spamhaus.org',
      'check_policy_service inet:127.0.0.1:10023',
    ],
    postscreen_greet_action: 'enforce',
    postscreen_access_list: ['permit_mynetworks', 'cidr:/etc/postfix/postscreen_access.cidr'],
    // XXX: in 3.6 renamed to postscreen_denylist_action, current image has postfix 3.5
    postscreen_blacklist_action: 'drop',
    postscreen_dnsbl_threshold: '3',
    postscreen_dnsbl_sites: [
      'zen.spamhaus.org*3',
      'b.barracudacentral.org*2',
      'bl.spameatingmonkey.net*2',
      'bl.mailspike.net',
      'bl.spamcop.net',
      'dnsbl.sorbs.net',
      'dnsbl.dronebl.org',
      'psbl.surriel.com',
      'dnsbl-1.uceprotect.net',
      'list.dnswl.org=127.0.[0..255].0*-2',
      'list.dnswl.org=127.0.[0..255].1*-3',
      'list.dnswl.org=127.0.[0..255].[2..3]*-4',
      'iadb.isipp.com=127.0.[0..255].[0..255]*-2',
      'iadb.isipp.com=127.3.100.[6..200]*-2',
      'wl.mailspike.net=127.0.0.[17;18]*-1',
      'wl.mailspike.net=127.0.0.[19;20]*-2',
    ],
  }),

  // used as input for whitelist_clients.local generation in user-patches
  'postgrey_whitelist_domains.txt': std.join('\n', this.postgreyWhitelistClients),

  'postscreen_access.cidr': std.join('\n', [
    '%s reject' % item
    for item in this.postscreenAccess.reject
  ] + [
    '%s permit' % item
    for item in this.postscreenAccess.permit
  ]),

  'user-patches.sh': importstr 'templates/user-patches.sh',

  'ldap-domains.cf': helper.manifestPostConf({
    server_host: '__replaced_by_configomat_from_env__',
    start_tls: '__replaced_by_configomat_from_env__',
    bind_dn: '__replaced_by_configomat_from_env__',
    bind_pw: '__replaced_by_configomat_from_env__',
    query_filter: '__replaced_by_configomat_from_env__',
    search_base: '__replaced_by_configomat_from_env__',
    bind: 'yes',
    version: 3,
    // XXX: the following keys are not completely configurable from docker env
    result_attribute: 'dc',
  }),

  'ldap-users.cf': helper.manifestPostConf({
    server_host: '__replaced_by_configomat_from_env__',
    start_tls: '__replaced_by_configomat_from_env__',
    bind_dn: '__replaced_by_configomat_from_env__',
    bind_pw: '__replaced_by_configomat_from_env__',
    query_filter: '__replaced_by_configomat_from_env__',
    search_base: '__replaced_by_configomat_from_env__',
    bind: 'yes',
    version: 3,
    // XXX: the following keys are not completely configurable from docker env
    result_attribute: 'mailDrop',
  }),

  'ldap-aliases.cf': helper.manifestPostConf({
    server_host: '__replaced_by_configomat_from_env__',
    start_tls: '__replaced_by_configomat_from_env__',
    bind_dn: '__replaced_by_configomat_from_env__',
    bind_pw: '__replaced_by_configomat_from_env__',
    query_filter: '__replaced_by_configomat_from_env__',
    search_base: '__replaced_by_configomat_from_env__',
    bind: 'yes',
    version: 3,
    // XXX: the following keys are not completely configurable from docker env
    result_attribute: 'mailDrop',
  }),

  'ldap-groups.cf': helper.manifestPostConf({
    server_host: '__replaced_by_configomat_from_env__',
    start_tls: '__replaced_by_configomat_from_env__',
    bind_dn: '__replaced_by_configomat_from_env__',
    bind_pw: '__replaced_by_configomat_from_env__',
    query_filter: '__replaced_by_configomat_from_env__',
    search_base: '__replaced_by_configomat_from_env__',
    bind: 'yes',
    version: 3,
    // XXX: the following keys are not completely configurable from docker env
    result_attribute: 'mailDrop',
  }),

  'fetchmail.cf': std.join('\n', [
    'poll %s proto %s interval %d user "%s" password "%s" is "%s" here options %s ssl' % [m.server, m.proto, m.interval, m.user, m.password, m.is, if m.keep then 'keep' else 'nokeep']
    for m in this.mailerConfig.fetchmailAccounts
  ]),
}
