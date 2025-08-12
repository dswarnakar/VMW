# --- Configuration ---
$vCenterServer = "your_vcenter_server_name_or_ip" # Replace with your vCenter server address
$vmListFile = "C:\Temp\VMsToPowerOff.txt" # Path to a text file containing VM names, one per line

# --- Script Logic ---

# Connect to vCenter Server
Connect-VIServer -Server $vCenterServer

# Check if the VM list file exists
if (-not (Test-Path $vmListFile)) {
    Write-Host "Error: VM list file '$vmListFile' not found." -ForegroundColor Red
    Exit
}

# Read VM names from the file
$vmNames = Get-Content $vmListFile

# Process each VM
foreach ($vmName in $vmNames) {
    Write-Host "Attempting to power off VM: $vmName"

    # Get the VM object
    $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue

    if ($vm) {
        # Check if the VM is powered on
        if ($vm.PowerState -eq "PoweredOn") {
            # Attempt graceful shutdown via VMware Tools
            Write-Host "Initiating graceful shutdown for $vmName..."
            Stop-VMGuest -VM $vm -Confirm:$false -ErrorAction SilentlyContinue

            # Wait for a short period for graceful shutdown
            Start-Sleep -Seconds 30

            # Check if VM is still powered on after graceful shutdown attempt
            $vm = Get-VM -Name $vmName # Refresh VM object
            if ($vm.PowerState -eq "PoweredOn") {
                Write-Warning "VMware Tools shutdown failed or timed out for $vmName. Forcing power off."
                Stop-VM -VM $vm -Confirm:$false -Force -RunAsync
            } else {
                Write-Host "$vmName successfully shut down gracefully." -ForegroundColor Green
            }
        } else {
            Write-Host "$vmName is already powered off." -ForegroundColor Yellow
        }
    } else {
        Write-Warning "VM '$vmName' not found in vCenter."
    }
}

# Disconnect from vCenter Server
Disconnect-VIServer -Server $vCenterServer -Confirm:$false
