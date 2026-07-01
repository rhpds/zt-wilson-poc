# AAP Helm Deployment Testing Repository

**Purpose**: Test Helm-based deployment of Ansible Automation Platform (AAP) in OpenShift sandbox namespace.

**Branch**: `aac-helm-deployment`  
**Test Environment**: Sandbox namespace on CNV clusters

---

## Development Workflow (2026 Best Practices)

### Git Workflow

**Branch Protection**:
- Main branch is protected (no direct commits)
- All changes via pull requests with review
- Use feature branches: `feature/<name>`, `fix/<name>`, `test/<name>`

**Commit Standards**:
- Conventional commits: `type(scope): description`
  - `feat:` new features
  - `fix:` bug fixes
  - `docs:` documentation only
  - `test:` test changes
  - `refactor:` code refactoring
  - `chore:` maintenance tasks

**Code Review Requirements**:
- Every PR must include: what changed, why, and testing evidence
- Reviewers check: functionality, security, maintainability
- No merge without approval

### Helm Chart Development Standards

**Chart Structure** (from Helm 4.x best practices):
```
charts/aap/
├── Chart.yaml           # Chart metadata
├── values.yaml          # Default configuration
├── values.prod.yaml     # Production overrides
├── values.sandbox.yaml  # Sandbox overrides
├── templates/
│   ├── _helpers.tpl     # Named templates (labels, names)
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── route.yaml
│   ├── NOTES.txt        # Post-install instructions
│   └── tests/           # Helm test hooks
└── README.md
```

**Template Best Practices**:
1. **Templates describe structure, not environment behavior**
   - Move environment-specific values to `values.yaml`
   - Use hierarchical keys: `controller.replicas`, not `controllerReplicas`
   - Document every value with YAML comments

2. **Security by default**:
   - Quote user-provided values: `{{ .Values.name | quote }}`
   - Never hard-code secrets
   - Use `lookup` function carefully (breaks declarative nature)

3. **Validation**:
   - Run `helm lint` before every commit
   - Use `helm template` to check output
   - Validate with `kubeconform` or `kubeval`
   - Add Helm tests in `templates/tests/`

4. **Deployment Safety**:
   - Use `helm upgrade --install --atomic` for idempotent deploys
   - `--atomic` auto-rolls back on failure
   - Test rollback: `helm rollback <release> <revision>`

### Infrastructure as Code (IaC) Principles

**GitOps Workflow**:
- **Git is single source of truth** for all configuration
- All infrastructure changes via Git (no kubectl apply from laptop)
- PR review = change control
- Merge = deployment trigger (via CI/CD)

**Directory Structure**:
```
zt-wilson-poc/
├── charts/              # Helm charts
├── config/              # Static manifests (instances.yaml)
├── setup-automation/    # Post-deploy configuration scripts
├── runtime-automation/  # Per-module scripts
└── docs/                # Documentation
```

**Change Process**:
1. Create feature branch
2. Make changes (Helm values, templates, scripts)
3. Test locally: `helm template`, `helm install --dry-run`
4. Commit with conventional commit message
5. Open PR with testing evidence
6. Review + approval
7. Merge triggers deployment (future: ArgoCD/Flux)

### Code Quality Standards

**Clean Code Principles** (applied to YAML, Jinja2, Bash):

