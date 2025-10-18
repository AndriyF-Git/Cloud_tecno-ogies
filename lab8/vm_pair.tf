# Two Windows VMs across zones (task 1)
resource "random_string" "suffix" {
  length  = 3
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_network_interface" "vm_nic" {
  count               = local.do_vm_pair ? 2 : 0
  name                = "vm${count.index + 1}-nic-${random_string.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name


  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    # No public IP (per lab)
  }
  tags = local.tags
}


resource "azurerm_windows_virtual_machine" "vm" {
  count               = local.do_vm_pair ? 2 : 0
  name                = "az104-vm${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size = local.do_vm_resize && count.index == 0 ? "Standard_E2ads_v6" : "Standard_E2s_v6"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.vm_nic[count.index].id
  ]


  zone = var.zones[count.index]


  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }


  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter-gensecond"
    version   = "latest"
  }


  tags = local.tags
}


# Data disk life-cycle for vm1 (task 2)
# 1) Create disk (HDD), 2) Attach, 3) Detach, 4) Convert to Standard SSD, 5) Attach again


resource "azurerm_managed_disk" "vm1_data" {
  count                = local.do_vm_pair ? 1 : 0
  name                 = "vm1-disk1"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = local.data_disk_sku   # <- головне
  create_option        = "Empty"
  disk_size_gb         = 32
  zone = var.zones[0]
  tags                 = local.tags
  # lifecycle НЕ потрібен — зміна Standard_LRS -> StandardSSD_LRS пройде in-place,
  # але диск має бути від’єднаний у фазі vm_detach.
}




# When lab_phase=vm_pair → attach once (HDD). When lab_phase=vm_resized → reattach the upgraded SSD.
resource "azurerm_virtual_machine_data_disk_attachment" "vm1_attach" {
  count              = local.attach_disk && local.do_vm_pair ? 1 : 0
  managed_disk_id    = azurerm_managed_disk.vm1_data[0].id
  virtual_machine_id = azurerm_windows_virtual_machine.vm[0].id
  lun                = 0
  caching            = "ReadOnly"
}

