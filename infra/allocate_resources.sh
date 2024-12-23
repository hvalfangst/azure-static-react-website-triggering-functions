#!/bin/bash

# Colors for console output
GREEN="\e[32m"
RED="\e[31m"
BLUE="\e[34m"
CYAN="\e[36m"
YELLOW="\e[33m"
RESET="\e[0m"

# Constants
RESOURCE_GROUP="hvalfangstresourcegroup"
STORAGE_ACCOUNT_NAME="hvalfangststorageaccount"
FUNCTION_APP_NAME="hvalfangstlinuxfunctionapp"
LOCATION="westeurope"
BICEP_FILE="infra/main.bicep"

# Set environment variable to prevent path conversion in MSYS (https://github.com/Azure/azure-cli/blob/dev/doc/use_cli_with_git_bash.md#auto-translation-of-resource-ids)
export MSYS_NO_PATHCONV=1;

# Function to handle errors
handle_error() {
    echo -e "${RED}Error occurred in script at line: ${BASH_LINENO[0]}. Exiting...${RESET}"
    exit 1
}

# Set trap to catch errors and execute handle_error
trap 'handle_error' ERR

# Check if you are logged in to Azure
echo -e "${YELLOW}Checking if logged in to Azure...${RESET}"
az account show

if [ $? -ne 0 ]; then
    echo -e "${RED}Not logged in to Azure. Please run 'az login' first.${RESET}"
    exit 1
fi

# Variables retrieved from Azure CLI
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
TENANT_ID=$(az account show --query tenantId --output tsv)

# Create Resource Group
echo -e "${YELLOW}Creating resource group ${RESOURCE_GROUP} in ${LOCATION} ${RESET}"
az group create --name ${RESOURCE_GROUP} --location ${LOCATION}
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to create resource group.${RESET}"
    exit 1
fi


# Deploy Bicep template
echo -e "${YELLOW}Deploying Bicep template...${RESET}"
az deployment group create --resource-group $RESOURCE_GROUP --template-file $BICEP_FILE -c
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to deploy Bicep template.${RESET}"
    exit 1
fi

# Create service principal used by GitHub Actions, the returned JSON is stored as secret in the GitHub repository
echo -e "${YELLOW}Creating service principal...${RESET}"
SP_APP_ID=$(az ad sp create-for-rbac --name hvalfangst-github-actions-sp --role contributor --scopes /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP} --query "appId" -o tsv)
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to create service principal.${RESET}"
    exit 1
fi
echo -e "${YELLOW}Service principal with ID ${SP_APP_ID} created successfully.${RESET}"

echo -e "${YELLOW}Adding federated credential to Azure AD application...${RESET}"

# Check if the federated credential already exists
EXISTING_CRED=$(az ad app federated-credential list --id ${SP_APP_ID} --query "[?name=='GitHubActionsFederatedCred']")

if [ "$EXISTING_CRED" == "[]" ]; then
  # Federated credential does not exist, create it
  az ad app federated-credential create --id ${SP_APP_ID} --parameters '{
    "name": "GitHubActionsFederatedCred",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:hvalfangst/azure-static-react-website-triggering-functions:ref:refs/heads/main",
    "audiences": [
      "api://AzureADTokenExchange"
    ]
  }'
  echo -e "${YELLOW}Federated credential created successfully.${RESET}"
else
  # Federated credential already exists
  echo -e "${YELLOW}Federated credential already exists. Skipping creation.${RESET}"
fi

# Set up our storage container to serve static website with default index and 404 page
echo -e "${YELLOW}Setting up static website...${RESET}"
az storage blob service-properties update \
  --account-name ${STORAGE_ACCOUNT_NAME} \
  --static-website \
  --index-document index.html \
  --404-document 404.html
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to set up static website.${RESET}"
    exit 1
fi

# Set up CORS for our Function App, which is used for our HTTP-triggered function
echo -e "${YELLOW}Setting up CORS for function app...${RESET}"
az functionapp cors add --name ${FUNCTION_APP_NAME} --resource-group ${RESOURCE_GROUP} --allowed-origins http://localhost:3000
az functionapp cors add --name ${FUNCTION_APP_NAME} --resource-group ${RESOURCE_GROUP} --allowed-origins https://hvalfangststorageaccount.z6.web.core.windows.net
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to set up CORS for function app.${RESET}"
    exit 1
fi

# Set up app registration for function app
echo -e "${YELLOW}Setting up app registration for function app...${RESET}"
FUNCTION_APP_CLIENT_ID=$(az ad app create \
  --display-name "hvalfangst-function-app" \
  --query appId -o tsv)

if [ $? -ne 0 ] || [ -z "$FUNCTION_APP_CLIENT_ID" ]; then
    echo -e "${RED}Failed to set up app registration or retrieve the app ID.${RESET}"
    exit 1
fi

# Set up app settings for the function app
echo -e "${YELLOW}Setting up app settings for function app...${RESET}"
az functionapp config appsettings set \
    --name ${FUNCTION_APP_NAME} \
    --resource-group ${RESOURCE_GROUP} \
    --settings TENANT_ID=${TENANT_ID} FUNCTION_APP_CLIENT_ID=${FUNCTION_APP_CLIENT_ID}
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to set up app settings for function app.${RESET}"
    exit 1
fi

# Set up app registration for the static web app
echo -e "${YELLOW}Setting up app registration for static web app...${RESET}"
STATIC_WEB_APP_CLIENT_ID=$(az ad app create \
  --display-name "hvalfangst-static-web-app" \
  --query appId -o tsv)

if [ $? -ne 0 ] || [ -z "STATIC_WEB_APP_CLIENT_ID" ]; then
    echo -e "${RED}Failed to set up app registration or retrieve the app ID.${RESET}"
    exit 1
fi

echo -e "${GREEN}All resources have been provisioned.${RESET}"