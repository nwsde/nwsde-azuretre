data "azurerm_subnet" "shared" {
  resource_group_name  = local.core_resource_group_name
  virtual_network_name = local.core_vnet
  name                 = "SharedSubnet"
}

resource "azurerm_data_factory" "adf" {
  name                = "lakehouse-ws-${var.short_workspace_id}adf"
  resource_group_name      = local.core_resource_group_name
  location                 = var.location
  managed_virtual_network_enabled   = true
  public_network_enabled = false

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_private_endpoint" "adf-pe" {
  name                = "lakhouse-ws-${var.short_workspace_id}-adf-pe"
  resource_group_name = local.core_resource_group_name
  location            = var.location
  subnet_id           = data.azurerm_subnet.shared.id

  private_service_connection {
    name                           = "nwsde-ir-connection"
    private_connection_resource_id = azurerm_data_factory.adf.id
    is_manual_connection           = false
    subresource_names = ["dataFactory"]
  }
  # Set up use of existing private DNS zone
}

resource "azurerm_data_factory_integration_runtime_azure" "int_runtime" {
  name            = "nwsde-ir"
  data_factory_id = azurerm_data_factory.adf.id
  location        = "AutoResolve"
  depends_on = [ azurerm_data_factory.adf ]
  virtual_network_enabled = true
}

resource "azurerm_data_factory_managed_private_endpoint" "lh-store-pe" {
  name               = "lakehouse-ws-pe"
  data_factory_id    = azurerm_data_factory.adf.id
  target_resource_id = data.azurerm_storage_account.ws-sa.id
  subresource_name   = "blob"
  depends_on = [ azurerm_data_factory.adf, data.azurerm_storage_account.ws-sa ]
}

data "azapi_resource" "lh_batch_storage_account_private_endpoint_connection" {
  type                   = "Microsoft.Storage/storageAccounts@2022-09-01"
  resource_id            = data.azurerm_storage_account.ws-sa.id
  response_export_values = ["properties.privateEndpointConnections."]

  depends_on = [azurerm_data_factory_managed_private_endpoint.lh-store-pe, data.azurerm_storage_account.ws-sa]
}

locals {

  lh_storage_account_blob_private_endpoint_connection_name = one([
    for connection in jsondecode(data.azapi_resource.lh_batch_storage_account_private_endpoint_connection.output).properties.privateEndpointConnections
    : connection.name
    if
    endswith(connection.properties.privateLinkServiceConnectionState.description, azurerm_data_factory_managed_private_endpoint.lh-store-pe.name)
  ])

}

resource "azapi_update_resource" "lh_approve_batch_storage_account_blob_private_endpoint_connection" {
  type      = "Microsoft.Storage/storageAccounts/privateEndpointConnections@2022-09-01"
  name      = local.lh_storage_account_blob_private_endpoint_connection_name
  parent_id = data.azurerm_storage_account.ws-sa.id

  body = jsonencode({
    properties = {
      privateLinkServiceConnectionState = {
        description = "Approved via NWSDE workspace - ${azurerm_data_factory_managed_private_endpoint.lh-store-pe.name}"
        status      = "Approved"
      }
    }
  })

  lifecycle {
    ignore_changes = all # We don't want to touch this after creation
  }
}

resource "azurerm_data_factory_linked_service_azure_blob_storage" "nwsde-lakehouse-storage-ls" {
  name              = format("%s-lakehouse-ws-storage-ls", var.tre_id)
  data_factory_id   = azurerm_data_factory.adf.id
  depends_on = [data.azurerm_storage_account.ws-sa, azurerm_data_factory.adf, azurerm_data_factory_integration_runtime_azure.int_runtime ]
  integration_runtime_name = "nwsde-ir"
  use_managed_identity = true
  service_endpoint = data.azurerm_storage_account.ws-sa.primary_blob_endpoint
  storage_kind = "StorageV2"
}

resource "azurerm_role_assignment" "adf-lakehouse-blob-contributor-role" {
  scope                 = data.azurerm_storage_account.ws-sa.id
  role_definition_name  = "Storage Blob Data Contributor"
  principal_id          = azurerm_data_factory.adf.identity[0].principal_id
  depends_on = [ azurerm_data_factory.adf, data.azurerm_storage_account.ws-sa ]
}
