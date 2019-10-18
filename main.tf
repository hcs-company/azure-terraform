variable "admin_username" {
  default = "adminuser"
}

variable "admin_password" {}
#variable "admin_password" {
#  default = "Password1234!"
#}

# Configure the provider
provider "azurerm" {
}

# Create a new resource group
resource "azurerm_resource_group" "node" {
  name     = "azure_rg"
  location = "westeurope"

}

resource "azurerm_virtual_network" "node" {
  name                = "azure_vn"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.node.location}"
  resource_group_name = "${azurerm_resource_group.node.name}"
}

resource "azurerm_subnet" "node" {
  name                 = "azure_sub"
  resource_group_name  = "${azurerm_resource_group.node.name}"
  virtual_network_name = "${azurerm_virtual_network.node.name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_public_ip" "node" {
  name                    = "azure_pip"
  location                = "${azurerm_resource_group.node.location}"
  resource_group_name     = "${azurerm_resource_group.node.name}"
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30
  domain_name_label       = "node-rancher"
}

resource "azurerm_network_interface" "node" {
  name                = "azure_ni"
  location            = "${azurerm_resource_group.node.location}"
  resource_group_name = "${azurerm_resource_group.node.name}"
  ip_configuration {
    name                          = "azure_ip"
    subnet_id                     = "${azurerm_subnet.node.id}"
    private_ip_address_allocation = "static"
    private_ip_address            = "10.0.2.5"
    public_ip_address_id          = "${azurerm_public_ip.node.id}"
  }
}

# Create a Linux virtual machine
resource "azurerm_virtual_machine" "node" {
  name                  = "azure_vm"
  location              = "westeurope"
  resource_group_name   = "${azurerm_resource_group.node.name}"
  network_interface_ids = ["${azurerm_network_interface.node.id}"]
  vm_size               = "Standard_B1S"

  storage_os_disk {
    name              = "azure_od"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "azurenode"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  provisioner "remote-exec" {
    connection {
      host     = "${azurerm_public_ip.node.fqdn}"
      type     = "ssh"
      user     = "${var.admin_username}"
      password = "${var.admin_password}"
    }
    inline = [
      #"sudo curl -sfL https://get.k3s.io | sh -"
      "ls -al"
    ]
  }
}
