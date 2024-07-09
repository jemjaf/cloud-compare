# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.51.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  skip_provider_registration = true
}

#Variables
variable "resource-group-name" {
  description = "Resource group name"
  type        = string
  default     = "1-d3b66f51-playground-sandbox"
}

variable "location" {
  description = "Location of the resource"
  type        = string
  default     = "southcentralus"
}

# Virtual Network 1
resource "azurerm_virtual_network" "virtualnetwork-1" {
  name                = "virtualnetwork-1"
  location            = var.location
  resource_group_name = var.resource-group-name
  address_space       = ["172.16.0.0/16"]

  subnet {
    name           = "subnet1"
    address_prefix = "172.16.1.0/24"
  }

  subnet {
    name           = "subnet2"
    address_prefix = "172.16.2.0/24"
  }

  tags = {
    environment = "Production"
  }
}

# Virtual Network 2
resource "azurerm_virtual_network" "virtualnetwork-2" {
  name                = "virtualnetwork-2"
  location            = var.location
  resource_group_name = var.resource-group-name
  address_space       = ["172.17.0.0/16"]

  subnet {
    name           = "subnet1"
    address_prefix = "172.17.1.0/24"
  }

  subnet {
    name           = "subnet2"
    address_prefix = "172.17.2.0/24"
  }

  tags = {
    environment = "Development"
  }
}

resource "azurerm_public_ip" "public_ip1" {
  name                = "public_ip_web"
  resource_group_name = var.resource-group-name
  location            = var.location
  allocation_method   = "Dynamic"
}

resource "azurerm_public_ip" "public_ip2" {
  name                = "public_ip_db"
  resource_group_name = var.resource-group-name
  location            = var.location
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "network-interface-main1" {
  name                = "network-interface-main1"
  location            = var.location
  resource_group_name = var.resource-group-name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_virtual_network.virtualnetwork-1.subnet.*.id[0]
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip1.id
  }
}

resource "azurerm_network_interface" "network-interface-main2" {
  name                = "network-interface-main2"
  location            = var.location
  resource_group_name = var.resource-group-name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_virtual_network.virtualnetwork-2.subnet.*.id[0]
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip2.id
  }
}

resource "azurerm_network_interface" "network-interface-internal1" {
  name                = "network-interface-internal1"
  location            = var.location
  resource_group_name = var.resource-group-name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_virtual_network.virtualnetwork-1.subnet.*.id[0]
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "network-interface-internal2" {
  name                = "network-interface-internal2"
  location            = var.location
  resource_group_name = var.resource-group-name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_virtual_network.virtualnetwork-2.subnet.*.id[0]
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_security_group" "sg-webserver" {
  name                = "sg-webserver"
  location            = var.location
  resource_group_name = var.resource-group-name
  security_rule {
    access                     = "Allow"
    direction                  = "Inbound"
    name                       = "tls"
    priority                   = 100
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "443"
    destination_address_prefix = azurerm_network_interface.network-interface-main1.private_ip_address
  }
}

resource "azurerm_network_security_group" "sg-database" {
  name                = "sg-database"
  location            = var.location
  resource_group_name = var.resource-group-name
  security_rule {
    access                     = "Allow"
    direction                  = "Inbound"
    name                       = "tls"
    priority                   = 100
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "443"
    destination_address_prefix = azurerm_network_interface.network-interface-main2.private_ip_address
  }
}

resource "azurerm_network_interface_security_group_association" "main1" {
  network_interface_id      = azurerm_network_interface.network-interface-internal1.id
  network_security_group_id = azurerm_network_security_group.sg-webserver.id
}

resource "azurerm_network_interface_security_group_association" "main2" {
  network_interface_id      = azurerm_network_interface.network-interface-internal2.id
  network_security_group_id = azurerm_network_security_group.sg-database.id
}

resource "azurerm_linux_virtual_machine" "virtual-machine-web" {
  name                            = "virtual-machine-web"
  resource_group_name             = var.resource-group-name
  location                        = var.location
  size                            = "Standard_F2"
  admin_username                  = "adminuser"
  admin_password                  = "P@ssw0rd1234!"
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.network-interface-main1.id,
    azurerm_network_interface.network-interface-internal1.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  tags = {
    environment = "Production"
    service     = "Web Server"
  }
}

resource "azurerm_linux_virtual_machine" "virtual-machine-db" {
  name                            = "virtual-machine-db"
  resource_group_name             = var.resource-group-name
  location                        = var.location
  size                            = "Standard_F2"
  admin_username                  = "adminuser"
  admin_password                  = "P@ssw0rd1234!"
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.network-interface-main2.id,
    azurerm_network_interface.network-interface-internal2.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  tags = {
    environment = "Production"
    service     = "Database"
  }
}

output "web_public_ip_address" {
  value = azurerm_linux_virtual_machine.virtual-machine-web.public_ip_address
}

output "web_public_ip_addresses" {
  value = azurerm_linux_virtual_machine.virtual-machine-web.public_ip_addresses
}

output "db_public_ip_address" {
  value = azurerm_linux_virtual_machine.virtual-machine-db.public_ip_address
}

output "db_public_ip_addresses" {
  value = azurerm_linux_virtual_machine.virtual-machine-db.public_ip_addresses
}