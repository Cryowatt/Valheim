#Requires -Module Az.OperationalInsights
#Requires -Module Az.Resources
#Requires -Module Az.Storage

[cmdletbinding()]
param(
    $ResourceGroupName = "GameServer",
    $StorageAccountName = "gameserverfiles",
    $LogWorkspaceName = "GameServerLogs",
    $AppId = 896660,
    $WorldName,
    [Parameter(Mandatory = $true)]
    [string] $Password
)

$activity = "Deploying game server"
$env:SERVER_APPID = $AppId
$env:SERVER_NAME = "valheim"

# Pull latest steamcmd
Write-Progress -Activity $activity -Status "Pulling latest docker images" -CurrentOperation "steamcmd" -PercentComplete 0
docker compose pull steamcmd
Write-Progress -Activity $activity -Status "Pulling latest docker images" -CurrentOperation "server" -PercentComplete 50
docker compose pull server
Write-Progress -Activity $activity -Status "Pulling latest docker images" -PercentComplete 100

# Query for latest buildid
Write-Progress -Activity $activity -Status "Building image" -CurrentOperation "Querying buildId"
if (-not ((docker compose run --rm steamcmd +app_info_print $appId +quit | Out-String) -match '"public"\s*{\s*"buildid"\s*"([^"]+)"')) {
    throw "Failed to parse public branch buildid"
}

$env:SERVER_BUILDID = $matches[1]

# Build and tag with latest buildid
Write-Progress -Activity $activity -Status "Building image" -CurrentOperation "server"
docker compose build server
docker compose push server

# Push
# Deploy with buildid

Write-Progress -Activity $activity -Status "Deploying to Azure" -CurrentOperation "Querying parameters"
$DeployParameters = @{
    saves_storage_account_name = $StorageAccountName
    saves_storage_account_key = [string] (Get-AzStorageAccountKey -Name $StorageAccountName -ResourceGroupName $ResourceGroupName | Select-Object -First 1 -ExpandProperty Value)
    log_analytics_workspace_id = [string] (Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -Name $LogWorkspaceName | Select-Object -ExpandProperty CustomerId)
    log_analytics_workspace_key = [string] (Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroupName $ResourceGroupName -Name $LogWorkspaceName | Select-Object -ExpandProperty PrimarySharedKey)
    server_version = $env:SERVER_BUILDID
    server_password = $Password
    server_world = $WorldName
}

Write-Progress -Activity $activity -Status "Deploying to Azure" -CurrentOperation "Deploying"
New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateParameterObject $DeployParameters -TemplateFile .\deploy\template.json -Name Valheim
Write-Progress -Activity $activity -Completed