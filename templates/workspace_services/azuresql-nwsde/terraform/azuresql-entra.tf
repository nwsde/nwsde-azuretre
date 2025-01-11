#
# data
#

data "azurerm_client_config" "current" {
}

data "azuread_group" "sql_admins" {
  display_name     = local.entra_group_sql_admins
}

data "azuread_group" "sql_users" {
  display_name     = local.entra_group_sql_users
}

data "template_file" "grant_access" {
  template = file("${path.module}/scripts/azuresql-add-user.sh")

  vars = {
    server_ip                       = azurerm_private_endpoint.azuresql_private_endpoint.private_service_connection[0].private_ip_address  # use ip address to work around dns propagation issues
    server_fqdn                     = azurerm_mssql_server.azuresql.fully_qualified_domain_name
    server_name                     = azurerm_mssql_server.azuresql.name
    sp_client_id                    = data.azurerm_client_config.current.client_id
    database_name                   = azurerm_mssql_database.azuresqldatabase.name
    add_database_user_script        = "${path.module}/scripts/add-database-user.sql"
    add_database_permissions_script = "${path.module}/scripts/add-database-permissions.sql"
    user_to_add                     = data.azuread_group.sql_users.display_name
  }
}

#
# resources
#

resource "azuread_group_member" "sql_admin_required_member" {
  count = contains(data.azuread_group.sql_admins.members, data.azurerm_client_config.current.object_id) ? 0 : 1

  group_object_id  = data.azuread_group.sql_admins.object_id
  member_object_id = data.azurerm_client_config.current.object_id
}

resource "null_resource" "grant_user_access" {
  triggers = {
    database_id     = azurerm_mssql_database.azuresqldatabase.id
    database_name   = azurerm_mssql_database.azuresqldatabase.name
    group_id        = data.azuread_group.sql_users.object_id
    group_name      = data.azuread_group.sql_users.display_name
    sql_admin       = data.azurerm_client_config.current.object_id
  }

  provisioner "local-exec" {
    command     = data.template_file.grant_access.rendered
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [
    azurerm_private_endpoint.azuresql_private_endpoint,
    azuread_group_member.sql_admin_required_member,
    azurerm_mssql_server_extended_auditing_policy.azuresqlaudit,
    azurerm_mssql_database_extended_auditing_policy.azuresqldbaudit
  ]
}
