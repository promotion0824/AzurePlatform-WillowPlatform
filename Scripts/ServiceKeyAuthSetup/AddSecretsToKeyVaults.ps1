<#
Overview
------------------------------------------------------------------------------------------------------------------
This script is for the service key auth remediation work and does the following:
For each keyvault adds secret Get, Set and List access policy to adGroupObjectId passed in
Creates 3 secrets and will only update if provided values are different from stored

Pre-req
------------------------------------------------------------------------------------------------------------------
Needs AZ Powershell module installed (not the AzuerRM version!). This can be installed with: Install-Module -Name Az
Connect-AzAccount -SubscriptionId '249312a0-4c83-4d73-b164-18c5e72bf219' (Sandbox)
Connect-AzAccount -SubscriptionId '0be01d84-8432-4558-9aba-ecd204a3ee61' (Platform-DEV)

Usage
------------------------------------------------------------------------------------------------------------------

Sandbox:
.\AddSecretsToKeyVaults.ps1 -serviceKey1 "nd*lv6XM@CcDmEaQcpXF7z@h44iTdV*E" -serviceKey2 "7sTG12RXDMAOY#MXXSX*r8oK*kdFPA9P" -serviceKeyMode "report-only" -willowEnv "sandbox" -adGroupObjectId "6c4d858d-336b-4c48-8893-d21efc77105d" -liveRun $false

Dev:
.\AddSecretsToKeyVaults.ps1 -serviceKey1 "nd*lv6XM@CcDmEaQcpXF7z@h44iTdV*E" -serviceKey2 "7sTG12RXDMAOY#MXXSX*r8oK*kdFPA9P" -serviceKeyMode "report-only" -willowEnv "dev" -adGroupObjectId "6c4d858d-336b-4c48-8893-d21efc77105d" -liveRun $false



References
------------------------------------------------------------------------------------------------------------------
https://docs.microsoft.com/en-us/cli/azure/keyvault/key?view=azure-cli-latest#az_keyvault_key_create
https://docs.microsoft.com/en-us/powershell/module/az.keyvault/set-azkeyvaultaccesspolicy?view=azps-8.1.0
#>

param (
    [Parameter(mandatory = $true)]
    [string] $serviceKey1,
    [Parameter(mandatory = $true)]
    [string] $serviceKey2,
    [Parameter(mandatory = $true)]
    [string] $serviceKeyMode,
    [Parameter(mandatory = $true)]
    [string] $willowEnv,
    [Parameter(mandatory = $true)]
    [string] $adGroupObjectId,
    [Parameter(mandatory = $true)]
    [bool] $liveRun                
)

function Read-ExistingSecretsFromKeyVault {
    param(
        [Parameter(Position = 0, mandatory = $true)]
        [string] $keyVaultName
    )

    $keyVaultSecrets = az keyvault secret list --vault-name $keyVaultName -o json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        Write-Output "Get key vault $keyVaultName secrets resulted in exit code $LASTEXITCODE"
    }

    return $keyVaultSecrets;
}

function Initialize-KeyVaultSecret {
    param(
        [Parameter(Position = 0, mandatory = $true)]
        [string] $keyVaultName,
        [Parameter(Position = 1, mandatory = $true)]
        [string] $secretName,
        [Parameter(Position = 2, mandatory = $false)]
        [string] $secretValue = ""
    )
    $existingKeyVaultSecrets = Read-ExistingSecretsFromKeyVault -keyVaultName $keyVaultName    

    $foundKeyVaultSecrets = $existingKeyVaultSecrets | Where-Object { $_.name -eq $secretName }      

    if ($foundKeyVaultSecrets.count -eq 0) {
        Write-Output "Creating Keyvault Secret ${secretName} in ${keyVaultName}"
        if ($secretValue -eq "") {
            $secretValue = "Default Value"
        }

        if($liveRun -eq $true){        
            az keyvault secret set --vault-name $keyVaultName --name $secretName --value $secretValue

            if ($LASTEXITCODE -ne 0) {
                Write-Output "Creating Keyvault Secret ${secretName} in ${keyVaultName} resulted in exit code $LASTEXITCODE"
            }
            else {
                Write-Output "Created Keyvault Secret ${secretName} in ${keyVaultName} successfully"
            }
        }
        else {
            Write-Output "Not live run so no secrets created"
        }       
        
    }
    else {
        $keyVaultSecret = az keyvault secret show --vault-name $keyVaultName --name $secretName | ConvertFrom-Json
        #$secretValue -eq "" is required to prevent manually set secrets from being replaced by empty string
        if (($keyVaultSecret.value -eq $secretValue) -or ($secretValue -eq "")) {
            Write-Output "Keyvault Secret ${secretName} in ${keyVaultName} already exists"
        }
        else {
            Write-Output "Replacing Keyvault Secret ${secretName} in ${keyVaultName}"

            if($liveRun -eq $true){ 
                az keyvault secret set --vault-name $keyVaultName --name $secretName --value $secretValue
                if ($LASTEXITCODE -ne 0) {
                    Write-Output "Replacing Keyvault Secret ${secretName} in ${keyVaultName} resulted in exit code $LASTEXITCODE"
                }
                else {
                    Write-Output "Replaced Keyvault Secret ${secretName} in ${keyVaultName} successfully"
                }
            }
            else {
                 Write-Output "Not live run so no secrets created"
            }            
        }
    }
}


