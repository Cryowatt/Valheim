#Requires -Module Az.OperationalInsights
#Requires -Module Az.Resources
#Requires -Module Az.Storage

[cmdletbinding(SupportsShouldProcess = $true)]
param(
    $AppId = 896660,
    $BuildId
)

$env:SERVER_BUILDID = $BuildId

# $env:BEPINEX_URL = (Invoke-RestMethod "https://api.github.com/repos/BepInEx/BepInEx/releases/latest").assets | 
#     Where-Object name -like "*_unix_*" | 
#     Select-Object -ExpandProperty browser_download_url

# az acr build --registry cryowattgs --image cryowatt/valheim:${env:SERVER_BUILDID} .
docker compose build server
