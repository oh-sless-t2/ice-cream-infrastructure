param LoadTestTargetUrl string = 'testy mctest'

resource prepareJmx 'Microsoft.Resources/deploymentScripts@2020-10-01' = if(false)  {
  name: 'createLoadTestJmx'
  location: resourceGroup().location
  kind: 'AzurePowerShell'
  properties: {
    forceUpdateTag: '1'
    azPowerShellVersion: '6.4'
    timeout: 'PT30M'
    arguments: '-url \\"${LoadTestTargetUrl}\\"'
    scriptContent: '''
      param([string] $url)
      $output = \'Hello {0}\' -f $url
      Write-Output $output
      $DeploymentScriptOutputs = @{}
      $DeploymentScriptOutputs[\'text\'] = $output
    '''
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
}
