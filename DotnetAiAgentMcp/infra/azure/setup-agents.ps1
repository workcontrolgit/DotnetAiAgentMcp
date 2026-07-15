# setup-agents.ps1
# Creates Azure AI Foundry agents via REST API (data-plane, not ARM).
# Run AFTER main.bicep has been deployed.
#
# Usage:
#   ./setup-agents.ps1
#   ./setup-agents.ps1 -ResourceGroup "my-rg" -AccountName "my-foundry"

param(
    [string]$ResourceGroup  = "rg-dotnet-ai-agent",
    [string]$AccountName    = "hr-mcp-ai-foundry",
    [string]$DeploymentName = "gpt-5-mini",
    [string]$ApiVersion     = "2025-05-01-preview"
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# 1. Resolve endpoint + API key from Azure
# ---------------------------------------------------------------------------
Write-Host "Fetching endpoint and key for '$AccountName'..." -ForegroundColor Cyan

$endpoint = az cognitiveservices account show `
    --name $AccountName `
    --resource-group $ResourceGroup `
    --query "properties.endpoint" -o tsv

$apiKey = az cognitiveservices account keys list `
    --name $AccountName `
    --resource-group $ResourceGroup `
    --query "key1" -o tsv

$baseUrl = "$($endpoint.TrimEnd('/'))agents/v1.0"

$headers = @{
    "api-key"      = $apiKey
    "Content-Type" = "application/json"
}

# ---------------------------------------------------------------------------
# 2. Helper — upsert agent (create or update by name)
# ---------------------------------------------------------------------------
function Invoke-FoundryApi {
    param([string]$Method, [string]$Path, [hashtable]$Body = $null)
    $url = "$baseUrl/$Path`?api-version=$ApiVersion"
    $params = @{ Method = $Method; Uri = $url; Headers = $headers }
    if ($Body) { $params.Body = ($Body | ConvertTo-Json -Depth 10) }
    return Invoke-RestMethod @params
}

function Get-AgentByName([string]$Name) {
    $list = Invoke-FoundryApi -Method GET -Path "assistants"
    return $list.data | Where-Object { $_.name -eq $Name } | Select-Object -First 1
}

function Upsert-Agent([string]$Name, [string]$Instructions, [hashtable]$Extra = @{}) {
    $body = @{
        model        = $DeploymentName
        name         = $Name
        instructions = $Instructions
    } + $Extra

    $existing = Get-AgentByName -Name $Name
    if ($existing) {
        Write-Host "  Updating existing agent '$Name' ($($existing.id))..." -ForegroundColor Yellow
        $result = Invoke-FoundryApi -Method POST -Path "assistants/$($existing.id)" -Body $body
    } else {
        Write-Host "  Creating agent '$Name'..." -ForegroundColor Green
        $result = Invoke-FoundryApi -Method POST -Path "assistants" -Body $body
    }
    return $result
}

# ---------------------------------------------------------------------------
# 3. Define agents
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Setting up Azure AI Foundry agents..." -ForegroundColor Cyan

$askHr = Upsert-Agent `
    -Name "AskHR" `
    -Instructions @"
You are AskHR, a helpful HR assistant for employees.
You answer questions about company policies, benefits, leave, onboarding, and job openings.
Be professional, concise, and empathetic.
If you do not know the answer, say so and suggest contacting the HR department directly.
"@

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
Write-Host ""
Write-Host "Agent IDs:" -ForegroundColor Cyan
Write-Host "  AskHR : $($askHr.id)"
