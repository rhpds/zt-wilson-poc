# Showroom AAP Iframe Integration Guide

**Status**: ✅ Working  
**Lab**: zt-wilson-poc  
**AAP Version**: 2.7  
**Tested**: 2026-07-01

---

## Overview

This document describes how to embed the Ansible Automation Platform (AAP) 2.7 web UI as an iframe tab in RHDP Zerotouch Showroom labs.

---

## Required Components

### 1. AAP Helm Chart with Route Patch Hook

**File**: `charts/aap-operator/templates/route-patch-job.yaml`

AAP's web UI blocks iframe embedding by default. The AAP operator creates a route but doesn't expose configuration for the `httpHeaders` spec field needed to allow iframes.

**Solution**: Helm post-install hook Job that patches the AAP route to remove X-Frame-Options header.

```yaml
{{- if .Values.showroom.iframeIntegration.enabled }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "aap-operator.fullname" . }}-route-patch
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-weight": "10"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  ttlSecondsAfterFinished: 300
  backoffLimit: 10
  template:
    spec:
      serviceAccountName: {{ include "aap-operator.serviceAccountName" . }}
      restartPolicy: Never
      containers:
        - name: patch-route
          image: registry.redhat.io/openshift4/ose-cli:latest
          command:
            - /bin/bash
            - -c
            - |
              # Wait for AAP operator to create route (up to 5 minutes)
              for i in {1..30}; do
                if oc get route {{ .Values.aap.name }} -n {{ .Release.Namespace }}; then
                  break
                fi
                sleep 10
              done

              # Patch route to remove X-Frame-Options header
              oc patch route {{ .Values.aap.name }} -n {{ .Release.Namespace }} --type=json -p='[
                {
                  "op": "add",
                  "path": "/spec/httpHeaders",
                  "value": {
                    "actions": {
                      "response": [
                        {
                          "name": "X-Frame-Options",
                          "action": {"type": "Delete"}
                        }
                      ]
                    }
                  }
                }
              ]'
{{- end }}
```

**Why this works:**
- Runs after `helm install` completes (post-install hook)
- Waits for AAP operator to create the route
- Uses namespace-scoped RBAC (no cluster-admin needed)
- Idempotent (safe to run multiple times)
- Self-cleans after 5 minutes (TTL)

### 2. RBAC Resources

**Files**: 
- `charts/aap-operator/templates/serviceaccount.yaml`
- `charts/aap-operator/templates/role.yaml`
- `charts/aap-operator/templates/rolebinding.yaml`

The route-patch Job requires permissions to read and patch routes in its namespace.

```yaml
# Role
rules:
  - apiGroups:
      - route.openshift.io
    resources:
      - routes
    verbs:
      - get
      - list
      - patch
```

**Verified**: Works in Babylon sandbox namespaces (namespace-scoped Role permissions are allowed).

### 3. Showroom ui-config.yml

**File**: `ui-config.yml`

Configure the AAP Web UI tab with the correct URL and iframe settings.

```yaml
tabs:
  - name: "AAP Web UI"
    url: https://aap-sandbox-${guid}-zt-rhelbu.apps.ocpvdev01.dal13.infra.demo.redhat.com/
    external: false
```

**Critical settings:**

| Setting | Value | Why |
|---------|-------|-----|
| `url` | Full HTTPS route hostname | Browsers cannot resolve internal `.svc` URLs |
| `external` | `false` | Embeds as iframe (not new tab) |
| `${guid}` | Variable substitution | Replaced by `envsubst` during Showroom pod startup |

**Domain mismatch issue**: The `${domain}` variable in Showroom expands to `apps.ocpvdev01.rhdp.net` but AAP route uses `apps.ocpvdev01.dal13.infra.demo.redhat.com`. **Solution**: Hardcode the full route hostname.

---

## Deployment

### Enable iframe integration (default: enabled)

```yaml
# charts/aap-operator/values.yaml
showroom:
  iframeIntegration:
    enabled: true  # Set to false to skip route patching
```

### Deploy AAP chart

```bash
helm template aap charts/aap-operator/ \
  --set admin.password=<password> \
  | oc apply -f -
```

The post-install hook will automatically patch the route.

---

## Verification

### 1. Check route httpHeaders

```bash
oc get route aap -n <namespace> -o yaml | grep -A10 "httpHeaders:"
```

Expected output:
```yaml
httpHeaders:
  actions:
    response:
      - action:
          type: Delete
        name: X-Frame-Options
```

### 2. Verify no X-Frame-Options in response

