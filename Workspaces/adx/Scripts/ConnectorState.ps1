[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $adxClusterName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $adxDBName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]    $adxClusterLocation    #eg: australiaeast
)

$subscriptionId = $env:ARM_SUBSCRIPTION_ID
$tenantId = $env:ARM_TENANT_ID
$clientId = $env:ARM_CLIENT_ID
$secret = $env:ARM_CLIENT_SECRET

Write-Verbose "Logging in to azure"
az login --service-principal --username $clientId --password $secret --tenant $tenantId
az account set --subscription $subscriptionId

$adxClusterUri = "https://${adxClusterName}.${adxClusterLocation}.kusto.windows.net"

Write-Verbose "Getting access token from ADX Cluster: ${adxClusterName}"
$token = az account get-access-token --resource $adxClusterUri --query accessToken --output tsv

$headers = @{
    Authorization = "Bearer $token"
}
$createTableBody = '{
    "db" : "' + ${adxDBName} + '",
    "csl" : ".create-merge table ConnectorState
            (
                ConnectorId: guid,
                ConnectionType: string,
                TimestampUTC: datetime,
                IsEnabled: bool,
                IsArchived: bool,
                Interval : int
            )"
}'
$enableStreamingIngestionBody = '{
    "db" : "' + ${adxDBName} + '",
    "csl" : ".alter table ConnectorState policy streamingingestion enable"
}'
$createMappingBody = '{
    "db" : "' + ${adxDBName} + '",
    "csl" : ".create-or-alter table ConnectorState ingestion json mapping \"ConnectorStateMapping\"
        ''[''
            ''{\"column\":\"ConnectorId\",\"path\":\"$.connectorId\",\"datatype\":\"guid\",\"transform\":null},''
            ''{\"column\":\"ConnectionType\",\"path\":\"$.connectionType\",\"datatype\":\"string\",\"transform\":null},''
            ''{\"column\":\"TimestampUTC\",\"path\":\"$.timestamp\",\"datatype\":\"datetime\",\"transform\":null},''
            ''{\"column\":\"IsEnabled\",\"path\":\"$.enabled\",\"datatype\":\"bool\",\"transform\":null},''
            ''{\"column\":\"IsArchived\",\"path\":\"$.archived\",\"datatype\":\"bool\",\"transform\":null},''
            ''{\"column\":\"Interval\",\"path\":\"$.interval\",\"datatype\":\"int\",\"transform\":null}''
        '']''"
}'

Write-Verbose "Creating table ConnectorState in ADX Database ${adxDBName} ADX Cluster: ${adxClusterName}"
Invoke-RestMethod -Uri $adxClusterUri/v1/rest/mgmt -Headers $headers -Method POST -Body $createTableBody -ContentType "application/json; charset=utf-8"

Write-Verbose "Altering table ConnectorState to enable streaming ingestion in ADX Database ${adxDBName} ADX Cluster: ${adxClusterName}"
Invoke-RestMethod -Uri $adxClusterUri/v1/rest/mgmt -Headers $headers -Method POST -Body $enableStreamingIngestionBody -ContentType "application/json; charset=utf-8"


Write-Verbose "Creating mapping ConnectorStateMapping in ADX Database ${adxDBName} ADX Cluster: ${adxClusterName}"
Invoke-RestMethod -Uri $adxClusterUri/v1/rest/mgmt -Headers $headers -Method POST -Body $createMappingBody -ContentType "application/json; charset=utf-8"