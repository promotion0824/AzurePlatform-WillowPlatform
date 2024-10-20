param(
    [Parameter(Mandatory = $true)]
    [string]    $mgtResourceGroup,
    [Parameter(Mandatory = $true)]
    [string]    $appResourceGroup,
    [string]    $slotName = 'staging',
    [string[]]  $keyPermissions = @('get'),
    [string[]]  $secretPermissions = @('get', 'list'),
    [string[]]  $certificatePermissions = @(),
    [string[]]  $excludeWebApps = @(),
    [string[]]  $includeResourceGroups = @('lda-[a-z0-9]*-app', 'plt-[a-z0-9]*-app', 'adm-[a-z0-9]*-app'),
    [switch]    $processAllWebApps,
    [string]    $defaultRegion = 'aue',
    [string]    $environment = 'dev',
    [string]    $project = 'platform',
    [int]       $zone = 1,
    [int]       $tier = 3
)

#$mgtResourceGroup = 't2-wil-uxa-$(environment)-rsg-mgt-$(deploymentRegionShortcode)'
#$appResourceGroup = 't3-wil-uxa-$(environment)-rsg-app-$(deploymentRegionShortcode)'

Write-Host "`$mgtResourceGroup: [$mgtResourceGroup]"
Write-Host "`$appResourceGroup: [$appResourceGroup]"

## custom filter functions
filter Where-Match($Selector, [String[]]$Like, [String[]]$Regex) {
    if ($Selector -is [String]) { $Value = $_.$Selector }
    elseif ($Selector -is [ScriptBlock]) { $Value = &$Selector }
    else { throw 'Selector must be a ScriptBlock or property name' }

    if ($Like.Length) {
        foreach ($Pattern in $Like) {
            if ($Value -like $Pattern) { return $_ }
        }
    }

    if ($Regex.Length) {
        foreach ($Pattern in $Regex) {
            if ($Value -match $Pattern) { return $_ }
        }
    }
}
filter Where-NotMatch($Selector, [String[]]$Like, [String[]]$Regex) {
    if ($Selector -is [String]) { $Value = $_.$Selector }
    elseif ($Selector -is [ScriptBlock]) { $Value = &$Selector }
    else { throw 'Selector must be a ScriptBlock or property name' }

    if ($Like.Length) {
        foreach ($Pattern in $Like) {
            if ($Value -like $Pattern) { return }
        }
    }

    if ($Regex.Length) {
        foreach ($Pattern in $Regex) {
            if ($Value -match $Pattern) { return }
        }
    }

    return $_
}

function addKeyVaultAccessPolicy (
    [string] $resourceGroupName,
    [string] $keyVaultName,
    [string] $webAppName,
    [guid]   $webAppIdentity
) {
    Write-Host "Processing webApp: [$webAppName]"
    
    Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -ObjectId $webAppIdentity `
        -PermissionsToKeys $keyPermissions `
        -PermissionsToSecrets $secretPermissions `
        -PermissionsToCertificates $certificatePermissions `
        -BypassObjectIdValidation
    
    Write-Host "Getting slot with name: [$slotName]"
    $slot = $null
    $slot = Get-AzWebAppSlot -ResourceGroupName $resourceGroupName -Slot $slotName -Name $webAppName -ErrorAction SilentlyContinue
    
    if ($null -ne $slot) {
        Write-Host "Processing webAppSlot: [$($slot.Name)]"
        $webAppSlotIdentity = $slot.Identity
        
        if ($null -eq $webAppSlotIdentity) { continue }
        Write-Host $webAppSlotIdentity.PrincipalId
        
        Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -ObjectId $webAppSlotIdentity.PrincipalId `
            -PermissionsToKeys $keyPermissions `
            -PermissionsToSecrets $secretPermissions `
            -PermissionsToCertificates $certificatePermissions `
            -BypassObjectIdValidation
    }
    else {
        Write-Host "No slot exists for app [$webAppName] under resource group [$resourceGroupName]"
    }
}

function removeKeyVaultAccessPolicy (
    [string] $resourceGroupName,
    [string] $keyVaultName,
    [string] $webAppName,
    [guid]   $webAppIdentity
) {
    Write-Host "Processing webApp: [$webAppName]"
    
    Remove-AzKeyVaultAccessPolicy -VaultName $keyVaultName -ObjectId $webAppIdentity

    Write-Host "Getting slot with name: [$slotName]"
    $slotToFilter = $null
    $slotToFilter = Get-AzWebAppSlot -ResourceGroupName $resourceGroupName -Slot $slotName -Name $webAppName -ErrorAction SilentlyContinue
        
    if ($null -ne $slotToFilter) {
        Write-Host "Processing webAppSlotToRemove: [$($slotToFilter.Name)]"
        $webAppSlotIdentity = $slotToFilter.Identity
            
        if ($null -eq $webAppSlotIdentity) { continue }
        Write-Host $webAppSlotIdentity.PrincipalId
            
        Remove-AzKeyVaultAccessPolicy -VaultName $keyVaultName -ObjectId $webAppSlotIdentity.PrincipalId
    }
    else {
        "No slot exists for app [$webAppName] under resource group [$resourceGroupName]"
    }
}

