# root app resources for ArgoCD

These are autogenerated from root.jsonnet during pre-commit hook. The reason for this directory is to avoid deletion limitations in the app-of-app pattern. ArgoCD refuses to delete Applications created from Applications for security reasons, which leaves dangling resources and namespaces. Once this "feature" is configurable or changed, we can resort to pointing to root.jsonnet directly (again).