variable "rg" {
  type = object({
    name = string,
    location = string
  })
  description = "Resource Group"
}

variable "vnet" {
  type = object({
    id = string,
    name = string
  })
  description = "Virtual Network"
}

variable "subnet" {
    type = object({
        id = string
    })
    description = "Subnet"
}

variable "storage_account" {
    type = object({
        id = string,
        name = string
    })
    description = "Storage Account"
}

variable "subresource" {
    type = string
    description = "Subresource Name"
}
