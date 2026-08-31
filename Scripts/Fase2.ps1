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

# Comprobar bitlocker antes de que el JSON tome el control.
$EstadoBL = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
$BitLockerYaActivo = ($EstadoBL.ProtectionStatus -eq 'On')

# =========================================================
# INTERCEPTOR ZERO TOUCH (JSON) - FASE 2
# =========================================================
$ModoDesatendido = $false
$RutaJson = $null
$ArchivosJsonEncontrados = @()

Write-Log "`n[+] Buscando archivo de configuracion Zero Touch (*AutoDespliegue.json)..." -Color Gray

# 1. Buscar en la carpeta local base
$ArchivosLocales = Get-ChildItem -Path $RutaBase -Filter "*AutoDespliegue.json" -File -ErrorAction SilentlyContinue
if ($ArchivosLocales) { $ArchivosJsonEncontrados += $ArchivosLocales }

# 2. Buscar en la raiz de todos los pendrives conectados
$UnidadesUSB = Get-CimInstance Win32_LogicalDisk | Where-Object DriveType -eq 2
foreach ($USB in $UnidadesUSB) {
    $RutaRaizUSB = "$($USB.DeviceID)\"
    $ArchivosUSB = Get-ChildItem -Path $RutaRaizUSB -Filter "*AutoDespliegue.json" -File -ErrorAction SilentlyContinue
    if ($ArchivosUSB) { $ArchivosJsonEncontrados += $ArchivosUSB }
}

