#We strongly recommend using the required_providers block to set the
#Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.51.0"
    }
  }
}

#Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  skip_provider_registration = true
}

#Variables
variable "resource-group-name" {
  description = "Resource group name"
  type        = string
  default     = "1-6d6b5be0-playground-sandbox"
}

variable "location" {
  description = "Location of the resource"
  type        = string
  default     = "southcentralus"
}

#Virtual Network 1
resource "azurerm_virtual_network" "virtualnetwork-1" {
  name                = "virtualnetwork-1"
  location            = var.location
  resource_group_name = var.resource-group-name
  address_space       = ["172.16.0.0/16"]
  tags = {
    environment = "Production"
  }
}

resource "azurerm_subnet" "vn1_subnet1" {
  name                 = "vn1_subnet1"
  resource_group_name  = var.resource-group-name
  virtual_network_name = azurerm_virtual_network.virtualnetwork-1.name
  address_prefixes     = ["172.16.1.0/24"]
}

resource "azurerm_subnet" "GatewaySubnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = var.resource-group-name
  virtual_network_name = azurerm_virtual_network.virtualnetwork-1.name
  address_prefixes     = ["172.16.2.0/24"]
}

#Virtual Network 2
resource "azurerm_virtual_network" "virtualnetwork-2" {
  name                = "virtualnetwork-2"
  location            = var.location
  resource_group_name = var.resource-group-name
  address_space       = ["172.17.0.0/16"]

  tags = {
    environment = "Development"
  }
}

resource "azurerm_subnet" "vn2_subnet1" {
  name                 = "vn2_subnet1"
  resource_group_name  = var.resource-group-name
  virtual_network_name = azurerm_virtual_network.virtualnetwork-2.name
  address_prefixes     = ["172.17.1.0/24"]
}

resource "azurerm_subnet" "vn2_subnet2" {
  name                 = "vn2_subnet2"
  resource_group_name  = var.resource-group-name
  virtual_network_name = azurerm_virtual_network.virtualnetwork-2.name
  address_prefixes     = ["172.17.2.0/24"]
}

resource "azurerm_virtual_network_peering" "vn-peering1to2" {
  name                         = "vn-peering1to2"
  resource_group_name          = var.resource-group-name
  virtual_network_name         = azurerm_virtual_network.virtualnetwork-1.name
  remote_virtual_network_id    = azurerm_virtual_network.virtualnetwork-2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "vn-peering2to1" {
  name                         = "vn-peering2to1"
  resource_group_name          = var.resource-group-name
  virtual_network_name         = azurerm_virtual_network.virtualnetwork-2.name
  remote_virtual_network_id    = azurerm_virtual_network.virtualnetwork-1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_network_interface" "network-interface-web" {
  name                = "network-interface-web"
  location            = var.location
  resource_group_name = var.resource-group-name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vn1_subnet1.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "network-interface-db" {
  name                = "network-interface-db"
  location            = var.location
  resource_group_name = var.resource-group-name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vn2_subnet1.id
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
    destination_address_prefix = azurerm_network_interface.network-interface-web.private_ip_address
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
    destination_address_prefix = azurerm_network_interface.network-interface-db.private_ip_address
  }
}

resource "azurerm_network_interface_security_group_association" "web" {
  network_interface_id      = azurerm_network_interface.network-interface-web.id
  network_security_group_id = azurerm_network_security_group.sg-webserver.id
}

resource "azurerm_network_interface_security_group_association" "db" {
  network_interface_id      = azurerm_network_interface.network-interface-db.id
  network_security_group_id = azurerm_network_security_group.sg-database.id
}

resource "azurerm_linux_virtual_machine" "virtual-machine-web" {
  name                            = "virtual-machine-web"
  resource_group_name             = var.resource-group-name
  location                        = var.location
  size                            = "Standard_D2s_v3"
  admin_username                  = "adminuser"
  admin_password                  = "P@ssw0rd1234!"
  disable_password_authentication = false

  user_data = base64encode(file("./web-server.sh"))
  network_interface_ids = [
    azurerm_network_interface.network-interface-web.id,
  ]

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
    environment = "Production"
    service     = "Web Server"
  }
}

