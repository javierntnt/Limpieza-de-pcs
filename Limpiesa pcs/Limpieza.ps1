#requires -Version 5.1
<#
    Limpieza.ps1
    Orquestador del motor de limpieza y optimizacion.

    Orquesta los scripts .bat existentes como "tareas". Detecta el hardware,
    decide que ejecutar, mide antes/despues y genera un informe HTML + JSON.

    Notas:
      - Compatible con Windows PowerShell 5.1 (sin sintaxis PS7).
      - -DryRun hace todo excepto ejecutar tareas y NO requiere administrador.
      - No modifica ningun .bat existente.
#>

[CmdletBinding()]
param(
    [string[]]$Task,
    [switch]$All,
    [switch]$DryRun,
    [switch]$Force,
    [switch]$NoReport,
    [string]$ReportsPath,
    [string]$LogsPath
)

$ErrorActionPreference = 'Continue'

# ---------------------------------------------------------------------------
# Rutas (derivadas de $PSScriptRoot; nunca hardcodeadas)
# ---------------------------------------------------------------------------
$ScriptsRoot = $PSScriptRoot
$ModulePath = Join-Path $ScriptsRoot 'modules\Limpieza.Core.psm1'

Import-Module $ModulePath -Force -ErrorAction Stop

$LimpiezaVersion = '1.0.0'
try {
    $v = & (Get-Module Limpieza.Core) { $script:LimpiezaVersion }
    if (-not [string]::IsNullOrWhiteSpace([string]$v)) { $LimpiezaVersion = [string]$v }
} catch { }

if ([string]::IsNullOrWhiteSpace($ReportsPath)) { $ReportsPath = Join-Path $ScriptsRoot 'reports' }
if ([string]::IsNullOrWhiteSpace($LogsPath)) { $LogsPath = Join-Path $ScriptsRoot 'logs' }

