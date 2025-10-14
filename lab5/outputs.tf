output "core_vm_private_ip" {
  description = "Private IP CoreServicesVM"
  value       = azurerm_network_interface.core_nic.private_ip_address
}

output "mfg_vm_private_ip" {
  description = "Private IP ManufacturingVM"
  value       = azurerm_network_interface.mfg_nic.private_ip_address
}

output "generated_vm_password_if_any" {
  description = "Згенерований пароль (якщо не вказував свій)"
  value       = try(random_password.vm.result, null)
  sensitive   = true
}
