Param(
	[string]$ControlHostName,
	[string]$TailscaleAuthKey
)

Get-WindowsCapability -Name OpenSSH.Server* -Online |
	Add-WindowsCapability -Online
Set-Service -Name sshd -StartupType Automatic -Status Running

$firewallParams = @{
	Name        = 'sshd-Server-In-TCP'
	DisplayName = 'Inbound rule for OpenSSH Server (sshd) on TCP port 22'
	Action      = 'Allow'
	Direction   = 'Inbound'
	Enabled     = 'True'  # This is not a boolean but an enum
	Profile     = 'Any'
	Protocol    = 'TCP'
	LocalPort   = 22
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
if ([string]::IsNullOrEmpty($TailscaleAuthKey)) {
	tailscale up --authkey=$TailscaleAuthKey
} else {
	tailscale up
}

Remove-Item 'tailscale-setup-latest.exe'

if ([string]::IsNullOrEmpty($ControlHostName)) {
	ssh-keygen -q -t ed25519 -f ~\.ssh\cluster -N ""
	$pub_key = '~\.ssh\cluster.pub'
	Get-Content $pub_key | ssh $ControlHostName "@
		mkdir -p ~/.ssh \
			&& chmod 700 ~/.ssh \
			&& cat >> ~/.ssh/authorized_keys \
			&& chmod 600 ~/.ssh/authorized_keys
	"
}
