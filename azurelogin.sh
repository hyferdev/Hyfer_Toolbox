#!/usr/bin/bash
#Azure Login
az login
if [ $? -ne 0 ]; then
  echo "Azure login failed. Exiting script."
  exit 1
fi
echo "Azure login successful."

#Add service principal for terraform to use
az account set --subscription "Backups"
subscription_id=$(az account show | jq -r '.id')
if [ -z "$subscription_id" ]; then
  echo "Subscription ID not found. Exiting script."
  exit 1
fi
echo "Azure Subscription ID: $subscription_id"
serviceprincipal=$(az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/$subscription_id")
export ARM_CLIENT_ID=$(echo "$serviceprincipal" | jq -r '.appId') 
export ARM_CLIENT_SECRET=$(echo "$serviceprincipal" | jq -r '.password')
export ARM_TENANT_ID=$(echo "$serviceprincipal" | jq -r '.tenant')
export ARM_SUBSCRIPTION_ID=$subscription_id
echo "ARM_CLIENT_ID: $ARM_CLIENT_ID"
echo "ARM_CLIENT_SECRET: $ARM_CLIENT_SECRET"
echo "ARM_SUBSCRIPTION_ID: $ARM_SUBSCRIPTION_ID"
echo "ARM_TENANT_ID: $ARM_TENANT_ID"

#Register Microsoft.ServiceBus
#az provider register --namespace Microsoft.ServiceBus
#while true; do
#  output=$(az provider show -n Microsoft.ServiceBus | grep -i registrationstate)
#  if [[ "$output" == *"Registered"* ]]; then
#    echo "Microsoft.ServiceBus provider is registered."
#    break
#  else
#    echo "Microsoft.ServiceBus provider is not yet registered. Waiting..."
#    sleep 10
#  fi
#done
