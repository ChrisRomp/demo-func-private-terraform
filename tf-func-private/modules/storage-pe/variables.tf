variable "rg_name" {
  type = string
  description = "Resource Group name."
}

variable "vnet_name" {
  type = string
  description = "Virtual Network name."
}

variable "subnet_name" {
    type = string
    description = "Subnet name."
}

variable "storage_account_name" {
    type = string
    description = "Storage Account name."
}

variable "subresource" {
    type = string
    description = "Subresource name."
}
