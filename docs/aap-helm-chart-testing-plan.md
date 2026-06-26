# AAP Operator Helm Chart Testing Plan

**Purpose**: Validate AAP 2.7 operator Helm chart across deployment scenarios for lab use cases.

**Branch**: `aap-helm-chart`  
**Test Namespace**: `sandbox-srlpt-zt-rhelbu`  
**Chart Path**: `~/Projects/zt-wilson-poc/charts/aap-operator/`

**Testing Principle**: Test incrementally, document findings, don't assume failures mean impossibility.

---

## Test Matrix Overview

| Test ID | Scenario | Components | Database | Expected Time | Status |
|---------|----------|------------|----------|---------------|--------|
| T1 | Operator installation only | Operator | N/A | 2-5 min | ⏳ Pending |
| T2 | Minimal AAP (controller only) | Controller | Managed | 10-15 min | ⏳ Pending |
| T3 | Full AAP stack | Controller + Hub + EDA | Managed | 15-25 min | ⏳ Pending |
| T4 | Controller with external DB | Controller | External | 10-15 min | ⏳ Pending |
| T5 | Hub with external DB | Controller + Hub | External Hub | 15-20 min | ⏳ Pending |
| T6 | Full external DB | All | All External | 15-20 min | ⏳ Pending |
| T7 | Pre-population workflow | Controller | External pre-populated | 15-20 min | ⏳ Pending |
| T8 | Resource quota compliance | Controller | Managed | 10-15 min | ⏳ Pending |
| T9 | Chart upgrade/update | Controller | Managed | 5-10 min | ⏳ Pending |

---

## Prerequisites

### Environment Setup

```bash
# 1. Verify namespace access
oc project sandbox-srlpt-zt-rhelbu

# 2. Check current resources (should be clean or have existing AAP operator)
oc get csv,subscription,operatorgroup,ansibleautomationplatform -n sandbox-srlpt-zt-rhelbu

# 3. Verify Helm is installed
helm version
# Expected: v3.10+

# 4. Verify chart location
ls -la ~/Projects/zt-wilson-poc/charts/aap-operator/
# Expected: Chart.yaml, values.yaml, templates/, README.md

# 5. Create test documentation directory
mkdir -p /tmp/aap-testing-results
cd /tmp/aap-testing-results
```

### Cleanup Procedure (if needed)

```bash
# Delete existing AAP instance
oc delete ansibleautomationplatform --all -n sandbox-srlpt-zt-rhelbu

# Wait for all pods to terminate (5-10 minutes)
oc get pods -n sandbox-srlpt-zt-rhelbu -w

# Delete subscription (this removes operator)
oc delete subscription ansible-automation-platform-operator -n sandbox-srlpt-zt-rhelbu

# Delete CSV
oc delete csv -l operators.coreos.com/ansible-automation-platform-operator.sandbox-srlpt-zt-rhelbu -n sandbox-srlpt-zt-rhelbu

# Delete operator group
oc delete operatorgroup --all -n sandbox-srlpt-zt-rhelbu

# Verify clean state
oc get all -n sandbox-srlpt-zt-rhelbu
```

---

## Test 1: Operator Installation Only

**Objective**: Verify operator installs successfully without creating AAP instance.

**Expected Time**: 2-5 minutes

### Steps

```bash
# 1.1 Create values file for operator-only installation
cat > /tmp/aap-testing-results/t1-operator-only-values.yaml <<'EOF'
# Operator installation only - no AAP instance
namespace: sandbox-srlpt-zt-rhelbu

# We'll create just the OperatorGroup and Subscription
# Commenting out would require template changes, so we'll delete the CR after render
EOF

# 1.2 Render chart with operator-only components
cd ~/Projects/zt-wilson-poc
helm template test-t1 charts/aap-operator/ \
  -f /tmp/aap-testing-results/t1-operator-only-values.yaml \
  --set admin.password=redhat123 \
  > /tmp/aap-testing-results/t1-rendered.yaml

# 1.3 Extract only OperatorGroup and Subscription
cat /tmp/aap-testing-results/t1-rendered.yaml | \
  awk '/kind: OperatorGroup/,/^---$/ {print} /kind: Subscription/,/^---$/ {print}' | \
  grep -v '^---$' | head -n -1 \
  > /tmp/aap-testing-results/t1-operator-only.yaml

# 1.4 Record start time
echo "T1 Start: $(date -Iseconds)" | tee /tmp/aap-testing-results/t1-timing.log

# 1.5 Apply operator resources
oc apply -f /tmp/aap-testing-results/t1-operator-only.yaml

# 1.6 Watch CSV creation and status
oc get csv -n sandbox-srlpt-zt-rhelbu -w
# Press Ctrl+C when PHASE shows "Succeeded"

# 1.7 Record completion time
echo "T1 Complete: $(date -Iseconds)" | tee -a /tmp/aap-testing-results/t1-timing.log

# 1.8 Capture final state
oc get csv,subscription,operatorgroup -n sandbox-srlpt-zt-rhelbu \
  -o yaml > /tmp/aap-testing-results/t1-final-state.yaml
```

### Success Criteria

- [ ] OperatorGroup created
- [ ] Subscription created
- [ ] InstallPlan created automatically
- [ ] CSV reaches "Succeeded" phase
- [ ] Operator pod running (check with `oc get pods -n sandbox-srlpt-zt-rhelbu`)
- [ ] No AAP instance created (intentional)

### Documentation

