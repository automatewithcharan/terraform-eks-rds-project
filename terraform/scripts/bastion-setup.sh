#!/bin/bash
set -ex
LOG_FILE="/var/log/terraform-bastion.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "===== Starting Bastion Setup ====="

# Update system
sudo yum update -y

# Install essential packages
sudo yum install -y unzip tar git jq nmap-ncat tree curl

echo "Removing old AWS CLI v1 if present..."
sudo rm -f /usr/bin/aws /usr/bin/aws_completer
sudo rm -rf /usr/local/aws-cli

echo "Installing AWS CLI v2..."
cd /tmp
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install --update

# Install kubectl
if ! command -v kubectl &>/dev/null; then
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/
sudo /usr/local/bin/kubectl version --client || true
fi

# Install helm
if ! command -v helm &>/dev/null; then
  echo "Installing Helm..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash || true
  export PATH=$PATH:/usr/local/bin
  which helm || echo "Helm binary not found yet, checking manually..."
  ls -l /usr/local/bin/helm || true
fi

# Install eksctl
if ! command -v eksctl &>/dev/null; then
  echo "Installing eksctl..."
  ARCH=amd64
  PLATFORM=$(uname -s)_$ARCH
  curl -sLO "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_${PLATFORM}.tar.gz"
  tar -xzf eksctl_${PLATFORM}.tar.gz -C /tmp && sudo mv /tmp/eksctl /usr/local/bin
fi

# Install Docker
if ! command -v docker &>/dev/null; then
  echo "Installing Docker..."
  sudo amazon-linux-extras install docker -y || sudo yum install -y docker
  sudo systemctl enable docker
  sudo systemctl start docker
  sudo usermod -aG docker ec2-user
fi

echo "===== Bastion setup completed successfully ====="
date | sudo tee /etc/bastion-setup-last-run.txt

echo "Installed tool versions:"
aws --version || true
sudo /usr/local/bin/kubectl version --client || true
helm version || true
eksctl version || true
docker --version || true

echo "✅ Setup complete. Log available at /var/log/terraform-bastion.log"

