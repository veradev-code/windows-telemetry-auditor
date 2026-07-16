<#
=====================================================================================
  Audit-Telemetria-Bloatware.ps1
=====================================================================================
  PROPOSITO:
    Auditar (y opcionalmente deshabilitar) servicios de telemetria de Windows y
    bloatware de fabricante (ejemplo base: ASUS) en un equipo recien comprado.

  MODO POR DEFECTO: SOLO LECTURA / AUDITORIA
    El script NUNCA modifica nada por defecto. Las lineas que aplicarian cambios
    reales (Set-Service, Stop-Service, sc.exe, etc.) estan comentadas con "#".
    Para aplicar un cambio, el usuario debe leer el comentario, entender que
    hace ese servicio especifico, y descomentar la linea manualmente.

  IMPORTANTE - NO ES UN "TWEAKER" AUTOMATICO:
    Este script NO elimina servicios, NO desinstala software, y NO toca
    controladores de hardware. Solo cambia (si el usuario lo decide) el tipo
    de inicio de servicios de telemetria/software a "Disabled", lo cual es
    reversible en cualquier momento volviendo a "Manual" o "Automatic".

  REQUISITOS:
    - Ejecutar en PowerShell como Administrador (para leer el estado real
      de todos los servicios; en modo auditoria no se requiere, pero se
      recomienda para evitar advertencias de acceso denegado).
    - Windows 10 / 11.

  COMO USARLO:
    1. Ejecutar el script tal cual -> te muestra un reporte en pantalla.
    2. Revisar cada servicio marcado en AMARILLO.
    3. Si estas de acuerdo, abrir el .ps1, buscar la linea comentada
       correspondiente (empieza con "#    Set-Service") y quitar el "#".
    4. Volver a ejecutar el script.
=====================================================================================
#>

[CmdletBinding()]
param(
    # Bandera de seguridad extra: aunque descomentes lineas de accion,
    # si esta en $true el script NO ejecutara ningun cambio real.
    # Cambiala a $false manualmente solo cuando estes 100% seguro.
    [bool]$ModoSoloLectura = $true
)

