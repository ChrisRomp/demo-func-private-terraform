variable "rg_name" {
  type = string
}

variable "location" {
  type = string
  default = "westus3"
}

variable "vnet_name" {
  type = string
  description = "Virtual Network name"
}

variable "vnet_address_space" {
  type = list(string)
  description = "Virtual network IP address space"
}

variable "snet_common_name" {
  type = string
  description = "Common subnet name"
}

variable "snet_common_cidr" {
  type = string
  description = "CIDR for Common subnet"
}

variable "snet_appplan_name" {
  type = string
  description = "AppPlan subnet name"
}
  
variable "snet_appplan_cidr" {
  type = string
  description = "CIDR for AppPlan subnet"
}

variable "snet_bastion_cidr" {
  type = string
  description = "CIDR for AzureBastionSubnet"
}

variable "bastion_pip_name" {
  type = string
  description = "Bastion public IP name"
  default = "pip-bastion"
}

variable "bastion_name" {
  type = string
  description = "Bastion host name"
  default = "bas-bastionhost"
}

variable "vm_jumpbox_name" {
  type = string
  description = "Jump Box VM hostname"
}

variable "vm_jumpbox_sku" {
  type = string
  description = "SKU for Jump Box VM"
  default = "Standard_DS2_v2"
}

variable "vm_jumpbox_user" {
  type = string
  description = "Username for shared admin account (when using ssh key auth)"
}

variable "storage_account_name" {
  type = string
  description = "Storage account name"
}

variable "app_plan_name" {
  type = string
  description = "App Service Plan name"
}

variable "app_plan_sku" {
  type = string
  description = "App Service Plan SKU"
}

variable "function_app_name" {
  type = string
  description = "Function App name"
}

variable "app_insights_name" {
  type = string
  description = "Application Insights name"
}

terraform {
  required_version = ">= 0.14"
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.47.0"
    }
  }
}

provider "azurerm" {
  # Configuration options
  features {}
}

