{
  ignoreDiff: {
    networkPolicy: [
      // the except: array will be updated by cronjob, similar to fail2ban, so we will only create this and then ignore differences
      { group: 'networking.k8s.io', kind: 'NetworkPolicy', jqPathExpressions: ['.spec.ingress[].from[] | select(.ipBlock.cidr == "0.0.0.0/0")'] },
    ],
  },
}
