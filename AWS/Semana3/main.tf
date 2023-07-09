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

resource "aws_db_subnet_group" "subnet_group" {
  name       = "subnet_group"
  subnet_ids = [aws_subnet.public_subnet.id, aws_subnet.private_subnet.id]

  tags = {
    Name = "DB subnet group"
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

resource "aws_route_table_association" "route_table_association_public" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_route_table_association" "route_table_association_private" {
  subnet_id      = aws_subnet.private_subnet.id
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
# RDS Postges SQL
#######################
resource "aws_db_instance" "rds_rafita" {
  availability_zone      = aws_subnet.private_subnet.availability_zone
  db_subnet_group_name   = aws_db_subnet_group.subnet_group.name
  engine                 = "postgres"
  engine_version         = "15.3"
  identifier             = "rds-rafita"
  username               = "postgres"
  password               = "m4st3rP4sw0rd"
  instance_class         = "db.t3.micro"
  publicly_accessible    = true
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  port                   = 5432
  db_name                = "rafita"
  allocated_storage      = 20
  skip_final_snapshot    = true
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
  user_data = base64encode(templatefile("./web-server.sh", {
    db_host = aws_db_instance.rds_rafita.address
  }))
  security_groups = [aws_security_group.app_sg.id]

  root_block_device {
    volume_size = 60
    volume_type = "gp3"
  }

  tags = {
    Name = "app-ec2-instance-${local.environment}"
  }
  depends_on = [aws_db_instance.rds_rafita]
}

resource "aws_dynamodb_table" "user_table" {
  name           = "Usuario"
  hash_key       = "id_usuario"
  range_key      = "nombre"
  billing_mode   = "PROVISIONED"
  read_capacity  = 10
  write_capacity = 10

  attribute {
    name = "id_usuario"
    type = "S"
  }

  attribute {
    name = "nombre"
    type = "S"
  }

}

resource "aws_dynamodb_table_item" "user_table_item_1" {
  table_name = aws_dynamodb_table.user_table.name
  hash_key   = aws_dynamodb_table.user_table.hash_key
  range_key  = aws_dynamodb_table.user_table.range_key

  item = <<ITEM
  {
    "id_usuario": {"S": "1"},
    "nombre": {"S": "Jean Reyes"}
  }
  ITEM
}

resource "aws_dynamodb_table_item" "user_table_item_2" {
  table_name = aws_dynamodb_table.user_table.name
  hash_key   = aws_dynamodb_table.user_table.hash_key
  range_key  = aws_dynamodb_table.user_table.range_key

  item = <<ITEM
  {
    "id_usuario": {"S": "2"},
    "nombre": {"S": "Carlo Razzeto"}
  }
  ITEM
}

resource "aws_dynamodb_table_item" "user_table_item_3" {
  table_name = aws_dynamodb_table.user_table.name
  hash_key   = aws_dynamodb_table.user_table.hash_key
  range_key  = aws_dynamodb_table.user_table.range_key

  item = <<ITEM
  {
    "id_usuario": {"S": "3"},
    "nombre": {"S": "Gerardo Avalos"}
  }
  ITEM
}

resource "aws_dynamodb_table_item" "user_table_item_4" {
  table_name = aws_dynamodb_table.user_table.name
  hash_key   = aws_dynamodb_table.user_table.hash_key
  range_key  = aws_dynamodb_table.user_table.range_key

  item = <<ITEM
  {
    "id_usuario": {"S": "4"},
    "nombre": {"S": "Alejandro Espinoza"}
  }
  ITEM
}

resource "aws_dynamodb_table_item" "user_table_item_5" {
  table_name = aws_dynamodb_table.user_table.name
  hash_key   = aws_dynamodb_table.user_table.hash_key
  range_key  = aws_dynamodb_table.user_table.range_key

  item = <<ITEM
  {
    "id_usuario": {"S": "5"},
    "nombre": {"S": "Gerald Ayala"}
  }
  ITEM
}


resource "aws_dynamodb_table" "pedido_table" {
  name           = "Pedido"
  hash_key       = "id_pedido"
  billing_mode   = "PROVISIONED"
  read_capacity  = 10
  write_capacity = 10

  attribute {
    name = "id_pedido"
    type = "S"
  }

  attribute {
    name = "cantidad"
    type = "N"
  }

  attribute {
    name = "libro"
    type = "S"
  }

  attribute {
    name = "nombre"
    type = "S"
  }

  global_secondary_index {
    name            = "GSICantidad"
    hash_key        = "cantidad"
    projection_type = "ALL"
    read_capacity   = 10
    write_capacity  = 10
  }

  global_secondary_index {
    name            = "GSINombre"
    hash_key        = "nombre"
    projection_type = "ALL"
    read_capacity   = 10
    write_capacity  = 10
  }

  global_secondary_index {
    name            = "GSILibro"
    hash_key        = "libro"
    projection_type = "ALL"
    read_capacity   = 10
    write_capacity  = 10
  }
}

resource "aws_dynamodb_table_item" "pedido_table_item_1" {
  table_name = aws_dynamodb_table.pedido_table.name
  hash_key   = aws_dynamodb_table.pedido_table.hash_key

  item = <<ITEM
  {
    "id_pedido": {"S": "1"},
    "cantidad": {"N": "5"},
    "libro": {"S": "Libro 1"},
    "nombre": {"S": "Nombre 1"}
  }
  ITEM
}

resource "aws_dynamodb_table_item" "pedido_table_item_2" {
  table_name = aws_dynamodb_table.pedido_table.name
  hash_key   = aws_dynamodb_table.pedido_table.hash_key

  item = <<ITEM
  {
    "id_pedido": {"S": "2"},
    "cantidad": {"N": "3"},
    "libro": {"S": "Libro 2"},
    "nombre": {"S": "Nombre 2"}
  }
  ITEM
}

resource "aws_dynamodb_table_item" "pedido_table_item_3" {
  table_name = aws_dynamodb_table.pedido_table.name
  hash_key   = aws_dynamodb_table.pedido_table.hash_key

  item = <<ITEM
  {
    "id_pedido": {"S": "3"},
    "cantidad": {"N": "2"},
    "libro": {"S": "Libro 3"},
    "nombre": {"S": "Nombre 3"}
  }
  ITEM
}

resource "aws_dynamodb_table_item" "pedido_table_item_4" {
  table_name = aws_dynamodb_table.pedido_table.name
  hash_key   = aws_dynamodb_table.pedido_table.hash_key

  item = <<ITEM
  {
    "id_pedido": {"S": "4"},
    "cantidad": {"N": "1"},
    "libro": {"S": "Libro 4"},
    "nombre": {"S": "Nombre 4"}
  }
  ITEM
}

data "aws_route53_zone" "hosted_zone" {
  name         = "cmcloudlab456.info"
  private_zone = false
}

resource "aws_route53_record" "dns_app" {
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = "${local.project_name}.${data.aws_route53_zone.hosted_zone.name}"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.app_instance.public_ip]
}

output "ssh_connect_app" {
  value = "ssh -i ec2_instance_key_pair.pem ubuntu@${aws_instance.app_instance.public_ip}"
}