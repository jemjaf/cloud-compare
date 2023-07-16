#Virtual Network 1
resource "azurerm_virtual_network" "virtualnetwork-1" {
  name                = "virtualnetwork-1-${local.environment}"
  location            = var.location
  resource_group_name = var.resource-group-name
  address_space       = ["10.0.0.0/16"]
  tags = {
    environment = local.environment
  }
}

resource "azurerm_subnet" "vn1_subnet1" {
  name                 = "vn1_subnet1-${local.environment}"
  resource_group_name  = var.resource-group-name
  virtual_network_name = azurerm_virtual_network.virtualnetwork-1.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_public_ip" "public_ip_web" {
  name                = "public_ip_web-${local.environment}"
  resource_group_name = var.resource-group-name
  location            = var.location
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "network-interface-web" {
  name                = "network-interface-web-${local.environment}"
  location            = var.location
  resource_group_name = var.resource-group-name

  ip_configuration {
    name                          = "web-internal-${local.environment}"
    subnet_id                     = azurerm_subnet.vn1_subnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip_web.id
  }
}

resource "azurerm_network_interface" "network-interface-db" {
  name                = "network-interface-db-${local.environment}"
  location            = var.location
  resource_group_name = var.resource-group-name

  ip_configuration {
    name                          = "db-internal-${local.environment}"
    subnet_id                     = azurerm_subnet.vn1_subnet1.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_security_group" "sg-webserver" {
  name                = "sg-webserver-${local.environment}"
  location            = var.location
  resource_group_name = var.resource-group-name

  security_rule {
    access                     = "Allow"
    direction                  = "Inbound"
    name                       = "SSH"
    priority                   = 120
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "22"
    destination_address_prefix = "*"
  }

  security_rule {
    access                     = "Allow"
    direction                  = "Inbound"
    name                       = "HTTP"
    priority                   = 100
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "8000"
    destination_address_prefix = "*"
  }

  security_rule {
    access                     = "Allow"
    direction                  = "Outbound"
    name                       = "AnyOutboundWeb"
    priority                   = 100
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "sg-database" {
  name                = "sg-database-${local.environment}"
  location            = var.location
  resource_group_name = var.resource-group-name

  security_rule {
    access                     = "Allow"
    direction                  = "Inbound"
    name                       = "SSHDatabase"
    priority                   = 120
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "22"
    destination_address_prefix = "*"
  }

  security_rule {
    access                     = "Allow"
    direction                  = "Inbound"
    name                       = "AllowPostgres"
    priority                   = 100
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "5432"
    destination_address_prefix = "*"
  }

  security_rule {
    access                     = "Allow"
    direction                  = "Outbound"
    name                       = "AnyOutboundDatabase"
    priority                   = 100
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "web_network_interface_security_group" {
  network_interface_id      = azurerm_network_interface.network-interface-web.id
  network_security_group_id = azurerm_network_security_group.sg-webserver.id
}

resource "azurerm_network_interface_security_group_association" "database_network_interface_security_group" {
  network_interface_id      = azurerm_network_interface.network-interface-db.id
  network_security_group_id = azurerm_network_security_group.sg-database.id
}

resource "azurerm_linux_virtual_machine" "virtual-machine-web" {
  name                            = "virtual-machine-web-${local.environment}"
  resource_group_name             = var.resource-group-name
  location                        = var.location
  size                            = "Standard_B1s"
  admin_username                  = "adminuser"
  admin_password                  = "aB1234"
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.network-interface-web.id
  ]

  user_data = base64encode(templatefile("./web-server.sh", { private_ip = azurerm_linux_virtual_machine.virtual-machine-db.private_ip_address }))

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    environment = "Web-Server"
  }

  depends_on = [azurerm_linux_virtual_machine.virtual-machine-db]
}

resource "azurerm_linux_virtual_machine" "virtual-machine-db" {
  name                            = "virtual-machine-db-${local.environment}"
  resource_group_name             = var.resource-group-name
  location                        = var.location
  size                            = "Standard_B1s"
  admin_username                  = "adminuser"
  admin_password                  = "aB1234"
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.network-interface-db.id,
  ]
  user_data = base64encode(file("./db-server.sh"))
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    environment = "DB-Server"
  }
}

output "web_public_ip_address" {
  value = azurerm_linux_virtual_machine.virtual-machine-web.public_ip_address
}

output "ssh_connect_app" {
  value = "ssh adminuser@${azurerm_linux_virtual_machine.virtual-machine-web.public_ip_address}"
}

output "ssh_connect_db" {
  value = "ssh adminuser@${azurerm_linux_virtual_machine.virtual-machine-db.private_ip_address}"
}