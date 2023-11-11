#2023.11.11.1205


<#
$strComputerName = "Computer.domain.com"

$objResult = $sbInvokeCommandAs.InvokeReturnAsIs($strComputerName, {return $true}, $null, $objRunAsCredential, $false)
Enter-PSSession -ComputerName $strComputerName -ConfigurationName ([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value)
hostname
Exit-PSSession
$objResult = $sbInvokeCommandAs.InvokeReturnAsIs($strComputerName, {return $true}, $null, $objRunAsCredential, $true)
#>



<#
$strComputerName = "Computer.domain.com"

$sbCommand = {
	param(
		$strLDAPServer,
		$strObjectDN
	)


	$strObjectADsPath = "LDAP://" + $strLDAPServer + "/" + $strObjectDN.Replace("/", "\/")
	$objADSIObject = New-Object -TypeName System.DirectoryServices.DirectoryEntry($strObjectADsPath)
	$objADSIObject.RefreshCache("ADsPath")
	return $objADSIObject.ADsPath
}

$arrCommandArguments = @(
	[System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain().Name
	"CN=User,OU=Container,DC=domain,DC=com"
)

$objRunAsCredential = Get-Credential -Credential ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)


$objResult = $sbInvokeCommandAs.InvokeReturnAsIs($strComputerName, $sbCommand, $arrCommandArguments, $objRunAsCredential)
#>



<#
$strComputerName = "Computer.domain.com"
$sbCommand = {hostname}
$arrCommandArguments = $null
$objRunAsCredential = Get-Credential -Credential ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
$bTemporaryConfiguration = $true
$objConnectAsCredential = Get-Credential -Credential ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)


$objResult = $sbInvokeCommandAs.InvokeReturnAsIs($strComputerName, $sbCommand, $arrCommandArguments, $objRunAsCredential, $bTemporaryConfiguration, $objConnectAsCredential)
#>



####################################################################################################
$sbInvokeCommandAs = {
	param(
		[System.String] $strComputerName =".",
		[System.Management.Automation.ScriptBlock] $sbCommand = {return "Hello World!"},
		[System.Object[]] $arrCommandArguments = @(),
		[System.Management.Automation.PSCredential] $objRunAsCredential = (Get-Credential -Credential ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)),
		[System.Boolean] $bTemporaryConfiguration = $true,
		[System.Management.Automation.PSCredential] $objConnectAsCredential = $null,
		[System.UInt16] $uiWinRMRestartWaitTime = 2000
	)


	$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

	$hshInvokeCommand = @{
		"ComputerName" = $strComputerName
	}

	if ($null -ne $objConnectAsCredential)
	{
		$hshInvokeCommand.Add("Credential", $objConnectAsCredential)
	}


	####################################################################################################
	$sbGetCurrentUser = {
		return [System.Security.Principal.WindowsIdentity]::GetCurrent()
	}
	####################################################################################################


	####################################################################################################
	$sbRegisterRunAsSessionConfiguration = {
		param(
			$strUserSID,
			$objRunAsCredential
		)


		try
		{
			$null = Get-PSSessionConfiguration -Name $strUserSID -ErrorAction ([System.Management.Automation.ActionPreference]::Stop)
			return $false
		}
		catch
		{
			#Session Configuration doesn't exist, therefore we need to register it
		}

		$hshSessionConfiguration = @{
			"Name" = $strUserSID
			"RunAsCredential" = $objRunAsCredential
			"SecurityDescriptorSddl" = "O:NSG:BAD:P(A;;GA;;;" + $strUserSID + ")S:P(AU;FA;GA;;;WD)(AU;SA;GXGW;;;WD)"
			"NoServiceRestart" = $true
			"Force" = $false
			"Confirm" = $false
			"WarningAction" = [System.Management.Automation.ActionPreference]::SilentlyContinue
		}
		#Looks like a bug - Windows 2016 shows warning message anyway, so suppressing it with "3> $null"
		$null = Register-PSSessionConfiguration @hshSessionConfiguration 3> $null

		return $true
	}
	####################################################################################################


	####################################################################################################
	$sbSetSessionConfiguration = {
		param(
			$strUserSID,
			$objRunAsCredential
		)


		$hshSessionConfiguration = @{
			"Name" = $strUserSID
			"RunAsCredential" = $objRunAsCredential
			"SecurityDescriptorSddl" = "O:NSG:BAD:P(A;;GA;;;" + $strUserSID + ")S:P(AU;FA;GA;;;WD)(AU;SA;GXGW;;;WD)"
			"NoServiceRestart" = $false
			"Force" = $true
			"WarningAction" = [System.Management.Automation.ActionPreference]::SilentlyContinue
		}
		$null = Set-PSSessionConfiguration @hshSessionConfiguration
	}
	####################################################################################################


	####################################################################################################
	$sbUnregisterRunAsSessionConfiguration = {
		param(
			$strUserSID
		)


		$hshSessionConfiguration = @{
			"Name" = $strUserSID
			"Force" = $true
			"ErrorAction" = [System.Management.Automation.ActionPreference]::Stop
		}

		try
		{
			Unregister-PSSessionConfiguration @hshSessionConfiguration
		}
		catch
		{
			return $false
		}

		return $true
	}
	####################################################################################################


	try
	{
		$objConnectAsUser = Invoke-Command @hshInvokeCommand -ScriptBlock $sbGetCurrentUser
		$strConnectAsUserSID = $objConnectAsUser.User.ToString()

		$bNewConfiguration = Invoke-Command @hshInvokeCommand -ArgumentList @($strConnectAsUserSID, $objRunAsCredential) -ScriptBlock $sbRegisterRunAsSessionConfiguration
	}
	catch
	{
		throw $Error[0]
	}

	if ($bNewConfiguration -or $bTemporaryConfiguration)
	{
		Invoke-Command @hshInvokeCommand -ArgumentList @($strConnectAsUserSID, $objRunAsCredential) -ScriptBlock $sbSetSessionConfiguration -ErrorAction ([System.Management.Automation.ActionPreference]::SilentlyContinue)
		[System.Threading.Thread]::Sleep($uiWinRMRestartWaitTime)
	}

	try
	{
		$objResult = Invoke-Command @hshInvokeCommand -ConfigurationName $strConnectAsUserSID -ArgumentList $arrCommandArguments -ScriptBlock $sbCommand
	}
	catch
	{
		throw $Error[0]
	}
	finally
	{
		if ($bTemporaryConfiguration)
		{
			$bResult = Invoke-Command @hshInvokeCommand -ArgumentList @($strConnectAsUserSID) -ScriptBlock $sbUnregisterRunAsSessionConfiguration -ErrorAction ([System.Management.Automation.ActionPreference]::SilentlyContinue)
			if ($bResult -eq $false)
			{
				Write-Warning -Message "Temporary Run As Session Configuration hasn't been unregistered."
			}
		}
	}

	return $objResult
}
####################################################################################################