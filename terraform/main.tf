provider "aws" {
  region = var.aws_region
}

# ------------------------------------------------------------------------------
# Networking Setup
# ------------------------------------------------------------------------------

resource "aws_vpc" "k8s_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "k8s-vpc"
  }
}

resource "aws_subnet" "k8s_public_subnet" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true

  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "k8s-public-subnet"
  }
}

resource "aws_internet_gateway" "k8s_igw" {
  vpc_id = aws_vpc.k8s_vpc.id

  tags = {
    Name = "k8s-igw"
  }
}

resource "aws_route_table" "k8s_route_table" {
  vpc_id = aws_vpc.k8s_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8s_igw.id
  }

  tags = {
    Name = "k8s-public-rt"
  }
}

resource "aws_route_table_association" "k8s_rt_assoc" {
  subnet_id      = aws_subnet.k8s_public_subnet.id
  route_table_id = aws_route_table.k8s_route_table.id
}

# ------------------------------------------------------------------------------
# Security Group
# ------------------------------------------------------------------------------

resource "aws_security_group" "k8s_sg" {
  name        = "k8s-cluster-sg"
  description = "Allow required ports for Kubernetes cluster"
  vpc_id      = aws_vpc.k8s_vpc.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes API Server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # etcd client API (Internal VPC access)
  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Kubelet API (Internal VPC access)
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # NodePort Services
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all intra-cluster communication (Required for CNI, Flannel/Calico to function properly)
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-sg"
  }
}

# ------------------------------------------------------------------------------
# EC2 Instances
# ------------------------------------------------------------------------------

resource "aws_instance" "master" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = aws_subnet.k8s_public_subnet.id

  vpc_security_group_ids = [aws_security_group.k8s_sg.id]

  root_block_device {
    volume_size           = 10
    volume_type           = "gp3"
    delete_on_termination = true
  }

  # Minimal cloud-init: only installs Python 3, which is required for Ansible to connect.
  # All K8s configuration is handled by the Ansible playbooks.
  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y python3
  EOF

  tags = {
    Name    = "k8s-master"
    Role    = "master"
    Project = "kubeadm"
  }
}

resource "aws_instance" "worker" {
  count         = 2
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = aws_subnet.k8s_public_subnet.id

  vpc_security_group_ids = [aws_security_group.k8s_sg.id]

  root_block_device {
    volume_size           = 10
    volume_type           = "gp3"
    delete_on_termination = true
  }

  # Minimal cloud-init: only installs Python 3, which is required for Ansible to connect.
  # All K8s configuration is handled by the Ansible playbooks.
  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y python3
  EOF

  tags = {
    Name    = "k8s-worker-${count.index + 1}"
    Role    = "worker"
    Project = "kubeadm"
  }
}
