Write-Host "This script is still in development, it may not work. - Matt"

##########################################################
####                   Challenge #1                   ####
##########################################################


$SubscriptionId = Read-Host -Prompt "Input the primary subscription ID"
$TenantId = Read-Host -Prompt "Input the primary tenant ID"
$secondTenant = Read-Host -Prompt "Input the secondary tenant ID"
$myenv = Read-Host -Prompt "Input a name for your environment, it must be 12 characters or less"
## $myenv must be 12 characters or less.

$workingFolder = Read-Host -Prompt "Input your working folder, eg. C:\fhirautomation"

$rg2 = $myenv + "-sof"
#Do not edit this.

$showAppsAndUsersInSecondTenant ="Connect-AzureAd -TenantDomain $secondTenant; Get-AzureADApplication -All:$true; Get-AzureADUser -searchstring $myenv"
$generateDeleteEverything ="Connect-AzureAd -TenantDomain $secondTenant; Remove-AzResourceGroup -Name $myenv -Force; Remove-AzResourceGroup -Name $rg2 -Force; Remove-AzureADApplication -All:$true; Remove-AzureADUser -searchstring $myenv"
## The above commands are assuming you're using an empty tenant for the app registrations and users, DO NOT USE THIS AS-IS IN ANY OTHER ENVIRONMENT.

Write-Host "After this script is complete, you can run lines 6-18 to clean out the environment. Press any key to acknowledge this information." -ForegroundColor Yellow
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Write-Host "Lastly, this script will prompt you for authentication multiple times including once where you will need to visit microsoft.com/devicelogin, this will be addressed in future versions. Press any key to acknowledge this information." -ForegroundColor Yellow
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

##########################################################
##########################################################

## Login to Primary Tenant and Sub
Write-host "Login to the Primary Tenant and Subscription (popup login prompt)." -ForegroundColor Yellow
Login-AzAccount
Set-AzContext -TenantId $TenantId -SubscriptionId $SubscriptionId

## Login to secondary Tenant
Write-host "Login to the Secondary Tenant (popup login prompt)." -ForegroundColor Yellow
Connect-AzureAd -TenantDomain $secondTenant

##########################################################
####                   Task #1                        ####
##########################################################

Set-ExecutionPolicy -Scope Process -ExecutionPolicy ByPass

## Download FHIR Deployment Scripts
Write-host "Downloading and extracting the FHIR deployment scripts..."
wget https://github.com/microsoft/OpenHack-FHIR/blob/main/Scripts/fhir-server-samples.zip?raw=true -OutFile fhir-server-samples.zip
Expand-Archive -LiteralPath fhir-server-samples.zip -DestinationPath .
Set-Location fhir-server-samples/deploy/scripts
## Note, I'ved tried calling the environment setup script by full path to get rid of these change directory commands but it throws a ton of errors because the script calls other scripts that it assumes are in the same directory.

## Deploy Environment 
Write-host "Deploying your environment, this could take 15-20 minutes..." -ForegroundColor Green
.\Create-FhirServerSamplesEnvironment.ps1 -EnvironmentName $myenv -EnvironmentLocation eastus -UsePaaS $true -EnableExport $true

### Need to Add deployment validation here

##########################################################
####                   Task #2                        ####
##########################################################

## These stay so you don't need to update them.
$storageAccountName = $myenv + "impsa"
$storageContainerName = "fhirimport"

Set-Location $workingFolder

## Download Sample FHIR Data
Write-host "Downloading and extracting FHIR sample data..."
Wget https://github.com/microsoft/OpenHack-FHIR/blob/main/Synthea/fhir.zip?raw=true -OutFile fhir.zip
Expand-Archive -LiteralPath fhir.zip -DestinationPath .
wget https://aka.ms/downloadazcopy-v10-windows -outfile azcopy.zip

## Download AzCopy
Write-host "Downloading AzCopy..."
Expand-Archive -LiteralPath azcopy.zip -DestinationPath .
gci -recurse azcopy.exe | cp -Destination .

