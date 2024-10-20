[cmdletbinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $workspaceName
)

$workspace = (terraform workspace list | Where-Object { $_ -match $workspaceName }).count
Write-Host "Workspace found: [$workspace]"

if ($workspace -gt 0) {
    Write-Host "Switching to workspace: [$workspaceName]"
    terraform workspace select $workspaceName -no-color
}
else {
    Write-Host "Creating new workspace: [$workspaceName]"
    terraform workspace new $workspaceName -no-color
}