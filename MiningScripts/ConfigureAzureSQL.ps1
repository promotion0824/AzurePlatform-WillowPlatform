[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $sqlServerPrefix,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $appServicePrefix,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $appServiceSuffix,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $twinPlatformManagedIdentityPrincipalId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $authApiManagedIdentityPrincipalId
)

$subscriptionId = $env:ARM_SUBSCRIPTION_ID
$tenantId = $env:ARM_TENANT_ID
$clientId = $env:ARM_CLIENT_ID
$secret = $env:ARM_CLIENT_SECRET

Write-Verbose "Logging in to azure"
az login --service-principal --username $clientId --password $secret --tenant $tenantId
az account set --subscription $subscriptionId

$accessTokenUri = "https://database.windows.net"
$sqlServer = "${sqlServerPrefix}sql.database.windows.net"

# Format: appService => (suffix, list-of-dbs)
[hashtable]$appServiceDBHash = [ordered]@{
    workflowcore    = @("plt", ("WorkflowCoreDB"));
    directorycore   = @("plt", ("DirectoryCoreDB"));
}

Write-Verbose "Getting access token from Azure SQL: ${sqlServer}"
$token = az account get-access-token --resource $accessTokenUri --query accessToken --output tsv

# Based on: https://github.com/MicrosoftDocs/sql-docs/issues/2323#issuecomment-652907219
function Get-SqlByteLiteral {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]    $stringValue
    )
    $objectGuid = [System.GUID]::Parse($stringValue.Replace("""", ""))
    $byteArray = $objectGuid.ToByteArray()
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('0x')

    foreach ($byte in $byteArray) {
        $byteToString = [System.BitConverter]::ToString($byte)
        [void]$sb.Append($byteToString)
    }

    return $sb.ToString().Replace("""", "")
}

function Get-AppIdAsSQLByteLiteral {
    param(
        [Parameter(Mandatory = $false)]
        [string]    $appServiceName,

        [Parameter(Mandatory = $false)]
        [string]    $managedIdentityPrincipalId
    )
    $appId = $null

    if(![string]::IsNullOrEmpty($appServiceName)){
        $appId = az ad sp list --display-name $appServiceName --query [0].appId
    }
    elseif (![string]::IsNullOrEmpty($managedIdentityPrincipalId)){
        $appId = az ad sp show --id $managedIdentityPrincipalId --query appId
        Write-Verbose "Twin Platform App Id: '${appId}'"
    }
    else {
        Write-Verbose "Either App Service name or Managed Identity Principal Id is required."
        return ""
    }

    if($null -eq $appId)
    {
        Write-Error "App service ${appServiceName} was not found in the current subscription ${subscriptionId}."
    }

    return (Get-SqlByteLiteral -stringValue $appId)
}

# Based on: https://github.com/betr-io/terraform-provider-mssql/pull/1/files#diff-0c3ec3c71840b2251e66d6b908c9f6053f81109fc88648721a055b8b02cade8d
# Might need to change if updates are released by Microsoft
function Add-DatabaseUser {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]    $appName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]    $principalIdAsSqlByteLiteral,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]    $databases
    )
    $createUserScript = "IF NOT EXISTS(SELECT * FROM SYS.database_principals WHERE NAME = '$appName')
        CREATE USER [$appName] WITH SID=${principalIdAsSqlByteLiteral}, TYPE=E"
    $addRoleScript = "EXEC sp_addrolemember db_owner, [$appName]"

    Write-Verbose "Adding user $appName in master DB in Azure SQL: ${sqlServer}"
    Invoke-Sqlcmd -ServerInstance $sqlServer -Database master -Query $createUserScript -AccessToken $token -ErrorAction 'Stop'

    foreach ($db in $databases) {
        Write-Verbose "Adding user $appName in $db DB in Azure SQL: ${sqlServer}"
        Invoke-Sqlcmd -ServerInstance $sqlServer -Database $db -Query $createUserScript -AccessToken $token -ErrorAction 'Stop'

        Write-Verbose "Adding user role for $appName in $db DB in Azure SQL: ${sqlServer}"
        Invoke-Sqlcmd -ServerInstance $sqlServer -Database $db -Query $addRoleScript -AccessToken $token -ErrorAction 'Stop'
    }
}

$twinPlatformSid = Get-AppIdAsSQLByteLiteral -managedIdentityPrincipalId $twinPlatformManagedIdentityPrincipalId

foreach ($h in $appServiceDBHash.GetEnumerator()) {
    $appServiceName = "${appServicePrefix}-$($h.Value[0])-${appServiceSuffix}-$($h.Name)"
    $appSID = Get-AppIdAsSQLByteLiteral -appServiceName $appServiceName
    $databaseNames = $h.Value[1]
    Add-DatabaseUser -appName $appServiceName -principalIdAsSqlByteLiteral $appSID -databases $databaseNames
    Add-DatabaseUser -appName 'Twin Platform' -principalIdAsSqlByteLiteral $twinPlatformSid -databases $databaseNames
}

# Allow Auth Api to access to DirectoryCore database
$authApiSid = Get-AppIdAsSQLByteLiteral -managedIdentityPrincipalId $authApiManagedIdentityPrincipalId
if(![string]::IsNullOrEmpty($authApiSid)){
    Add-DatabaseUser -appName 'Auth Api' -principalIdAsSqlByteLiteral $authApiSid -databases "DirectoryCoreDB"
}