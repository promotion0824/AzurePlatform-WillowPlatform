param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $environmentName, #dev

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $productPrefix, #min

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $azureRegion, #aue2

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $customerId, #Guid for customer from DirectoryCoreDB Sites.CustomerId

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $twinPlatformManagedIdentityPrincipalId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $adxClusterUri, #https://clustername.location.kusto.windows.net

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $adxDbName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $aadTenantName #willowinc.com
)

#--------------------------------------------
# Variables
#--------------------------------------------
#Common
$ErrorActionPreference = "Stop"
$companyPrefix = "wil"
$sharedResourcesPrefix = "shr"
$ldaResourcesPrefix = "lda"
$pltResourcesPrefix = "plt"
$sharedAzurePrefix = "${companyPrefix}-${environmentName}-${productPrefix}-${sharedResourcesPrefix}-${azureRegion}"
$sharedKeyVault = "${sharedAzurePrefix}-kvl"
$consoleLogsDivider = "-----------------------------------"
$existingKeyVaultSecrets = {}

#Shared
$dataProtectionStorageAccount = "${companyPrefix}${environmentName}${productPrefix}${sharedResourcesPrefix}${azureRegion}sto"
$shrMgtRG = "t2-${companyPrefix}-${environmentName}-${productPrefix}-${sharedResourcesPrefix}-${azureRegion}-mgt-rsg"
$ldaAppRG = "t3-${companyPrefix}-${environmentName}-${productPrefix}-${ldaResourcesPrefix}-${companyPrefix}-${azureRegion}-app-rsg"

#Platform
$pltRG = "t3-${companyPrefix}-${environmentName}-${productPrefix}-${pltResourcesPrefix}-${azureRegion}-app-rsg"
$directoryCoreApp = "${companyPrefix}-${environmentName}-${productPrefix}-${pltResourcesPrefix}-${azureRegion}-directorycore"
$workflowCoreApp = "${companyPrefix}-${environmentName}-${productPrefix}-${pltResourcesPrefix}-${azureRegion}-workflowcore"
$portalXlApp = "${companyPrefix}-${environmentName}-${productPrefix}-${pltResourcesPrefix}-${azureRegion}-portalxl"
$imageHubApp = "${companyPrefix}-${environmentName}-${productPrefix}-${pltResourcesPrefix}-${azureRegion}-imagehub"
$imageHubStorageAccount = "${companyPrefix}${environmentName}${productPrefix}${pltResourcesPrefix}${azureRegion}imagehub"

#Live Data
$piServerIngestionFunc = "${companyPrefix}-${environmentName}-${productPrefix}-${ldaResourcesPrefix}-${companyPrefix}-${azureRegion}-eventhub"
$siteToPlatformEventHubNamespace = "${companyPrefix}-${environmentName}-${productPrefix}-${ldaResourcesPrefix}-${companyPrefix}-${azureRegion}-sit"
$unifiedEventHubNamespace = "${companyPrefix}-${environmentName}-${productPrefix}-${ldaResourcesPrefix}-${companyPrefix}-${azureRegion}-uie"

#--------------------------------------------
# End Variables
#--------------------------------------------

#--------------------------------------------
# Functions
#--------------------------------------------
#https://docs.microsoft.com/en-us/cli/azure/keyvault/key?view=azure-cli-latest#az_keyvault_key_create
function Initialize-KeyVaultKey {
    param(
        [Parameter(Position = 0, mandatory = $true)]
        [string] $keyVaultName,
        [Parameter(Position = 1, mandatory = $true)]
        [string] $keyName
    )
    $key = az keyvault key show --vault-name $keyVaultName --name $keyName
    if ($null -ne $key) {
        Write-Verbose "Key ${keyName} in ${keyVaultName} exists already"
    }
    else {
        Write-Verbose "Creating Keyvault Key ${keyName} in ${keyVaultName}"
        az keyvault key create --name $keyName --vault-name $keyVaultName --kty RSA --size 2048 --ops encrypt decrypt sign verify wrapKey unwrapKey
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Creating Keyvault Key ${keyName} in ${keyVaultName} resulted in exit code $LASTEXITCODE"
        }
    }
}