# ------------------------------------------------------------------------------------
# Verificacion de privilegios (informativa, no bloqueante en modo auditoria)
# ------------------------------------------------------------------------------------
$esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $esAdmin) {
    Write-Host "[INFO] No se esta ejecutando como Administrador. El reporte de auditoria funcionara," -ForegroundColor Yellow
    Write-Host "       pero para aplicar cambios reales en el futuro necesitaras una consola elevada." -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "   AUDITORIA DE TELEMETRIA Y BLOATWARE - MODO SOLO LECTURA: $ModoSoloLectura" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------------------------------
# LISTA DE EXCLUSIONES CRITICAS (WHITELISTING)
# ------------------------------------------------------------------------------------
# Estos servicios/controladores NUNCA deben ser tocados por este script, aunque
# contengan palabras como "ASUS", "Update" o "Assist". Se listan aqui solo como
# referencia y documentacion para quien edite el script en el futuro.
#
#   - Servicios core de Windows: RpcSs, DcomLaunch, EventLog, Winmgmt (WMI),
#     BFE (Base Filtering Engine / Firewall), CryptSvc, LanmanServer/Workstation,
#     Power (administracion de energia), Schedule (Task Scheduler del sistema).
#   - Controladores de hardware del fabricante: cualquier servicio que controle
#     ventiladores, perfiles termicos/energia, teclas FN, retroiluminacion de
#     teclado, Armoury Crate / Armoury Crate Service / ASUS System Control
#     Interface (ATKWMI, AsIO, AsusFanControlService, etc.).
#   - Drivers de audio, video, red, tactil (touchpad) y bluetooth.
#
# Este script NO ENUMERA estos servicios como candidatos a deshabilitar bajo
# ninguna circunstancia. Si un servicio no esta en la lista blanca de "objetivos
# conocidos" de abajo, se ignora por diseno (no se reporta ni se toca).
# ------------------------------------------------------------------------------------

# ------------------------------------------------------------------------------------
# OBJETIVOS CONOCIDOS: Telemetria de Microsoft / Windows
# ------------------------------------------------------------------------------------
# Servicios documentados publicamente como recolectores de datos de diagnostico
# y uso, no relacionados con la funcionalidad esencial del sistema.
$telemetriaMicrosoft = @(
    [PSCustomObject]@{ Nombre = "DiagTrack";                 Descripcion = "Connected User Experiences and Telemetry (telemetria principal de Windows)" }
    [PSCustomObject]@{ Nombre = "dmwappushservice";          Descripcion = "WAP Push Message Routing (usado historicamente para telemetria/enrolamiento)" }
    [PSCustomObject]@{ Nombre = "diagnosticshub.standardcollector.service"; Descripcion = "Microsoft Diagnostics Hub Standard Collector" }
    [PSCustomObject]@{ Nombre = "PcaSvc";                    Descripcion = "Program Compatibility Assistant (recopila datos de compatibilidad de apps)" }
    [PSCustomObject]@{ Nombre = "WerSvc";                    Descripcion = "Windows Error Reporting (envia reportes de fallos a Microsoft)" }
)

# ------------------------------------------------------------------------------------
# OBJETIVOS CONOCIDOS: Bloatware / Telemetria de ASUS (ejemplo de fabricante)
# ------------------------------------------------------------------------------------
# OJO: estos NO son los servicios de control de hardware (esos estan en la
# lista de exclusiones de arriba). Son utilidades de software preinstaladas
# de tipo "asistente", "actualizador de terceros" o "recolector de uso".
# Adapta esta lista al fabricante real de tu equipo (Dell, HP, Lenovo, etc.)
# revisando primero con Get-Service | Where-Object DisplayName -like "*<marca>*"
$bloatwareASUS = @(
    [PSCustomObject]@{ Nombre = "ASUSSoftwareManager";       Descripcion = "ASUS Software / Update Manager (notificador de actualizaciones de apps de terceros preinstaladas)" }
    [PSCustomObject]@{ Nombre = "ASUSLiveUpdate";             Descripcion = "ASUS Live Update (chequeo periodico de utilidades ASUS, no drivers criticos)" }
    [PSCustomObject]@{ Nombre = "GameSDKService";             Descripcion = "Servicio de telemetria/analitica asociado a ASUS Gaming Center" }
)

# ------------------------------------------------------------------------------------
# OBJETIVOS CONOCIDOS: Notificadores de terceros comunes en laptops nuevas
# ------------------------------------------------------------------------------------
# Ejemplos genericos que aparecen en muchas marcas (McAfee, WPS Office, etc.)
# como recordatorios de suscripcion o actualizadores. Revisa el nombre exacto
# en tu equipo con Get-Service antes de asumir que coincide.
$notificadoresTerceros = @(
    [PSCustomObject]@{ Nombre = "mfewc";                      Descripcion = "McAfee WebAdvisor / notificador de suscripcion preinstalado" }
    [PSCustomObject]@{ Nombre = "McAfee.MSC.ProductNotification"; Descripcion = "Notificaciones de producto McAfee (recordatorios, no proteccion en tiempo real)" }
)

$todosLosObjetivos = $telemetriaMicrosoft + $bloatwareASUS + $notificadoresTerceros

# ------------------------------------------------------------------------------------
# FASE DE AUDITORIA: revisar el estado real de cada servicio candidato
# ------------------------------------------------------------------------------------
Write-Host "Escaneando servicios candidatos en este equipo..." -ForegroundColor Cyan
Write-Host ""

$encontrados = @()

foreach ($objetivo in $todosLosObjetivos) {
    $servicio = Get-Service -Name $objetivo.Nombre -ErrorAction SilentlyContinue

    if ($null -eq $servicio) {
        # No presente en este equipo: no es un error, simplemente no aplica.
        continue
    }

    $encontrados += $servicio

    if ($servicio.StartType -eq "Disabled") {
        Write-Host "[LIMPIO]     $($servicio.Name)  -  ya esta Disabled" -ForegroundColor Green
        Write-Host "             $($objetivo.Descripcion)" -ForegroundColor DarkGray
    }
    else {
        Write-Host "[DETECTADO]  $($servicio.Name)  -  StartType actual: $($servicio.StartType) / Status: $($servicio.Status)" -ForegroundColor Yellow
        Write-Host "             $($objetivo.Descripcion)" -ForegroundColor DarkGray
        Write-Host "             Candidato a deshabilitar (ver seccion de acciones mas abajo)." -ForegroundColor Yellow

        # ------------------------------------------------------------------------
        # ZONA DE ACCION (DESHABILITADA POR DEFECTO)
        # Descomenta la linea de abajo SOLO despues de leer la descripcion y
        # confirmar que entiendes que este servicio no es critico para ti.
        # Set-Service NO borra el servicio, solo evita que arranque solo.
        # ------------------------------------------------------------------------
         if (-not $ModoSoloLectura) {
             Set-Service -Name $servicio.Name -StartupType Disabled
             Stop-Service -Name $servicio.Name -Force -ErrorAction SilentlyContinue
             Write-Host "             -> Deshabilitado." -ForegroundColor Red
         }
    }
    Write-Host ""
}

# ------------------------------------------------------------------------------------
# RESUMEN FINAL
# ------------------------------------------------------------------------------------
Write-Host "=====================================================================" -ForegroundColor Cyan
if ($encontrados.Count -eq 0) {
    Write-Host "No se encontro ninguno de los servicios de la lista de objetivos en este equipo." -ForegroundColor Green
    Write-Host "Esto puede significar que ya fueron deshabilitados, o que los nombres de" -ForegroundColor Green
    Write-Host "servicio de tu modelo especifico son distintos (revisa con Get-Service)." -ForegroundColor Green
}
else {
    $paraDeshabilitar = $encontrados | Where-Object { $_.StartType -ne "Disabled" }
    Write-Host "Servicios candidatos encontrados: $($encontrados.Count)" -ForegroundColor Cyan
    Write-Host "Pendientes de revision manual: $($paraDeshabilitar.Count)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Este script NO aplico ningun cambio (modo auditoria)." -ForegroundColor Green
    Write-Host "Para deshabilitar un servicio especifico, edita este archivo, ubica su" -ForegroundColor Cyan
    Write-Host "bloque 'ZONA DE ACCION' y descomenta las lineas correspondientes." -ForegroundColor Cyan
}
Write-Host "=====================================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------------------------
# RECORDATORIO FINAL DE SEGURIDAD
# ------------------------------------------------------------------------------------
# - NUNCA deshabilites un servicio cuyo nombre no reconoces plenamente.
# - Antes de tocar cualquier utilidad de ASUS distinta a las listadas arriba
#   (especialmente Armoury Crate, ATKWMI, AsIO o cualquier "*Fan*", "*Power*",
#   "*Thermal*"), investiga su funcion: pueden controlar ventiladores, perfiles
#   de rendimiento o teclas de funcion, y deshabilitarlas puede causar
#   sobrecalentamiento o perdida de funcionalidad del teclado.
# - Deshabilitar (Disabled) es reversible: puedes volver a "Manual" o
#   "Automatic" con Set-Service -StartupType Manual en cualquier momento.
