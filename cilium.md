# cilium setup

## howtos

### flow decisions by hubble

```bash
kubectl -n cilium-system exec cilium-fv9ls -- hubble observe --since 3m --pod base-mx-lts/mailserver-0
```
