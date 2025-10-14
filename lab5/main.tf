terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.114"
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


resource "azurerm_resource_group" "rg" {
  name     = "az104-rg5"
  location = var.location # "East US"
}


# VNet + підмережі
resource "azurerm_virtual_network" "core_vnet" {
  name                = "CoreServicesVnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "core_subnet" {
  name                 = "Core"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.core_vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "perimeter_subnet" {
  name                 = "perimeter"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.core_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "core_nic" {
  name                = "nic-CoreServicesVM"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.core_subnet.id
    private_ip_address_allocation = "Dynamic"
    # без public_ip_address_id
  }
}

resource "random_password" "vm" {
  length           = 16
  special          = true
  override_special = "!@#$%^&*()-_=+[]{}"
}

# Windows Server 2019 Gen2
resource "azurerm_windows_virtual_machine" "core_vm" {
  name                = "CoreServicesVM"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_D2s_v3"
  admin_username      = var.vm_admin_username
  admin_password      = coalesce(var.vm_admin_password, random_password.vm.result)

  network_interface_ids = [azurerm_network_interface.core_nic.id]

  os_disk {
    name                 = "CoreServicesVM_OSDisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # Image: Windows Server 2019 Datacenter, Gen2
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-datacenter-gensecond"
    version   = "latest"
  }


}

resource "azurerm_virtual_network" "mfg_vnet" {
  name                = "ManufacturingVnet"
  address_space       = ["172.16.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "mfg_subnet" {
  name                 = "Manufacturing"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.mfg_vnet.name
  address_prefixes     = ["172.16.0.0/24"]
}

resource "azurerm_network_interface" "mfg_nic" {
  name                = "nic-ManufacturingVM"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.mfg_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "mfg_vm" {
  name                = "ManufacturingVM"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_D2s_v3"
  admin_username      = var.vm_admin_username
  admin_password      = coalesce(var.vm_admin_password, random_password.vm.result)

  network_interface_ids = [azurerm_network_interface.mfg_nic.id]

  os_disk {
    name                 = "ManufacturingVM_OSDisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-datacenter-gensecond"
    version   = "latest"
  }
}

# Network Watcher (в регіоні East US)
resource "azurerm_network_watcher" "nw" {
  name                = "NetworkWatcher_eastus"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_virtual_machine_extension" "nw_agent_core" {
  name                       = "NetworkWatcherAgentWindows"
  virtual_machine_id         = azurerm_windows_virtual_machine.core_vm.id
  publisher                  = "Microsoft.Azure.NetworkWatcher"
  type                       = "NetworkWatcherAgentWindows"
  type_handler_version       = "1.4"
  auto_upgrade_minor_version = true
}

resource "azurerm_virtual_machine_extension" "nw_agent_mfg" {
  name                       = "NetworkWatcherAgentWindows"
  virtual_machine_id         = azurerm_windows_virtual_machine.mfg_vm.id
  publisher                  = "Microsoft.Azure.NetworkWatcher"
  type                       = "NetworkWatcherAgentWindows"
  type_handler_version       = "1.4"
  auto_upgrade_minor_version = true
}

resource "time_sleep" "wait_for_agents" {
  depends_on = [azurerm_virtual_machine_extension.nw_agent_core,
  azurerm_virtual_machine_extension.nw_agent_mfg]
  create_duration = "60s"
}


# Connection Monitor v2: TCP 3389 від CoreServicesVM -> ManufacturingVM
resource "azurerm_network_connection_monitor" "cm_rdp" {
  name               = "cm-Core-to-Mfg-RDP"
  location           = azurerm_resource_group.rg.location
  network_watcher_id = azurerm_network_watcher.nw.id

  depends_on = [
    time_sleep.wait_for_agents
  ]

  endpoint {
    name               = "src-CoreServicesVM"
    target_resource_id = azurerm_windows_virtual_machine.core_vm.id
  }

  endpoint {
    name               = "dst-ManufacturingVM"
    target_resource_id = azurerm_windows_virtual_machine.mfg_vm.id
  }

  test_configuration {
    name                      = "tcp3389"
    protocol                  = "Tcp"
    test_frequency_in_seconds = 300
    tcp_configuration {
      port = 3389
    }
    preferred_ip_version = "IPv4"
  }

  test_group {
    name                     = "core-to-mfg"
    enabled                  = true
    test_configuration_names = ["tcp3389"]
    source_endpoints         = ["src-CoreServicesVM"]
    destination_endpoints    = ["dst-ManufacturingVM"]
  }
}

resource "azurerm_virtual_network_peering" "core_to_mfg" {
  name                      = "CoreServicesVnet-to-ManufacturingVnet"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.core_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.mfg_vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
  allow_gateway_transit        = false
}

resource "azurerm_virtual_network_peering" "mfg_to_core" {
  name                      = "ManufacturingVnet-to-CoreServicesVnet"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.mfg_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.core_vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
  allow_gateway_transit        = false
}


resource "azurerm_route_table" "rt_core" {
  name                          = "rt-CoreServices"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  bgp_route_propagation_enabled = false
}

# Маршрут з perimeter -> в Core через майбутню NVA 10.0.1.7
resource "azurerm_route" "perimeter_to_core" {
  name                   = "PerimetertoCore"
  resource_group_name    = azurerm_resource_group.rg.name
  route_table_name       = azurerm_route_table.rt_core.name
  address_prefix         = "10.0.0.0/16" # Core VNet
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = "10.0.1.7" # майбутня NVA у perimeter
}

resource "azurerm_subnet_route_table_association" "core_assoc" {
  subnet_id      = azurerm_subnet.core_subnet.id
  route_table_id = azurerm_route_table.rt_core.id
}
