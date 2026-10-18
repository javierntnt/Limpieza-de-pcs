<#
    Limpieza.Core.Tests.ps1
    Tests con sintaxis compatible con Pester 3.4 (la que trae Windows).
    No requieren mocks ni hardware real: las funciones puras se prueban
    con valores sinteticos.
#>

$modulePath = Join-Path $PSScriptRoot '..\modules\Limpieza.Core.psm1'
Import-Module $modulePath -Force

Describe 'Resolve-StorageType' {
    Context 'Deteccion por texto' {
        It 'reconoce SSD' {
            (Resolve-StorageType -MediaType 'SSD' -TrimEnabled $false -IsRemovable $false) | Should Be 'SSD'
        }
        It 'reconoce Solid State Drive' {
            (Resolve-StorageType -MediaType 'Solid State Drive' -TrimEnabled $false -IsRemovable $false) | Should Be 'SSD'
        }
        It 'reconoce HDD' {
            (Resolve-StorageType -MediaType 'HDD' -TrimEnabled $false -IsRemovable $false) | Should Be 'HDD'
        }
        It 'reconoce Hard Disk Drive' {
            (Resolve-StorageType -MediaType 'Hard Disk Drive' -TrimEnabled $false -IsRemovable $false) | Should Be 'HDD'
        }
        It 'ignora espacios y mayusculas' {
            (Resolve-StorageType -MediaType '  ssd  ' -TrimEnabled $false -IsRemovable $false) | Should Be 'SSD'
        }
    }

    Context 'Deteccion por MediaType numerico' {
        It 'MediaType 4 es SSD' {
            (Resolve-StorageType -MediaType '4' -TrimEnabled $false -IsRemovable $false) | Should Be 'SSD'
        }
        It 'MediaType 3 es HDD' {
            (Resolve-StorageType -MediaType '3' -TrimEnabled $false -IsRemovable $false) | Should Be 'HDD'
        }
    }

    Context 'Fallback por TRIM' {
        It 'Unspecified con TRIM es SSD' {
            (Resolve-StorageType -MediaType 'Unspecified' -TrimEnabled $true -IsRemovable $false) | Should Be 'SSD'
        }
        It 'Unspecified sin TRIM es Unknown' {
            (Resolve-StorageType -MediaType 'Unspecified' -TrimEnabled $false -IsRemovable $false) | Should Be 'Unknown'
        }
        It 'vacio con TRIM es SSD' {
            (Resolve-StorageType -MediaType '' -TrimEnabled $true -IsRemovable $false) | Should Be 'SSD'
        }
        It 'vacio sin TRIM es Unknown' {
            (Resolve-StorageType -MediaType '' -TrimEnabled $false -IsRemovable $false) | Should Be 'Unknown'
        }
    }

    Context 'Casos borde' {
        It 'removible siempre es Unknown' {
            (Resolve-StorageType -MediaType 'SSD' -TrimEnabled $true -IsRemovable $true) | Should Be 'Unknown'
        }
        It 'null no lanza' {
            { Resolve-StorageType -MediaType $null -TrimEnabled $false -IsRemovable $false } | Should Not Throw
        }
        It 'valor desconocido es Unknown' {
            (Resolve-StorageType -MediaType 'Alien' -TrimEnabled $true -IsRemovable $false) | Should Be 'Unknown'
        }
    }
}

