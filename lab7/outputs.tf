output "storage_account_id" {
  value = azurerm_storage_account.sa.id
}

output "redundancy" {
  value = azurerm_storage_account.sa.account_replication_type
}

output "container_name" {
  value = azurerm_storage_container.data.name
}

output "immutability_days" {
  value = azurerm_storage_container_immutability_policy.data_ip.immutability_period_in_days
}

output "lifecycle_rule" {
  value = azurerm_storage_management_policy.policy.rule[0].name
}

output "share1_name" {
  value = azurerm_storage_share.share1.name
}

output "blob_url_private" {
  value       = local.blob_url
  description = "Звичайний URL блоба (має бути недоступний анонімно)."
}

output "blob_url_with_sas" {
  value       = local.blob_sas_url
  sensitive   = true
  description = "SAS-URL для читання (робитиме в InPrivate)."
}
