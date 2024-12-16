#!/bin/bash

# Define colors for console output
GREEN="\e[32m"
RED="\e[31m"
BLUE="\e[34m"
CYAN="\e[36m"
YELLOW="\e[33m"
RESET="\e[0m"
# echo -e "${GREEN}This text is green.${RESET}"

# Variables
RESOURCE_GROUP="hvalfangstresourcegroup"
LOCATION="westeurope"
BICEP_FILE="infra/main.bicep"

# Function to handle errors
handle_error() {
    echo -e "${RED}Error occurred in script at line: ${BASH_LINENO[0]}. Exiting...${RESET}"
    exit 1
}

# Set trap to catch errors and execute handle_error
trap 'handle_error' ERR

# Create Resource Group
echo -e "${YELLOW}Creating resource group $RESOURCE_GROUP in $LOCATION ${RESET}"
az group create --name $RESOURCE_GROUP --location $LOCATION

# Deploy Bicep template
echo -e "${YELLOW}Deploying Bicep template...${RESET}"
az deployment group create --resource-group $RESOURCE_GROUP --template-file $BICEP_FILE -c
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to deploy Bicep template.${RESET}"
fi

echo -e "${GREEN}Deployment completed.${RESET}"