Describe 'Resolve-IsLaptop' {
    Context 'Chasis portatil' {
        It 'chasis 10 es laptop' {
            (Resolve-IsLaptop -ChassisTypes @(10) -HasBattery $false) | Should Be $true
        }
        It 'chasis 8 es laptop' {
            (Resolve-IsLaptop -ChassisTypes @(8) -HasBattery $false) | Should Be $true
        }
        It 'chasis 31 es laptop' {
            (Resolve-IsLaptop -ChassisTypes @(31) -HasBattery $false) | Should Be $true
        }
    }

    Context 'Chasis de escritorio' {
        It 'chasis 3 sin bateria es desktop' {
            (Resolve-IsLaptop -ChassisTypes @(3) -HasBattery $false) | Should Be $false
        }
        It 'chasis 6 sin bateria es desktop' {
            (Resolve-IsLaptop -ChassisTypes @(6) -HasBattery $false) | Should Be $false
        }
    }

    Context 'Fallback por bateria' {
        It 'chasis vacio con bateria es laptop' {
            (Resolve-IsLaptop -ChassisTypes @() -HasBattery $true) | Should Be $true
        }
        It 'chasis vacio sin bateria es desktop' {
            (Resolve-IsLaptop -ChassisTypes @() -HasBattery $false) | Should Be $false
        }
    }

    Context 'Casos borde' {
        It 'null no lanza' {
            { Resolve-IsLaptop -ChassisTypes $null -HasBattery $false } | Should Not Throw
        }
        It 'null con bateria es laptop' {
            (Resolve-IsLaptop -ChassisTypes $null -HasBattery $true) | Should Be $true
        }
    }
}

Describe 'Format-SizeDelta' {
    It 'libera espacio con un decimal' {
        (Format-SizeDelta -BeforeGB 100 -AfterGB 112.4) | Should Be '12.4 GB liberados'
    }
    It 'sin cambios cuando el delta es minimo' {
        (Format-SizeDelta -BeforeGB 100 -AfterGB 100.01) | Should Be 'Sin cambios en el disco'
    }
    It 'mas ocupado cuando el delta es negativo' {
        (Format-SizeDelta -BeforeGB 100 -AfterGB 99.7) | Should Be '0.3 GB mas ocupado'
    }
    It 'redondea correctamente hacia arriba' {
        (Format-SizeDelta -BeforeGB 10 -AfterGB 11.25) | Should Be '1.3 GB liberados'
    }
}

Describe 'Compare-Metrics' {
    It 'calcula deltas y resumen cuando mejora' {
        $before = [PSCustomObject]@{ DiskFreeGB = 100.0; RunningServices = 120; StartupItems = 10; RamFreeGB = 8.0 }
        $after = [PSCustomObject]@{ DiskFreeGB = 112.4; RunningServices = 112; StartupItems = 8; RamFreeGB = 9.5 }
        $c = Compare-Metrics -Before $before -After $after
        $c.DiskFreeDeltaGB | Should Be 12.4
        $c.DiskFreeDeltaText | Should Be '12.4 GB liberados'
        $c.ServiceDeltaText | Should Be '8 servicios menos'
        $c.StartupDeltaText | Should Be '2 elementos de inicio menos'
        $c.RamFreeDeltaGB | Should Be 1.5
        $c.Summary | Should Be 'Libere 12.4 GB de disco y quedaron 8 servicios menos.'
    }

    It 'reporta sin cambios cuando todo es igual' {
        $before = [PSCustomObject]@{ DiskFreeGB = 100.0; RunningServices = 100; StartupItems = 5; RamFreeGB = 8.0 }
        $after = [PSCustomObject]@{ DiskFreeGB = 100.0; RunningServices = 100; StartupItems = 5; RamFreeGB = 8.0 }
        $c = Compare-Metrics -Before $before -After $after
        $c.DiskFreeDeltaText | Should Be 'Sin cambios en el disco'
        $c.ServiceDeltaText | Should Be 'sin cambios en servicios'
        $c.StartupDeltaText | Should Be 'sin cambios en elementos de inicio'
        $c.Summary | Should Be 'Sin cambios de disco y sin cambios en servicios.'
    }

    It 'reporta mas servicios cuando empeora' {
        $before = [PSCustomObject]@{ DiskFreeGB = 100.0; RunningServices = 100; StartupItems = 5; RamFreeGB = 8.0 }
        $after = [PSCustomObject]@{ DiskFreeGB = 99.7; RunningServices = 103; StartupItems = 9; RamFreeGB = 7.0 }
        $c = Compare-Metrics -Before $before -After $after
        $c.ServiceDeltaText | Should Be '3 servicios mas'
        $c.StartupDeltaText | Should Be '4 elementos de inicio mas'
        $c.DiskFreeDeltaText | Should Be '0.3 GB mas ocupado'
        $c.Summary | Should Be 'Se ocuparon 0.3 GB de disco y quedaron 3 servicios mas.'
    }

    It 'no lanza con objetos nulos' {
        { Compare-Metrics -Before $null -After $null } | Should Not Throw
    }
}

