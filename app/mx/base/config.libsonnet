local helper = import '../../lib/helper.libsonnet';

{
  postmasterAddress:: error 'need postmaster mail address to configure',
  trustedPublicNetworks:: error 'need trusted public networks to configure',

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
    public:: self.trustedPublicNetworks,
  },

  postscreenAccess:: {
    reject: [
      '46.173.211.0/24', // gpi ru
      '62.173.128.0/19', // spacenet ru
      '93.189.40.0/21',  // ntcom ru
      '5.188.206.0/24',  // fastvps / hk /ru
      '141.98.10.0/24',  // hostbaltic lt
      '77.247.110.0/24', // PEENQ.NL
      '106.75.0.0/16',   // ucloud shanghai china
    ],
    permit: [],
  },

  'amavis.cf': std.join('\n', [
    '@mynetworks = qw (' + std.join(' ', mynetworks.private + mynetworks.public) + ');',
    '$clean_quarantine_to = ' + helper.escapePerlEnd(self.postmasterAddress),
    '$virus_quarantine_to = ' + helper.escapePerlEnd(self.postmasterAddress),
    '$banned_quarantine_to = ' + helper.escapePerlEnd(self.postmasterAddress),
    '$bad_header_quarantine_to = ' + helper.escapePerlEnd(self.postmasterAddress),
    '$spam_quarantine_to = ' + helper.escapePerlEnd(self.postmasterAddress),
    |||
    $policy_bank{"MYNETS"}': {  # clients in @mynetworks
      bypass_spam_checks_maps   => [1],  # don't spam-check internal mail
      bypass_banned_checks_maps => [1],  # don't banned-check internal mail
      bypass_header_checks_maps => [1],  # don't header-check internal mail
    };
    |||,
    ])
  },

  'dovecot.cf': helper.manifestPostconf({
    lmtp_save_to_detail_mailbox: 'yes',
    postmaster_address: self.postmasterAddress,
    quota_full_tempfail: 'yes',
  }),

  'postfix-main.cf': helper.manifestPostconf({
    smtpd_banner: '"$myhostname ESMTP"',
    mynetworks: mynetworks.private + mynetworks.public,
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
      'check_policy_service inet:127.0.0.1:10023', ],
    postscreen_greet_action: 'enforce',
    postscreen_access_list: ['permit_mynetworks', 'cidr:/etc/postfix/postscreen_access.cidr'],
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
      'list.dnswl.org=127.0.[0..255].0*-2'
      'list.dnswl.org=127.0.[0..255].1*-3',
      'list.dnswl.org=127.0.[0..255].[2..3]*-4',
      'iadb.isipp.com=127.0.[0..255].[0..255]*-2',
      'iadb.isipp.com=127.3.100.[6..200]*-2',
      'wl.mailspike.net=127.0.0.[17;18]*-1',
      'wl.mailspike.net=127.0.0.[19;20]*-2',
    ],
  }),

  'postscreen-access.cidr': std.join('\n', [
    '%s reject' % item
    for item in self.postscreenAccess.reject
  ] + [
    '%s permit' % item
    for item in self.postscreenAccess.permit
  ]),
}
