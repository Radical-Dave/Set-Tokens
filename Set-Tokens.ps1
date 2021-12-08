#Set-StrictMode -Version Latest
#####################################################
# Set-Tokens
#####################################################
<#PSScriptInfo

.VERSION 0.5

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
	$ProgressPreference = "SilentlyContinue"		
	$ErrorActionPreference = 'Stop'
	$PSScriptName = ($MyInvocation.MyCommand.Name.Replace(".ps1",""))
	$PSCallingScript = if ($MyInvocation.PSCommandPath) { $MyInvocation.PSCommandPath | Split-Path -Parent } else { $null }
	$currLocation = "$(Get-Location)"
	Write-Verbose "$PSScriptRoot\$PSScriptName $source $destination called by:$PSCallingScript from $currLocation"

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
 
	if (!$source) { $source = "$currLocation\*.json" }
	Write-Host "source:$source"

	@((Split-Path $profile -Parent),$PSScriptRoot,("$currLocation" -ne "$PSScriptRoot" ? $currLocation : ''),(Split-Path $source -Parent)).foreach({
		try {
			$p = $_
			if ($p) {
				#Write-Verbose "checking:$p\*.env*"
				if (Test-Path $p\*.env*) {
					Get-ChildItem –Path $p\*.env* | Foreach-Object {
						try {
							$f = $_
							#Write-Verbose "checking:$($f.FullName)"							
							$content = (Get-Content $f.FullName)
							$content | ForEach-Object {
								if (-not ($_ -like '#*') -and  ($_ -like '*=*')) {
									$sp = $_.Split('=')
									#Write-Verbose "Set-Env $($sp[0])=$($sp[1])"
									[System.Environment]::SetEnvironmentVariable($sp[0], $sp[1])
								}
							}
						}
						catch {
							Write-Error "ERROR Set-Env $p-$f" -InformationVariable results
						}
					}
				} else { 
					#Write-Verbose "skipped:$p no *.env* files found"
				}
			}
		}
		catch {
			Write-Error "ERROR Set-Env $p" -InformationVariable results
		}
	})

	if (-not (Test-Path $source) -or (Test-Path $source -PathType Leaf)) {
		if(-not (Test-Path $source -PathType Leaf)) {
			Write-Verbose "Leaf!:$source"
			$results = Set-TokenContent $source
		} else {
			$path = $source
			$source = Get-Content $source
			#Write-Verbose "source:$source"
			$results = Set-TokenContent $source
			if (!$destination) {$destination = $path} elseif ($destination.IndexOf(':') -eq -1 -and $destination.Substring(0,1) -ne '\') {$destination = Join-Path $currLocation $destination}
			$destParent = Split-Path $destination -Parent
			#Write-Verbose "destParent:$destParent"
			if (-not (Test-Path $destParent)) { New-Item -Path $destParent -ItemType Directory | Out-Null}
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
						#Write-Verbose "path:$path"
						#Write-Verbose "source:$source"			
						#Write-Verbose "destination:$destination"
						$currDestination = "$destination\$($_.Name)"
						#Write-Verbose "currDestination:$currDestination"
						$destParent = Split-Path $currDestination -Parent
						#Write-Verbose "destParent:$destParent"
						if (-not (Test-Path $destParent)) { New-Item -Path $destParent -ItemType Directory | Out-Null}
						#Write-Verbose "updated:$currDestination"
						$string | Out-File $currDestination
					}
				}
			}
			$results = $path
		}	
	}
	Write-Verbose "$PSScriptName $path end"
	return $results
}