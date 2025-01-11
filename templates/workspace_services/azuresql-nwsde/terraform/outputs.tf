output "azuresql_fqdn" {
  value = azurerm_mssql_server.azuresql.fully_qualified_domain_name
}

output "workspace_address_spaces" {
  value = data.azurerm_virtual_network.ws.address_space
}
