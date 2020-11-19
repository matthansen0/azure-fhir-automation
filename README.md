# Azure FHIR Automation
Automation scripts for Azure API for FHIR OpenHack Challenges

## Assumptions for Challenge01 Automation:

- You have a Primary Tenant and Subscription where resources will be deployed, and are using an empty Secondary Tenant for User Accounts and App Registrations
- You have the apprpriate PowerShell versions and other prereqs

This script will ask for input at the beginning and will require your Primary Tenant ID, Primary Subscription ID, Secondary Tenant ID, a Unique environment name, and the Filesystem path where you're working and executing the script.

Note: Due to the length of some of the file names and paths it is reccomended that you create a folder on the root of your C:\ drive as your working folder.

[Challenge01 Script](./scripts/Challenge01.ps1)

### Cleanup: 

To cleanup the entire environment from Challenge01, you can run lines 6-18 in the script, then execute ```$generateDeleteEverything```, and copy/past the output 1-line command and it will delete both resource groups, all of the resources, along with the user and the app registrations in AAD. This will take 15-20 minutes. 