```bash
# 1.9 Document results
cat > /tmp/aap-testing-results/t1-results.md <<EOF
# Test 1 Results: Operator Installation Only

## Timing
$(cat /tmp/aap-testing-results/t1-timing.log)

## CSV Status
\`\`\`
$(oc get csv -n sandbox-srlpt-zt-rhelbu)
\`\`\`

## Operator Pods
\`\`\`
$(oc get pods -n sandbox-srlpt-zt-rhelbu -l app.kubernetes.io/name=aap-operator)
\`\`\`

## Observations
- [Document any unexpected behavior]
- [Document operator version installed]
- [Document any warnings or errors]

## Status
- [ ] PASS
- [ ] FAIL (reason: _____________)
- [ ] BLOCKED (reason: _____________)
EOF

echo "T1 results documented in /tmp/aap-testing-results/t1-results.md"
```

---

## Test 2: Minimal AAP Deployment (Controller Only)

**Objective**: Deploy AAP with only automation controller, managed database.

**Expected Time**: 10-15 minutes

**Prerequisites**: Test 1 completed successfully (operator installed)

### Steps

```bash
# 2.1 Create values file for minimal deployment
cat > /tmp/aap-testing-results/t2-minimal-values.yaml <<'EOF'
namespace: sandbox-srlpt-zt-rhelbu

admin:
  username: admin
  password: redhat123

# Controller only, managed database
controller:
  enabled: true

hub:
  enabled: false

eda:
  enabled: false

lightspeed:
  enabled: false
EOF

# 2.2 Render full chart
cd ~/Projects/zt-wilson-poc
helm template test-t2 charts/aap-operator/ \
  -f /tmp/aap-testing-results/t2-minimal-values.yaml \
  > /tmp/aap-testing-results/t2-rendered.yaml

# 2.3 Review rendered AnsibleAutomationPlatform CR
grep -A 200 "kind: AnsibleAutomationPlatform" /tmp/aap-testing-results/t2-rendered.yaml | head -100

# 2.4 Record start time
echo "T2 Start: $(date -Iseconds)" | tee /tmp/aap-testing-results/t2-timing.log

# 2.5 Apply all resources
oc apply -f /tmp/aap-testing-results/t2-rendered.yaml

# 2.6 Monitor AnsibleAutomationPlatform CR creation
oc get ansibleautomationplatform -n sandbox-srlpt-zt-rhelbu

# 2.7 Watch pod creation (in separate terminal or check periodically)
watch -n 10 'oc get pods -n sandbox-srlpt-zt-rhelbu'

# 2.8 Monitor events for issues
oc get events -n sandbox-srlpt-zt-rhelbu --sort-by='.lastTimestamp' | tail -30

# 2.9 Wait for all pods to be Running (check every 2 minutes)
# Expected pods: platform gateway, platform redis, platform database, controller pods
oc get pods -n sandbox-srlpt-zt-rhelbu -o wide

# 2.10 Check for routes
oc get routes -n sandbox-srlpt-zt-rhelbu

# 2.11 Record completion time when all pods Running and routes created
echo "T2 Complete: $(date -Iseconds)" | tee -a /tmp/aap-testing-results/t2-timing.log
```

### Success Criteria

- [ ] Secret created: `aap-admin-password`
- [ ] AnsibleAutomationPlatform CR created
- [ ] Platform gateway pods running (api, redis)
- [ ] Platform database pod running
- [ ] Controller pods running (web, task)
- [ ] Routes created for platform gateway
- [ ] Route accessible via curl (HTTP 200 or redirect to login)
- [ ] No hub pods created
- [ ] No EDA pods created

### Verification

```bash
# 2.12 Test platform gateway accessibility
GATEWAY_URL=$(oc get route -n sandbox-srlpt-zt-rhelbu -o jsonpath='{.items[0].spec.host}' | grep gateway)
curl -sSL -o /dev/null -w "HTTP Status: %{http_code}\n" https://${GATEWAY_URL}/api/v2/ping/ -k

# 2.13 Verify admin credentials work
# (Manual step - access in browser or use API)
echo "Gateway URL: https://${GATEWAY_URL}"
echo "Username: admin"
echo "Password: redhat123"

# 2.14 Check database is managed (not external)
oc get pods -n sandbox-srlpt-zt-rhelbu | grep postgres
# Should see platform database pod
```

### Documentation

```bash
# 2.15 Capture deployment state
oc get all,ansibleautomationplatform,routes,secrets -n sandbox-srlpt-zt-rhelbu \
  -o yaml > /tmp/aap-testing-results/t2-final-state.yaml

# 2.16 Document results
cat > /tmp/aap-testing-results/t2-results.md <<EOF
# Test 2 Results: Minimal AAP Deployment (Controller Only)

## Timing
$(cat /tmp/aap-testing-results/t2-timing.log)

## Pods
\`\`\`
$(oc get pods -n sandbox-srlpt-zt-rhelbu)
\`\`\`

## Routes
\`\`\`
$(oc get routes -n sandbox-srlpt-zt-rhelbu)
\`\`\`

## Resource Usage
\`\`\`
$(oc adm top pods -n sandbox-srlpt-zt-rhelbu)
\`\`\`

## Accessibility Test
Gateway URL: https://${GATEWAY_URL}
\`\`\`
$(curl -sSL -o /dev/null -w "HTTP %{http_code}, Time: %{time_total}s\n" https://${GATEWAY_URL}/api/v2/ping/ -k)
\`\`\`

## Observations
- [Document unexpected behavior]
- [Document pod restart counts]
- [Document any errors in logs]
- [Document actual vs expected deployment time]

## Status
- [ ] PASS
- [ ] FAIL (reason: _____________)
- [ ] BLOCKED (reason: _____________)

## Next Steps
- [ ] If PASS: Proceed to Test 3
- [ ] If FAIL: Investigate logs, events, and AAP CR status
EOF

echo "T2 results documented in /tmp/aap-testing-results/t2-results.md"
```

