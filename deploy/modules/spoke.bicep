param parLocation string
param parUtc string

param parVnetAddressPrefix string

param parAppSubnetAddressPrefix string
param parSqlSubnetAddressPrefix string
param parStSubnetAddressPrefix string

param parSpokeName string

param parDefaultNsgId string
param parRtId string

param parAspSkuName string

param parLinuxFxVersion string

param parRepoUrl string
param parBranch string

@secure()
param parSqlAdminUsername string
@secure()
param parSqlAdminPassword string

param parGuidSuffix string

param parWaPDnsZoneName string
param parWaPDnsZoneId string
param parSqlPDnsZoneName string
param parSqlPDnsZoneId string
param parSaPDnsZoneName string
param parSaPDnsZoneId string
param parKvPDnsZoneName string

//Spoke VNet + Private DNS Zone Link
resource resVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'vnet-${parSpokeName}-${parLocation}-001'
  location: parLocation
  tags: {
    Dept: parSpokeName
    Owner: '${parSpokeName}Owner'
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        parVnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'AppSubnet'
        properties: {
          addressPrefix: parAppSubnetAddressPrefix
          networkSecurityGroup: {
            id: parDefaultNsgId
          }
          routeTable: {
            id: parRtId
          }
        }
      }
      {
        name: 'SqlSubnet'
        properties: {
          addressPrefix: parSqlSubnetAddressPrefix
          networkSecurityGroup: {
            id: parDefaultNsgId
          }
          routeTable: {
            id: parRtId
          }
        }
      }
      {
        name: 'StSubnet'
        properties: {
          addressPrefix: parStSubnetAddressPrefix
          networkSecurityGroup: {
            id: parDefaultNsgId
          }
          routeTable: {
            id: parRtId
          }
        }
      }
    ]
  }
}
resource resWaPDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${parWaPDnsZoneName}/${parWaPDnsZoneName}-${parSpokeName}-link'
  location: 'global'
  tags: {
    Dept: parSpokeName
    Owner: '${parSpokeName}Owner'
  }
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: resVnet.id
    }
  }
}
resource resSqlPDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${parSqlPDnsZoneName}/${parSqlPDnsZoneName}-${parSpokeName}-link'
  location: 'global'
  tags: {
    Dept: parSpokeName
    Owner: '${parSpokeName}Owner'
  }
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: resVnet.id
    }
  }
}
resource resSaPDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${parSaPDnsZoneName}/${parSaPDnsZoneName}-${parSpokeName}-link'
  location: 'global'
  tags: {
    Dept: parSpokeName
    Owner: '${parSpokeName}Owner'
  }
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: resVnet.id
    }
  }
}
resource resKvPDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${parKvPDnsZoneName}/${parKvPDnsZoneName}-${parSpokeName}-link'
  location: 'global'
  tags: {
    Dept: parSpokeName
    Owner: '${parSpokeName}Owner'
  }
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: resVnet.id
    }
  }
}

//App Service Plan + Web App + Source Controls
resource resAsp 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: 'asp-${parSpokeName}-${parLocation}-001-${uniqueString(parUtc)}'
  location: parLocation
  tags: {
    Dept: 'coreServices'
    Owner: 'coreServicesOwner'
  }
  properties: {
    reserved: true
  }
  sku: {
    name: parAspSkuName
  }
  kind: 'linux'
}
resource resWa 'Microsoft.Web/sites@2022-09-01' = {
  name: 'as-${parSpokeName}-${parLocation}-001-${uniqueString(parUtc)}'
  location: parLocation
  tags: {
    Dept: 'coreServices'
    Owner: 'coreServicesOwner'
  }
  properties: {
    serverFarmId: resAsp.id
    publicNetworkAccess: 'Disabled'
    siteConfig: {
      linuxFxVersion: parLinuxFxVersion
    }
  }
}
resource resSrcControls 'Microsoft.Web/sites/sourcecontrols@2022-09-01' = {
  name: 'web'
  parent: resWa
  properties: {
    repoUrl: parRepoUrl
    branch: parBranch
    isManualIntegration: true
  }
}

