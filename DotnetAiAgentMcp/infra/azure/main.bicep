@description('Azure region for the Azure AI Foundry resource.')
param location string = resourceGroup().location

@description('Name of the Azure AI Foundry (AIServices) account.')
param accountName string

@description('Deployment name used by the application code.')
param deploymentName string = 'gpt-4.1-mini'

@description('Model name to deploy.')
param modelName string = 'gpt-4.1-mini'

@description('Model version.')
param modelVersion string = '2025-04-14'

@description('SKU for the AI Foundry resource.')
@allowed([
  'S0'
])
param accountSku string = 'S0'

@description('Deployment SKU.')
@allowed([
  'GlobalStandard'
  'Standard'
])
param deploymentSkuName string = 'GlobalStandard'

@description('Deployment capacity units (in thousands of tokens per minute).')
@minValue(1)
param deploymentCapacity int = 1

// ---------------------------------------------------------------------------
// Azure AI Foundry account  (AIServices kind — endpoint: <name>.services.ai.azure.com)
// Supports OpenAI, Anthropic, and other model families in one resource.
// ---------------------------------------------------------------------------
resource aiFoundry 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: accountName
  location: location
  kind: 'AIServices'
  sku: {
    name: accountSku
  }
  properties: {
    customSubDomainName: accountName
    publicNetworkAccess: 'Enabled'
  }
}

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: aiFoundry
  name: deploymentName
  sku: {
    name: deploymentSkuName
    capacity: deploymentCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: modelName
      version: modelVersion
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    raiPolicyName: 'Microsoft.Default'
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output endpoint string = aiFoundry.properties.endpoint
output openAiEndpoint string = 'https://${accountName}.openai.azure.com/'
output foundryEndpoint string = 'https://${accountName}.services.ai.azure.com/'
output deployment string = deploymentName
output resourceName string = aiFoundry.name
