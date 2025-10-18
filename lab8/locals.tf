locals {
  tags = { lab = "az104-lab08" }

  # Фази
  do_vm_pair    = contains(["vm_pair","vm_resized"], var.lab_phase)
  do_vm_resize  = var.lab_phase == "vm_resized"
  do_vmss       = contains(["vmss","vmss_autoscale"], var.lab_phase)
  do_autoscale  = var.lab_phase == "vmss_autoscale"

  # Коли тримати диск прикріпленим:
  # прикріплено у vm_pair та vm_resized, але НЕ у vm_detach
  attach_disk   = var.lab_phase != "vm_detach"

  # Тип диска: HDD у vm_pair / vm_detach, SSD у vm_resized
  data_disk_sku = var.lab_phase == "vm_resized" ? "StandardSSD_LRS" : "Standard_LRS"
}