function SetupKeyVaultAccessPermissions {
    param(
        [Parameter(Position = 0, mandatory = $true)]
        [string] $keyVaultName
    )
    
    $minimumKeyVaultPermissionsRequired = @('Get','Set','List')
    $currentKeyVault = Get-AzKeyVault -VaultName $keyVaultName          
    $currentAccessPoliciesForAdObject = $currentKeyVault.AccessPolicies.where{$_.ObjectId -match $adGroupObjectId}  
            
    if(
        ($currentAccessPoliciesForAdObject -eq $null) -or 
        ($currentAccessPoliciesForAdObject.PermissionsToSecrets.Count -eq 0)
       ){

        Write-Host "No secret permissions exist for AD objectId ${adGroupObjectId} in keyvault ${keyVaultName} so creating now"

        if($liveRun -eq $true){
            Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -ObjectId $adGroupObjectId -PermissionsToSecrets $minimumKeyVaultPermissionsRequired    
        }
        else {
            Write-Output "Not Live Run so no permissions created"
        }                      
    }
    else 
    {   
        
        Write-Host "Existing secret permissions found for AD objectId ${adGroupObjectId} in keyvault ${keyVaultName}: ${currentAccessPoliciesForAdObject.PermissionsToSecretsStr}"
        
        $currentSecretPermissions = $currentAccessPoliciesForAdObject.PermissionsToSecrets

        Write-Host "Current Secret Permissions: ${currentSecretPermissions}"

        #Azure returns a string if just single permission rather than an array :S
        if($currentSecretPermissions -is [string]){
            $currentSecretPermissions = @($currentSecretPermissions)
        }
            
        if(
            (-Not $currentSecretPermissions.Contains('Get')) -or 
            (-Not $currentSecretPermissions.Contains('List')) -or 
            (-Not $currentSecretPermissions.Contains('Set'))
          ){
        
            Write-Host "Keyvault ${keyVaultName} is missing required permissions for AD objectId ${adGroupObjectId}"

            #copy existing permissions then add any missing            
            $newPermissionSet = $currentSecretPermissions.Clone()                    
                        
            $minimumKeyVaultPermissionsRequired | ForEach-Object {
                 
                if(-not $newPermissionSet.contains($_)){
                    Write-Host "Adding permission ${_}"
                    $newPermissionSet += $_
                }
                                     
            }

            $newPermissionSet = [string[]] $newPermissionSet    
            
            Write-Host "Final permissions to set: {$newPermissionSet}"


            if($liveRun -eq $true){
                Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -ObjectId $adGroupObjectId -PermissionsToSecrets $newPermissionSet  
            }
            else {
                Write-Output "Not Live Run so no permissions modified"
            }
                                
       }
       else {
            Write-Host "AD objectId ${adGroupObjectId} has required minimum permissions for keyvault ${keyVaultName} so no changes required"
            
            if($liveRun -ne $true){
                Write-Output "Not Live Run so no permissions modified"
            }
       }              
      
    }           
    
}

