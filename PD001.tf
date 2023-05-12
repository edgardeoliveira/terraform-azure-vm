terraform {
  required_version = ">= 1.4.0"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 3.55.0"
    }
  }
}

provider "azurerm" {
    features {  
  }
}

resource "azurerm_resource_group" "rg-edonlinecloud" {
  name     = "rg-edonlinecloud"
  location = "East US"
}

resource "azurerm_virtual_network" "vnet-ed-cloud" {
  name                = "vnet-ed-cloud"
  resource_group_name = azurerm_resource_group.rg-edonlinecloud.name
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg-edonlinecloud.location

  tags= {
    environment = "Producao"
    Empresa = "Edonline282"
  }
}


resource "azurerm_subnet" "subnet-ed-cloud" {
  name                 = "subnet-ed-cloud"
  resource_group_name  = azurerm_resource_group.rg-edonlinecloud.name
  virtual_network_name = azurerm_virtual_network.vnet-ed-cloud.name
  address_prefixes     = ["10.0.1.0/24"]
}

 resource "azurerm_public_ip" "ip-ed-cloud" {
  name                = "ip-ed-cloud"
  resource_group_name = azurerm_resource_group.rg-edonlinecloud.name
  location            = azurerm_resource_group.rg-edonlinecloud.location
  allocation_method   = "Static"

  tags = {
    environment = "Production"
  }
} 

resource "azurerm_network_interface" "nic-ed-cloud" {
  name                = "nic-ed-cloud"
  location            = azurerm_resource_group.rg-edonlinecloud.location
  resource_group_name = azurerm_resource_group.rg-edonlinecloud.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet-ed-cloud.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip-ed-cloud.id
  }
}

resource "azurerm_linux_virtual_machine" "machine-ed-cloud" {
  name                = "machine-ed-cloud"
  resource_group_name = azurerm_resource_group.rg-edonlinecloud.name
  location            = azurerm_resource_group.rg-edonlinecloud.location
  size                = "Standard_DS1_v2"
  admin_username      = "adminuser"
  admin_password      = "Edgar@1234@"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.nic-ed-cloud.id,
  ]



  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_network_security_group" "security-ed-cloud" {
  name                = "security-ed-cloud"
  location            = azurerm_resource_group.rg-edonlinecloud.location
  resource_group_name = azurerm_resource_group.rg-edonlinecloud.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Web"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }


  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_interface_security_group_association" "nic-security-ed-cloud" {
  network_interface_id      = azurerm_network_interface.nic-ed-cloud.id
  network_security_group_id = azurerm_network_security_group.security-ed-cloud.id
}


resource "null_resource" "instalar-ed-nginx" {
  connection {
    type = "ssh"
    host = azurerm_public_ip.ip-ed-cloud.ip_address
    user = "adminuser"
    password = "Edgar@1234@"
    }
provisioner "remote-exec" {
  inline = [
    "sudo apt update",
    "sudo apt install -y nginx"
    ]  
}
depends_on = [azurerm_linux_virtual_machine.machine-ed-cloud]
}