## Upload Sample FHIR Data
Write-host "Uploading sample FHIR data to be processed..."
Write-Host "Look at the output below, you need to authenticate on behalf of AzCopy." -ForegroundColor Red -BackgroundColor Yellow

.\azcopy.exe login
$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $myenv -AccountName $storageAccountName).Value[0]
$destinationContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
$containerSASURI = New-AzStorageContainerSASToken -Context $destinationContext -ExpiryTime(get-date).AddSeconds(3600) -FullUri -Name $storageContainerName -Permission rw
.\azcopy.exe copy fhir $containerSASURI --recursive

## Validate data in container
$importStorageContext = (Get-AzStorageAccount -ResourceGroupName $myenv -AccountName $storageAccountName).Context
write-host "The number of blobs left in the container is:" (Get-AzStorageBlob -Container $storageContainerName -Context $importStorageContext).count
write-host "Now that this script is complete for Challenge01, you can run lines 6-18 in this script to clean out the environment." -ForegroundColor Green
write-host "If you want to throw caution to the wind, you could also just copy/paste the generated code below." -ForegroundColor Yellow
write-host "$generateDeleteEverything" -ForegroundColor Red
## Add Loop here to check for count of blobs in container, continue when empty.

Set-Location $workingFolder

##########################################################
####                   Challenge #2                   ####
##########################################################


Write-Host "Info: Primary Subscription ID - $SubscriptionId"
Write-Host "Info: Primary Tenant ID - $TenantId"
Write-Host "Info: Secondary Tenant ID - $secondTenant"
Write-Host "Info: Working Environment - $workingFolder"
Write-Host "Info: Environment Name - $myenv"


#$deploymentType = Read-Host -Prompt "Converter/Ingest Deployment Type: Press 0 for full deployment, nothing else is supported with this script."
$deploymentType = "0"
#$ingestRG = Read-Host -Prompt "Enter Name for the HL7 Ingest Resource Group" <#"rg-$myenv-ingest"#>
$ingestRG = "rg-$myenv-ingest"
#$location = Read-Host -Prompt "Enter Azure Region for Resource Deployment eg. EastUS." 
$location = "EastUS"
#$converterRG = Read-Host -Prompt "Enter Name for the HL7 Converter Resource Group" <#"rg-$myenv-convert"#>
$converterRG = "rg-$myenv-convert"
$fhirURL = "https://$myenv.azurehealthcareapis.com"


## Getting App ID and Secrets

$myKV = $myenv + "-ts"
$svcClientAppIDNm = $myenv + "-service-client-id"
$svcClientSecretNm = $myenv + "-service-client-secret"

## Get App ID

$svcClientAppID = Get-AzKeyVaultSecret -VaultName "$myKV" -Name "$svcClientAppIDNm"
$svcClientAppIDValue = " ";
$ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($svcClientAppID.SecretValue)
try {
    $svcClientAppIDValue = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)
} finally {
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)
}

Write-Host "AppID is:" $svcClientAppIDValue

## Get App Secret

$svcClientSecret = Get-AzKeyVaultSecret -VaultName "$myKV" -Name "$svcClientSecretNm"
$svcClientSecretValue = " ";
$ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($svcClientSecret.SecretValue)
try {
    $svcClientSecretValue = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)
} finally {
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)
}

Write-Host "Secret Value is:" $svcClientSecretValue


## Add in hash validation between original powershell script and the one here. 

#Do not edit this.


##########################################################
##########################################################

Set-Location $workingFolder

## Download Health Architectures Master
Write-host "Downloading and extracting the Health Architectures Zip File..."

Wget https://github.com/microsoft/OpenHack-FHIR/blob/main/Scripts/health-architectures-master.zip?raw=true -OutFile health-architectures-master.zip

Expand-Archive -LiteralPath health-architectures-master.zip -DestinationPath .

Set-Location "$workingFolder\health-architectures-master\HL7Conversion"