---

## Test 3: Full AAP Stack Deployment

**Objective**: Deploy controller + hub + EDA with managed databases.

**Expected Time**: 15-25 minutes

**Prerequisites**: Test 2 completed (or namespace cleaned)

### Steps

```bash
# 3.1 If T2 is still deployed, delete it first
oc delete ansibleautomationplatform aap -n sandbox-srlpt-zt-rhelbu
oc delete secret aap-admin-password -n sandbox-srlpt-zt-rhelbu

# Wait for all AAP pods to terminate
while oc get pods -n sandbox-srlpt-zt-rhelbu | grep -q aap; do
  echo "Waiting for AAP pods to terminate..."
  sleep 10
done

# 3.2 Identify RWX storage class for hub
oc get storageclass
# Look for RWX (ReadWriteMany) storage class
# Common names: nfs-local-rwx, ocs-storagecluster-cephfs, netapp-file

# 3.3 Create values file for full deployment
cat > /tmp/aap-testing-results/t3-full-values.yaml <<'EOF'
namespace: sandbox-srlpt-zt-rhelbu

admin:
  username: admin
  password: redhat123

# Full stack deployment
controller:
  enabled: true

hub:
  enabled: true
  storage:
    type: file
    file:
      storageClass: "nfs-local-rwx"  # Update with actual RWX storage class
      size: "20Gi"  # Smaller than default for testing

eda:
  enabled: true

lightspeed:
  enabled: false  # Requires additional subscription
EOF

# 3.4 Render chart
cd ~/Projects/zt-wilson-poc
helm template test-t3 charts/aap-operator/ \
  -f /tmp/aap-testing-results/t3-full-values.yaml \
  > /tmp/aap-testing-results/t3-rendered.yaml

# 3.5 Verify hub storage configuration in rendered YAML
grep -A 10 "hub:" /tmp/aap-testing-results/t3-rendered.yaml | grep -A 5 "storage"

# 3.6 Record start time
echo "T3 Start: $(date -Iseconds)" | tee /tmp/aap-testing-results/t3-timing.log

# 3.7 Apply all resources
oc apply -f /tmp/aap-testing-results/t3-rendered.yaml

# 3.8 Monitor pod creation (expect more pods than T2)
watch -n 15 'oc get pods -n sandbox-srlpt-zt-rhelbu | grep -E "NAME|aap"'

# 3.9 Monitor PVC creation for hub
oc get pvc -n sandbox-srlpt-zt-rhelbu -w

# 3.10 Check events for any issues
oc get events -n sandbox-srlpt-zt-rhelbu --sort-by='.lastTimestamp' | tail -40

# 3.11 Record completion time when all pods Running
echo "T3 Complete: $(date -Iseconds)" | tee -a /tmp/aap-testing-results/t3-timing.log
```

### Success Criteria

- [ ] All controller pods running
- [ ] Hub pods running (api, content, worker, web, redis)
- [ ] Hub PVC created and bound (RWX)
- [ ] EDA pods running (api, ui, scheduler, workers, event-stream)
- [ ] All routes created (gateway, hub)
- [ ] All pods in Running state (no CrashLoopBackOff)
- [ ] Hub accessible via route
- [ ] EDA accessible via route

### Verification

```bash
# 3.12 Count pods by component
echo "Controller pods:"
oc get pods -n sandbox-srlpt-zt-rhelbu | grep controller | wc -l

echo "Hub pods:"
oc get pods -n sandbox-srlpt-zt-rhelbu | grep hub | wc -l

echo "EDA pods:"
oc get pods -n sandbox-srlpt-zt-rhelbu | grep eda | wc -l

# 3.13 Verify all routes
oc get routes -n sandbox-srlpt-zt-rhelbu -o custom-columns=NAME:.metadata.name,HOST:.spec.host

# 3.14 Test each UI is accessible
for route in $(oc get routes -n sandbox-srlpt-zt-rhelbu -o jsonpath='{.items[*].spec.host}'); do
  echo "Testing $route:"
  curl -sSL -o /dev/null -w "  HTTP %{http_code}\n" https://$route -k
done

# 3.15 Check PVC status
oc get pvc -n sandbox-srlpt-zt-rhelbu
```

### Documentation

```bash
# 3.16 Capture full deployment state
oc get all,ansibleautomationplatform,routes,pvc,secrets -n sandbox-srlpt-zt-rhelbu \
  -o yaml > /tmp/aap-testing-results/t3-final-state.yaml

# 3.17 Document results
cat > /tmp/aap-testing-results/t3-results.md <<EOF
# Test 3 Results: Full AAP Stack Deployment

## Timing
$(cat /tmp/aap-testing-results/t3-timing.log)

## Component Pod Counts
- Controller: $(oc get pods -n sandbox-srlpt-zt-rhelbu | grep -c controller || echo 0)
- Hub: $(oc get pods -n sandbox-srlpt-zt-rhelbu | grep -c hub || echo 0)
- EDA: $(oc get pods -n sandbox-srlpt-zt-rhelbu | grep -c eda || echo 0)
- Platform: $(oc get pods -n sandbox-srlpt-zt-rhelbu | grep -c platform || echo 0)

## Pods
\`\`\`
$(oc get pods -n sandbox-srlpt-zt-rhelbu)
\`\`\`

## PVCs
\`\`\`
$(oc get pvc -n sandbox-srlpt-zt-rhelbu)
\`\`\`

## Routes
\`\`\`
$(oc get routes -n sandbox-srlpt-zt-rhelbu)
\`\`\`

## Resource Usage
\`\`\`
$(oc adm top pods -n sandbox-srlpt-zt-rhelbu || echo "Metrics not available")
\`\`\`

## Observations
- [Document any component that failed to start]
- [Document PVC binding issues]
- [Document route accessibility]
- [Compare actual vs expected deployment time]

## Status
- [ ] PASS
- [ ] FAIL (reason: _____________)
- [ ] BLOCKED (reason: _____________)
EOF

echo "T3 results documented in /tmp/aap-testing-results/t3-results.md"
```

