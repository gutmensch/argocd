{
  getIngress(tenant, name, ingressRoot):: (
    if tenant != 'lts' then
      std.join('.', ['%s-%s' % [name, tenant], ingressRoot])
    else
      std.join('.', [name, ingressRoot])
  ),

  ldifKeySort(line)::
    if std.startsWith(line, 'dn:') then 1 else
      if std.startsWith(line, 'description:') then 2 else
        if std.startsWith(line, 'objectClass:') then 4 else 3,

  manifestLdif(ldifs)::
    local body_lines(body) = std.join([], [
      local entry = body[i];
      if std.isArray(entry) then
        local entries = [
          std.sort(std.flattenArrays([
	    local elem =
	      if std.isArray(e[k]) then ['%s: %s' % [k, i] for i in e[k]]
	      else ['%s: %s' % [k, e[k]]];
	    elem
	    for k in std.objectFields(e)
	    ]), self.ldifKeySort) + ['']
          for e in entry
        ];
        std.flattenArrays(entries)
      else
        std.sort(std.flattenArrays([
	  local elem =
	    if std.isArray(entry[j]) then ['%s: %s' % [j, i] for i in entry[j]]
	    else ['%s: %s' % [j, entry[j]]];
	  elem
	  for j in std.objectFields(entry)
	  ]), self.ldifKeySort) + ['']
      for i in std.objectFields(body)
    ]);
    std.join('\n', body_lines(ldifs) + ['']),

  removeVersion(obj)::
    std.mergePatch(obj, { 'app.kubernetes.io/version': null })
    
}
