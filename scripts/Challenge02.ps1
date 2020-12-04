Write-Host "This script is still in development, it may not work. - Matt"

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

.\customized-fhirhl7deployment.ps1
