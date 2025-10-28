#!/usr/bin/env bash
# deploy_microk8s.sh
# Remote MicroK8s installation and configuration on a managed workstation.
# Run from the managing workstation as:
#   ./deploy_microk8s.sh <managed_host_ip>

set -euo pipefail

REMOTE_HOST="${1:-}"
REMOTE_USER="infra_si"
REMOTE_SCRIPT="/tmp/setup_microk8s_remote.sh"

if [[ -z "$REMOTE_HOST" ]]; then
  echo "Usage: $0 <managed_host_ip>"
  exit 1
fi

echo "➡️  Starting remote MicroK8s setup on $REMOTE_HOST as $REMOTE_USER..."

# --- Inner remote script to run on the managed workstation ---
REMOTE_CONTENT='#!/usr/bin/env bash
set -euo pipefail

echo "🏗️  Installing MicroK8s..."
sudo snap install microk8s --classic --channel=1.30/stable

echo "👥  Adding infra_si to microk8s and docker groups..."
sudo usermod -aG microk8s infra_si
sudo usermod -aG docker infra_si
sudo chown -f -R infra_si ~/.kube || true

echo "⏳ Waiting for MicroK8s to be ready..."
sudo microk8s status --wait-ready

echo "🔧 Enabling core add-ons..."
sudo microk8s enable dns storage ingress registry

echo "🔍 Detecting host IP..."
HOST_IP=$(ip route get 8.8.8.8 | awk "/src/ {print \$7; exit}")
if [[ -z "$HOST_IP" ]]; then
  echo "ERROR: could not detect host IP." >&2
  exit 1
fi
echo "Detected host IP: $HOST_IP"

IFS="." read -r O1 O2 O3 O4 <<< "$HOST_IP"
BLOCK_INDEX=$(( O4 / 10 + 1 ))
START=$(( BLOCK_INDEX * 10 ))
[[ $START -gt 245 ]] && START=$(( (O4 / 10) * 10 ))
[[ $START -lt 2 ]] && START=2
END=$(( START + 9 ))
POOL_RANGE="${O1}.${O2}.${O3}.${START}-${O1}.${O2}.${O3}.${END}"

echo "🌐 Configuring MetalLB with range $POOL_RANGE ..."
sudo microk8s enable metallb:"$POOL_RANGE"

echo "✅ MetalLB configured successfully."

echo "Linking kubectl to microk8s.kubectl..."
snap alias microk8s.kubectl kubectl || true


echo "Configure permissions..."
microk8s config > "/home/${REMOTE_USER}/.kube/config"
chown -R "${REMOTE_USER}:${REMOTE_USER}" "/home/${REMOTE_USER}/.kube"

echo "📦 Verifying pods..."
sudo kubectl get pods -A


echo "🎉 MicroK8s setup complete on $(hostname)"
echo "   Host IP: $HOST_IP"
echo "   MetalLB range: $POOL_RANGE"
'

# --- Copy and execute remote script ---
ssh ${REMOTE_USER}@${REMOTE_HOST} "echo \"$REMOTE_CONTENT\" | sudo tee $REMOTE_SCRIPT >/dev/null"
ssh ${REMOTE_USER}@${REMOTE_HOST} "sudo bash $REMOTE_SCRIPT && sudo rm -f $REMOTE_SCRIPT"

echo "✅ MicroK8s deployment completed on $REMOTE_HOST"