# ---------------------------------------------------------------------------
# Helpers del orquestador
# ---------------------------------------------------------------------------
function Test-IsElevated {
    try {
        $null = & cmd /c "net session >nul 2>&1"
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Get-QuickDiskFreeGB {
    try {
        $sum = 0.0
        $drives = Get-CimInstance -ClassName Win32_LogicalDisk -ErrorAction Stop | Where-Object { $_.DriveType -eq 3 }
        foreach ($d in $drives) { if ($null -ne $d.FreeSpace) { $sum += [double]$d.FreeSpace } }
        return [Math]::Round(($sum / 1GB), 2)
    } catch { return $null }
}

function Get-QuickRunningServices {
    try { return @(Get-Service -ErrorAction Stop | Where-Object { $_.Status -eq 'Running' }).Count } catch { return $null }
}

function New-TaskResult {
    param($PlanEntry)
    return [PSCustomObject]@{
        Id               = $PlanEntry.Id
        Name             = $PlanEntry.Name
        Script           = $PlanEntry.Script
        Mode             = $PlanEntry.Mode
        Status           = 'Pendiente'
        ExitCode         = $null
        DurationSeconds  = $null
        DiskFreeDeltaGB  = $null
        Note             = ''
        OutputTail       = @()
    }
}

function Get-DiskDelta {
    param($BeforeGB, $AfterGB)
    if ($null -eq $BeforeGB -or $null -eq $AfterGB) { return $null }
    return [Math]::Round(([double]$AfterGB - [double]$BeforeGB), 2)
}

# ---------------------------------------------------------------------------
# Menu interactivo (espanol sin acentos)
# ---------------------------------------------------------------------------
function Show-LimpiezaMenu {
    [CmdletBinding()]
    param($Plan, [string]$Version)

    Clear-Host
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ('   LIMPIEZA DE PCS - MENU PRINCIPAL   (motor v' + $Version + ')') -ForegroundColor White
    Write-Host '============================================================' -ForegroundColor Cyan
    foreach ($p in $Plan) {
        $tag = ''
        if ($p.Mode -eq 'Skip') { $tag = '  [se omite por defecto]' }
        elseif ($p.Mode -eq 'Interactive') { $tag = '  [interactiva]' }
        Write-Host ('  [' + $p.Id + ']  ' + $p.Name + $tag) -ForegroundColor Gray
    }
    Write-Host ''
    Write-Host '  [T]  Ejecutar todo (tareas automaticas)' -ForegroundColor Green
    Write-Host '  [0]  Salir' -ForegroundColor Yellow
    Write-Host ''
}

# ---------------------------------------------------------------------------
# Ejecucion de una tarea
# ---------------------------------------------------------------------------
function Invoke-CapturedTask {
    param($PlanEntry, [string]$LogPath, [string]$ScriptsRoot)

    $result = New-TaskResult -PlanEntry $PlanEntry
    $scriptFull = Join-Path $ScriptsRoot $PlanEntry.Script

    if (-not (Test-Path -LiteralPath $scriptFull)) {
        $result.Status = 'Error'
        $result.Note = 'No se encontro el script: ' + $PlanEntry.Script
        Write-LimpiezaLog -Message $result.Note -Level 'ERROR' -LogPath $LogPath
        return $result
    }

    $tmpOut = [System.IO.Path]::GetTempFileName()
    $tmpErr = [System.IO.Path]::GetTempFileName()
    $diskBefore = Get-QuickDiskFreeGB
    $svcBefore = Get-QuickRunningServices

    try {
        $comspec = $env:ComSpec
        if ([string]::IsNullOrWhiteSpace($comspec)) { $comspec = 'cmd.exe' }
        $cmdArgs = '/c call "' + $scriptFull + '" /S > "' + $tmpOut + '" 2> "' + $tmpErr + '"'

        Write-LimpiezaLog -Message ('Ejecutando: ' + $PlanEntry.Script) -Level 'INFO' -LogPath $LogPath
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $proc = Start-Process -FilePath $comspec -ArgumentList $cmdArgs -NoNewWindow -Wait -PassThru
        $sw.Stop()

        $result.ExitCode = $proc.ExitCode
        $result.DurationSeconds = [Math]::Round($sw.Elapsed.TotalSeconds, 2)

        $stdout = @()
        $stderr = @()
        try { if (Test-Path -LiteralPath $tmpOut) { $stdout = @(Get-Content -LiteralPath $tmpOut -ErrorAction SilentlyContinue) } } catch { }
        try { if (Test-Path -LiteralPath $tmpErr) { $stderr = @(Get-Content -LiteralPath $tmpErr -ErrorAction SilentlyContinue) } } catch { }

        $tail = @()
        if ($stdout.Count -gt 0) { $tail += ($stdout | Select-Object -Last 15) }
        if ($stderr.Count -gt 0) { $tail += ($stderr | Select-Object -Last 15) }
        $result.OutputTail = @($tail)

        foreach ($ln in $tail) { Write-LimpiezaLog -Message ('    | ' + $ln) -Level 'INFO' -LogPath $LogPath }

        if ($proc.ExitCode -eq 0) {
            $result.Status = 'Ok'
            $result.Note = 'Completada correctamente.'
        } else {
            $result.Status = 'Error'
            $result.Note = 'Termino con codigo de salida ' + $proc.ExitCode + '.'
            Write-LimpiezaLog -Message ($PlanEntry.Script + ' -> ' + $result.Note) -Level 'ERROR' -LogPath $LogPath
        }
    } catch {
        $result.Status = 'Error'
        $result.Note = 'Excepcion al ejecutar: ' + $_.Exception.Message
        Write-LimpiezaLog -Message ($PlanEntry.Script + ' -> ' + $result.Note) -Level 'ERROR' -LogPath $LogPath
    } finally {
        try { Remove-Item -LiteralPath $tmpOut -Force -ErrorAction SilentlyContinue } catch { }
        try { Remove-Item -LiteralPath $tmpErr -Force -ErrorAction SilentlyContinue } catch { }
    }

    $diskAfter = Get-QuickDiskFreeGB
    $result.DiskFreeDeltaGB = Get-DiskDelta -BeforeGB $diskBefore -AfterGB $diskAfter
    return $result
}

function Invoke-InteractiveTask {
    param($PlanEntry, [string]$LogPath, [string]$ScriptsRoot)

    $result = New-TaskResult -PlanEntry $PlanEntry
    $scriptFull = Join-Path $ScriptsRoot $PlanEntry.Script

    if (-not (Test-Path -LiteralPath $scriptFull)) {
        $result.Status = 'Error'
        $result.Note = 'No se encontro el script: ' + $PlanEntry.Script
        Write-LimpiezaLog -Message $result.Note -Level 'ERROR' -LogPath $LogPath
        return $result
    }

    $diskBefore = Get-QuickDiskFreeGB
    try {
        Write-LimpiezaLog -Message ('Ejecutando (interactiva): ' + $PlanEntry.Script) -Level 'INFO' -LogPath $LogPath
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        & cmd /c ('call "' + $scriptFull + '" /S')
        $code = $LASTEXITCODE
        $sw.Stop()
        $result.ExitCode = $code
        $result.DurationSeconds = [Math]::Round($sw.Elapsed.TotalSeconds, 2)
        if ($code -eq 0) { $result.Status = 'Ejecutado'; $result.Note = 'Tarea interactiva finalizada.' }
        else { $result.Status = 'Error'; $result.Note = 'Tarea interactiva termino con codigo ' + $code + '.' }
    } catch {
        $result.Status = 'Error'
        $result.Note = 'Excepcion en tarea interactiva: ' + $_.Exception.Message
    }

    $diskAfter = Get-QuickDiskFreeGB
    $result.DiskFreeDeltaGB = Get-DiskDelta -BeforeGB $diskBefore -AfterGB $diskAfter
    return $result
}

# ---------------------------------------------------------------------------
# Una corrida completa del motor
# ---------------------------------------------------------------------------
function Invoke-EngineRun {
    param(
        [string[]]$SelectedIds,
        [bool]$RunAllMode,
        [bool]$DryRun,
        [bool]$Force,
        [bool]$NoReport,
        [string]$ReportsPath,
        [string]$LogsPath,
        [string]$ScriptsRoot,
        [string]$Version
    )

    try { New-Item -ItemType Directory -Path $ReportsPath -Force | Out-Null } catch { }
    try { New-Item -ItemType Directory -Path $LogsPath -Force | Out-Null } catch { }

    $logPath = Join-Path $LogsPath ('limpieza_{0:yyyyMMdd_HHmmss}.log' -f (Get-Date))

    Write-LimpiezaLog -Message ('===== Limpieza de PCs v' + $Version + ' =====') -Level 'INFO' -LogPath $logPath
    if ($DryRun) { Write-LimpiezaLog -Message 'Modo simulacion (DryRun): no se ejecutara ninguna tarea mutante.' -Level 'WARN' -LogPath $logPath }

    # 1) Hardware
    Write-LimpiezaLog -Message 'Detectando hardware...' -Level 'INFO' -LogPath $logPath
    $hw = Get-HardwareProfile
    $sType = 'Unknown'; if ($null -ne $hw.StorageType) { $sType = [string]$hw.StorageType }
    $lapTxt = 'No'; if ($hw.IsLaptop) { $lapTxt = 'Si' }
    Write-LimpiezaLog -Message ('Equipo: ' + $hw.ComputerName + ' | SO: ' + $hw.OsCaption + ' (build ' + $hw.OsBuild + ')') -Level 'INFO' -LogPath $logPath
    Write-LimpiezaLog -Message ('CPU: ' + $hw.CpuName) -Level 'INFO' -LogPath $logPath
    Write-LimpiezaLog -Message ('Almacenamiento: ' + $sType + ' | Laptop: ' + $lapTxt + ' | RAM: ' + $hw.TotalRamGB + ' GB | Disco libre: ' + $hw.DiskFreeGB + ' GB') -Level 'OK' -LogPath $logPath

    # 2) Metricas antes
    Write-LimpiezaLog -Message 'Tomando metricas ANTES...' -Level 'INFO' -LogPath $logPath
    $before = Get-SystemMetrics
    Write-LimpiezaLog -Message ('Antes: disco libre ' + $before.DiskFreeGB + ' GB | servicios ' + $before.RunningServices + ' | inicio ' + $before.StartupItems + ' | procesos ' + $before.ProcessCount) -Level 'INFO' -LogPath $logPath

    # 3) Plan
    $plan = Get-TaskPlan -HardwareProfile $hw -Force:$Force

    Write-Host ''
    Write-Host '================ PLAN DE EJECUCION ================' -ForegroundColor Cyan
    foreach ($p in $plan) {
        $color = 'Gray'
        if ($p.Mode -eq 'Run') { $color = 'Green' }
        elseif ($p.Mode -eq 'Skip') { $color = 'DarkGray' }
        elseif ($p.Mode -eq 'Interactive') { $color = 'Yellow' }
        Write-Host ('  [' + $p.Id + '] ' + $p.Name.PadRight(26) + ' ' + $p.Mode.PadRight(12) + ' ' + $p.Reason) -ForegroundColor $color
    }
    Write-Host '===================================================' -ForegroundColor Cyan
    Write-Host ''

    # 4) Seleccion y ejecucion
    $results = New-Object System.Collections.ArrayList
    $explicitSelection = (-not $RunAllMode)

    foreach ($p in $plan) {
        $isSelected = $false
        if ($RunAllMode) {
            $isSelected = $true
        } else {
            foreach ($sid in $SelectedIds) {
                if ([string]$sid -eq [string]$p.Id) { $isSelected = $true; break }
            }
        }

        if (-not $isSelected) {
            $r = New-TaskResult -PlanEntry $p
            $r.Status = 'Omitido'
            $r.Note = 'No seleccionado.'
            [void]$results.Add($r)
            continue
        }

        if ($p.Mode -eq 'Skip') {
            $r = New-TaskResult -PlanEntry $p
            $r.Status = 'Omitido'
            $r.Note = $p.Reason
            [void]$results.Add($r)
            Write-LimpiezaLog -Message ('OMITIDA ' + $p.Name + ': ' + $p.Reason) -Level 'WARN' -LogPath $logPath
            continue
        }

        if ($p.Mode -eq 'Interactive') {
            if ($explicitSelection -and -not $DryRun) {
                $r = Invoke-InteractiveTask -PlanEntry $p -LogPath $logPath -ScriptsRoot $ScriptsRoot
            } else {
                $r = New-TaskResult -PlanEntry $p
                $r.Status = 'Omitido'
                if ($DryRun) {
                    $r.Note = 'Tarea interactiva: se omite en modo simulacion (requiere humano).'
                } else {
                    $r.Note = 'Tarea interactiva: requiere decision humana; se omite en modo automatico.'
                }
            }
            [void]$results.Add($r)
            Write-LimpiezaLog -Message ('OMITIDA (interactiva) ' + $p.Name + ': ' + $r.Note) -Level 'WARN' -LogPath $logPath
            continue
        }

        # Mode = Run
        if ($DryRun) {
            $r = New-TaskResult -PlanEntry $p
            $r.Status = 'Simulado'
            $r.Note = 'Simulado (DryRun): no se ejecuto el script.'
            [void]$results.Add($r)
            Write-LimpiezaLog -Message ('SIMULADA ' + $p.Name + ': ' + $p.Script) -Level 'OK' -LogPath $logPath
            continue
        }

        $r = Invoke-CapturedTask -PlanEntry $p -LogPath $logPath -ScriptsRoot $ScriptsRoot
        [void]$results.Add($r)
    }

    # 5) Metricas despues
    Write-LimpiezaLog -Message 'Tomando metricas DESPUES...' -Level 'INFO' -LogPath $logPath
    $after = Get-SystemMetrics
    Write-LimpiezaLog -Message ('Despues: disco libre ' + $after.DiskFreeGB + ' GB | servicios ' + $after.RunningServices + ' | inicio ' + $after.StartupItems + ' | procesos ' + $after.ProcessCount) -Level 'INFO' -LogPath $logPath

    # 6) Comparacion
    $comparison = Compare-Metrics -Before $before -After $after

    # 7) Alertas
    $warnings = New-Object System.Collections.ArrayList
    if ($sType -eq 'Unknown') { [void]$warnings.Add('No se pudo determinar el tipo de almacenamiento (SSD/HDD).') }
    if ($null -eq $hw.TotalRamGB) { [void]$warnings.Add('No se pudo leer la memoria RAM total.') }
    if ($null -eq $hw.CpuName) { [void]$warnings.Add('No se pudo leer el nombre del procesador.') }
    if ($DryRun) { [void]$warnings.Add('Ejecucion en simulacion (DryRun): no se modifico el sistema.') }
    foreach ($r in $results) {
        if ($r.Status -eq 'Error') { [void]$warnings.Add('Tarea ' + $r.Id + ' (' + $r.Name + ') fallo: ' + $r.Note) }
    }
    if ([math]::Abs([double]$comparison.DiskFreeDeltaGB) -lt 0.05 -and -not $DryRun) {
        [void]$warnings.Add('No se detectaron cambios de espacio en disco respecto del inicio.')
    }

    # 8) Datos del informe
    $data = [PSCustomObject]@{
        Version      = $Version
        Timestamp    = (Get-Date)
        ComputerName = $hw.ComputerName
        DryRun       = [bool]$DryRun
        Hardware     = $hw
        Plan         = $plan
        Before       = $before
        After        = $after
        Comparison   = $comparison
        TaskResults  = @($results)
        Warnings     = @($warnings)
    }

    # 9) Escribir informes
    $htmlPath = $null
    if (-not $NoReport) {
        $safe = 'PC'
        if (-not [string]::IsNullOrWhiteSpace([string]$hw.ComputerName)) {
            $safe = ([string]$hw.ComputerName) -replace '[^A-Za-z0-9_\-]', '_'
        }
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $base = 'reporte_' + $safe + '_' + $stamp
        $htmlPath = Join-Path $ReportsPath ($base + '.html')
        $jsonPath = Join-Path $ReportsPath ($base + '.json')
        Export-HtmlReport -Path $htmlPath -Data $data
        Export-JsonReport -Path $jsonPath -Data $data
        Write-LimpiezaLog -Message ('Informe HTML: ' + $htmlPath) -Level 'OK' -LogPath $logPath
        Write-LimpiezaLog -Message ('Informe JSON: ' + $jsonPath) -Level 'OK' -LogPath $logPath
    }

    # 10) Resumen final
    Write-Host ''
    Write-Host '================ RESULTADO ================' -ForegroundColor Cyan
    Write-Host ('  ' + $comparison.Summary) -ForegroundColor Green
    Write-Host ('  ' + $comparison.DiskFreeDeltaText + ' | ' + $comparison.ServiceDeltaText + ' | ' + $comparison.StartupDeltaText) -ForegroundColor Gray
    $okCount = @($results | Where-Object { $_.Status -eq 'Ok' -or $_.Status -eq 'Ejecutado' }).Count
    $errCount = @($results | Where-Object { $_.Status -eq 'Error' }).Count
    $simCount = @($results | Where-Object { $_.Status -eq 'Simulado' }).Count
    $skipCount = @($results | Where-Object { $_.Status -eq 'Omitido' }).Count
    Write-Host ('  Tareas -> Ok: ' + $okCount + ' | Simuladas: ' + $simCount + ' | Omitidas: ' + $skipCount + ' | Error: ' + $errCount) -ForegroundColor Gray
    if ($null -ne $htmlPath) {
        Write-Host ('  Informe HTML: ' + $htmlPath) -ForegroundColor White
    }
    Write-Host ('  Log: ' + $logPath) -ForegroundColor DarkGray
    Write-Host '===========================================' -ForegroundColor Cyan
    Write-Host ''

    return 0
}

# ---------------------------------------------------------------------------
# Elevacion (solo si NO es DryRun)
# ---------------------------------------------------------------------------
if (-not $DryRun) {
    if (-not (Test-IsElevated)) {
        Write-Host 'Necesitas permisos de Administrador. Solicitando permisos...' -ForegroundColor Yellow
        $argParts = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $PSCommandPath + '"'))
        if ($Task -and $Task.Count -gt 0) { $argParts += '-Task'; $argParts += ($Task -join ',') }
        if ($All) { $argParts += '-All' }
        if ($Force) { $argParts += '-Force' }
        if ($NoReport) { $argParts += '-NoReport' }
        if (-not [string]::IsNullOrWhiteSpace($ReportsPath)) { $argParts += '-ReportsPath'; $argParts += ('"' + $ReportsPath + '"') }
        if (-not [string]::IsNullOrWhiteSpace($LogsPath)) { $argParts += '-LogsPath'; $argParts += ('"' + $LogsPath + '"') }
        $argString = $argParts -join ' '
        try {
            Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argString | Out-Null
        } catch {
            Write-Host ('No se pudo elevar: ' + $_.Exception.Message) -ForegroundColor Red
        }
        exit
    }
}

