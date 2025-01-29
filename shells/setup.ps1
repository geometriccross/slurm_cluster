# Enables the WinRM service and sets up the HTTP listener
Enable-PSRemoting -Force

# Opens port 5985 for all profiles
$firewallParams = @{
    Action      = 'Allow'
    Description = 'Inbound rule for Windows Remote Management via WS-Management. [TCP 5985]'
    Direction   = 'Inbound'
    DisplayName = 'Windows Remote Management (HTTP-In)'
    LocalPort   = 5985
    Profile     = 'Any'
    Protocol    = 'TCP'
}
New-NetFirewallRule @firewallParams

# Allows local user accounts to be used with WinRM
# This can be uncoment if not using domain accounts
# $tokenFilterParams = @{
#     Path         = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
#     Name         = 'LocalAccountTokenFilterPolicy'
#     Value        = 1
#     PropertyType = 'DWORD'
#     Force        = $true
# }
# New-ItemProperty @tokenFilterParams

# Install tailscale
Invoke-WebRequest 'https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe' -OutFile 'tailscale-setup-latest.exe'
.\tailscale-setup-latest.exe
