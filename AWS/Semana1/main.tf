######
# VPC
######
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "vpc-${local.environment}"
  }
}

# Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${local.environment}"
  }
}

#Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = "us-east-1b"
  cidr_block        = "10.0.2.0/24"

  tags = {
    Name = "private-subnet-${local.environment}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "vpc-${local.environment}-Internet-Gateway"
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "igw-route-table"
  }
}

resource "aws_route_table_association" "route_table_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.route_table.id
}

#####################
# App Security Group
#####################
resource "aws_security_group" "app_sg" {
  name        = "app-sg-${local.environment}"
  description = "Web application security group"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "app-sg-${local.environment}"
  }
}

resource "aws_security_group_rule" "app_sgr_internet_app" {
  description       = "Security group to expose the application to the internet"
  type              = "ingress"
  from_port         = 8000
  to_port           = 8000
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app_sg.id
}

resource "aws_security_group_rule" "app_sgr_admin_app" {
  description       = "Security group to connect to the ec2 instance"
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app_sg.id
}

resource "aws_security_group_rule" "app_sgr_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app_sg.id
}

###########
# Key Pair
###########
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "ec2_instance_key_pair" {
  key_name   = "ec2_instance_key_pair"
  public_key = tls_private_key.rsa.public_key_openssh
}
resource "local_file" "ec2_instance_key_pair" {
  filename        = "ec2_instance_key_pair.pem"
  content         = tls_private_key.rsa.private_key_pem
  file_permission = "0400"
}

##########################
# Database Security Group
##########################
resource "aws_security_group" "db_sg" {
  name        = "db-sg-${local.environment}"
  description = "Database security group"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "db-sg-${local.environment}"
  }
}

resource "aws_security_group_rule" "db_sgr_ec2_pg" {
  description       = "Security group to connect to the database"
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = [aws_subnet.public_subnet.cidr_block]
  security_group_id = aws_security_group.db_sg.id
}

resource "aws_security_group_rule" "db_sgr_ec2_ssh" {
  description       = "Security group to connect to the ec2 instance"
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [aws_subnet.public_subnet.cidr_block]
  security_group_id = aws_security_group.db_sg.id
}

resource "aws_security_group_rule" "db_sgr_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.db_sg.id
}

#######################
# Database EC2 Instance
#######################
resource "aws_instance" "database_instance" {
  availability_zone = aws_subnet.private_subnet.availability_zone
  ami               = "ami-007855ac798b5175e"
  instance_type     = "t2.micro"
  key_name          = aws_key_pair.ec2_instance_key_pair.key_name
  subnet_id         = aws_subnet.private_subnet.id
  user_data         = filebase64("db-server.sh")
  security_groups   = [aws_security_group.db_sg.id]

  root_block_device {
    volume_size = 60
    volume_type = "gp3"
  }

  tags = {
    Name = "db-ec2-instance-${local.environment}"
  }
}

#######################
# App EC2 Instance
#######################
resource "aws_instance" "app_instance" {
  availability_zone = aws_subnet.public_subnet.availability_zone
  ami               = "ami-007855ac798b5175e"
  instance_type     = "t2.micro"
  key_name          = aws_key_pair.ec2_instance_key_pair.key_name
  subnet_id         = aws_subnet.public_subnet.id
  user_data         = base64encode(templatefile("./web-server.sh", { private_ip = aws_instance.database_instance.private_ip }))
  security_groups   = [aws_security_group.app_sg.id]

  root_block_device {
    volume_size = 60
    volume_type = "gp3"
  }

  tags = {
    Name = "app-ec2-instance-${local.environment}"
  }
  depends_on = [aws_instance.database_instance]
}

output "key_copy" {
  value = "scp -i ${local_file.ec2_instance_key_pair.filename} ${local_file.ec2_instance_key_pair.filename} ubuntu@${aws_instance.app_instance.public_ip}:/home/ubuntu"
}

output "ssh_connect_app" {
  value = "ssh -i ${local_file.ec2_instance_key_pair.filename} ubuntu@${aws_instance.app_instance.public_ip}"
}

output "ssh_connect_db" {
  value = "ssh -i ${local_file.ec2_instance_key_pair.filename} ubuntu@${aws_instance.database_instance.private_ip}"
}