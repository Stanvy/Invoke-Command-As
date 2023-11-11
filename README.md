# Invoke Command As

Solves double/triple/quadro (you've got an idea😉) hop problem and allows to execute PowerShell command/script/whatever in a same way as if it was running locally.

## Dot-source the main code as the first step:
```PowerShell
. ".\Invoke Command As.ps1"
```

## Use-case 1 - execute necessary PowerShell activities remotely just once and perform clean-up upon completion:
```PowerShell
$objRunAsCredential = Get-Credential -Credential ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
$sbInvokeCommandAs.InvokeReturnAsIs("Computer.domain.com", {hostname}, $null, $objRunAsCredential)
```


## The same use-case with more advanced example, which actually represents double-hop problem:
```PowerShell
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
```


## Use-case 2 - spin-up all the necessary plumbing around remote execution, re-use it and clean-up when done:
```PowerShell
$strComputerName = "Computer.domain.com"

#Create persistent remote session
$objResult = $sbInvokeCommandAs.InvokeReturnAsIs($strComputerName, {return $true}, $null, $objRunAsCredential, $false)

#Enter remote session created
Enter-PSSession -ComputerName $strComputerName -ConfigurationName ([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value)

#Perform whatever is needed inside the session and exit
hostname
Exit-PSSession

#Clean-up
$objResult = $sbInvokeCommandAs.InvokeReturnAsIs($strComputerName, {return $true}, $null, $objRunAsCredential, $true)
```



## Use-case 3 - connect to remote host with explicit credentials:
```PowerShell
$strComputerName = "Computer.domain.com"
$sbCommand = {hostname}
$arrCommandArguments = $null
$objRunAsCredential = Get-Credential -Credential ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
$bTemporaryConfiguration = $true
$objConnectAsCredential = Get-Credential -Credential ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)


$objResult = $sbInvokeCommandAs.InvokeReturnAsIs($strComputerName, $sbCommand, $arrCommandArguments, $objRunAsCredential, $bTemporaryConfiguration, $objConnectAsCredential)
```