function SetupServiceKeySecrets {
    param(
        [Parameter(Position = 0, mandatory = $true)]
        [string] $keyVaultName,
        [Parameter(Position = 1, mandatory = $true)]
        [string] $secretNamePrefix,
        [Parameter(Position = 2, mandatory = $true)]
        [bool] $addKeyVaultPermission
    )

    if($addKeyVaultPermission -eq $true){
        Write-Output "addKeyVaultPermission set to true so changing access permissions"
        SetupKeyVaultAccessPermissions -keyVaultName $keyVaultName
    }
    else{
         Write-Output "addKeyVaultPermission set to false so not changing access permissions"
    }
    
    Initialize-KeyVaultSecret -keyVaultName $keyVaultName -secretName "${secretNamePrefix}ServiceKeyAuth--ServiceKey1" -secretValue $serviceKey1
    Initialize-KeyVaultSecret -keyVaultName $keyVaultName -secretName "${secretNamePrefix}ServiceKeyAuth--ServiceKey2" -secretValue $serviceKey2
    Initialize-KeyVaultSecret -keyVaultName $keyVaultName -secretName "${secretNamePrefix}ServiceKeyAuth--ServiceKeyMode" -secretValue $serviceKeyMode
}

Write-Output "-----------------------------------------------------------"
Write-Output "Setting up service-key Keyvault secrets and permissions"
Write-Output "-----------------------------------------------------------"
Write-Output "Env: ${willowEnv}"
Write-Output "ServiceKey1: ${serviceKey1}"
Write-Output "ServiceKey2: ${serviceKey2}"
Write-Output "ServiceKeyMode: ${serviceKeyMode}"
Write-Output "AD Group: ${adGroupObjectId}"
Write-Output "Live Run Mode: ${liveRun}"
Write-Output "-----------------------------------------------------------"

Write-Output "Begin secret setup for ${willowEnv}"

if ($willowEnv -eq "sandbox")
{
    SetupServiceKeySecrets -keyVaultName "ServiceKeyTesting2" -secretNamePrefix "Common--" -addKeyVaultPermission $true 
}

if ($willowEnv -eq "dev")
{       
    #Real Estate
    SetupServiceKeySecrets -keyVaultName "wil-dev-plt-aue1-kvl" -secretNamePrefix "Common--" -addKeyVaultPermission $true
    SetupServiceKeySecrets -keyVaultName "wil-dev-plt-eu21-kvl" -secretNamePrefix "Common--" -addKeyVaultPermission $true 

    #Real Estate Admin
    SetupServiceKeySecrets -keyVaultName "wil-dev-adm-aue1-kvl" -secretNamePrefix "Common--" -addKeyVaultPermission $true 
    
    #Livedata
    SetupServiceKeySecrets -keyVaultName "wil-dev-lda-aue1-kvl" -secretNamePrefix "WillowCommon--" -addKeyVaultPermission $true
    SetupServiceKeySecrets -keyVaultName "wil-dev-lda-shr-aue1-kvl" -secretNamePrefix "WillowCommon--" -addKeyVaultPermission $true
    SetupServiceKeySecrets -keyVaultName "wil-dev-lda-eu21-kvl" -secretNamePrefix "WillowCommon--" -addKeyVaultPermission $true
    SetupServiceKeySecrets -keyVaultName "wil-dev-lda-shr-eu21-kvl" -secretNamePrefix "WillowCommon--" -addKeyVaultPermission $true

    #Marketplace
    SetupServiceKeySecrets -keyVaultName "wil-dev-mkp-aue1-kvl" -secretNamePrefix "Common--" -addKeyVaultPermission $true
}


if ($willowEnv -eq "uat")
{       
    #Real Estate
    SetupServiceKeySecrets -keyVaultName "wil-uat-plt-aue1-kvl" -secretNamePrefix "Common--" -addKeyVaultPermission $true
    SetupServiceKeySecrets -keyVaultName "wil-uat-plt-eu21-kvl" -secretNamePrefix "Common--" -addKeyVaultPermission $true 

    #Real Estate Admin
    SetupServiceKeySecrets -keyVaultName "wil-uat-adm-aue1-kvl" -secretNamePrefix "Common--" -addKeyVaultPermission $true 
    
    #Livedata
    SetupServiceKeySecrets -keyVaultName "wil-uat-lda-aue1-kvl" -secretNamePrefix "WillowCommon--" -addKeyVaultPermission $true
    SetupServiceKeySecrets -keyVaultName "wil-uat-lda-shr-aue1-kvl" -secretNamePrefix "WillowCommon--" -addKeyVaultPermission $true
    SetupServiceKeySecrets -keyVaultName "wil-uat-lda-shr-eu21-kvl" -secretNamePrefix "WillowCommon--" -addKeyVaultPermission $true
    SetupServiceKeySecrets -keyVaultName "wil-uat-lda-shr-eu22-kvl" -secretNamePrefix "WillowCommon--" -addKeyVaultPermission $true

    #Marketplace
    SetupServiceKeySecrets -keyVaultName "wil-uat-mkp-aue1-kvl" -secretNamePrefix "Common--" -addKeyVaultPermission $true
}


