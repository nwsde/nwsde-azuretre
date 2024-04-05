terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.73.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "=2.20.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "=1.5.0"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {
    key_vault {
      # Don't purge on destroy (this would fail due to purge protection being enabled on keyvault)
      purge_soft_delete_on_destroy               = false
      purge_soft_deleted_secrets_on_destroy      = false
      purge_soft_deleted_certificates_on_destroy = false
      purge_soft_deleted_keys_on_destroy         = false
      # When recreating an environment, recover any previously soft deleted secrets - set to true by default
      recover_soft_deleted_key_vaults   = true
      recover_soft_deleted_secrets      = true
      recover_soft_deleted_certificates = true
      recover_soft_deleted_keys         = true
    }
  }
}

provider "azuread" {
  client_id     = var.auth_client_id
  client_secret = var.auth_client_secret
  tenant_id     = var.auth_tenant_id
}

provider "azapi" {
}



# SCRATCHPLATE SPECIFIC
resource "azurerm_resource_group" "rg-mph-scratchplate" {
  name     = "rg-mph-scratchplate"
  location = var.location
}

data "azurerm_resource_group" "rg-nwsdedev" {
  name = "rg-nwsdedev"
}

data "azurerm_data_factory" "lakehouse-adf" {
  name = "lakehouse-ws-c7d9adf"
  resource_group_name = data.azurerm_resource_group.rg-nwsdedev.name
}

# LAKEHOUSE SPECIFIC

# data "azurerm_virtual_network" "vnet-nwsdedev" {
#   name                = "vnet-nwsdedev"
#   resource_group_name = data.azurerm_resource_group.rg-nwsdedev.name
# }

# data "azurerm_subnet" "shared" {
#   name                 = "SharedSubnet"
#   virtual_network_name = data.azurerm_virtual_network.vnet-nwsdedev.name
#   resource_group_name  = data.azurerm_virtual_network.vnet-nwsdedev.resource_group_name
# }

# resource "azurerm_data_factory" "adf" {
#   name                = "mph-nwsde-data-factory"
#   resource_group_name      = azurerm_resource_group.rg-mph-scratchplate.name
#   location                 = azurerm_resource_group.rg-mph-scratchplate.location
#   managed_virtual_network_enabled   = true
#   public_network_enabled = false
# }

# resource "azurerm_private_endpoint" "adf-pe" {
#   name                = "adf-pe"
#   resource_group_name = azurerm_resource_group.rg-mph-scratchplate.name
#   location            = azurerm_resource_group.rg-mph-scratchplate.location
#   subnet_id           = data.azurerm_subnet.shared.id

#   private_service_connection {
#     name                           = "nwsde-ir-connection"
#     private_connection_resource_id =  azurerm_data_factory.adf.id
#     is_manual_connection           = false
#     subresource_names = ["dataFactory"]
#   }
# }

# DO IN LAKEHOUSE WORKSPACE
resource "azurerm_storage_account" "nwsdestoragea" {
  name                     = "nwsdestoragea"
  resource_group_name      = azurerm_resource_group.rg-mph-scratchplate.name
  location                 = azurerm_resource_group.rg-mph-scratchplate.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  is_hns_enabled           = true
  depends_on = [azurerm_resource_group.rg-mph-scratchplate]
}

resource "azurerm_storage_container" "nwsde-con-a" {
  name                  = "goldplus"
  storage_account_name  = azurerm_storage_account.nwsdestoragea.name
}

resource "azurerm_data_factory_linked_service_azure_blob_storage" "nwsde-lakehouse-storage-ls" {
  name              = "test-lakehouse-storage-ls"
  data_factory_id   =  data.azurerm_data_factory.lakehouse-adf.id #azurerm_data_factory.adf.id
  #connection_string = azurerm_storage_account.nwsdestoragea.primary_connection_string
  depends_on = [azurerm_storage_account.nwsdestoragea, data.azurerm_data_factory.lakehouse-adf ]
  integration_runtime_name = "nwsde-ir"
  use_managed_identity = true
  service_endpoint = azurerm_storage_account.nwsdestoragea.primary_blob_endpoint
  storage_kind = "StorageV2"
}

# Dont need this in prod
resource "azurerm_storage_account" "nwsdestorageb" {
  name                     = "nwsdestorageb"
  resource_group_name      = azurerm_resource_group.rg-mph-scratchplate.name
  location                 = azurerm_resource_group.rg-mph-scratchplate.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  is_hns_enabled           = true
  depends_on = [azurerm_resource_group.rg-mph-scratchplate]
}

resource "azurerm_storage_share" "shared_storage" {
  name                 = "vm-shared-storage"
  storage_account_name = azurerm_storage_account.nwsdestorageb.name
  quota                = 1

  //depends_on = [
    //azurerm_private_endpoint.stgfilepe,
    //azurerm_storage_account_network_rules.stgrules
  //]
}

resource "azurerm_data_factory_linked_service_azure_file_storage" "fileshare" {
  name              = "test-fileshare-ls"
  data_factory_id   = data.azurerm_data_factory.lakehouse-adf.id
  depends_on = [azurerm_storage_account.nwsdestorageb, data.azurerm_data_factory.lakehouse-adf]
  integration_runtime_name = "nwsde-ir"
  connection_string = azurerm_storage_account.nwsdestorageb.primary_connection_string
  file_share = azurerm_storage_share.shared_storage.name
}

