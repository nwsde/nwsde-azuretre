#
# data
#

data "azuread_client_config" "current" {
}

data "azuread_group" "sql_admins" {
  display_name     = local.entra_group_sql_admins
}

data "azuread_group" "sql_users" {
  display_name     = local.entra_group_sql_users
}

#
# resources
#

resource "azuread_group_member" "sql_admin_required_member" {
  group_object_id  = data.azuread_group.sql_admins.object_id
  member_object_id = data.azuread_client_config.current.object_id
}