```bash
AAP_URL=$(oc get route aap -n <namespace> -o jsonpath='{.spec.host}')
curl -I https://${AAP_URL}/ | grep -i "x-frame"
```

Expected: No output (header removed).

### 3. Test iframe in Showroom

1. Open Showroom URL: `https://showroom-<guid>.<domain>/`
2. Click "AAP Web UI" tab
3. AAP interface should load (not blank white screen)

---

## Troubleshooting

### Blank white screen in iframe

**Symptoms**: AAP tab shows empty white page.

**Possible causes:**

1. **X-Frame-Options not removed**
   - Check route httpHeaders configuration
   - Verify hook Job completed successfully
   ```bash
   oc get jobs -n <namespace> | grep route-patch
   oc logs job/<job-name> -n <namespace>
   ```

2. **Wrong URL in ui-config.yml**
   - Internal `.svc` URLs don't resolve from browsers
   - Must use external HTTPS route hostname
   - Check: `oc exec <showroom-pod> -c content -- cat /showroom/www/ui-config.yml`

3. **external: true set incorrectly**
   - `external: true` opens in new tab (not iframe)
   - Must be `false` or omitted for iframe embedding

4. **Browser cache**
   - Hard refresh (Ctrl+Shift+R)
   - Clear site data and reload

### Route patch Job fails

**Error**: `Error from server (NotFound): routes.route.openshift.io "aap" not found`

**Cause**: AAP operator hasn't created route yet.

**Solution**: Job retries for 5 minutes. Check AAP CR status:
```bash
oc get ansibleautomationplatform aap -n <namespace> -o yaml
```

### RBAC permission errors

**Error**: `User "system:serviceaccount:<ns>:aap-operator" cannot patch resource "routes"`

**Cause**: Role/RoleBinding not applied.

**Solution**: Verify RBAC resources exist:
```bash
oc get role,rolebinding,serviceaccount -n <namespace> | grep aap-operator
```

---

## Architecture Notes

### Why Helm hook instead of setup-automation?

| Approach | Pros | Cons |
|----------|------|------|
| **setup-automation playbook** | Runs during lab provisioning | Manual, not chart-managed |
| **Helm post-install hook** | Declarative, survives upgrades | Requires RBAC resources |

**Chosen**: Helm hook for better integration with chart lifecycle.

### Why not AAP operator CRD configuration?

The AAP 2.7 CRD does **not** expose `httpHeaders` configuration:
- `route_annotations` field only supports simple string key=value
- Cannot pass complex nested `httpHeaders.actions.response[]` structure
- OpenShift Route spec.httpHeaders must be set directly

**Research**: 
- [2016 RFE for X-Frame-Options annotation](https://bugzilla.redhat.com/show_bug.cgi?id=1371292) was CLOSED DEFERRED
- No `haproxy.router.openshift.io/x-frame-options` annotation exists
- Route httpHeaders are consumed from spec by HAProxy router template

---

## Alternative Approaches Considered

### ❌ Use internal service URL in iframe

```yaml
url: http://aap.sandbox-${guid}-zt-rhelbu.svc/
```

**Why not**: Browsers cannot resolve internal Kubernetes service DNS (`.svc` domains).

### ❌ Use ${domain} variable

```yaml
url: https://aap-sandbox-${guid}-zt-rhelbu.${domain}/
```

**Why not**: Showroom's `${domain}` expands to `apps.ocpvdev01.rhdp.net` but AAP route is on `apps.ocpvdev01.dal13.infra.demo.redhat.com`.

### ❌ Add nginx proxy in Showroom pod

```yaml
url: /aap-proxy/
```

**Why not**: 
- Not a standard Showroom pattern
- Requires custom nginx ConfigMap
- Adds complexity for cross-namespace proxying

---

## References

- **AAP 2.7 Operator CRD**: `oc explain ansibleautomationplatform.spec`
- **OpenShift Route httpHeaders**: https://docs.openshift.com/container-platform/4.14/networking/routes/route-configuration.html
- **Helm Hooks**: https://helm.sh/docs/topics/charts_hooks/
- **Showroom Lab Authoring**: `~/Projects/cursor-revisit/platform/showroom-lab-authoring-reference.md`
- **AAP Operator Research**: `~/Projects/cursor-revisit/platform/aap-operator-openshift-deployment-research.md`

---

## Changelog

- **2026-07-01**: Initial implementation, tested and verified working
  - Helm post-install hook approach
  - RBAC namespace-scoped permissions
  - Hardcoded route hostname in ui-config.yml
  - external: false for iframe embedding
