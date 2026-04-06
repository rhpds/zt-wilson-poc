#!/bin/sh
echo "Starting module called module-01" >> /tmp/progress.log

cat > /home/rhel/runtime-env-check.txt << EOF
GUID=${GUID}
DOMAIN=${DOMAIN}
LITELLM_API_URL=${LITELLM_API_URL}
LITELLM_API_KEY=${LITELLM_API_KEY}
EOF
chown rhel:rhel /home/rhel/runtime-env-check.txt
