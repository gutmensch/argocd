{
  getIngress(tenant, name, ingressRoot):: (
    if tenant != 'lts' then
      std.join('.', ['%s-%s' % [name, tenant], ingressRoot])
    else
      std.join('.', [name, ingressRoot])
  ),

  // ldif allows duplicate entries for certain attributes
  ldifKeySanitize(key)::
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

  ldifKeySort(line)::
    if std.startsWith(line, 'dn:') then 1 else
      if std.startsWith(line, 'description:') then 2 else
        if std.startsWith(line, 'objectClass:') then 4 else 3,

  manifestLdif(ldifs)::
    local body_lines(body) = std.join([], [
      local entry = body[i];
      if std.isArray(entry) then
        local entries = [
          std.sort(['%s: %s' % [self.ldifKeySanitize(k), e[k]] for k in std.objectFields(e)], self.ldifKeySort) + ['']
          for e in entry
        ];
        std.flattenArrays(entries)
      else
        std.sort(['%s: %s' % [self.ldifKeySanitize(j), entry[j]] for j in std.objectFields(entry)], self.ldifKeySort) + ['']
      for i in std.objectFields(body)
    ]);
    std.join('\n', body_lines(ldifs) + ['']),

  removeVersion(obj)::
    std.mergePatch(obj, { 'app.kubernetes.io/version': null })
    
}
