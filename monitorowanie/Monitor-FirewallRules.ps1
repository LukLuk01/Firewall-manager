#Requires -RunAsAdministrator


$ErrorActionPreference = 'Stop'

# ---- KATALOG SKRYPTU ----
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $ScriptDir) { $ScriptDir = (Get-Location).Path }

# ---- ŚCIEŻKA LOGU ----
$OutPath = Join-Path $ScriptDir 'firewall_changes.jsonl'
if (-not (Test-Path $OutPath)) { New-Item -ItemType File -Path $OutPath -Force | Out-Null }

# ---- INTERWAŁ (sekundy) ----
$IntervalSeconds = 5   # ustaw np. 10–15 jeśli chcesz jeszcze lżej

# ---- DZIENNIKI I EVENT ID ----
$Logs = @(
  @{ Name = 'Microsoft-Windows-Windows Firewall With Advanced Security/Firewall'; Ids = @(2004,2005,2006,2007,2033,2034,2039,2040,2041) },
  @{ Name = 'Security'; Ids = @(4946,4947,4948,4949,4950,4951,4952,4954,4955,4956,4957) }
)

# ---- OBNIŻ PRIORYTET ----
try { [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass = 'BelowNormal' } catch {}

# ---- STAN W PAMIĘCI: ostatnie RecordId per log ----
$lastIds = @{}

foreach ($log in $Logs) {
  try {
    $last = Get-WinEvent -LogName $log.Name -MaxEvents 1 -ErrorAction Stop
    $lastIds[$log.Name] = [int64]$last.RecordId
  } catch {
    $lastIds[$log.Name] = 0
  }
}

function New-RecordIdFilterXml {
  param([string]$LogName,[int64]$StartRecordId,[int[]]$EventIds)
  $ids = ($EventIds | ForEach-Object { "EventID=$_"} ) -join ' or '
  if ([string]::IsNullOrEmpty($ids)) { $ids = 'true()' }
@"
<QueryList>
  <Query Id="0" Path="$LogName">
    <Select Path="$LogName">
      *[System[(EventRecordID &gt; $StartRecordId) and ($ids)]]
    </Select>
  </Query>
</QueryList>
"@
}

Write-Host "Polling zmian zapory co $IntervalSeconds s. Log: $OutPath"

while ($true) {
  foreach ($log in $Logs) {
    $name  = $log.Name
    $ids   = $log.Ids
    $start = $lastIds[$name]

    $xml = New-RecordIdFilterXml -LogName $name -StartRecordId $start -EventIds $ids

    try {
      $events = Get-WinEvent -FilterXml $xml -ErrorAction Stop | Sort-Object RecordId

      if ($events.Count -gt 0) {
        foreach ($ev in $events) {
          $msg = $null; try { $msg = $ev.FormatDescription() } catch {}
          $sid = $null; try { $sid = $ev.UserId.Value } catch {}

          [pscustomobject]@{
            TimeCreated = $ev.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss.fffK")
            EventId     = $ev.Id
            RecordId    = $ev.RecordId
            Level       = $ev.LevelDisplayName
            Provider    = $ev.ProviderName
            LogName     = $name
            Machine     = $ev.MachineName
            UserSid     = $sid
            Message     = $msg
          } | ConvertTo-Json -Compress -Depth 6 | Add-Content -LiteralPath $OutPath

          $lastIds[$name] = [int64]$ev.RecordId
        }
      }
    } catch {
      if ($_.Exception.Message -notmatch 'No events were found') {
        [pscustomobject]@{
          TimeCreated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fffK")
          EventId     = -1
          RecordId    = $start
          Provider    = "Monitor-FirewallRules-Poll"
          LogName     = $name
          Error       = $_.Exception.Message
        } | ConvertTo-Json -Compress | Add-Content -LiteralPath $OutPath
      }
    }
  }

  Start-Sleep -Seconds $IntervalSeconds
}
