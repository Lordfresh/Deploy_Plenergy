[console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ---------------------------------------------------------
# 1. ENTORNO DE DESPLIEGUE (ESTRUCTURA PROFESIONAL LOCAL)
# ---------------------------------------------------------
$RutaBase         = "C:\Deploy_Plenergy"
$CarpetaScripts   = "$RutaBase\Scripts"
$CarpetaSoftware  = "$RutaBase\Software"
$CarpetaLogs      = "$RutaBase\Logs"
$CarpetaBitLocker = "$RutaBase\BitLocker_Keys"

# 2. FUNCION DE LOGS
function Write-Log {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Mensaje,
        [string]$Color = "White",
        [string]$Nivel = "INFO",
        [switch]$Silencioso
    )
    $FechaHora = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $MensajeParaLog = "[$FechaHora] [$Nivel] $Mensaje"
    if (-not $Silencioso) { Write-Host $Mensaje -ForegroundColor $Color }
    if ($global:RutaArchivoLog) { Add-Content -Path $global:RutaArchivoLog -Value $MensajeParaLog }
}

# 3. IDENTIFICACION DEL EQUIPO Y LOGS
$NumeroSerie = (Get-CimInstance Win32_BIOS).SerialNumber
$FechaNombre = (Get-Date).ToString("yyyy-MM-dd")

if (-not (Test-Path $CarpetaLogs)) { New-Item -Path $CarpetaLogs -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $CarpetaBitLocker)) { New-Item -Path $CarpetaBitLocker -ItemType Directory -Force | Out-Null }

$global:RutaArchivoLog = "$CarpetaLogs\SN-${NumeroSerie}_Fase2_${FechaNombre}.log"

# ========================================================================
# INICIO DE LA FASE 2 (SECURIZACIÓN)
# ========================================================================

if (-not (Test-Path $RutaBase)) {
    Write-Host "[X] ERROR CRITICO: No se encuentra la estructura local en $RutaBase" -ForegroundColor Red
    Start-Sleep -Seconds 7
    exit
}

Write-Log "--- NUEVA SESION DE DESPLIEGUE (FASE 2) ---" -Nivel INFO -Silencioso
Write-Log "Log inicializado. Numero de Serie: $NumeroSerie" -Nivel DEBUG -Silencioso

Write-Host "========================================================" -ForegroundColor Cyan
Write-Log "Fase 2: Securizacion, Cifrado y Conectividad" -Color Green
Write-Host "========================================================" -ForegroundColor Cyan

# ---------------------------------------------------------
# CUESTIONARIO DE DESPLIEGUE
# ---------------------------------------------------------
Write-Log "`n--- CUESTIONARIO DE DESPLIEGUE ---" -Color Yellow

$SysInfo = Get-CimInstance Win32_ComputerSystem
$EnDominio = $SysInfo.PartOfDomain
$NombreActual = $env:COMPUTERNAME

Write-Log "`n> Equipo actual: $NombreActual" -Color Cyan

$InstalarSeguridad = $false 
$MeterDominioFase2 = $false
$NuevoNombreF2 = $null
$CredencialesF2 = $null

# 1. VALIDACION DE IDENTIDAD Y RED CORPORATIVA[cite: 3]
if ($EnDominio) {
    Write-Log "> Estado de Red: UNIDO AL DOMINIO ($($SysInfo.Domain))" -Color Green
    $InstalarSeguridad = $true
} else {
    Write-Log "> Estado de Red: GRUPO DE TRABAJO (Fuera de Dominio)" -Color Red
    Write-Log "  [!] ATENCION: El equipo no esta unido a un dominio corporativo." -Color Yellow
    
    if ($NombreActual -match "^PLENERGY-") {
        Write-Log "  [V] Nomenclatura del equipo validada correctamente ($NombreActual)." -Color Green
        $RespuestaDominio = Read-Host "`n> ¿Desea integrar el equipo al dominio corporativo AHORA? [S / Enter=No]"
        
        if ($RespuestaDominio -match "^[sS]$") {
            $MeterDominioFase2 = $true
            $DominioDestino = "plenoil.com"
            Write-Log "  [!] Solicitando credenciales de administracion..." -Color Cyan
            $CredencialesValidas = $false
            
            while (-not $CredencialesValidas) {
                $CredencialesTemp = Get-Credential -UserName "$DominioDestino\ntmaster1" -Message "Credenciales de administrador (Se validara la conexion LDAP)"
                try {
                    $Usuario = $CredencialesTemp.UserName
                    $Clave = $CredencialesTemp.GetNetworkCredential().Password
                    $Directorio = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$DominioDestino", $Usuario, $Clave)
                    $Prueba = $Directorio.NativeObject 
                    Write-Log "     [V] Autenticacion LDAP exitosa. Credenciales confirmadas." -Color Green
                    $CredencialesValidas = $true
                    $CredencialesF2 = $CredencialesTemp
                } catch {
                    Write-Log "     [X] ERROR: Autenticacion rechazada." -Color Red
                    Start-Sleep -Seconds 2
                }
            }
            $Clave = $null
        }
    } else {
        Write-Log "  [!] Nomenclatura actual no estandar ($NombreActual)." -Color Red
        $NuevoNombreF2 = Read-Host "`n> Introduzca el NUEVO HOSTNAME (Ej: PLENERGY-23) o pulse Enter para omitir"
        if (-not [string]::IsNullOrWhiteSpace($NuevoNombreF2)) {
            $NuevoNombreF2 = $NuevoNombreF2.Trim().ToUpper()
        }
    }
}

