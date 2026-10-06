# 🧹 Limpiesa de PCs — Suite de Mantenimiento para Windows

Suite de scripts batch para mantenimiento y optimización de sistemas Windows. Diseñada para técnicos y usuarios avanzados que quieren limpiar, optimizar y poner a punto PCs de forma rápida y consistente.

> ⚠ **Ejecutar siempre como Administrador** — `Automatizacion.bat` lo pide automáticamente.

## 📋 Scripts incluidos

| # | Script | Función |
|---|--------|---------|
| 0 | `restaurar_punto.bat` | Crea un punto de restauración del sistema antes de optimizar |
| 1 | `Temp.bat` | Limpia archivos temporales (`%temp%` y `C:\Windows\Temp`) |
| 2 | `windows_update.bat` | Limpia caché de Windows Update (SoftwareDistribution) |
| 3 | `Cache.bat` | Ejecuta el Liberador de espacio en disco (cleanmgr) |
| 4 | `limpiar_visor_eventos.bat` | Limpia todos los registros del Visor de Eventos |
| 5 | `Limpieza_Servicios.bat` | Deshabilita telemetría, Xbox Game Bar y servicios innecesarios |
| 6 | `Limpieza_sesion.bat` | Limpia Prefetch **(no recomendado — ralentiza apps)** |
| 7 | `desactivar_inicio.bat` | Guía interactiva para configurar inicio y rendimiento visual |
| 8 | `planes_energia.bat` | Cambia entre planes de energía de Windows |
| 9 | `optimizar_rendimiento.bat` | Optimización avanzada: background apps, Superfetch, DISM, hibernación, servicios extra, DNS |
| 10 | `verificar_sistema.bat` | Verifica archivos del sistema (SFC /SCANNOW) y busca/instala actualizaciones de programas con Winget |
| 11 | `chris_titus.bat` | Lanza la herramienta WinUtil de Chris Titus Tech |
| — | `Automatizacion.bat` | **Menú principal** — orquesta todos los scripts anteriores |

## 🚀 Cómo usar

Ejecutá **`Automatizacion.bat`** — te va a pedir permisos de administrador automáticamente y después abre el menú principal.

Cada script también funciona por separado y **te va a preguntar (S/N)** antes de hacer cualquier cambio.

---

# 🛠️ WinUtil — Guía de Optimización (Chris Titus Tech)

Herramienta externa recomendada para optimización avanzada. Se lanza desde `chris_titus.bat` o manualmente con:

```powershell
iwr -useb https://christitus.com/win | iex
```

> **Ejecutar como Administrador en PowerShell.**

## 1️⃣ Tweaks Esenciales ✅ (Recomendado para TODAS las PCs)

| Opción | Por qué activarla |
|--------|-------------------|
| **Create Restore Point** | Crea backup antes de tocar nada — **OBLIGATORIO** |
| **Run Disk Cleanup** | Limpieza profunda del disco duro |
| **Delete Temporary Files** | Elimina basura para liberar espacio |
| **Disable Telemetry** | Apaga envío de datos a Microsoft (ahorra recursos) |
| **Disable Activity History** | Evita que Windows guarde historial de uso |
| **Disable Location Tracking** | Apaga rastreo de GPS/ubicación (ahorra CPU) |
| **Disable ConsumerFeatures** | Bloquea instalación de apps basura (Candy Crush, etc.) |
| **Disable Hibernation** | Borra el archivo de hibernación (libera ~4 GB - 8 GB) |
| **Disable WPBT** | Bloquea bloatware de la placa base (Asus, etc.) |
| **Disable Explorer Discovery** | Evita escaneo automático de carpetas (más rápido) |
| **Remove Widgets** | Borra panel de noticias (ahorra mucha RAM) |
| **Set Services to Manual** | Pasa servicios a manual (arranque más rápido) |

### Opcionales

