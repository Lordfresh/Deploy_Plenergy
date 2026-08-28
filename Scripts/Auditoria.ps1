[console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ---------------------------------------------------------
# ENTORNO DE DESPLIEGUE LOCAL
# ---------------------------------------------------------
$RutaBase = "C:\Deploy_Plenergy"
$CarpetaLogs = "$RutaBase\Logs"

# Validar que existe la carpeta de logs
if (-not (Test-Path $CarpetaLogs)) { New-Item -Path $CarpetaLogs -ItemType Directory -Force | Out-Null }

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "   INICIANDO AUDITORIA DE DESPLIEGUE PLENERGY..." -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Cyan

# ---------------------------------------------------------
# VARIABLES DEL REPORTE
# ---------------------------------------------------------
$Fecha = Get-Date -Format "dd/MM/yyyy HH:mm"
$Equipo = $env:COMPUTERNAME
$RutaReporte = "$CarpetaLogs\Auditoria_Plenergy_$Equipo.txt"
$Reporte = @()

# Rescatar el ID de AnyDesk de la Fase 1
$ArchivoAnyDesk = "$RutaBase\AnyDesk_ID.txt"
if (Test-Path $ArchivoAnyDesk) {
    $ID_Temporal = Get-Content -Path $ArchivoAnyDesk -Raw
} else {
    $ID_Temporal = "No encontrado"
}

$Reporte += "========================================================"
$Reporte += "        REPORTE DE AUDITORIA - MAQUETADOR PLENERGY      "
$Reporte += "========================================================"
$Reporte += "Fecha: $Fecha"
$Reporte += "Equipo: $Equipo"
$Reporte += "Usuario Actual: $($env:USERNAME)"
$Reporte += "Anydesk: $ID_Temporal"
$Reporte += "--------------------------------------------------------`n"

# ---------------------------------------------------------
# 1. COMPROBAR LO QUE DEBE ESTAR (Software Requerido)
# ---------------------------------------------------------
Write-Host "`n[1/4] Comprobando software y seguridad..." -ForegroundColor Yellow
$Reporte += "[+] SOFTWARE OBLIGATORIO Y SEGURIDAD"

$AppsObligatorias = @(
    @{ Nombre = "AnyDesk"; Ruta = "C:\Program Files (x86)\AnyDesk\AnyDesk.exe" },
    @{ Nombre = "KeePass"; Ruta = "C:\Program Files*\KeePass Password Safe 2\KeePass.exe" },
    @{ Nombre = "PDF24 Creator"; Ruta = "C:\Program Files*\PDF24\pdf24-Creator.exe" },
    @{ Nombre = "FortiClient VPN"; Ruta = "C:\Program Files*\Fortinet\FortiClient\FortiClient.exe" },
    @{ Nombre = "DisplayLink"; Ruta = "C:\Program Files*\DisplayLink Core Software*" },
    @{ Nombre = "Google Chrome"; Ruta = "C:\Program Files*\Google\Chrome\Application\chrome.exe" },
    @{ Nombre = "7-Zip"; Ruta = "C:\Program Files\7-Zip\7zFM.exe" },
    @{ Nombre = "CrowdStrike Falcon"; Ruta = "C:\Program Files\CrowdStrike\CSFalconService.exe" },
    @{ Nombre = "ESET Endpoint Security"; Ruta = "C:\Program Files\ESET\ESET Security\egui.exe" }
)

foreach ($App in $AppsObligatorias) {
    if (Test-Path $App.Ruta) {
        Write-Host "  [OK] $($App.Nombre) esta instalado." -ForegroundColor Green
        $Reporte += "  [V] $($App.Nombre): INSTALADO"
    } else {
        Write-Host "  [X] $($App.Nombre) NO se encontro." -ForegroundColor Red
        $Reporte += "  [X] $($App.Nombre): FALTA"
    }
}

# ---------------------------------------------------------
# 2. COMPROBAR LO QUE NO DEBE ESTAR (Bloatware)
# ---------------------------------------------------------
Write-Host "`n[2/4] Comprobando software prohibido (Bloatware)..." -ForegroundColor Yellow
$Reporte += "`n[-] SOFTWARE PROHIBIDO (BLOATWARE)"

# McAfee
$McAfeeReg = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match "McAfee" }
if (-not $McAfeeReg -and -not (Test-Path "C:\Program Files*\McAfee*")) {
    Write-Host "  [OK] McAfee esta desinstalado." -ForegroundColor Green
    $Reporte += "  [V] McAfee: LIMPIO"
} else {
    Write-Host "  [X] Se encontraron restos de McAfee." -ForegroundColor Red
    $Reporte += "  [X] McAfee: DETECTADO"
}

