#Set-StrictMode -Version Latest
#####################################################
# Set-Tokens
#####################################################
<#PSScriptInfo

.VERSION 0.9

.GUID bfd55243-60dd-4394-a80e-835718187e1f

.AUTHOR David Walker, Sitecore Dave, Radical Dave

.COMPANYNAME David Walker, Sitecore Dave, Radical Dave

.COPYRIGHT David Walker, Sitecore Dave, Radical Dave

.TAGS powershell sitecore package

.LICENSEURI https://github.com/SharedSitecore/Set-Tokens/blob/main/LICENSE

.PROJECTURI https://github.com/SharedSitecore/Set-Tokens

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES

#>

<# 

.DESCRIPTION 
 PowerShell Script to set/replace tokens in strings and files

.PARAMETER name
Path of package

#> 
#####################################################
# Set-Tokens
#####################################################

[CmdletBinding(SupportsShouldProcess)]
Param(
	[Parameter(Mandatory=$false)]
	[string] $source,
	[Parameter(Mandatory=$false)]
	[string] $destination,
	[Parameter(Mandatory=$false)]
	[string] $regex = '(\$\()([a-zA-Z0-9\.\-_]*)(\))'
)
begin {
	$ProgressPreference = 'SilentlyContinue'
	$ErrorActionPreference = 'Stop'
	$PSScriptVerson = (Test-ScriptFileInfo -Path $MyInvocation.MyCommand | Select-Object -ExpandProperty Version)
	$PSScriptName = ($MyInvocation.MyCommand.Name.Replace('.ps1',''))
	$PSCallingScript = if ($MyInvocation.PSCommandPath) { $MyInvocation.PSCommandPath | Split-Path -Parent } else { $null }
	$currLocation = "$(Get-Location)"
	Write-Verbose "$PSScriptName $PSScriptVerson $source $destination called by:$PSCallingScript from $currLocation"

	function Set-TokenContent($string) {
		if (!$string) { return $string }
		$results = $string
		$tokens = [regex]::Matches($string,$regex)
		if (!$tokens) {
			return $string
		}
		$tokens | Foreach-Object {			
			$org = $_.groups[0].value
			$token = $org
			#Write-Verbose "token:$token"
			if ($token -like '$(*') {
				$token = $token.Remove(0,2) 
				$token = $token.Substring(0, $token.Length - 1)
			}
			$value = [System.Environment]::GetEnvironmentVariable($token)
			#Write-Verbose "Set-TokenContent:$token=$value"
			$results = $results.replace($org,$value)
		}
		return $results
	}

	#TODO - extract to own script or finish inclusion in Set-Env with Nick
	function Set-Envs($path) {
		try {
			if ($path) {
				#Write-Verbose "checking:$path\*.env*"
				if (Test-Path $path\*.env*) {
					Get-ChildItem –Path $path\*.env* | Foreach-Object {
						try {
							$f = $_
							#Write-Verbose "checking:$($f.FullName)"							
							$content = (Get-Content $f.FullName)
							$content | ForEach-Object {
								if (-not ($_ -like '#*') -and  ($_ -like '*=*')) {
									$sp = $_.Split('=')
									#Write-Verbose "Set-Env $($sp[0])=$($sp[1])"
									#$env:${$sp[0]} = $sp[1]
									#$scope = System.EnvironmentVariableTarget]::User
									#$scope = System.EnvironmentVariableTarget]::Session
									#$scope = System.EnvironmentVariableTarget]::Machine
									#[System.Environment]::SetEnvironmentVariable($sp[0], $sp[1], $scope)
									[System.Environment]::SetEnvironmentVariable($sp[0], $sp[1])									
									Write-Verbose "Set-Env $($sp[0])=$($sp[1]):set"
								}
							}
						}
						catch {
							Write-Error "ERROR Set-Env $path-$f" -InformationVariable results
						}
					}
				} else { 
					#Write-Verbose "skipped:$p no *.env* files found"
				}
			}
		}
		catch {
			Write-Error "ERROR Set-Env $path" -InformationVariable results
		}
	}
 
	if (!$source) { $source = "$currLocation\*.json" }
	if (-not (Test-Path $source)) {
		Write-Host "$PSScriptName skipped - empty source:$source"
		return "$PSScriptName skipped - empty source:$source"
	}
	#Write-Verbose "source:$source"
	#Write-Verbose "destination:$destination"
	if (!$destination) {$destination = $source} elseif ($destination.IndexOf(':') -eq -1 -and $destination.Substring(0,1) -ne '\') {$destination = Join-Path $currLocation $destination}
	#Write-Verbose "destination:$destination"
	if ($destination) {
		if (-not (Test-Path $source -PathType Leaf)) {
			if (-not (Test-Path $destination)) { New-Item -Path $destination -ItemType Directory | Out-Null}			
		} else {
			$destParent = Split-Path $destination -Parent
			if (-not (Test-Path $destParent)) { New-Item -Path $destParent -ItemType Directory | Out-Null}
		}
	}

	@((Split-Path $profile -Parent),$PSScriptRoot,("$currLocation" -ne "$PSScriptRoot" ? $currLocation : ''),(Split-Path $source -Parent),($destination -ne $source -and $destParent) ? $destParent : '').foreach({
		Set-Envs $_ -Verbose
	})
	#if ($destination -ne $path -and -not (Test-Path $destination -PathType Leaf)) { Set-Envs $destination }

	if (-not (Test-Path $source) -or (Test-Path $source -PathType Leaf)) {
		if(-not (Test-Path $source -PathType Leaf)) {
			$results = Set-TokenContent $source
		} else {
			$source = Get-Content $source
			$results = Set-TokenContent $source
			#Write-Verbose "updated:$destination"
			$results | Out-File $destination
		}
	} else {
		#Write-Verbose "source:$source"
		Get-ChildItem –Path $source | Foreach-Object {
			$path = $_.FullName
			#Write-Verbose "path:$path"
			if (!(Test-Path $path -PathType Leaf)) {
				#Write-Verbose "SKIPPED Folder:$path"
			} else {	
				$string = Set-TokenContent (Get-Content $path)			
				#Write-Verbose "tokenized:$string"
				if (!$destination) {
					#Write-Verbose "updated:$path"
					$string | Out-File $path
				} else {					
					if ($destination.IndexOf('.') -gt -1) {
						#Write-Verbose "updated:$destination"
						$string | Out-File $destination
					} else {
						$currDestination = "$destination\$($_.Name)"
						#Write-Verbose "updated:$currDestination"
						$string | Out-File $currDestination
					}
				}
			}
			$results = $path
		}	
	}
	Write-Verbose "$PSScriptName end"
	return $results
}