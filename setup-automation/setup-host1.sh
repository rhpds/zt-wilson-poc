#!/bin/bash
USER=rhel

echo "Adding wheel" > /root/post-run.log
usermod -aG wheel rhel

echo "Setup vm host1" > /tmp/progress.log
chmod 666 /tmp/progress.log

cat > /home/rhel/setup-env-check.txt << EOF
GUID=${GUID}
DOMAIN=${DOMAIN}
LITELLM_API_URL=${LITELLM_API_URL}
LITELLM_API_KEY=${LITELLM_API_KEY}
EOF
chown rhel:rhel /home/rhel/setup-env-check.txt