---

## Test 4: Controller with External Database

**Objective**: Deploy controller with pre-created external PostgreSQL database.

**Expected Time**: 10-15 minutes

**Prerequisites**: Test 2 or T3 cleaned up

### Steps

```bash
# 4.1 Deploy PostgreSQL pod as external database
cat > /tmp/aap-testing-results/t4-postgres-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: external-postgres
  namespace: sandbox-srlpt-zt-rhelbu
  labels:
    app: external-postgres
spec:
  containers:
  - name: postgresql
    image: registry.redhat.io/rhel9/postgresql-15:latest
    env:
    - name: POSTGRESQL_USER
      value: awx
    - name: POSTGRESQL_PASSWORD
      value: awxpassword
    - name: POSTGRESQL_DATABASE
      value: awx
    ports:
    - containerPort: 5432
      protocol: TCP
    volumeMounts:
    - name: postgres-data
      mountPath: /var/lib/pgsql/data
  volumes:
  - name: postgres-data
    emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: external-postgres
  namespace: sandbox-srlpt-zt-rhelbu
spec:
  selector:
    app: external-postgres
  ports:
  - port: 5432
    targetPort: 5432
    protocol: TCP
EOF

# 4.2 Deploy PostgreSQL
oc apply -f /tmp/aap-testing-results/t4-postgres-pod.yaml

# 4.3 Wait for PostgreSQL to be ready
oc wait --for=condition=ready pod/external-postgres -n sandbox-srlpt-zt-rhelbu --timeout=120s

# 4.4 Verify PostgreSQL is accessible
oc exec -it external-postgres -n sandbox-srlpt-zt-rhelbu -- psql -U awx -d awx -c '\l'

# 4.5 Create external database secret for controller
cat > /tmp/aap-testing-results/t4-controller-db-secret.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: controller-external-db
  namespace: sandbox-srlpt-zt-rhelbu
type: Opaque
stringData:
  host: "external-postgres.sandbox-srlpt-zt-rhelbu.svc.cluster.local"
  port: "5432"
  database: "awx"
  username: "awx"
  password: "awxpassword"
  type: "unmanaged"
EOF

oc apply -f /tmp/aap-testing-results/t4-controller-db-secret.yaml

# 4.6 Create values file with external database for controller
cat > /tmp/aap-testing-results/t4-external-db-values.yaml <<'EOF'
namespace: sandbox-srlpt-zt-rhelbu

admin:
  username: admin
  password: redhat123

controller:
  enabled: true
  externalDatabase:
    enabled: true
    secretName: controller-external-db

hub:
  enabled: false

eda:
  enabled: false

lightspeed:
  enabled: false
EOF

# 4.7 Render chart
cd ~/Projects/zt-wilson-poc
helm template test-t4 charts/aap-operator/ \
  -f /tmp/aap-testing-results/t4-external-db-values.yaml \
  > /tmp/aap-testing-results/t4-rendered.yaml

# 4.8 Verify controller postgres_configuration_secret is set
grep -A 5 "controller:" /tmp/aap-testing-results/t4-rendered.yaml | grep postgres_configuration_secret

# 4.9 Record start time
echo "T4 Start: $(date -Iseconds)" | tee /tmp/aap-testing-results/t4-timing.log

# 4.10 Apply AAP resources
oc apply -f /tmp/aap-testing-results/t4-rendered.yaml

# 4.11 Monitor pod creation
watch -n 10 'oc get pods -n sandbox-srlpt-zt-rhelbu | grep -E "NAME|aap|postgres"'

# 4.12 Check controller pods connect to external database
# Look for controller task pod logs
sleep 60  # Wait for controller to initialize
CONTROLLER_TASK_POD=$(oc get pods -n sandbox-srlpt-zt-rhelbu -l app.kubernetes.io/component=awx-task -o name | head -1)
oc logs $CONTROLLER_TASK_POD -n sandbox-srlpt-zt-rhelbu | grep -i database

# 4.13 Record completion time
echo "T4 Complete: $(date -Iseconds)" | tee -a /tmp/aap-testing-results/t4-timing.log
```

### Success Criteria

- [ ] External PostgreSQL pod running
- [ ] External database secret created
- [ ] Controller uses external database (verify in logs)
- [ ] No managed database pod created for controller
- [ ] Platform database still managed (separate from controller DB)
- [ ] Controller web UI accessible
- [ ] Controller can create/modify resources (test via API or UI)

### Verification

