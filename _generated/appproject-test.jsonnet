{
  "apiVersion": "argoproj.io/v1alpha1",
  "kind": "AppProject",
  "metadata": {
    "finalizers": [
      "resources-finalizer.argocd.argoproj.io"
    ],
    "labels": {
      "app.kubernetes.io/managed-by": "ArgoCD"
    },
    "name": "test",
    "namespace": "argo-cd-system"
  },
  "spec": {
    "clusterResourceWhitelist": [
      {
        "group": "",
        "kind": "Namespace"
      }
    ],
    "description": "Test applications",
    "destinations": [],
    "orphanedResources": {
      "warn": true
    },
    "sourceRepos": [
      "*"
    ]
  }
}