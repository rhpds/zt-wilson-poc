# setup-automation/

This directory is optional for Helm-only deployments but included for consistency with RHDP content repo structure.

## Purpose

The `setup` init container (if enabled) runs Ansible playbooks from this directory to configure VMs after they boot but before the lab is accessible to users.

## For This Deployment

This Foreman deployment:
- Has no VMs (`virtualmachines: []` in instances.yaml)
- All infrastructure deployed via Helm charts
- No post-boot VM configuration needed

The `setup` init container is not included in the Showroom pod for Helm-only labs.

## What Would Go Here

In labs with VMs:
```
setup-automation/
├── ansible.cfg
├── main.yml          # Playbook entry point
└── setup-<vmname>.sh # Per-VM setup scripts
```

The setup container:
1. Runs during Showroom pod initialization (before main containers start)
2. SSHs to VMs using credentials from `_showroom_user_data`
3. Executes `main.yml` which calls `setup-<vmname>.sh` scripts
4. Exits after completion (pod continues with main containers)

See: `~/Projects/cursor-revisit/troubleshooting/concepts/rhdp-zt-showroom-setup-init-lifecycle.md`