function Read-ExistingSecretsFromKeyVault {
    param(
        [Parameter(Position = 0, mandatory = $true)]
        [string] $keyVaultName
    )

    $keyVaultSecrets = az keyvault secret list --vault-name $keyVaultName -o json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Get key vault $keyVaultName secrets resulted in exit code $LASTEXITCODE"
    }

    return $keyVaultSecrets;
}
#https://docs.microsoft.com/en-us/cli/azure/keyvault/key?view=azure-cli-latest#az_keyvault_key_create
function Initialize-KeyVaultSecret {
    param(
        [Parameter(Position = 0, mandatory = $true)]
        [string] $keyVaultName,
        [Parameter(Position = 1, mandatory = $true)]
        [string] $secretName,
        [Parameter(Position = 2, mandatory = $false)]
        [string] $secretValue = ""
    )
    $foundKeyVaultSecrets = $existingKeyVaultSecrets | Where-Object { $_.name -eq $secretName }
    if ($foundKeyVaultSecrets.count -eq 0) {
        Write-Verbose "Creating Keyvault Secret ${secretName} in ${keyVaultName}"
        if ($secretValue -eq "") {
            $secretValue = "Default Value"
        }
        az keyvault secret set --vault-name $keyVaultName --name $secretName --value $secretValue
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Creating Keyvault Secret ${secretName} in ${keyVaultName} resulted in exit code $LASTEXITCODE"
        }
        else {
            Write-Verbose "Created Keyvault Secret ${secretName} in ${keyVaultName} successfully"
        }
    }
    else {
        $keyVaultSecret = az keyvault secret show --vault-name $keyVaultName --name $secretName | ConvertFrom-Json
        #$secretValue -eq "" is required to prevent manually set secrets from being replaced by empty string
        if (($keyVaultSecret.value -eq $secretValue) -or ($secretValue -eq "")) {
            Write-Verbose "Keyvault Secret ${secretName} in ${keyVaultName} already exists"
        }
        else {
            Write-Verbose "Replacing Keyvault Secret ${secretName} in ${keyVaultName}"
            az keyvault secret set --vault-name $keyVaultName --name $secretName --value $secretValue
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Replacing Keyvault Secret ${secretName} in ${keyVaultName} resulted in exit code $LASTEXITCODE"
            }
            else {
                Write-Verbose "Replaced Keyvault Secret ${secretName} in ${keyVaultName} successfully"
            }
        }
    }
}

function Initialize-AppSettings-FromJson {
    param(
        [Parameter(Position = 0, mandatory = $true)]
        [string] $appName,
        [Parameter(Position = 1, mandatory = $true)]
        [string] $resourceGroup,
        [Parameter(Position = 2, mandatory = $true)]
        [string] $configJsonFilePath
    )
    Write-Verbose "Configuring appsetting for ${appName} (${resourceGroup}) setting:${settingName} to ${settingValue}"
    az webapp config appsettings set --name $appName --resource-group $resourceGroup --settings @$configJsonFilePath
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Configuring appsetting for ${appName} (${resourceGroup}) setting:${settingName} to ${settingValue} resulted in exit code $LASTEXITCODE"
    }
}

function Initialize-FunctionAppSettings-FromJson {
    param(
        [Parameter(Position = 0, mandatory = $true)]
        [string] $functionAppName,
        [Parameter(Position = 1, mandatory = $true)]
        [string] $resourceGroup,
        [Parameter(Position = 2, mandatory = $true)]
        [string] $configJsonFilePath
    )
    Write-Verbose "Configuring function appsetting for ${functionAppName} (${resourceGroup})"
    az functionapp config appsettings set --name $functionAppName --resource-group $resourceGroup --settings @$configJsonFilePath
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Configuring function appsetting for ${functionAppName} (${resourceGroup}) resulted in exit code $LASTEXITCODE"
    }
}

function Get-StorageAccountConnectionString {
    param(
        [Parameter(Position = 0, mandatory = $true)]
        [string] $resourceGroup,
        [Parameter(Position = 0, mandatory = $true)]
        [string] $storageAcc
    )
    Write-Verbose "Getting storage account connection string for (${resourceGroup}) ${storageAcc}"
    $storageAccCon = (az storage account show-connection-string -g $resourceGroup -n $storageAcc -o tsv)
    return $storageAccCon
}

