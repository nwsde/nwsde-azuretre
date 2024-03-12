resource "azurerm_data_factory_linked_service_azure_blob_storage" "nwsde-lakehouse-storage-ls" {
  name              = format("%s-lakehouse-ws-storage-ls", var.tre_id)
  data_factory_id   = data.azurerm_data_factory.lakehouse-adf.id
  connection_string = data.azurerm_storage_account.lakehouse-sa.primary_connection_string  #azurerm_storage_account.nwsdestoragea.primary_connection_string
  depends_on = [data.azurerm_storage_account.lakehouse-sa, data.azurerm_data_factory.lakehouse-adf]
}

# Dont need this in prod
# resource "azurerm_storage_account" "nwsdestorageb" {
#   name                     = "nwsdestorageb"
#   resource_group_name      = azurerm_resource_group.rg-mph-scratchplate.name
#   location                 = azurerm_resource_group.rg-mph-scratchplate.location
#   account_tier             = "Standard"
#   account_replication_type = "GRS"
#   is_hns_enabled           = true
#   depends_on = [azurerm_resource_group.rg-mph-scratchplate]
# }



resource "azurerm_data_factory_linked_service_azure_blob_storage" "ws-storage-linked-service" {
  name              = format("%s_storage_ls", var.short_workspace_id)
  data_factory_id   = data.azurerm_data_factory.lakehouse-adf.id
  connection_string = data.azurerm_storage_account.ws-sa.primary_connection_string
  depends_on        = [data.azurerm_storage_account.ws-sa, data.azurerm_data_factory.lakehouse-adf]
}

resource "azurerm_data_factory_dataset_azure_blob" "nwsde_dataset_a" {
  name                = format("%s_source_ds", var.short_workspace_id)
  data_factory_id     = data.azurerm_data_factory.lakehouse-adf.id
  linked_service_name = azurerm_data_factory_linked_service_azure_blob_storage.nwsde-lakehouse-storage-ls.name
  path                = format("/goldplus/%s", var.short_workspace_id)

}

resource "azurerm_data_factory_dataset_azure_blob" "nwsde_dataset_b" {
  name                = format("%s_sink_ds", var.short_workspace_id)
  data_factory_id     = data.azurerm_data_factory.lakehouse-adf.id
  linked_service_name = azurerm_data_factory_linked_service_azure_blob_storage.ws-storage-linked-service.name
  path                = var.short_workspace_id
}

resource "azurerm_data_factory_pipeline" "ws_pipeline" {
  data_factory_id = data.azurerm_data_factory.lakehouse-adf.id #CHANGE
  name            =  format("%s_ws_pipeline", var.short_workspace_id)
  depends_on = [ azurerm_data_factory_dataset_azure_blob.nwsde_dataset_a, azurerm_data_factory_dataset_azure_blob.nwsde_dataset_b ] #CHANGE

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
                "type": "BlobSink",
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
                    "FolderPath": "goldplus/${var.short_workspace_id}"
                }
            }
        ],
        "outputs": [
            {
                "referenceName": "${var.short_workspace_id}_sink_ds",
                "type": "DatasetReference",
                "parameters": {
                     "FolderPath": "${var.short_workspace_id}"
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
  blob_path_begins_with = format("/goldplus/blobs/%s/", var.short_workspace_id)
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
