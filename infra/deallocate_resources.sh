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

# App registration names
APP_NAMES=("hvalfangst-static-web-app" "hvalfangst-function-app" "hvalfangst-github-actions-sp")

# Function to handle errors
handle_error() {
    echo -e "${RED}Error occurred in script at line: ${BASH_LINENO[0]}. Exiting...${RESET}"
    exit 1
}

# Set trap to catch errors and execute handle_error
trap 'handle_error' ERR

# Check if the resource group exists
if az group show --name $RESOURCE_GROUP > /dev/null 2>&1; then
    echo -e "${YELLOW}Deallocating resources asynch...${RESET}"
    az group delete --name $RESOURCE_GROUP --yes --no-wait
else
    echo -e "${CYAN}Resource group ${RESOURCE_GROUP} does not exist. Skipping deletion.${RESET}"
fi

echo -e "${YELLOW}Deleting app registrations...${RESET}"

for APP_NAME in "${APP_NAMES[@]}"
do
    # Get the app registration object ID
    APP_OBJECT_ID=$(az ad app list --display-name $APP_NAME --query "[].appId" -o tsv)

    if [ -n "$APP_OBJECT_ID" ]; then
        echo -e "${BLUE}Deleting app registration ${APP_NAME} with object ID ${APP_OBJECT_ID}${RESET}"
        az ad app delete --id $APP_OBJECT_ID
    else
        echo -e "${CYAN}App registration ${APP_NAME} not found.${RESET}"
    fi
done

echo -e "${GREEN}Script completed successfully.${RESET}"