function Get-StorageAccountKey {
    param(
        [Parameter(Position = 0, mandatory = $true)]
        [string] $resourceGroup,
        [Parameter(Position = 0, mandatory = $true)]
        [string] $storageAcc
    )
    Write-Verbose "Getting storage account key for (${resourceGroup}) ${storageAcc}"
    $storageAccKey = az storage account keys list -g $resourceGroup -n $storageAcc --query [0].value -o tsv
    return $storageAccKey
}

function Get-EventHubRootConnectionString {
    param(
        [Parameter(Position = 0, mandatory = $true)]
        [string] $resourceGroup,
        [Parameter(Position = 0, mandatory = $true)]
        [string] $eventHubNamespace
    )
    Write-Verbose "Getting Event Hub Root Connection String for (${resourceGroup}) ${eventHubNamespace}"
    $eventHubRootKey = (az eventhubs namespace authorization-rule keys list --resource-group $resourceGroup --namespace-name $eventHubNamespace --name RootManageSharedAccessKey -o json | ConvertFrom-Json)
    return $eventHubRootKey.primaryConnectionString
}

function Initialize-SecretsInKeyVault {
    param(
        [Parameter(Position = 0, mandatory = $true)]
        [string] $keyVaultCustomerId
    )
    #Live data secrets (lda-aue1-kvl)
    Write-Verbose "Setting Live Data Secrets"

    Initialize-KeyVaultSecret -keyVaultName $sharedKeyVault -secretName "WillowCommon--$($keyVaultCustomerId)--IotHubEndpoint"
    Initialize-KeyVaultSecret -keyVaultName $sharedKeyVault -secretName "WillowCommon--$($keyVaultCustomerId)--IotHubRegWriteConnString"
    Initialize-KeyVaultSecret -keyVaultName $sharedKeyVault -secretName "WillowCommon--$($keyVaultCustomerId)--TimescaleDbConnection"

    # #platform. Note havent created forge secrets
    # Write-Verbose "Creating Empty Platform Secrets"
    Initialize-KeyVaultSecret -keyVaultName $sharedKeyVault -secretName "WillowCommon--DataProtection--StorageKey" -secretValue (Get-StorageAccountKey -resourceGroup $shrMgtRG -storageAcc $dataProtectionStorageAccount)
    Initialize-KeyVaultSecret -keyVaultName $sharedKeyVault -secretName "Common--SendGridApiKey"
    Initialize-KeyVaultSecret -keyVaultName $sharedKeyVault -secretName "DirectoryCore--1--Auth0--ClientSecret"
    Initialize-KeyVaultSecret -keyVaultName $sharedKeyVault -secretName "DirectoryCore--1--Auth0--ManagementClientSecret"
    Initialize-KeyVaultSecret -keyVaultName $sharedKeyVault -secretName "DirectoryCore--1--Auth0Mobile--ClientSecret"
    Initialize-KeyVaultSecret -keyVaultName $sharedKeyVault -secretName "DirectoryCore--1--AzureB2C--ClientSecret"
    Initialize-KeyVaultSecret -keyVaultName $sharedKeyVault -secretName "DirectoryCore--1--NotificationHub--ConnectionString"#service bus connection str
    Initialize-KeyVaultSecret -keyVaultName $sharedKeyVault -secretName "DigitalTwinCore--1--AzureDigitalTwins--ClientSecret"#use secret from app registration created by service desk

    Initialize-KeyVaultSecret -keyVaultName $sharedKeyVault -secretName "PlatformPortalXL--1--HttpClientFactory--MarketPlaceCore--Authentication--ClientSecret"
    Initialize-KeyVaultSecret -keyVaultName $sharedKeyVault -secretName "PlatformPortalXL--1--PowerBIOptions--Password"
    Initialize-KeyVaultSecret -keyVaultName $sharedKeyVault -secretName "ImageHub--1--Storages--CachedImage--Key" -secretValue (Get-StorageAccountKey -resourceGroup $pltRG -storageAcc $imageHubStorageAccount)
    Initialize-KeyVaultSecret -keyVaultName $sharedKeyVault -secretName "ImageHub--1--Storages--OriginalImage--Key" -secretValue (Get-StorageAccountKey -resourceGroup $pltRG -storageAcc $imageHubStorageAccount)
    Initialize-KeyVaultSecret -keyVaultName $sharedKeyVault -secretName "PIServerIngestionFunc--SiteToPlatformEventHubConnectionString" -secretValue (Get-EventHubRootConnectionString -resourceGroup $ldaAppRG -eventHubNamespace $siteToPlatformEventHubNamespace)
    Initialize-KeyVaultSecret -keyVaultName $sharedKeyVault -secretName "PIServerIngestionFunc--UnifiedEventHubConnectionString" -secretValue (Get-EventHubRootConnectionString -resourceGroup $ldaAppRG -eventHubNamespace $unifiedEventHubNamespace)

    Initialize-KeyVaultSecret -keyVaultName $sharedKeyVault -secretName "WillowCommon--ServiceKeyAuth--ServiceKey1"
    Initialize-KeyVaultSecret -keyVaultName $sharedKeyVault -secretName "WillowCommon--ServiceKeyAuth--ServiceKey2"
    Initialize-KeyVaultSecret -keyVaultName $sharedKeyVault -secretName "WillowCommon--ServiceKeyAuth--ServiceKeyMode"
}

