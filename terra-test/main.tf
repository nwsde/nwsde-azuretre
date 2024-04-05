terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.40.0" //3.40.0
    }
    azapi = {
      source  = "Azure/azapi"
      version = "=1.1.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "=1.37.1"
    }
    dns = {
      source  = "hashicorp/dns"
      version = "=3.2.3"
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

provider "azapi" {
}


module "azure_region" {
  source  = "claranet/regions/azurerm"
  version = "=6.1.0"
  azure_region = "uksouth"
}

provider "dns" {
}

module "terraform_azurerm_environment_configuration" {
  source          = "git::https://github.com/microsoft/terraform-azurerm-environment-configuration.git?ref=0.2.0"
  arm_environment = "public"
}


provider "databricks" {
  alias      = "account"
  host       = "accounts.azuredatabricks.net"
  account_id = "e1a4f1fa-4ba6-4b03-968f-02d05c5780c4"
  auth_type  = "azure-cli"
}

data "databricks_metastores" "all" {
  provider = databricks.account
}

output "all_metastores" {
  value = data.databricks_metastores.all.ids
}

//resource "databricks_user" "account_user" {
//  provider     = databricks.account
//  user_name    = "terraformtest@example.com"
//  display_name = "terraform test user"
//}


