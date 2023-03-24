# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone
resource "azurerm_private_dns_zone" "dns_pe_storage" {
  name = "privatelink.${var.subresource}.core.windows.net"
  resource_group_name = var.rg.name
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link
resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet_pe_storage" {
  name = "privatelink.${var.subresource}.core.windows.net-${var.vnet.name}"
  resource_group_name = var.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.dns_pe_storage.name
  virtual_network_id = var.vnet.id
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint
resource "azurerm_private_endpoint" "pe_storage" {
  name = "pe-${var.storage_account.name}-${var.subresource}"
  location = var.rg.location
  resource_group_name = var.rg.name
  subnet_id = var.subnet.id
  custom_network_interface_name = "pe-${var.storage_account.name}-${var.subresource}-nic"

  private_dns_zone_group {
    name = "dns-pe-${var.storage_account.name}-${var.subresource}"
    private_dns_zone_ids = [ azurerm_private_dns_zone.dns_pe_storage.id ]
  }

  private_service_connection {
    name = "plink-${var.subresource}"
    is_manual_connection = false
    private_connection_resource_id = var.storage_account.id
    subresource_names = [ "${var.subresource}" ]
  }
}