# OneDrive
if (-not (Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue) -and -not (Test-Path "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe")) {
    Write-Host "  [OK] OneDrive esta desinstalado." -ForegroundColor Green
    $Reporte += "  [V] OneDrive: LIMPIO"
} else {
    Write-Host "  [X] OneDrive sigue presente." -ForegroundColor Red
    $Reporte += "  [X] OneDrive: DETECTADO"
}

# UWP Básicas
$BloatwareRestante = Get-AppxPackage | Where-Object { $_.Name -match "Solitaire|BingWeather|XboxApp|Clipchamp|FeedbackHub|BingSearch" }
if (-not $BloatwareRestante) {
    Write-Host "  [OK] Apps de Microsoft y Xbox (Basura) limpias." -ForegroundColor Green
    $Reporte += "  [V] Apps UWP Basicas (Bloatware): LIMPIO"
} else {
    Write-Host "  [X] UWP Bloatware detectado." -ForegroundColor Red
    $Reporte += "  [X] Apps UWP Basicas: DETECTADAS ($($BloatwareRestante.Name -join ', '))"
}

# ---------------------------------------------------------
# 3. COMPROBAR CONFIGURACIONES (BitLocker, Dominio, etc.)
# ---------------------------------------------------------
Write-Host "`n[3/4] Comprobando configuraciones de sistema y cifrado..." -ForegroundColor Yellow
$Reporte += "`n[*] CONFIGURACIONES DEL SISTEMA"

# Dominio
$Dominio = (Get-CimInstance Win32_ComputerSystem).PartOfDomain
if ($Dominio) {
    $NombreDominio = (Get-CimInstance Win32_ComputerSystem).Domain
    Write-Host "  [OK] Equipo en dominio: $NombreDominio" -ForegroundColor Green
    $Reporte += "  [V] Estado de Dominio: UNIDO ($NombreDominio)"
} else {
    Write-Host "  [X] El equipo esta en Grupo de Trabajo (Fuera de dominio)." -ForegroundColor Red
    $Reporte += "  [X] Estado de Dominio: FUERA DE DOMINIO"
}

# BitLocker
$BitLocker = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
if ($BitLocker.ProtectionStatus -eq 'On') {
    Write-Host "  [OK] Disco C: cifrado con BitLocker." -ForegroundColor Green
    $Reporte += "  [V] BitLocker (Disco C:): ACTIVO"
} else {
    Write-Host "  [X] Disco C: NO esta cifrado." -ForegroundColor Red
    $Reporte += "  [X] BitLocker (Disco C:): APAGADO/DESCIFRADO"
}

# Fondo de Bloqueo Corporativo
$RegPolPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
$FondoBloqueo = Get-ItemPropertyValue -Path $RegPolPath -Name "LockScreenImage" -ErrorAction SilentlyContinue
if ($FondoBloqueo) {
    Write-Host "  [OK] Directiva de fondo de bloqueo aplicada." -ForegroundColor Green
    $Reporte += "  [V] Fondo de Bloqueo: APLICADO ($FondoBloqueo)"
} else {
    Write-Host "  [X] Directiva de fondo de bloqueo ausente." -ForegroundColor Red
    $Reporte += "  [X] Fondo de Bloqueo: NO APLICADO"
}

