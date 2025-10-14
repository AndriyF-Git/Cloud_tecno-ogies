variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "vm_admin_username" {
  description = "Логін локального адміністратора для ВМ"
  type        = string
  default     = "localadmin"
}

variable "vm_admin_password" {
  description = "Пароль для локального адміністратора"
  type        = string
  default     = null
  sensitive   = true
}
