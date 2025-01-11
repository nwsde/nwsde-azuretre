output "azuresql_fqdn" {
  value = azurerm_mssql_server.azuresql.fully_qualified_domain_name
}

output "workspace_address_spaces" {
  value = data.azurerm_virtual_network.ws.address_space
}

output "rg_name" {
  value = data.azurerm_resource_group.ws.name
}

output "server_name" {
  value = azurerm_mssql_server.azuresql.name
}

output "server_ip" {
  value = azurerm_private_endpoint.azuresql_private_endpoint.private_service_connection[0].private_ip_address
}

output "database_name" {
  value = azurerm_mssql_database.azuresqldatabase.name
}

output "entra_sql_users_group" {
  value = data.azuread_group.sql_users.display_name
}

output "entra_sql_admins_group" {
  value = data.azuread_group.sql_admins.display_name
}

output "cloud_admin_user" {
  value = azurerm_mssql_server.azuresql.administrator_login
}
