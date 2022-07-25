{
  getIngress(tenant, name, ingressRoot):: (
    if tenant != 'lts' then
      std.join('.', ['%s-%s' % [name, tenant], ingressRoot])
    else
      std.join('.', [name, ingressRoot])
  ),

  // ldif allows duplicate entries for certain attributes
  cleanLdifKey(key)::
    local dupEntryAttributes = ['objectClass'];
    local res = std.prune([
      if std.startsWith(key, a) && std.length(key) > std.length(a) then
        a
      for a in dupEntryAttributes
    ]);
    if std.length(res) > 0 then
      res[0]
    else
      key,

  manifestLdif(ldifs)::
    local body_lines(body) = std.join([], [
      local entry = body[i];
      if std.isArray(entry) then
        local entries = [
          ['%s: %s' % [self.cleanLdifKey(k), e[k]] for k in std.objectFields(e)] + ['']
          for e in entry
        ];
        std.flattenArrays(entries)
      else
        ['%s: %s' % [self.cleanLdifKey(j), entry[j]] for j in std.objectFields(entry)] + ['']
      for i in std.objectFields(body)
    ]);
    std.join('\n', body_lines(ldifs) + ['']),

  removeVersion(obj)::
    std.mergePatch(obj, { 'app.kubernetes.io/version': null })
    
}