## main
try {
    Write-Host "Process all web apps for shared keyVault mode: [$processAllWebApps]"
    
    ## get shared resource group against defaultRegion if processingAllWebApps
    if ($processAllWebApps) {
        $replaceString = "{0}{1}" -f $defaultRegion, $zone
        $sharedResourceGroup = $mgtResourceGroup -replace "-shr-[a-z0-9]*-mgt-rsg", "-shr-$replaceString-mgt-rsg"
        Write-Host "`$sharedResourceGroup replaced: [$sharedResourceGroup]"
    }
    else {
        $sharedResourceGroup = $mgtResourceGroup
    }

    ## find keyVault against the resource group
    $kv = Get-AzKeyVault -ResourceGroupName $sharedResourceGroup -ErrorAction Stop | Select-Object -First 1
    Write-Host "keyVault name: [$($kv.VaultName)]"
    
    ## get keyVault object
    $keyVault = Get-AzKeyVault -VaultName $kv.VaultName
    Write-Host "`$keyVault accessPolicies count: [$($keyVault.AccessPolicies.Count)]"

    $objKeyVaultAccessPolicies = $keyVault.AccessPolicies | % {
        @{
            objectid       = $_.ObjectId
            keypermissions = $_.PermissionsToKeysStr
        }
    }

    if ($processAllWebApps) {
        $resourceFilterTags = @{ "project" = "$project"; "zone" = $zone; "tier" = $tier; "environment" = "$environment"; }
        $arrFilter = $null
        $filterScriptBlock = $null
        foreach ($tag in $resourceFilterTags.GetEnumerator()) {
            $arrFilter += ("`$_.tags.$($tag.key) -eq '$($tag.value)'")
        }

        $filter = $arrFilter.Replace("`'$", "' -and `$")
        $filterScriptBlock = [scriptblock]::Create($filter)
        
        $allAppServices = (Get-AzResource -ResourceType Microsoft.Web/sites).where($filterScriptBlock)
        Write-Host "`$allAppServices count: [$($allAppServices.Count)]"

        $filteredApps = $allAppServices | `
            Where-Match ResourceGroupName -Regex $includeResourceGroups | `
            Where-NotMatch Name -Like $excludeWebApps

        Write-Host "`$filteredApps count: [$($filteredApps.Count)]"

        if ($null -eq $filteredApps) { 
            Write-Host "No webApps returned against the filter [project, tier, environment]" 
            return 
        }

        $filteredApps | ForEach-Object {
            Write-Host "*Processing app [$($_.Name)] under resource group [$($_.ResourceGroupName)]"
            $app = Get-AzWebApp -ResourceGroupName $_.ResourceGroupName -Name $_.Name
            $webAppIdentity = $app.Identity
                
            if ($null -eq $webAppIdentity) { 
                Write-Host "Identity not found for app: [$($_.Name)]" 
                continue 
            }

            Write-Host "Processing Identity [$($webAppIdentity.PrincipalId)]"
            
            if ($webAppIdentity.PrincipalId -notin $objKeyVaultAccessPolicies.objectid) {
                addKeyVaultAccessPolicy -resourceGroupName $app.ResourceGroup `
                    -keyVaultName $keyVault.VaultName `
                    -webAppName $app.Name `
                    -webAppIdentity $webAppIdentity.PrincipalId
            }
            else {
                Write-Host "[$processAllWebApps] Identity [$($webAppIdentity.PrincipalId)] already exists against the keyVault [$($keyVault.VaultName)]"
            }
        }
    }
    
    else {
        ## add access policies for all apps in resource group except excluded
        $webApps = Get-AzWebApp -ResourceGroupName $appResourceGroup -ErrorAction Stop
        Write-Host "webApps count: [$($webApps.Count)]"

        $webAppsToAssign = $webApps | Where-NotMatch Name -Like $excludeWebApps
        Write-Host "`$webAppsToAssign count: [$($webAppsToAssign.Count)]"
    
        $webAppsToAssign | ForEach-Object {
            Write-Host "**Processing webAppToAssign: [$($_.Name)]"
            $webAppIdentity = $_.Identity
        
            if ($null -eq $webAppIdentity) { 
                Write-Host "Identity not found for app: [$($_.Name)]" 
                continue 
            }

            Write-Host $webAppIdentity.PrincipalId

            if ($webAppIdentity.PrincipalId -notin $objKeyVaultAccessPolicies.objectid) {
                addKeyVaultAccessPolicy -resourceGroupName $_.ResourceGroup `
                    -keyVaultName $keyVault.VaultName `
                    -webAppName $_.Name `
                    -webAppIdentity $webAppIdentity.PrincipalId
            } 
            else {
                Write-Host "[$processAllWebApps] Identity [$($webAppIdentity.PrincipalId)] already exists against the keyVault [$($keyVault.VaultName)]"
            }
        }

        ## clean unwanted access policies if there are webApps to exclude
        $webAppsToRemove = $webApps | Where-Match Name -Like $excludeWebApps
        Write-Host "`$webAppsToRemove count: [$($webAppsToRemove.Count)]"

        $webAppsToRemove | ForEach-Object {
            Write-Host "***Processing webAppToClean: [$($_.Name)]"
            $webAppIdentity = $_.Identity
        
            if ($null -eq $webAppIdentity) { 
                Write-Host "Identity not found for app: [$($_.Name)]" 
                continue 
            }

            Write-Host $webAppIdentity.PrincipalId

            if ($webAppIdentity.PrincipalId -in $objKeyVaultAccessPolicies.objectid) {
                removeKeyVaultAccessPolicy -resourceGroupName $_.ResourceGroup `
                    -keyVaultName $keyVault.VaultName `
                    -webAppName $_.Name `
                    -webAppIdentity $webAppIdentity.PrincipalId
            }
            else {
                Write-Host "Identity [$($webAppIdentity.PrincipalId)] does not exist against the keyVault [$($keyVault.VaultName)]"
            }
        }
    }
}
catch {
    throw $_
}
