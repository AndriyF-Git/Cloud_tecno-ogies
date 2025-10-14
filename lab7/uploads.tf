# Потрібен локальний файл (var.file_to_upload)

resource "azurerm_storage_blob" "sample_blob" {
  count                  = var.file_to_upload == null ? 0 : 1
  name                   = "securitytest/${basename(var.file_to_upload)}"
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_container.data.name
  type                   = "Block"
  source                 = var.file_to_upload
  access_tier            = "Hot"
}

resource "azurerm_storage_share_file" "share_file" {
  count            = var.share_file_to_upload == null ? 0 : 1
  name             = basename(var.share_file_to_upload)
  storage_share_id = azurerm_storage_share.share1.id
  source           = var.share_file_to_upload
  content_type     = "application/octet-stream"
}

# Аналог кроку "Generate SAS" у порталі
data "azurerm_storage_account_sas" "read_sas" {
  connection_string = azurerm_storage_account.sa.primary_connection_string

  # вчора -> завтра
  start      = timeadd(timestamp(), "-24h")
  expiry     = timeadd(timestamp(), "24h")
  https_only = true
  resource_types {
    service   = false # операції рівня сервісу
    container = false # операції з контейнером/шарою (list тощо)
    object    = true  # доступ до об'єктів (блобів/файлів)
  }

  services {
    blob  = true
    file  = false
    queue = false
    table = false
  }
  signed_version = "2020-08-04"

  permissions {
    read    = true
    write   = false
    delete  = false
    list    = false
    add     = false
    create  = false
    update  = false
    process = false
    tag     = false
    filter  = false
  }
}

locals {
  blob_base_url = "https://${azurerm_storage_account.sa.name}.blob.core.windows.net/${azurerm_storage_container.data.name}"
  blob_name     = var.file_to_upload == null ? null : azurerm_storage_blob.sample_blob[0].name
  blob_url      = var.file_to_upload == null ? null : "${local.blob_base_url}/${local.blob_name}"
  blob_sas_url  = var.file_to_upload == null ? null : "${local.blob_base_url}/${local.blob_name}?${data.azurerm_storage_account_sas.read_sas.sas}"
}
