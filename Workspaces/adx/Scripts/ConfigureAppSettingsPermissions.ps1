param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $environmentName, #dev

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $azureRegion, #aue2

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $customerName,

    [Parameter(Mandatory = $true)]
    [string]    $adxClusterUri, #https://clustername.location.kusto.windows.net

    [Parameter(Mandatory = $true)]
    [string]    $adxDbName,

    [Parameter(Mandatory = $true)]
    [string]    $aadTenantName #willowinc.com
)

#--------------------------------------------
# Variables
#--------------------------------------------
#Common
$companyPrefix = "wil"
$sharedResourcesPrefix = "shr"
$ldaResourcesPrefix = "lda"
$sharedAzurePrefix = "${companyPrefix}-${environmentName}-${sharedResourcesPrefix}-${azureRegion}"
$sharedKeyVault = "${sharedAzurePrefix}-kvl"
$consoleLogsDivider = "-----------------------------------"

#Livedata-Core & Customer
$liveDataRG = "t3-${companyPrefix}-${environmentName}-${ldaResourcesPrefix}-${azureRegion}-app-rsg"
$customerRg = "t3-${companyPrefix}-${environmentName}-${ldaResourcesPrefix}-${customerName}-${azureRegion}-app-rsg"
$liveDataCoreApp = "${companyPrefix}-${environmentName}-${ldaResourcesPrefix}-${azureRegion}-livedatacore"
$adaptorFnApp = "${companyPrefix}-${environmentName}-${ldaResourcesPrefix}-${customerName}-${azureRegion}-adaptortouie"
$unifiedEventHub = "${companyPrefix}-${environmentName}-${ldaResourcesPrefix}-${azureRegion}-uie"

#--------------------------------------------
# End Variables
#--------------------------------------------

#--------------------------------------------
# Functions
#--------------------------------------------
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

function Show-StartScriptConfiguration {
    Write-Verbose $consoleLogsDivider
    Write-Verbose "Configuring IoT Services Azure Resources"
    Write-Verbose $consoleLogsDivider
    Write-Verbose "Azure Region: ${azureRegion}"
    Write-Verbose "Environment: ${environmentName}"
    Write-Verbose "Customer Name: ${customerName}"
    Write-Verbose "Shared Key vault: ${sharedKeyVault}"
    Write-Verbose $consoleLogsDivider
}

function Show-EndScript {
    Write-Verbose $consoleLogsDivider
    Write-Verbose "Finished Configuring IoT Services Azure Resources"
    Write-Verbose $consoleLogsDivider
}

function Initialize-AdxDBUserRole {
    param(
        [Parameter(Position = 0)]
        [string[]]    $tenantName,

        [Parameter(Position = 1)]
        [string[]]    $clusterUri,

        [Parameter(Position = 2)]
        [string[]]    $dbName,

        [Parameter(Position = 3)]
        [string[]]    $dbViewerAppNameList,

        [Parameter(Position = 4)]
        [string[]]    $dbAdminAppNameList
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

Initialize-AdxDBUserRole -tenantName $aadTenantName -clusterUri $adxClusterUri -dbName $adxDbName -dbViewerAppNameList $liveDataCoreApp

#Livedata-core and Adaptor App Configuration
Initialize-FunctionAppSettings-FromJson -functionAppName $adaptorFnApp -resourceGroup $customerRg -configJsonFilePath $PSScriptRoot\adaptor.config.json
#TODO Reenable configuring livedata-core customer specific appsettings when ready to go live
#Initialize-AppSettings-FromJson -appName $liveDataCoreApp -resourceGroup $liveDataRG -configJsonFilePath $PSScriptRoot\livedatacore.config.json

Show-EndScript
#--------------------------------------------
# End Configuration
#--------------------------------------------