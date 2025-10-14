locals {
tags = {
lab = "az104-lab08"
}


do_vm_pair = contains(["vm_pair","vm_resized"], var.lab_phase)
do_vm_resize = var.lab_phase == "vm_resized"
do_vmss = contains(["vmss","vmss_autoscale"], var.lab_phase)
do_autoscale = var.lab_phase == "vmss_autoscale"
}