## Download modified fhirhl7 powershell script
Wget https://github.com/matthansen0/azure-fhir-automation/blob/main/scripts/resources/customized-fhirhl7deployment.ps1?raw=true -OutFile customized-fhirhl7deployment.ps1


## Anything modified in this script will come after a comment labeled "## Customized for Automation" -MH

<############################# Functions ##############################
1) Check-RG
    1.1 Checks if either the ingest or convert groups exists and returrns the details which are:
        A) Resource Group name 
        B) Location

2) Create-RG
    2.1) If the Resource group doesnt exist then we create the Resource group and retunr the detials which are:
        A) Resource Group name 
        B) Location

3) Create-IngestResources
    3.1) Will create the resources for the Ingest
        A) Create HL7OverHTTPS Ingest Functions App
        B) Create Service Plan
        C) Create the Transform Function App
        D) Create Service Bus Namespace and Queue
        E) Create hl7 ingest queue
        F) Create Storage Account

4) Create-ConvertResources
    4.1) Will create the resources for the convert
        A) Storage
        B) HL7 ServiceBus namespace
        C) HL7 ServiceBus destination queue
        D) FHIR Server URL same as below
        E) FHIR Server/Service Client Audience/Resource same as above

5) Deployment-printer
    5.1) prints out the deployment type and description to the user before proceeding.

#######################################################################>
function Check-RG {
    [CmdletBinding()]
    param (
        [string]$resourceGroupName
    )

    $getAllRG = Get-AzResourceGroup
    foreach($getRGs in $getAllRG){
        if($getRGs.ResourceGroupName.ToLower() -eq $resourceGroupName.ToLower()){
            $getRG = $resourceGroupName.ToLower()
            $getlocation = $getRGs.Location
            return $getRG, $getlocation
        }
    }
}

function Create-RG {
    [CmdletBinding()]
    param (
        [string]$resourceGroupName
    )
    ## Customized for Automation
    #$getlocation = Read-Host "Enter Location: "
    $getlocation = "$location"
    $RGInfo = (az group create -l $getlocation -n $resourceGroupName.tolower() | ConvertFrom-Json)
    return $RGInfo.name, $RGInfo.location
}


