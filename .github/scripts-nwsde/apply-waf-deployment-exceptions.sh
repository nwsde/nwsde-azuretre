#!/bin/bash

function main() {

  local ACTION=$1
  local TRE_ID=$2

  if [[ $ACTION != "ENABLE" && $ACTION != "DISABLE" ]]; then
    echo "ENABLE or DISABLE action not received, cannot continue"
    echo "Usage: $0 <ENABLE|DISABLE> <tre_id>"
    exit 1
  fi

  if [[ -z "$TRE_ID" ]]; then
    echo "TRE_ID not defined, cannot continue"
    echo "Usage: $0 <ENABLE|DISABLE> <tre_id>"
    exit 2
  fi

  local ACTION_VERB="Enabling"
  local ACTION_ADJECTIVE="Enabled"

  if [[ $ACTION == "DISABLE" ]]; then
    ACTION_VERB="Disabling"
    ACTION_ADJECTIVE="Disabled"
  fi

  local RG="rg-${TRE_ID}"

  local RG_EXISTS
  RG_EXISTS=$(az group list --query "[?name=='$RG'].id" --output tsv)

  if [[ -z $RG_EXISTS ]]; then
    echo "Resource group $RG does not exist, exiting..."
    exit 0
  fi

  local WAF_POLICY="wafpolicy-${TRE_ID}"
  local RULES=("DEPLOYMENTRUNNER" "CERTBOT")

  echo "$ACTION_VERB deployment exceptions on WAF..."

  for RULE in "${RULES[@]}"; do

    echo " $ACTION_VERB custom rule $RULE on $WAF_POLICY"

    az network application-gateway waf-policy custom-rule update \
      --resource-group "$RG" \
      --policy-name "$WAF_POLICY" \
      --state "$ACTION_ADJECTIVE" \
      --name "$RULE" \
      --output none

  done

  echo -e "\n Listing custom rules on wafpolicy-${TRE_ID}...\n"

  az network application-gateway waf-policy custom-rule list \
    --resource-group "$RG" \
    --policy-name "$WAF_POLICY" \
    --output table
}

main "$@"