//Web App Private Endpoint + Private Endpoint NIC + Private Endpoint DNS Group
resource resWaPe 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: 'pe-${parSpokeName}-${parLocation}-wa-001'
  location: parLocation
  tags: {
    Dept: parSpokeName
    Owner: '${parSpokeName}Owner'
  }
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'pe-${parSpokeName}-${parLocation}-wa-001'
        properties: {
          privateLinkServiceId: resWa.id
          groupIds: [
            'sites'
          ]
        }
      }
    ]
    subnet: {
      id: resVnet.properties.subnets[0].id
    }
  }
}
resource resWaPeNic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: 'nic-${parSpokeName}-${parLocation}-wa-001'
  location: parLocation
  tags: {
    Dept: parSpokeName
    Owner: '${parSpokeName}Owner'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resVnet.properties.subnets[0].id
          }
        }
      }
    ]
  }
}
resource resWaPeDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  name: 'waPeDnsGroup'
  parent: resWaPe
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'waPeDnsGroupConfig'
        properties: {
          privateDnsZoneId: parWaPDnsZoneId
        }
      }
    ]
  }
}

//SQL Server + Database
resource resSqlServer 'Microsoft.Sql/servers@2021-11-01' ={
  name: 'sql-${parSpokeName}-${parLocation}-001-${uniqueString(parUtc)}'
  location: parLocation
  tags: {
    Dept: 'coreServices'
    Owner: 'coreServicesOwner'
  }
  properties: {
    administratorLogin: parSqlAdminUsername
    administratorLoginPassword: parSqlAdminPassword
    publicNetworkAccess: 'Disabled'
  }
}
resource resSqlDb 'Microsoft.Sql/servers/databases@2021-11-01' = {
  parent: resSqlServer
  name: 'sqldb-${parSpokeName}-${parLocation}-001'
  location: parLocation
  tags: {
    Dept: 'coreServices'
    Owner: 'coreServicesOwner'
  }
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
}

//SQL Private Endpoint + Private Endpoint NIC + Private Endpoint DNS Group
resource resSqlPe 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: 'pe-${parSpokeName}-${parLocation}-sql-001'
  location: parLocation
  tags: {
    Dept: parSpokeName
    Owner: '${parSpokeName}Owner'
  }
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'pe-${parSpokeName}-${parLocation}-sql-001'
        properties: {
          privateLinkServiceId: resSqlServer.id
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
    subnet: {
      id: resVnet.properties.subnets[1].id
    }
  }
}
resource resSqlPeNic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: 'nic-${parSpokeName}-${parLocation}-sql-001'
  location: parLocation
  tags: {
    Dept: parSpokeName
    Owner: '${parSpokeName}Owner'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resVnet.properties.subnets[1].id
          }
        }
      }
    ]
  }
}
resource resSqlPeDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  name: 'sqlPeDnsGroup'
  parent: resSqlPe
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'sqlPeDnsGroupConfig'
        properties: {
          privateDnsZoneId: parSqlPDnsZoneId
        }
      }
    ]
  }
}

//Storage Account
resource resSa 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'st${parSpokeName}001${parGuidSuffix}'
  location: parLocation
  tags: {
    Dept: 'coreServices'
    Owner: 'coreServicesOwner'
  }
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    publicNetworkAccess: 'Disabled'
  }
}

//Storage Account Private Endpoint + Private Endpoint NIC + Private Endpoint DNS Group
resource resSaPe 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: 'pe-${parSpokeName}-${parLocation}-sa-001'
  location: parLocation
  tags: {
    Dept: parSpokeName
    Owner: '${parSpokeName}Owner'
  }
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'pe-${parSpokeName}-${parLocation}-sa-001'
        properties: {
          privateLinkServiceId: resSa.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
    subnet: {
      id: resVnet.properties.subnets[2].id
    }
  }
}
resource resSaPeNic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: 'nic-${parSpokeName}-${parLocation}-sa-001'
  location: parLocation
  tags: {
    Dept: parSpokeName
    Owner: '${parSpokeName}Owner'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resVnet.properties.subnets[2].id
          }
        }
      }
    ]
  }
}
resource resSaPeDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  name: 'saPeDnsGroup'
  parent: resSaPe
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'saPeDnsGroupConfig'
        properties: {
          privateDnsZoneId: parSaPDnsZoneId
        }
      }
    ]
  }
}

output outVnetName string = resVnet.name
output outVnetId string = resVnet.id
output outWaName string = resWa.name
output outWaFqdn string = resWa.properties.defaultHostName