function Create-IngestResources {
    [CmdletBinding()]
    param (
        [string]$resourceGroupName,
        [string]$LocationName
    )
    
    # Starting Debugging output
    $DebugPreference = 'Continue'

    #Create Storage Account
    $RANDOM =  Get-Random -Maximum 10000 -Minimum 100
    $deployprefix = "ingest"
    $storageAccountNameSuffix = $deployprefix + "stgacnt" + $RANDOM
    $storecontainername = "hl7"
    
    Write-Debug("Starting HL7 Ingest Platform deployment in location [$LocationName]...")
    Write-Debug("Creating Storage Account [$storageAccountNameSuffix]...")
    az storage account create --location $LocationName --name $storageAccountNameSuffix.tolower() --resource-group $resourceGroupName.tolower() --sku Standard_LRS --encryption-services blob
    $storageConnectionString =(az storage account show-connection-string --name $storageAccountNameSuffix.tolower() --resource-group $resourceGroupName.tolower() --query "connectionString" --output tsv)
    Write-Debug("Creating Storage Account Container [$storecontainername]...")
    $container = (az storage container create -n $storecontainername --connection-string $storageConnectionString)
  
    #Create Service Bus Namespace and Queue
    $busnamespaceName = $deployprefix + "hlsb" + $RANDOM
    $busqueue= $deployprefix + "hl7busqueue" + $RANDOM
    Write-Debug( "Creating Service Bus Namespace [$busnamespaceName]...")
    $ingestservicebus=(az servicebus namespace create --resource-group $resourceGroupName --name $busnamespaceName --location $LocationName)
    #Create hl7 ingest queue
    Write-Debug( "Creating Queue [$busqueue]...")
    $ingestQueue=(az servicebus queue create --resource-group $resourceGroupName --namespace-name $busnamespaceName --name $busqueue)
    Write-Debug( "Retrieving ServiceBus Connection String...")
    $sbconnectionString=(az servicebus namespace authorization-rule keys list --resource-group $resourceGroupName --namespace-name $busnamespaceName --name RootManageSharedAccessKey --query primaryConnectionString --output tsv)

    #Create HL7OverHTTPS Ingest Functions App
    #Create Service Plan
    $serviceplanSuffix = $deployprefix + "asp" + $RANDOM
    $serviceplansku = "B1"
    $faname = $deployprefix + "hl7azfunc" + $RANDOM
    $deployzip="./hl7ingest/distribution/publish.zip"

    Start-Sleep -Seconds 15
    $faresourceid="/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Web/sites/$faname"
    
    Start-Sleep -Seconds 15
    Write-Debug( "Creating hl7ingest Function App Serviceplan[$serviceplanSuffix]...")
    $serviceplan=(az appservice plan create -g  $resourceGroupName -n $serviceplanSuffix --number-of-workers 2 --sku $serviceplansku)
    

    Start-Sleep -Seconds 15
    #Create the Transform Function App
    Write-Debug( "Creating hl7ingest Function App [$faname]...")
    $fahost=(az functionapp create --name $faname --storage-account $storageAccountNameSuffix.tolower() --plan $serviceplanSuffix --resource-group $resourceGroupName --runtime dotnet --os-type Windows --query defaultHostName --output tsv)
    


    Start-Sleep -Seconds 30
    Write-Debug( "Retrieving Function App Host Key...")
    $fakey=(az rest --method post --uri "https://management.azure.com$faresourceid/host/default/listKeys?api-version=2018-02-01" --query "functionKeys.default" --output tsv)
    

    Start-Sleep -Seconds 15
    #Add App Settings
    #StorageAccount
    Write-Debug( "Configuring hl7ingest Function App [$faname]...")
    $azfunction=(az functionapp config appsettings set --name $faname --resource-group $resourceGroupName --settings "StorageAccount=$storageConnectionString" "StorageAccountBlobContainer=$storecontainername" "ServiceBusConnection=$sbconnectionString" "QueueName=$busqueue")
    

    Start-Sleep -Seconds 15
    #deeployment from devops repo
    Write-Debug( "Deploying hl7ingest Function App from source repo to [$fahost]...")
    $azfuncdeploy=(az functionapp deployment source config-zip --name $faname --resource-group $resourceGroupName --src $deployzip)
    
    $TheDate = Get-Date -Format "dddd MM/dd/yyyy HH:mm K"
    Write-Debug( " 
    ************************************************************************************************************
    HL7 Ingest Platform has successfully been deployed to group $resourceGroupName on $TheDate
    Please note the following reference information for future use:
    Your ingest host is: https://$fahost
    Your ingest host key is: $fakey
    Your hl7 ingest service bus namespace is: $busnamespaceName
    Your hl7 ingest service bus destination queue is: $busqueue
    Your hl7 storage account name is: $storageAccountNameSuffix
    our hl7 storage account container is: $storecontainername
    ************************************************************************************************************
    ")
    
    $DebugPreference = 'SilentlyContinue'
    #return $fahost, $fakey, $busnamespaceName, $busqueue, $storageAccountNameSuffix.tolower(), $storecontainername
}


<#
Need:
Storage
HL7 ServiceBus namespace
HL7 ServiceBus destination queue
FHIR Server URL same as below
FHIR Server/Service Client Audience/Resource same as above
Client Tenant ID

FHIR Server Service Client Application ID
FHIR Server Service Client Secret

#>
<# Maybe just put everything in the same RG. #>
function Create-ConvertResources{
    [CmdletBinding()]
    param (
        [string]$varingestRG,
        [string]$varconvertRG,
        [string]$fstenant,
        [string]$LocationName
    )

    # Starting Debugging output
    $DebugPreference = 'Continue'
    $hl7rgname, $vargetIngestLocation = Check-RG -resourceGroupName $varingestRG
    $RANDOM =  Get-Random -Maximum 10000 -Minimum 100
    $deployprefix = "convert"
    # Check if you want use defualt tenant ID or enter manually

    ## Customized for Automation
    <# $tenantValidation = Read-Host "Do you want to use the following tenant ID [$fstenant]? Please enter Y to continue with exisitng tenant ID or N to manually enter tenant ID: "
    if($tenantValidation.ToUpper() -eq "N"){
        $fstenant = ""
        $fstenant = Read-Host "Enter tenant: "
    } #>
    $tenantValidation = "Y"


    <# Creating the App RG if not needed we can delete and update line number 266 for the github link#>
    $varconvertAppRG = $varconvertRG +"App"
    az group create -l $vargetIngestLocation -n $varconvertAppRG.tolower() | ConvertFrom-Json 
    # App ID and client Secret

    ## Customized for Automation
    #$fsclientid = Read-Host "Enter the FHIR Server Service Client Application ID: "
    $fsclientid = "$svcClientAppIDValue"
    #$fssecret = Read-Host "Enter the FHIR Server Service Client Secret: "
    $fssecret = "$svcClientSecretValue"
    #$fsurl = Read-Host "Enter the destination FHIR Server URL: "
    $fsurl = "$fhirURL"
    $fsaud = $fsurl
    
    Write-Debug( "tenant ID [$fstenant]
    Client Application ID [$fsclientid]
    Service Client Secret [$fssecret]
    FHIR Server URL [$fsurl]
    Audiance [$fsaud]")
    #Create Storage Account
    $storageAccountNameSuffix = $deployprefix + "stgacnt" + $RANDOM
    $storecontainername = "hl7" + $deployprefix
    $hl7storename = (Get-AzStorageAccount -ResourceGroupName $varingestRG)
    #Create Storage Account
    Write-Debug( "Creating Storage Account[$storageAccountNameSuffix]...")
    $convertStorage= (az storage account create --name $storageAccountNameSuffix --resource-group $varconvertRG --location  $vargetIngestLocation --sku Standard_LRS --encryption-services blob --kind StorageV2)
        
    Write-Debug( "Retrieving Storage Account Connection String...")
    $storageConnectionString= (az storage account show-connection-string -g $varconvertRG -n $storageAccountNameSuffix --query connectionString --output tsv)
        
    #Create EventHub Bus Namespace and Hub
    $evhubnamespaceName="fehub"+$RANDOM
    Write-Debug( "Creating FHIR Event Hub Namespace [$evhubnamespaceName]...")
    $fhireventns= (az eventhubs namespace create --name $evhubnamespaceName --resource-group $varconvertRG -l $LocationName)
        
    # Create eventhub for fhirevents
    $evhub = "fhirevents"
    Write-Debug( "Creating FHIR Event Hub [$evhub]...")
    $fhireventq= (az eventhubs eventhub create --name $evhub --resource-group $varconvertRG --namespace-name $evhubnamespaceName)
    
    Write-Debug( "Retrieving Event Hub Connection String...")
    $evconnectionString= (az eventhubs namespace authorization-rule keys list --resource-group $varconvertRG --namespace-name $evhubnamespaceName --name RootManageSharedAccessKey --query primaryConnectionString --output tsv)
    
    #Create FHIREventProcessor Function App
    #Create Service Plan
    $serviceplanSuffix=$deployprefix+"asp"
    $deployzip="../FHIR/FHIREventProcessor/distribution/publish.zip"
    $faname="fhirevt"+$RANDOM
    $serviceplansku = "B1"
    
    Start-Sleep -Seconds 15
    Write-Debug( "Creating FHIREventProcessor Function App Service Plan[$serviceplanSuffix]...")
    $serviceplan= (az appservice plan create -g  $varconvertRG -n $serviceplanSuffix --number-of-workers 2 --sku $serviceplansku)
    
    #Create the Function App
    Start-Sleep -Seconds 15
    Write-Debug( "Creating FHIREventProcessor Function App [$faname]...")
    $fahost= (az functionapp create --name $faname --storage-account $storageAccountNameSuffix  --plan $serviceplanSuffix  --resource-group $varconvertRG --runtime dotnet --os-type Windows --query defaultHostName --output tsv)
    
    #Add App Settings
    Start-Sleep -Seconds 15
    Write-Debug( "Configuring FHIREventProcessor Function App [$faname]...")
    $FHIREventProcessorApp= (az functionapp config appsettings set --name $faname  --resource-group $varconvertRG --settings FS_URL=$fsurl FS_TENANT_NAME=$fstenant FS_CLIENT_ID=$fsclientid FS_SECRET=$fssecret FS_RESOURCE=$fsaud EventHubConnection=$evconnectionString EventHubName=$evhub)
    
    Start-Sleep -Seconds 30
    Write-Debug( "Deploying FHIREventProcessor Function App from repo to host [$fahost]...")
    #deployment from git repo
    $FHIREventProcessorRepo= (az functionapp deployment source config-zip --name $faname --resource-group $varconvertRG --src $deployzip)
    
    #Deploy HL7 FHIR Converter
    $uid= New-Guid
    $hl7convertername="hl7conv"
    $hl7converterinstance=$deployprefix+$hl7convertername+$RANDOM
    $hl7convertkey= $uid -replace '[-]'
    Start-Sleep -Seconds 15
    Write-Debug( "Deploying FHIR Converter [$hl7converterinstance] to resource group [$varconvertRG]...")
    # If we can use the linux for services apps we can change the RG to use the convert RG rather than a App RG.
    az deployment group create -g $varconvertAppRG --template-uri "https://raw.githubusercontent.com/microsoft/FHIR-Converter/master/deploy/default-azuredeploy.json" --parameters serviceName=$hl7converterinstance apiKey=$hl7convertkey
    
    Start-Sleep -Seconds 15
    Write-Debug( "Deploying Custom Logic App Connector for FHIR Server...")
    $fhirlaconserver = (az deployment group create -g $varconvertRG --template-file "./hl7tofhir/LogicAppCustomConnectors/fhir_server_connect_template.json" --parameters fhirserverproxyhost="$faname.azurewebsites.net")
    
    Start-Sleep -Seconds 15
    Write-Debug( "Deploying Custom Logic App Connector for FHIR Converter...")
    $fhirlaconconverter = (az deployment group create -g $varconvertRG --template-file "./hl7tofhir/LogicAppCustomConnectors/fhir_converter_connect_template.json"  --parameters fhirconverterhost="$hl7converterinstance.azurewebsites.net")
    
    Start-Sleep -Seconds 15
    Write-Debug( "Loading HL7 Ingest connections/keys...")
    $hl7storekey= (az storage account keys list -g $hl7rgname -n $hl7storename.StorageAccountName.trim(" ") --query "[?keyName=='key1'].value" --output tsv)

    #Set up variables
    $hl7sbnamespace = (Get-AzServiceBusNamespace -resourcegroupname $hl7rgname)
    $hl7sbqueuename = (Get-AzServiceBusQueue -ResourceGroup $hl7rgname  -NamespaceName $hl7sbnamespace.Name.trim(" "))
    $hl7store = $hl7storename.StorageAccountName.trim(" ")
    $hl7sbns = $hl7sbnamespace.Name.trim(" ")
    $hl7sbq = $hl7sbqueuename.Name.trim(" ")

    Start-Sleep -Seconds 15
    $faresourceid="/subscriptions/$subscriptionId/resourceGroups/$varconvertRG/providers/Microsoft.Web/sites/$faname"
    $hl7sbconnection= (az servicebus namespace authorization-rule keys list --resource-group $hl7rgname --namespace-name $hl7sbns --name RootManageSharedAccessKey --query primaryConnectionString --output tsv)
    #hl7sbconnection=$(az servicebus namespace authorization-rule keys list --resource-group $hl7rgname --namespace-name $hl7sbnamespace --name RootManageSharedAccessKey --query primaryConnectionString --output tsv)
   
    Write-Debug( "Loading FHIREventProcessor Function Keys...")
    Start-Sleep -Seconds 15
    $fakey= (az rest --method post --uri "https://management.azure.com$faresourceid/host/default/listKeys?api-version=2018-02-01" --query "functionKeys.default" --output tsv)
    Write-Debug( "Deploying HL72FHIR Logic App...")
    $azlogicappdeploy= (az deployment group create -g $varconvertRG --template-file "./hl7tofhir/hl72fhir.json" --parameters HL7FHIRConverter_1_api_key=$hl7convertkey azureblob_1_accountName=$hl7store azureblob_1_accessKey=$hl7storekey FHIRServerProxy_1_api_key=$fakey servicebus_1_connectionString=$hl7sbconnection servicebus_1_queue=$hl7sbq)
    
    $TheDate = Get-Date -Format "dddd MM/dd/yyyy HH:mm K"
    Write-Debug( "
    ************************************************************************************************************
    HL72FHIR Workflow Platform has successfully been deployed to group $resourceGroupName on $TheDate
    Please note the following reference information for future use:
    Your FHIR EventHub namespace is: $evhubnamespaceName
    Your FHIR EventHub name is: $evhub
    Your HL7 FHIR Converter Host is: $hl7converterinstance
    Your HL7 FHIR Converter Key is: $hl7convertkey
    Your HL7 FHIR Converter Resource Group is: $varconvertRG
    ************************************************************************************************************
    ")
    
    $DebugPreference = 'SilentlyContinue'
    #return $fahost, $fakey, $evhubnamespaceName, $evhub, $storageAccountNameSuffix.tolower() , $storecontainername
}

function Deployment-printer{
    [CmdletBinding()]
    param (
        [int]$deploymenttype
    )
    $printoutput = ""
    if($deploymenttype -eq 0){
        $printoutput = "You chose Full Deployment
        Here are the details of the following deployment option:
        1) we will create the ingestion resources in an existing or new resource group which you will specify.
        1.1) App Service Plan
        1.2) Storage Account for ingestion
        1.3) Azure Function App and Apps Insights
        1.4) Service Bus
        2) we will create the Convertion resources in an existing or new resource group which you will specify.
        2.1) 4 API connections: FHIRServer-Proxy, HL7FHIRConverter, HL7ServiceBus, HL7BlobStorageaccount
        2.2) Logic App HL7toFHIR
        2.3) 2 Logic App custom connectors: FHIRServer-Proxy, HL7FHIRConverter
        2.4) storage account
        2.5) App Service Plan
        2.6) Events Hub
        2.7) Azure Function App and Apps Insights"
    }
    elseif($deploymenttype -eq 1){
        $printoutput = "You chose Ingestion Deployment
        Here are the details of the following deployment option:
        1) we will create the ingestion resources in an existing or new resource group which you will specify.
        1.1) App Service Plan
        1.2) Storage Account for ingestion
        1.3) Azure Function App and Apps Insights
        1.4) Service Bus"
    }
    elseif($deploymenttype -eq 2){
        $printoutput = "You chose Conversion Deployment
        Here are the details of the following deployment option:
        1) we will create the Convertion resources in an existing or new resource group which you will specify.
        1.1) 4 API connections: FHIRServer-Proxy, HL7FHIRConverter, HL7ServiceBus, HL7BlobStorageaccount
        1.2) Logic App HL7toFHIR
        1.3) 2 Logic App custom connectors: FHIRServer-Proxy, HL7FHIRConverter
        1.4) storage account
        1.5) App Service Plan
        1.6) Events Hub
        1.7) Azure Function App and Apps Insights"
    }
    else{
        $printoutput = "Invalid entry goodbye."
        exit 
    }
    return $printoutput
}

