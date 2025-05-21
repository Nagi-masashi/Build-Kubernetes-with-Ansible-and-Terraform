### Create Azure VM with terraform

```
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  #    az login を使用
}

data "azurerm_subnet" "existing" {
  name                = "${SUBNET_NAME}"
  virtual_network_name = "${VIRTUAL_NETWORK_NAME}"
  resource_group_name = "${RESOURCE_GROUP_NAME}"
}

resource "azurerm_network_interface" "k8s_nic" {
  name                = "k8s-nic"
  resource_group_name = "${RESOURCE_GROUP_NAME}"
  location            = "japaneast"

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.existing.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "k8s_vm" {
  name                  = "${VM_NAME}"
  resource_group_name   = "${RESOURCE_GROUP_NAME}"
  location              = "japaneast"
  size                  = "Standard_B2s"
  network_interface_ids = [azurerm_network_interface.k8s_nic.id]
  admin_username        = "azureuser"

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

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
```
