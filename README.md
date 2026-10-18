# 🧹 Limpieza de PCs

[![GitHub repo size](https://img.shields.io/github/repo-size/javierntnt/Limpieza-de-pcs?style=for-the-badge)](https://github.com/javierntnt/Limpieza-de-pcs)
[![GitHub stars](https://img.shields.io/github/stars/javierntnt/Limpieza-de-pcs?style=for-the-badge)](https://github.com/javierntnt/Limpieza-de-pcs/stargazers)
[![GitHub license](https://img.shields.io/github/license/javierntnt/Limpieza-de-pcs?style=for-the-badge)](https://github.com/javierntnt/Limpieza-de-pcs/blob/main/LICENSE)
[![GitHub last commit](https://img.shields.io/github/last-commit/javierntnt/Limpieza-de-pcs?style=for-the-badge)](https://github.com/javierntnt/Limpieza-de-pcs/commits/main)

> **Suite completa de mantenimiento y optimización para sistemas Windows.** Diseñada para técnicos y usuarios avanzados que quieren limpiar, optimizar y poner a punto PCs de forma rápida y consistente.

---

## 📦 ¿Qué incluye este repositorio?

Este repositorio contiene dos carpetas principales con herramientas de mantenimiento:

### 🛠️ `Limpiesa pcs` — Suite de Scripts Batch

**Herramienta principal:** `Automatizacion.bat` — Menú interactivo que orquesta 14 scripts de mantenimiento.

| # | Script | Función |
|---|--------|---------|
| 0 | `restaurar_punto.bat` | Crea un punto de restauración antes de optimizar |
| 1 | `Temp.bat` | Limpia archivos temporales (`%temp%` y `C:\Windows\Temp`) |
| 2 | `windows_update.bat` | Limpia la caché de Windows Update |
| 3 | `Cache.bat` | Ejecuta el Liberador de espacio en disco (cleanmgr) |
| 4 | `limpiar_visor_eventos.bat` | Limpia todos los registros del Visor de Eventos |
| 5 | `Limpieza_Servicios.bat` | Deshabilita telemetría, Xbox Game Bar y servicios innecesarios |
| 6 | `Limpieza_sesion.bat` | Limpia Prefetch (no recomendado — puede ralentizar apps) |
| 7 | `desactivar_inicio.bat` | Guía interactiva para configurar inicio y rendimiento visual |
| 8 | `planes_energia.bat` | Cambia entre planes de energía de Windows |
| 9 | `optimizar_rendimiento.bat` | Optimización avanzada: background apps, Superfetch, DISM, hibernación, DNS |
| 10 | `verificar_sistema.bat` | Verifica archivos del sistema (SFC /SCANNOW) y busca/instala actualizaciones con Winget |
| 11 | `chris_titus.bat` | Lanza la herramienta WinUtil de Chris Titus Tech |
| 12 | `activar_windows.bat` | Activación de Windows usando scripts MAS (requiere internet) |
| 13 | `activar_wsearch.bat` | Activa Windows Search/Indexación |

**Documentación incluida:**
- `README.md` — Esta guía completa
- `Facil.txt` — Guía visual de los tweaks de Chris Titus con casillas para marcar

**Características:**
- ✅ Todos los scripts requieren permisos de Administrador (algunos lo piden automáticamente)
- ✅ Cada script pregunta (S/N) antes de hacer cambios (seguro)
- ✅ Menú principal orquesta todos los scripts en secuencia con confirmación
- 🎯 Ideales para: liberar espacio, mejorar rendimiento, desactivar telemetría, limpiar registros, optimizar energía

### 📁 `Herramientas` — Utilidades Diversas

| Herramienta | Descripción |
|-------------|-------------|
| **ISLC v1.0.4.5** | Intelligent Standby List Cleaner — Libera memoria RAM al purgar listas standby inactivas. Línea de comandos: `-minimized -polling 500 -listsize 1024 -freememory 1024` |
| **RAMMap** | Herramienta Sysinternals para analizar el uso de memoria en tiempo real. Muestra qué archivos y datos están ocupando memoria física. |
| **VideoDownloaderPro** | Descargador de videos basado en Python. Ideal para descargar videos de YouTube, Vimeo y otras plataformas. |
| **AnyDesk.exe** | Control remoto de PCs. Permite acceder y controlar otros ordenadores en la red. |

---

## 🚀 Cómo usar

### Opción 1: Menú principal (recomendado)

```powershell
cd "C:\Users\USUARIO\Documents\Limpieza de pcs github\Limpieza-de-pcs\Limpiesa pcs"
.\Automatizacion.bat
```

Selecciona una opción del menú o presiona `T` para ejecutar TODO en secuencia con confirmación para cada tarea.

### Opción 2: Scripts individuales

```powershell
# Ejemplo limpiando archivos temporales
cd "C:\Users\USUARIO\Documents\Limpieza de pcs github\Limpieza-de-pcs\Limpiesa pcs"
.\Temp.bat
```

### Opción 3: Herramientas auxiliares

```powershell
# ISLC minimizado con polling cada 500ms
cd "C:\Users\USUARIO\Documents\Limpieza de pcs github\Limpieza-de-pcs\Herramientas\ISLC v1.0.4.5"
.\ISLC.exe -minimized -polling 500 -listsize 1024 -freememory 1024
```

---

## ⚙️ Motor PowerShell (`Limpieza.ps1`)

Además de la suite de scripts `.bat`, el repositorio incluye un motor en PowerShell que automatiza todo el flujo: **detecta el hardware** (SSD/HDD, laptop/escritorio), **decide qué tareas conviene ejecutar**, mide el sistema **antes y después**, ejecuta los `.bat` existentes como tareas y genera un **reporte HTML autocontenido** (más un JSON con los mismos datos).

> Los scripts `.bat` siguen siendo los mismos: el motor solo los orquesta. No reemplaza a `Automatizacion.bat`.

### Requisitos
- Windows PowerShell **5.1** (viene con Windows). No requiere instalar nada.
- Algunas tareas necesitan **administrador** (el motor lo pide automáticamente).

### La forma fácil: doble clic en `Limpieza.bat`

`Limpieza.bat` es el lanzador del motor: **doble clic y listo**. Hace falta porque a un `.ps1` Windows no lo ejecuta con doble clic, lo abre en el Bloc de notas.

```bat
Limpieza.bat                    :: menú interactivo
Limpieza.bat -DryRun -All       :: simula todo, sin tocar el sistema
Limpieza.bat -All               :: mantenimiento completo
Limpieza.bat -Task 2,4          :: solo las tareas indicadas
```

La ventana queda abierta al terminar, así podés leer el resumen y la ruta del reporte antes de cerrarla.

### Cómo ejecutarlo desde una consola

```powershell
cd "Limpiesa pcs"

# Menú interactivo (igual al clásico)
.\Limpieza.ps1

# Simulación: hace todo (hardware, métricas, plan, reportes) pero NO ejecuta tareas.
# NO requiere administrador y no modifica el sistema.
.\Limpieza.ps1 -DryRun -All

# Ejecutar todas las tareas automáticas que el plan marque como "Run"
.\Limpieza.ps1 -All

# Ejecutar solo algunas tareas por Id
.\Limpieza.ps1 -Task 1,2,4
```

Opciones disponibles: `-Force` (ignora las omisiones por hardware/política, ej. Prefetch), `-NoReport`, `-ReportsPath`, `-LogsPath`.

### Dónde quedan los resultados
- Reportes: `Limpiesa pcs\reports\reporte_<PC>_<fecha>.html` y `.json`
- Registros: `Limpiesa pcs\logs\limpieza_<fecha>.log`

El HTML es **autocontenido** (CSS embebido, sin internet ni recursos externos) y se abre con doble clic.

### Cómo correr los tests

```powershell
Invoke-Pester -Path "Limpiesa pcs\tests"
```

> **Nota sobre Pester:** los tests usan la sintaxis de **Pester 3.4** (la que viene instalada por defecto en Windows), por ejemplo `Should Be`. No hace falta instalar Pester 5.

---

## ⚠️ Consideraciones Importantes

### ⚡ Requisitos
- **Permisos de Administrador:** La mayoría de los scripts deben ejecutarse como administrador.
- **Windows 10/11:** Todas las herramientas están diseñadas para sistemas Windows modernos.
- **Internet:** Algunos scripts (`activar_windows.bat`, `verificar_sistema.bat`) requieren conexión a internet.

### 🛡️ Seguridad
- **Punto de restauración:** El script `restaurar_punto.bat` siempre se recomienda ejecutar primero antes de optimizar.
- **Confirmaciones:** Cada script pregunta (S/N) antes de hacer cambios importantes.
- **No abortar:** No interrumpa la ejecución de los scripts a mitad para evitar inconsistencias.

### ⚠️ Advertencias
- **Prefetch (Script 6):** No recomendado — puede ralentizar el inicio de aplicaciones.
- **IPv6 (Script avanzado):** Desactivar IPv6 rompe algunas redes modernas.
- **Store Apps:** Remover todas las apps de Microsoft Store es un extremo que borra hasta la calculadora.

---

## 📬 Contacto y Soporte

- **Repositorio:** [https://github.com/javierntnt/Limpieza-de-pcs](https://github.com/javierntnt/Limpieza-de-pcs)
- **Autor:** JavierNTNT
### 📄 Licencia y autoría
- **Licencia:** No tiene licencia definida - Este es software de código abierto para uso personal y técnico.
- **Creador:** JavierNTNT - Suite de mantenimiento y optimización para Windows.
- **Aviso de código abierto:** Este proyecto se distribuye bajo la filosofía de software abierto. Puedes usarlo y modificarlo libremente, pero no hay garantía formal ni soporte profesional.

---

## 🙏 Agradecimientos

- **Chris Titus Tech** — Por la guía de tweaks y WinUtil
- **Don Paquito** — Por ServiceKiller_Lite
- **Microsoft** — Por herramientas nativas (cleanmgr, SFC, Winget)
- **Sysinternals** — Por RAMMap

---

### ⭐ ¿Te gustó este proyecto?

Dale una ⭐ en GitHub para apoyar el desarrollo y hacer más visible esta suite de mantenimiento!

---

**Última actualización:** 6 de octubre de 2026