########################### Main ##################################
#                                                                 #
###################################################################

<#
    Checking to see if RG exists from a list of RGs on the subscription
#>
$tenantId = (az account show | ConvertFrom-Json).tenantId
$subscriptionId = (az account show | ConvertFrom-Json).Id
$TheDate = Get-Date -Format "dddd MM/dd/yyyy HH:mm K"

## Customized for Automation
<#$DeploymentOptions = Read-Host "Please enter the deployemnt you want to do:
Full Deployment: 0
Ingestion Deployment: 1
Conversion Deployment: 2
>" #>
$DeploymentOptions = "0"

if($DeploymentOptions -eq 0 -Or $DeploymentOptions -eq 1){
    Deployment-printer -deploymenttype $DeploymentOptions
    ## Customized for Automation
    #$ContDeployment = Read-Host "Do you wish to proceed? please enter Y to continue or N to exit."
    $ContDeployment = "Y"
    if($ContDeployment.ToUpper() -eq "Y"){
        <#
        Ingest checks
        #>
        ## Customized for Automation
        #$ingestRG = Read-Host "Enter the name of the HL7 Ingest Resource Group: "
        ## This variable is already instantiated in the automation script

        <#
        Checking if the Convert RG was created before hand if it was great if not then create it.
        #>
        $getIngestRG, $getIngestLocation = Check-RG -resourceGroupName $ingestRG
        
        if(!$getIngestRG){
            write-Host("Resource group does not exist, going to create resource group: $ingestRG and ingest resources" )
            write-Host("Setting up the resouce group...")
            $getIngestRG, $getIngestLocation = Create-RG -resourceGroupName $ingestRG
        }
        Write-Host("Ingest Resource Group: $getIngestRG Ingest in Location: $getIngestLocation")
        Create-IngestResources -resourceGroupName $getIngestRG -LocationName $getIngestLocation
    }
    else{
        write-Host("You chose not to continue with the deployment" )
        exit
    }
}

