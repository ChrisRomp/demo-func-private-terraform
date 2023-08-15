rg_name = "TEST-cr1-func-priv-02"
location = "westus3"

# NETWORKING
vnet_name = "vnet-cr1-func-priv-02"
vnet_address_space = [
  "10.16.56.0/24"
]

snet_common_name = "snet-common-cr1-func-priv-02"
snet_common_cidr = "10.16.56.0/26"

snet_appplan_name = "snet-appplan-cr1-func-priv-02"
snet_appplan_cidr = "10.16.56.128/26"

snet_bastion_cidr = "10.16.56.192/26"

# BASTION
bastion_pip_name = "pip-bas-cr1-func-priv-02"
bastion_name = "bas-cr1-func-priv-02"

# VM JUMPBOX
vm_pip_name = "pip-vm-jumpbox-cr1-func-priv-02"
vm_jumpbox_name = "vm-jumpbox-cr1-func-priv-02"
vm_jumpbox_sku = "Standard_DS2_v2"
vm_jumpbox_user = "azureuser"

# STORAGE
storage_account_name = "storcr1funcprivate02"

# APP SERVICE PLAN
app_plan_name = "asp-cr1-func-priv-02"
app_plan_sku = "EP1"

# APP INSIGHTS
app_insights_name = "ai-cr1-func-priv-02"

# FUNCTION APP
function_app_name = "func-cr1-func-priv-02b"