```bash
# 4.14 Verify no controller-specific database pod
oc get pods -n sandbox-srlpt-zt-rhelbu | grep -i database
# Should only see platform database, not controller database

# 4.15 Check database connections from external PostgreSQL
oc exec -it external-postgres -n sandbox-srlpt-zt-rhelbu -- \
  psql -U awx -d awx -c "SELECT count(*) FROM pg_stat_activity WHERE datname='awx';"
# Should see active connections from controller

# 4.16 Test controller functionality via API
GATEWAY_URL=$(oc get route -n sandbox-srlpt-zt-rhelbu -o jsonpath='{.items[0].spec.host}' | grep gateway)
curl -k -u admin:redhat123 https://${GATEWAY_URL}/api/v2/ping/
```

### Documentation

```bash
# 4.17 Document results
cat > /tmp/aap-testing-results/t4-results.md <<EOF
# Test 4 Results: Controller with External Database

## Timing
$(cat /tmp/aap-testing-results/t4-timing.log)

## Database Configuration
External PostgreSQL Pod: external-postgres
Controller DB Secret: controller-external-db
Database Name: awx

## Pods
\`\`\`
$(oc get pods -n sandbox-srlpt-zt-rhelbu | grep -E "NAME|postgres|controller|platform")
\`\`\`

## Database Connections
\`\`\`
$(oc exec -it external-postgres -n sandbox-srlpt-zt-rhelbu -- psql -U awx -d awx -c "SELECT count(*) FROM pg_stat_activity WHERE datname='awx';" 2>/dev/null || echo "Unable to query")
\`\`\`

## Controller Logs (database connection)
\`\`\`
$(oc logs $CONTROLLER_TASK_POD -n sandbox-srlpt-zt-rhelbu --tail=50 | grep -i database | head -10)
\`\`\`

## Observations
- [Document if controller connected to external DB successfully]
- [Document any errors in controller logs related to database]
- [Note whether platform database is still separate]

## Status
- [ ] PASS
- [ ] FAIL (reason: _____________)
- [ ] BLOCKED (reason: _____________)

## Learning
- [Document any unexpected behavior]
- [Document differences from managed database deployment]
EOF

echo "T4 results documented in /tmp/aap-testing-results/t4-results.md"
```

---

## Test 5: Hub with External Database

**Objective**: Deploy hub with external PostgreSQL (requires hstore extension).

**Expected Time**: 15-20 minutes

**Prerequisites**: T4 cleaned up or fresh namespace

### Steps

```bash
# 5.1 Create separate PostgreSQL for Hub (requires hstore extension)
cat > /tmp/aap-testing-results/t5-hub-postgres-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: external-postgres-hub
  namespace: sandbox-srlpt-zt-rhelbu
  labels:
    app: external-postgres-hub
spec:
  containers:
  - name: postgresql
    image: registry.redhat.io/rhel9/postgresql-15:latest
    env:
    - name: POSTGRESQL_USER
      value: galaxy
    - name: POSTGRESQL_PASSWORD
      value: galaxypassword
    - name: POSTGRESQL_DATABASE
      value: galaxy
    ports:
    - containerPort: 5432
      protocol: TCP
    volumeMounts:
    - name: postgres-data
      mountPath: /var/lib/pgsql/data
  volumes:
  - name: postgres-data
    emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: external-postgres-hub
  namespace: sandbox-srlpt-zt-rhelbu
spec:
  selector:
    app: external-postgres-hub
  ports:
  - port: 5432
    targetPort: 5432
    protocol: TCP
EOF

# 5.2 Deploy Hub PostgreSQL
oc apply -f /tmp/aap-testing-results/t5-hub-postgres-pod.yaml

# 5.3 Wait for PostgreSQL to be ready
oc wait --for=condition=ready pod/external-postgres-hub -n sandbox-srlpt-zt-rhelbu --timeout=120s

# 5.4 Enable hstore extension (REQUIRED for Hub)
oc exec -it external-postgres-hub -n sandbox-srlpt-zt-rhelbu -- \
  psql -U galaxy -d galaxy -c "CREATE EXTENSION IF NOT EXISTS hstore;"

# 5.5 Verify hstore extension
oc exec -it external-postgres-hub -n sandbox-srlpt-zt-rhelbu -- \
  psql -U galaxy -d galaxy -c "\dx" | grep hstore

# 5.6 Create external database secret for hub
cat > /tmp/aap-testing-results/t5-hub-db-secret.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: hub-external-db
  namespace: sandbox-srlpt-zt-rhelbu
type: Opaque
stringData:
  host: "external-postgres-hub.sandbox-srlpt-zt-rhelbu.svc.cluster.local"
  port: "5432"
  database: "galaxy"
  username: "galaxy"
  password: "galaxypassword"
  type: "unmanaged"
EOF

oc apply -f /tmp/aap-testing-results/t5-hub-db-secret.yaml

# 5.7 Get RWX storage class for hub content
oc get storageclass | grep -i rwx

# 5.8 Create values file
cat > /tmp/aap-testing-results/t5-hub-external-db-values.yaml <<'EOF'
namespace: sandbox-srlpt-zt-rhelbu

admin:
  username: admin
  password: redhat123

controller:
  enabled: true

hub:
  enabled: true
  externalDatabase:
    enabled: true
    secretName: hub-external-db
  storage:
    type: file
    file:
      storageClass: "nfs-local-rwx"  # Update with actual RWX storage class
      size: "10Gi"

eda:
  enabled: false

lightspeed:
  enabled: false
EOF

# 5.9 Render chart
cd ~/Projects/zt-wilson-poc
helm template test-t5 charts/aap-operator/ \
  -f /tmp/aap-testing-results/t5-hub-external-db-values.yaml \
  > /tmp/aap-testing-results/t5-rendered.yaml

# 5.10 Verify hub postgres_configuration_secret is set
grep -A 10 "hub:" /tmp/aap-testing-results/t5-rendered.yaml | grep postgres_configuration_secret

# 5.11 Record start time
echo "T5 Start: $(date -Iseconds)" | tee /tmp/aap-testing-results/t5-timing.log

# 5.12 Apply AAP resources
oc apply -f /tmp/aap-testing-results/t5-rendered.yaml

# 5.13 Monitor hub pod creation
watch -n 10 'oc get pods -n sandbox-srlpt-zt-rhelbu | grep -E "NAME|hub|postgres"'

# 5.14 Check hub logs for database connection
sleep 90  # Wait for hub to initialize
HUB_API_POD=$(oc get pods -n sandbox-srlpt-zt-rhelbu -l app.kubernetes.io/component=galaxy-api -o name | head -1)
oc logs $HUB_API_POD -n sandbox-srlpt-zt-rhelbu | grep -i database

# 5.15 Record completion time
echo "T5 Complete: $(date -Iseconds)" | tee -a /tmp/aap-testing-results/t5-timing.log
```

