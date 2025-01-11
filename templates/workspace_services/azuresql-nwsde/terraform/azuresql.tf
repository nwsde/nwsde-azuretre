#
# data
#

data "azurerm_resource_group" "ws" {
  name = local.workspace_resource_group_name
}

data "azurerm_virtual_network" "ws" {
  name                = local.workspace_vnet_name
  resource_group_name = data.azurerm_resource_group.ws.name
}

data "azurerm_subnet" "services" {
  name                 = "ServicesSubnet"
  virtual_network_name = data.azurerm_virtual_network.ws.name
  resource_group_name  = data.azurerm_resource_group.ws.name
}

data "azurerm_private_dns_zone" "azuresql" {
  name                = module.terraform_azurerm_environment_configuration.private_links["privatelink.database.windows.net"]
  resource_group_name = local.core_resource_group_name
}

data "azurerm_user_assigned_identity" "sql_identity" {
  name                = local.azuresql_identity_parsed["resource_name"]
  resource_group_name = local.azuresql_identity_parsed["resource_group_name"]
}


#
# resources
#

resource "azurerm_mssql_server" "azuresql" {
  name                                 = local.azuresql_server_name
  resource_group_name                  = data.azurerm_resource_group.ws.name
  location                             = data.azurerm_resource_group.ws.location
  version                              = "12.0"
  minimum_tls_version                  = "1.2"
  public_network_access_enabled        = false
  outbound_network_restriction_enabled = true
  tags                                 = local.workspace_service_tags

  azuread_administrator {
    azuread_authentication_only = true
    login_username              = data.azuread_group.sql_admins.display_name
    object_id                   = data.azuread_group.sql_admins.object_id
    tenant_id                   = data.azurerm_client_config.current.tenant_id
  }

  identity {
    type         = "UserAssigned"

    identity_ids = [ data.azurerm_user_assigned_identity.sql_identity.id ]
  }

  primary_user_assigned_identity_id = data.azurerm_user_assigned_identity.sql_identity.id

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_mssql_database" "azuresqldatabase" {
  name         = local.azuresql_database_name
  server_id    = azurerm_mssql_server.azuresql.id
  collation    = local.azuresql_collation
  license_type = "LicenseIncluded"
  max_size_gb  = var.storage_gb
  sku_name     = local.azuresql_sku[var.sql_sku].value
  tags         = local.workspace_service_tags

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_private_endpoint" "azuresql_private_endpoint" {
  name                = local.azuresql_private_endpoint_name
  location            = data.azurerm_resource_group.ws.location
  resource_group_name = data.azurerm_resource_group.ws.name
  subnet_id           = data.azurerm_subnet.services.id
  tags                = local.workspace_service_tags

  private_service_connection {
    private_connection_resource_id = azurerm_mssql_server.azuresql.id
    name                           = local.azuresql_private_service_connection_name
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = module.terraform_azurerm_environment_configuration.private_links["privatelink.database.windows.net"]
    private_dns_zone_ids = [data.azurerm_private_dns_zone.azuresql.id]
  }

  lifecycle { ignore_changes = [tags] }
}
