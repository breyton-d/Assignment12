terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ── Key pair (point this at your actual public key file) ──────────────────────
resource "aws_key_pair" "deployer" {
  key_name   = "finance-server-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCfQn/8LKnxYGwjme9s4ljbZGC0HXcwdHmkavAGpNkQtAFtzwl/XNCPTEoNCiWLTCE46rwKA2Gxb6WhrtEglKRt3wgjN8LhMST+eBRkE5K9NErKR/Y20QBolq6QX076sORxZFSyD7jj6VfG+V7ud10UnSC6n42FaxXJz0/Fju0bhRaDcpqj1Lekc3+2ToMKgkh3cbNHKJE0riJbP7ajSokkkY36SOh+TP5bzQADg95kcZZ8+Z2s4uu6APXPE974jfskbFFR7PChuMlQpIrULm8Ev70F2LQ2UfpvLkm7HJgdCxPxzT+4jHxdXijzHD6a9mXJaPkGYqqWumlQQgXDfplmBqeaR32f2Jp5xXTc+24rXwnuVmyuyhjNOhxEMLO3n2yxsQBJV5FXDnWn5+r0S4bJQGim/qxJSNm1kcT+OfHSiv/ESoqFCWU9RXT1lM3zkjdHGLbWcNyIl9+cn250uwHgTTQxPrf3/vnkn3bKMyXcecpKAL5f5RwBaU+FyjLLIRT2+poPXQtKBhysiUAZwK8Ll2JVhfH0J8qYAM8coJOIj+aFvqhFqE0xNMkQGdXI/0/wu6Afx2tU9BH33Kn60Y52FQoMNqVWnPo6/bPm13UpMRFIl9q1uQ0gAl3rHSMa8U42SuY1vYB6u9EbLlPTC+LQtBqfDy9bjCuEXt0Wf7m2iw== breyt@BreytGram"
}

# ── Security group: SSH only ──────────────────────────────────────────────────
resource "aws_security_group" "finance_sg" {
  name        = "finance-server-sg"
  description = "Allow SSH inbound"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict to your IP in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── EC2 instance (Ubuntu 22.04 LTS) ──────────────────────────────────────────
resource "aws_instance" "finance_server" {
  ami                    = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS us-east-1
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.finance_sg.id]

  tags = {
    Name = "finance-server"
  }
}

# ── 5 GB EBS volume (the extra disk for partitioning) ────────────────────────
resource "aws_ebs_volume" "finance_data" {
  availability_zone = aws_instance.finance_server.availability_zone
  size              = 5
  type              = "gp3"

  tags = {
    Name = "finance-data-disk"
  }
}

# ── Attach the volume to the instance as /dev/xvdf ───────────────────────────
resource "aws_volume_attachment" "finance_data_attach" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.finance_data.id
  instance_id = aws_instance.finance_server.id
}

# ── Outputs (feed these into your Ansible inventory) ─────────────────────────
output "instance_public_ip" {
  description = "Public IP of the finance server"
  value       = aws_instance.finance_server.public_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.finance_server.id
}
