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
    [string]    $adxTableName,
    
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
    "csl" : ".create-merge table '+ ${adxTableName} +' 
            (
                ConnectorId: string,
                DtId: string,
                ExternalId: string,
                TrendId: string,
                SourceTimestamp: datetime,
                EnqueuedTimestamp: datetime,
                ScalarValue: dynamic,
                Latitude: real,
                Longitude: real,
                Altitude: real,
                Properties: dynamic
            )"
}'
$enableStreamingIngestionBody = '{
    "db" : "' + ${adxDBName} + '",
    "csl" : ".alter table '+ ${adxTableName} +' policy streamingingestion enable"
}'
$createMappingBody = '{
    "db" : "' + ${adxDBName} + '",
    "csl" : ".create-or-alter table '+ ${adxTableName}+' ingestion json mapping \"'+ ${adxTableName}+'Mapping\"
        ''[''
            ''{\"column\":\"ConnectorId\",\"path\":\"$.ConnectorId\",\"datatype\":\"string\",\"transform\":null},''
            ''{\"column\":\"DtId\",\"path\":\"$.DtId\",\"datatype\":\"string\",\"transform\":null},''
            ''{\"column\":\"ExternalId\",\"path\":\"$.ExternalId\",\"datatype\":\"string\",\"transform\":null},''
            ''{\"column\":\"TrendId\",\"path\":\"$.TrendId\",\"datatype\":\"string\",\"transform\":null},''
            ''{\"column\":\"SourceTimestamp\",\"path\":\"$.SourceTimestamp\",\"datatype\":\"datetime\",\"transform\":null},''
            ''{\"column\":\"EnqueuedTimestamp\",\"path\":\"$.EnqueuedTimestamp\",\"datatype\":\"datetime\",\"transform\":null},''
            ''{\"column\":\"ScalarValue\",\"path\":\"$.ScalarValue\",\"datatype\":\"dynamic\",\"transform\":null},''
            ''{\"column\":\"Latitude\",\"path\":\"$.Latitude\",\"datatype\":\"real\",\"transform\":null},''
            ''{\"column\":\"Longitude\",\"path\":\"$.Longitude\",\"datatype\":\"real\",\"transform\":null},''
            ''{\"column\":\"Altitude\",\"path\":\"$.Altitude\",\"datatype\":\"real\",\"transform\":null},''
            ''{\"column\":\"Properties\",\"path\":\"$.Properties\",\"datatype\":\"dynamic\",\"transform\":null}''
        '']''"
}'

Write-Verbose "Creating table ${adxTableName} in ADX Database ${adxDBName} ADX Cluster: ${adxClusterName}"
Invoke-RestMethod -Uri $adxClusterUri/v1/rest/mgmt -Headers $headers -Method POST -Body $createTableBody -ContentType "application/json; charset=utf-8"

Write-Verbose "Altering table ${adxTableName} to enable streaming ingestion in ADX Database ${adxDBName} ADX Cluster: ${adxClusterName}"
Invoke-RestMethod -Uri $adxClusterUri/v1/rest/mgmt -Headers $headers -Method POST -Body $enableStreamingIngestionBody -ContentType "application/json; charset=utf-8"

Write-Verbose "Creating mapping ${adxTableName}Mapping in ADX Database ${adxDBName} ADX Cluster: ${adxClusterName}"
Invoke-RestMethod -Uri $adxClusterUri/v1/rest/mgmt -Headers $headers -Method POST -Body $createMappingBody -ContentType "application/json; charset=utf-8"