### Success Criteria

- [ ] External PostgreSQL for hub running
- [ ] hstore extension enabled in hub database
- [ ] Hub external database secret created
- [ ] Hub uses external database (verify in logs)
- [ ] Hub PVC created for content storage
- [ ] All hub pods running (api, content, worker, web, redis)
- [ ] Hub accessible via route
- [ ] Controller still uses managed database (separate from hub)

### Verification

```bash
# 5.16 Verify hstore extension is active
oc exec -it external-postgres-hub -n sandbox-srlpt-zt-rhelbu -- \
  psql -U galaxy -d galaxy -c "SELECT extname, extversion FROM pg_extension WHERE extname='hstore';"

# 5.17 Check database connections
oc exec -it external-postgres-hub -n sandbox-srlpt-zt-rhelbu -- \
  psql -U galaxy -d galaxy -c "SELECT count(*) FROM pg_stat_activity WHERE datname='galaxy';"

# 5.18 Test hub UI accessibility
HUB_ROUTE=$(oc get route -n sandbox-srlpt-zt-rhelbu -o jsonpath='{.items[*].spec.host}' | grep hub)
curl -k -sSL -o /dev/null -w "Hub HTTP: %{http_code}\n" https://${HUB_ROUTE}
```

### Documentation

```bash
# 5.19 Document results
cat > /tmp/aap-testing-results/t5-results.md <<EOF
# Test 5 Results: Hub with External Database

## Timing
$(cat /tmp/aap-testing-results/t5-timing.log)

## Database Configuration
External PostgreSQL Pod: external-postgres-hub
Hub DB Secret: hub-external-db
Database Name: galaxy
hstore Extension: $(oc exec -it external-postgres-hub -n sandbox-srlpt-zt-rhelbu -- psql -U galaxy -d galaxy -c "\dx" | grep hstore || echo "Not verified")

## Pods
\`\`\`
$(oc get pods -n sandbox-srlpt-zt-rhelbu | grep -E "NAME|hub|postgres")
\`\`\`

## PVCs (Hub Content Storage)
\`\`\`
$(oc get pvc -n sandbox-srlpt-zt-rhelbu | grep hub)
\`\`\`

## Database Connections
\`\`\`
$(oc exec -it external-postgres-hub -n sandbox-srlpt-zt-rhelbu -- psql -U galaxy -d galaxy -c "SELECT count(*) FROM pg_stat_activity WHERE datname='galaxy';" 2>/dev/null || echo "Unable to query")
\`\`\`

## Observations
- [Document if hub connected to external DB successfully]
- [Document any errors related to hstore extension]
- [Document hub content storage PVC status]

## Status
- [ ] PASS
- [ ] FAIL (reason: _____________)
- [ ] BLOCKED (reason: _____________)

## Learning
- [Document hstore requirement and how it was satisfied]
- [Document any differences in hub behavior with external DB]
EOF

echo "T5 results documented in /tmp/aap-testing-results/t5-results.md"
```

---

## Test 6: Full External Database Configuration

**Objective**: Deploy all components (controller, hub, EDA, platform) with external databases.

**Expected Time**: 15-20 minutes

**Prerequisites**: All previous tests cleaned up

### Steps

