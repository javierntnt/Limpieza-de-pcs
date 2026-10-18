#requires -Version 5.1
<#
    Limpieza.Core.psm1
    Motor de logica del proyecto "Limpieza de PCs".

    Regla de diseno: toda la logica de decision/clasificacion/formato son
    funciones PURAS (reciben valores, devuelven valores, sin efectos
    secundarios ni estado global). Solo las funciones "colector"
    (Get-HardwareProfile, Get-SystemMetrics) tocan el sistema.

    Identificadores en ingles. Comentarios y textos visibles en espanol
    sin acentos (limitacion de PowerShell 5.1 sin BOM).
#>

$script:LimpiezaVersion = '1.0.0'

# ===========================================================================
# Helpers internos (no exportados)
# ===========================================================================

function ConvertTo-HtmlText {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    $t = $Text.ToString()
    $t = $t -replace '&', '&amp;'
    $t = $t -replace '<', '&lt;'
    $t = $t -replace '>', '&gt;'
    return $t
}

function Format-InvariantNumber {
    param(
        [double]$Value,
        [int]$Decimals = 2
    )
    $fmt = '{0:0.' + ('0' * $Decimals) + '}'
    return [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, $fmt, $Value)
}

function Get-FreeBytesFromFsutil {
    param([string]$DriveLetter)
    try {
        if ([string]::IsNullOrWhiteSpace($DriveLetter)) { return -1 }
        $out = & fsutil volume diskfree $DriveLetter 2>$null
        if ($null -eq $out) { return -1 }
        foreach ($line in $out) {
            $s = $line.ToString()
            $m = [regex]::Match($s, '(?i)Total free bytes\s*:\s*(\d+)')
            if ($m.Success) { return [double]$m.Groups[1].Value }
            $m2 = [regex]::Match($s, '(?i)\bfree bytes\b\s*:\s*(\d+)')
            if ($m2.Success) { return [double]$m2.Groups[1].Value }
        }
    } catch { }
    return -1
}

