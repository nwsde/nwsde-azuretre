#
# data
#

data "azurerm_log_analytics_workspace" "la" {
  name                = local.workspace_log_analytics_name
  resource_group_name = local.workspace_resource_group_name
}


#
# resources
#

// storage to store audits
//
resource "azurerm_storage_account" "stgaudit" {
  name                              = local.storage_account_name
  resource_group_name               = data.azurerm_resource_group.ws.name
  location                          = data.azurerm_resource_group.ws.location
  account_tier                      = "Standard"
  account_replication_type          = "ZRS"
  allow_nested_items_to_be_public   = false
  cross_tenant_replication_enabled  = false
  shared_access_key_enabled         = false
  local_user_enabled                = false
  infrastructure_encryption_enabled = true
  tags                              = local.workspace_service_tags

  lifecycle { ignore_changes = [tags] }
}

// outbound sql server firewall rule
//
resource "azurerm_mssql_outbound_firewall_rule" "azuresqlfwrule" {
  name      = azurerm_storage_account.stgaudit.primary_blob_host
  server_id = azurerm_mssql_server.azuresql.id
}

// RBAC role for storage account
//
resource "azurerm_role_assignment" "azuresqlstoragerole" {
  scope                = azurerm_storage_account.stgaudit.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_user_assigned_identity.sql_identity.principal_id
}

// server level auditing
//
resource "azurerm_mssql_server_extended_auditing_policy" "azuresqlaudit" {
  server_id              = azurerm_mssql_server.azuresql.id
  storage_endpoint       = azurerm_storage_account.stgaudit.primary_blob_endpoint
  retention_in_days      = 0
  log_monitoring_enabled = true

  depends_on = [
    azurerm_role_assignment.azuresqlstoragerole,
    azurerm_mssql_outbound_firewall_rule.azuresqlfwrule
  ]
}

// server level diagnostic setting (for log analytics)
//
resource "azurerm_monitor_diagnostic_setting" "azuresqldiagnosticsetting" {
  name                       = local.azuresql_server_diagnostic_setting_name
  target_resource_id         = "${azurerm_mssql_server.azuresql.id}/databases/master"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.la.id

  enabled_log {
    category = "SQLSecurityAuditEvents"
  }

  lifecycle {
    ignore_changes = [metric]
  }

  depends_on = [
    azurerm_mssql_server.azuresql,
    azurerm_mssql_database.azuresqldatabase, // https://github.com/hashicorp/terraform-provider-azurerm/issues/22226#issuecomment-2464486997
    azurerm_mssql_server_extended_auditing_policy.azuresqlaudit
  ]
}

// server level auditing of microsoft support
//
resource "azurerm_mssql_server_microsoft_support_auditing_policy" "azuresqlaudit2" {
  server_id              = azurerm_mssql_server.azuresql.id
  blob_storage_endpoint  = azurerm_storage_account.stgaudit.primary_blob_endpoint
  log_monitoring_enabled = true

  depends_on = [
    azurerm_role_assignment.azuresqlstoragerole,
    azurerm_mssql_outbound_firewall_rule.azuresqlfwrule
  ]
}

// server level (microsoft support) diagnostic setting (for log analytics)
//
resource "azurerm_monitor_diagnostic_setting" "azuresqldiagnosticsetting2" {
  name                       = local.azuresql_server_diagnostic_setting_name_2
  target_resource_id         = "${azurerm_mssql_server.azuresql.id}/databases/master"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.la.id

  enabled_log {
    category = "DevOpsOperationsAudit"
  }

  lifecycle {
    ignore_changes = [metric]
  }

  depends_on = [
    azurerm_mssql_server.azuresql,
    azurerm_mssql_database.azuresqldatabase, // https://github.com/hashicorp/terraform-provider-azurerm/issues/22226#issuecomment-2464486997
    azurerm_mssql_server_microsoft_support_auditing_policy.azuresqlaudit2
  ]
}

// database level auditing
//
resource "azurerm_mssql_database_extended_auditing_policy" "azuresqldbaudit" {
  database_id            = azurerm_mssql_database.azuresqldatabase.id
  storage_endpoint       = azurerm_storage_account.stgaudit.primary_blob_endpoint
  retention_in_days      = 0
  log_monitoring_enabled = true

  depends_on = [
    azurerm_role_assignment.azuresqlstoragerole,
    azurerm_mssql_outbound_firewall_rule.azuresqlfwrule
  ]
}

// database level diagnostic setting (for log analytics)
//
resource "azurerm_monitor_diagnostic_setting" "sql_audit3" {
  name                       = local.azuresql_database_diagnostic_setting_name
  target_resource_id         = azurerm_mssql_database.azuresqldatabase.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.la.id

  enabled_log {
    category = "SQLSecurityAuditEvents"
  }

  lifecycle {
    ignore_changes = [metric]
  }

  depends_on = [
    azurerm_mssql_database.azuresqldatabase,
    azurerm_mssql_database_extended_auditing_policy.azuresqldbaudit
  ]
}
