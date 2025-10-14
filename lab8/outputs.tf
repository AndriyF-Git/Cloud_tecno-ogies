output "rg_name" {
  value = azurerm_resource_group.rg.name
}


output "vm_names" {
  value = local.do_vm_pair ? [for i in azurerm_windows_virtual_machine.vm : i.name] : []
}


output "vmss_public_ip" {
  value       = local.do_vmss ? azurerm_public_ip.lb_pip[0].ip_address : null
  description = "Public IP of the VMSS load balancer (HTTP 80)"
}
