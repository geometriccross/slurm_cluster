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

	# convert CR+LF to only LF
	$remote_cmd = @"
mkdir -p ~/.ssh && chmod 700 ~/.ssh;
ssh-keygen -q -t ed25519 -f ~/.ssh/$key_name -N '';
"@ -replace "`r", ""
	ssh $SSHUserHost -p $ControllerSSHPort -o PreferredAuthentications=password $remote_cmd

	scp -o PreferredAuthentications=password -P $ControllerSSHPort "${SSHUserHost}:~/.ssh/${key_name}.pub" "${env:USERPROFILE}\.ssh\${key_name}.pub"
	Get-Content "${env:USERPROFILE}\.ssh\${key_name}.pub" | Out-File -Append -Encoding utf8 "${env:ALLUSERSPROFILE}\ssh\administrators_authorized_keys"
	icacls.exe "$Env:ProgramData\ssh\administrators_authorized_keys" /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"
	
	$sshd_cfg = "${env:ALLUSERSPROFILE}\ssh\sshd_config"
	$lines = Get-Content -Path $sshd_cfg

	# line 8 is located in Port 22, insert it after port22 line
	$lineIndex = 9
	$insertLine = "Port $NewSSHPort"
	# split before after lines, and put in
	$newLines = $lines[0..($lineIndex - 1)] + $insertLine + $lines[$lineIndex..($lines.Count - 1)]

	# ReWrite lines
	$newLines | Set-Content -Encoding utf8 -Path $sshd_cfg
	Restart-Service sshd
}

# troubleshooting
# https://zenn.dev/noonworks/scraps/abc67a39c74fd0
