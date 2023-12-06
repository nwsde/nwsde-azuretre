#!/bin/bash

#
# Work in progress - needs testing & integrating with devops/scripts/control_tre.sh
#

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

if [[ -z ${TRE_ID:-} ]]; then
    echo "TRE_ID environment variable must be set."
    exit 1
fi

core_rg_name="rg-${TRE_ID}"
sku_when_running="P1v2"
sku_when_stopped="B1"

# Check TRE exists
#
if [[ $(az group list --output json --query "[?name=='${core_rg_name}'] | length(@)") == 0 ]]; then
  echo "TRE resource group doesn't exist. Exiting..."
  exit 0
fi

az config set extension.use_dynamic_install=yes_without_prompt


# Changing diagnostic settings log category enablement (as tied to premium app service plan SKU)
#
change_diag_log_enablement_AppServiceFileAuditLogs() {

  enabled=$1

  echo
  echo "Changing diagnostic settings log category AppServiceFileAuditLogs to ${enabled}..."

  webapps=$(az webapp list --output tsv --resource-group "${core_rg_name}" --query "[].id")
  for webapp_id in ${webapps}; do

    diag_name=$(az monitor diagnostic-settings list --output tsv --resource "${webapp_id}" --query "[].name")
    echo "  Changing AppServiceFileAuditLogs diagnostic settings log category on resource ${diag_name} to ${enabled}"

    log_settings_json=$(az monitor diagnostic-settings show --output json --resource "${webapp_id}" --name "${diag_name}" --query "logs")
    mutated_log_settings_json=$(echo "${log_settings_json}" | jq "(.[] | select (.category==\"AppServiceFileAuditLogs\")).enabled = ${enabled}")

    az monitor diagnostic-settings update --resource "${webapp_id}" --name "${diag_name}" --output none --logs <(printf "%s" "${mutated_log_settings_json}")
  done

}

change_diag_log_enablement_AppServiceFileAuditLogs false


# Change app service plans to B1
#

change_appservice_plan_skus() {
  from_sku=$1
  to_sku=$2

  echo
  echo "Changing app service plans from ${from_sku} to ${to_sku}..."

  appserviceplans=$(az appservice plan list --output tsv --resource-group "${core_rg_name}" --query "[].name")

  for appserviceplan_name in ${appserviceplans}; do

    existing_sku=$(az appservice plan show --resource-group rg-nwtredev --name plan-airlock-nwtredev --query "sku.name")

    if [[ ${existing_sku} == "\"${from_sku}\"" ]]; then
      echo "  Changing ${appserviceplan_name} from ${from_sku} to ${to_sku}"

      az appservice plan update --output none --resource-group "${core_rg_name}" --name "${appserviceplan_name}" --sku "${to_sku}"
    elif [[ ${existing_sku} == "\"${to_sku}\"" ]]; then
      echo "  ${appserviceplan_name} is already at SKU ${existing_sku}"
    else
      echo "  Not changing ${appserviceplan_name} as not at expected SKU of ${from_sku}"
    fi

  done
}

change_appservice_plan_skus ${sku_when_running} ${sku_when_stopped}
