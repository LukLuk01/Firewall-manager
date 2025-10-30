# ==============================
# FIREWALL MANAGEMENT SCRIPT v2 (POPRAWIONA WERSJA)
# ==============================

# Pliki w tym samym katalogu co skrypt
$configFile = Join-Path -Path $PSScriptRoot -ChildPath "firewall_rules.json"
$systemBackupFile = Join-Path -Path $PSScriptRoot -ChildPath "firewall_system_backup.wfw"
$csvExportPath = Join-Path -Path $PSScriptRoot -ChildPath "firewall_rules.csv"
$originBackupFile = Join-Path -Path $PSScriptRoot -ChildPath "firewall_origin_backup.wfw"

# ------------------------------
# Function: Get firewall rules from JSON
# ------------------------------
function Get-FirewallRulesFromJson {
    try {
        if (Test-Path $configFile) {
            $jsonContent = Get-Content $configFile -Raw | ConvertFrom-Json
            return $jsonContent.rules
        } else {
            Write-Host "Configuration file not found. Creating a new one..."
            $emptyJson = @{ rules = @() } | ConvertTo-Json -Depth 3
            Set-Content -Path $configFile -Value $emptyJson
            return @()
        }
    } catch {
        Write-Host "Error reading JSON file: $_"
        return @()
    }
}

# ------------------------------
# Function: Display rules from JSON
# ------------------------------
function Show-FirewallRulesFromJson {
    Write-Host "`n--- Rules in JSON file ---`n"
    $rules = Get-FirewallRulesFromJson

    if (-not $rules -or $rules.Count -eq 0) {
        Write-Host "No rules found in JSON."
        return
    }

    foreach ($rule in $rules) {
        Write-Host "--------------------------------------"
        Write-Host "Rule Name : $($rule.name)"
        Write-Host "Direction : $($rule.direction)"
        Write-Host "Action    : $($rule.action)"
        Write-Host "Protocol  : $($rule.protocol)"
        Write-Host "LocalPort : $($rule.localport)"
        Write-Host "RemotePort: $($rule.remoteport)"
        Write-Host "Profile   : $($rule.profile)"
        Write-Host "Enabled   : $($rule.enabled)"
        Write-Host "--------------------------------------"
    }
}

# ------------------------------
# Function: Add new or update existing rule
# ------------------------------
function Add-FirewallRule {
    Write-Host "`n--- Add or Update a Firewall Rule ---`n"

    $currentRules = Get-FirewallRulesFromJson
    if (-not ($currentRules -is [Array])) { $currentRules = @() }

    $ruleName = Read-Host "Enter rule name"

    do {
        $direction = Read-Host "Enter direction (in/out)"
    } until ($direction -match '^(in|out)$')

    do {
        $action = Read-Host "Enter action (allow/block)"
    } until ($action -match '^(allow|block)$')

    do {
        $protocol = Read-Host "Enter protocol (TCP/UDP)"
    } until ($protocol -match '^(TCP|UDP)$')

    do {
        $localPort = Read-Host "Enter local port (1-65535)"
    } until ($localPort -match '^\d+$' -and [int]$localPort -ge 1 -and [int]$localPort -le 65535)

    $remotePort = Read-Host "Enter remote port (leave blank for any)"
    if (-not $remotePort) { $remotePort = "any" }

    do {
        $ruleProfile = Read-Host "Enter profile (any/private/public/domain)"
    } until ($ruleProfile -match '^(any|private|public|domain)$')

    $existingRule = $currentRules | Where-Object { $_.name -eq $ruleName }

    if ($existingRule) {
        Write-Host "Updating existing rule: $ruleName"
        $currentRules = $currentRules | Where-Object { $_.name -ne $ruleName }
    }

    $newRule = @{
        name       = $ruleName
        direction  = $direction
        action     = $action
        protocol   = $protocol
        localport  = $localPort
        remoteport = $remotePort
        profile    = $ruleProfile
        enabled    = $true
    }

    try {
        netsh advfirewall firewall add rule name="$ruleName" dir=$direction action=$action protocol=$protocol localport=$localPort remoteport=$remotePort profile=$ruleProfile
        $currentRules += $newRule
        $jsonContent = @{ rules = $currentRules } | ConvertTo-Json -Depth 3
        Set-Content -Path $configFile -Value $jsonContent
        Write-Host "Rule added/updated and saved."
    } catch {
        Write-Host "Error adding rule: $_"
    }
}

# ------------------------------
# Function: Display all system firewall rules
# ------------------------------
function Show-AllFirewallRules {
    Write-Host "`n--- All firewall rules in system ---`n"
    try {
        netsh advfirewall firewall show rule name=all
    } catch {
        Write-Host "Error showing firewall rules: $_"
    }
}

# ------------------------------
# Function: Backup firewall rules to JSON
# ------------------------------
function Backup-SystemFirewallRules {
    Write-Host "`n--- Creating full system firewall backup (.wfw) ---`n"

    try {
        netsh advfirewall export "$systemBackupFile"
        Write-Host " System firewall configuration exported to: $systemBackupFile"
    } catch {
        Write-Host " Failed to export system firewall configuration: $_"
    }
}

