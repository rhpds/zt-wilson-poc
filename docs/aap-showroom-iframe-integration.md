# AAP Showroom Iframe Integration (Research & Design)

**Status**: ✅ Solution Implemented & Verified (2026-07-01)  
**Context**: Embedding AAP 2.7 web UI in RHDP Zerotouch Showroom labs  
**Issue**: X-Frame-Options header prevents iframe embedding  
**Solution**: Helm post-install hook to patch AAP route

> **For working implementation guide**, see `showroom-aap-iframe-integration.md`  
> This document contains research notes and design decisions.

---

## Problem Statement

The AAP 2.7 operator creates an OpenShift Route for the AAP web UI, but by default the AAP application sends `X-Frame-Options: SAMEORIGIN` headers that prevent embedding the UI in iframes.

Showroom labs use Nookbag UI which embeds service UIs in iframe tabs. Without removing the X-Frame-Options header, the AAP tab displays as a blank white page.

---

## AAP Operator Route Configuration Capabilities

The `AnsibleAutomationPlatform` CR (AAP 2.7, apiVersion `aap.ansible.com/v1alpha1`) supports these route configuration options:

```yaml
spec:
  route_host: "aap.example.com"
  route_tls_termination_mechanism: "Edge"  # Edge, Passthrough, or Reencrypt
  route_tls_secret: "aap-tls-cert"        # Optional custom cert
  route_annotations: "key=value"           # Simple annotations only
  route_api_version: "route.openshift.io/v1"
```

**Limitation**: The operator **does NOT** support configuring `httpHeaders` in the route spec. The `route_annotations` field only supports simple key=value annotations, not the complex `httpHeaders.actions.response[]` structure required to remove headers.

### What We Need

To allow iframe embedding, the route must have:

```yaml
spec:
  httpHeaders:
    actions:
      response:
        - name: X-Frame-Options
          action:
            type: Delete
```

This is a **spec-level** configuration, not an annotation, so `route_annotations` cannot achieve this.

---

## Solution: Helm Post-Install Hook

Since the operator doesn't expose httpHeaders configuration, we use a **Helm post-install Job** that:

1. Waits for the AAP operator to create the route (up to 5 minutes)
2. Patches the route to add the httpHeaders configuration
3. Self-cleans after 5 minutes (TTL)

### Implementation

**File**: `charts/aap-operator/templates/route-patch-job.yaml`

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
      containers:
        - name: patch-route
          image: registry.redhat.io/openshift4/ose-cli:latest
          command:
            - /bin/bash
            - -c
            - |
              # Wait for route to exist
              for i in {1..30}; do
                if oc get route {{ .Values.aap.name }} -n {{ .Release.Namespace }}; then
                  break
                fi
                sleep 10
              done

              # Patch route
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

### RBAC Requirements

The Job requires a ServiceAccount with permissions to read and patch routes:

**Role**:
```yaml
rules:
  - apiGroups: ["route.openshift.io"]
    resources: ["routes"]
    verbs: ["get", "list", "patch"]
```

---

## Configuration

**values.yaml**:

```yaml
showroom:
  iframeIntegration:
    enabled: true  # Set to false to skip route patching
```

**Enable in production deployment**:

```bash
helm template aap charts/aap-operator/ \
  --set showroom.iframeIntegration.enabled=true \
  --set admin.password=<password> \
  | oc apply -f -
```

---

## Alternative Approaches Considered

### ❌ Approach 1: route_annotations

**Why not**: `route_annotations` only supports simple string annotations, not the complex nested structure required for `httpHeaders`.

### ❌ Approach 2: setup-automation playbook

**Why not**: Helm hooks are cleaner and idempotent. Setup-automation runs once during lab provisioning, but Helm hooks run on every chart upgrade, keeping the configuration in sync.

### ❌ Approach 3: Manual route creation (bypass operator)

**Why not**: The operator owns the route (via ownerReferences). Manual routes would be deleted or conflict with operator-managed routes.

### ✅ Approach 4: Helm post-install hook (chosen)

**Why**: 
- Declarative (part of Helm chart)
- Idempotent (runs on install + upgrade)
- Self-cleaning (TTL after success)
- Scoped RBAC (namespace-level only)
- Survives chart upgrades

---

## Showroom ui-config.yml Integration

**File**: `ui-config.yml`

```yaml
tabs:
  - name: "AAP Web UI"
    url: http://aap.sandbox-${guid}-zt-rhelbu.svc/
```

**Why internal service URL**:
- Works across all CNV clusters (dev, prod, HCP)
- No TLS certificate issues
- Faster (no external route hop)
- NetworkPolicy-compatible (same namespace)

**Variable substitution**:
- `${guid}` → Lab GUID (e.g., `qppv2`)
- Performed by envsubst in Showroom content container at startup

---

## Verification

### 1. Check route headers configured

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

### 2. Verify header removed from responses

```bash
AAP_URL=$(oc get route aap -n <namespace> -o jsonpath='{.spec.host}')
curl -I https://${AAP_URL}/ | grep -i "X-Frame"
```

Expected: No X-Frame-Options header in output.

### 3. Test iframe embedding

Open Showroom UI and verify the "AAP Web UI" tab loads the AAP interface (not blank white).

---

## Troubleshooting

### Job fails: "route not found"

**Symptom**: Hook job logs show `Error from server (NotFound): routes.route.openshift.io "aap" not found`

**Cause**: AAP operator hasn't created the route yet.

**Fix**: The job retries for 5 minutes. If it still fails, check AAP CR status:

```bash
oc get ansibleautomationplatform aap -n <namespace> -o yaml
```

### Iframe still blank after patching

**Symptom**: Route has httpHeaders configured but iframe is blank.

**Possible causes**:

1. **Browser cache**: Hard refresh (Ctrl+Shift+R)
2. **Wrong URL**: Check ui-config.yml uses the internal service URL pattern
3. **NetworkPolicy**: Verify firewall.yaml allows same-namespace traffic
4. **AAP not ready**: Check AAP pods are all running:
   ```bash
   oc get pods -n <namespace> | grep aap
   ```

### Route patch overwritten

**Symptom**: httpHeaders disappear after some time.

**Cause**: AAP operator reconciliation overwriting the route.

**Investigation**: Check if the operator reconciles routes on every change. If so, we may need a different approach (operator feature request or sidecar controller).

---

## References

- **AAP 2.7 Operator CRD**: `oc explain ansibleautomationplatform.spec`
- **OpenShift Route httpHeaders docs**: https://docs.openshift.com/container-platform/4.14/networking/routes/route-configuration.html#nw-route-specific-annotations_route-configuration
- **Helm Hooks**: https://helm.sh/docs/topics/charts_hooks/
- **Showroom iframe integration**: `~/Projects/cursor-revisit/platform/showroom-lab-authoring-reference.md`