# 2. REINICIO AUTOMATICO[cite: 3]
$EntradaReinicio = Read-Host "`n> ¿Desea que el equipo se reinicie AUTOMATICAMENTE al terminar la Fase 2? [S / Enter=No]"
$AutoReinicio = ($EntradaReinicio -match "^[sS]$")

# 3. BITLOCKER Y MENU DINAMICO[cite: 3]
Write-Log "`n[+] Comprobando estado actual de BitLocker en C:..." -Color Yellow
$EstadoBL = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
$BitLockerYaActivo = ($EstadoBL.ProtectionStatus -eq 'On')

if ($BitLockerYaActivo) {
    Write-Log "  -> [V] BitLocker YA ESTA ACTIVO en este equipo." -Color Green
    $ActivarBitLocker = "N" 
    
    $AbrirCarpeta = Read-Host "`n> ¿Desea abrir la carpeta local de claves BitLocker? [S / Enter=No]"
    if ($AbrirCarpeta -match "^[sS]$") { Invoke-Item $CarpetaBitLocker }
} else {
    $ActivarBitLocker = Read-Host "`n> ¿Desea activar y optimizar BitLocker? [S / Enter=No]"
    if ($ActivarBitLocker -match "^[sS]$") {
        # Simplificamos la ruta: Ahora se guarda directamente en C:\Deploy_Plenergy\BitLocker_Keys
        $NombrePC = if ($NuevoNombreF2) { $NuevoNombreF2 } else { $env:COMPUTERNAME }
        Write-Log "  [OK] BitLocker se guardara localmente para el equipo: $NombrePC" -Color DarkGray
    }
}

# 4. VPN[cite: 3]
$ActivarVPN = Read-Host "`n> ¿Desea crear los perfiles de VPN? [S / Enter=No]"

# 5. CROWDSTRIKE[cite: 3]
if ($InstalarSeguridad) {
    if (Get-Service -Name "csagent" -ErrorAction SilentlyContinue) {
        Write-Log "`n  -> [OMITIDO] CrowdStrike ya se encuentra instalado." -Color Green
        $InstalarCrowd = "N"
    } else {
        $InstalarCrowd = Read-Host "`n> ¿Desea instalar CrowdStrike Falcon? [S / Enter=No]"
        if ($InstalarCrowd -match "^[sS]$") {
            $CID_Crowdstrike = Read-Host "  > Por favor, introduce el CID (Customer ID) de Plenergy"
            if ([string]::IsNullOrWhiteSpace($CID_Crowdstrike)) { $InstalarCrowd = "N"; Write-Log "  [!] CID vacio. Instalacion cancelada." -Color Red }
        }
    }
} else {
    Write-Log "`n  -> [OMITIDO] Instalacion de CrowdStrike cancelada por politica de dominio." -Color DarkGray
    $InstalarCrowd = "N"
}

# 6. ESET[cite: 3]
if ($InstalarSeguridad) {
    if (Get-Service -Name "ekrn" -ErrorAction SilentlyContinue) {
        Write-Log "`n  -> [OMITIDO] ESET ya se encuentra instalado." -Color Green
        $InstalarEset = "N"
    } else {
        $InstalarEset = Read-Host "`n> ¿Desea instalar ESET Antivirus? [S / Enter=No]"
        if ([string]::IsNullOrWhiteSpace($InstalarEset)) { $InstalarEset = "N" }
    }
} else {
    Write-Log "`n  -> [OMITIDO] Instalacion de ESET cancelada por politica de dominio." -Color DarkGray
    $InstalarEset = "N"
}