if ($willowEnv -eq "prd")
{   
    #prd keyvaults will require PIM request which will temporarily add to group so dont change key vault permissions
        
    #Real Estate
    SetupServiceKeySecrets -keyVaultName "wil-prd-plt-aue2-kvl" -secretNamePrefix "Common--" -addKeyVaultPermission $false
    SetupServiceKeySecrets -keyVaultName "wil-prd-plt-eu22-kvl" -secretNamePrefix "Common--" -addKeyVaultPermission $false
    SetupServiceKeySecrets -keyVaultName "wil-prd-plt-weu2-kvl" -secretNamePrefix "Common--" -addKeyVaultPermission $false  

    #Real Estate Admin
    SetupServiceKeySecrets -keyVaultName "wil-prd-adm-aue2-kvl" -secretNamePrefix "Common--" -addKeyVaultPermission $false 
    
    #Livedata
    SetupServiceKeySecrets -keyVaultName "wil-prd-lda-aue2-kvl" -secretNamePrefix "WillowCommon--" -addKeyVaultPermission $false
    SetupServiceKeySecrets -keyVaultName "wil-prd-lda-shr-aue2-kvl" -secretNamePrefix "WillowCommon--" -addKeyVaultPermission $false
    SetupServiceKeySecrets -keyVaultName "wil-prd-lda-eu22-kvl" -secretNamePrefix "WillowCommon--" -addKeyVaultPermission $false
    SetupServiceKeySecrets -keyVaultName "wil-prd-lda-shr-eu22-kvl" -secretNamePrefix "WillowCommon--" -addKeyVaultPermission $false
    SetupServiceKeySecrets -keyVaultName "wil-prd-lda-weu2-kvl" -secretNamePrefix "WillowCommon--" -addKeyVaultPermission $false
    SetupServiceKeySecrets -keyVaultName "wil-prd-lda-shr-weu2-kvl" -secretNamePrefix "WillowCommon--" -addKeyVaultPermission $false

    #Marketplace
    SetupServiceKeySecrets -keyVaultName "wil-prd-mkp-aue2-kvl" -secretNamePrefix "Common--" -addKeyVaultPermission $false
    SetupServiceKeySecrets -keyVaultName "wil-prd-mkp-eu22-kvl" -secretNamePrefix "Common--" -addKeyVaultPermission $false
}

if ($willowEnv -eq "experience-dev")
{       
    #Experience
    SetupServiceKeySecrets -keyVaultName "wil-uxa-dev-key-aue" -secretNamePrefix "WillowCommon--" -addKeyVaultPermission $true
    SetupServiceKeySecrets -keyVaultName "wil-dev-exp-aue1-glb-kvl" -secretNamePrefix "WillowCommon--" -addKeyVaultPermission $true
    SetupServiceKeySecrets -keyVaultName "wil-dev-fnb-aue1-kvl" -secretNamePrefix "WillowCommon--" -addKeyVaultPermission $true
}

if ($willowEnv -eq "experience-uat")
{       
    #Experience
    SetupServiceKeySecrets -keyVaultName "wil-uxa-uat-key-aue" -secretNamePrefix "WillowCommon--" -addKeyVaultPermission $true
    SetupServiceKeySecrets -keyVaultName "wil-uat-exp-aue1-glb-kvl" -secretNamePrefix "WillowCommon--" -addKeyVaultPermission $true
}

if ($willowEnv -eq "experience-prd")
{   
    #Experience
    SetupServiceKeySecrets -keyVaultName "wil-uxa-prd-key-aue" -secretNamePrefix "WillowCommon--" -addKeyVaultPermission $false
    SetupServiceKeySecrets -keyVaultName "wil-prd-exp-aue1-glb-kvl" -secretNamePrefix "WillowCommon--" -addKeyVaultPermission $false
}

Write-Output "Completed secret setup for ${willowEnv}"