# ---------------------------------------------------------------------------
# Punto de entrada
# ---------------------------------------------------------------------------
$directRun = (($null -ne $Task) -and ($Task.Count -gt 0)) -or $All

if ($directRun) {
    $runAll = [bool]$All
    $ids = @()
    if ($Task) { $ids = @($Task) }
    Invoke-EngineRun -SelectedIds $ids -RunAllMode $runAll -DryRun ([bool]$DryRun) -Force ([bool]$Force) `
        -NoReport ([bool]$NoReport) -ReportsPath $ReportsPath -LogsPath $LogsPath -ScriptsRoot $ScriptsRoot -Version $LimpiezaVersion | Out-Null
    exit 0
}

# Menu interactivo
$planForMenu = Get-TaskPlan -HardwareProfile (Get-HardwareProfile) -Force:$Force
while ($true) {
    Show-LimpiezaMenu -Plan $planForMenu -Version $LimpiezaVersion
    $choice = Read-Host '  Opcion'

    if ($null -eq $choice) { continue }
    $choice = $choice.Trim()

    if ($choice -eq '0') { break }

    if ($choice -match '^(?i)t$') {
        Invoke-EngineRun -SelectedIds @() -RunAllMode $true -DryRun ([bool]$DryRun) -Force ([bool]$Force) `
            -NoReport ([bool]$NoReport) -ReportsPath $ReportsPath -LogsPath $LogsPath -ScriptsRoot $ScriptsRoot -Version $LimpiezaVersion | Out-Null
        Write-Host ''
        Read-Host '  Presiona ENTER para volver al menu'
        continue
    }

    if ($choice -match '^\d+$') {
        $planForMenu = Get-TaskPlan -HardwareProfile (Get-HardwareProfile) -Force:$Force
        Invoke-EngineRun -SelectedIds @([string]$choice) -RunAllMode $false -DryRun ([bool]$DryRun) -Force ([bool]$Force) `
            -NoReport ([bool]$NoReport) -ReportsPath $ReportsPath -LogsPath $LogsPath -ScriptsRoot $ScriptsRoot -Version $LimpiezaVersion | Out-Null
        Write-Host ''
        Read-Host '  Presiona ENTER para volver al menu'
        continue
    }

    Write-Host '  Opcion no valida.' -ForegroundColor Red
}

exit 0
