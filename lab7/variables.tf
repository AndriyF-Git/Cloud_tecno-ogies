variable "subscription_id" {
  description = "2d2c7915-d7d9-4c46-9986-e3254f7b9c4b"
  type        = string
  default     = null
}

variable "location" {
  description = "eastus"
  type        = string
  default     = "eastus"
}

variable "rg_name" {
  type    = string
  default = "az104-rg7"
}

variable "storage_account_name" {
  description = "fedirko13102025lab7"
  type        = string
}

variable "stage" {
  description = "selected_with_ip" #стан лабки disable_public | selected_with_ip | vnet_only
  type        = string
  default     = "vnet_only"
}

variable "client_ipv4" {
  description = ""
  type        = string
  default     = null
}

variable "file_to_upload" {
  description = "C:/Users/fedir/Documents/IPZ_43/Cloud_tecnologies/lab7/file1.txt"
  type        = string
  default     = null
}

variable "share_file_to_upload" {
  description = "C:/Users/fedir/Documents/IPZ_43/Cloud_tecnologies/lab7/file2.txt"
  type        = string
  default     = null
}
