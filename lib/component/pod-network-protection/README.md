# pod-network-protection

This is a simple integration similar to fail2ban but without the need to mess with iptables with the following functionality:

1. Create base network policy to allow k8s standard ingress/egress traffic (dns, ldap, etc.)

2. Create static network policy for specific service ingress/egress (service related e.g. smtp)

3. Create dynamic network policy based on pod log regex filtering (disable access for "bad guys")

The k8s log filtering and network policy manipulation logic is implemented as python function in the toolbox image.