# ---------------------------------------------------------
# 7. IMPRESORAS CORPORATIVAS (Modulo Externo)
# ---------------------------------------------------------
Write-Log "`n[+] Modulo de Impresoras..." -Color Yellow

$CarpetaDriversC = "C:\1. IMPRESORAS\AltaLink_C8030-C8070_5.639.3.0_PS_x64\AltaLink_C8030-C8070_5.639.3.0_PS_x64_Driver.inf"
$RutaScriptImpresoras = "$CarpetaScripts\Impresoras_Plenergy.ps1" 

if (-not (Test-Path $CarpetaDriversC)) {
    Write-Log "  [X] Omitido: No se encontro la carpeta de drivers instalada localmente." -Color Red
} elseif (-not (Test-Path $RutaScriptImpresoras)) {
    Write-Log "  [X] Omitido: No se encontro el modulo en $RutaScriptImpresoras." -Color DarkYellow
} else {
    Write-Log "  -> Lanzando el asistente interactivo de impresoras..." -Color Cyan
    try {
        & $RutaScriptImpresoras
        Write-Log "  -> [OK] Asistente de impresoras finalizado." -Color Green
    } catch { Write-Log "  [X] ERROR al ejecutar el script de impresoras." -Color Red }
}

# =========================================================
# MOTOR DE EJECUCION (Modo Desatendido)
# =========================================================
Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Log "Iniciando despliegue desatendido." -Color Green
Write-Host "========================================================" -ForegroundColor Cyan

# ---------------------------------------------------------
# EJECUCION: BITLOCKER
# ---------------------------------------------------------
if ($ActivarBitLocker -match "^[sS]$") {
    Write-Log "`n  -> Configurando y Cifrando con BitLocker..." -Color Gray
    
    manage-bde -protectors -add C: -rp | Out-Null
    $Volumen = Get-BitLockerVolume -MountPoint "C:"
    $Protector = $Volumen.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' } | Select-Object -First 1
    
    if ($Protector) {
        $ID = $Protector.KeyProtectorId
        $Clave = $Protector.RecoveryPassword
        $NombrePC = if ($NuevoNombreF2) { $NuevoNombreF2 } else { $env:COMPUTERNAME }
        $ArchivoClave = "$CarpetaBitLocker\Clave_BitLocker_$NombrePC.txt"
        
        $TextoLimpio = "=========================================`r`n" +
                       "       GUARDALO EN EL INVENTARIO         `r`n" +
                       "=========================================`r`n`r`n" +
                       "Equipo de fabrica: $($env:COMPUTERNAME)`r`n" +
                       "Serial Number: $NumeroSerie`r`n" +
                       "Nombre Asignado: $NombrePC`r`n" +
                       "Identificador: $ID`r`n" +
                       "Clave de recuperacion: $Clave"
        
        $TextoLimpio | Out-File $ArchivoClave -Encoding UTF8
        Write-Log "     [OK] Claves guardadas localmente en: $ArchivoClave" -Color Green
        
        manage-bde -protectors -add C: -tpm | Out-Null
        manage-bde -on C: -used -s | Out-Null
        Write-Log "     [OK] ¡Disco cifrando en segundo plano con TPM!" -Color Green
        
        Start-Process $ArchivoClave    
    } else { Write-Log "     [ERROR] No se genero la clave. Verifica el estado del TPM." -Color Red }
}

# ---------------------------------------------------------
# EJECUCION: VPN FORTICLIENT
# ---------------------------------------------------------
if ($ActivarVPN -match "^[sS]$") {
    Write-Log "`n  -> Inyectando configuraciones de VPN en FortiClient..." -Color Gray
    $PerfilesVPN = @(
        @{ CarpetaId = "VPN_1"; Server = "plenoil.fortiddns.com:4333"; Description = "VPN Plenergy" },
        @{ CarpetaId = "VPN_2"; Server = "vpn2.fortiddns.com:4433"; Description = "VPN Plenergy 2" }
    )

    try {
        foreach ($Perfil in $PerfilesVPN) {
            $RegPath = "HKLM:\SOFTWARE\Fortinet\FortiClient\Sslvpn\Tunnels\$($Perfil.CarpetaId)"
            New-Item -Path $RegPath -Force | Out-Null
            New-ItemProperty -Path $RegPath -Name "Server" -Value $Perfil.Server -PropertyType String -Force | Out-Null
            New-ItemProperty -Path $RegPath -Name "Description" -Value $Perfil.Description -PropertyType String -Force | Out-Null
            New-ItemProperty -Path $RegPath -Name "promptusername" -Value 1 -PropertyType DWord -Force | Out-Null
            New-ItemProperty -Path $RegPath -Name "promptcertificate" -Value 0 -PropertyType DWord -Force | Out-Null
            New-ItemProperty -Path $RegPath -Name "show_remember_password" -Value 1 -PropertyType DWord -Force | Out-Null
            Write-Log "     [OK] Perfil '$($Perfil.Description)' inyectado correctamente." -Color Green
        }
    } catch { Write-Log "     [X] Hubo un error al inyectar las directivas VPN." -Color Red }
}

