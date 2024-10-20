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
$selectStreamingIngestionBody = '{
    "db" : "' + ${adxDBName} + '",
    "csl" : ".show table Telemetry policy streamingingestion"
}'
$enableStreamingIngestionBody = '{
    "db" : "' + ${adxDBName} + '",
    "csl" : ".alter table Telemetry policy streamingingestion enable"
}'
$selectMappingBody = '{
    "db" : "' + ${adxDBName} + '",
    "csl" : ".show table Telemetry ingestion json mapping \"TelemetryMapping\""
}'
$createMappingBody = '{
    "db" : "' + ${adxDBName} + '",
    "csl" : ".create table Telemetry ingestion json mapping \"TelemetryMapping\"
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

function Get-CreateTelemetryTableQuery {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]    $dbName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]    $tableName
    )

    $createTableBody = '{
        "db" : "' + ${dbName} + '",
        "csl" : ".create-merge table ' + ${tableName} + '
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

    return $createTableBody
}

Write-Verbose "Creating table Telemetry in ADX Database ${adxDBName} ADX Cluster: ${adxClusterName}"
Invoke-RestMethod -Uri $adxClusterUri/v1/rest/mgmt -Headers $headers -Method POST -Body (Get-CreateTelemetryTableQuery -dbName $adxDBName -tableName "Telemetry") -ContentType "application/json; charset=utf-8"

Write-Verbose "Checking if streaming ingestion is enabled in table Telemetry ADX Database ${adxDBName} ADX Cluster: ${adxClusterName}"
$selecctStreamingIngestionResponse = Invoke-RestMethod -Uri $adxClusterUri/v1/rest/mgmt -Headers $headers -Method POST -Body $selectStreamingIngestionBody -ContentType "application/json; charset=utf-8"

if($selecctStreamingIngestionResponse.Tables[0].Rows[0][2] -Match '"IsEnabled": true'){
    Write-Verbose "Streaming ingestion is already enabled in table Telemetry ADX Database ${adxDBName} ADX Cluster: ${adxClusterName}"
}
else {
    Write-Verbose "Altering table Telemetry to enable streaming ingestion in ADX Database ${adxDBName} ADX Cluster: ${adxClusterName}"
    Invoke-RestMethod -Uri $adxClusterUri/v1/rest/mgmt -Headers $headers -Method POST -Body $enableStreamingIngestionBody -ContentType "application/json; charset=utf-8"
}

try{
    Write-Verbose "Checking if mapping TelemetryMapping exists in ADX Database ${adxDBName} ADX Cluster: ${adxClusterName}"
    Invoke-RestMethod -Uri $adxClusterUri/v1/rest/mgmt -Headers $headers -Method POST -Body $selectMappingBody -ContentType "application/json; charset=utf-8"
    Write-Verbose "Mapping TelemetryMapping already exists in ADX Database ${adxDBName} ADX Cluster: ${adxClusterName}"
} catch{
    if($_.Exception.Response.StatusCode.value__ -eq "400" -and $_.ErrorDetails.Message -Match "Entity ID 'TelemetryMapping' of kind 'MappingPersistent' was not found.")
    {
        Write-Verbose "Creating mapping TelemetryMapping in ADX Database ${adxDBName} ADX Cluster: ${adxClusterName}"
        Invoke-RestMethod -Uri $adxClusterUri/v1/rest/mgmt -Headers $headers -Method POST -Body $createMappingBody -ContentType "application/json; charset=utf-8"
    }
}