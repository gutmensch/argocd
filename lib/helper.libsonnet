{
  uniquify(obj)::
    {
      [std.md5(std.toString(v))]: v
      for v in std.objectValues(obj)
    },

  strToRandInt(val, mod)::
    std.mod(std.foldl(function(x, y) (x + y), [std.codepoint(x) for x in std.stringChars(val)], 0), mod),

  boolToStrInt(val)::
    if val == true then '1' else '0',

  configMerge(name, component, project, tenant, secrets, config, shared, cd)::
    local global = import '../config/global.libsonnet';
    std.mergePatch(
      std.get(global, tenant, default={}), std.mergePatch(
        std.get(config, 'default', default={}), std.mergePatch(
          std.get(shared, tenant, default={}), std.mergePatch(
            std.get(config, tenant, default={}), std.mergePatch(
              std.get(secrets, tenant, default={}), std.mergePatch(
                std.get(cd, tenant, default={}), { labels+: {
                  'app.kubernetes.io/name': name,
                  'app.kubernetes.io/project': project,
                  'app.kubernetes.io/component': component,
                  'app.kubernetes.io/managed-by': 'ArgoCD',
                }, containerImageLabels+: {
                  [if std.get(cd, tenant) != null && std.get(cd[tenant], 'imageOwner') != null then 'app.kubernetes.io/created-by']: cd[tenant].imageOwner,
                  [if std.get(cd, tenant) != null && std.get(cd[tenant], 'imageTimestamp') != null then 'app.kubernetes.io/created-at']: cd[tenant].imageTimestamp,
                } }
              ),
            ),
          ),
        ),
      ),
    ),

  getImage(registry, image, version):: (
    local ref = if registry != '' then std.join('/', [registry, image]) else image;
    if std.startsWith(version, 'sha256') then
      '%s@%s' % [ref, version]
    else
      '%s:%s' % [ref, version]
  ),

  getIngress(tenant, name, ingressRoot):: (
    if tenant == 'staging' then
      std.join('.', [name, 'stg', ingressRoot])
    else
      if tenant == 'lts' then
        std.join('.', [name, ingressRoot])
      else
        std.join('.', [name, tenant, ingressRoot])
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

  manifestPostConf(obj)::
    local body_lines(body) = std.join([], [
      local entry = body[i];
      local elem =
        if std.isArray(entry) then ['%s = %s' % [i, std.join(', ', entry)]]
        else ['%s = %s' % [i, entry]];
      elem
      for i in std.objectFields(body)
    ]);
    std.join('\n', body_lines(obj) + ['']),

  phpWrapVariable(var)::
    if std.type(var) == 'boolean' || std.type(var) == 'number' then var else "'%s'" % [var],

  manifestPhpConfig(obj)::
    local body_lines(body) = std.join([], [
      local entry = body[i];
      local elem =
        if std.isArray(entry) then ["$config['%s'] = ['%s'];" % [i, std.strReplace(std.join(',', entry), ',', "','")]]
        else ["$config['%s'] = %s;" % [i, self.phpWrapVariable(entry)]];
      elem
      for i in std.objectFields(body)
    ]);
    std.join('\n', ['<?php', '$config = [];'] + body_lines(obj) + ['']),
}
