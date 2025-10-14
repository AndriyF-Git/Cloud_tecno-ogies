resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
  tags     = local.tags
}


# Core VNet for both standalone VMs and VMSS
resource "azurerm_virtual_network" "vnet" {
  name                = "lab08-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.80.0.0/16"]
  tags                = local.tags
}


resource "azurerm_subnet" "subnet" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.80.1.0/24"]
}


# NSG for VMSS subnet to allow HTTP (task 3)
resource "azurerm_network_security_group" "vmss_nsg" {
  count               = local.do_vmss ? 1 : 0
  name                = "vmss1-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  security_rule {
    name                       = "allow-http"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  tags = local.tags
}


resource "azurerm_subnet_network_security_group_association" "vmss_subnet_assoc" {
  count                     = local.do_vmss ? 1 : 0
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.vmss_nsg[0].id
}