//resource "azurerm_data_factory_linked_service_azure_blob_storage" "ws-storage-linked-service" {
//  name              = format("%s_storage_ls", var.ws_id)
//  data_factory_id   = data.azurerm_data_factory.lakehouse-adf.id #azurerm_data_factory.adf.id
//  connection_string = azurerm_storage_account.nwsdestorageb.primary_connection_string
//  depends_on        = [azurerm_storage_account.nwsdestorageb, data.azurerm_data_factory.lakehouse-adf] #azurerm_data_factory.adf
//}

resource "azurerm_data_factory_dataset_azure_blob" "nwsde_dataset_a" {
  name                = format("%s_source_ds", var.ws_id)
  data_factory_id     = data.azurerm_data_factory.lakehouse-adf.id #CHANGE
  linked_service_name = azurerm_data_factory_linked_service_azure_blob_storage.nwsde-lakehouse-storage-ls.name #CHANGE
  path                = format("/goldplus/%s", var.ws_id)

}

resource "azurerm_data_factory_dataset_azure_blob" "nwsde_dataset_b" {
  name                = format("%s_sink_ds", var.ws_id)
  data_factory_id     = data.azurerm_data_factory.lakehouse-adf.id #CHANGE
  linked_service_name = azurerm_data_factory_linked_service_azure_file_storage.fileshare.name
  path                = format("%s", var.ws_id)
}

resource "azurerm_data_factory_pipeline" "ws_pipeline" {
  data_factory_id = data.azurerm_data_factory.lakehouse-adf.id #CHANGE
  name            = "ws-pipeline"
  depends_on = [ azurerm_data_factory_dataset_azure_blob.nwsde_dataset_a, azurerm_data_factory_dataset_azure_blob.nwsde_dataset_b ] #CHANGE

  activities_json = jsonencode([{
        "name": "${var.ws_id}-ws-pipe",
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
                "referenceName": "${var.ws_id}_source_ds",
                "type": "DatasetReference",
                "parameters": {
                    "FolderPath": "goldplus/${var.ws_id}"
                }
            }
        ],
        "outputs": [
            {
                "referenceName": "${var.ws_id}_sink_ds",
                "type": "DatasetReference",
                "parameters": {
                     "FolderPath": "${var.ws_id}"
                }
            }
        ]
    }])
}

resource "azurerm_data_factory_trigger_blob_event" "ws_pipeline_trigger" {
  name                = format("%s_%s", "ws_pipeline_trigger", var.ws_id)
  data_factory_id     = data.azurerm_data_factory.lakehouse-adf.id  #CHANGE
  storage_account_id  = azurerm_storage_account.nwsdestoragea.id #CHANGE
  events              = ["Microsoft.Storage.BlobCreated", "Microsoft.Storage.BlobDeleted"]
  blob_path_ends_with = ".zip"
  blob_path_begins_with = format("/goldplus/blobs/%s/", var.ws_id)
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

# resource "azurerm_data_factory_integration_runtime_azure" "ir_test" {
#   name            = "ir-adf-test"
#   data_factory_id = data.azurerm_data_factory.lakehouse-adf.id
#   location        = "AutoResolve"
#   depends_on = [ data.azurerm_data_factory.lakehouse-adf ]
#   virtual_network_enabled = true
# }


resource "azurerm_data_factory_managed_private_endpoint" "storeape" {
  name               = "sa-a-pe"
  data_factory_id    = data.azurerm_data_factory.lakehouse-adf.id
  target_resource_id = azurerm_storage_account.nwsdestoragea.id
  subresource_name   = "blob"
}

resource "azurerm_data_factory_managed_private_endpoint" "file_pe" {
  name               = "file-sa-pe"
  data_factory_id    = data.azurerm_data_factory.lakehouse-adf.id
  target_resource_id = azurerm_storage_account.nwsdestorageb.id
  subresource_name   = "file"
}


resource "azurerm_role_assignment" "blob-contributor-role" {
  scope                 = azurerm_storage_account.nwsdestoragea.id
  role_definition_name  = "Storage Blob Data Contributor"
  principal_id          = data.azurerm_data_factory.lakehouse-adf.identity[0].principal_id
  depends_on = [ data.azurerm_data_factory.lakehouse-adf, azurerm_storage_account.nwsdestoragea ]
}



# data "azapi_resource" "batch_storage_account_private_endpoint_connection" {
#   type                   = "Microsoft.Storage/storageAccounts@2022-09-01"
#   resource_id            = azurerm_storage_account.nwsdestoragea.id
#   response_export_values = ["properties.privateEndpointConnections."]

#   depends_on = [
#     azurerm_data_factory_managed_private_endpoint.storeape
#   ]
# }

# locals {

#   storage_account_blob_private_endpoint_connection_name = one([
#     for connection in jsondecode(data.azapi_resource.batch_storage_account_private_endpoint_connection.output).properties.privateEndpointConnections
#     : connection.name
#     if
#     endswith(connection.properties.privateLinkServiceConnectionState.description, azurerm_data_factory_managed_private_endpoint.storeape.name)
#   ])

# }

# resource "azapi_update_resource" "approve_batch_storage_account_blob_private_endpoint_connection" {
#   type      = "Microsoft.Storage/storageAccounts/privateEndpointConnections@2022-09-01"
#   name      = local.storage_account_blob_private_endpoint_connection_name
#   parent_id = azurerm_storage_account.nwsdestoragea.id

#   body = jsonencode({
#     properties = {
#       privateLinkServiceConnectionState = {
#         description = "Approved via NWSDE workspace - ${azurerm_data_factory_managed_private_endpoint.storeape.name}"
#         status      = "Approved"
#       }
#     }
#   })

#   lifecycle {
#     ignore_changes = all # We don't want to touch this after creation
#   }
# }
