resource "azurerm_role_assignment" "adf-research-blob-contributor-role" {
  scope                 = data.azurerm_storage_account.ws-sa.id
  role_definition_name  = "Storage Blob Data Contributor"
  principal_id          = data.azurerm_data_factory.lakehouse-adf.identity[0].principal_id
  depends_on = [ data.azurerm_data_factory.lakehouse-adf, data.azurerm_storage_account.ws-sa ]
}

resource "azurerm_data_factory_managed_private_endpoint" "ws-store-pe" {
  name               = format("%s-ws-pe", var.short_workspace_id)
  data_factory_id    = data.azurerm_data_factory.lakehouse-adf.id
  target_resource_id = data.azurerm_storage_account.ws-sa.id
  subresource_name   = "file"
  depends_on = [ data.azurerm_storage_account.ws-sa ]
}

data "azapi_resource" "batch_storage_account_private_endpoint_connection" {
  type                   = "Microsoft.Storage/storageAccounts@2022-09-01"
  resource_id            = data.azurerm_storage_account.ws-sa.id
  response_export_values = ["properties.privateEndpointConnections."]
  depends_on = [azurerm_data_factory_managed_private_endpoint.ws-store-pe]
}

locals {
  storage_account_file_private_endpoint_connection_name = one([
    for connection in jsondecode(data.azapi_resource.batch_storage_account_private_endpoint_connection.output).properties.privateEndpointConnections
    : connection.name
    if
    endswith(connection.properties.privateLinkServiceConnectionState.description, azurerm_data_factory_managed_private_endpoint.ws-store-pe.name)
  ])
}

resource "azapi_update_resource" "approve_batch_storage_account_file_private_endpoint_connection" {
  type      = "Microsoft.Storage/storageAccounts/privateEndpointConnections@2022-09-01"
  name      = local.storage_account_file_private_endpoint_connection_name
  parent_id = data.azurerm_storage_account.ws-sa.id

  body = jsonencode({
    properties = {
      privateLinkServiceConnectionState = {
        description = "Approved via NWSDE research workspace - ${azurerm_data_factory_managed_private_endpoint.ws-store-pe.name}"
        status      = "Approved"
      }
    }
  })

  lifecycle {
    ignore_changes = all
  }
}

/*
resource "azurerm_data_factory_linked_service_azure_blob_storage" "ws-storage-linked-service" {
  name              = format("%s_storage_ls", var.short_workspace_id)
  data_factory_id   = data.azurerm_data_factory.lakehouse-adf.id
  depends_on        = [data.azurerm_storage_account.ws-sa, data.azurerm_data_factory.lakehouse-adf , azurerm_data_factory_managed_private_endpoint.ws-store-pe  ]
  integration_runtime_name = local.adf_integration_runtime_name
  use_managed_identity = true
  service_endpoint = data.azurerm_storage_account.ws-sa.primary_blob_endpoint
  storage_kind = "StorageV2"
}
*/

resource "azurerm_data_factory_linked_service_azure_file_storage" "fileshare" {
  name              = format("%s_storage_ls", var.short_workspace_id)
  data_factory_id   = data.azurerm_data_factory.lakehouse-adf.id
  depends_on = [data.azurerm_storage_account.ws-sa, data.azurerm_data_factory.lakehouse-adf, azurerm_data_factory_managed_private_endpoint.ws-store-pe]
  integration_runtime_name = local.adf_integration_runtime_name
  connection_string = data.azurerm_storage_account.ws-sa.primary_connection_string
  file_share = local.workspace_sa_file_share_name
}

resource "azurerm_data_factory_dataset_azure_blob" "nwsde_dataset_source" {
  name                = format("%s_source_ds", var.short_workspace_id)
  data_factory_id     = data.azurerm_data_factory.lakehouse-adf.id
  linked_service_name = local.adf_lakehouse_storage_ls_name
  path                = format("/goldplus/%s", var.research_project_id)
}

resource "azurerm_data_factory_dataset_azure_blob" "nwsde_dataset_sink" {
  name                = format("%s_sink_ds", var.short_workspace_id)
  data_factory_id     = data.azurerm_data_factory.lakehouse-adf.id
  linked_service_name = azurerm_data_factory_linked_service_azure_file_storage.fileshare.name
  path                = var.research_project_id
}

resource "azurerm_data_factory_pipeline" "ws_pipeline" {
  data_factory_id = data.azurerm_data_factory.lakehouse-adf.id
  name            =  format("%s_ws_pipeline", var.short_workspace_id)
  depends_on = [ azurerm_data_factory_dataset_azure_blob.nwsde_dataset_source, azurerm_data_factory_dataset_azure_blob.nwsde_dataset_sink ]

  activities_json = jsonencode([{
        "name": "${var.short_workspace_id}-ws-pipe",
        "description": "",
        "type": "Copy",
        "dependsOn": [],
        "policy": {
            "timeout": "7.00:00:00",
            "retry": 0,
            "retryIntervalInSeconds": 30,
            "secureOutput": false,
            "secureInput": false
        },
        "userProperties": [],
        "typeProperties": {
            "source": {
                "type": "BlobSource",
                "storeSettings": {
                    "type": "AzureBlobStorageReadSettings",
                    "recursive": true
                }
            },
            "sink": {
                "type": "FileSystemSink",
                "storeSettings": {
                    "type": "AzureBlobStorageReadSettings"
                }
            },
            "enableStaging": false
        },
        "inputs": [
            {
                "referenceName": "${var.short_workspace_id}_source_ds",
                "type": "DatasetReference",
                "parameters": {
                    "FolderPath": "goldplus/${var.research_project_id}"
                }
            }
        ],
        "outputs": [
            {
                "referenceName": "${var.short_workspace_id}_sink_ds",
                "type": "DatasetReference",
                "parameters": {
                     "FolderPath": "${var.research_project_id}"
                }
            }
        ]
    }])
}

resource "azurerm_data_factory_trigger_blob_event" "ws_pipeline_trigger" {
  name                = format("%s_%s", "ws_pipeline_trigger", var.short_workspace_id)
  data_factory_id     = data.azurerm_data_factory.lakehouse-adf.id
  storage_account_id  = data.azurerm_storage_account.lakehouse-sa.id
  events              = ["Microsoft.Storage.BlobCreated", "Microsoft.Storage.BlobDeleted"]
  blob_path_ends_with = ".zip"
  blob_path_begins_with = format("/goldplus/blobs/%s/", var.research_project_id)
  ignore_empty_blobs  = true
  activated           = true
  depends_on = [ azurerm_data_factory_pipeline.ws_pipeline ]
  description = "Research WS pipeline trigger"

  pipeline {
    name = azurerm_data_factory_pipeline.ws_pipeline.name
     parameters = {
      Env = "Prod"
    }
  }
}