function Show-StartScriptConfiguration {
    Write-Verbose $consoleLogsDivider
    Write-Verbose "Configuring Mining Azure Resources"
    Write-Verbose $consoleLogsDivider
    Write-Verbose "Azure Region: ${azureRegion}"
    Write-Verbose "Environment: ${environmentName}"
    Write-Verbose "Shared Key vault: ${sharedKeyVault}"
    Write-Verbose $consoleLogsDivider
}

function Show-EndScript {
    Write-Verbose $consoleLogsDivider
    Write-Verbose "Finished Configuring Mining Azure Resources"
    Write-Verbose $consoleLogsDivider
}

function Initialize-AdxDBUserRole {
    param(
        [Parameter(Position = 0)]
        [string]    $tenantName,

        [Parameter(Position = 1)]
        [string]    $clusterUri,

        [Parameter(Position = 2)]
        [string]    $dbName,

        [Parameter(Position = 3)]
        [string[]]    $dbViewerAppNameList,

        [Parameter(Position = 4)]
        [string[]]    $dbAdminAppNameList,

        [Parameter(Position = 5)]
        [bool]    $includeTwinPlatform
    )

    Write-Verbose "Initialising ADX database Viewers. ADX Database: ${dbName} ADX Cluster: ${clusterUri}"

    if ([string]::IsNullOrEmpty($clusterUri)) {
        Write-Verbose "Invalid ADX Cluster URI. DB Viewers not added."
        return
    }

    if ([string]::IsNullOrEmpty($dbName)) {
        Write-Verbose "Invalid ADX DB Name. DB Viewers not added."
        return
    }

    if ([string]::IsNullOrEmpty($tenantName)) {
        Write-Verbose "Invalid AAD Tenant Name. DB Viewers not added."
        return
    }

    Write-Verbose "Getting access token from ADX Cluster: ${clusterUri}"
    $token = az account get-access-token --resource $clusterUri --query accessToken --output tsv

    $headers = @{
        Authorization = "Bearer $token"
    }

    if ($null -eq $dbViewerAppNameList -or $dbViewerAppNameList.count -le 0) {
        Write-Verbose "App list is empty. DB Viewers not added."
    }
    else {
        foreach ($app in $dbViewerAppNameList) {
            $addRoleBody = '{
                "csl" : ".add database [\"' + ${dbName} + '\"] viewers (\"aadapp=' + ${app} + ';' + ${tenantName} + '\")"
            }'

            Write-Verbose "Adding db viewer ${app} from tenant ${tenantName} to ADX Database ${dbName} ADX Cluster: ${clusterUri}"
            Invoke-RestMethod -Uri $clusterUri/v1/rest/mgmt -Headers $headers -Method POST -Body $addRoleBody -ContentType "application/json; charset=utf-8"
        }
    }

    if($true -eq $includeTwinPlatform){
        $addRoleBody = '{
            "csl" : ".add database [\"' + ${dbName} + '\"] viewers (\"aadapp=' + ${twinPlatformManagedIdentityPrincipalId} + ';' + ${tenantName} + '\")"
        }'

        Write-Verbose "Adding db viewer for Twin Platform ${$twinPlatformManagedIdentityPrincipalId} from tenant ${tenantName} to ADX Database ${dbName} ADX Cluster: ${clusterUri}"
        Invoke-RestMethod -Uri $clusterUri/v1/rest/mgmt -Headers $headers -Method POST -Body $addRoleBody -ContentType "application/json; charset=utf-8"

        $addTableRoleBody = '{
            "csl" : ".add table Telemetry admins (\"aadapp=' + ${twinPlatformManagedIdentityPrincipalId} + ';' + ${tenantName} + '\")",
            "db": "' + ${dbName} + '"
        }'

        Write-Verbose "Adding Telemetry table admin for Twin Platform ${$twinPlatformManagedIdentityPrincipalId} from tenant ${tenantName} to ADX Database ${dbName} ADX Cluster: ${clusterUri}"
        Invoke-RestMethod -Uri $clusterUri/v1/rest/mgmt -Headers $headers -Method POST -Body $addTableRoleBody -ContentType "application/json; charset=utf-8"
    }

    if ($null -eq $dbAdminAppNameList -or $dbAdminAppNameList.count -le 0) {
        Write-Verbose "App list is empty. DB Admins not added."
    }
    else {
        foreach ($app in $dbAdminAppNameList) {
            $addRoleBody = '{
            "csl" : ".add database [\"' + ${dbName} + '\"] admins (\"aadapp=' + ${app} + ';' + ${tenantName} + '\")"
        }'

            Write-Verbose "Adding db admin ${app} from tenant ${tenantName} to ADX Database ${dbName} ADX Cluster: ${clusterUri}"
            Invoke-RestMethod -Uri $clusterUri/v1/rest/mgmt -Headers $headers -Method POST -Body $addRoleBody -ContentType "application/json; charset=utf-8"
        }
    }
}
#--------------------------------------------
# End Functions
#--------------------------------------------

