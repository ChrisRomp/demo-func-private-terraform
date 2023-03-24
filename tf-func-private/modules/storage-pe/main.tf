data "azurerm_resource_group" "rg" {
  name = var.rg_name
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network
data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subnet
data "azurerm_subnet" "subnet" {
  name = var.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = data.azurerm_resource_group.rg.name
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/storage_account
data "azurerm_storage_account" "storage" {
  name = var.storage_account_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone
resource "azurerm_private_dns_zone" "dns_pe_storage" {
  name = "privatelink.${var.subresource}.core.windows.net"
  resource_group_name = data.azurerm_resource_group.rg.name
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link
resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet_pe_storage" {
  name = "privatelink.${var.subresource}.core.windows.net-${data.azurerm_virtual_network.vnet.name}"
  resource_group_name = data.azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.dns_pe_storage.name
  virtual_network_id = data.azurerm_virtual_network.vnet.id
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint
resource "azurerm_private_endpoint" "pe_storage" {
  name = "pe-${data.azurerm_storage_account.storage.name}-${var.subresource}"
  location = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  subnet_id = data.azurerm_subnet.subnet.id
  custom_network_interface_name = "pe-${data.azurerm_storage_account.storage.name}-${var.subresource}-nic"

  private_dns_zone_group {
    name = "dns-pe-${data.azurerm_storage_account.storage.name}-${var.subresource}"
    private_dns_zone_ids = [ azurerm_private_dns_zone.dns_pe_storage.id ]
  }

  private_service_connection {
    name = "plink-${var.subresource}"
    is_manual_connection = false
    private_connection_resource_id = data.azurerm_storage_account.storage.id
    subresource_names = [ "${var.subresource}" ]
  }
}
