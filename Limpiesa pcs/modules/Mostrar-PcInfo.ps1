#requires -Version 5.1
<#
    Mostrar-PcInfo.ps1
    Imprime los componentes del equipo y las metricas del sistema en consola.
    Lo invoca Automatizacion.bat (subrutina :PCINFO) al iniciar y al finalizar
    el mantenimiento completo de la opcion [T].

    -Phase Before : muestra COMPONENTES + METRICAS INICIALES y guarda un
                    snapshot JSON para comparar al final.
    -Phase After  : muestra METRICAS FINALES + COMPARACION contra el snapshot.

    Reutiliza el motor Limpieza.Core.psm1 (no duplica logica).
    ASCII-only, PowerShell 5.1. Nunca lanza: ante cualquier fallo avisa y
    termina con exit 0 para no romper el flujo del menu.
#>

[CmdletBinding()]
param(
    [ValidateSet('Before', 'After')]
    [string]$Phase = 'Before',
    [string]$SnapshotPath
)

$Rule = '-' * 69

function Write-BlockHeader {
    param([string]$Text)
    Write-Host ''
    Write-Host $Rule -ForegroundColor Cyan
    Write-Host ('  ' + $Text) -ForegroundColor Cyan
    Write-Host $Rule -ForegroundColor Cyan
}

function Write-InfoRow {
    param([string]$Label, [string]$Value)
    Write-Host ('  ' + $Label.PadRight(26) + ': ' + $Value) -ForegroundColor White
}

function Format-GB {
    param($Value)
    if ($null -eq $Value) { return 'n/d' }
    try {
        return ([string]([Math]::Round([double]$Value, 1)) + ' GB')
    } catch {
        return [string]$Value
    }
}

function Show-Metrics {
    param($Metrics)
    Write-InfoRow 'Disco libre (todos)' (Format-GB $Metrics.DiskFreeGB)
    Write-InfoRow 'Disco total (todos)' (Format-GB $Metrics.DiskTotalGB)
    Write-InfoRow 'RAM libre' (Format-GB $Metrics.RamFreeGB)
    Write-InfoRow 'RAM total' (Format-GB $Metrics.RamTotalGB)
    Write-InfoRow 'Servicios activos' ([string]$Metrics.RunningServices)
    Write-InfoRow 'Elementos de inicio' ([string]$Metrics.StartupItems)
    Write-InfoRow 'Procesos' ([string]$Metrics.ProcessCount)
}

try {
    Import-Module (Join-Path $PSScriptRoot 'Limpieza.Core.psm1') -Force -ErrorAction Stop

    if ([string]::IsNullOrWhiteSpace($SnapshotPath)) {
        $SnapshotPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'logs\pc_session.json'
    }
    $snapDir = Split-Path -Path $SnapshotPath -Parent
    try {
        if (-not [string]::IsNullOrWhiteSpace($snapDir) -and -not (Test-Path -LiteralPath $snapDir)) {
            New-Item -ItemType Directory -Path $snapDir -Force -ErrorAction Stop | Out-Null
        }
    } catch { }

    if ($Phase -eq 'After') {
        $after = Get-SystemMetrics

        Write-BlockHeader 'METRICAS FINALES'
        Show-Metrics $after

        Write-BlockHeader 'COMPARACION'
        $before = $null
        $canCompare = $true
        if (-not (Test-Path -LiteralPath $SnapshotPath)) {
            $canCompare = $false
        } else {
            try {
                $raw = Get-Content -LiteralPath $SnapshotPath -Raw -ErrorAction Stop
                $before = $raw | ConvertFrom-Json -ErrorAction Stop
            } catch {
                $canCompare = $false
            }
        }

        if ($canCompare -and $null -ne $before) {
            $cmp = Compare-Metrics -Before $before -After $after
            Write-InfoRow 'Disco' ([string]$cmp.DiskFreeDeltaText)
            Write-InfoRow 'Servicios' ([string]$cmp.ServiceDeltaText)
            Write-InfoRow 'Inicio' ([string]$cmp.StartupDeltaText)
            Write-Host ''
            Write-Host ('  ' + [string]$cmp.Summary) -ForegroundColor Green
        } else {
            Write-Host '  Comparacion no disponible: falta el snapshot inicial.' -ForegroundColor Yellow
        }

        try { Remove-Item -LiteralPath $SnapshotPath -Force -ErrorAction SilentlyContinue } catch { }
    } else {
        $hardware = Get-HardwareProfile

        Write-BlockHeader 'COMPONENTES DEL EQUIPO'
        Write-InfoRow 'Equipo' ([string]$hardware.ComputerName)
        $osText = [string]$hardware.OsCaption
        if (-not [string]::IsNullOrWhiteSpace([string]$hardware.OsBuild)) {
            $osText = $osText + ' (build ' + [string]$hardware.OsBuild + ')'
        }
        Write-InfoRow 'Sistema operativo' $osText
        Write-InfoRow 'Procesador' ([string]$hardware.CpuName)
        Write-InfoRow 'Almacenamiento' ([string]$hardware.StorageType)
        Write-InfoRow 'Unidad del sistema' ([string]$hardware.SystemDrive)
        Write-InfoRow 'Disco total (sistema)' (Format-GB $hardware.DiskTotalGB)
        Write-InfoRow 'Disco libre (sistema)' (Format-GB $hardware.DiskFreeGB)
        $isLaptopText = 'No'
        if ($hardware.IsLaptop) { $isLaptopText = 'Si' }
        Write-InfoRow 'Es laptop' $isLaptopText
        Write-InfoRow 'RAM total' (Format-GB $hardware.TotalRamGB)
        $trimText = 'No aplica (unidad no SSD)'
        if ([string]$hardware.StorageType -eq 'SSD') { $trimText = 'Compatible (unidad SSD)' }
        Write-InfoRow 'Optimizacion TRIM' $trimText

        $before = Get-SystemMetrics
        Write-BlockHeader 'METRICAS INICIALES'
        Show-Metrics $before

        $json = $before | ConvertTo-Json -Depth 5
        try {
            [System.IO.File]::WriteAllText($SnapshotPath, $json, (New-Object System.Text.UTF8Encoding($false)))
        } catch { }
    }

    Write-Host ''
    exit 0
} catch {
    Write-Host ('  Aviso: no se pudo mostrar la info del equipo (' + $_.Exception.Message + ').') -ForegroundColor Yellow
    exit 0
}
