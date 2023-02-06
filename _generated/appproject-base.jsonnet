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
    "name": "base",
    "namespace": "argo-cd-system"
  },
  "spec": {
    "clusterResourceWhitelist": [
      {
        "group": "",
        "kind": "Namespace"
      }
    ],
    "description": "Base applications like Backstage, MX, roundcube, Nextcloud, etc.",
    "destinations": [
      {
        "namespace": "base-dns-lts",
        "server": "https://kubernetes.default.svc"
      },
      {
        "namespace": "base-auth-lts",
        "server": "https://kubernetes.default.svc"
      },
      {
        "namespace": "base-minio-lts",
        "server": "https://kubernetes.default.svc"
      },
      {
        "namespace": "base-mx-lts",
        "server": "https://kubernetes.default.svc"
      },
      {
        "namespace": "base-mysqldb-staging",
        "server": "https://kubernetes.default.svc"
      },
      {
        "namespace": "base-mysqldb-lts",
        "server": "https://kubernetes.default.svc"
      },
      {
        "namespace": "base-roundcube-lts",
        "server": "https://kubernetes.default.svc"
      }
    ],
    "orphanedResources": {
      "warn": true
    },
    "sourceRepos": [
      "*"
    ]
  }
}