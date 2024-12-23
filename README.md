# Static web app invoking Azure functions

This repository contains a [static web app](client/src/App.js), which enables users to upload CSV files containing demographic and financial data about individuals to a designated storage blob via an HTTP-triggered Azure Function. 
Once uploaded to the blob, another, blob-triggered function calculates correlations between various variables, such as experience, state, gender, and income. The computed statistics are then stored in a separate storage blob. 
These functions are defined in the python script [function_app.py](hvalfangst_function/function_app.py) - which is the main entrypoint of our Azure Function App instance.

The associated Azure infrastructure is deployed with a script (more on that below).

A branch-triggered pipeline has been set up to deploy our code to the respective Azure resources using a GitHub Actions Workflows [script](.github/workflows/deploy_to_azure.yml). 
The two functions are deployed using the Function App's associated **publish profile**, whereas the static web app is deployed using a service principal configured with a federated credential. 
Note that the static web app is actually hosted directly on a storage blob, which is configured to serve static websites. Thus, deploying the web app is simply a matter of uploading the files to the designated blob container.


## Requirements

- **Platform**: x86-64, Linux/WSL
- **Programming Languages**: [React](https://reactjs.org/docs/getting-started.html), [Python 3](https://www.python.org/downloads/)
- **Cloud Account**: [Azure](https://azure.microsoft.com/en-us/pricing/purchase-options/azure-account)
- **Resource provisioning**: [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/)


## Allocate resources

The shell script [allocate_resources](infra/allocate_resources.sh) creates Azure resources using the Azure CLI and a
[Bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview?tabs=bicep) template [file](infra/main.bicep). 

It will create the following hierarchy of resources:

```mermaid
graph TD
    A[Subscription]
    A --> B[Resource Group]
    B --> C[Storage Account]
    C --> D[Blob Container]
    D -->|Static Website Hosting| H[index.html]
    B --> E[App Service Plan]
    E -->|Hosts| G[Function App]
    G -->|Uses| F[Application Insights]

    A -->|Contains| B
    B -->|Contains| C
    C -->|Contains| D
    B -->|Contains| E
    B -->|Contains| F
```

## GitHub secrets
Four secrets are required in order for the GitHub Actions Workflow script to deploy the code to the Azure resources. 
As may be observed in the [script](.github/workflows/deploy_to_azure.yml), these are:

- **AZURE_CLIENT_ID**: Used to authenticate the service principal in order to deploy the static web app
- **AZURE_SUBSCRIPTION_ID**: Used to authenticate the service principal in order to deploy the static web app
- **AZURE_TENANT_ID**: Used to authenticate the service principal in order to deploy the static web app
- **PUBLISH_PROFILE**: Used to deploy our two functions to the Azure Function App

![img_1.png](images/img_1.png)
