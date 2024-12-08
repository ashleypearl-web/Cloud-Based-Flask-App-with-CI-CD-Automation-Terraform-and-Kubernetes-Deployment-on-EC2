#!/bin/bash

# Check if the instance has internet connectivity
ping -c 4 google.com || { echo "No internet connection. Exiting..."; exit 1; }

# Update system and install dependencies
echo "Updating system and installing dependencies..."
sudo apt-get update -y
sudo apt-get install -y curl unzip python3-pip jq python3-venv

# Install AWS CLI using official AWS installer (v2)
echo "Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify AWS CLI installation
echo "Verifying AWS CLI installation..."
if ! aws --version; then
    echo "AWS CLI installation failed. Exiting..."
    exit 1
fi

# Install kubectl
echo "Installing kubectl..."
sudo snap install kubectl --classic

# Wait for kubectl installation to finish
echo "Waiting for kubectl to finish installing..."
if ! kubectl version --client; then
    echo "kubectl installation failed. Exiting..."
    exit 1
fi

# Install kops using curl (ensure connectivity)
echo "Installing kops..."
KOPS_VERSION=$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | jq -r .tag_name)
curl -Lo kops https://github.com/kubernetes/kops/releases/download/${KOPS_VERSION}/kops-linux-amd64 || { echo "Failed to download kops. Exiting..."; exit 1; }
chmod +x kops
sudo mv kops /usr/local/bin/kops

# Wait for kops installation to complete
echo "Waiting for kops installation..."
if ! kops version; then
    echo "kops installation failed. Exiting..."
    exit 1
fi

# Verify installations
echo "Verifying installations..."
kubectl version --client
kops version

# Use the SSH public key from the key pair created by Terraform
KOPS_SSH_PUBLIC_KEY="/tmp/kops_ssh_key.pub"

# Retry AWS CLI configuration (checking if the instance can assume the role)
echo "Configuring AWS CLI..."
retries=0
max_retries=10
while [ $retries -lt $max_retries ]; do
    if aws sts get-caller-identity; then
        echo "AWS CLI configuration successful."
        break
    else
        echo "Retrying AWS CLI configuration..."
        retries=$((retries+1))
        sleep 5
    fi
done

# If AWS CLI configuration still fails after retries, exit
if [ $retries -ge $max_retries ]; then
    echo "AWS CLI configuration failed after multiple attempts. Exiting..."
    exit 1
fi

# Create the Kops cluster
echo "Creating Kops cluster..."
kops create cluster \
  --name=kubeashley.ashley.solutions \
  --state=s3://ashlkopss-state-store-bucket \
  --zones=us-east-1a,us-east-1b \
  --node-count=2 \
  --node-size=t3.small \
  --control-plane-size=t3.medium \
  --dns-zone=kubeashley.ashley.solutions \
  --node-volume-size=12 \
  --control-plane-volume-size=12 \
  --ssh-public-key=${KOPS_SSH_PUBLIC_KEY}

# Apply the cluster
echo "Applying Kops cluster..."
kops update cluster --name=kubeashley.ashley.solutions --state=s3://ashlkopss-state-store-bucket --yes --admin

# Give some time for the cluster to apply
echo "Waiting for Kops to apply the cluster..."
sleep 30  # Wait for the cluster creation process to kick off

# Check the cluster status
echo "Validating Kops cluster..."
kops validate cluster --name=kubeashley.ashley.solutions --state=s3://ashlkopss-state-store-bucket --wait 10m

echo "Cluster validation complete!"
