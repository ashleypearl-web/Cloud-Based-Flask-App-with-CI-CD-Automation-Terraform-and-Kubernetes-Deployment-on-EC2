output "kops_cluster_name" {
  description = "The name of the Kubernetes cluster created by Kops"
  value       = "kubeashley.ashley.solutions"
}

output "kops_state_store_bucket" {
  description = "The S3 bucket used for Kops state storage"
  value       = aws_s3_bucket.k8s_state_store.bucket
}

output "control_plane_instance_type" {
  description = "The EC2 instance type for the control plane nodes"
  value       = "t3.medium"
}

output "node_instance_type" {
  description = "The EC2 instance type for the worker nodes"
  value       = "t3.small"
}

output "node_count" {
  description = "The number of worker nodes in the cluster"
  value       = 2
}

output "security_group_id" {
  description = "The ID of the security group associated with the Kubernetes instances"
  value       = aws_security_group.k8s_sg.id
}

output "kops_key_pair_name" {
  description = "The name of the AWS key pair used to access the instances"
  value       = aws_key_pair.kube-keypair.key_name
}

output "kops_cluster_state" {
  description = "The state store bucket for Kops"
  value       = "s3://ashlkopss-state-store-bucket"
}
