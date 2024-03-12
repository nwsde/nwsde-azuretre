data "azurerm_resource_group" "rg-core" {
  name = local.core_resource_group_name
}

data "azurerm_data_factory" "lakehouse-adf" {
  name = local.lakehouse_adf_name
  resource_group_name = data.azurerm_resource_group.rg-core.name
}

data "azurerm_storage_account" "lakehouse-sa" {
  name = local.lakehouse_sa_name
  resource_group_name = local.lakehouse_ws_rg_name
}

data "azurerm_storage_account" "ws-sa" {
  name = local.workspace_sa_name
  resource_group_name = var.ws_resource_group_name
}

