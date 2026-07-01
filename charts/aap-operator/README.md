# AAP Instance Helm Chart

Helm chart for deploying Ansible Automation Platform 2.7 instances on OpenShift Container Platform.

## Overview

This chart deploys:
1. **Secret** - Admin password (if not using existing secret)
2. **AnsibleAutomationPlatform CR** - Creates configured AAP instance

**Note:** This chart assumes the AAP 2.7 operator is already installed cluster-scoped by a cluster administrator.

## Prerequisites

- OpenShift Container Platform 4.12+ (see [AAP Life Cycle](https://access.redhat.com/support/policy/updates/ansible-automation-platform))
- **AAP 2.7 cluster-scoped operator pre-installed** (requires cluster-admin)
- Valid Red Hat Ansible Automation Platform subscription
- Namespace admin permissions for target namespace
- Helm 3.10+ (for rendering templates)

## Quick Start

### 1. Install with default configuration

Deploy AAP with automation controller only (minimal configuration):

```bash
helm template aap charts/aap-operator/ \
  --set admin.password=redhat123 \
  --set namespace=my-aap-namespace \
  | oc apply -f -
```

### 2. Install with all components

Deploy full AAP stack (controller, hub, EDA):

```bash
helm template aap charts/aap-operator/ \
  --set admin.password=redhat123 \
  --set namespace=my-aap-namespace \
  --set hub.enabled=true \
  --set hub.storage.file.storageClass=nfs-local-rwx \
  --set eda.enabled=true \
  | oc apply -f -
```

### 3. Using a values file

```bash
# Create custom values file
cat > my-values.yaml <<EOF
namespace: sandbox-test-zt-rhelbu
admin:
  password: redhat123
controller:
  enabled: true
hub:
  enabled: false
eda:
  enabled: false
EOF

# Deploy
helm template aap charts/aap-operator/ -f my-values.yaml | oc apply -f -
```

## Configuration

### Required Configuration

| Parameter | Description | Example |
|-----------|-------------|---------|
| `namespace` | Target namespace for AAP | `my-aap-namespace` |
| `admin.password` | Admin user password | `redhat123` |

### Component Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `controller.enabled` | `true` | Enable automation controller |
| `hub.enabled` | `false` | Enable private automation hub |
| `eda.enabled` | `false` | Enable Event-Driven Ansible |
| `lightspeed.enabled` | `false` | Enable Ansible Lightspeed (AI) |

### Storage Configuration

When enabling automation hub with file storage:

```yaml
hub:
  enabled: true
  storage:
    type: file
    file:
      storageClass: nfs-local-rwx  # Must be RWX storage class
      size: 50Gi
```

### External Database Configuration

To use pre-populated external databases:

```yaml
controller:
  externalDatabase:
    enabled: true
    secretName: controller-external-db
```

Create the secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: controller-external-db
  namespace: my-aap-namespace
type: Opaque
stringData:
  host: "postgresql.example.com"
  port: "5432"
  database: "awx"
  username: "awx"
  password: "password"
  type: "unmanaged"
```

## Deployment Workflow

1. **Operator Installation** (2-5 minutes)
   - Subscription creates InstallPlan
   - OLM installs operator pods
   - CSV reaches "Succeeded" phase

2. **AAP Instance Creation** (5-15 minutes depending on components)
   - Platform gateway pods start
   - Component pods start (controller, hub, eda)
   - Routes created for web access

3. **Verification**

```bash
# Check operator installation
oc get csv -n my-aap-namespace

# Check AAP instance
oc get ansibleautomationplatform -n my-aap-namespace

# Check pods
oc get pods -n my-aap-namespace

# Get admin password (if auto-generated)
oc get secret aap-admin-password -n my-aap-namespace -o jsonpath='{.data.password}' | base64 -d

# Get platform gateway route
oc get route -n my-aap-namespace | grep gateway
```

## Resource Requirements

Default resource requirements follow Red Hat documentation. Customize in values.yaml:

```yaml
controller:
  resources:
    task:
      requests:
        cpu: "200m"      # Increase for heavy workloads
        memory: "300Mi"
      limits:
        cpu: "2000m"
        memory: "2400Mi"
```

## Troubleshooting

### Operator not installing

```bash
# Check subscription
oc get subscription ansible-automation-platform -n my-aap-namespace -o yaml

# Check install plan
oc get installplan -n my-aap-namespace

# Check operator logs
oc logs -n my-aap-namespace -l app.kubernetes.io/name=aap-operator
```

### AAP instance not creating

```bash
# Check AnsibleAutomationPlatform CR
oc describe ansibleautomationplatform aap -n my-aap-namespace

# Check events
oc get events -n my-aap-namespace --sort-by='.lastTimestamp' | tail -20

# Check operator logs
oc logs -n my-aap-namespace deployment/aap-operator-controller-manager
```

## Integration with AgnosticD

This chart can be used with `ocp4_workload_helm_from_content_repo`:

```yaml
# In content repo: config/helm-charts.yaml
charts:
  - name: aap-operator
    enabled: true
    source:
      type: path
      path: charts/aap-operator
    release:
      name: aap
      namespace: "{{ guid }}"
      values:
        namespace: "{{ guid }}"
        admin:
          password: redhat123
        controller:
          enabled: true
        hub:
          enabled: false
        eda:
          enabled: false
```

## References

- [AAP 2.7 Documentation](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7)
- [AAP Operator Customization](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/html/deploying_the_red_hat_ansible_automation_platform_operator_on_openshift_container_platform/assembly-platform-customize-ocp)
- [External Database Configuration](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/html/deploying_the_red_hat_ansible_automation_platform_operator_on_openshift_container_platform/assembly-platform-ext-database-ocp)

## License

Red Hat Demo Platform - Internal Use