# 3. Ordenar TODOS los encontrados por fecha
if ($ArchivosJsonEncontrados.Count -gt 0) {
    $ArchivosJsonEncontrados = $ArchivosJsonEncontrados | Sort-Object LastWriteTime -Descending
    $RutaJson = $ArchivosJsonEncontrados[0].FullName
}    
    Write-Log "  [V] Archivo mas reciente detectado: $RutaJson" -Color Cyan

    $wshell = New-Object -ComObject Wscript.Shell
    # 4 (Sí/No) + 32 (Pregunta) + 4096 (Siempre arriba)
    $MensajeJson = "Se ha detectado el archivo de configuracion MAS RECIENTE:`n$($ArchivosJsonEncontrados[0].Name)`n`n¿Deseas aplicar la configuracion automatica ZERO TOUCH?`n`n(Si no respondes en 10 segundos, se aplicara automaticamente)"
    $Respuesta = $wshell.Popup($MensajeJson, 10, "Modo Autonomo Detectado", 4 + 32 + 4096)

    # Si pulsa 'Sí' (6) o se agota el tiempo (-1)
    if ($Respuesta -eq 6 -or $Respuesta -eq -1) {
        Write-Log "  [+] Modo ZERO TOUCH activado. Mapeando cerebro JSON..." -Color Magenta
        $ModoDesatendido = $true
        
        # Copiar el JSON al disco C: si viene del USB (Failsafe)
        if ($RutaJson -notmatch "^C:\\Deploy_Plenergy") {
            Copy-Item -Path $RutaJson -Destination "$RutaBase\AutoDespliegue.json" -Force -ErrorAction SilentlyContinue
            Write-Log "  [i] Archivo JSON clonado al disco C: por seguridad." -Color DarkGray
        }

        
       try {
            $Config = Get-Content $RutaJson | ConvertFrom-Json

            # --- DESCIFRADO RSA (Fase 2) --- Si llego a tener credenciales de dominio. 
            # Pegas aquí tu clave PRIVADA (El XML largo con P, Q, DP, DQ, D)
            # $ClavePrivadaXML = "<RSAKeyValue><Modulus>PEGAR_AQUI...</Modulus><Exponent>AQAB</Exponent><P>...</P>...</RSAKeyValue>"
            # $RSA_Descifrado = New-Object System.Security.Cryptography.RSACryptoServiceProvider
            # $RSA_Descifrado.FromXmlString($ClavePrivadaXML)
            #
            # if (-not [string]::IsNullOrWhiteSpace($Config.Identidad.PasswordDominio)) {
            #     $BytesCifrados = [Convert]::FromBase64String($Config.Identidad.PasswordDominio)
            #     $BytesDescifrados = $RSA_Descifrado.Decrypt($BytesCifrados, $false)
            #     $PassTextoPlano = [System.Text.Encoding]::UTF8.GetString($BytesDescifrados)
            #     
            #     $SecureDomPass = ConvertTo-SecureString $PassTextoPlano -AsPlainText -Force
            #     # IMPORTANTE: Sustituye "ntmaster1" por la cuenta delegada real que te asigne Sistemas
            #     $global:Auto_CredencialesDominio = New-Object System.Management.Automation.PSCredential("plenoil.com\ntmaster1", $SecureDomPass)
            #     $MeterDominioFase2 = $true
            # }
            
            # Mapeo de variables interactivas de Fase 2
            $AutoReinicio    = [bool]$Config.Despliegue.AutoReinicio
            $ActivarBitLocker= if ($Config.Seguridad.ActivarBitLocker) { "S" } else { "N" }
            $ActivarVPN      = if ($Config.Seguridad.ConfigurarVPN) { "S" } else { "N" }
            $InstalarCrowd   = if ($Config.Seguridad.InstalarCrowdStrike) { "S" } else { "N" }
            $CID_Crowdstrike = $Config.Seguridad.CID_CrowdStrike
            $InstalarEset    = if ($Config.Seguridad.InstalarEset) { "S" } else { "N" }
            
            $global:Auto_PassHP = $Config.Identidad.PasswordHP
            $global:Auto_ImpresorasTodas = $Config.Impresoras.InstalarTodas
            $global:Auto_ImpresorasIds = $Config.Impresoras.ImpresorasId

            # --- PARCHE HIBRIDO: Pedir credenciales de dominio si no esta en AD ---
            $SysInfo = Get-CimInstance Win32_ComputerSystem
            $DominioDestino = "plenoil.com"
            
            if (-not $SysInfo.PartOfDomain -and $env:COMPUTERNAME -match "^PLENERGY-") {
                Write-Log "  -> [Modo Hibrido] El equipo requiere dominio. Verificando red corporativa..." -Color Cyan
                
                # 1. El Guardian: Comprobar DNS Interno antes de preguntar nada
                $PruebaDNSInterno = Resolve-DnsName "_ldap._tcp.dc._msdcs.$DominioDestino" -Type SRV -ErrorAction SilentlyContinue
                
                if ($null -eq $PruebaDNSInterno) {
                    Write-Log "     [X] ERROR: No se detecta el DNS interno de $DominioDestino." -Color Red
                    Write-Log "     -> Omitiendo peticion de credenciales (El equipo no esta en la red corporativa)." -Color DarkYellow
                    $MeterDominioFase2 = $false
                } else {
                    Write-Log "     [V] Red corporativa detectada. Solicitando credenciales..." -Color Green
                    
                    # 2. Bucle de Autenticacion (Maximo 5 intentos)
                    $CredencialesValidas = $false
                    $Intentos = 0
                    $MaxIntentos = 5
                    
                    while (-not $CredencialesValidas) {
                        if ($Intentos -ge $MaxIntentos) {
                            Write-Log "  [!] Se han superado los $MaxIntentos intentos de autenticacion." -Color Yellow
                            $Omitir = Read-Host "  > ¿Deseas OMITIR la union al dominio? [S para omitir / ENTER para reintentar]"
                            
                            if ($Omitir -match "^[sS]$") {
                                Write-Log "  -> Union al dominio cancelada por el usuario. Continuando script..." -Color DarkGray
                                $MeterDominioFase2 = $false
                                break
                            } else {
                                $Intentos = 0
                                Write-Log "  -> Reiniciando contador de intentos..." -Color Cyan
                            }
                        }

                        try {
                            $MensajeCaja = "Intento $($Intentos + 1) de $MaxIntentos : Introduce credenciales de dominio (Validacion LDAP interna)"
                            $CredencialesTemp = Get-Credential -UserName "$DominioDestino\ntmaster1" -Message $MensajeCaja -ErrorAction Stop
                            
                            $Usuario = $CredencialesTemp.UserName
                            $Clave = $CredencialesTemp.GetNetworkCredential().Password
                            
                            # 3. Validacion LDAP
                            $Directorio = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$DominioDestino", $Usuario, $Clave)
                            [void]$Directorio.NativeObject # <-- El [void] quita el error de VSCode
                            
                            Write-Log "     [V] Autenticacion LDAP exitosa." -Color Green
                            $CredencialesValidas = $true
                            $global:Auto_CredencialesDominio = $CredencialesTemp
                            $MeterDominioFase2 = $true
                        } 
                        catch {
                            Write-Log "     [X] ERROR: Credenciales rechazadas o ventana cancelada." -Color Red
                            Write-Log "         Detalle tecnico: $($_.Exception.Message)" -Color DarkRed
                            $Intentos++  # Incrementa contador de intentos fallidos
                            Start-Sleep -Seconds 1  # Pausa de seguridad para evitar ataques de fuerza bruta
                        }
                    }
                }
            }

            # [TACTICA TIERRA QUEMADA] El archivo solo se borra aqui al final de la lectura
            if (Test-Path $RutaJson) { Remove-Item -Path $RutaJson -Force -ErrorAction SilentlyContinue }

            Write-Log "  [OK] Reglas inyectadas y JSON purgado. Saltando cuestionario." -Color Green
            
        } catch {
            # ESTE ES EL CATCH PRINCIPAL QUE TE FALTABA
            Write-Log "  [X] Error al leer el JSON. Pasando a manual..." -Color Red
            $ModoDesatendido = $false
        }
    else {
        Write-Log "  [-] Autodespliegue cancelado. Iniciando cuestionario manual..." -Color DarkYellow
    }
}