Describe 'Get-TaskPlan' {
    $desktopHDD = [PSCustomObject]@{ IsLaptop = $false; StorageType = 'HDD' }
    $laptopSSD = [PSCustomObject]@{ IsLaptop = $true; StorageType = 'SSD' }

    It 'devuelve 14 tareas' {
        (Get-TaskPlan -HardwareProfile $desktopHDD).Count | Should Be 14
    }

    It 'marca Prefetch como Skip por defecto' {
        ((Get-TaskPlan -HardwareProfile $desktopHDD) | Where-Object { $_.Id -eq 7 }).Mode | Should Be 'Skip'
    }

    It '-Force convierte Prefetch en Run' {
        ((Get-TaskPlan -HardwareProfile $desktopHDD -Force) | Where-Object { $_.Id -eq 7 }).Mode | Should Be 'Run'
    }

    It 'marca MAS (14) como Skip por defecto' {
        ((Get-TaskPlan -HardwareProfile $desktopHDD) | Where-Object { $_.Id -eq 14 }).Mode | Should Be 'Skip'
    }

    It '-Force convierte MAS (14) en Run' {
        ((Get-TaskPlan -HardwareProfile $desktopHDD -Force) | Where-Object { $_.Id -eq 14 }).Mode | Should Be 'Run'
    }

    It 'marca las tareas 8 y 9 como Interactive' {
        ($plan = Get-TaskPlan -HardwareProfile $desktopHDD) | Out-Null
        ($plan | Where-Object { $_.Id -eq 8 }).Mode | Should Be 'Interactive'
        ($plan | Where-Object { $_.Id -eq 9 }).Mode | Should Be 'Interactive'
    }

    It 'en un laptop marca SkipHibernation = true' {
        ((Get-TaskPlan -HardwareProfile $laptopSSD) | Where-Object { $_.Id -eq 10 }).SkipHibernation | Should Be $true
    }

    It 'en un escritorio marca SkipHibernation = false' {
        ((Get-TaskPlan -HardwareProfile $desktopHDD) | Where-Object { $_.Id -eq 10 }).SkipHibernation | Should Be $false
    }

    It 'en SSD marca UseTrim = true' {
        ((Get-TaskPlan -HardwareProfile $laptopSSD) | Where-Object { $_.Id -eq 10 }).UseTrim | Should Be $true
    }

    It 'en HDD marca UseTrim = false' {
        ((Get-TaskPlan -HardwareProfile $desktopHDD) | Where-Object { $_.Id -eq 10 }).UseTrim | Should Be $false
    }

    It 'con almacenamiento desconocido marca UseTrim = false y motiva' {
        $unknown = [PSCustomObject]@{ IsLaptop = $false; StorageType = 'Unknown' }
        $entry = (Get-TaskPlan -HardwareProfile $unknown) | Where-Object { $_.Id -eq 10 }
        $entry.UseTrim | Should Be $false
        $entry.Reason | Should Match 'desconocido'
    }

    It 'cada tarea tiene Script .bat y Reason no vacio' {
        $plan = Get-TaskPlan -HardwareProfile $desktopHDD
        foreach ($p in $plan) {
            $p.Script | Should Match '\.bat$'
            ($p.Reason.Length -gt 0) | Should Be $true
        }
    }

    It 'no lanza con hardware nulo' {
        { Get-TaskPlan -HardwareProfile $null } | Should Not Throw
    }
}
