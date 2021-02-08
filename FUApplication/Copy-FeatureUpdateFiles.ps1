<#
.SYNOPSIS
    Copies files using the Process-Content script
.DESCRIPTION
    Copies all required Feature Update files/scripts to a device. Designed to be deployed as an Application from SCCM.
.PARAMETER GUID
    A unique GUID required by Windows 10 Feature Updates
    Run New-GUID to get a new GUID any time changes are made to the content folders..
.PARAMETER RemoveOnly
    Set to true for the uninstall commandline in SCCM
    Powershell.exe -ExecutionPolicy ByPass -File Copy-FeatureUpdateFiles.PS1
.PARAMETER TranscriptPath

.PARAMETER TempDirPath
    Directory root for scripts to be copied to.

.NOTES
  Version:          1.1
  Author:           Adam Gross - @AdamGrossTX
  GitHub:           https://www.github.com/AdamGrossTX
  WebSite:          https://www.asquaredozen.com
  Creation Date:    08/08/2019
  Purpose/Change:
    1.0 Initial script development
    1.1 Updated formatting

.EXAMPLE
    Uninstall all files/folders
    Copy-FeatureUpdateFiles.PS1 -RemoveOnly

.EXAMPLE
    Copy all content
    Copy-FeatureUpdateFiles.PS1 -GUID "ca3d0b66-131d-4e85-b474-98565a01a1f2"

.EXAMPLE
    Remove DestPath and all child content without copying any new content
    ProcessContent -DestPath $DestPath -DestChildFolder $DestChild -RemoveLevel Root -RemoveOnly

.EXAMPLE
    SCCM CommandLine
    Powershell.exe -ExecutionPolicy ByPass -File Copy-FeatureUpdateFiles.PS1
 #>
 [cmdletbinding()]
 Param (

    [Parameter()]
    [string]$GUID,

    [Parameter()]
    [string]$Path,

    [Parameter()]
    [switch]$RemoveOnly,

    [Parameter()]
    [string]$TranscriptPath,

    [Parameter()]
    [string]$BaselineName
)
#Import the Process-Content script/function. This file should be present in the folder where you are launching this file from, or you need to change the path.
. (Join-Path -Path $PSScriptRoot -ChildPath ".\Scripts\Process-Content.ps1" -ErrorAction SilentlyContinue)
. (Join-Path -Path $PSScriptRoot -ChildPath ".\Scripts\Trigger-DCMEvaluation.ps1" -ErrorAction SilentlyContinue)

Start-Transcript -Path $TranscriptPath -Append -Force -ErrorAction SilentlyContinue
$Sources = @{
    "Update" = @{
        SourcePath = (Join-Path -Path $PSScriptRoot -ChildPath "Update")
        DestPath = "c:\Windows\System32\update\run"
        DestChildFolder = $GUID
        RemoveLevel = 'Root'
    }
    "Scripts" = @{
        SourcePath = (Join-Path -Path $PSScriptRoot -ChildPath "Scripts")
        DestPath = $Path
        DestChildFolder = "Scripts"
        RemoveLevel = 'Child'
        Hide = $True
    }
}

ForEach($Key in $Sources.keys) {
    $ArgList = $Sources[$Key]
    If($RemoveOnly.IsPresent) {
        $ArgList.Remove("SourcePath")
        $ArgList.Remove("Hide")
        $ArgList["RemoveOnly"] = $True
    }
    ProcessContent @ArgList -ErrorAction Continue
}

#####
#Update permissions on the new folder to prevent users from replacing script content.
$User = "NT AUTHORITY\Authenticated Users"
$ACL = Get-Acl -Path $Path
$ACL.SetAccessRuleProtection($True, $True) # Remove inheritance 
$ACL.Access | Where-Object {$_.IdentityReference -eq $User} | ForEach-Object {$ACL.RemoveAccessRule($_)}
Set-ACL -Path $Path -AclObject $ACL | Out-Null # Apply ACL on folder
$ACL = Get-Acl -Path $Path
#Add ReadAndExecute back for Authenticated Users
$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($User,"ReadAndExecute, Synchronize", "ContainerInherit,ObjectInherit", "None", "Allow")
$ACL.SetAccessRule($AccessRule)
Set-ACL -Path $Path -AclObject $ACL | Out-Null # Apply ACL on folder
#####

If($BaselineName) {
    Trigger-DCMEvaluation -BaseLine $BaselineName -ErrorAction SilentlyContinue
}

Stop-Transcript