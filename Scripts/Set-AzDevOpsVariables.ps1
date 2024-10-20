[cmdletbinding()]
Param(
    [Parameter(Mandatory = $false)]
    [hashtable]
    $taskVariables,

    [Parameter(Mandatory = $false)]
    [hashtable]
    $releaseVariables,

    [Parameter(Mandatory = $false)]
    [hashtable]
    $agentVariables
)

Write-Host "Task variables count: [$($taskVariables.Count)]"
Write-Host "Release variables count: [$($releaseVariables.Count)]"
Write-Host "Agent variables count: [$($agentVariables.Count)]"

$utcDateTime = $((get-date -format filedatetimeuniversal).substring(4))

if (-not $taskVariables) {
    Write-Host "No task variables to be processed"
}

foreach ($key in $taskVariables.Keys) {
    $value = $taskVariables[$key]

    if ($key -match 'deploymentName') {
        Write-Output "Found (task) variable 'deploymentName'. Appending utcDateTime [$utcDateTime]"
        $value = ('{0}-{1}' -f $value, $utcDateTime)
    }

    Write-Output "Setting AzDevOps (task) variable: [$key] to [$value]"
    Write-Host "##vso[task.setvariable variable=$key]$value"

    if ($env:VSTS_DEBUG) {
        Set-Item "env:$($key.Replace('.', '_'))" $value
    }
}

if (-not ($releaseVariables -or $agentVariables)) {
    Write-Host "No release/agent variables to be processed!"
    return
}

#region ReleaseUrl
$releaseUrl = ('{0}{1}/_apis/release/releases/{2}?api-version=5.0' -f $($env:SYSTEM_TEAMFOUNDATIONSERVERURI), $($env:SYSTEM_TEAMPROJECTID), $($env:RELEASE_RELEASEID))
Write-Host "ReleaseUrl: [$releaseUrl]"
#endregion

#region Get Release Definition
$Release = Invoke-RestMethod -Uri $releaseUrl -Headers @{
    Authorization = "Bearer $env:SYSTEM_ACCESSTOKEN"
}
#endregion

#region Output current release pipeline
Write-Output ('Current Release Pipeline variables output: {0}' -f $($Release.variables | ConvertTo-Json -Depth 10))
#endregion

#region Update release variables
foreach ($key in $releaseVariables.Keys) {
    $value = $releaseVariables[$key]

    if ($key -match 'deploymentName') {
        Write-Output "Found (release) variable 'deploymentName'. Appending utcDateTime [$utcDateTime]"
        $value = ('{0}-{1}' -f $value, $utcDateTime)
    }

    Write-Output "Setting AzDevOps (release) variable: [$key] to [$value]"
    $release.variables.$key.value = $value
}
#endregion

#region Add new variable on the fly
foreach ($key in $agentVariables.Keys) {
    $value = $agentVariables[$key]
    
    if ($key -match 'deploymentName') {
        Write-Output "Found (agent) variable 'deploymentName'. Appending utcDateTime [$utcDateTime]"
        $value = ('{0}-{1}' -f $value, $utcDateTime)
    }

    # check if the property is already added
    if ($release.variables.$key) {
        Write-Output "Removing existing member [$key]"
        $release.variables.PsObject.Properties.Remove($key)
    }
    
    Write-Output "Setting AzDevOps (agent) variable: [$key] to [$value]"
    $release.variables | Add-Member NoteProperty $key([PSCustomObject]@{value = $value })
}
#endregion

#region Update release pipeline
Write-Output "Updating Release Definition"
$json = @($release) | ConvertTo-Json -Depth 99
Invoke-RestMethod -Uri $releaseUrl -Method Put -Body $json -ContentType "application/json" -Headers @{
    Authorization = "Bearer $env:SYSTEM_ACCESSTOKEN"
}
#endregion

#region Get updated release definition
Write-Output "Get updated Release Definition"
$Release = Invoke-RestMethod -Uri $releaseUrl -Headers @{
    Authorization = "Bearer $env:SYSTEM_ACCESSTOKEN"
}
#endregion

#region Output updated release pipeline
Write-Output ('Updated Release Pipeline variables output: {0}' -f $($Release.variables | ConvertTo-Json -Depth 10))
#endregion