#--------------------------------------------
# Configuration
#--------------------------------------------
Show-StartScriptConfiguration

$existingKeyVaultSecrets = Read-ExistingSecretsFromKeyVault -keyVaultName $sharedKeyVault
#Create and initialize KeyVault Secrets with actual values if known or default value otherwise
Initialize-SecretsInKeyVault -keyVaultCustomerId $customerId
Initialize-KeyVaultKey -keyVaultName $sharedKeyVault -keyName "DataProtectionKey"

#Note certificates are manually configured (wil-ncp-lda-shr-aue1-kvl willowinc cert)

#Platform Configuration
Initialize-AppSettings-FromJson -appName $workflowCoreApp -resourceGroup $pltRG -configJsonFilePath $PSScriptRoot\platform\workflowcore.config.json
Initialize-AppSettings-FromJson -appName $portalXlApp -resourceGroup $pltRG -configJsonFilePath $PSScriptRoot\platform\portalxl.config.json
Initialize-AppSettings-FromJson -appName $imageHubApp -resourceGroup $pltRG -configJsonFilePath $PSScriptRoot\platform\imagehub.config.json
Initialize-AppSettings-FromJson -appName $directoryCoreApp -resourceGroup $pltRG -configJsonFilePath $PSScriptRoot\platform\directorycore.config.json

Initialize-AdxDBUserRole -tenantName $aadTenantName -clusterUri $adxClusterUri -dbName $adxDbName -includeTwinPlatform $true

#Livedata and Ingestion Function App Configuration
Initialize-FunctionAppSettings-FromJson -functionAppName $piServerIngestionFunc -resourceGroup $ldaAppRG -configJsonFilePath $PSScriptRoot\livedata\piserveringestionfunc.config.json

#Give twin platform managed identity shared kvl permissions
az keyvault set-policy -n $sharedKeyVault --key-permissions get list wrapkey unwrapkey --secret-permissions get list --object-id $twinPlatformManagedIdentityPrincipalId

#Grant Frontdoor access (Guid: ad0e1c7e-6d38-4ba4-9efd-0bc77ba9f037) to shared keyvault - see https://docs.microsoft.com/en-us/azure/frontdoor/front-door-custom-domain-https
az keyvault set-policy -n $sharedKeyVault --certificate-permissions get --secret-permissions get --object-id "ad0e1c7e-6d38-4ba4-9efd-0bc77ba9f037"

Show-EndScript
#--------------------------------------------
# End Configuration
#--------------------------------------------