if($DeploymentOptions -eq 0 -Or $DeploymentOptions -eq 2){
    Deployment-printer -deploymenttype $DeploymentOptions
    ## Customized for Automation
    #$ContDeployment = Read-Host "Do you wish to proceed? please enter Y to continue or N to exit."
    $ContDeployment = "Y"
    if($ContDeployment.ToUpper() -eq "Y"){
        <#ingest checks#>
        ## Customized for Automation
        #$ingestRG = Read-Host "Enter the name of the HL7 Ingest Resource Group:"
        ## This variable is already instantiated in the automation script

        <#Checking if the Convert RG was created before hand if it was great if not then create it.#>
        $getIngestRG, $getIngestLocation = Check-RG -resourceGroupName $ingestRG
        if(!$getIngestRG){
            write-Host("Resource group does not exist, going to create resource group: $ingestRG and ingest resources" )
            write-Host("Setting up the resouce group...")
            $getIngestRG, $getIngestLocation = Create-RG -resourceGroupName $ingestRG
            Write-Host("Ingest Resource Group: $getIngestRG Ingest Location: $getIngestLocation")
            <# function #>
            Create-IngestResources -resourceGroupName $getIngestRG -LocationName $getIngestLocation
        }
        <#Convert checks#>
        ## Customized for Automation
        #$ConvertRG = Read-Host "Enter new or exisitng HL7 Converter Resource Group name:"
        $ConvertRG = "$converterRG"
            
        <#Checking if the Convert RG was created before hand if it was great if not then create it.#>
        $getConvertRG, $getConvertLocation = Check-RG -resourceGroupName $ConvertRG
            
        if(!$getConvertRG){
            write-Host("Resource group does not exist, going to create resource group: $ConvertRG and ingest resources" )
            write-Host("Setting up the resouce group...")
            $getConvertRG, $getConvertLocation = Create-RG -resourceGroupName $ConvertRG
            Write-Host("Ingest Resource Group: $getIngestRG in Ingest Location: $getIngestLocation")
            Write-Host("Ingest Resource Group: $getConvertRG in Convert Location: $getConvertLocation")
        }
        <# convert Function #>
        Create-ConvertResources -varconvertRG $getConvertRG -LocationName $getConvertLocation -varingestRG $getIngestRG -fstenant $tenantId
    }
    else{
        write-Host("You chose not to continue with the deployment" )
        exit
    }
}
################################### END #######################################
#                                                                             #
###############################################################################