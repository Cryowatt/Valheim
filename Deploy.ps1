#Requires -Module Az.OperationalInsights
#Requires -Module Az.Resources
#Requires -Module Az.Storage

[cmdletbinding(SupportsShouldProcess = $true)]
param(
    $ResourceGroupName = "GameServer",
    $StorageAccountName = "gameserverfiles",
    $LogWorkspaceName = "GameServerLogs",
    $AppId = 896660,
    [Parameter(Mandatory = $true)]
    [string] $WorldName,
    [Parameter(Mandatory = $true)]
    [securestring] $Password
)

$activity = "Deploying game server"

# Query for latest buildid
Write-Progress -Activity $activity -Status "Building image" -CurrentOperation "Querying buildId"
docker compose up steamapi --detach --build
Start-Sleep -Seconds 1
$appInfo = Invoke-RestMethod "http://localhost:8080/v1/info/$AppId"

if ($appInfo.status -ne "success") {
    throw $appInfo.status
}

$buildId = $appInfo.data."$appId".depots.branches.public.buildid
$env:SERVER_BUILDID = $buildId

# Build and tag with latest buildid
Write-Progress -Activity $activity -Status "Building image" -CurrentOperation "server"
.\Build.ps1 -AppId $AppId -BuildId $buildId
docker compose push server

# # Push
# # Deploy with buildid

Write-Progress -Activity $activity -Status "Deploying to Azure" -CurrentOperation "Querying parameters"
$DeployParameters = @{
    saves_storage_account_name = $StorageAccountName
    saves_storage_account_key = [string] (Get-AzStorageAccountKey -Name $StorageAccountName -ResourceGroupName $ResourceGroupName | Select-Object -First 1 -ExpandProperty Value)
    log_analytics_workspace_id = [string] (Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -Name $LogWorkspaceName | Select-Object -ExpandProperty CustomerId)
    log_analytics_workspace_key = [string] (Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroupName $ResourceGroupName -Name $LogWorkspaceName | Select-Object -ExpandProperty PrimarySharedKey)
    server_version = $buildId
    server_password = ($Password | ConvertFrom-SecureString -AsPlainText)
    server_world = $WorldName
}

Write-Progress -Activity $activity -Status "Deploying to Azure" -CurrentOperation "Deploying"
New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateParameterObject $DeployParameters -TemplateFile .\deploy\template.json -Name Valheim -Confirm
Write-Progress -Activity $activity -Completed