# Comprobacion de Salvapantallas
$RegScreenSaver = "HKCU:\Control Panel\Desktop"
$SalvapantallasActivo = Get-ItemPropertyValue -Path $RegScreenSaver -Name "ScreenSaveActive" -ErrorAction SilentlyContinue

if ($SalvapantallasActivo -eq "1") {
    Write-Host "  [OK] Salvapantallas configurado en el registro." -ForegroundColor Green
    $Reporte += "  [V] Salvapantallas: CONFIGURADO"
} else {
    Write-Host "  [~] Salvapantallas no activo en esta sesion." -ForegroundColor DarkYellow
    $Reporte += "  [~] Salvapantallas: PENDIENTE"
}

# Verificacion automatica de Contrasena por defecto de HP
if (Get-LocalUser -Name "HP" -ErrorAction SilentlyContinue) {
    Write-Host "`n  -> Comprobando si la contrasena de 'HP' ha sido cambiada..." -ForegroundColor Cyan
    
    $PassPorDefecto = "Temporal123!"
    
    # Invocamos el motor local de .NET para probar la clave silenciosamente
    Add-Type -AssemblyName System.DirectoryServices.AccountManagement
    $Contexto = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Machine)
    
    if ($Contexto.ValidateCredentials("HP", $PassPorDefecto)) {
        # Si devuelve True, el inicio de sesion funciono (Sigue usando la clave expuesta)
        Write-Host "  [X] ALERTA: La contrasena de HP sigue siendo la temporal ($PassPorDefecto)." -ForegroundColor Red
        $Reporte += "`n  [X] Seguridad de cuenta (HP): VULNERABLE (Usa clave por defecto)"
    } else {
        # Si devuelve False, el inicio de sesion fallo (La clave fue cambiada con exito)
        Write-Host "  [OK] La contrasena de HP ha sido modificada y es segura." -ForegroundColor Green
        $Reporte += "`n  [V] Seguridad de cuenta (HP): MODIFICADA Y SEGURA"
    }
} else {
    Write-Host "  [X] Usuario HP no encontrado." -ForegroundColor Red
    $Reporte += "`n  [X] Seguridad de cuenta (HP): USUARIO INEXISTENTE"
}

# ---------------------------------------------------------
# 4. COMPROBAR IMPRESORAS INSTALADAS
# ---------------------------------------------------------
Write-Host "`n[4/4] Comprobando Impresoras Corporativas..." -ForegroundColor Yellow
$Reporte += "`n[#] IMPRESORAS INSTALADAS"

$ImpresorasVirtuales = @("Microsoft Print to PDF", "Microsoft XPS Document Writer", "OneNote", "Fax", "OneNote for Windows 10")
$ImpresorasInstaladas = Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin $ImpresorasVirtuales }

if ($ImpresorasInstaladas) {
    foreach ($Imp in $ImpresorasInstaladas) {
        Write-Host "  [+] $($Imp.Name) (Puerto: $($Imp.PortName))" -ForegroundColor Green
        $Reporte += "  [+] $($Imp.Name) (Puerto: $($Imp.PortName))"
    }
} else {
    Write-Host "  [-] No se detectaron impresoras corporativas instaladas." -ForegroundColor DarkYellow
    $Reporte += "  [-] No hay impresoras físicas/corporativas configuradas."
}

# ---------------------------------------------------------
# GENERACIÓN Y CIERRE DEL REPORTE
# ---------------------------------------------------------
Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "Auditoria finalizada. Generando reporte..." -ForegroundColor Yellow

if (Test-Path $RutaReporte) { Set-ItemProperty -Path $RutaReporte -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue }

$Reporte | Out-File -FilePath $RutaReporte -Encoding UTF8

Write-Host "Reporte editable guardado en: $RutaReporte" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Cyan

Invoke-Item $RutaReporte

Read-Host "`n> Presiona ENTER para salir de la auditoria..."