```bash
# 6.1 Deploy separate PostgreSQL for each component
# (In production, same PostgreSQL instance with different databases is supported)
cat > /tmp/aap-testing-results/t6-all-postgres-pods.yaml <<'EOF'
# Platform database
---
apiVersion: v1
kind: Pod
metadata:
  name: external-postgres-platform
  namespace: sandbox-srlpt-zt-rhelbu
  labels:
    app: external-postgres-platform
spec:
  containers:
  - name: postgresql
    image: registry.redhat.io/rhel9/postgresql-15:latest
    env:
    - name: POSTGRESQL_USER
      value: platform
    - name: POSTGRESQL_PASSWORD
      value: platformpassword
    - name: POSTGRESQL_DATABASE
      value: platform
    ports:
    - containerPort: 5432
    volumeMounts:
    - name: postgres-data
      mountPath: /var/lib/pgsql/data
  volumes:
  - name: postgres-data
    emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: external-postgres-platform
  namespace: sandbox-srlpt-zt-rhelbu
spec:
  selector:
    app: external-postgres-platform
  ports:
  - port: 5432
    targetPort: 5432

# Controller database
---
apiVersion: v1
kind: Pod
metadata:
  name: external-postgres-controller
  namespace: sandbox-srlpt-zt-rhelbu
  labels:
    app: external-postgres-controller
spec:
  containers:
  - name: postgresql
    image: registry.redhat.io/rhel9/postgresql-15:latest
    env:
    - name: POSTGRESQL_USER
      value: awx
    - name: POSTGRESQL_PASSWORD
      value: awxpassword
    - name: POSTGRESQL_DATABASE
      value: awx
    ports:
    - containerPort: 5432
    volumeMounts:
    - name: postgres-data
      mountPath: /var/lib/pgsql/data
  volumes:
  - name: postgres-data
    emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: external-postgres-controller
  namespace: sandbox-srlpt-zt-rhelbu
spec:
  selector:
    app: external-postgres-controller
  ports:
  - port: 5432
    targetPort: 5432

# Hub database (with hstore)
---
apiVersion: v1
kind: Pod
metadata:
  name: external-postgres-hub
  namespace: sandbox-srlpt-zt-rhelbu
  labels:
    app: external-postgres-hub
spec:
  containers:
  - name: postgresql
    image: registry.redhat.io/rhel9/postgresql-15:latest
    env:
    - name: POSTGRESQL_USER
      value: galaxy
    - name: POSTGRESQL_PASSWORD
      value: galaxypassword
    - name: POSTGRESQL_DATABASE
      value: galaxy
    ports:
    - containerPort: 5432
    volumeMounts:
    - name: postgres-data
      mountPath: /var/lib/pgsql/data
  volumes:
  - name: postgres-data
    emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: external-postgres-hub
  namespace: sandbox-srlpt-zt-rhelbu
spec:
  selector:
    app: external-postgres-hub
  ports:
  - port: 5432
    targetPort: 5432

# EDA database
---
apiVersion: v1
kind: Pod
metadata:
  name: external-postgres-eda
  namespace: sandbox-srlpt-zt-rhelbu
  labels:
    app: external-postgres-eda
spec:
  containers:
  - name: postgresql
    image: registry.redhat.io/rhel9/postgresql-15:latest
    env:
    - name: POSTGRESQL_USER
      value: eda
    - name: POSTGRESQL_PASSWORD
      value: edapassword
    - name: POSTGRESQL_DATABASE
      value: eda
    ports:
    - containerPort: 5432
    volumeMounts:
    - name: postgres-data
      mountPath: /var/lib/pgsql/data
  volumes:
  - name: postgres-data
    emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: external-postgres-eda
  namespace: sandbox-srlpt-zt-rhelbu
spec:
  selector:
    app: external-postgres-eda
  ports:
  - port: 5432
    targetPort: 5432
EOF

# 6.2 Deploy all PostgreSQL pods
oc apply -f /tmp/aap-testing-results/t6-all-postgres-pods.yaml

# 6.3 Wait for all PostgreSQL pods to be ready
for pod in external-postgres-platform external-postgres-controller external-postgres-hub external-postgres-eda; do
  oc wait --for=condition=ready pod/$pod -n sandbox-srlpt-zt-rhelbu --timeout=120s
done

# 6.4 Enable hstore extension for hub database
oc exec -it external-postgres-hub -n sandbox-srlpt-zt-rhelbu -- \
  psql -U galaxy -d galaxy -c "CREATE EXTENSION IF NOT EXISTS hstore;"

# 6.5 Create secrets for all components
cat > /tmp/aap-testing-results/t6-all-db-secrets.yaml <<'EOF'
# Platform database secret
---
apiVersion: v1
kind: Secret
metadata:
  name: platform-external-db
  namespace: sandbox-srlpt-zt-rhelbu
type: Opaque
stringData:
  host: "external-postgres-platform.sandbox-srlpt-zt-rhelbu.svc.cluster.local"
  port: "5432"
  database: "platform"
  username: "platform"
  password: "platformpassword"
  type: "unmanaged"

# Controller database secret
---
apiVersion: v1
kind: Secret
metadata:
  name: controller-external-db
  namespace: sandbox-srlpt-zt-rhelbu
type: Opaque
stringData:
  host: "external-postgres-controller.sandbox-srlpt-zt-rhelbu.svc.cluster.local"
  port: "5432"
  database: "awx"
  username: "awx"
  password: "awxpassword"
  type: "unmanaged"

# Hub database secret
---
apiVersion: v1
kind: Secret
metadata:
  name: hub-external-db
  namespace: sandbox-srlpt-zt-rhelbu
type: Opaque
stringData:
  host: "external-postgres-hub.sandbox-srlpt-zt-rhelbu.svc.cluster.local"
  port: "5432"
  database: "galaxy"
  username: "galaxy"
  password: "galaxypassword"
  type: "unmanaged"

# EDA database secret
---
apiVersion: v1
kind: Secret
metadata:
  name: eda-external-db
  namespace: sandbox-srlpt-zt-rhelbu
type: Opaque
stringData:
  host: "external-postgres-eda.sandbox-srlpt-zt-rhelbu.svc.cluster.local"
  port: "5432"
  database: "eda"
  username: "eda"
  password: "edapassword"
  type: "unmanaged"
EOF

oc apply -f /tmp/aap-testing-results/t6-all-db-secrets.yaml

# 6.6 Create values file with all external databases
cat > /tmp/aap-testing-results/t6-all-external-db-values.yaml <<'EOF'
namespace: sandbox-srlpt-zt-rhelbu

admin:
  username: admin
  password: redhat123

# Platform database external
database:
  externalDatabase:
    enabled: true
    secretName: platform-external-db

# Controller with external database
controller:
  enabled: true
  externalDatabase:
    enabled: true
    secretName: controller-external-db

# Hub with external database
hub:
  enabled: true
  externalDatabase:
    enabled: true
    secretName: hub-external-db
  storage:
    type: file
    file:
      storageClass: "nfs-local-rwx"
      size: "10Gi"

# EDA with external database
eda:
  enabled: true
  externalDatabase:
    enabled: true
    secretName: eda-external-db

lightspeed:
  enabled: false
EOF

# 6.7 Render chart
cd ~/Projects/zt-wilson-poc
helm template test-t6 charts/aap-operator/ \
  -f /tmp/aap-testing-results/t6-all-external-db-values.yaml \
  > /tmp/aap-testing-results/t6-rendered.yaml

# 6.8 Verify all postgres_configuration_secret settings
grep -A 3 "postgres_configuration_secret:" /tmp/aap-testing-results/t6-rendered.yaml

# 6.9 Record start time
echo "T6 Start: $(date -Iseconds)" | tee /tmp/aap-testing-results/t6-timing.log

# 6.10 Apply AAP resources
oc apply -f /tmp/aap-testing-results/t6-rendered.yaml

# 6.11 Monitor all pod creation
watch -n 15 'oc get pods -n sandbox-srlpt-zt-rhelbu'

# 6.12 Record completion time
echo "T6 Complete: $(date -Iseconds)" | tee -a /tmp/aap-testing-results/t6-timing.log
```

