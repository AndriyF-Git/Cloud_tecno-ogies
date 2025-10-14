locals {
  tags = {
    lab  = "az104-lab07"
    part = "storage"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
  tags     = local.tags
}

# Storage Account
resource "azurerm_storage_account" "sa" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = "RAGRS" 

  # Етапи мережі:
  # 1) Disable public access
  # 2) Enable + Selected networks (IP)
  # 3) Selected networks (тільки VNet з service endpoint)
  public_network_access_enabled = var.stage == "disable_public" ? false : true

  dynamic "network_rules" {
    for_each = var.stage == "disable_public" ? [] : [1]
    content {
      default_action             = "Deny"
      bypass                     = ["AzureServices"]
      ip_rules = var.stage == "selected_with_ip" && var.client_ipv4 != null ? [var.client_ipv4] : []
      virtual_network_subnet_ids = var.stage == "vnet_only" ? [azurerm_subnet.default.id] : []
    }
  }

  tags = local.tags
}

resource "azurerm_storage_management_policy" "policy" {
  storage_account_id = azurerm_storage_account.sa.id

  rule {
    name    = "Movetocool"
    enabled = true

    filters {
      blob_types   = ["blockBlob"]
      prefix_match = [] # увесь акаунт; за потреби можна звузити
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than = 30
      }
    }
  }
}

resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

# Time-based retention 180 days (Unlocked)
resource "azurerm_storage_container_immutability_policy" "data_ip" {
  storage_container_resource_manager_id = azurerm_storage_container.data.resource_manager_id
  immutability_period_in_days           = 180
  locked                                = false #не ставити true, лочить все так що не можна потім видалити
}

resource "azurerm_storage_share" "share1" {
  name                 = "share1"
  storage_account_name = azurerm_storage_account.sa.name
  quota                = 100 # GiB
  access_tier          = "TransactionOptimized"
}

resource "azurerm_virtual_network" "vnet1" {
  name                = "vnet1"
  address_space       = ["10.20.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}

resource "azurerm_subnet" "default" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.20.1.0/24"]

  service_endpoints = ["Microsoft.Storage"]
}
