{
  "apiVersion": "argoproj.io/v1alpha1",
  "kind": "Application",
  "metadata": {
    "finalizers": [
      "resources-finalizer.argocd.argoproj.io"
    ],
    "labels": {
      "app.kubernetes.io/instance": "base-mysqldb-lts",
      "app.kubernetes.io/managed-by": "ArgoCD",
      "app.kubernetes.io/name": "mysqldb"
    },
    "name": "base-mysqldb-lts",
    "namespace": "argo-cd-system"
  },
  "spec": {
    "destination": {
      "namespace": "base-mysqldb-lts",
      "server": "https://kubernetes.default.svc"
    },
    "project": "base",
    "source": {
      "directory": {
        "jsonnet": {
          "tlas": [
            {
              "code": false,
              "name": "name",
              "value": "mysqldb"
            },
            {
              "code": false,
              "name": "namespace",
              "value": "base-mysqldb-lts"
            },
            {
              "code": false,
              "name": "project",
              "value": "base"
            },
            {
              "code": false,
              "name": "tenant",
              "value": "lts"
            },
            {
              "code": false,
              "name": "region",
              "value": "falkenstein"
            }
          ]
        },
        "recurse": false
      },
      "path": "base/mysqldb",
      "repoURL": "https://github.com/gutmensch/argocd.git",
      "targetRevision": "HEAD"
    },
    "syncPolicy": {
      "automated": {
        "allowEmpty": true,
        "prune": true,
        "selfHeal": true
      },
      "retry": {
        "backoff": {
          "duration": "5s",
          "factor": 2,
          "maxDuration": "5m"
        },
        "limit": 5
      },
      "syncOptions": [
        "Validate=true",
        "CreateNamespace=true",
        "PrunePropagationPolicy=background"
      ]
    }
  }
}