# ---------------------------------------------------------
# EJECUCIÓN: IDENTIDAD Y DOMINIO
# ---------------------------------------------------------
Write-Log "`n[+] Ejecutando operaciones de Identidad y Red..." -Color Yellow
$RequiereReinicio = $false

if ($MeterDominioFase2) { 
    Write-Log "  -> Verificando resolucion DNS del dominio ($DominioDestino)..." -Color Gray
    $PruebaDNS = Resolve-DnsName $DominioDestino -ErrorAction SilentlyContinue
    
    if ($null -eq $PruebaDNS) {
        Write-Log "     [X] ERROR CRITICO: El equipo no ve el dominio '$DominioDestino'." -Color Red
    } else {
        try {
            $ParametrosDominio = @{ DomainName = $DominioDestino; Credential = $CredencialesF2; Force = $true; PassThru = $true; ErrorAction = 'Stop' }
            Write-Log "  -> Integrando equipo al AD..." -Color Cyan
            $Resultado = Add-Computer @ParametrosDominio
            if ($Resultado) { Write-Log "     [OK] ¡Equipo unido al dominio exitosamente!" -Color Green; $RequiereReinicio = $true }
        } catch { Write-Log "     [X] Fallo la union al Active Directory." -Color Red }
    }
} elseif ($NuevoNombreF2) {
    try {
        Write-Log "  -> Cambiando nomenclatura local a: $NuevoNombreF2..." -Color Gray
        $ParametrosNombre = @{ NewName = $NuevoNombreF2; Force = $true; PassThru = $true; ErrorAction = 'Stop' }
        $ResultadoNombre = Rename-Computer @ParametrosNombre
        if ($ResultadoNombre) { Write-Log "     [OK] Nombre local cambiado."; $RequiereReinicio = $true }
    } catch { Write-Log "     [X] Error al aplicar nomenclatura local." -Color Red }
} else { Write-Log "  -> No hay operaciones pendientes de dominio en esta fase." -Color DarkYellow }