function Get-StartupItemCount {
    $count = 0
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
    )
    foreach ($k in $keys) {
        try {
            if (Test-Path -LiteralPath $k) {
                $props = Get-ItemProperty -LiteralPath $k -ErrorAction Stop
                if ($null -ne $props) {
                    $names = @($props.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' })
                    $count += $names.Count
                }
            }
        } catch { }
    }
    $folders = @()
    try { $folders += [Environment]::GetFolderPath('Startup') } catch { }
    try { if ($env:ProgramData) { $folders += (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\StartUp') } } catch { }
    foreach ($f in $folders) {
        try {
            if (-not [string]::IsNullOrWhiteSpace($f) -and (Test-Path -LiteralPath $f)) {
                $count += @(Get-ChildItem -LiteralPath $f -File -ErrorAction SilentlyContinue).Count
            }
        } catch { }
    }
    return $count
}

function New-PlanEntry {
    param(
        [int]$Id,
        [string]$Name,
        [string]$Script,
        [string]$Mode,
        [string]$Reason,
        [bool]$Interactive = $false,
        [bool]$SkipHibernation = $false,
        [bool]$UseTrim = $false
    )
    return [PSCustomObject]@{
        Id               = $Id
        Name             = $Name
        Script           = $Script
        Mode             = $Mode
        Reason           = $Reason
        Interactive      = $Interactive
        SkipHibernation  = $SkipHibernation
        UseTrim          = $UseTrim
    }
}

# ===========================================================================
# Hardware (puro + colector)
# ===========================================================================

function Resolve-StorageType {
    <#
        PURE. Clasifica el tipo de almacenamiento como SSD / HDD / Unknown.
    #>
    [CmdletBinding()]
    param(
        [string]$MediaType,
        [bool]$TrimEnabled,
        [bool]$IsRemovable
    )

    if ($IsRemovable) { return 'Unknown' }

    $raw = ''
    if ($null -ne $MediaType) { $raw = $MediaType.ToString().Trim() }
    $lower = $raw.ToLowerInvariant()

    if ($lower -eq '4' -or $lower -eq 'ssd' -or $lower -eq 'solid state drive') { return 'SSD' }
    if ($lower -eq '3' -or $lower -eq 'hdd' -or $lower -eq 'hard disk drive') { return 'HDD' }

    if ($lower -eq '' -or $lower -eq '0' -or $lower -eq 'unspecified') {
        if ($TrimEnabled) { return 'SSD' }
        return 'Unknown'
    }

    return 'Unknown'
}

function Resolve-IsLaptop {
    <#
        PURE. Determina si el equipo es una notebook/laptop.
    #>
    [CmdletBinding()]
    param(
        [int[]]$ChassisTypes,
        [bool]$HasBattery
    )

    $portable = @(8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32)
    $desktopish = @(3, 4, 5, 6, 7, 15, 16, 17, 23, 24)

    if ($null -ne $ChassisTypes -and $ChassisTypes.Count -gt 0) {
        foreach ($c in $ChassisTypes) {
            if ($portable -contains [int]$c) { return $true }
        }
        foreach ($c in $ChassisTypes) {
            if ($desktopish -contains [int]$c) {
                if ($HasBattery) { return $true }
                return $false
            }
        }
        return $HasBattery
    }

    return $HasBattery
}

function Get-HardwareProfile {
    <#
        Colector. Nunca lanza: ante cualquier fallo devuelve 'Unknown'/$null
        en el campo correspondiente y continua.
    #>
    [CmdletBinding()]
    param()

    $result = [PSCustomObject]@{
        ComputerName = $null
        OsCaption    = $null
        OsBuild      = $null
        CpuName      = $null
        TotalRamGB   = $null
        IsLaptop     = $false
        StorageType  = 'Unknown'
        SystemDrive  = $null
        DiskTotalGB  = $null
        DiskFreeGB   = $null
    }

    try { $result.ComputerName = $env:COMPUTERNAME } catch { }

    $os = $null
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        if ($null -ne $os) {
            $result.OsCaption = $os.Caption
            if ($null -ne $os.BuildNumber) { $result.OsBuild = [string]$os.BuildNumber }
            if ($null -ne $os.TotalVisibleMemorySize) {
                $result.TotalRamGB = [Math]::Round(([double]$os.TotalVisibleMemorySize / 1MB), 1)
            }
        }
    } catch { }

    try {
        $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
        if ($null -ne $cpu) { $result.CpuName = $cpu.Name }
    } catch { }

    # Chasis + bateria
    $chassis = @()
    $hasBattery = $false
    try {
        $enclosures = Get-CimInstance -ClassName Win32_SystemEnclosure -ErrorAction Stop
        foreach ($e in $enclosures) {
            if ($null -ne $e.ChassisTypes) {
                foreach ($ct in $e.ChassisTypes) { $chassis += [int]$ct }
            }
        }
    } catch { }
    try {
        $bat = Get-CimInstance -ClassName Win32_Battery -ErrorAction Stop
        if ($null -ne $bat) { $hasBattery = (@($bat).Count -gt 0) }
    } catch { }
    try { $result.IsLaptop = Resolve-IsLaptop -ChassisTypes $chassis -HasBattery $hasBattery } catch { $result.IsLaptop = $false }

    # Unidad del sistema
    try {
        if (-not [string]::IsNullOrWhiteSpace($env:SystemDrive)) {
            $result.SystemDrive = $env:SystemDrive
        }
    } catch { }
    if ([string]::IsNullOrWhiteSpace($result.SystemDrive)) { $result.SystemDrive = 'C:' }

    # TRIM
    $trim = $false
    try {
        $fsu = & fsutil behavior query DisableDeleteNotify 2>$null
        foreach ($l in $fsu) {
            $m = [regex]::Match($l.ToString(), '=\s*(\d+)')
            if ($m.Success) {
                if ([int]$m.Groups[1].Value -eq 0) { $trim = $true }
                break
            }
        }
    } catch { }

    # Disco fisico que respalda la unidad del sistema
    $pd = $null
    $sysLetter = $result.SystemDrive.TrimEnd(':')
    try {
        $diskNumber = $null
        try {
            $part = Get-Partition -DriveLetter $sysLetter -ErrorAction Stop | Select-Object -First 1
            if ($null -ne $part) { $diskNumber = $part.DiskNumber }
        } catch { }
        if ($null -ne $diskNumber) {
            try {
                $pd = Get-PhysicalDisk -ErrorAction Stop | Where-Object { [string]$_.DeviceId -eq [string]$diskNumber } | Select-Object -First 1
            } catch { }
        }
        if ($null -eq $pd) {
            try { $pd = Get-PhysicalDisk -ErrorAction Stop | Where-Object { $_.BusType -ne 'USB' } | Select-Object -First 1 } catch { }
        }
        if ($null -eq $pd) {
            try { $pd = Get-PhysicalDisk -ErrorAction Stop | Select-Object -First 1 } catch { }
        }
    } catch { }

    $mediaTypeStr = ''
    $isRemovable = $false
    if ($null -ne $pd) {
        try { if ($null -ne $pd.MediaType) { $mediaTypeStr = $pd.MediaType.ToString() } } catch { }
        try { if ([string]$pd.BusType -eq 'USB') { $isRemovable = $true } } catch { }
        try { if ($null -ne $pd.Size) { $result.DiskTotalGB = [Math]::Round(([double]$pd.Size / 1GB), 1) } } catch { }
    }
    try {
        $result.StorageType = Resolve-StorageType -MediaType $mediaTypeStr -TrimEnabled $trim -IsRemovable $isRemovable
    } catch { $result.StorageType = 'Unknown' }

    # Espacio libre de la unidad del sistema
    try {
        $vol = Get-CimInstance -ClassName Win32_LogicalDisk -Filter ("DeviceID='{0}'" -f $result.SystemDrive) -ErrorAction Stop
        if ($null -ne $vol) {
            if ($null -ne $vol.FreeSpace) { $result.DiskFreeGB = [Math]::Round(([double]$vol.FreeSpace / 1GB), 1) }
            if ($null -eq $result.DiskTotalGB -and $null -ne $vol.Size) {
                $result.DiskTotalGB = [Math]::Round(([double]$vol.Size / 1GB), 1)
            }
        }
    } catch { }

    return $result
}

# ===========================================================================
# Metricas
# ===========================================================================

function Get-SystemMetrics {
    <#
        Colector. Nunca lanza; datos faltantes = 0 o $null.
    #>
    [CmdletBinding()]
    param()

    $result = [PSCustomObject]@{
        Timestamp       = (Get-Date)
        DiskFreeGB      = 0.0
        DiskTotalGB     = 0.0
        PerDrive        = @()
        RamFreeGB       = $null
        RamTotalGB      = $null
        RunningServices = 0
        AutoServices    = 0
        StartupItems    = 0
        ProcessCount    = 0
    }

    # ---- Discos fijos (DriveType 3) ----
    $perDrive = @()
    $freeBytes = 0.0
    $totalBytes = 0.0
    try {
        $logical = Get-CimInstance -ClassName Win32_LogicalDisk -ErrorAction Stop | Where-Object { $_.DriveType -eq 3 }
        foreach ($d in $logical) {
            if ($null -eq $d) { continue }
            $letter = [string]$d.DeviceID
            $dFree = 0.0
            $dTotal = 0.0
            if ($null -ne $d.Size) { $dTotal = [double]$d.Size }
            if ($null -ne $d.FreeSpace) { $dFree = [double]$d.FreeSpace }
            $fsuFree = Get-FreeBytesFromFsutil -DriveLetter $letter
            if ($fsuFree -ge 0) { $dFree = $fsuFree }
            $freeBytes += $dFree
            $totalBytes += $dTotal
            $perDrive += [PSCustomObject]@{
                Drive   = $letter
                TotalGB = [Math]::Round(($dTotal / 1GB), 2)
                FreeGB  = [Math]::Round(($dFree / 1GB), 2)
            }
        }
    } catch { }
    $result.PerDrive = @($perDrive)
    $result.DiskFreeGB = [Math]::Round(($freeBytes / 1GB), 2)
    $result.DiskTotalGB = [Math]::Round(($totalBytes / 1GB), 2)

    # ---- RAM ----
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        if ($null -ne $os) {
            if ($null -ne $os.FreePhysicalMemory) { $result.RamFreeGB = [Math]::Round(([double]$os.FreePhysicalMemory / 1MB), 2) }
            if ($null -ne $os.TotalVisibleMemorySize) { $result.RamTotalGB = [Math]::Round(([double]$os.TotalVisibleMemorySize / 1MB), 2) }
        }
    } catch { }

    # ---- Servicios ----
    try {
        $svc = @(Get-Service -ErrorAction Stop)
        $result.RunningServices = @($svc | Where-Object { $_.Status -eq 'Running' }).Count
        $result.AutoServices = @($svc | Where-Object { $_.StartupType -eq 'Automatic' }).Count
    } catch { }

    # ---- Procesos ----
    try { $result.ProcessCount = @(Get-Process -ErrorAction Stop).Count } catch { }

    # ---- Inicio ----
    try { $result.StartupItems = Get-StartupItemCount } catch { }

    return $result
}

function Format-SizeDelta {
    <#
        PURE. Devuelve un texto en espanol con el delta de disco (1 decimal).
    #>
    [CmdletBinding()]
    param(
        [double]$BeforeGB,
        [double]$AfterGB
    )

    $delta = $AfterGB - $BeforeGB
    if ([Math]::Abs($delta) -lt 0.05) { return 'Sin cambios en el disco' }

    if ($delta -gt 0) {
        $v = [Math]::Round($delta, 1, [System.MidpointRounding]::AwayFromZero)
        return ((Format-InvariantNumber $v 1) + ' GB liberados')
    }

    $v = [Math]::Round([Math]::Abs($delta), 1, [System.MidpointRounding]::AwayFromZero)
    return ((Format-InvariantNumber $v 1) + ' GB mas ocupado')
}

function Compare-Metrics {
    <#
        PURE. Compara dos objetos de metricas y devuelve los deltas.
    #>
    [CmdletBinding()]
    param(
        $Before,
        $After
    )

    $bDisk = 0.0; $aDisk = 0.0
    $bSvc = 0; $aSvc = 0
    $bSt = 0; $aSt = 0
    $bRam = 0.0; $aRam = 0.0

    if ($null -ne $Before) {
        if ($null -ne $Before.DiskFreeGB) { $bDisk = [double]$Before.DiskFreeGB }
        if ($null -ne $Before.RunningServices) { $bSvc = [int]$Before.RunningServices }
        if ($null -ne $Before.StartupItems) { $bSt = [int]$Before.StartupItems }
        if ($null -ne $Before.RamFreeGB) { $bRam = [double]$Before.RamFreeGB }
    }
    if ($null -ne $After) {
        if ($null -ne $After.DiskFreeGB) { $aDisk = [double]$After.DiskFreeGB }
        if ($null -ne $After.RunningServices) { $aSvc = [int]$After.RunningServices }
        if ($null -ne $After.StartupItems) { $aSt = [int]$After.StartupItems }
        if ($null -ne $After.RamFreeGB) { $aRam = [double]$After.RamFreeGB }
    }

    $diskDelta = [Math]::Round(($aDisk - $bDisk), 2)
    $svcDelta = $aSvc - $bSvc
    $stDelta = $aSt - $bSt
    $ramDelta = [Math]::Round(($aRam - $bRam), 2)

    $diskText = Format-SizeDelta -BeforeGB $bDisk -AfterGB $aDisk

    if ($svcDelta -lt 0) { $svcText = ([Math]::Abs($svcDelta).ToString()) + ' servicios menos' }
    elseif ($svcDelta -gt 0) { $svcText = ($svcDelta.ToString()) + ' servicios mas' }
    else { $svcText = 'sin cambios en servicios' }

    if ($stDelta -lt 0) { $stText = ([Math]::Abs($stDelta).ToString()) + ' elementos de inicio menos' }
    elseif ($stDelta -gt 0) { $stText = ($stDelta.ToString()) + ' elementos de inicio mas' }
    else { $stText = 'sin cambios en elementos de inicio' }

    $diskPart = 'Sin cambios de disco'
    if ($diskDelta -ge 0.05) { $diskPart = 'Libere ' + (Format-InvariantNumber $diskDelta 1) + ' GB de disco' }
    elseif ($diskDelta -le -0.05) { $diskPart = 'Se ocuparon ' + (Format-InvariantNumber ([Math]::Abs($diskDelta)) 1) + ' GB de disco' }

    $svcPart = 'sin cambios en servicios'
    if ($svcDelta -lt 0) { $svcPart = 'quedaron ' + ([Math]::Abs($svcDelta).ToString()) + ' servicios menos' }
    elseif ($svcDelta -gt 0) { $svcPart = 'quedaron ' + ($svcDelta.ToString()) + ' servicios mas' }

    $summary = $diskPart + ' y ' + $svcPart + '.'

    return [PSCustomObject]@{
        DiskFreeDeltaGB   = $diskDelta
        DiskFreeDeltaText = $diskText
        ServiceDeltaText  = $svcText
        StartupDeltaText  = $stText
        RamFreeDeltaGB    = $ramDelta
        Summary           = $summary
    }
}

# ===========================================================================
# Plan de tareas (decision pura basada en hardware)
# ===========================================================================

function Get-TaskPlan {
    <#
        PURE. Construye el plan de tareas. No decide automatico vs manual:
        solo marca las interactivas como 'Interactive'.
    #>
    [CmdletBinding()]
    param(
        $HardwareProfile,
        [switch]$Force
    )

    $isLaptop = $false
    $storage = 'Unknown'
    if ($null -ne $HardwareProfile) {
        if ($null -ne $HardwareProfile.IsLaptop) { $isLaptop = [bool]$HardwareProfile.IsLaptop }
        if ($null -ne $HardwareProfile.StorageType -and -not [string]::IsNullOrWhiteSpace([string]$HardwareProfile.StorageType)) {
            $storage = [string]$HardwareProfile.StorageType
        }
    }

    $useTrim = ($storage -eq 'SSD')
    $hdd = ($storage -eq 'HDD')

    # Razones de la tarea 10 (Optimizacion Avanzada)
    if ($useTrim) {
        $trimReason = 'Disco SSD detectado: se usara TRIM (Optimize-Volume -ReTrim) y NO se desfragmentara.'
    } elseif ($hdd) {
        $trimReason = 'Disco HDD detectado: se permite la desfragmentacion tradicional.'
    } else {
        $trimReason = 'Tipo de disco desconocido: se opta por la opcion segura (sin desfragmentar).'
    }
    if ($isLaptop) {
        $hibReason = ' Hibernacion solo informativa: es una notebook/laptop, no se recomienda desactivarla.'
    } else {
        $hibReason = ' En un equipo de escritorio se puede desactivar la hibernacion para liberar espacio.'
    }

    $defaultReason = 'Tarea incluida en el mantenimiento automatico.'
    $interactiveReason = 'Requiere intervencion humana: se ejecuta de forma interactiva, no automatica.'

    $plan = New-Object System.Collections.ArrayList

    [void]$plan.Add((New-PlanEntry -Id 1 -Name 'Punto de Restauracion' -Script 'restaurar_punto.bat' -Mode 'Run' -Reason $defaultReason))
    [void]$plan.Add((New-PlanEntry -Id 2 -Name 'Archivos Temporales' -Script 'Temp.bat' -Mode 'Run' -Reason $defaultReason))
    [void]$plan.Add((New-PlanEntry -Id 3 -Name 'Cache de Windows Update' -Script 'windows_update.bat' -Mode 'Run' -Reason $defaultReason))
    [void]$plan.Add((New-PlanEntry -Id 4 -Name 'Liberador de Espacio' -Script 'Cache.bat' -Mode 'Run' -Reason $defaultReason))
    [void]$plan.Add((New-PlanEntry -Id 5 -Name 'Visor de Eventos' -Script 'limpiar_visor_eventos.bat' -Mode 'Run' -Reason $defaultReason))
    [void]$plan.Add((New-PlanEntry -Id 6 -Name 'Servicios y Privacidad' -Script 'Limpieza_Servicios.bat' -Mode 'Run' -Reason $defaultReason))

    # Tarea 7: Prefetch (siempre Skip salvo -Force)
    if ($Force) {
        [void]$plan.Add((New-PlanEntry -Id 7 -Name 'Prefetch' -Script 'Limpieza_sesion.bat' -Mode 'Run' -Reason 'Forzado: se limpiara Prefetch aunque puede ralentizar el arranque de las aplicaciones.'))
    } else {
        [void]$plan.Add((New-PlanEntry -Id 7 -Name 'Prefetch' -Script 'Limpieza_sesion.bat' -Mode 'Skip' -Reason 'Se omite la limpieza de Prefetch porque puede ralentizar el arranque de las aplicaciones.'))
    }

    # Tareas interactivas
    [void]$plan.Add((New-PlanEntry -Id 8 -Name 'Inicio y Rendimiento' -Script 'desactivar_inicio.bat' -Mode 'Interactive' -Reason $interactiveReason -Interactive $true))
    [void]$plan.Add((New-PlanEntry -Id 9 -Name 'Planes de Energia' -Script 'planes_energia.bat' -Mode 'Interactive' -Reason $interactiveReason -Interactive $true))

    # Tarea 10: Optimizacion Avanzada (siempre Run; hibernacion + TRIM)
    [void]$plan.Add((New-PlanEntry -Id 10 -Name 'Optimizacion Avanzada' -Script 'optimizar_rendimiento.bat' -Mode 'Run' -Reason ($trimReason + $hibReason) -SkipHibernation $isLaptop -UseTrim $useTrim))

    [void]$plan.Add((New-PlanEntry -Id 11 -Name 'Activar WSearch' -Script 'activar_wsearch.bat' -Mode 'Run' -Reason $defaultReason))
    [void]$plan.Add((New-PlanEntry -Id 12 -Name 'SFC y Winget' -Script 'verificar_sistema.bat' -Mode 'Run' -Reason $defaultReason))
    [void]$plan.Add((New-PlanEntry -Id 13 -Name 'WinUtil (Chris Titus)' -Script 'chris_titus.bat' -Mode 'Run' -Reason $defaultReason))

    # Tarea 14: MAS (Skip salvo -Force)
    if ($Force) {
        [void]$plan.Add((New-PlanEntry -Id 14 -Name 'Activar Windows (MAS)' -Script 'activar_windows.bat' -Mode 'Run' -Reason 'Forzado: se ejecutara la activacion MAS (metodo no oficial de Windows).'))
    } else {
        [void]$plan.Add((New-PlanEntry -Id 14 -Name 'Activar Windows (MAS)' -Script 'activar_windows.bat' -Mode 'Skip' -Reason 'Excluida de la ejecucion automatica: la activacion con MAS es un metodo no oficial de Windows.'))
    }

    return @($plan)
}

# ===========================================================================
# Reportes
# ===========================================================================

function Export-JsonReport {
    [CmdletBinding()]
    param(
        [string]$Path,
        $Data
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    try {
        $dir = Split-Path -Path $Path -Parent
        if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        $json = $Data | ConvertTo-Json -Depth 8
        [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
    } catch { }
}

function Export-HtmlReport {
    <#
        Escribe un informe HTML5 autocontenido (CSS embebido, sin recursos
        externos). Acentos via entidades HTML.
    #>
    [CmdletBinding()]
    param(
        [string]$Path,
        $Data
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return }

    $hw = $null
    $cmp = $null
    $plan = @()
    $results = @()
    $warnings = @()
    $before = $null
    $after = $null
    $version = '1.0.0'
    $dryRun = $false
    if ($null -ne $Data) {
        if ($null -ne $Data.Hardware) { $hw = $Data.Hardware }
        if ($null -ne $Data.Comparison) { $cmp = $Data.Comparison }
        if ($null -ne $Data.Plan) { $plan = @($Data.Plan) }
        if ($null -ne $Data.TaskResults) { $results = @($Data.TaskResults) }
        if ($null -ne $Data.Warnings) { $warnings = @($Data.Warnings) }
        if ($null -ne $Data.Before) { $before = $Data.Before }
        if ($null -ne $Data.After) { $after = $Data.After }
        if ($null -ne $Data.Version) { $version = [string]$Data.Version }
        if ($null -ne $Data.DryRun) { $dryRun = [bool]$Data.DryRun }
    }

    $pcName = 'Desconocido'
    if ($null -ne $hw -and -not [string]::IsNullOrWhiteSpace([string]$hw.ComputerName)) { $pcName = [string]$hw.ComputerName }
    $tsText = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    if ($null -ne $Data -and $null -ne $Data.Timestamp) {
        try { $tsText = ([DateTime]$Data.Timestamp).ToString('yyyy-MM-dd HH:mm:ss') } catch { }
    }

    $css = @'
body{font-family:Segoe UI,Arial,sans-serif;background:#f4f6f9;color:#1f2933;margin:0;padding:0}
.wrap{max-width:1000px;margin:0 auto;padding:24px}
header{background:#0f4c81;color:#fff;padding:24px;border-radius:10px}
header h1{margin:0;font-size:22px}
header .sub{opacity:.9;margin-top:6px;font-size:13px}
h2{font-size:16px;margin:28px 0 8px;border-bottom:2px solid #d7dee8;padding-bottom:4px}
table{width:100%;border-collapse:collapse;background:#fff;border-radius:8px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,.08)}
th,td{padding:8px 10px;text-align:left;border-bottom:1px solid #eef2f7;font-size:13px;vertical-align:top}
th{background:#e8eef6;font-weight:600}
.badge{display:inline-block;padding:2px 8px;border-radius:10px;font-size:11px;font-weight:700;color:#fff;white-space:nowrap}
.badge.run{background:#1f9d55}
.badge.skip{background:#8a94a6}
.badge.inter{background:#d97706}
.badge.err{background:#c0392b}
.badge.sim{background:#2b6cb0}
.summary{background:#e6f6ec;border-left:5px solid #1f9d55;padding:14px 16px;border-radius:8px;font-size:15px;font-weight:600;margin:10px 0}
.warn{background:#fff4e5;border-left:5px solid #d97706;padding:10px 12px;border-radius:6px;margin:6px 0;font-size:13px}
.pos{color:#1f9d55;font-weight:600}
.neg{color:#c0392b;font-weight:600}
.muted{color:#6b7280}
.footer{color:#6b7280;font-size:11px;margin-top:24px;text-align:center}
'@

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<!DOCTYPE html>')
    [void]$sb.AppendLine('<html lang="es">')
    [void]$sb.AppendLine('<head>')
    [void]$sb.AppendLine('<meta charset="utf-8">')
    [void]$sb.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1">')
    [void]$sb.AppendLine('<title>Reporte de Limpieza - ' + (ConvertTo-HtmlText $pcName) + '</title>')
    [void]$sb.AppendLine('<style>')
    [void]$sb.AppendLine($css)
    [void]$sb.AppendLine('</style>')
    [void]$sb.AppendLine('</head>')
    [void]$sb.AppendLine('<body>')
    [void]$sb.AppendLine('<div class="wrap">')

    # Cabecera
    [void]$sb.AppendLine('<header>')
    [void]$sb.AppendLine('<h1>Reporte de Limpieza y Optimizaci&oacute;n</h1>')
    [void]$sb.AppendLine('<div class="sub">Equipo: <strong>' + (ConvertTo-HtmlText $pcName) + '</strong> &nbsp;|&nbsp; Fecha: ' + (ConvertTo-HtmlText $tsText) + '</div>')
    $modeText = 'Ejecuci&oacute;n real'
    if ($dryRun) { $modeText = 'Modo simulaci&oacute;n (DryRun)' }
    [void]$sb.AppendLine('<div class="sub">Modo: ' + $modeText + ' &nbsp;|&nbsp; Motor v' + (ConvertTo-HtmlText $version) + '</div>')
    [void]$sb.AppendLine('</header>')

    # Equipo
    [void]$sb.AppendLine('<h2>Equipo</h2>')
    [void]$sb.AppendLine('<table>')
    $rows = New-Object System.Collections.ArrayList
    function AddRow { param($k, $v) [void]$rows.Add('<tr><th style="width:220px">' + $k + '</th><td>' + (ConvertTo-HtmlText $v) + '</td></tr>') }
    $sType = 'Unknown'; $isLap = 'No'; $ram = 'n/d'; $dTot = 'n/d'; $dFree = 'n/d'
    if ($null -ne $hw) {
        if ($null -ne $hw.StorageType) { $sType = [string]$hw.StorageType }
        if ($hw.IsLaptop) { $isLap = 'Si' }
        if ($null -ne $hw.TotalRamGB) { $ram = (Format-InvariantNumber ([double]$hw.TotalRamGB) 1) + ' GB' }
        if ($null -ne $hw.DiskTotalGB) { $dTot = (Format-InvariantNumber ([double]$hw.DiskTotalGB) 1) + ' GB' }
        if ($null -ne $hw.DiskFreeGB) { $dFree = (Format-InvariantNumber ([double]$hw.DiskFreeGB) 1) + ' GB' }
    }
    AddRow 'Nombre del equipo' $pcName
    AddRow 'Sistema operativo' $(if ($null -ne $hw) { $hw.OsCaption } else { $null })
    AddRow 'Compilacion (build)' $(if ($null -ne $hw) { $hw.OsBuild } else { $null })
    AddRow 'Procesador' $(if ($null -ne $hw) { $hw.CpuName } else { $null })
    AddRow 'Memoria RAM total' $ram
    AddRow 'Es laptop/notebook' $isLap
    AddRow 'Tipo de almacenamiento' $sType
    AddRow 'Unidad del sistema' $(if ($null -ne $hw) { $hw.SystemDrive } else { $null })
    AddRow 'Disco total' $dTot
    AddRow 'Disco libre' $dFree
    foreach ($r in $rows) { [void]$sb.AppendLine($r) }
    [void]$sb.AppendLine('</table>')

    # Decisiones automaticas
    [void]$sb.AppendLine('<h2>Decisiones autom&aacute;ticas</h2>')
    [void]$sb.AppendLine('<table>')
    [void]$sb.AppendLine('<tr><th style="width:40px">#</th><th style="width:200px">Tarea</th><th style="width:110px">Decision</th><th>Motivo</th></tr>')
    foreach ($p in $plan) {
        $mode = 'Run'; if ($null -ne $p.Mode) { $mode = [string]$p.Mode }
        $cls = 'run'; $label = 'Ejecutar'
        if ($mode -eq 'Skip') { $cls = 'skip'; $label = 'Omitir' }
        elseif ($mode -eq 'Interactive') { $cls = 'inter'; $label = 'Interactiva' }
        $extra = ''
        if ($p.UseTrim -eq $true) { $extra += ' <span class="muted">[TRIM]</span>' }
        if ($p.SkipHibernation -eq $true) { $extra += ' <span class="muted">[sin hibernacion]</span>' }
        [void]$sb.AppendLine('<tr><td>' + (ConvertTo-HtmlText $p.Id) + '</td><td>' + (ConvertTo-HtmlText $p.Name) + $extra + '</td><td><span class="badge ' + $cls + '">' + $label + '</span></td><td>' + (ConvertTo-HtmlText $p.Reason) + '</td></tr>')
    }
    [void]$sb.AppendLine('</table>')

    # Antes y despues
    [void]$sb.AppendLine('<h2>Antes y despu&eacute;s</h2>')
    $summaryText = 'Sin datos de comparacion.'
    if ($null -ne $cmp -and $null -ne $cmp.Summary) { $summaryText = [string]$cmp.Summary }
    [void]$sb.AppendLine('<div class="summary">' + (ConvertTo-HtmlText $summaryText) + '</div>')
    [void]$sb.AppendLine('<table>')
    [void]$sb.AppendLine('<tr><th>Metrica</th><th>Antes</th><th>Despu&eacute;s</th><th>Diferencia</th></tr>')
    $bDiskFree = ''; $aDiskFree = ''
    $bSvc = ''; $aSvc = ''
    $bSt = ''; $aSt = ''
    $bRam = ''; $aRam = ''
    if ($null -ne $before) {
        if ($null -ne $before.DiskFreeGB) { $bDiskFree = (Format-InvariantNumber ([double]$before.DiskFreeGB) 2) + ' GB' }
        if ($null -ne $before.RunningServices) { $bSvc = [string]$before.RunningServices }
        if ($null -ne $before.StartupItems) { $bSt = [string]$before.StartupItems }
        if ($null -ne $before.RamFreeGB) { $bRam = (Format-InvariantNumber ([double]$before.RamFreeGB) 2) + ' GB' }
    }
    if ($null -ne $after) {
        if ($null -ne $after.DiskFreeGB) { $aDiskFree = (Format-InvariantNumber ([double]$after.DiskFreeGB) 2) + ' GB' }
        if ($null -ne $after.RunningServices) { $aSvc = [string]$after.RunningServices }
        if ($null -ne $after.StartupItems) { $aSt = [string]$after.StartupItems }
        if ($null -ne $after.RamFreeGB) { $aRam = (Format-InvariantNumber ([double]$after.RamFreeGB) 2) + ' GB' }
    }
    $diskDiff = ''; $svcDiff = ''; $stDiff = ''; $ramDiff = ''
    if ($null -ne $cmp) {
        $diskDiff = [string]$cmp.DiskFreeDeltaText
        $svcDiff = [string]$cmp.ServiceDeltaText
        $stDiff = [string]$cmp.StartupDeltaText
        if ($null -ne $cmp.RamFreeDeltaGB) {
            $rv = [double]$cmp.RamFreeDeltaGB
            $cls = 'muted'
            if ($rv -gt 0) { $cls = 'pos' } elseif ($rv -lt 0) { $cls = 'neg' }
            $ramDiff = '<span class="' + $cls + '">' + (Format-InvariantNumber $rv 2) + ' GB</span>'
        }
    }
    [void]$sb.AppendLine('<tr><td>Disco libre</td><td>' + $bDiskFree + '</td><td>' + $aDiskFree + '</td><td>' + (ConvertTo-HtmlText $diskDiff) + '</td></tr>')
    [void]$sb.AppendLine('<tr><td>Servicios en ejecuci&oacute;n</td><td>' + $bSvc + '</td><td>' + $aSvc + '</td><td>' + (ConvertTo-HtmlText $svcDiff) + '</td></tr>')
    [void]$sb.AppendLine('<tr><td>Elementos de inicio</td><td>' + $bSt + '</td><td>' + $aSt + '</td><td>' + (ConvertTo-HtmlText $stDiff) + '</td></tr>')
    [void]$sb.AppendLine('<tr><td>RAM libre</td><td>' + $bRam + '</td><td>' + $aRam + '</td><td>' + $ramDiff + '</td></tr>')
    [void]$sb.AppendLine('</table>')

    # Detalle por tarea
    [void]$sb.AppendLine('<h2>Detalle por tarea</h2>')
    [void]$sb.AppendLine('<table>')
    [void]$sb.AppendLine('<tr><th style="width:40px">#</th><th style="width:200px">Tarea</th><th style="width:110px">Estado</th><th style="width:90px">Duraci&oacute;n</th><th style="width:110px">Delta disco</th><th>Notas</th></tr>')
    foreach ($r in $results) {
        $st = 'Omitido'
        if ($null -ne $r.Status) { $st = [string]$r.Status }
        $cls = 'skip'
        if ($st -eq 'Ok' -or $st -eq 'Ejecutado') { $cls = 'run' }
        elseif ($st -eq 'Error') { $cls = 'err' }
        elseif ($st -eq 'Simulado') { $cls = 'sim' }
        $dur = ''
        if ($null -ne $r.DurationSeconds) { $dur = (Format-InvariantNumber ([double]$r.DurationSeconds) 2) + ' s' }
        $dd = ''
        if ($null -ne $r.DiskFreeDeltaGB) {
            $ddv = [double]$r.DiskFreeDeltaGB
            $ddcls = 'muted'
            if ($ddv -gt 0) { $ddcls = 'pos' } elseif ($ddv -lt 0) { $ddcls = 'neg' }
            $dd = '<span class="' + $ddcls + '">' + (Format-InvariantNumber $ddv 2) + ' GB</span>'
        }
        [void]$sb.AppendLine('<tr><td>' + (ConvertTo-HtmlText $r.Id) + '</td><td>' + (ConvertTo-HtmlText $r.Name) + '</td><td><span class="badge ' + $cls + '">' + (ConvertTo-HtmlText $st) + '</span></td><td>' + $dur + '</td><td>' + $dd + '</td><td>' + (ConvertTo-HtmlText $r.Note) + '</td></tr>')
    }
    [void]$sb.AppendLine('</table>')

    # Alertas
    [void]$sb.AppendLine('<h2>Alertas</h2>')
    if ($warnings.Count -eq 0) {
        [void]$sb.AppendLine('<p class="muted">Sin alertas.</p>')
    } else {
        foreach ($w in $warnings) { [void]$sb.AppendLine('<div class="warn">' + (ConvertTo-HtmlText $w) + '</div>') }
    }

    [void]$sb.AppendLine('<div class="footer">Generado por Limpieza de PCs - Motor v' + (ConvertTo-HtmlText $version) + '</div>')
    [void]$sb.AppendLine('</div>')
    [void]$sb.AppendLine('</body>')
    [void]$sb.AppendLine('</html>')

    try {
        $dir = Split-Path -Path $Path -Parent
        if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        [System.IO.File]::WriteAllText($Path, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
    } catch { }
}

# ===========================================================================
# Logging
# ===========================================================================

function Write-LimpiezaLog {
    [CmdletBinding()]
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'OK')]
        [string]$Level = 'INFO',
        [string]$LogPath
    )

    $color = 'Gray'
    switch ($Level) {
        'OK' { $color = 'Green' }
        'WARN' { $color = 'Yellow' }
        'ERROR' { $color = 'Red' }
        default { $color = 'Gray' }
    }

    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = '[' + $ts + '][' + $Level + '] ' + $Message

    try { Write-Host $line -ForegroundColor $color } catch { }

    if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
        try {
            $dir = Split-Path -Path $LogPath -Parent
            if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
            Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8 -ErrorAction Stop
        } catch { }
    }
}

Export-ModuleMember -Function @(
    'Resolve-StorageType',
    'Resolve-IsLaptop',
    'Get-HardwareProfile',
    'Get-SystemMetrics',
    'Format-SizeDelta',
    'Compare-Metrics',
    'Get-TaskPlan',
    'Export-HtmlReport',
    'Export-JsonReport',
    'Write-LimpiezaLog'
)
