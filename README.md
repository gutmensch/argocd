# argocd - deployment configuration for kubectl.me

## root kubernetes installation

See ansible repository.

## secrets

Managed via git-crypt. After clone use `git-crypt unlock` and for adding a new user key use `git-crypt add-gpg-user key`.

## hooks

Set repository hooks to the repo directory to allow auto generating of apps (see more explanation in \_generated/README.md).

```bash
git config --local core.hooksPath .githooks/
```