### Success Criteria

- [ ] All 4 external PostgreSQL pods running
- [ ] All 4 database secrets created
- [ ] No managed database pods created
- [ ] All AAP components using external databases
- [ ] Platform gateway functional
- [ ] Controller functional
- [ ] Hub functional
- [ ] EDA functional

### Documentation Template

*(Similar structure to T5, document all components and their database connections)*

---

## Test 7: Pre-Population Workflow

**Objective**: Pre-populate controller database, deploy AAP pointing to it.

**Expected Time**: 15-20 minutes

**Prerequisites**: Knowledge of AAP configuration (from T2 or T4)

### Steps Overview

```bash
# 7.1 Deploy AAP with managed database
# 7.2 Configure AAP via UI/API (create org, credentials, inventory, projects)
# 7.3 Dump controller database
# 7.4 Delete AAP instance
# 7.5 Deploy external PostgreSQL with restored dump
# 7.6 Deploy AAP pointing to pre-populated database
# 7.7 Verify configuration persisted
```

*(Detailed steps to be documented during actual test execution)*

---

## Test 8: Resource Quota Compliance

**Objective**: Deploy AAP in namespace with ResourceQuota, verify deployment succeeds.

**Expected Time**: 10-15 minutes

### Steps

```bash
# 8.1 Check existing ResourceQuota
oc get resourcequota -n sandbox-srlpt-zt-rhelbu -o yaml

# 8.2 Document quota limits
# 8.3 Deploy minimal AAP with custom resource requirements
# 8.4 Verify all pods fit within quota
# 8.5 Document actual resource usage vs quota
```

---

## Test 9: Chart Upgrade/Update

**Objective**: Update values and re-apply, verify changes apply without disruption.

**Expected Time**: 5-10 minutes

### Steps

```bash
# 9.1 Deploy AAP with initial configuration (from T2)
# 9.2 Make changes to values (e.g., increase replicas, change resource limits)
# 9.3 Re-render chart
# 9.4 Apply changes
# 9.5 Verify changes applied (check pod specs)
# 9.6 Verify no data loss
```

---

## Results Summary Template

After all tests complete, create `/tmp/aap-testing-results/SUMMARY.md`:

```markdown
# AAP Helm Chart Testing Summary

## Test Execution Date
Started: [DATE]
Completed: [DATE]

## Test Results

| Test | Scenario | Status | Time | Notes |
|------|----------|--------|------|-------|
| T1 | Operator only | ⏳/✅/❌ | X min | |
| T2 | Minimal (controller) | ⏳/✅/❌ | X min | |
| T3 | Full stack | ⏳/✅/❌ | X min | |
| T4 | Controller external DB | ⏳/✅/❌ | X min | |
| T5 | Hub external DB | ⏳/✅/❌ | X min | |
| T6 | All external DB | ⏳/✅/❌ | X min | |
| T7 | Pre-population | ⏳/✅/❌ | X min | |
| T8 | Resource quota | ⏳/✅/❌ | X min | |
| T9 | Chart upgrade | ⏳/✅/❌ | X min | |

## Key Findings

### What Works
- [List successful scenarios]

### Issues Found
- [List issues and workarounds]

### Documentation Gaps
- [List areas needing more documentation]

## Recommendations for Labs

### Deployment Times
- Operator installation: X-Y minutes
- Minimal AAP: X-Y minutes
- Full stack: X-Y minutes

### Best Practices
- [List learned best practices]

### External Database Recommendations
- [Document when to use external vs managed]
- [Document pre-population workflow timing]

## Files Created
$(ls -lh /tmp/aap-testing-results/)
```

---

## Next Steps After Testing

1. **Update Helm Chart** based on findings
2. **Update README.md** with actual deployment times and verified examples
3. **Create troubleshooting guide** from issues encountered
4. **Document pre-population workflow** if T7 succeeds
5. **Update values.yaml** with production-ready defaults
6. **Create AgnosticD integration** (`config/helm-charts.yaml`)
7. **Commit findings** to cursor-revisit knowledge base

---

**END OF TESTING PLAN**
