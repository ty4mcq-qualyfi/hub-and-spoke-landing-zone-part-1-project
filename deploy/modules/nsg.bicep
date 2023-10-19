param parLocation string

resource resDefaultNsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: 'nsg-default'
  location: parLocation
}

output outDefaultNsgName string = resDefaultNsg.name