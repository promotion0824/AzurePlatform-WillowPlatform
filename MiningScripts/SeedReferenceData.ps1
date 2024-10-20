[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $companyPrefix,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $environmentPrefix,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $productPrefix,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $regionPrefix,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $miningCustomerId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $longCustomerName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $customerCountry,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $customerAccountExternalId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $siteName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $siteTimeZone,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $supervisorEmail,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $adtInstanceUri
)

$sqlServer = "${companyPrefix}-${environmentPrefix}-${productPrefix}-shr-${regionPrefix}-sql.database.windows.net"
$portfolioId = [guid]::NewGuid().ToString()
$siteId = [guid]::NewGuid().ToString()

Write-Verbose "Getting access token from Azure SQL: ${sqlServer}"
$token = az account get-access-token --resource https://database.windows.net --query accessToken --output tsv

$seedDirectoryCoreParams = `
    "CustomerId='${miningCustomerId}'", `
    "LongCustomerName='${longCustomerName}'", `
    "CustomerCountry='${customerCountry}'", `
    "CustomerAccountExternalId='${customerAccountExternalId}'", `
    "PortfolioId='${portfolioId}'", `
    "SiteId='${siteId}'", `
    "SiteName='${siteName}'", `
    "SiteTimeZone='${siteTimeZone}'", `
    "SupervisorEmail='${supervisorEmail}'"

Write-Verbose "Seeding DirectoryCoreDB"
$directoryOutput = Invoke-Sqlcmd -ServerInstance $sqlServer `
    -Database DirectoryCoreDB `
    -InputFile $PSScriptRoot\seed\SeedDirectoryCoreDB.sql `
    -Variable $seedDirectoryCoreParams `
    -AccessToken $token `
    -ErrorAction 'Stop' `
    -Verbose

$siteId = $directoryOutput.SiteId
$portfolioId = $directoryOutput.PortfolioId

$seedSiteCoreParams = `
    "SiteId='${siteId}'", `
    "CustomerId='${miningCustomerId}'", `
    "PortfolioId='${portfolioId}'", `
    "SiteName='${siteName}'", `
    "SiteTimeZone='${siteTimeZone}'"

Write-Verbose "Seeding SiteCoreDB"
Invoke-Sqlcmd -ServerInstance $sqlServer `
    -Database SiteCoreDB `
    -InputFile $PSScriptRoot\seed\SeedSiteCoreDB.sql `
    -Variable $seedSiteCoreParams `
    -AccessToken $token `
    -ErrorAction 'Stop' `
    -Verbose

$seedDTCoreParams = `
    "SiteId='${siteId}'", `
    "ADTInstanceUri='${adtInstanceUri}'", `
    "SiteName='${siteName}'"

Write-Verbose "Seeding DigitalTwinDB"
Invoke-Sqlcmd -ServerInstance $sqlServer `
    -Database DigitalTwinDB `
    -InputFile $PSScriptRoot\seed\SeedDTCoreDB.sql `
    -Variable $seedDTCoreParams `
    -AccessToken $token `
    -ErrorAction 'Stop' `
    -Verbose