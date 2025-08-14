<#
.SYNOPSIS
    Automates the forced update of VMware Tools on virtual machines with PowerCLI.

.DESCRIPTION
    This script connects to a vCenter Server, identifies virtual machines with outdated VMware Tools,
    takes a snapshot of the VMs (optional but highly recommended), and then initiates a forced update
    of VMware Tools using the -NoReboot parameter to prevent immediate guest OS restarts.
    Logging is implemented to track the process.

.PARAMETER vCenterServer
    The IP address or FQDN of the vCenter Server.

.PARAMETER LogFilePath
    The path to the log file where the script's output will be stored.

.EXAMPLE
    .\Update-VMwareTools-Forced.ps1 -vCenterServer "your_vcenter.your_domain.com" -LogFilePath "C:\Logs\VMwareToolsUpdate.log"

.NOTES
    - Requires VMware PowerCLI modules to be installed.
    - It's crucial to test this script in a lab environment before running it in production.
    - Snapshots are created before the update for easy rollback if issues occur.
    - The -NoReboot parameter attempts to update without rebooting, but reboots may still occur depending
      on the guest OS and Tools version. A separate reboot schedule might be necessary.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$vCenterServer,

    [Parameter(Mandatory=$false)]
    [string]$LogFilePath = "C:\Logs\VMwareToolsUpdate_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
)

# Function for logging messages
function Write-Log {
    param(
        [string]$Message,
        [string]$Type = "Information" # Can be Information, Warning, Error
    )
    $LogEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Type] $Message"
    Add-Content -Path $LogFilePath -Value $LogEntry
    Write-Host $LogEntry
}

# --- Script Start ---
Write-Log -Message "Script initiated for VMware Tools update on vCenter Server: $vCenterServer"

# Check if PowerCLI modules are installed and imported
if (-not (Get-Module -ListAvailable -Name VMware.VimAutomation.Core)) {
    Write-Log -Message "VMware PowerCLI module 'VMware.VimAutomation.Core' not found. Please install it." -Type "Error"
    exit 1
}

# Connect to vCenter Server
try {
    Write-Log -Message "Attempting to connect to vCenter Server: $vCenterServer"
    Connect-VIServer -Server $vCenterServer -Credential (Get-Credential) -ErrorAction Stop
    Write-Log -Message "Successfully connected to vCenter Server: $vCenterServer"
}
catch {
    Write-Log -Message "Failed to connect to vCenter Server: $_.Exception.Message" -Type "Error"
    exit 1
}

# Get VMs with outdated VMware Tools
Write-Log -Message "Identifying VMs with outdated VMware Tools..."
$vmsToUpdate = Get-VM | Get-VMGuest | Where-Object {$_.ToolsVersionStatus -eq "guestToolsNeedUpgrade" -and $_.State -eq "Running"}

if ($vmsToUpdate.Count -eq 0) {
    Write-Log -Message "No VMs found with outdated and running VMware Tools."
}
else {
    Write-Log -Message "$($vmsToUpdate.Count) VMs identified for VMware Tools update."

    foreach ($vmGuest in $vmsToUpdate) {
        $vm = $vmGuest.VM
        Write-Log -Message "Processing VM: $($vm.Name)"

        # Optional: Take a snapshot before updating tools
        try {
            Write-Log -Message "Taking snapshot for VM: $($vm.Name)"
            New-Snapshot -VM $vm -Name "Pre-VMwareTools-Update-$(Get-Date -Format 'yyyyMMdd_HHmmss')" -Description "Snapshot before forced VMware Tools update" -Memory:$false -Quiesce:$false -Confirm:$false -ErrorAction Stop
            Write-Log -Message "Snapshot created successfully for VM: $($vm.Name)"
        }
        catch {
            Write-Log -Message "Failed to create snapshot for VM $($vm.Name): $_.Exception.Message" -Type "Error"
            # Decide if you want to stop or continue without a snapshot
            # For this example, we'll continue, but in production, you might want to stop.
        }

        # Perform the forced update without reboot
        try {
            Write-Log -Message "Initiating forced VMware Tools update for VM: $($vm.Name) (No Reboot)"
            Update-Tools -VM $vm -NoReboot -Force -ErrorAction Stop
            Write-Log -Message "VMware Tools update initiated for VM: $($vm.Name)."
        }
        catch {
            Write-Log -Message "Failed to initiate VMware Tools update for VM $($vm.Name): $_.Exception.Message" -Type "Error"
        }
    }
}

# Disconnect from vCenter Server
try {
    Write-Log -Message "Disconnecting from vCenter Server: $vCenterServer"
    Disconnect-VIServer -Server $vCenterServer -Confirm:$false -ErrorAction Stop
    Write-Log -Message "Successfully disconnected from vCenter Server: $vCenterServer"
}
catch {
    Write-Log -Message "Failed to disconnect from vCenter Server: $_.Exception.Message" -Type "Error"
}

Write-Log -Message "Script finished."
# --- Script End ---