# Si no se encuentra JSON hace preguntas...
if (-not $ModoDesatendido) {

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

    # 1. VALIDACION DE IDENTIDAD Y RED CORPORATIVA
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
                $DominioDestino = "plenoil.com"
                
                # 1. Validacion DNS Interno (Guardian de Red)
                Write-Log "  -> Verificando red corporativa (DNS Interno)..." -Color Gray
                $PruebaDNSInterno = Resolve-DnsName "_ldap._tcp.dc._msdcs.$DominioDestino" -Type SRV -ErrorAction SilentlyContinue
                
                if ($null -eq $PruebaDNSInterno) {
                    Write-Log "     [X] ERROR: No se detecta el DNS interno de $DominioDestino." -Color Red
                    Write-Log "     -> Cancelando union al dominio (El equipo no esta en la red corporativa)." -Color DarkYellow
                } else {
                    Write-Log "     [V] Red corporativa detectada. Solicitando credenciales..." -Color Cyan
                    $MeterDominioFase2 = $true
                    $CredencialesValidas = $false
                    $Intentos = 0
                    $MaxIntentos = 5
                    
                    # 2. Bucle de Seguridad con limite de intentos y rescate
                    while (-not $CredencialesValidas) {
                        if ($Intentos -ge $MaxIntentos) {
                            Write-Log "  [!] Se han superado los $MaxIntentos intentos de autenticacion." -Color Yellow
                            $Omitir = Read-Host "  > ¿Deseas OMITIR la union al dominio? [S para omitir / ENTER para reintentar]"
                            
                            if ($Omitir -match "^[sS]$") {
                                Write-Log "  -> Union al dominio cancelada por el usuario. Continuando script..." -Color DarkGray
                                $MeterDominioFase2 = $false
                                break
                            } else {
                                $Intentos = 0
                                Write-Log "  -> Reiniciando contador de intentos..." -Color Cyan
                            }
                        }

                        try {
                            $MensajeCaja = "Intento $($Intentos + 1) de $MaxIntentos : Credenciales de administrador (Validacion LDAP)"
                            $CredencialesTemp = Get-Credential -UserName "$DominioDestino\ntmaster1" -Message $MensajeCaja -ErrorAction Stop
                            
                            $Usuario = $CredencialesTemp.UserName
                            $Clave = $CredencialesTemp.GetNetworkCredential().Password
                            
                            # 3. Validacion LDAP
                            $Directorio = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$DominioDestino", $Usuario, $Clave)
                            $Prueba = $Directorio.NativeObject 
                            
                            Write-Log "     [V] Autenticacion LDAP exitosa. Credenciales confirmadas." -Color Green
                            $CredencialesValidas = $true
                            $CredencialesF2 = $CredencialesTemp
                        } catch {
                            Write-Log "     [X] ERROR: Credenciales rechazadas o ventana cancelada." -Color Red
                            $Intentos++
                            Start-Sleep -Seconds 1
                        }
                    }
                    $Clave = $null
                }
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
    $DominioDestino = "plenoil.com"
    Write-Log "  -> Verificando resolucion DNS interna del Active Directory..." -Color Gray
    
    # Resolucion SRV: Garantiza que estamos hablando con los servidores DNS internos reales
    $PruebaDNSInterno = Resolve-DnsName "_ldap._tcp.dc._msdcs.$DominioDestino" -Type SRV -ErrorAction SilentlyContinue
    
    if ($null -eq $PruebaDNSInterno) {
        Write-Log "     [X] ERROR CRITICO: El equipo no ve el DNS interno del dominio '$DominioDestino'." -Color Red
        Write-Log "         (Posiblemente este resolviendo la IP publica desde fuera de la red corporativa)." -Color DarkYellow
    } else {
        try {
            # Toma la credencial del JSON hibrido o del cuestionario manual
            $CredsAUsar = if ($global:Auto_CredencialesDominio) { $global:Auto_CredencialesDominio } else { $CredencialesF2 }
            $ParametrosDominio = @{ DomainName = $DominioDestino; Credential = $CredsAUsar; Force = $true; PassThru = $true; ErrorAction = 'Stop' }
            
            Write-Log "  -> Integrando equipo al AD..." -Color Cyan
            $Resultado = Add-Computer @ParametrosDominio
            
            if ($Resultado) { 
                Write-Log "     [OK] ¡Equipo unido al dominio exitosamente!" -Color Green
                $RequiereReinicio = $true 
            }
        } catch { Write-Log "     [X] Fallo la union al Active Directory." -Color Red }
    }
} elseif ($NuevoNombreF2) {
    try {
        Write-Log "  -> Cambiando nomenclatura local a: $NuevoNombreF2..." -Color Gray
        $ParametrosNombre = @{ NewName = $NuevoNombreF2; Force = $true; PassThru = $true; ErrorAction = 'Stop' }
        $ResultadoNombre = Rename-Computer @ParametrosNombre
        if ($ResultadoNombre) { Write-Log "     [OK] Nombre local cambiado."; $RequiereReinicio = $true }
    } catch { Write-Log "     [X] Error al aplicar nomenclatura local." -Color Red }
} else { 
    Write-Log "  -> No hay operaciones pendientes de dominio en esta fase." -Color DarkYellow 
}
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
# 7. IMPRESORAS CORPORATIVAS (Modulo Externo)
# ---------------------------------------------------------
Write-Log "`n[+] Modulo de Impresoras..." -Color Yellow

