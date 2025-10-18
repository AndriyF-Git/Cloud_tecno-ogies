variable "subscription_id" {
  description = "(Optional) Pin a subscription"
  type        = string
  default     = null
}

variable "location" {
  description = "Lab region"
  type        = string
  default     = "polandcentral"
}

variable "rg_name" {
  type    = string
  default = "az104-rg8"
}

variable "admin_username" {
  type        = string
  default     = "localadmin"
  description = "Local admin for Windows VMs"
}

variable "admin_password" {
  type        = string
  sensitive   = true
  description = "Secure password for Windows VMs (set via tfvars or TF_VAR_admin_password)"
}

variable "zones" {
  type    = list(string)
  default = ["1","2"]
}

variable "lab_phase" {
  description = "What to deploy: vm_pair | vm_resized | vmss | vmss_autoscale"
  type        = string
  default     = "vmss_autoscale"
  validation {
    condition     = contains(["vm_pair", "vm_resized", "vmss", "vmss_autoscale"], var.lab_phase)
    error_message = "lab_phase must be one of: vm_pair, vm_resized, vmss, vmss_autoscale"
  }
}
