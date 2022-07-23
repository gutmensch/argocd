local kube = import '../../lib/kube.libsonnet';
local deploy = import '../../lib/deployment.libsonnet';
local tag = import 'cd/state.json';


function(
  name,
  namespace,
  region,
  tenant,
  storage
)
  deploy(name=name, namespace=namespace, tag=tag['deployment'][tenant]['version'])
