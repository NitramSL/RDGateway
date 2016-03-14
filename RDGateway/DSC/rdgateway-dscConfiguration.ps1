Configuration Main
{

Param ( [string] $fqdn )

Import-DscResource -ModuleName PSDesiredStateConfiguration

[string]$moduleName='RemoteDesktopServices'

# RDG Allowed Users
[string]$RDG_AllowedUsers='Administrators@BUILTIN'

# Port RDG is allowed to connect to internal servers
[int]$RD_Port=3389

# Location where the Self-Signed Certificate is to be stored
[string]$Cert_Location='cert:\LocalMachine\My'

Node localhost
  {
		# Remote Desktop Gateway 
        WindowsFeature RDSGateway
        {
            Name = "RDS-Gateway"
            Ensure = "Present"
        }
        # Remote Desktop Gateway Tools
        WindowsFeature RSATRDSGateway
        {
            Name = "RSAT-RDS-Gateway"
            Ensure = "Present"
        }
		# Create Default RDSCAP
		Script RDSCAP
        {
            SetScript = {
                Import-Module -Name $using:moduleName
                new-item -path RDS:\GatewayServer\CAP -Name Default-CAP -UserGroups $using:RDG_AllowedUsers -AuthMethod 1
            }
            TestScript = {
                Import-Module -Name $using:moduleName
                return (Get-ChildItem -Path RDS:\GatewayServer\CAP\ | ?{$_.Name -eq "Default-CAP"}) -ne $null    
            }
            GetScript = {
               
            }
            DependsOn = "[WindowsFeature]RSATRDSGateway" 
        }

		# Create Default RDSRAP
        Script RDSRAP
        {
            SetScript = {
                Import-Module -Name $using:moduleName
                new-item -Path RDS:\GatewayServer\RAP -Name Default-RAP -UserGroups $using:RDG_AllowedUsers -ComputerGroupType 2 -Port $using:RD_Port
            }
            TestScript = {
                Import-Module -Name $using:moduleName
                return (Get-ChildItem -Path RDS:\GatewayServer\RAP\ | ?{$_.Name -eq "Default-RAP"}) -ne $null
                
            }
            GetScript = {
               
            }
            DependsOn = "[WindowsFeature]RSATRDSGateway" 
		}

        #Create and Configure a Self-Signed certificate 
        Script RDSCertificate
        {
            SetScript = {
                Import-Module -Name $using:moduleName
                
				# Create Self-Signed Certificate
				$SSCertificate=New-SelfSignedCertificate -DnsName $using:fqdn,($using:fqdn).Split('.')[0] -CertStoreLocation $using:Cert_Location
				# Configure RDG to work with the created certificate
				Set-Item -Path RDS:\GatewayServer\SSLCertificate\Thumbprint -value $SSCertificate.Thumbprint
				# Restart RD Gateway to apply Certificate settings
				Restart-Service TSGateway				

            }
            TestScript = {
                Import-Module -Name $using:moduleName
				# Retrieve and Compare Self-Signed Certificate with the one configured for RDG
                try {
					$StoreThumbprint = ((Get-ChildItem $using:Cert_Location) | ?{ $_.Subject -eq "CN=$using:fqdn”})[0].Thumbprint
				} catch {
					$StoreThumbprint = ''
				}
                $RDSThumbprint = (Get-ChildItem -Path RDS:\GatewayServer\SSLCertificate\Thumbprint).CurrentValue
				# Return True if they match and are not empty, False otherwise
				if (($StoreThumbprint -eq $RDSThumbprint) -and ($StoreThumbprint.Length -gt 0))
                {
                    return $true
                } else {
                    return $false
                }
            }
            GetScript = {
               
            }
            DependsOn = "[WindowsFeature]RDSGateway" 

        }
  }

}
