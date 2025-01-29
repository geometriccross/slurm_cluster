Param(
	[Parameter(Mandatory=$true)][string]$VMName,
	[Parameter(Mandatory=$true)][string]$InstallMediaPath,
	[string]$VHDFolder = "C:\ProgramData\Microsoft\Windows\Virtual Hard Disks",
	[string]$VMSwitch = "Default Switch",
	[int]$CPUCores = 2,
	[int]$Memory = 2,
	[int]$DiskSize = 50,
	[string]$VHDXType = "D"
)

# set vhdx file stored pos
$VHDPath = Join-Path -Path $VHDFolder -ChildPath ($VMName + ".vhdx")

# convert memory and disk size to bytes
$MemoryBytes = [int]$Memory * 1GB
$DiskSizeBytes = [int]$DiskSize * 1GB

# check VHDX type
while ($VHDXType -ne "D" -and $VHDXType -ne "d" -and $VHDXType -ne "F" -and $VHDXType -ne "f") {
	Write-Host "Invalid input"
	$VHDXType = Read-Host -Prompt "VHDX Type: D for Dynamic, F for Fixed"
}

if ($VHDXType -eq "D" -or $VHDXType -eq "d") {
	$VHDXType = "Dynamic"
} else {
	$VHDXType = "Fixed"
}

# create vm
New-VM `
	-Name $VMName `
	-MemoryStartupBytes $MemoryBytes `
	-NewVHDPath $VHDPath `
	-NewVHDSizeBytes $DiskSizeBytes `
	-Generation 2 `
	-Switch 'Default Switch'

Set-VMProcessor $VMName -Count $CPUCores

Set-VMMemory `
	-VMName $VMName `
	-DynamicMemoryEnabled $true `
	-MinimumBytes 512MB `
	-StartupBytes $MemoryBytes `
	-MaximumBytes $MemoryBytes

Add-VMDvdDrive `
	-VMName $VMName `
	-Path $InstallMediaPath

Set-VMFirmware $VMName `
	-EnableSecureBoot Off `
	-FirstBootDevice $(Get-VMDvdDrive -VMName $VMName)

Start-VM -Name $VMName

# status show
$VMInfo = Get-VM $VMName | Select-Object Name, State, @{Name="CPU"; Expression={$_.ProcessorCount}}, @{Name="MemoryGB"; Expression={[math]::Round($_.MemoryAssigned / 1GB, 2)}}, Version | Format-Table -AutoSize | Out-String
Write-Host "VM Information:"
Write-Host $VMInfo

$VHDXInfo = Get-VHD $VHDPath | Select-Object Path, @{Name="SizeGB"; Expression={[math]::Round(($_.Size / 1GB), 2)}}, VhdType | Format-Table -AutoSize | Out-String
Write-Host "VHDX Information:"
Write-Host $VHDXInfo

vmconnect $env:COMPUTERNAME $VMName
Pause