### NETWORKING ###
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network
resource "azurerm_virtual_network" "vnet" {
  name = var.vnet_name
  location = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space = var.vnet_address_space
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet
resource "azurerm_subnet" "snet_common" {
  name = var.snet_common_name
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes = [var.snet_common_cidr]
  private_endpoint_network_policies_enabled = false
}

resource "azurerm_subnet" "snet_appplan" {
  name = var.snet_appplan_name
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes = [var.snet_appplan_cidr]

  delegation {
    name = "delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "snet_bastion" {
  name = "AzureBastionSubnet" # Do not rename
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes = [var.snet_bastion_cidr]
}


### BASTION ###
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
resource "azurerm_public_ip" "pip_bastion" {
  name                = var.bastion_pip_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/bastion_host
resource "azurerm_bastion_host" "bastion" {
  name                = var.bastion_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku = "Standard"
  scale_units = 2
  copy_paste_enabled = true

  # Native client support
  tunneling_enabled = true

  ip_configuration {
    name                 = "bas-ip-configuration"
    subnet_id            = azurerm_subnet.snet_bastion.id
    public_ip_address_id = azurerm_public_ip.pip_bastion.id
  }
}


### VIRTUAL MACHINE (Jump Box) ###
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface
resource "azurerm_network_interface" "nic_vm_jumpbox" {
  name                = "${var.vm_jumpbox_name}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet_common.id
    private_ip_address_allocation = "Dynamic"
  }
}

# https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key
resource "tls_private_key" "vm_jumphost_ssh_key" {
    algorithm = "RSA"
    rsa_bits = 4096
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine
resource "azurerm_linux_virtual_machine" "vm_jumpbox" {
  name                = var.vm_jumpbox_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.vm_jumpbox_sku
  admin_username      = var.vm_jumpbox_user
  network_interface_ids = [
    azurerm_network_interface.nic_vm_jumpbox.id,
  ]

  identity {
    type = "SystemAssigned"
  }

  admin_ssh_key {
    username   = var.vm_jumpbox_user
    public_key = tls_private_key.vm_jumphost_ssh_key.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "${var.vm_jumpbox_name}-os-disk"
  }

  # az vm image list-offers -l westus3 --publisher Canonical --query "[?contains(name, 'focal')]"
  # az vm image list-skus -l westus3 --publisher Canonical --offer 0001-com-ubuntu-server-focal
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_extension
resource "azurerm_virtual_machine_extension" "vm_jumpbox_aadlogin" {
  name                 = "AADSSHLogin"
  virtual_machine_id   = azurerm_linux_virtual_machine.vm_jumpbox.id
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADSSHLoginForLinux"
  type_handler_version = "1.0"
}


### STORAGE ACCOUNT ###
# Fetch local IP address for network rules
data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account
resource "azurerm_storage_account" "storage" {
  name                     = var.storage_account_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  allow_nested_items_to_be_public = false

  public_network_access_enabled = true
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    # Allow local IP access for file share creation
    ip_rules       = [chomp(data.http.myip.response_body)]
  }
}

# Private Endpoint - Blob
module "pe_blob" {
  source = "./modules/storage-pe"

  rg = azurerm_resource_group.rg
  vnet = azurerm_virtual_network.vnet
  subnet = azurerm_subnet.snet_common
  storage_account = azurerm_storage_account.storage
  subresource = "blob"
}

# Private Endpoint - Table
module "pe_table" {
  source = "./modules/storage-pe"

  rg = azurerm_resource_group.rg
  vnet = azurerm_virtual_network.vnet
  subnet = azurerm_subnet.snet_common
  storage_account = azurerm_storage_account.storage
  subresource = "table"
}

# Private Endpoint - Queue
module "pe_queue" {
  source = "./modules/storage-pe"

  rg = azurerm_resource_group.rg
  vnet = azurerm_virtual_network.vnet
  subnet = azurerm_subnet.snet_common
  storage_account = azurerm_storage_account.storage
  subresource = "queue"
}

# Private Endpoint - File
module "pe_file" {
  source = "./modules/storage-pe"

  rg = azurerm_resource_group.rg
  vnet = azurerm_virtual_network.vnet
  subnet = azurerm_subnet.snet_common
  storage_account = azurerm_storage_account.storage
  subresource = "file"
}


### APPLICATION INSIGHTS ###
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace
resource "azurerm_log_analytics_workspace" "workspace" {
  name                = "log-analytics-${var.app_insights_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_insights
resource "azurerm_application_insights" "app_insights" {
  name                = var.app_insights_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.workspace.id
  application_type    = "web"
}


### APP PLAN ###
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/service_plan
resource "azurerm_service_plan" "asp" {
  name                = var.app_plan_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  os_type     = "Linux"
  sku_name    = var.app_plan_sku
}

# Create a unique string to use as the suffix of the file share
# https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string
resource "random_string" "storage_share_suffix" {
  length  = 5
  numeric = false
  special = false
  upper   = false
}

# Creating the storage share ahead of time allows us to attach to a private storage account
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_share
resource "azurerm_storage_share" "share" {
  name                 = "${var.function_app_name}-${random_string.storage_share_suffix.result}"
  storage_account_name = azurerm_storage_account.storage.name
  access_tier          = "TransactionOptimized"
  quota                = 5120

  depends_on = [
    azurerm_storage_account.storage
  ]
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_function_app
resource "azurerm_linux_function_app" "app" {
  name                = var.function_app_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id = azurerm_service_plan.asp.id

  storage_account_name = azurerm_storage_account.storage.name
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key

  virtual_network_subnet_id = azurerm_subnet.snet_appplan.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.10"
    }
    application_insights_connection_string = azurerm_application_insights.app_insights.connection_string
  }

  app_settings = {
    FUNCTIONS_EXTENSION_VERSION = "~4"
    FUNCTIONS_WORKER_RUNTIME = "python"
    WEBSITE_CONTENTOVERVNET = "1"
    WEBSITE_CONTENTSHARE = azurerm_storage_share.share.name
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = azurerm_storage_account.storage.primary_connection_string
    AzureWebJobsStorage = azurerm_storage_account.storage.primary_connection_string
  }

  depends_on = [
    azurerm_storage_share.share
  ]
}

# Private DNS Zone for Function App
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone
resource "azurerm_private_dns_zone" "dns_zone_func" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.rg.name
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link
resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet_pe_storage" {
  name = "privatelink.azurewebsites.net-${azurerm_virtual_network.vnet.name}"
  resource_group_name = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.dns_zone_func.name
  virtual_network_id = azurerm_virtual_network.vnet.id
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint
resource "azurerm_private_endpoint" "pe_func" {
  name = "pe-${azurerm_linux_function_app.app.name}"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id = azurerm_subnet.snet_common.id
  custom_network_interface_name = "pe-${azurerm_linux_function_app.app.name}-nic"

  private_dns_zone_group {
    name = "dns-pe-${azurerm_linux_function_app.app.name}"
    private_dns_zone_ids = [ azurerm_private_dns_zone.dns_zone_func.id ]
  }

  private_service_connection {
    name = "plink-${azurerm_linux_function_app.app.name}"
    is_manual_connection = false
    private_connection_resource_id = azurerm_linux_function_app.app.id
    subresource_names = [ "sites" ]
  }
}