$CarpetaDriversC = "C:\IMPRESORAS\AltaLink_C8030-C8070_5.639.3.0_PS_x64\AltaLink_C8030-C8070_5.639.3.0_PS_x64_Driver.inf"
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

# ---------------------------------------------------------
# FINALIZACION, LIMPIEZA Y REINICIO
# ---------------------------------------------------------
Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Log "¡Fase 2 completada con exito!" -Color Green
Write-Host "========================================================" -ForegroundColor Cyan

Write-Log "`n[+] Ejecutando cierre de seguridad y recoleccion de logs..." -Color Yellow

# 1. Aplicar contraseña definitiva al usuario HP (Modo Hibrido)
try {
    if (-not [string]::IsNullOrWhiteSpace($global:ZeroTouch_PassHP)) {
        Write-Log "  -> [Zero Touch] Aplicando contrasena definitiva para HP silenciosamente..." -Color Magenta
        $SecurePass = ConvertTo-SecureString $global:ZeroTouch_PassHP -AsPlainText -Force
        Get-LocalUser -Name "HP" | Set-LocalUser -Password $SecurePass -ErrorAction Stop
        Write-Log "  [OK] Contrasena automatica de HP configurada." -Color Green
    } else {
        Write-Log "  -> Solicitando credenciales definitivas al tecnico..." -Color Cyan
        $CredencialesValidas = $false
        while (-not $CredencialesValidas) {
            try {
                $MensajeCaja = "Despliegue finalizado. Introduce la contrasena DEFINITIVA para el usuario local."
                $Credencial = Get-Credential -UserName "HP" -Message $MensajeCaja
                Get-LocalUser -Name "HP" | Set-LocalUser -Password $Credencial.Password -ErrorAction Stop
                Write-Log "  [OK] Contrasena del usuario HP actualizada y asegurada en el sistema." -Color Green
                $CredencialesValidas = $true
            } catch {
                Write-Log "  [X] Accion cancelada o error. Debes establecer una contrasena obligatoriamente." -Color Red
                Start-Sleep -Seconds 2
            }
        }
    }
} catch { Write-Log "  [X] Error fatal al establecer la contrasena de HP." -Color Red }

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