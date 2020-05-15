# PowerShell Skript zur automatisierten Installation eines OpenSSH Server und der Option, VIM als Standardeditor festzulegen.

#Requires -RunAsAdministrator




###### Funktionen ######

# Auswahlmenue
function Show-Menu
{
    param (
        [string]$Title = 'Auswahlmenue'
    )
    Clear-Host
    write-Host "================ $Title ================"
    
    Write-Host "1: OpenSSH Server installieren"
    Write-Host "2: VIM installieren"
    Write-Host "3: PowerShell als SSH-Shell festlegen"
    Write-Host "Q: Beenden"
}


# (1) OpenSSH Server installieren und aktivieren
function install-openssh-server
{
	# Check ob der OpenSSH Server bereits aktiv ist
	if ( [bool](Get-Service | ? name -eq sshd | ? status -eq Running) )
	{
		write-host "Der OpenSSH Server ist bereits gestartet."
		return
	}

	# Check ob OpenSSH Server bereits installiert ist
	if ( [bool](Get-WindowsCapability -Online | ? Name -like 'OpenSSH.Server*' | ? State -like 'Installed') )
	{
		write-host "OpenSSH Server ist bereits installiert."
		return
	}


	# OpenSSH Server installieren
	write-host "OpenSSH Server wird installiert."
	Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
	Start-Service sshd
	Set-Service -Name sshd -StartupType 'Automatic'
	
	# Firewall Regeln checken
	if ( -Not ( [bool](Get-NetFirewallRule -Name *ssh*) ) )
	{
		New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
	}
	
}


# (2) Installation von VIM
function install-vim
{
	# Check, ob ExecutionPolicy korrekt gesetzt ist
	if ( -not( (Get-ExecutionPolicy) -eq 'Unrestricted' ) )
	{	
		write-host "Setze ExecutionPolicy auf Unrestricted."
		Set-ExecutionPolicy Unrestricted
	}	
	
	# Check, ob VIM schon installiert ist
	if ( (Test-path -LiteralPath "$env:Programdata\chocolatey") )
	{
		write-Host "VIM ist bereits installiert"
		return
	}
	
	Invoke-WebRequest https://chocolatey.org/install.ps1 -UseBasicParsing | Invoke-Expression;
	choco install vim
	choco update vim

	$command = (Get-itemProperty -LiteralPath "HKLM:\SOFTWARE\Classes\`*\shell\Vim\Command").'(default)';

	if ($command -match "`"([^`"]+)`".*") 
	{
		$expression = "Set-Alias -Name 'vim' -Value '$($Matches[1])';"

		if (-Not (Test-Path "$PROFILE")) {
			"$expression`r`n" | Out-File -FilePath "$PROFILE" -Encoding UTF8;
		} elseif (Get-Content "$PROFILE" | Where-Object { $_ -eq "$expression" } ) { 
			Add-Content '$PROFILE' "`r`n$expression`r`n";
		}
	}
}


# (3) PowerShell als Shell festlegen
function set-pwsh-as-default
{
	# Check, ob OpenSSH schon installiert ist (erforderlich)
	if ( -Not ( [bool](Get-WindowsCapability -Online | ? Name -like 'OpenSSH.Server*' | ? State -like 'Installed') ) )
	{
		write-host "Installiere zuerst den OpenSSH Server!"
		return
	}

	$regpath  = "HKLM:\SOFTWARE\OpenSSH"
	$pwshpath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
	
	# Prüfen, ob Aenderung bereits erfolgt
	if ( [bool]((Get-ItemProperty -Path "$regpath").DefaultShell -like "*powershell.exe") )
	{
		write-host "Die PowerShell ist bereits die Standardshell. Keine Aktion erforderlich."
		return
	}

	# Registry wird bearbeitet
	New-ItemProperty -Path "$regpath" -Name DefaultShell -Value "$pwshpath" -PropertyType String -Force
	write-host "PowerShell erfolgreich als Standardshell via SSH festgelegt."

}


#############################################################


# Aufruf des Menues
do
{
	Show-Menu
	$selection = Read-Host "Waehle einen Menuepunkt aus"
	switch ($selection)
	{
		'1' {
				install-openssh-server
			}
		'2' {
				install-vim
			}
		'3' {
				set-pwsh-as-default
			}
		'q' {
				return
			}
	 }
	 pause
}
until ($selection -eq 'q')
