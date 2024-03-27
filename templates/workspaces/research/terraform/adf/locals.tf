locals {
  core_vnet                      = "vnet-${var.tre_id}"
  short_workspace_id             = substr(var.tre_resource_id, -4, -1)

  lakehouse_adf_name             = "lakehouse-ws-c7d9adf"
  adf_integration_runtime_name   = "nwsde-ir"
  adf_lakehouse_storage_ls_name       = "nwsdedev-lakehouse-ws-storage-ls"
  core_resource_group_name       = "rg-${var.tre_id}"

  lakehouse_sa_name              = "stgwsc7d9"
  lakehouse_ws_rg_name           = "rg-nwsdedev-ws-c7d9" #rg-nwsdedev-ws-lakehouse

  workspace_sa_name              = "stgws${var.short_workspace_id}"
 }
