
# Get VPC and Subnet details

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

# Key Pair

resource "tls_private_key" "key_rsa" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "aws_key_pair" "key" {
  key_name = "devops_key"
  public_key = tls_private_key.key_rsa.public_key_openssh
}

resource "local_file" "local_key" {
  content = tls_private_key.key_rsa.private_key_pem
  filename = "${path.cwd}/devops_key.pem"
}

# Configure Security Groups

resource "aws_security_group" "alb_sg" {
  name = "alb-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    protocol = "tcp"
    from_port = 80
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Configure Security group for EC2
resource "aws_security_group" "ec2_sg" {
  
  name = "ec2-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    protocol = "tcp"
    from_port = 22
    to_port = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "alb_to_ec2" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_sg.id
  security_group_id        = aws_security_group.ec2_sg.id
}


# Load Balancer
resource "aws_alb" "app_alb" {
  name = "app-alb"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb_sg.id]
  subnets = data.aws_subnets.default.ids

}

resource "aws_alb_target_group" "app_tg" {
  name = "app-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = data.aws_vpc.default.id

  health_check {
    path = "/"
    interval = 30
    timeout = 5
    healthy_threshold = 2
    unhealthy_threshold = 2
  }

}

resource "aws_lb_listener" "http" {
  load_balancer_arn =  aws_alb.app_alb.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_alb_target_group.app_tg.arn
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app_asg" {
  name = "app-asg"
  desired_capacity =  1
  max_size = 2
  min_size = 1
  vpc_zone_identifier = data.aws_subnets.default.ids

  launch_template {
    id = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_alb_target_group.app_tg.arn]
  tag {
    key = "name"
    value = "container-ec2"
    propagate_at_launch = true
  }
}

# Launch Template
resource "aws_launch_template" "app_lt" {
  
  name_prefix = "app-lt"
  image_id = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name = "devops_key"

  network_interfaces {
    security_groups = [aws_security_group.ec2_sg.id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -ex

    # Update system
    apt-get update -y
    apt-get upgrade -y

    # Install dependencies
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Add Docker’s official GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # Set up the repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    # Start Docker
    systemctl start docker
    systemctl enable docker

    # Add ubuntu user to docker group
    usermod -aG docker ubuntu

    # Run nginx container
    docker run -d --name web -p 80:80 nginx
    EOF
  )


}

# Outputs
output "alb_dns_name" {
  value = aws_alb.app_alb.dns_name
}