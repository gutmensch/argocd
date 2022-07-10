{
  getIngress(tenant, name, ingressRoot):: (
    if tenant != 'lts' then
      std.join('.', ['%s-%s' % [name, tenant], ingressRoot])
    else
      std.join('.', [name, ingressRoot])
  ),
}
