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
