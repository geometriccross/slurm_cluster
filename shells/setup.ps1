Param(
	[string]$ControllerSSHUserHost,
	[int]$ControllerSSHPort=22,
	[int]$NewSSHPort=22,
	[string]$TailscaleAuthKey
)

Get-WindowsCapability -Name OpenSSH.Server* -Online | Add-WindowsCapability -Online
Set-Service -Name sshd -StartupType Automatic -Status Running
if (-not (Test-Path '~\.ssh')) {
	New-Item -Type Directory -Path '~\.ssh'
}


$firewallParams = @{
	Name        = 'sshd-Server-In-TCP'
	DisplayName = ('Inbound rule for OpenSSH Server (sshd) on TCP port ' + $NewSSHPort)
	Action      = 'Allow'
	Direction   = 'Inbound'
	Enabled     = 'True'  # This is not a boolean but an enum
	Profile     = 'Any'
	Protocol    = 'TCP'
	LocalPort   = $NewSSHPort
}
New-NetFirewallRule @firewallParams

$shellParams = @{
	Path         = 'HKLM:\SOFTWARE\OpenSSH'
	Name         = 'DefaultShell'
	Value        = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
	PropertyType = 'String'
	Force        = $true
}
New-ItemProperty @shellParams

# Install tailscale
Invoke-WebRequest 'https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe' -OutFile 'tailscale-setup-latest.exe'
Start-Process -Wait -FilePath .\tailscale-setup-latest.exe
# this work like "source ~/.bashrc"
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
if ([string]::IsNullOrEmpty($TailscaleAuthKey)) {
	Start-Process -Wait -FilePath "tailscale" -ArgumentList "up", "--authkey=$TailscaleAuthKey"
} else {
	Start-Process -Wait -FilePath "tailscale" -ArgumentList "up"
}

Remove-Item -Path .\tailscale-setup-latest.exe

if (-not ([string]::IsNullOrEmpty($SSHUserHost))) {
	$key_name = ('cluster_' + (HOSTNAME))
	ssh-keygen -q -t ed25519 -f ($env:USERPROFILE + '\.ssh\' + $key_name) -N '""'
	# publish private key to controller
	Get-Content $key_name | ssh $ControllerSSHUserHost -p $ControllerSSHPort "@
		mkdir -p ~/.ssh && chmod 700 ~/.ssh;
		cat > ~/.ssh/$key_name \
			&& chmod 600 ~/.ssh/$key_name;
	"
}
