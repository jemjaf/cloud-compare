###########
# VPC
###########
resource "alicloud_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  vpc_name   = "vpc-${local.environment}"
}

###########
# Subnets
###########
resource "alicloud_vswitch" "subnet" {
  vswitch_name = "subnet-${local.environment}"
  cidr_block   = "10.0.0.0/24"
  vpc_id       = alicloud_vpc.vpc.id
  zone_id      = local.zone
}

#####################
# App Security Group
#####################
resource "alicloud_security_group" "app_sg" {
  name        = "app-sg-${local.environment}"
  description = "Web application security group"
  vpc_id      = alicloud_vpc.vpc.id
}

resource "alicloud_security_group_rule" "app_sgr_internet_app" {
  description       = "Security group to expose the application to the internet"
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "8000/8000"
  security_group_id = alicloud_security_group.app_sg.id
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_security_group_rule" "app_sgr_admin_app" {
  description       = "Security group to connect to the ec2 instance"
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "22/22"
  security_group_id = alicloud_security_group.app_sg.id
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_security_group_rule" "app_sgr_users_app" {
  description       = "Security group to expose the application to the internet for HTTPS"
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "443/443"
  security_group_id = alicloud_security_group.app_sg.id
  cidr_ip           = "0.0.0.0/0"
}

#########################
# Database Security Group
#########################
resource "alicloud_security_group" "db_sg" {
  name        = "db-sg-${local.environment}"
  description = "Database security group"
  vpc_id      = alicloud_vpc.vpc.id
}

resource "alicloud_security_group_rule" "db_sgr_ec2_pg" {
  description       = "Security group to connect to the database"
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "5432/5432"
  security_group_id = alicloud_security_group.db_sg.id
  cidr_ip           = alicloud_vswitch.subnet.cidr_block
}

resource "alicloud_security_group_rule" "db_sgr_ec2_ssh" {
  description       = "Security group to connect to the ec2 instance"
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "22/22"
  security_group_id = alicloud_security_group.db_sg.id
  cidr_ip           = alicloud_vswitch.subnet.cidr_block
}

##########
# SSH Key
##########
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "alicloud_key_pair" "ecs_instance_key_pair" {
  key_pair_name = "ecs_instance_key_pair"
  public_key    = tls_private_key.rsa.public_key_openssh
}

resource "local_file" "ecs_instance_key_pair" {
  filename        = "ecs_instance_key_pair.pem"
  content         = tls_private_key.rsa.private_key_pem
  file_permission = "0400"
}

######################
# Instance Type
######################
data "alicloud_instance_types" "types_ds" {
  cpu_core_count    = 1
  memory_size       = 1
  availability_zone = local.zone
}

#######################
# Database EC2 Instance
#######################
resource "alicloud_instance" "database_instance" {
  availability_zone = local.zone
  image_id          = "ubuntu_22_04_uefi_x64_20G_alibase_20230515.vhd"
  instance_type     = data.alicloud_instance_types.types_ds.instance_types.0.id
  key_name          = alicloud_key_pair.ecs_instance_key_pair.key_name
  vswitch_id        = alicloud_vswitch.subnet.id
  security_groups   = [alicloud_security_group.db_sg.id]
  user_data         = filebase64("db-server.sh")

  data_disks {
    name        = "app-disk2-${local.environment}"
    size        = 20
    category    = "cloud_efficiency"
    description = "app-disk2-${local.environment}"
  }

  instance_name              = "db-ec2-instance-${local.environment}"
  instance_charge_type       = "PostPaid"
  internet_max_bandwidth_out = 100
  internet_charge_type       = "PayByTraffic"
}

#######################
# App EC2 Instance
#######################
resource "alicloud_instance" "app_instance" {
  availability_zone = local.zone
  image_id          = "ubuntu_22_04_uefi_x64_20G_alibase_20230515.vhd"
  instance_type     = data.alicloud_instance_types.types_ds.instance_types.0.id
  key_name          = alicloud_key_pair.ecs_instance_key_pair.key_name
  vswitch_id        = alicloud_vswitch.subnet.id
  security_groups   = [alicloud_security_group.app_sg.id]
  user_data         = base64encode(templatefile("./web-server.sh", { private_ip = alicloud_instance.database_instance.private_ip }))

  instance_name              = "app-ec2-instance-${local.environment}"
  instance_charge_type       = "PostPaid"
  internet_max_bandwidth_out = 100
  internet_charge_type       = "PayByTraffic"

  depends_on = [alicloud_instance.database_instance]
}

#######################
# Outputs
#######################
output "instance_type" {
  value = data.alicloud_instance_types.types_ds.instance_types.0.id
}

output "key_copy" {
  value = "scp -i ${local_file.ecs_instance_key_pair.filename} ${local_file.ecs_instance_key_pair.filename} root@${alicloud_instance.app_instance.public_ip}:/root"
}

output "ssh_connect_app" {
  value = "ssh -i ${local_file.ecs_instance_key_pair.filename} root@${alicloud_instance.app_instance.public_ip}"
}

output "ssh_connect_db" {
  value = "ssh -i ${local_file.ecs_instance_key_pair.filename} root@${alicloud_instance.database_instance.private_ip}"
}