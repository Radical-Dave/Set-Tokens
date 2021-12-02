#Set-StrictMode -Version Latest
#####################################################
# Set-Tokens
#####################################################
<#PSScriptInfo

.VERSION 0.1

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
	Write-Verbose "$PSScriptRoot\$PSScriptName $source $destination called by:$PSCallingScript"

	function Set-TokenContent($string) {
		if (!$string) { return $string }
		$results = $string		
		$tokens = [regex]::Matches($string,$regex)
		if (!$tokens) { return $string }
		$tokens | Foreach-Object {
			$org = $_.groups[0].value
			$token = $org
			if ($token -like '$(*') {
				$token = $token.Remove(0,2) 
				$token = $token.Substring(0, $token.Length - 1)
			}
			$value = [System.Environment]::GetEnvironmentVariable($token)
			$results = $string.replace($org,$value)
		}
		return $results
	}

	if (!$source) { $source = Get-Location }
	if (-not (Test-Path $source)) {
		$results = Set-TokenContent $source
	}
	Get-ChildItem –Path $source -recurse | Foreach-Object {
		$path = $_.FullName
		$content = (Get-Content $path)
		$string = Set-TokenContent $content
		if ($destination) {
			if ($destination.IndexOf('.') -gt -1) {
				$string | Out-File $destination
			} else {
				Write-Verbose "path:$path"
				Write-Verbose "source:$source"			
				if ($path.EndsWith($source)) { $destination = $path.Replace($source, "$destination\$source") }
				Write-Verbose "destination:$destination"
				$parent = Split-Path $destination -Parent
				if (-not (Test-Path $parent)) {New-Item -Path $parent -ItemType Directory | Out-Null}
				$string | Out-File $destination
			}
		} else {
			$string | Out-File $path #.replace('.json','-new.json')
		}

		$results = $path
	}	
	Write-Verbose "$PSScriptName $path end"
	return $results
}