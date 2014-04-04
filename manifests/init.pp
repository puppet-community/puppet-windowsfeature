define windowsfeature (
    $ensure = 'present',
    $feature_name = $title,
    $includemanagementtools = false,
    $includesubfeatures = false,
    $restart = false
) {

  validate_re($ensure, '^(present|absent)$', 'valid values for ensure are \'present\' or \'absent\'')
  validate_bool($includemanagementtools)
  validate_bool($includesubfeatures)
  validate_bool($restart)

  if $::operatingsystem != 'windows' { fail ("${module_name} not supported on ${::operatingsystem}") }
  if $restart { $_restart = 'true' } else { $_restart = 'false' }
  if $includesubfeatures { $_includesubfeatures = '-IncludeAllSubFeature' }

  if $::kernelversion =~ /^(6.1)/ and $includemanagementtools {
    fail ('Windows 2012 or newer is required to use the includemanagementtools parameter')
  } elsif $includemanagementtools {
    $_includemanagementtools = '-IncludeManagementTools'
  }

  if(is_array($feature_name)){
    $escaped = join(prefix(suffix($feature_name,"'"),"'"),',')
    $features = "@(${escaped})"
  }else{
    $features = $feature_name
  }

  # Windows 2008 R2 and newer required http://technet.microsoft.com/en-us/library/ee662309.aspx
  if $::kernelversion !~ /^(6\.1|6\.2|6\.3)/ { fail ("${module_name} requires Windows 2008 R2 or newer") }

  # from Windows 2012 'Add-WindowsFeature' has been replaced with 'Install-WindowsFeature' http://technet.microsoft.com/en-us/library/ee662309.aspx
  if ($ensure == 'present') {
    if $::kernelversion =~ /^(6.1)/ { $command = 'Add-WindowsFeature' } else { $command = 'Install-WindowsFeature' }

    exec { "add-feature-${title}" :
      command   => "Import-Module ServerManager; ${command} ${features} ${_includemanagementtools} ${_includesubfeatures} -Restart:$${_restart}",
      onlyif    => "Import-Module ServerManager; if((Get-WindowsFeature ${features} | where InstallState -eq 'Available').count -eq 0){ exit 1 }",
      provider  => powershell
    }
  } elsif ($ensure == 'absent') {
    exec { "remove-feature-${title}" :
      command   => "Import-Module ServerManager; Remove-WindowsFeature ${$features} -Restart:$${_restart}",
      unless    => "Import-Module ServerManager; if((Get-WindowsFeature ${features} | where InstallState -eq 'Installed').count -gt 0){ exit 1 }",
      provider  => powershell
    }
  }
}
