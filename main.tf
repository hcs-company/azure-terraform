variable "admin_username" {
  default = "k3suser"
}
variable "admin_password" {
  default = "Password1234!"
}

# Configure the provider
provider "azurerm" {
}

# Create a new resource group
resource "azurerm_resource_group" "k3s" {
  name     = "azure_rg"
  location = "westeurope"

}

resource "azurerm_virtual_network" "k3s" {
  name                = "azure_vn"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.k3s.location}"
  resource_group_name = "${azurerm_resource_group.k3s.name}"
}

resource "azurerm_subnet" "k3s" {
  name                 = "azure_sub"
  resource_group_name  = "${azurerm_resource_group.k3s.name}"
  virtual_network_name = "${azurerm_virtual_network.k3s.name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_public_ip" "k3s" {
  name                    = "azure_pip"
  location                = "${azurerm_resource_group.k3s.location}"
  resource_group_name     = "${azurerm_resource_group.k3s.name}"
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30
  domain_name_label       = "k3s-rancher"
}

resource "azurerm_network_interface" "k3s" {
  name                = "azure_ni"
  location            = "${azurerm_resource_group.k3s.location}"
  resource_group_name = "${azurerm_resource_group.k3s.name}"
  ip_configuration {
    name                          = "azure_ip"
    subnet_id                     = "${azurerm_subnet.k3s.id}"
    private_ip_address_allocation = "static"
    private_ip_address            = "10.0.2.5"
    public_ip_address_id          = "${azurerm_public_ip.k3s.id}"
  }
}

# Create a Linux virtual machine
resource "azurerm_virtual_machine" "k3s" {
  name                  = "azure_vm"
  location              = "westeurope"
  resource_group_name   = "${azurerm_resource_group.k3s.name}"
  network_interface_ids = ["${azurerm_network_interface.k3s.id}"]
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
    computer_name  = "azurek3snode"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  provisioner "remote-exec" {
    connection {
      host     = "${azurerm_public_ip.k3s.fqdn}"
      type     = "ssh"
      user     = "${var.admin_username}"
      password = "${var.admin_password}"
    }
    inline = [
      "sudo curl -sfL https://get.k3s.io | sh -"
    ]
  }
}
