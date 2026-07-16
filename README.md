# 🛡️ Windows Telemetry Auditor & Cleaner

![Windows](https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?style=for-the-badge&logo=powershell&logoColor=white)
![Open Source](https://img.shields.io/badge/Open_Source-4CAF50?style=for-the-badge&logo=open-source-initiative&logoColor=white)

Script de PowerShell avanzado y seguro diseñado para auditar y deshabilitar servicios de telemetría y bloatware OEM (como Armoury Crate) en Windows. Optimiza el consumo de RAM y previene cuellos de botella en la CPU, manteniendo intactos los servicios críticos del sistema y del hardware.

---

## ⚠️ Advertencia de Seguridad y Configuración

Por diseño y protección al usuario, este script se ejecuta por defecto en **Modo de Solo Lectura (Auditoría)**. Escaneará tu sistema e identificará los servicios, pero **NO** realizará ningún cambio real.

Para que el script ejecute la limpieza, debes abrir el archivo `Audit-Telemetria-Bloatware.ps1` en tu editor de código y cambiar manualmente la variable `$ModoSoloLectura` a `$false` en el bloque inicial:

```powershell
[CmdletBinding()]
param(
    # Bandera de seguridad extra: aunque descomentes lineas de accion,
    # si esta en $true el script NO ejecutara ningun cambio real.
    # Cambiala a $false manualmente solo cuando estes 100% seguro.
    [bool]$ModoSoloLectura =$false
)
```
---
🚀 Instrucciones de Ejecución
Debido a las políticas de seguridad predeterminadas de Windows, debes ejecutar este script omitiendo temporalmente la restricción de ejecución.

Abre PowerShell como Administrador.

Navega hasta la carpeta donde guardaste el archivo.

Ejecuta el script con el flag ExecutionPolicy Bypass.

Ejemplo de ejecución en consola:

```powershell
PS C:\> powershell -ExecutionPolicy Bypass -File .\Audit-Telemetria-Bloatware.ps1
(Nota: Ajusta la ruta mostrada arriba según la carpeta donde hayas descargado el archivo en tu equipo).
```
---
### 🌐 Conecta conmigo
Desarrollado con buenas prácticas por veradev.
Si el script te fue útil, acompáñame en mis redes para más contenido sobre arquitectura de software, backend y optimización de sistemas:

[![Beacons](https://img.shields.io/badge/Beacons-veradev-black?style=for-the-badge&logo=beacons)](https://beacons.ai/veradev)
[![YouTube](https://img.shields.io/badge/YouTube-veradev-red?style=for-the-badge&logo=youtube)](https://www.youtube.com/@veradev_)
[![TikTok](https://img.shields.io/badge/TikTok-veradev-black?style=for-the-badge&logo=tiktok)](https://www.tiktok.com/@veradev_)
[![Instagram](https://img.shields.io/badge/Instagram-veratecno360-E4405F?style=for-the-badge&logo=instagram)](https://www.instagram.com/veratecno360)
