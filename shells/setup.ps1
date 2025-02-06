Param(
	[string]$SSHUserHost,
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
	$key_name = ('cluster_' + (HOSTNAME.exe))
	$tmp_key_path = Join-Path $env:USERPROFILE ".ssh\${key_name}_tmp"
	$tmp_pubkey_path = "${tmp_key_path}.pub"
	ssh-keygen -q -t ed25519 -f $tmp_key_path -N '""'

	# pub_key publish
	Get-Content $tmp_pubkey_path | ssh $SSHUserHost -p $ControllerSSHPort @"
mkdir -p ~/.ssh && chmod 700 ~/.ssh;
cat >> ~/.ssh/authorized_keys \
	&& chmod 600 ~/.ssh/authorized_keys

# key generate for scp
ssh-keygen -q -t ed25519 -f ~/.ssh/$key_name -N ""
"@

	scp -P $ControllerSSHPort "${SSHUserHost}:~/.ssh/${key_name}.pub" "${env:USERPROFILE}\.ssh\${key_name}"
	Get-Content "${env:USERPROFILE}\.ssh\${key_name}" | Out-File -Append -Force "${env:ALLUSERPROFILE}\ssh\administrators_authorized_keys"

	# remove temporary files
	Remove-Item -Force "${tmp_key_path}" "${tmp_pubkey_path}"
}
