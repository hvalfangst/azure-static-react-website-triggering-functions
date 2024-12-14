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

# Create the resource group
echo -e "\nCreating resource group: $RESOURCE_GROUP_NAME in location $LOCATION..."
az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION"
if [ $? -ne 0 ]; then
  echo "Failed to create resource group: $RESOURCE_GROUP_NAME."
  exit 1
fi
echo "Resource group $RESOURCE_GROUP_NAME created successfully."

# Create the Storage Account
echo -e "\nCreating Storage Account: $STORAGE_ACCOUNT_NAME..."
az storage account create --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --location "$LOCATION" --sku Standard_LRS
if [ $? -ne 0 ]; then
  echo "Failed to create Storage Account: $STORAGE_ACCOUNT_NAME."
  exit 1
fi
echo "Storage Account $STORAGE_ACCOUNT_NAME created successfully."

# Retrieve the Storage Account connection string
echo -e "\nRetrieving connection string for Storage Account: $STORAGE_ACCOUNT_NAME..."
STORAGE_CONNECTION_STRING=$(az storage account show-connection-string --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query "connectionString" -o tsv)
if [ $? -ne 0 ]; then
  echo "Failed to retrieve connection string for Storage Account: $STORAGE_ACCOUNT_NAME."
  exit 1
fi

# Create the Blob Container
echo -e "\nCreating Blob Container: $BLOB_CONTAINER_NAME..."
az storage container create --name "$BLOB_CONTAINER_NAME" --connection-string "$STORAGE_CONNECTION_STRING"
if [ $? -ne 0 ]; then
  echo "Failed to create Blob Container: $BLOB_CONTAINER_NAME."
  exit 1
fi
echo "Blob Container $BLOB_CONTAINER_NAME created successfully."


# Create an App Service Plan
echo -e "\nCreating App Service Plan: $SERVICE_PLAN_NAME..."
az appservice plan create \
  --name "$SERVICE_PLAN_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --location "$LOCATION" \
  --sku S1 \
  --is-linux
if [ $? -ne 0 ]; then
  echo "Failed to create App Service Plan: $SERVICE_PLAN_NAME."
  exit 1
fi
echo "App Service Plan $SERVICE_PLAN_NAME created successfully."


# Enable dynamic installation of extensions without prompting the user.
echo -e "\nConfiguring Azure CLI to allow dynamic installation of extensions..."
az config set extension.use_dynamic_install=yes_without_prompt
if [ $? -ne 0 ]; then
  echo "Failed to configure Azure CLI for dynamic extension installation."
  exit 1
fi
echo "Azure CLI configured successfully for dynamic extension installation."

# Ensure the Application Insights extension is installed.
echo -e "\nInstalling Application Insights extension if not already installed..."
az extension add --name application-insights 2>/dev/null
if [ $? -ne 0 ]; then
  echo "Failed to add the Application Insights extension. It might already be installed."
else
  echo "Application Insights extension installed successfully."
fi

# Verify that the Application Insights extension is installed.
echo -e "\nVerifying Application Insights extension installation..."
az extension show --name application-insights >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Application Insights extension is not installed or failed to load."
  exit 1
fi
echo "Application Insights extension is verified as installed."

# Create an Application Insights resource
echo -e "\nCreating Application Insights: $APP_INSIGHTS_NAME..."
az monitor app-insights component create \
  --app "$APP_INSIGHTS_NAME" \
  --location "$LOCATION" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --application-type "web"
if [ $? -ne 0 ]; then
  echo "Failed to create Application Insights: $APP_INSIGHTS_NAME."
  exit 1
fi
echo "Application Insights $APP_INSIGHTS_NAME created successfully."

# Retrieve Storage Account Key
echo -e "\nRetrieving storage account key for $STORAGE_ACCOUNT_NAME..."
STORAGE_ACCOUNT_KEY=$(az storage account keys list \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --query "[0].value" -o tsv)
if [ $? -ne 0 ]; then
  echo "Failed to retrieve storage account key for $STORAGE_ACCOUNT_NAME."
  exit 1
fi
echo "Storage account key retrieved successfully."

# Retrieve Application Insights Keys
echo -e "\nRetrieving Application Insights keys for $APP_INSIGHTS_NAME..."
APP_INSIGHTS_KEY=$(az monitor app-insights component show \
  --app "$APP_INSIGHTS_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --query "instrumentationKey" -o tsv)
if [ $? -ne 0 ]; then
  echo "Failed to retrieve Application Insights key."
  exit 1
fi

# Create a Function App
echo -e "\nCreating Function App: $FUNCTION_APP_NAME..."
az functionapp create \
  --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --storage-account "$STORAGE_ACCOUNT_NAME" \
  --plan "$SERVICE_PLAN_NAME" \
  --runtime python \
  --runtime-version 3.10 \
  --os-type Linux
if [ $? -ne 0 ]; then
  echo "Failed to create Function App: $FUNCTION_APP_NAME."
  exit 1
fi
echo "Function App $FUNCTION_APP_NAME created successfully."

# Set Application Settings for Function App
echo -e "\nConfiguring application settings for $FUNCTION_APP_NAME..."
az functionapp config appsettings set \
  --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --settings \
  "APPINSIGHTS_INSTRUMENTATIONKEY=$APP_INSIGHTS_KEY" \
  "AzureWebJobsFeatureFlags=EnableWorkerIndexing"
if [ $? -ne 0 ]; then
  echo "Failed to configure application settings for $FUNCTION_APP_NAME."
  exit 1
fi
echo "Application settings configured successfully."

echo -e "\n\n - - - - | ALL RESOURCES WERE SUCCESSFULLY PROVISIONED | - - - - \n\n"
