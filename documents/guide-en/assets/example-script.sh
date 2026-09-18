#!/bin/bash
# Example: verify an ECS instance is reachable and running
# Usage: ./check-ecs.sh <EIP>

EIP="${1:?Usage: check-ecs.sh <EIP>}"

echo "Checking instance at $EIP ..."
ssh -i ~/.ssh/huawei_key.pem "ubuntu@$EIP" << 'EOF'
  uname -a
  df -h
  systemctl is-active nginx
EOF

echo "Done."
