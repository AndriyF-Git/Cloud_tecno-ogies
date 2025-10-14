terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.113"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "location" { default = "East US" }
variable "rg_name" { default = "az104-rg6" }

variable "admin_username" { default = "azureuser" }
variable "ssh_public_key" { default = "" }
variable "admin_password" {
  type      = string
  default   = ""
  sensitive = true
}

locals {
  use_password = length(var.admin_password) > 0 && length(var.ssh_public_key) == 0
}

resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "az104-06-vnet1"
  address_space       = ["10.60.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Підмережі для VM
resource "azurerm_subnet" "sn_web1" {
  name                 = "subnet-web1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.60.1.0/24"]
}
resource "azurerm_subnet" "sn_web2" {
  name                 = "subnet-web2"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.60.2.0/24"]
}
resource "azurerm_subnet" "sn_web3" {
  name                 = "subnet-web3"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.60.3.0/25"]
}

# Виділена підмережа для App Gateway як у завданні
resource "azurerm_subnet" "sn_appgw" {
  name                 = "subnet-appgw"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.60.3.224/27"]
}

resource "azurerm_network_security_group" "web_nsg" {
  name                = "az104-06-web-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-HTTP-80"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # відкрий SSH для адміністрування
  security_rule {
    name                       = "Allow-SSH-22"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "assoc1" {
  subnet_id                 = azurerm_subnet.sn_web1.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}
resource "azurerm_subnet_network_security_group_association" "assoc2" {
  subnet_id                 = azurerm_subnet.sn_web2.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}
resource "azurerm_subnet_network_security_group_association" "assoc3" {
  subnet_id                 = azurerm_subnet.sn_web3.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}


# Спрощений cloud-init
locals {
  cloud_init = <<-EOF
    #cloud-config
    package_update: true
    packages:
      - nginx
    runcmd:
      - mkdir -p /var/www/html/image /var/www/html/video
      - bash -c 'cat > /var/www/html/index.html << "HTML"
<h1>Hello World from $(hostname)</h1>
<p>Served by nginx on $(hostname)</p>
HTML'
      - bash -c 'cat > /var/www/html/image/index.html << "HTML"
<h2>Images endpoint on $(hostname)</h2>
HTML'
      - bash -c 'cat > /var/www/html/video/index.html << "HTML"
<h2>Videos endpoint on $(hostname)</h2>
HTML'
      - systemctl enable nginx
      - systemctl restart nginx
  EOF
}


resource "random_password" "vm" {
  length  = 16
  special = false
}

locals {
  final_password = local.use_password ? var.admin_password : random_password.vm.result
}

# VM0 у subnet-web1
resource "azurerm_network_interface" "nic0" {
  name                = "az104-06-nic0"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.sn_web1.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm0" {
  name                            = "az104-06-vm0"
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  size                            = "Standard_B1s"
  admin_username                  = var.admin_username
  disable_password_authentication = !local.use_password
  admin_password                  = local.use_password ? local.final_password : null
  network_interface_ids           = [azurerm_network_interface.nic0.id]
  custom_data                     = base64encode(local.cloud_init)

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  os_disk {
    name                 = "az104-06-vm0-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  dynamic "admin_ssh_key" {
    for_each = length(var.ssh_public_key) > 0 ? [1] : []
    content {
      username   = var.admin_username
      public_key = var.ssh_public_key
    }
  }
}

# VM1 у subnet-web2
resource "azurerm_network_interface" "nic1" {
  name                = "az104-06-nic1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.sn_web2.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm1" {
  name                            = "az104-06-vm1"
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  size                            = "Standard_B1s"
  admin_username                  = var.admin_username
  disable_password_authentication = !local.use_password
  admin_password                  = local.use_password ? local.final_password : null
  network_interface_ids           = [azurerm_network_interface.nic1.id]
  custom_data                     = base64encode(local.cloud_init)

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  os_disk {
    name                 = "az104-06-vm1-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  dynamic "admin_ssh_key" {
    for_each = length(var.ssh_public_key) > 0 ? [1] : []
    content {
      username   = var.admin_username
      public_key = var.ssh_public_key
    }
  }
}

# VM2 у subnet-web3
resource "azurerm_network_interface" "nic2" {
  name                = "az104-06-nic2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.sn_web3.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm2" {
  name                            = "az104-06-vm2"
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  size                            = "Standard_B1s"
  admin_username                  = var.admin_username
  disable_password_authentication = !local.use_password
  admin_password                  = local.use_password ? local.final_password : null
  network_interface_ids           = [azurerm_network_interface.nic2.id]
  custom_data                     = base64encode(local.cloud_init)

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  os_disk {
    name                 = "az104-06-vm2-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  dynamic "admin_ssh_key" {
    for_each = length(var.ssh_public_key) > 0 ? [1] : []
    content {
      username   = var.admin_username
      public_key = var.ssh_public_key
    }
  }
}


resource "azurerm_public_ip" "lb_pip" {
  name                = "az104-lbpip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "lb" {
  name                = "az104-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "az104-fe"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "lb_be" {
  name            = "az104-be"
  loadbalancer_id = azurerm_lb.lb.id
}

# Прив’язати NIC vm0 та vm1 до backend pool
resource "azurerm_network_interface_backend_address_pool_association" "be0" {
  network_interface_id    = azurerm_network_interface.nic0.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_be.id
}
resource "azurerm_network_interface_backend_address_pool_association" "be1" {
  network_interface_id    = azurerm_network_interface.nic1.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_be.id
}

resource "azurerm_lb_probe" "hp" {
  name                = "az104-hp"
  loadbalancer_id     = azurerm_lb.lb.id
  protocol            = "Tcp"
  port                = 80
  interval_in_seconds = 5
}

resource "azurerm_lb_rule" "lbrule" {
  name                           = "az104-lbrule"
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "az104-fe"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_be.id]
  probe_id                       = azurerm_lb_probe.hp.id
}


resource "azurerm_public_ip" "appgw_pip" {
  name                = "az104-gwpip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]
}

resource "azurerm_application_gateway" "appgw" {
  name                = "az104-appgw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "appgw-ipcfg"
    subnet_id = azurerm_subnet.sn_appgw.id
  }

  frontend_port {
    name = "port-80"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "frontend-public"
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  backend_address_pool {
    name         = "az104-appgwbe"
    ip_addresses = [azurerm_network_interface.nic1.private_ip_address, azurerm_network_interface.nic2.private_ip_address]
  }

  backend_address_pool {
    name         = "az104-imagebe"
    ip_addresses = [azurerm_network_interface.nic1.private_ip_address]
  }

  backend_address_pool {
    name         = "az104-videobe"
    ip_addresses = [azurerm_network_interface.nic2.private_ip_address]
  }

  probe {
    name                = "http-probe-80"
    protocol            = "Http"
    host                = "127.0.0.1"
    path                = "/"
    interval            = 5
    timeout             = 5
    unhealthy_threshold = 2
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101S" # або "AppGwSslPolicy20220101"
  }

  backend_http_settings {
    name                  = "az104-http"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
    probe_name            = "http-probe-80"
  }

  http_listener {
    name                           = "az104-listener"
    frontend_ip_configuration_name = "frontend-public"
    frontend_port_name             = "port-80"
    protocol                       = "Http"
  }

  url_path_map {
    name                               = "az104-pathmap"
    default_backend_address_pool_name  = "az104-appgwbe"
    default_backend_http_settings_name = "az104-http"

    path_rule {
      name                       = "images"
      paths                      = ["/image/*"]
      backend_address_pool_name  = "az104-imagebe"
      backend_http_settings_name = "az104-http"
    }

    path_rule {
      name                       = "videos"
      paths                      = ["/video/*"]
      backend_address_pool_name  = "az104-videobe"
      backend_http_settings_name = "az104-http"
    }
  }

  # Правило маршрутизації просто посилається на карту шляхів
  request_routing_rule {
    name               = "az104-gwrule"
    rule_type          = "PathBasedRouting"
    http_listener_name = "az104-listener"
    priority           = 10

    url_path_map_name = "az104-pathmap"
  }

  depends_on = [
    azurerm_linux_virtual_machine.vm0,
    azurerm_linux_virtual_machine.vm1,
    azurerm_linux_virtual_machine.vm2
  ]
}




output "lb_public_ip" {
  value = azurerm_public_ip.lb_pip.ip_address
}
output "appgw_public_ip" {
  value = azurerm_public_ip.appgw_pip.ip_address
}
