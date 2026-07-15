@description('Azure region for the AI Services resource.')
param location string = resourceGroup().location

@description('Name of the Azure AI Services account (used in the endpoint URL).')
param accountName string

@description('Claude model to deploy.')
@allowed([
  'claude-haiku-4-5'
  'claude-sonnet-4-5'
  'claude-sonnet-4-6'
  'claude-sonnet-5'
  'claude-opus-4-5'
  'claude-opus-4-6'
  'claude-opus-4-7'
  'claude-opus-4-8'
])
param claudeModel string = 'claude-sonnet-4-6'

@description('Deployment name used by the application code.')
param deploymentName string = 'claude-sonnet-4-6'

@description('Your organization name (required for Anthropic marketplace registration).')
param organizationName string

@description('Industry for marketplace registration (e.g. Technology, Finance, Healthcare).')
param industry string = 'Technology'

@description('Two-letter ISO country code for marketplace registration.')
param countryCode string = 'US'

// ---------------------------------------------------------------------------
// Azure AI Services account  (kind: AIServices gives the .services.ai.azure.com endpoint
// which supports both OpenAI and Anthropic model families)
// ---------------------------------------------------------------------------
resource aiServices 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: accountName
  location: location
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: accountName
    publicNetworkAccess: 'Enabled'
  }
}

// ---------------------------------------------------------------------------
// Claude model deployment (Global Standard — routes across Azure regions)
// ---------------------------------------------------------------------------
resource claudeDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: aiServices
  name: deploymentName
  sku: {
    name: 'GlobalStandard'
    capacity: 1
  }
  properties: {
    model: {
      format: 'Anthropic'
      name: claudeModel
      version: '1'
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    #disable-next-line BCP035
    modelProviderData: {
      organizationName: organizationName
      industry: industry
      countryCode: countryCode
    }
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output endpoint string = aiServices.properties.endpoint
output anthropicEndpoint string = 'https://${accountName}.services.ai.azure.com/anthropic/v1/messages'
output deployment string = deploymentName
output resourceName string = aiServices.name
