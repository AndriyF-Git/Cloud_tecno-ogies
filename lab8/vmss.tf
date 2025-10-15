# Public LB for VMSS HTTP (task 3)
resource "azurerm_public_ip" "lb_pip" {
  count               = local.do_vmss ? 1 : 0
  name                = "vmss-lb-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}


resource "azurerm_lb" "vmss_lb" {
  count               = local.do_vmss ? 1 : 0
  name                = "vmss-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"


  frontend_ip_configuration {
    name                 = "fe"
    public_ip_address_id = azurerm_public_ip.lb_pip[0].id
  }
  tags = local.tags
}

resource "azurerm_lb_backend_address_pool" "bepool" {
  count           = local.do_vmss ? 1 : 0
  name            = "bepool"
  loadbalancer_id = azurerm_lb.vmss_lb[0].id
}


resource "azurerm_lb_probe" "http" {
  count           = local.do_vmss ? 1 : 0
  name            = "http-80"
  loadbalancer_id = azurerm_lb.vmss_lb[0].id
  protocol        = "Tcp"
  port            = 80
}


resource "azurerm_lb_rule" "http" {
  count                          = local.do_vmss ? 1 : 0
  name                           = "http-80"
  loadbalancer_id                = azurerm_lb.vmss_lb[0].id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "fe"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.bepool[0].id]
  probe_id                       = azurerm_lb_probe.http[0].id
}


resource "azurerm_windows_virtual_machine_scale_set" "vmss" {
  count               = local.do_vmss ? 1 : 0
  name                = "vmss1"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard_E2s_v6"
  instances           = 2
  zones               = ["1", "2", "3"]
  upgrade_mode        = "Manual"


  admin_username = var.admin_username
  admin_password = var.admin_password


  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter-gensecond"
    version   = "latest"
  }


  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }


  network_interface {
    name    = "nic"
    primary = true


    ip_configuration {
      name                                   = "ipconfig"
      primary                                = true
      subnet_id                              = azurerm_subnet.subnet.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bepool[0].id]
      # Public IPs per instance are not used; LB has the public IP
    }
  }


  tags = local.tags
}