# ------------------------------
# Function: Restore firewall rules from JSON backup
# ------------------------------

function Restore-SystemFirewallRules {
    Write-Host "`n--- Restoring full system firewall from backup (.wfw) ---`n"

    if (Test-Path $systemBackupFile) {
        try {
            netsh advfirewall import "$systemBackupFile"
            Write-Host " Firewall configuration restored from backup."
        } catch {
            Write-Host " Failed to restore firewall configuration: $_"
        }
    } else {
        Write-Host " Backup file not found: $systemBackupFile"
    }
}


# ------------------------------
# Function: Enable a specific rule
# ------------------------------
function Enable-FirewallRule {
    $ruleName = Read-Host "Enter rule name to enable"
    $rules = Get-FirewallRulesFromJson
    $rule = $rules | Where-Object { $_.name -eq $ruleName }

    if ($rule) {
        netsh advfirewall firewall set rule name="$ruleName" new enable=yes
        $rule.enabled = $true
        $json = @{ rules = $rules } | ConvertTo-Json -Depth 3
        Set-Content -Path $configFile -Value $json
        Write-Host "Rule '$ruleName' enabled."
    } else {
        Write-Host "Rule not found."
    }
}

# ------------------------------
# Function: Disable a specific rule
# ------------------------------
function Disable-FirewallRule {
    $ruleName = Read-Host "Enter rule name to disable"
    $rules = Get-FirewallRulesFromJson
    $rule = $rules | Where-Object { $_.name -eq $ruleName }

    if ($rule) {
        netsh advfirewall firewall set rule name="$ruleName" new enable=no
        $rule.enabled = $false
        $json = @{ rules = $rules } | ConvertTo-Json -Depth 3
        Set-Content -Path $configFile -Value $json
        Write-Host "Rule '$ruleName' disabled."
    } else {
        Write-Host "Rule not found."
    }
}

# ------------------------------
# Function: Edit existing rule
# ------------------------------
function Edit-FirewallRule {
    $ruleName = Read-Host "Enter rule name to edit"
    $rules = Get-FirewallRulesFromJson
    $rule = $rules | Where-Object { $_.name -eq $ruleName }

    if ($rule) {
        Write-Host "`nEditing rule: $ruleName"
        Write-Host "Press Enter to keep current values.`n"

        $direction = Read-Host "Direction (in/out) [current: $($rule.direction)]"
        $action = Read-Host "Action (allow/block) [current: $($rule.action)]"
        $protocol = Read-Host "Protocol (TCP/UDP) [current: $($rule.protocol)]"
        $localPort = Read-Host "Local Port [current: $($rule.localport)]"
        $remotePort = Read-Host "Remote Port [current: $($rule.remoteport)]"
        $ruleProfile = Read-Host "Profile (any/private/public/domain) [current: $($rule.profile)]"

        if (-not $direction)   { $direction = $rule.direction }
        if (-not $action)      { $action = $rule.action }
        if (-not $protocol)    { $protocol = $rule.protocol }
        if (-not $localPort)   { $localPort = $rule.localport }
        if (-not $remotePort)  { $remotePort = $rule.remoteport }
        if (-not $ruleProfile) { $ruleProfile = $rule.profile }

        $rule.direction  = $direction
        $rule.action     = $action
        $rule.protocol   = $protocol
        $rule.localport  = $localPort
        $rule.remoteport = $remotePort
        $rule.profile    = $ruleProfile

        try {
            netsh advfirewall firewall set rule name="$ruleName" new dir=$direction action=$action protocol=$protocol localport=$localPort remoteport=$remotePort profile=$ruleProfile
            $json = @{ rules = $rules } | ConvertTo-Json -Depth 3
            Set-Content -Path $configFile -Value $json
            Write-Host "Rule '$ruleName' updated."
        } catch {
            Write-Host "Error editing rule: $_"
        }
    } else {
        Write-Host "Rule not found."
    }
}

# ------------------------------
# Function: Remove rule
# ------------------------------
function Remove-FirewallRule {
    $ruleName = Read-Host "Enter rule name to remove"
    $rules = Get-FirewallRulesFromJson
    $rule = $rules | Where-Object { $_.name -eq $ruleName }

    if ($rule) {
        netsh advfirewall firewall delete rule name="$ruleName"
        $rules = $rules | Where-Object { $_.name -ne $ruleName }
        $json = @{ rules = $rules } | ConvertTo-Json -Depth 3
        Set-Content -Path $configFile -Value $json
        Write-Host "Rule '$ruleName' removed."
    } else {
        Write-Host "Rule not found."
    }
}

# ------------------------------
# Function: Export rules to CSV
# ------------------------------
function Export-FirewallRulesToCsv {
    $rules = Get-FirewallRulesFromJson
    if ($rules.Count -eq 0) {
        Write-Host "No rules to export."
        return
    }
    $rules | ConvertTo-Csv -NoTypeInformation | Set-Content $csvExportPath
    Write-Host "Rules exported to $csvExportPath"
}