resource "azurerm_linux_virtual_machine" "virtual-machine-db" {
  name                            = "virtual-machine-db"
  resource_group_name             = var.resource-group-name
  location                        = var.location
  size                            = "Standard_D2s_v3"
  admin_username                  = "adminuser"
  admin_password                  = "P@ssw0rd1234!"
  disable_password_authentication = false

  user_data = base64encode(file("./db-server.sh"))

  network_interface_ids = [
    azurerm_network_interface.network-interface-db.id,
  ]

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
    environment = "Dev"
    service     = "Database"
  }
}

resource "azurerm_public_ip" "gw_public_ip" {
  name                = "gw_public_ip"
  location            = var.location
  resource_group_name = var.resource-group-name

  allocation_method = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "Gw_Vnet1" {
  name                = "Gw_Vnet1"
  location            = var.location
  resource_group_name = var.resource-group-name

  type     = "Vpn"
  vpn_type = "RouteBased"
  sku      = "VpnGw1"

  active_active = false
  enable_bgp    = false

  ip_configuration {
    name                          = "IP-Vnet1"
    public_ip_address_id          = azurerm_public_ip.gw_public_ip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.GatewaySubnet.id
  }

  vpn_client_configuration {
    address_space = ["10.100.0.0/24"]

    vpn_client_protocols = ["SSTP", "IkeV2"]
    vpn_auth_types       = ["Certificate"]

    root_certificate {
      name = "grupo01.com"

      public_cert_data = <<EOF
MIIC5zCCAc+gAwIBAgIQNKBpivv+JL9Dxrv5QzB+jDANBgkqhkiG9w0BAQsFADAW
MRQwEgYDVQQDDAtncnVwbzAxLmNvbTAeFw0yMzA1MDEyMzAzMzFaFw0yNDA1MDEy
MzIzMzFaMBYxFDASBgNVBAMMC2dydXBvMDEuY29tMIIBIjANBgkqhkiG9w0BAQEF
AAOCAQ8AMIIBCgKCAQEAusw8JFtRJ9aX6EHUxd/KqLoFT416liRgIWeaVysQEc8b
W6utKM774iEx+ktZsUl9iwLfex8fS8cNq8rH2k0GLT/HASKzKnLISaz1bOBuHAmD
JuyfGhAUSGvBO1GOkiFFD7ijdiMF+fFtaB2KM9KHRfZDk+8xvEpW3eZN2IX+buaf
WzUj0Zs0GNvcl5u/1M3FUOfZaWdwuGSxcJWWVZXquGWvWYJDp+N9fzpHD7UO3o1S
RbuWHyuF1UnosDVatUeKRslh9/kEsPdQVwvAB3/nR/SWFGQOXUM6ZAtPIMzxRoAm
pcVT3+Vq5/GhSIujEXIrYxOvSr+qNA3lEiJ/owVIIQIDAQABozEwLzAOBgNVHQ8B
Af8EBAMCAgQwHQYDVR0OBBYEFDNraeRkaN9gUjVLsgZ5FE5ubGKfMA0GCSqGSIb3
DQEBCwUAA4IBAQAeo7IJc8m8A4CJKvd8dd7CnLh/uHxz1vZmGCNnHympxm5v9io8
sQIX+biuJwZICJ3C21Qd5SsUC8bfAyigf6t0i+PP+sStRiOXHoSDU2lOw2/b09Kd
WF4ZKnp/dUZ7cpEZ0UmVx3kN4GF0ABGpLVQdAqtIZgejzMe5quovaPHm+npsFLQv
lV0q4FpcHf6vN7J6TbEZzy096A1U0HF/yTxMUeqr9fQLh7EvZpn/skRxbPzpr+ab
rm3AsOod0/Fd0HO73RwXB9AYY+J+keWhhbGSA+wDmN6Fmj1KEcW4ea5kmVa3aOul
s5wjEWYjaZtMN7RiPWswieE04yHdWJ0zdLQS
      EOF

    }

  }
}

