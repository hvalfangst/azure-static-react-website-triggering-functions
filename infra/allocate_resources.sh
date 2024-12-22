#!/bin/bash

# Define colors for console output
GREEN="\e[32m"
RED="\e[31m"
BLUE="\e[34m"
CYAN="\e[36m"
YELLOW="\e[33m"
RESET="\e[0m"

# Variables
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
RESOURCE_GROUP="hvalfangstresourcegroup"
STORAGE_ACCOUNT_NAME="hvalfangststorageaccount"
FUNCTION_APP_NAME="hvalfangstlinuxfunctionapp"
LOCATION="westeurope"
BICEP_FILE="infra/main.bicep"

# Function to handle errors
handle_error() {
    echo -e "${RED}Error occurred in script at line: ${BASH_LINENO[0]}. Exiting...${RESET}"
    exit 1
}

# Set trap to catch errors and execute handle_error
trap 'handle_error' ERR

# Check if logged in to Azure
echo -e "${YELLOW}Checking if logged in to Azure...${RESET}"
az account show

if [ $? -ne 0 ]; then
    echo -e "${RED}Not logged in to Azure. Please run 'az login' first.${RESET}"
    exit 1
fi

# Create Resource Group
echo -e "${YELLOW}Creating resource group $RESOURCE_GROUP in $LOCATION ${RESET}"
az group create --name $RESOURCE_GROUP --location $LOCATION
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

echo -e "${YELLOW}Creating service principal...${RESET}"
az ad sp create-for-rbac --name hvalfangst --role contributor --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP --sdk-auth
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to create service principal.${RESET}"
    exit 1
fi

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

echo -e "${YELLOW}Setting up CORS for function app...${RESET}"
az functionapp cors add --name ${FUNCTION_APP_NAME} --resource-group $RESOURCE_GROUP --allowed-origins http://localhost:3000
az functionapp cors add --name ${FUNCTION_APP_NAME} --resource-group $RESOURCE_GROUP --allowed-origins https://hvalfangststorageaccount.z6.web.core.windows.net
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to set up CORS for function app.${RESET}"
    exit 1
fi

echo -e "${GREEN}All resources have been provisioned.${RESET}"
