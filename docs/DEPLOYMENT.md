# Deployment Guide

## Showroom Integration

To ensure AAP route hostname matches Showroom's `${domain}` variable:

### Set route_host in values

```yaml
# values.yaml or --set flag
# Pattern: aap-${guid}.${domain}
route_host: "aap-<guid>.apps.ocpvdev01.rhdp.net"
```

### Example for ocpvdev01 cluster

```bash
helm template aap charts/aap-operator/ \
  --set admin.password=redhat123 \
  --set route_host="aap-qppv2.apps.ocpvdev01.rhdp.net" \
  | oc apply -f -
```

### Why this matters

Without `route_host`, AAP uses the cluster's default route domain (e.g., `apps.ocpvdev01.dal13.infra.demo.redhat.com`), which may not match Showroom's `${domain}` variable (`apps.ocpvdev01.rhdp.net`).

Setting `route_host` ensures:
- ✅ ui-config.yml can use `${domain}` variable
- ✅ Route hostname matches Showroom expectations
- ✅ No hardcoded hostnames in ui-config.yml

### Alternative: Hardcode in ui-config.yml

If you cannot set `route_host` during deployment, hardcode the full hostname in `ui-config.yml`:

```yaml
tabs:
  - name: "AAP Web UI"
    url: https://aap-sandbox-${guid}-zt-rhelbu.apps.ocpvdev01.dal13.infra.demo.redhat.com/
    external: false
```

**Note**: This fallback approach uses the operator's default domain, which may differ from Showroom's `${domain}`.
