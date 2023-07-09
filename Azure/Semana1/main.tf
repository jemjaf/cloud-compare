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
  default     = "1-55adc6cb-playground-sandbox"
}

variable "location" {
  description = "Location of the resource"
  type        = string
  default     = "southcentralus"
}

#Security Group
resource "azurerm_network_security_group" "securitygroup" {
  name                = "securitygroup"
  location            = var.location
  resource_group_name = var.resource-group-name

  security_rule {
    name                       = "RDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "3389"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}

# Create 2 vitual networks
# Virtual Network 1
resource "azurerm_virtual_network" "virtualnetwork-1" {
  name                = "virtualnetwork-1"
  location            = var.location
  resource_group_name = var.resource-group-name
  address_space       = ["172.16.0.0/16"]

  subnet {
    name           = "subnet1"
    address_prefix = "172.16.1.0/24"
    security_group = azurerm_network_security_group.securitygroup.id
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

resource "azurerm_network_interface" "network-interface" {
  name                = "network-interface"
  location            = var.location
  resource_group_name = var.resource-group-name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_virtual_network.virtualnetwork-1.subnet.*.id[0]
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "virtual-machine" {
  name                = "virtual-machine"
  resource_group_name = var.resource-group-name
  location            = var.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!"
  network_interface_ids = [
    azurerm_network_interface.network-interface.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  tags = {
    environment = "Production"
  }
}