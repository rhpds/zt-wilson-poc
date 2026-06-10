# Helm Workload Testing - zt-wilson-poc

**Purpose:** Test content repo for `ocp4_workload_helm_from_content_repo` workload validation.

## Branch: helm-test

This branch adds `config/helm-charts.yaml` to test Helm chart deployment in zerotouch labs.

## What's Deployed

### Existing (from main branch):
- 1 RHEL 10 VM: `host1` (8GB RAM, 1 CPU, 40GB disk)
- Firewall: TCP/443 egress allowed
- Network: default

### NEW: Helm Charts
- **Redis** (enabled) - Simple key-value store for testing
  - Chart: bitnami/redis v19.0.0
  - Architecture: standalone
  - Storage: 1Gi PVC
  - Resources: 100m CPU / 128Mi RAM (requests)
  
- **PostgreSQL** (disabled) - Database for multi-chart testing
  - Chart: bitnami/postgresql v15.0.0
  - Storage: 2Gi PVC
  - Auth: uses `{{ common_password }}`

## Testing the Workload

### 1. Deploy via Catalog

Use catalog item: `zt-admins/zt-helm-poc`

Parameters:
- **Git repo**: `https://github.com/rhpds/zt-wilson-poc.git`
- **Git branch**: `helm-test`

### 2. Expected Deployment Flow

```
1. Namespace created: {{ guid }}
   ↓
2. VM created: host1 (RHEL 10)
   ↓
3. Helm workload runs (post_software_workloads)
   ├─ Fetches config/helm-charts.yaml
   ├─ Renders bitnami/redis chart
   ├─ Validates security constraints
   ├─ Deploys to namespace
   └─ Waits for Redis pod Ready
   ↓
4. Showroom deploys (access UI)
```

### 3. Validation Checklist

After deployment, verify:

```bash
# Check namespace
oc get all -n {{ guid }}

# Verify Redis pod is Running
oc get pods -n {{ guid }} -l app.kubernetes.io/instance=test-redis

# Check Redis service
oc get svc test-redis-master -n {{ guid }}

# Check PVC
oc get pvc -n {{ guid }}

# Test Redis connection from bastion
redis-cli -h test-redis-master ping
# Expected: PONG
```

### 4. Security Validation Tests

The workload should validate and pass these constraints:

- ✅ No cluster-scoped resources (no ClusterRole, ClusterRoleBinding)
- ✅ No privileged containers
- ✅ No hostPath volumes
- ✅ CPU limit ≤ 1000m
- ✅ Memory limit ≤ 1Gi
- ✅ Storage claim ≤ 2Gi

### 5. NetworkPolicy Validation

Verify firewall.yaml rules apply to Helm-deployed pods:

```bash
# Check NetworkPolicy
oc get networkpolicy -n {{ guid }}

# Verify Redis pod has network policy applied
oc describe pod -n {{ guid }} -l app.kubernetes.io/instance=test-redis | grep -A 5 "Network"
```

## Test Variations

### Test 1: Redis Only (Current)
- `redis.enabled: true`
- `postgresql.enabled: false`

### Test 2: Multiple Charts
Edit `config/helm-charts.yaml`:
```yaml
  - name: postgresql
    enabled: true  # Enable PostgreSQL
```

Redeploy to test multiple Helm charts in one deployment.

### Test 3: Security Violation (Expected Failure)

Test cluster-scoped resource blocking:
```yaml
charts:
  - name: prometheus-operator
    enabled: true
    source:
      type: repository
      url: https://prometheus-community.github.io/helm-charts
      chart_ref: kube-prometheus-stack
    security:
      allowClusterScopedResources: false  # Should FAIL
```

Expected: Workload fails with "SECURITY VIOLATION: cluster-scoped resource"

## Accessing Redis from Showroom

Add to `ui-config.yml` (optional):
```yaml
terminals:
  - name: redis-cli
    displayName: Redis Terminal
    command: >-
      oc exec -it deployment/test-redis-master -n {{ guid }} -- redis-cli
```

## Files Changed

- `config/helm-charts.yaml` - **NEW** - Helm chart definitions
- `HELM-TEST.md` - **NEW** - This file

## Next Steps After Validation

1. ✅ Confirm Redis deploys successfully
2. ✅ Verify security validation works
3. ✅ Test with multiple charts (enable PostgreSQL)
4. Create production Foreman Helm chart
5. Merge workload to AgnosticD main branch

## Rollback

To revert to VM-only deployment:
```bash
git checkout main
```

Or remove helm-charts.yaml:
```bash
rm config/helm-charts.yaml
git commit -am "Remove helm charts for testing"
```
