
# Create VPC

resource "aws_vpc" "this" {
  cidr_block = "176.0.0.0/16"

  tags = {
    Name = var.vpc_name
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.vpc_name}_igw"
  }
}

resource "aws_subnet" "subnet_public" {
  vpc_id = aws_vpc.this.id
  cidr_block = "176.0.1.0/28"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public_subnet_${var.vpc_name}"
  }
}

resource "aws_subnet" "subnet_private" {
  vpc_id = aws_vpc.this.id
  cidr_block = "176.0.10.0/28"
  map_public_ip_on_launch = false

  tags = {
    Name = "Private_subnet_${var.vpc_name}"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.this.id

  route {
    gateway_id = aws_internet_gateway.igw.id
    cidr_block = "0.0.0.0/0"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id = aws_subnet.subnet_public.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "ssh_sg" {
  
  vpc_id = aws_vpc.this.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 50000
    to_port = 50000
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress  {

    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Pem Key to connect instance
resource "tls_private_key" "rsa_key" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "aws_key_pair" "iac_key" {
  key_name = var.key_name
  public_key = tls_private_key.rsa_key.public_key_openssh
}

resource "local_file" "local_iac_key" {
  content = tls_private_key.rsa_key.private_key_pem
  filename = "${path.cwd}/${var.key_name}.pem"
}

data "aws_ami" "ubuntu" {
    most_recent = true

    owners = ["099720109477"]

    filter {
      name = "name"
      values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
}

resource "aws_instance" "iac_instance" {
  ami = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name = var.key_name

  vpc_security_group_ids = [aws_security_group.ssh_sg.id]
  subnet_id = aws_subnet.subnet_public.id

  associate_public_ip_address = true

  tags = {
    Name = var.vpc_name
  }
  # user_data = file("${path.module}/scripts/docker_installation_on_ubuntu_22_04.sh")

  # Running multiple scripts using template file
  user_data = templatefile("${path.module}/userdata.tpl", {
  script1 = file("${path.module}/scripts/docker_installation_on_ubuntu_22_04.sh")
  script2 = file("${path.module}/scripts/deploy_jenkins.sh")
})
}