# ------------------------------
# Function: Enable all rules from JSON if not already enabled or created
# ------------------------------

function Enable-AllFirewallRulesFromJson {
    Write-Host "`nEnabling all rules from JSON..."

    $rules = Get-FirewallRulesFromJson
    if (-not $rules -or $rules.Count -eq 0) {
        Write-Host "No rules found in JSON."
        return
    }

    foreach ($rule in $rules) {
        $ruleName = $rule.name

        # Sprawdź, czy reguła istnieje
        $existingRuleOutput = netsh advfirewall firewall show rule name="$ruleName" 2>&1

        if ($existingRuleOutput -match "No rules match the specified criteria.") {
            Write-Host "Rule '$ruleName' not found in firewall. Adding..."

            # Budowanie komendy krok po kroku
            $cmd = "netsh advfirewall firewall add rule"
            $cmd += " name=`"$($rule.name)`""
            $cmd += " dir=$($rule.direction)"
            $cmd += " action=$($rule.action)"
            $cmd += " protocol=$($rule.protocol)"

            if ($rule.localport -and $rule.localport -ne "any") {
                $cmd += " localport=$($rule.localport)"
            }

            if ($rule.remoteport -and $rule.remoteport -ne "any") {
                $cmd += " remoteport=$($rule.remoteport)"
            }

            if ($rule.profile) {
                $cmd += " profile=$($rule.profile)"
            } else {
                $cmd += " profile=any"
            }

            $cmd += " enable=yes"
            $cmd += " program=System"

            try {
                Invoke-Expression $cmd
                Write-Host "Rule '$ruleName' added."
            } catch {
                Write-Host "Failed to add rule '$ruleName': $_"
            }
        } else {
            Write-Host "Rule '$ruleName' exists. Enabling..."
            try {
                netsh advfirewall firewall set rule name="$ruleName" new enable=yes
            } catch {
                Write-Host "Failed to enable rule '$ruleName': $_"
            }
        }

        # Ustaw enabled = true w obiekcie JSON (jeśli nie istnieje)
        if (-not $rule.PSObject.Properties.Name -contains 'enabled') {
            $rule | Add-Member -NotePropertyName enabled -NotePropertyValue $true
        } else {
            $rule.enabled = $true
        }
    }

    # Zapisz zaktualizowany JSON
    try {
        $json = @{ rules = $rules } | ConvertTo-Json -Depth 3
        Set-Content -Path $configFile -Value $json
        Write-Host "`nAll rules from JSON have been processed and enabled (if needed)."
    } catch {
        Write-Host "Failed to update JSON file: $_"
    }
}

# ------------------------------
# One-time creation of origin firewall backup
# ------------------------------
function Ensure-OriginFirewallBackup {
    Write-Host "`n--- Checking for original system firewall backup ---`n"

    try {
        if (Test-Path -LiteralPath $originBackupFile) {
            Write-Host "Origin backup already exists: $originBackupFile (skipping)."
            return
        }

        # Upewnij się, że katalog docelowy istnieje
        $parent = Split-Path -Parent $originBackupFile
        if ($parent -and -not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }

        netsh advfirewall export "$originBackupFile"
        Write-Host " Origin firewall backup created at: $originBackupFile"
    } catch {
        Write-Host " Failed to create origin backup: $_"
    }
}




# ------------------------------
# MAIN MENU
# ------------------------------
function Main {
    Write-Host "`nWelcome to Interactive Firewall Manager"

    # Jednorazowy backup przy pierwszym uruchomieniu
    Ensure-OriginFirewallBackup

    while ($true) {
        Write-Host "`nSelect an option:"
        Write-Host "1. Add or update rule"
        Write-Host "2. Remove rule"
        Write-Host "3. Edit rule"
        Write-Host "4. Show rules from JSON"
        Write-Host "5. Show all system firewall rules"
        Write-Host "6. Enable rule"
        Write-Host "7. Disable rule"
        Write-Host "8. Export rules to CSV"
        Write-Host "9. Enable all rules from JSON"
        Write-Host "10. Backup full system firewall (WFW)"
        Write-Host "11. Restore full system firewall from backup"
        Write-Host "12. Exit"


        $choice = Read-Host "Enter option number"
        switch ($choice) {
            1  { Add-FirewallRule }
            2  { Remove-FirewallRule }
            3  { Edit-FirewallRule }
            4  { Show-FirewallRulesFromJson }
            5  { Show-AllFirewallRules }
            6  { Enable-FirewallRule }
            7  { Disable-FirewallRule }
            8 { Export-FirewallRulesToCsv }
            9 { Enable-AllFirewallRulesFromJson }
            10 { Backup-SystemFirewallRules }
            11 { Restore-SystemFirewallRules }
            12 { break }
            default { Write-Host "Invalid choice, try again." }
        }
    }
}

# Start application
Main
