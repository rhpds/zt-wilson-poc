# runtime-automation/

This directory is **required** by the showroom deployer's `runner` container even when empty.

## Why This Exists

The `runner` container (zerotouch-automation) mounts `/app/runtime-automation` from the cloned content repo and loads module configuration from this path during startup:

```
INFO:     Ansible Runner directory: /app/runtime-automation
INFO:     Module config loaded from: /app/runtime-automation
```

## For This Deployment

This Foreman deployment:
- Has no VMs (Helm-only)
- Uses `solveButton: false` (no solve/validation scripts)
- Does not require runtime automation

**However**, the directory must exist in the repo or the runner container will fail to start.

## What Would Go Here

In labs with VMs and progression controls:
```
runtime-automation/
├── ansible.cfg
├── inventory
├── main.yml
└── <module-name>/
    ├── setup-<vmname>.sh
    ├── solve-<vmname>.sh
    └── validation-<vmname>.sh
```

See: `~/Projects/cursor-revisit/platform/showroom-lab-authoring-reference.md` §runtime-automation