| Opción | Decisión |
|--------|:--------:|
| Disable PowerShell 7 Telemetry | ❌ No necesario |
| Enable End Task Right Click | ⚪ A gusto |

## 2️⃣ Tweaks Avanzados ⚠️ (Depende del uso de la PC)

| Opción | Por qué activarla |
|--------|-------------------|
| **Disable Background Apps** | Evita que apps corran de fondo — **libera mucha RAM** |
| **Disable Fullscreen Optimizations** | Mejora FPS y latencia en juegos |
| **Disable Microsoft Copilot** | Saca la IA de la barra de tareas |
| **Edge Debloat** | Quita telemetría y basura de Microsoft Edge |
| **Brave Debloat** | Limpia funciones cripto (si usan Brave) |
| **Remove Xbox & Gaming Components** | Elimina la barra Xbox — ideal si no juegan o usan Steam |
| **Set Classic Right-Click** | Vuelve al menú contextual clásico (más rápido en Win11) |
| **Set Display for Performance** | Quita animaciones — la PC vuela, pero se ve más fea |
| **Remove OneDrive** | Elimina OneDrive (ahorra internet y RAM) |
| **Block Razer Installs** | Evita que Synapse se instale solo |
| **Remove Gallery/Home** | Limpia la barra lateral del explorador de archivos |
| **Prefer IPv4 over IPv6** | Prioriza IPv4 para evitar problemas de ping |

### ❌ No recomiendo

| Opción | Motivo |
|--------|--------|
| Disable IPv6 | Rompe algunas redes modernas |
| Disable Storage Sense | Dejá que Windows limpie solo |
| Remove ALL MS Store Apps | Borra hasta la calculadora — muy extremo |

## 3️⃣ Tweaks de UI / Perfil 🎨

| Opción | Por qué |
|--------|---------|
| **Bing Search in Start Menu** | Saca la búsqueda de internet del menú inicio — **CLAVE** |
| **Recommendations in Start** | Saca los anuncios de apps sugeridas |
| **Remove Settings Home Page** | Saca los banners de publicidad en Configuración |
| **Show File Extensions** | Muestra extensiones (`.exe`, `.pdf`) — **seguridad clave** |
| **Disable Sticky Keys** | Apaga el cartel de "Teclas Especiales" (Shift × 5) |
| **Disable Multiplane Overlay** | Arregla parpadeos en videos/juegos |
| **Modern Standby Fix** | Evita que laptops se prendan solas en la mochila |

### Opcionales estéticos

| Opción | Para qué |
|--------|----------|
| Mouse Acceleration | Desactivar = mejor aim en juegos |
| Center Taskbar Items | Estético |
| Dark Theme | Estético |
| Detailed BSoD | Muestra el texto técnico en pantallazo azul |
| Verbose Messages | Muestra los procesos al arrancar |

---

## 📁 Archivos del proyecto

```
Limpiesa pcs/
├── Automatizacion.bat          # Menú principal (orquestador)
├── restaurar_punto.bat         # Punto de restauracion del sistema
├── Temp.bat                    # Limpieza de archivos temporales
├── windows_update.bat          # Limpieza de caché de Windows Update
├── Cache.bat                   # Liberador de espacio en disco
├── limpiar_visor_eventos.bat   # Limpieza del Visor de Eventos
├── Limpieza_Servicios.bat      # Deshabilitar servicios innecesarios
├── Limpieza_sesion.bat         # Limpieza de Prefetch (no recomendado)
├── desactivar_inicio.bat       # Guía de configuración de inicio
├── planes_energia.bat          # Selector de planes de energía
├── optimizar_rendimiento.bat   # Optimización avanzada de rendimiento
├── verificar_sistema.bat       # SFC /SCANNOW y Windows Update
├── chris_titus.bat             # Lanzador de WinUtil
├── README.md                   # Esta guía
└── ControlDePcsDistancia/      # Herramientas de control remoto
```