1. **DRY (Don't Repeat Yourself)**:
   - Use Helm `_helpers.tpl` for repeated patterns
   - Extract common logic to named templates
   - Bad: copying `metadata.labels` blocks
   - Good: `{{- include "aap.labels" . }}`

2. **YAGNI (You Ain't Gonna Need It)**:
   - Don't add features/config until actually needed
   - Start minimal, expand when required
   - Avoid premature optimization

3. **Readability**:
   - Meaningful names: `controller_admin_password` not `cap`
   - Comment the "why", not the "what"
   - Use whitespace to group related config

4. **Modularity**:
   - One template per resource type
   - Separate concerns: deployment ≠ service ≠ route
   - Keep functions/scripts small and focused

**YAML Best Practices**:
- Indent with 2 spaces (never tabs)
- Quote strings when ambiguous
- Use `|` for multi-line strings, `>` for folded
- Run `yamllint -c .yamllint` before commit

**Bash Script Standards**:
- Use `#!/bin/bash` shebang
- Enable strict mode: `set -euo pipefail`
- Quote variables: `"${VAR}"` not `$VAR`
- Check command success: `if ! command; then ... fi`
- Comment complex logic

### Testing Strategy

**Levels**:
1. **Linting**: `yamllint`, `helm lint`, `shellcheck`
2. **Template validation**: `helm template`, `kubeconform`
3. **Dry-run**: `helm install --dry-run --debug`
4. **Integration**: Deploy to sandbox, run smoke tests
5. **E2E**: Full lab workflow validation

**Before Every Commit**:
```bash
# Lint YAML files
yamllint -c .yamllint charts/

# Lint Helm chart
helm lint charts/aap/

# Validate templates
helm template test-release charts/aap/ \
  -f charts/aap/values.sandbox.yaml \
  | kubeconform -strict

# Check bash scripts
shellcheck setup-automation/*.sh
```

**Test in Sandbox**:
```bash
# Deploy to sandbox namespace
helm upgrade --install aap-test charts/aap/ \
  -f charts/aap/values.sandbox.yaml \
  --namespace sandbox-<guid> \
  --atomic \
  --timeout 10m

# Run Helm tests
helm test aap-test -n sandbox-<guid>

# Validate AAP accessibility
curl -k https://control-<guid>.apps.cluster.example.com
```

### Documentation Requirements

**Every PR Must Include**:
- What changed (feature, fix, config update)
- Why the change was needed
- How to test/verify the change
- Impact on existing deployments

**Chart README.md Must Document**:
- Prerequisites (OCP version, CNV, storage class)
- Installation steps
- Configuration options (values.yaml parameters)
- Upgrade procedure
- Troubleshooting common issues

**Inline Documentation**:
- YAML: comment every configurable value in `values.yaml`
- Templates: explain non-obvious Helm logic
- Scripts: document expected env vars, side effects

---

## Claude Code Behavioral Rules

**When working in this repository**:

### Code Generation
1. **Apply clean code principles**: DRY, YAGNI, meaningful names
2. **Follow Helm 4.x best practices**: templates in _helpers.tpl, quote values, hierarchical keys
3. **Security first**: never hard-code credentials, quote user input
4. **Comment the "why"**: explain non-obvious decisions, not syntax

### Change Management
1. **Verify current state first**: read files before editing
2. **Explain changes**: what, why, impact before making them
3. **Test commands**: provide lint/validation commands after changes
4. **GitOps mindset**: all changes should be Git-committable

### Testing Approach
1. **Lint before commit**: run yamllint, helm lint, shellcheck
2. **Validate templates**: use `helm template` to check output
3. **Provide test commands**: give exact commands to verify changes
4. **Sandbox testing**: remind about sandbox deployment testing

### Documentation
1. **Update docs with code**: when changing templates, update README
2. **Comment values.yaml**: every parameter needs description
3. **PR descriptions**: what/why/how format
4. **Keep examples current**: test snippets should work as-is

### Resource Efficiency
1. **Start minimal**: don't over-engineer initial implementation
2. **Iterate based on need**: add complexity only when required
3. **Reference production**: check reference lab patterns before inventing

### Error Handling
1. **Provide diagnostic commands**: when things fail, give debug steps
2. **Check recent changes**: git diff to understand what broke
3. **Systematic debugging**: logs → events → describe → fix
4. **Document solutions**: update troubleshooting docs

---

## Reference Resources

**Key Patterns**:
- Production lab: `~/Projects/zt-ans-bu-intro-controller-aap25/`
- Setup script patterns: ansible.controller collection usage
- AAP Operator research: `~/Projects/cursor-revisit/platform/aap-operator-openshift-deployment-research.md`

**External Documentation**:
- [Helm Best Practices (Official)](https://helm.sh/docs/chart_best_practices/)
- [Kubernetes API Reference](https://kubernetes.io/docs/reference/kubernetes-api/)
- [AAP Operator Docs](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/)

**CI/CD Future State**:
- ArgoCD or Flux for GitOps continuous deployment
- Automated testing pipeline (lint → template → deploy → test)
- Automatic rollback on test failure

---

**Status**: Active development  
**Last Updated**: 2026-06-24  
**Contact**: RHDP Zerotouch team
