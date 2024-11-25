#!/bin/bash

# Load values from infra_config.env
CONFIG_FILE="$(dirname "$0")/infra_config.env"
if [ -f "$CONFIG_FILE" ]; then
  echo "Loading configuration from $CONFIG_FILE..."
  source "$CONFIG_FILE"
else
  echo "Configuration file $CONFIG_FILE not found!"
  exit 1
fi

echo -e "\nSetting subscription context to $SUBSCRIPTION_ID..."
az account set --subscription "$SUBSCRIPTION_ID"
if [ $? -ne 0 ]; then
  echo "Failed to set subscription context."
  exit 1
fi
echo "Subscription context set successfully."

# Delete Function App
echo -e "\nDeleting Function App: $FUNCTION_APP_NAME..."
az functionapp delete \
  --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME"
if [ $? -ne 0 ]; then
  echo "Failed to delete Function App: $FUNCTION_APP_NAME."
  exit 1
fi
echo "Function App $FUNCTION_APP_NAME deleted successfully."

# Delete Application Insights
echo -e "\nDeleting Application Insights: $APP_INSIGHTS_NAME..."
az monitor app-insights component delete \
  --app "$APP_INSIGHTS_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME"
if [ $? -ne 0 ]; then
  echo "Failed to delete Application Insights: $APP_INSIGHTS_NAME."
  exit 1
fi
echo "Application Insights $APP_INSIGHTS_NAME deleted successfully."

# Delete Blob Container
echo -e "\nDeleting Blob Container: $BLOB_CONTAINER_NAME..."
az storage container delete \
  --name "$BLOB_CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT_NAME"
if [ $? -ne 0 ]; then
  echo "Failed to delete Blob Container: $BLOB_CONTAINER_NAME."
  exit 1
fi
echo "Blob Container $BLOB_CONTAINER_NAME deleted successfully."

# Delete Storage Account
echo -e "\nDeleting Storage Account: $STORAGE_ACCOUNT_NAME..."
az storage account delete \
  --name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --yes
if [ $? -ne 0 ]; then
  echo "Failed to delete Storage Account: $STORAGE_ACCOUNT_NAME."
  exit 1
fi
echo "Storage Account $STORAGE_ACCOUNT_NAME deleted successfully."

# Delete App Service Plan
echo -e "\nDeleting App Service Plan: $SERVICE_PLAN_NAME..."
az appservice plan delete \
  --name "$SERVICE_PLAN_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --yes
if [ $? -ne 0 ]; then
  echo "Failed to delete App Service Plan: $SERVICE_PLAN_NAME."
  exit 1
fi
echo "App Service Plan $SERVICE_PLAN_NAME deleted successfully."

# Delete Resource Group
echo -e "\nDeleting Resource Group: $RESOURCE_GROUP_NAME..."
az group delete \
  --name "$RESOURCE_GROUP_NAME" \
  --yes \
  --no-wait
if [ $? -ne 0 ]; then
  echo "Failed to delete Resource Group: $RESOURCE_GROUP_NAME."
  exit 1
fi
echo "Resource Group $RESOURCE_GROUP_NAME deletion initiated successfully."

echo -e "\n\n - - - - | ALL RESOURCES WERE SUCCESSFULLY DELETED | - - - - \n\n"
