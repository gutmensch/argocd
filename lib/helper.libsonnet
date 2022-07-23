{
  getIngress(tenant, name, ingressRoot):: (
    if tenant != 'lts' then
      std.join('.', ['%s-%s' % [name, tenant], ingressRoot])
    else
      std.join('.', [name, ingressRoot])
  ),

  manifestLdif(ldifs)::
    local body_lines(body) = std.join([], [
      local entry = body[i];
      if std.isArray(entry) then
        local entries = [
          ['%s: %s' % [k, e[k]] for k in std.objectFields(e)] + ['']
          for e in entry
        ];
        std.flattenArrays(entries)
      else
        ['%s: %s' % [j, entry[j]] for j in std.objectFields(entry)] + ['']
      for i in std.objectFields(body)
    ]);
    std.join('\n', body_lines(ldifs) + ['']),

  removeVersion(obj)::
    std.mergePatch(obj, { 'app.kubernetes.io/version': null })
    
}
