# Step 1: Generate an RSA private key for SSH access
resource "tls_private_key" "kube_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Save the private key to a local file on your machine
resource "local_file" "kube_private_key" {
  content  = tls_private_key.kube_key.private_key_pem
  filename = "${path.module}/id_rsa"  # Save to a local file 'id_rsa'
}

# Use the data block to generate the corresponding public key
data "tls_public_key" "kube_key" {
  private_key_pem = tls_private_key.kube_key.private_key_pem
}

# Create an AWS key pair using the public key
resource "aws_key_pair" "kube-keypair" {
  key_name   = "kube-keypair"
  public_key = data.tls_public_key.kube_key.public_key_openssh
}

# Create a security group for Kubernetes instances
resource "aws_security_group" "k8s_sg" {
  name        = "k8s_security_group"
  description = "Allow inbound traffic for Kubernetes"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Replace with your IP address or range for SSH access
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # All traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# S3 bucket for Kops state store
resource "aws_s3_bucket" "k8s_state_store" {
  bucket = "ashlkopss-state-store-bucket"

  tags = {
    Name        = "kops-state-store"
    Environment = "dev"
  }
}

# IAM role for Kops
resource "aws_iam_role" "kops_role" {
  name               = "kops-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach a custom, limited policy to the Kops role
resource "aws_iam_role_policy" "kops_policy" {
  name   = "kops-policy"
  role   = aws_iam_role.kops_role.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = [
          "ec2:Describe*",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:DescribeInstances",
          "ec2:CreateSecurityGroup",
          "ec2:DescribeSecurityGroups"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = [
          "s3:CreateBucket",
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::ashlkopss-state-store-bucket/*"
      }
    ]
  })
}

# Attach AdministratorAccess policy for broader permissions
resource "aws_iam_role_policy_attachment" "kops_admin_policy" {
  role       = aws_iam_role.kops_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# IAM instance profile for the EC2 instance
resource "aws_iam_instance_profile" "kops_instance_profile" {
  name = "kops-instance-profile"
  role = aws_iam_role.kops_role.name
}

# EC2 instance for Kops
resource "aws_instance" "kops" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.kube-keypair.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.kops_instance_profile.name
  associate_public_ip_address = true

  tags = {
    Name = "kops"
  }

  provisioner "file" {
    source      = "kops.sh"           # Local path to kops.sh script
    destination = "/tmp/kops.sh"      # Remote destination for kops.sh script

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = local_file.kube_private_key.content  # Use the locally saved private key
      host        = self.public_ip
    }
  }

  provisioner "file" {
    content     = data.tls_public_key.kube_key.public_key_openssh  # Directly use the key content
    destination = "/tmp/kops_ssh_key.pub"  # Remote destination for the public key

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = local_file.kube_private_key.content  # Use the locally saved private key
      host        = self.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/kops.sh",  # Make the script executable
      "sudo /tmp/kops.sh"       # Run the script to install Kubernetes
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = local_file.kube_private_key.content  # Use the locally saved private key
      host        = self.public_ip
    }
  }
}
