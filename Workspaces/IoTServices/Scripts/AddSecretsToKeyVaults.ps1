<#
Overview
------------------------------------------------------------------------------------------------------------------
This script is based on the similar script for the service key auth remediation work and does the following:
Accepts secretName, secretValue and target keyvault name as parameters and
creates secrets and will only update if provided values are different from stored
There is also a parameter to specify a dry run to see the effect of running the pipeline
Provide full secret name including any prefix and suffix required
 
Usage
------------------------------------------------------------------------------------------------------------------

Recommended:
Use the release pipeline under IoT Services folder for AzurePlatform repo

Manual: 
.\AddSecretsToKeyVaults.ps1 -secretValue "<somevalue>" -secretName "WillowCommon--testSecret" -keyvaultName "wil-dev-iot-dep-aue1-kvl"  -liveRun $false

References
------------------------------------------------------------------------------------------------------------------
https://docs.microsoft.com/en-us/cli/azure/keyvault/key?view=azure-cli-latest#az_keyvault_key_create
https://docs.microsoft.com/en-us/powershell/module/az.keyvault/set-azkeyvaultaccesspolicy?view=azps-8.1.0
#>
[CmdletBinding()]
param (
    [Parameter(mandatory = $true)]
    [string] $secretValue,
    [Parameter(mandatory = $true)]
    [string] $secretName,
    [Parameter(mandatory = $true)]
    [string] $keyvaultName,
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

Write-Output "-----------------------------------------------------------"
Write-Output "Setting up Keyvault secrets"
Write-Output "-----------------------------------------------------------"
Write-Output "SecretName: ${secretName}"
Write-Output "KeyvaultName: ${keyvaultName}"
Write-Output "Live Run Mode: ${liveRun}"
Write-Output "-----------------------------------------------------------"

Write-Output "Initializing secret setup"

Initialize-KeyVaultSecret -keyVaultName $keyVaultName -secretName "${secretName}" -secretValue $secretValue

Write-Output "Completed secret setup"