# ---------------------------------------------------------
# EJECUCION: LIMPIEZA DE ONEDRIVE
# ---------------------------------------------------------
Write-Log "`n  -> Verificando y eliminando OneDrive..." -Color Gray
try {
    Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
    $Desinstalador = if (Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") { "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" } else { "$env:SystemRoot\System32\OneDriveSetup.exe" }
    
    if (Test-Path $Desinstalador) { Start-Process -FilePath $Desinstalador -ArgumentList "/uninstall" -Wait -NoNewWindow }
    
    Remove-Item -Path "$env:USERPROFILE\OneDrive", "$env:LOCALAPPDATA\Microsoft\OneDrive", "$env:PROGRAMDATA\Microsoft OneDrive" -Force -Recurse -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "OneDrive" -Force -ErrorAction SilentlyContinue
    Write-Log "     [OK] Rastros de OneDrive fulminados." -Color Green
} catch { Write-Log "     [X] Error intentando limpiar restos de OneDrive." -Color DarkYellow }

# ---------------------------------------------------------
# EJECUCION: CROWDSTRIKE FALCON
# ---------------------------------------------------------
if ($InstalarCrowd -match "^[sS]$") {
    Write-Log "`n  -> Instalando CrowdStrike Falcon..." -Color Gray
    $InstaladorCS = "$CarpetaSoftware\FalconSensor_Windows.exe"
    
    if (Test-Path $InstaladorCS) {
        try {
            Start-Process -FilePath $InstaladorCS -ArgumentList "/install /quiet /norestart CID=$CID_Crowdstrike ProvNoWait=1" -Wait -NoNewWindow
            Write-Log "     [OK] CrowdStrike instalado correctamente en segundo plano." -Color Green
        } catch { Write-Log "     [X] Error al ejecutar el instalador de CrowdStrike." -Color Red }
    } else { Write-Log "     [X] No se encontro el instalador en $InstaladorCS" -Color Red }
}

# ---------------------------------------------------------
# EJECUCION: ESET ENDPOINT SECURITY
# ---------------------------------------------------------
if ($InstalarEset -match "^[sS]$") {
    if (($ActivarBitLocker -match "^[sS]$") -or ($BitLockerYaActivo -eq $true)) {
        Write-Log "`n  -> Instalando ESET Endpoint Security..." -Color Gray
        $InstaladorEset = "$CarpetaSoftware\epi_win_live_installer.exe"
        
        if (Test-Path $InstaladorEset) {
            try {
                Start-Process -FilePath $InstaladorEset -ArgumentList "--silent" -Wait -NoNewWindow
                Write-Log "     [OK] ESET instalado y aprovisionado en el sistema." -Color Green
            } catch { Write-Log "     [X] Error al ejecutar el instalador de ESET." -Color Red }
        } else { Write-Log "     [X] No se encontro el instalador en $InstaladorEset" -Color Red }
    } else { Write-Log "`n  -> [OMITIDO] ESET requiere BitLocker activo." -Color DarkYellow }
}

# ---------------------------------------------------------
# FINALIZACION Y REINICIO
# ---------------------------------------------------------
Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Log "¡Fase 2 completada con exito!" -Color Green
Write-Host "========================================================" -ForegroundColor Cyan

if ($AutoReinicio) {
    Write-Log "`n[!] Lanzando aviso de reinicio automatico (60s)..." -Color Yellow
    $wshell = New-Object -ComObject Wscript.Shell
    $BotonPulsado = $wshell.Popup("El despliegue ha finalizado.`n`nEl equipo se reiniciara en 1 minuto.`n`n[Aceptar] = Reiniciar AHORA`n[Cancelar] = NO reiniciar", 60, "Reinicio de Sistema", 1 + 48 + 4096)
    
    if ($BotonPulsado -eq 2) { Write-Log "  -> [V] Reinicio CANCELADO." -Color DarkGray } 
    else { Write-Log "  -> Procediendo con el reinicio..." -Color Red; Restart-Computer -Force }
} else {
    Write-Host "`n[?] ¿Desea reiniciar el equipo AHORA?" -ForegroundColor Yellow
    Write-Host "> Pulsa S para Si, o N para No: " -NoNewline

    $TiempoEspera = 30
    $Respuesta = "N"
    $TiempoInicio = Get-Date

    while ((Get-Date) - $TiempoInicio -lt ([timespan]::FromSeconds($TiempoEspera))) {
        if ([console]::KeyAvailable) {
            $TeclaPulsada = [console]::ReadKey($true)
            if ($TeclaPulsada.KeyChar -match '^[sSnN]$') { $Respuesta = $TeclaPulsada.KeyChar.ToString().ToUpper(); break }
        }
        Start-Sleep -Milliseconds 50
    }

    Write-Host $Respuesta -ForegroundColor Cyan

    if ($Respuesta -eq "S") { Restart-Computer -Force } 
    else { Write-Log "`n[V] Despliegue finalizado. Reinicia cuando sea posible." -Color Green }
}

# ---------------------------------------------------------
# 7. IMPRESORAS CORPORATIVAS (Modulo Externo)
# ---------------------------------------------------------
Write-Log "`n[+] Modulo de Impresoras..." -Color Yellow

$CarpetaDriversC = "C:\Impresoras_Corp\AltaLink_C8030-C8070_5.639.3.0_PS_x64\AltaLink_C8030-C8070_5.639.3.0_PS_x64_Driver.inf"
$RutaScriptImpresoras = "$CarpetaScripts\Impresoras_Plenergy.ps1" 

if (-not (Test-Path $CarpetaDriversC)) {
    Write-Log "  [X] Omitido: No se encontro la carpeta de drivers instalada localmente." -Color Red
} elseif (-not (Test-Path $RutaScriptImpresoras)) {
    Write-Log "  [X] Omitido: No se encontro el modulo en $RutaScriptImpresoras." -Color DarkYellow
} else {
    Write-Log "  -> Lanzando el asistente interactivo de impresoras..." -Color Cyan
    try {
        & $RutaScriptImpresoras
        Write-Log "  -> [OK] Asistente de impresoras finalizado." -Color Green
    } catch { Write-Log "  [X] ERROR al ejecutar el script de impresoras." -Color Red }
}

# =========================================================
# MOTOR DE EJECUCION (Modo Desatendido)
# =========================================================
Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Log "Iniciando despliegue desatendido." -Color Green
Write-Host "========================================================" -ForegroundColor Cyan

# ---------------------------------------------------------
# EJECUCION: BITLOCKER
# ---------------------------------------------------------
if ($ActivarBitLocker -match "^[sS]$") {
    Write-Log "`n  -> Configurando y Cifrando con BitLocker..." -Color Gray
    
    manage-bde -protectors -add C: -rp | Out-Null
    $Volumen = Get-BitLockerVolume -MountPoint "C:"
    $Protector = $Volumen.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' } | Select-Object -First 1
    
    if ($Protector) {
        $ID = $Protector.KeyProtectorId
        $Clave = $Protector.RecoveryPassword
        $NombrePC = if ($NuevoNombreF2) { $NuevoNombreF2 } else { $env:COMPUTERNAME }
        $ArchivoClave = "$CarpetaBitLocker\Clave_BitLocker_$NombrePC.txt"
        
        $TextoLimpio = "=========================================`r`n" +
                       "       GUARDALO EN EL INVENTARIO         `r`n" +
                       "=========================================`r`n`r`n" +
                       "Equipo de fabrica: $($env:COMPUTERNAME)`r`n" +
                       "Serial Number: $NumeroSerie`r`n" +
                       "Nombre Asignado: $NombrePC`r`n" +
                       "Identificador: $ID`r`n" +
                       "Clave de recuperacion: $Clave"
        
        $TextoLimpio | Out-File $ArchivoClave -Encoding UTF8
        Write-Log "     [OK] Claves guardadas localmente en: $ArchivoClave" -Color Green
        
        manage-bde -protectors -add C: -tpm | Out-Null
        manage-bde -on C: -used -s | Out-Null
        Write-Log "     [OK] ¡Disco cifrando en segundo plano con TPM!" -Color Green
        
        Start-Process $ArchivoClave    
    } else { Write-Log "     [ERROR] No se genero la clave. Verifica el estado del TPM." -Color Red }
}

# ---------------------------------------------------------
# EJECUCION: VPN FORTICLIENT
# ---------------------------------------------------------
if ($ActivarVPN -match "^[sS]$") {
    Write-Log "`n  -> Inyectando configuraciones de VPN en FortiClient..." -Color Gray
    $PerfilesVPN = @(
        @{ CarpetaId = "VPN_1"; Server = "plenoil.fortiddns.com:4333"; Description = "VPN Plenergy" },
        @{ CarpetaId = "VPN_2"; Server = "vpn2.fortiddns.com:4433"; Description = "VPN Plenergy 2" }
    )

    try {
        foreach ($Perfil in $PerfilesVPN) {
            $RegPath = "HKLM:\SOFTWARE\Fortinet\FortiClient\Sslvpn\Tunnels\$($Perfil.CarpetaId)"
            New-Item -Path $RegPath -Force | Out-Null
            New-ItemProperty -Path $RegPath -Name "Server" -Value $Perfil.Server -PropertyType String -Force | Out-Null
            New-ItemProperty -Path $RegPath -Name "Description" -Value $Perfil.Description -PropertyType String -Force | Out-Null
            New-ItemProperty -Path $RegPath -Name "promptusername" -Value 1 -PropertyType DWord -Force | Out-Null
            New-ItemProperty -Path $RegPath -Name "promptcertificate" -Value 0 -PropertyType DWord -Force | Out-Null
            New-ItemProperty -Path $RegPath -Name "show_remember_password" -Value 1 -PropertyType DWord -Force | Out-Null
            Write-Log "     [OK] Perfil '$($Perfil.Description)' inyectado correctamente." -Color Green
        }
    } catch { Write-Log "     [X] Hubo un error al inyectar las directivas VPN." -Color Red }
}

# ---------------------------------------------------------
# EJECUCIÓN: IDENTIDAD Y DOMINIO
# ---------------------------------------------------------
Write-Log "`n[+] Ejecutando operaciones de Identidad y Red..." -Color Yellow
$RequiereReinicio = $false

if ($MeterDominioFase2) { 
    Write-Log "  -> Verificando resolucion DNS del dominio ($DominioDestino)..." -Color Gray
    $PruebaDNS = Resolve-DnsName $DominioDestino -ErrorAction SilentlyContinue
    
    if ($null -eq $PruebaDNS) {
        Write-Log "     [X] ERROR CRITICO: El equipo no ve el dominio '$DominioDestino'." -Color Red
    } else {
        try {
            $ParametrosDominio = @{ DomainName = $DominioDestino; Credential = $CredencialesF2; Force = $true; PassThru = $true; ErrorAction = 'Stop' }
            Write-Log "  -> Integrando equipo al AD..." -Color Cyan
            $Resultado = Add-Computer @ParametrosDominio
            if ($Resultado) { Write-Log "     [OK] ¡Equipo unido al dominio exitosamente!" -Color Green; $RequiereReinicio = $true }
        } catch { Write-Log "     [X] Fallo la union al Active Directory." -Color Red }
    }
} elseif ($NuevoNombreF2) {
    try {
        Write-Log "  -> Cambiando nomenclatura local a: $NuevoNombreF2..." -Color Gray
        $ParametrosNombre = @{ NewName = $NuevoNombreF2; Force = $true; PassThru = $true; ErrorAction = 'Stop' }
        $ResultadoNombre = Rename-Computer @ParametrosNombre
        if ($ResultadoNombre) { Write-Log "     [OK] Nombre local cambiado."; $RequiereReinicio = $true }
    } catch { Write-Log "     [X] Error al aplicar nomenclatura local." -Color Red }
} else { Write-Log "  -> No hay operaciones pendientes de dominio en esta fase." -Color DarkYellow }

# ---------------------------------------------------------
# EJECUCION: LIMPIEZA DE ONEDRIVE
# ---------------------------------------------------------
Write-Log "`n  -> Verificando y eliminando OneDrive..." -Color Gray
try {
    Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
    $Desinstalador = if (Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") { "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" } else { "$env:SystemRoot\System32\OneDriveSetup.exe" }
    
    if (Test-Path $Desinstalador) { Start-Process -FilePath $Desinstalador -ArgumentList "/uninstall" -Wait -NoNewWindow }
    
    Remove-Item -Path "$env:USERPROFILE\OneDrive", "$env:LOCALAPPDATA\Microsoft\OneDrive", "$env:PROGRAMDATA\Microsoft OneDrive" -Force -Recurse -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "OneDrive" -Force -ErrorAction SilentlyContinue
    Write-Log "     [OK] Rastros de OneDrive fulminados." -Color Green
} catch { Write-Log "     [X] Error intentando limpiar restos de OneDrive." -Color DarkYellow }

# ---------------------------------------------------------
# EJECUCION: CROWDSTRIKE FALCON
# ---------------------------------------------------------
if ($InstalarCrowd -match "^[sS]$") {
    Write-Log "`n  -> Instalando CrowdStrike Falcon..." -Color Gray
    $InstaladorCS = "$CarpetaSoftware\FalconSensor_Windows.exe"
    
    if (Test-Path $InstaladorCS) {
        try {
            Start-Process -FilePath $InstaladorCS -ArgumentList "/install /quiet /norestart CID=$CID_Crowdstrike ProvNoWait=1" -Wait -NoNewWindow
            Write-Log "     [OK] CrowdStrike instalado correctamente en segundo plano." -Color Green
        } catch { Write-Log "     [X] Error al ejecutar el instalador de CrowdStrike." -Color Red }
    } else { Write-Log "     [X] No se encontro el instalador en $InstaladorCS" -Color Red }
}

# ---------------------------------------------------------
# EJECUCION: ESET ENDPOINT SECURITY
# ---------------------------------------------------------
if ($InstalarEset -match "^[sS]$") {
    if (($ActivarBitLocker -match "^[sS]$") -or ($BitLockerYaActivo -eq $true)) {
        Write-Log "`n  -> Instalando ESET Endpoint Security..." -Color Gray
        $InstaladorEset = "$CarpetaSoftware\epi_win_live_installer.exe"
        
        if (Test-Path $InstaladorEset) {
            try {
                Start-Process -FilePath $InstaladorEset -ArgumentList "--silent" -Wait -NoNewWindow
                Write-Log "     [OK] ESET instalado y aprovisionado en el sistema." -Color Green
            } catch { Write-Log "     [X] Error al ejecutar el instalador de ESET." -Color Red }
        } else { Write-Log "     [X] No se encontro el instalador en $InstaladorEset" -Color Red }
    } else { Write-Log "`n  -> [OMITIDO] ESET requiere BitLocker activo." -Color DarkYellow }
}

# ---------------------------------------------------------
# FINALIZACION, LIMPIEZA Y REINICIO
# ---------------------------------------------------------
Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Log "¡Fase 2 completada con exito!" -Color Green
Write-Host "========================================================" -ForegroundColor Cyan

Write-Log "`n[+] Ejecutando cierre de seguridad y recoleccion de logs..." -Color Yellow

# 1. Aplicar contrasena definitiva al usuario HP (Metodo Seguro)
Write-Log "  -> Solicitando credenciales definitivas al tecnico..." -Color Cyan
$CredencialesValidas = $false

while (-not $CredencialesValidas) {
    try {
        $MensajeCaja = "Despliegue finalizado. Introduce la contrasena DEFINITIVA para el usuario local."
        # Lanza el popup nativo de Windows pre-rellenando el usuario
        $Credencial = Get-Credential -UserName "HP" -Message $MensajeCaja
        
        # Aplicamos la clave directamente como SecureString (Cifrada)
        Get-LocalUser -Name "HP" | Set-LocalUser -Password $Credencial.Password -ErrorAction Stop
        
        Write-Log "  [OK] Contrasena del usuario HP actualizada y asegurada en el sistema." -Color Green
        $CredencialesValidas = $true
    } catch {
        Write-Log "  [X] Accion cancelada o error. Debes establecer una contrasena obligatoriamente." -Color Red
        Start-Sleep -Seconds 2
    }
}

# 2. Eliminar el acceso directo del lanzador
$RutaLanzador = "$env:PUBLIC\Desktop\LanzadorPlenergy.lnk"
Remove-Item -Path $RutaLanzador -Force -ErrorAction SilentlyContinue

# 3. Comprimir Logs (Nombre del PC + _Logs)
$NombreEquipo = $env:COMPUTERNAME
$RutaZip = "C:\${NombreEquipo}_Logs.zip"
$RutaLogPPKG = "C:\Log_PPKG.txt"
$RutaLogsCarpeta = "C:\Deploy_Plenergy\Logs\*"

$ArchivosAComprimir = @()
if (Test-Path $RutaLogsCarpeta) { $ArchivosAComprimir += $RutaLogsCarpeta }
if (Test-Path $RutaLogPPKG) { $ArchivosAComprimir += $RutaLogPPKG }

if ($ArchivosAComprimir.Count -gt 0) {
    try {
        Compress-Archive -Path $ArchivosAComprimir -DestinationPath $RutaZip -Update -Force
        Write-Log "  [OK] Logs consolidados exitosamente en: $RutaZip" -Color Green
    } catch { Write-Log "  [X] Error al empaquetar los logs." -Color Red }
}

# 4. Bloque de Reinicio (Tu logica)
if ($AutoReinicio) {
    Write-Log "`n[!] Lanzando aviso de reinicio automatico (60s)..." -Color Yellow
    $wshell = New-Object -ComObject Wscript.Shell
    $BotonPulsado = $wshell.Popup("El despliegue ha finalizado.`n`nEl equipo se reiniciara en 1 minuto.`n`n[Aceptar] = Reiniciar AHORA`n[Cancelar] = NO reiniciar", 60, "Reinicio de Sistema", 1 + 48 + 4096)
    
    if ($BotonPulsado -eq 2) { Write-Log "  -> [V] Reinicio CANCELADO." -Color DarkGray } 
    else { Write-Log "  -> Procediendo con el reinicio..." -Color Red; Restart-Computer -Force }
} else {
    Write-Host "`n[?] ¿Desea reiniciar el equipo AHORA?" -ForegroundColor Yellow
    Write-Host "> Pulsa S para Si, o N para No: " -NoNewline

    $TiempoEspera = 30
    $Respuesta = "N"
    $TiempoInicio = Get-Date

    while ((Get-Date) - $TiempoInicio -lt ([timespan]::FromSeconds($TiempoEspera))) {
        if ([console]::KeyAvailable) {
            $TeclaPulsada = [console]::ReadKey($true)
            if ($TeclaPulsada.KeyChar -match '^[sSnN]$') { $Respuesta = $TeclaPulsada.KeyChar.ToString().ToUpper(); break }
        }
        Start-Sleep -Milliseconds 50
    }

    Write-Host $Respuesta -ForegroundColor Cyan

    if ($Respuesta -eq "S") { Restart-Computer -Force } 
    else { Write-Log "`n[V] Despliegue finalizado. Reinicia cuando sea posible." -Color Green }
}