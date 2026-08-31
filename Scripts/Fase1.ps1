[console]::OutputEncoding = [System.Text.Encoding]::UTF8 # Aquí se habla Español 

# ---------------------------------------------------------
# 1. ENTORNO DE DESPLIEGUE (ESTRUCTURA PROFESIONAL LOCAL)
# ---------------------------------------------------------
$RutaBase        = "C:\Deploy_Plenergy"
$CarpetaScripts  = "$RutaBase\Scripts"
$CarpetaSoftware = "$RutaBase\Software"
$CarpetaRecursos = "$RutaBase\Recursos"
$CarpetaLogs     = "$RutaBase\Logs"

# 2. FUNCION DE LOGS (Unificada y Robusta)
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

# Crear carpeta de logs si no existe
if (-not (Test-Path $CarpetaLogs)) { New-Item -Path $CarpetaLogs -ItemType Directory -Force | Out-Null }

$global:RutaArchivoLog = "$CarpetaLogs\SN-${NumeroSerie}_Fase1_${FechaNombre}.log"

# ========================================================================
# INICIO DEL SCRIPT (FASE 1)
# ========================================================================

# --- VALIDACIÓN ESTRUCTURAL ---
if (-not (Test-Path $RutaBase)) {
    Write-Host "`n[ERROR CRITICO] No se encontro el directorio base en $RutaBase." -ForegroundColor Red
    Write-Host "Por favor, copia la carpeta del maquetador a la raiz del disco C: y vuelve a intentarlo." -ForegroundColor Yellow
    Start-Sleep -Seconds 7
    exit 
}

Write-Log "`n[OK] Entorno de despliegue validado en $RutaBase. Iniciando maquetacion..." -Color Green

# ---------------------------------------------------------
# 1. COMPROBACIÓN DE RED E INYECCIÓN WI-FI
# ---------------------------------------------------------
Write-Log "`n[1/10] Comprobando perfiles Wi-Fi y conectividad..." -Color Yellow

$NombreWifi = "OperacionesIT"
$RutaWifiPpkg = "$CarpetaRecursos\PPKG\WifiOperacionesIT.ppkg"

# 1A. INYECCION DE PPKG DE WIFI EN CASO DE SER NECESARIO
$PerfilesInstalados = netsh wlan show profiles
if ($PerfilesInstalados -match $NombreWifi) {
    Write-Log "  [OK] Las redes Wi-Fi '$NombreWifi' ya estan configuradas." -Color Green
} else {
    if (Test-Path $RutaWifiPpkg) {
        Write-Log "  -> Inyectando paquete PPKG de redes Wi-Fi (Intento Inicial)..." -Color Cyan
        try {
            Install-ProvisioningPackage -PackagePath $RutaWifiPpkg -QuietInstall -ForceInstall
            Write-Log "  [OK] Redes Wi-Fi inyectadas con exito. Esperando 5s para negociacion..." -Color Green
            Start-Sleep -Seconds 5
        } catch {
            Write-Log "  [X] Hubo un problema al inyectar el paquete Wi-Fi inicial." -Color Red 
            Write-Log "Fallo en PPKG: $($_.Exception.Message)" -Nivel ERROR -Silencioso
        }
    } else { 
        Write-Log "  [!] No se encontro el archivo en $RutaWifiPpkg. Pasando a validacion..." -Color DarkGray 
    }
}

# 1B. BUCLE DE VALIDACION DE INTERNET Y AUTO-RESCATE
$InternetOK = $false

while (-not $InternetOK) {
    Write-Log "  -> Comprobando resolucion DNS y salida a Internet..." -Color Gray
    
    $PruebaDNS = Resolve-DnsName "www.google.com" -ErrorAction SilentlyContinue
    
    if ($PruebaDNS) {
        Write-Log "  [V] ¡Conexion a Internet confirmada!" -Color Green
        $InternetOK = $true
    } else {
        Write-Log "  [X] Sin conexion a Internet." -Color Red
        
        # --- INTENTO DE RESCATE DENTRO DEL BUCLE ---
        $PerfilesActuales = netsh wlan show profiles
        if (-not ($PerfilesActuales -match $NombreWifi)) {
            if (Test-Path $RutaWifiPpkg) {
                Write-Log "  -> Reintentando inyeccion de paquete PPKG..." -Color Cyan
                try {
                    Install-ProvisioningPackage -PackagePath $RutaWifiPpkg -QuietInstall -ForceInstall
                    Write-Log "  [OK] Redes Wi-Fi inyectadas. Esperando 10s para negociacion..." -Color Green
                    Start-Sleep -Seconds 10
                    continue 
                } catch {
                    Write-Log "  [X] Fallo al inyectar el PPKG en el reintento." -Color Red 
                }
            }
        }
        # ---------------------------------------------
        
        Write-Host "`n[!] El script necesita Internet para instalar aplicaciones y otras tareas." -ForegroundColor Yellow
        Write-Host "    Conecta un cable de red, verifica el PPKG o revisa la Wi-Fi manualmente." -ForegroundColor Yellow
        
        $RespuestaRed = Read-Host "`n> Escribe 'S' para continuar SIN RED, o presiona ENTER para reintentar"
        
        if ($RespuestaRed -match "^[sS]$") {
            Write-Log "  -> [!] ADVERTENCIA: Se ha forzado continuar el despliegue sin conexion a internet." -Color DarkYellow
            break 
        } else {
            Write-Log "  -> Reintentando ciclo de conexion..." -Color Cyan
            Start-Sleep -Seconds 2
        }
    }
}

# ---------------------------------------------------------
# 2. ANYDESK (Verificacion, Instalacion y Accesos Directos)
# ---------------------------------------------------------
Write-Log "`n[2/10] Verificando y configurando AnyDesk..." -Color Yellow

$RutaAnyDeskExe = "C:\Program Files (x86)\AnyDesk\AnyDesk.exe"
# Fijamos la ruta al escritorio publico para evitar duplicados en distintos perfiles
$ShortcutPath = "$env:PUBLIC\Desktop\AnyDesk.lnk"
$InstaladoAhora = $false

# 1. Instalación o Detección
if (Test-Path $RutaAnyDeskExe) {
    Write-Log "  [~] AnyDesk detectado en el sistema. Saltando instalacion..." -Color DarkYellow
} else {
    $AnyDeskPath = "$CarpetaSoftware\AnyDesk.exe"
    
    if (Test-Path $AnyDeskPath) {
        try {
            $ArgumentosAnyDesk = "--install", "`"C:\Program Files (x86)\AnyDesk`"", "--start-with-win", "--silent"
            Start-Process -FilePath $AnyDeskPath -ArgumentList $ArgumentosAnyDesk -Wait -NoNewWindow -ErrorAction Stop
            Write-Log "  [OK] AnyDesk instalado en el sistema." -Color Green
            $InstaladoAhora = $true
        } catch {
            Write-Log "  [X] Error critico al lanzar el instalador de AnyDesk." -Color Red
            Write-Log "Fallo Start-Process: $($_.Exception.Message)" -Nivel ERROR -Silencioso
        }
    } else { 
        Write-Log "  [X] No se encontro el instalador en $AnyDeskPath." -Color Red 
    }
}

# 2. Creación segura del acceso directo en el escritorio publico
if (Test-Path $RutaAnyDeskExe) {
    if (-not (Test-Path $ShortcutPath)) {
        Write-Log "  -> Generando acceso directo en el escritorio..." -Color Cyan
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
        $Shortcut.TargetPath = $RutaAnyDeskExe
        $Shortcut.Save()
        Write-Log "  [OK] Icono creado exitosamente." -Color Green
    } else {
        Write-Log "  [V] El icono de AnyDesk ya existe en el escritorio." -Color Green
    }
}

# 3. Captura del ID (Bucle Robusto)
if (Test-Path $RutaAnyDeskExe) {
    Write-Log "  -> Solicitando ID de conexion a los servidores de AnyDesk..." -Color Gray
    
    $ID_AnyDesk = ""
    $Intentos = 0
    $MaxIntentos = 6 
    
    while ([string]::IsNullOrWhiteSpace($ID_AnyDesk) -and $Intentos -lt $MaxIntentos) {
        if ($InstaladoAhora -or $Intentos -gt 0) { Start-Sleep -Seconds 5 }
        $ID_AnyDesk = (& $RutaAnyDeskExe --get-id | ForEach-Object { $_ }) -join ""
        if ($ID_AnyDesk) { $ID_AnyDesk = $ID_AnyDesk.Trim() }
        $Intentos++
    }
    
    # 4. Presentacion y Guardado
    if (-not [string]::IsNullOrWhiteSpace($ID_AnyDesk)) {
        
        $ArchivoID = "$RutaBase\AnyDesk_ID.txt"
        $ID_AnyDesk | Out-File -FilePath $ArchivoID -Encoding UTF8 -Force
        
        Write-Host "`n=================================================" -ForegroundColor Cyan
        Write-Host "   ID DE ANYDESK DEL EQUIPO: $ID_AnyDesk" -ForegroundColor Green
        Write-Host "=================================================`n" -ForegroundColor Cyan
        
        Write-Log "ID ($ID_AnyDesk) obtenido tras $Intentos intento(s). Guardado en $ArchivoID" -Nivel INFO -Silencioso
        
    } else {
        Write-Log "  [X] No se pudo obtener el ID (El equipo quiza no tenga salida a Internet)." -Color Red
    }
}

# Banner decorativo actualizado a Fase 1
Write-Log "--- NUEVA SESION DE DESPLIEGUE (FASE 1) ---" -Nivel INFO -Silencioso
Write-Log "Log inicializado. Numero de Serie: $NumeroSerie" -Nivel DEBUG -Silencioso

Write-Host "================================================================" -ForegroundColor Cyan
Write-Log "   MAQUETADOR PLENERGY: FASE 1 (Despliegue Pre-dominio)       " -Color Green
Write-Host "================================================================" -ForegroundColor Cyan

# =========================================================
# INTERCEPTOR ZERO TOUCH (JSON)
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

# 3. Ordenar TODOS los encontrados por fecha (El mas reciente gana) y procesar
if ($ArchivosJsonEncontrados.Count -gt 0) {
    $ArchivosJsonEncontrados = $ArchivosJsonEncontrados | Sort-Object LastWriteTime -Descending
    $RutaJson = $ArchivosJsonEncontrados[0].FullName
    
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

            # 1. Validacion Segura de Contrasena
            if (-not [string]::IsNullOrWhiteSpace($Config.Identidad.PasswordSistemas)) {
                $SysPassSecure = ConvertTo-SecureString $Config.Identidad.PasswordSistemas -AsPlainText -Force
            } else {
                $SysPassSecure = $null
                Write-Log "  [!] PasswordSistemas vacio en JSON. Se omitira la creacion del usuario." -Color DarkYellow
            }

            # 2. Asignacion con valores por defecto (Anti-Errores)
            $OpcionEmpresa = if ($Config.Identidad.DivisionEmpresa) { [string]$Config.Identidad.DivisionEmpresa } else { "1" }
            
            # Asignar el nombre exacto del JSON, o dejar en $null para mantener el nombre original
            if (-not [string]::IsNullOrWhiteSpace($Config.Identidad.PrefijoEquipo)) {
                $NuevoNombre = $Config.Identidad.PrefijoEquipo
            } else {
                $NuevoNombre = $null
                Write-Log "  [i] Nombre de equipo vacio en JSON. Se mantendra el nombre actual de fabrica." -Color DarkYellow
            }
            
            $AutoReinicio  = [bool]$Config.Despliegue.AutoReinicio
            $EjecutarFase2 = if ($Config.Despliegue.ContinuarFase2) { "S" } else { "N" }
            $OpcionMcAfee  = if ($Config.Limpieza.DesinstalarMcAfee) { "1" } else { "0" }
            
            Write-Log "  [OK] Variables inyectadas en memoria. Saltando cuestionario." -Color Green
        } catch {
            Write-Log "  [X] Error fatal al leer el JSON. Revisa el formato. Pasando a manual..." -Color Red
            $ModoDesatendido = $false
        }
    } else {
        Write-Log "  [-] Modo autonomo cancelado por el usuario. Iniciando asistente manual..." -Color DarkYellow
    }
} else {
    Write-Log "  [-] No se encontro ningun JSON de autodespliegue. Iniciando asistente manual..." -Color Gray
}

# =========================================================
# BLOQUE A: FASE DE RECOPILACIÓN DE DATOS (Interacción Humana)
# =========================================================
if (-not $ModoDesatendido) {
    
    # =========================================================
    # BLOQUE A: FASE DE RECOPILACIÓN DE DATOS (Interacción Humana)
    # =========================================================
    Write-Log "`n--- RECOPILACION DE DATOS ---" -Color Yellow

    # 1. Contrasena de Usuario Sistemas
    Write-Log "`n> Configuracion de la cuenta de Administrador Local alternativa (SISTEMAS)" -Color Cyan
    $UserName = "SISTEMAS"

    if (Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue) {
        Write-Log "  [i] El usuario $UserName ya existe en el equipo. Omitiendo peticion de contrasena." -Color DarkYellow
        $SysPassSecure = $null 
        Write-Log "Q&A - Usuario SISTEMAS: Usuario ya existente, se omite contraseña." -Nivel DEBUG -Silencioso
    } else {
        do {
            $SysPassSecure1 = Read-Host "  Introduce la contrasena para el usuario $UserName" -AsSecureString
            $SysPassSecure2 = Read-Host "  Confirma la contrasena para el usuario $UserName" -AsSecureString

            $TextoPass1 = (New-Object System.Management.Automation.PSCredential("temp", $SysPassSecure1)).GetNetworkCredential().Password
            $TextoPass2 = (New-Object System.Management.Automation.PSCredential("temp", $SysPassSecure2)).GetNetworkCredential().Password

            if ($TextoPass1 -ne $TextoPass2) { Write-Log "  [!] Las contrasenas no coinciden. Vuelve a intentarlo.`n" -Color Red }
        } until ($TextoPass1 -eq $TextoPass2)
        
        $SysPassSecure = $SysPassSecure1
        Write-Log "Q&A - Usuario SISTEMAS: Contrasena validada y capturada." -Nivel DEBUG -Silencioso
    }

    # 2. Gestión de McAfee
    Write-Log "`n> Verificando existencia de McAfee en el sistema..." -Color Cyan
    $RegistryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $McAfeeReg = Get-ItemProperty $RegistryPaths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match "McAfee" }
    $McAfeePath = Test-Path "C:\Program Files*\McAfee*"

    if ($McAfeeReg -or $McAfeePath) {
        Write-Log "  [!] ¡McAfee detectado en el sistema!" -Color DarkYellow
        Write-Log "  ¿Como deseas proceder con la desinstalacion de McAfee?"
        Start-Sleep -seconds 2
        Write-Host "  1. Usar el asistente de desinstalacion Mcafee"
        Start-Sleep -seconds 1
        Write-Host "  2. Lo hare yo manualmente desde el Panel de Control"
        
        $EntradaMcAfee = Read-Host "  Elige una opcion (Presiona ENTER para usar '1')"
        if ([string]::IsNullOrWhiteSpace($EntradaMcAfee)) { $OpcionMcAfee = "1" } else { $OpcionMcAfee = $EntradaMcAfee.Trim() }
        Write-Log "Q&A - McAfee: El usuario selecciono la opcion $OpcionMcAfee" -Nivel DEBUG -Silencioso
    } else {
        Write-Log "  [V] Equipo limpio de McAfee. Omitiendo opciones de desinstalacion." -Color Green
        $OpcionMcAfee = "0"
        Write-Log "Q&A - McAfee: No detectado. Paso omitido." -Nivel DEBUG -Silencioso
    }

    # 3. Identidad del Equipo
    Write-Log "`n> El equipo actualmente se llama: $($env:COMPUTERNAME)" -Color Yellow
    $CambiarNombre = Read-Host "  ¿Desea cambiar el nombre del equipo? [S / Enter=No]"
    $NuevoNombre = $null

    if ($CambiarNombre -match "^[sS]$") {
        $EntradaNombre = Read-Host "  Introduce el NUEVO NOMBRE (Ej: PLENERGY-23)"
        if ($EntradaNombre) { $NuevoNombre = $EntradaNombre.Trim().ToUpper() }
        Write-Log "Q&A - Nombre Equipo: Peticion de cambio a $NuevoNombre." -Nivel DEBUG -Silencioso
    } else {
        Write-Log "Q&A - Nombre Equipo: Se mantiene el nombre original ($($env:COMPUTERNAME))." -Nivel DEBUG -Silencioso
    }

    # 4. Reinicio Automático
    $EntradaReinicio = Read-Host "`n> ¿Desea que el equipo se reinicie AUTOMATICAMENTE al terminar todo el script? [S / Enter=No]"
    $AutoReinicio = ($EntradaReinicio -match "^[sS]$")
    Write-Log "Q&A - Reinicio: AutoReinicio configurado a $AutoReinicio." -Nivel DEBUG -Silencioso

    # 5. Selección de Empresa
    Write-Log "`n> Selecciona la division de la empresa para aplicar el fondo corporativo y salvapantalla:" -Color Cyan
    Write-Log "  1. Plenergy ES (Fondo por defecto)"
    Write-Log "  2. Plenergy PT"
    Write-Log "  3. Plainco"
    $EntradaEmpresa = Read-Host "  Elige una opcion (1/2/3) [Presiona ENTER para '1']"

    if ([string]::IsNullOrWhiteSpace($EntradaEmpresa)) { $OpcionEmpresa = "1" } else { $OpcionEmpresa = $EntradaEmpresa.Trim() }

    $NombreEmpresaLog = switch ($OpcionEmpresa) {
        "2" { "Plenergy PT" }
        "3" { "Plainco" }
        Default { "Plenergy ES" }
    }
    Write-Log "Q&A - Empresa: El usuario selecciono $NombreEmpresaLog (Opcion $OpcionEmpresa)" -Nivel DEBUG -Silencioso

    # 6. Consulta para ejecutar Fase2 del tiron
    $EjecutarFase2 = Read-Host "¿Continuar con Fase 2 tras el reinicio? [S / Enter=No]"
}


# =========================================================
# BLOQUE B: Ejecucion desatendida
# =========================================================
Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Log "Iniciando automatizacion. No se requiere mas interaccion..." -Color Green
Write-Host "========================================================" -ForegroundColor Cyan

# ---------------------------------------------------------
# 2. USUARIO LOCAL (SISTEMAS)
# ---------------------------------------------------------
Write-Log "`n[2/10] Configurando cuenta de Administrador Local..." -Color Yellow
$UserName = "SISTEMAS"

if ($SysPassSecure) {
    try {
        New-LocalUser -Name $UserName -Password $SysPassSecure -PasswordNeverExpires -FullName "SISTEMAS" -Description "Cuenta de Administracion Local" -ErrorAction Stop | Out-Null
        Write-Log "  [OK] Usuario $UserName creado con exito." -Color Green
    } catch {
        Write-Log "  [X] Error al crear el usuario." -Color Red
        Write-Log "Fallo New-LocalUser: $($_.Exception.Message)" -Nivel ERROR -Silencioso
    }
} else {
    Write-Log "  -> Omitiendo creacion (El usuario $UserName ya existe o no se introdujo contrasena)." -Color DarkGray
}

if (Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue) {
    try {
        Write-Log "  -> Verificando privilegios de administrador..." -Color Gray
        $AdminGroup = (Get-LocalGroup | Where-Object SID -eq 'S-1-5-32-544').Name
        $UserGroups = Get-LocalGroupMember -Group $AdminGroup | Where-Object Name -match $UserName
        
        if (-not $UserGroups) {
            Add-LocalGroupMember -Group $AdminGroup -Member $UserName -ErrorAction Stop
            Write-Log "  [OK] Privilegios de administrador concedidos." -Color Green
        } else { 
            Write-Log "  [V] El usuario $UserName ya es Administrador." -Color Green 
        }
    } catch {
        Write-Log "  [X] Error al asignar permisos de Administrador." -Color Red
    }
}

# ---------------------------------------------------------
# 4. GESTIÓN DE MCAFEE
# ---------------------------------------------------------
Write-Log "`n[4/10] Gestionando McAfee..." -Color Yellow
if ($McAfeeReg -or $McAfeePath) {
    if ($OpcionMcAfee -eq "2") {
        Write-Log "  -> Has elegido la eliminacion manual." -Color Gray
        Write-Host "     > Por favor desinstala McAfee desde el panel de control antes de continuar." -ForegroundColor Yellow
        Read-Host "     > [ Presiona Enter para continuar ]"
        Start-Sleep -Seconds 10
    } elseif ($OpcionMcAfee -eq "1") {
        $MCPR_Url = "https://download.mcafee.com/molbin/iss-loc/SupportTools/MCPR/MCPR.exe"
        $MCPR_Destino = "$env:TEMP\MCPR.exe"
        
        Write-Log "  -> Descargando la ultima version de MCPR directamente desde McAfee..." -Color Gray
        try {
            Invoke-WebRequest -Uri $MCPR_Url -OutFile $MCPR_Destino -UseBasicParsing -ErrorAction Stop
            Write-Log "     [V] Descarga completada. Lanzando asistente de eliminacion..." -Color Cyan
            Start-Process -FilePath $MCPR_Destino
            Write-Log "  -> [ACCION REQUERIDA] Completa el Captcha en la ventana de McAfee y dale a 'Next'." -Color Cyan
            
            $TimeoutCaptcha = 300 
            $Cronometro = [Diagnostics.Stopwatch]::StartNew()
            $MotorArrancado = $false

            while ($Cronometro.Elapsed.TotalSeconds -lt $TimeoutCaptcha) {
                if (Get-Process -Name "mccleanup" -ErrorAction SilentlyContinue) {
                    $MotorArrancado = $true
                    break
                }
                Start-Sleep -Seconds 2
            }
            
            if ($MotorArrancado) {
                Write-Log "  -> [OK] Captcha superado. Desinstalando antivirus de fondo..." -Color Green
                while (Get-Process -Name "mccleanup" -ErrorAction SilentlyContinue) { Start-Sleep -Seconds 5 }
                Write-Log "  -> [OK] Desinstalacion profunda terminada." -Color Green
                Get-Process -Name "MCPR", "McClnUI" -ErrorAction SilentlyContinue | Stop-Process -Force
                if (Test-Path $MCPR_Destino) { Remove-Item -Path $MCPR_Destino -Force -ErrorAction SilentlyContinue }
                $RequiereReinicio = $true
            } else {
                Write-Log "  -> [X] Tiempo agotado (5 min) esperando el Captcha. Se omite la desinstalacion." -Color Red
                Get-Process -Name "MCPR", "McClnUI" -ErrorAction SilentlyContinue | Stop-Process -Force
            }
        } catch {
            Write-Log "     [!] Error al descargar o ejecutar MCPR. Comprueba la conexion a internet." -Color Red
        }
    }
} else { 
    Write-Log "  -> [~] McAfee no detectado en este equipo. Saltando este paso..." -Color DarkYellow 
}

# ---------------------------------------------------------
# 5. LIMPIEZA PROFUNDA
# ---------------------------------------------------------
Write-Log "`n[5/10] Optimizando y limpiando sistema operativo..." -Color Yellow

# Matar procesos[cite: 1]
$Processes = @("OneDrive", "PowerAutomate", "Xbox", "QuickAssist", "GamingApp")
foreach ($Proc in $Processes) { Get-Process -Name "*$Proc*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
Write-Log "  -> [OK] Procesos detenidos." -Color Green

# Limpieza UWP[cite: 1]
$AppList = "*Experience*", "*FeedbackHub*", "*BingWeather*", "*Family*", "*Journal*", "*BingSearch*", "*Clipchamp*", "*Todos*", "*Whiteboard*", "*MixedReality*", "*StickyNotes*", "*BingNews*", "*PowerAutomate*", "*Solitaire*", "*QuickAssist*", "*GamingApp*", "*Lenovo*", "*XboxApp*", "*XboxGamingOverlay*", "*XboxSpeechToTextOverlay*"
Write-Log "   --- Limpiando perfiles de usuario y UWP base ---" -Color Cyan
foreach ($App in $AppList) {
    Get-AppxPackage -AllUsers -Name $App -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch "StartMenu|ShellExperience|CloudExperience|PeopleExperience|Vantage" } | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $App -and $_.DisplayName -notmatch "Vantage" } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
}
Write-Log "  -> [OK] Aplicaciones UWP procesadas." -Color Green

# Limpieza Lenovo[cite: 1]
$AppsLenovo = Get-ItemProperty $RegistryPaths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match "Lenovo" -and $_.DisplayName -notmatch "Vantage" }
if ($AppsLenovo) {
    foreach ($App in $AppsLenovo) {
        $UninstallString = if ($App.QuietUninstallString) { $App.QuietUninstallString } else { $App.UninstallString }
        if ($UninstallString) {
            try {
                if ($UninstallString -match "msiexec") {
                    $UninstallString = $UninstallString -replace "/I", "/X" -replace "/i", "/x"
                    if ($UninstallString -notmatch "/qn|/quiet") { $UninstallString += " /qn /norestart" }
                } else { if ($UninstallString -notmatch "/S|/silent|/quiet") { $UninstallString += " /S" } }
                Start-Process "cmd.exe" -ArgumentList "/c $UninstallString" -Wait -WindowStyle Hidden -ErrorAction Stop
            } catch { }
        }
    }
    Write-Log "  -> [OK] Limpieza de Lenovo finalizada." -Color Green
}

# OneDrive[cite: 1]
taskkill /f /im OneDrive.exe /t /fi "status eq running" 2>$null | Out-Null
try {
    if (Test-Path "$env:SystemRoot\System32\OneDriveSetup.exe") { Start-Process "$env:SystemRoot\System32\OneDriveSetup.exe" -ArgumentList "/uninstall" -Wait -WindowStyle Hidden -ErrorAction Stop }
    if (Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") { Start-Process "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" -ArgumentList "/uninstall" -Wait -WindowStyle Hidden -ErrorAction Stop }
    Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match "OneDrive" } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "  -> [OK] OneDrive desinstalado correctamente." -Color Green
} catch { Write-Log "  -> [!] Fallo menor al desinstalar OneDrive." -Color DarkYellow }

# ---------------------------------------------------------
# 6. INSTALACIÓN DE APLICACIONES MASIVAS
# ---------------------------------------------------------
Write-Log "`n[6/10] Desplegando software corporativo..." -Color Yellow

# --- DisplayLink ---
if (Test-Path "C:\Program Files*\DisplayLink Core Software") {
    Write-Log "  [~] DisplayLink ya esta instalado. Omitiendo..." -Color DarkYellow
} else {
    $DisplayLinkPath = "$CarpetaSoftware\DisplayLink.exe"
    if (Test-Path $DisplayLinkPath) {
        try {
            Start-Process -FilePath $DisplayLinkPath -ArgumentList "-silent" -Wait -NoNewWindow -ErrorAction Stop
            Write-Log "  [OK] DisplayLink instalado." -Color Green
        } catch { Write-Log "  [X] Error al instalar DisplayLink." -Color Red }
    } else { Write-Log "  [!] Instalador de DisplayLink no encontrado en $CarpetaSoftware." -Color Red }
}

# --- PDF24 ---
if (Test-Path "C:\Program Files*\PDF24\pdf24-Creator.exe") {
    Write-Log "  [~] PDF24 ya esta instalado. Omitiendo..." -Color DarkYellow
} else {
    $PDFPath = "$CarpetaSoftware\pdf24-creator.msi"
    if (Test-Path $PDFPath) {
        try {
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$PDFPath`" AUTOUPDATE=Yes DESKTOPICONS=Yes /qn /norestart" -Wait -NoNewWindow -ErrorAction Stop
            Get-ChildItem -Path "C:\Users\Public\Desktop\*.lnk" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "PDF24" -and $_.Name -notmatch "Toolbox" } | Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Log "  [OK] PDF24 instalado (Solo icono Toolbox)." -Color Green
        } catch { Write-Log "  [X] Error al instalar PDF24." -Color Red }
    } else { Write-Log "  [!] Instalador de PDF24 no encontrado en $CarpetaSoftware." -Color Red }
}

# --- KeePass ---
if (Test-Path "C:\Program Files*\KeePass Password Safe 2\KeePass.exe") {
    Write-Log "  [~] KeePass ya esta instalado. Omitiendo..." -Color DarkYellow
} else {
    $KeePassPath = "$CarpetaSoftware\KeePass-Setup.exe"
    if (Test-Path $KeePassPath) {
        try {
            Start-Process -FilePath $KeePassPath -ArgumentList "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART" -Wait -NoNewWindow -ErrorAction Stop
            Write-Log "  [OK] KeePass instalado." -Color Green
        } catch { Write-Log "  [X] Error al instalar KeePass." -Color Red }
    } else { Write-Log "  [!] Instalador de KeePass no encontrado en $CarpetaSoftware." -Color Red }
}

# --- FortiClient ---
if (Test-Path "C:\Program Files*\Fortinet\FortiClient\FortiClient.exe") {
    Write-Log "  [~] FortiClient ya esta instalado. Omitiendo..." -Color DarkYellow
} else {
    $InstaladorForti = "$CarpetaSoftware\FortiClientVPN.msi"
    if (Test-Path $InstaladorForti) {
        try {
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$InstaladorForti`" ALLUSERS=1 /qn /norestart" -Wait -NoNewWindow -ErrorAction Stop
            Write-Log "  [OK] FortiClient desplegado." -Color Green
        } catch { Write-Log "  [X] Error al instalar FortiClient." -Color Red }
    } else { Write-Log "  [!] Instalador de FortiClient no encontrado en $CarpetaSoftware." -Color Red }
}

# --- Winget[cite: 1]---
Write-Log "`n   --- Desplegando paquetes mediante Winget ---" -Color Cyan
$PaquetesWinget = @(
    @{ Id = "Google.Chrome"; Nombre = "Google Chrome" },
    @{ Id = "Mozilla.Firefox"; Nombre = "Mozilla Firefox" },
    @{ Id = "7zip.7zip"; Nombre = "7-Zip" },
    @{ Id = "Adobe.Acrobat.Reader.64-bit"; Nombre = "Adobe Acrobat Reader" },
    @{ Id = "VideoLAN.VLC"; Nombre = "VLC Media Player" },
    @{ Id = "Microsoft.Teams"; Nombre = "Microsoft Teams" },
    @{ Id = "Lenovo.Vantage"; Nombre = "Lenovo Vantage" },
    @{ Id = "WhatsApp.WhatsApp"; Nombre = "WhatsApp" }
)

foreach ($Paquete in $PaquetesWinget) {
    $ArgsWinget = "install --id $($Paquete.Id) --exact --silent --accept-source-agreements --accept-package-agreements --scope machine"
    try {
        $Proc = Start-Process -FilePath "winget" -ArgumentList $ArgsWinget -Wait -NoNewWindow -PassThru -ErrorAction Stop
        if ($Proc.ExitCode -eq 0) { Write-Log "  [OK] $($Paquete.Nombre) instalado correctamente." -Color Green }
        elseif ($Proc.ExitCode -eq -1978335189) { Write-Log "  [~] $($Paquete.Nombre) ya estaba instalado." -Color DarkYellow }
        else { Write-Log "  [X] Hubo un problema al procesar $($Paquete.Nombre)." -Color Red }
    } catch { Write-Log "  [X] Error critico con Winget para $($Paquete.Nombre)." -Color Red }
}

# ---------------------------------------------------------
# 7. PERSONALIZACIÓN E IMPRESORAS
# ---------------------------------------------------------
Write-Log "`n[7/10] Copiando Impresoras y Fondos..." -Color Yellow

# --- Drivers de Impresoras (A su ubicación permanente) ---
$OrigenImpresoras = "$CarpetaRecursos\Impresoras"
$DestinoImpresoras = "C:\IMPRESORAS"

if (Test-Path $OrigenImpresoras) { 
    Write-Log "   -> Volcando contenido de drivers a la raiz..." -Color Gray
    try {
        Copy-Item -Path "$OrigenImpresoras\*" -Destination "C:\" -Recurse -Force -ErrorAction Stop
        Write-Log "   [OK] Drivers guardados permanentemente en $DestinoImpresoras." -Color Green
    } catch { Write-Log "   [X] Error al copiar la carpeta de impresoras." -Color Red }
} else { Write-Log "   [!] Carpeta de impresoras no encontrada en Recursos. Omitiendo..." -Color DarkYellow }

# --- Fondos Corporativos (A su ubicación permanente) ---
$OrigenFondos = "$CarpetaRecursos\Fondos"
$DestinoFondos = "C:\BC FONDOS"

if (Test-Path $OrigenFondos) { 
    Write-Log "   -> Volcando repositorio de fondos a la raiz..." -Color Gray
    try {
        Copy-Item -Path "$OrigenFondos\*" -Destination "C:\" -Recurse -Force -ErrorAction Stop
        Write-Log "   [OK] Fondos guardados permanentemente en $DestinoFondos." -Color Green
    } catch { Write-Log "   [X] Error al copiar la carpeta de fondos." -Color Red }
} else { Write-Log "   [!] Carpeta de fondos no encontrada en Recursos. Omitiendo..." -Color DarkYellow }

# --- Asignacion de Rutas segun Empresa ---
$RutaFondoBloqueo = switch ($OpcionEmpresa) {
    "2" { "$DestinoFondos\BC PLENERGY PT\BLOQUEO\FONDO BLOQUEO 1920x1080.png" }
    "3" { "$DestinoFondos\FONDOS PLAINCO\FONDO PANTALLA 1920x1080.png" }
    Default { "$DestinoFondos\BC PLENERGY\BLOQUEO\FONDO BLOQUEO 1920x1080.png" }
}

$RutaSalvapantallasOrigen = switch ($OpcionEmpresa) {
    "2" { "$DestinoFondos\BC PLENERGY PT\FONDOS Y SALVAPANTALLAS" }
    "3" { $null } 
    Default { "$DestinoFondos\BC PLENERGY\FONDOS Y SALVAPANTALLAS" }
}

# 1. APLICAR PANTALLA DE BLOQUEO
Write-Log "`n[+] Configurando Pantalla de Bloqueo Corporativa..." -Color Yellow
$RegPolPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
$RegCspPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"

if (Test-Path $RutaFondoBloqueo) {
    try {
        if (-not (Test-Path $RegPolPath)) { New-Item -Path $RegPolPath -Force | Out-Null }
        if (-not (Test-Path $RegCspPath)) { New-Item -Path $RegCspPath -Force | Out-Null }

        Set-ItemProperty -Path $RegPolPath -Name "LockScreenImage" -Value $RutaFondoBloqueo -Type String -Force
        Set-ItemProperty -Path $RegPolPath -Name "NoChangingLockScreen" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $RegCspPath -Name "LockScreenImageStatus" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $RegCspPath -Name "LockScreenImagePath" -Value $RutaFondoBloqueo -Type String -Force
        Set-ItemProperty -Path $RegCspPath -Name "LockScreenImageUrl" -Value $RutaFondoBloqueo -Type String -Force

        Write-Log "   [OK] Pantalla de bloqueo aplicada y asegurada." -Color Green
    } catch { Write-Log "   [X] Error al inyectar directivas de bloqueo." -Color Red }
} else { 
    Write-Log "   [!] Imagen no encontrada. Liberando directivas de bloqueo (Anti-Pantalla Negra)..." -Color DarkYellow 
    Remove-ItemProperty -Path $RegPolPath -Name "LockScreenImage" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $RegPolPath -Name "NoChangingLockScreen" -ErrorAction SilentlyContinue
    Remove-Item -Path $RegCspPath -Force -Recurse -ErrorAction SilentlyContinue
}

# 2. APLICAR SALVAPANTALLAS
Write-Log "`n[+] Configurando Salvapantallas (Slideshow)..." -Color Yellow
if ($null -ne $RutaSalvapantallasOrigen) {
    if (Test-Path $RutaSalvapantallasOrigen) {
        $RutaDefaultFotos = "C:\Users\Default\Pictures\Salvapantallas"
        if (-not (Test-Path $RutaDefaultFotos)) { New-Item -ItemType Directory -Path $RutaDefaultFotos -Force | Out-Null }
        
        Remove-Item -Path "$RutaDefaultFotos\*" -Force -Recurse -ErrorAction SilentlyContinue
        Copy-Item -Path "$RutaSalvapantallasOrigen\*" -Destination $RutaDefaultFotos -Force -Recurse
        
        try {
            reg load "HKU\PerfilBase" "C:\Users\Default\NTUSER.DAT" | Out-Null
            $RutaRegDefault = "Registry::HKU\PerfilBase\Control Panel\Desktop"
            Set-ItemProperty -Path $RutaRegDefault -Name "ScreenSaveActive" -Value "1" -Force
            Set-ItemProperty -Path $RutaRegDefault -Name "ScreenSaveTimeOut" -Value "180" -Force
            Set-ItemProperty -Path $RutaRegDefault -Name "SCRNSAVE.EXE" -Value "C:\Windows\System32\PhotoScreensaver.scr" -Force
            Set-ItemProperty -Path $RutaRegDefault -Name "ScreenSaverIsSecure" -Value "1" -Force 
            reg unload "HKU\PerfilBase" | Out-Null
            Write-Log "   [OK] Salvapantallas programado exitosamente." -Color Green
        } catch {
            Write-Log "   [X] Error al configurar el salvapantallas." -Color Red
            reg unload "HKU\PerfilBase" 2>$null | Out-Null
        }
    } else { Write-Log "   [!] Carpeta de salvapantallas no encontrada en $RutaSalvapantallasOrigen." -Color DarkYellow }
} else { Write-Log "   -> La division seleccionada no utiliza salvapantallas." -Color DarkGray }


# ---------------------------------------------------------
# 8. IDENTIDAD (RENOMBRADO LOCAL)[cite: 1]
# ---------------------------------------------------------
Write-Log "`n[8/10] Gestionando Identidad Local del Equipo..." -Color Yellow
$RequiereReinicio = $false

if ($NuevoNombre -and ($env:COMPUTERNAME -ne $NuevoNombre)) {
    try {
        Write-Log "  -> Cambiando nombre del equipo a $NuevoNombre..." -Color Gray
        $ParametrosNombre = @{ NewName = $NuevoNombre; Force = $true; PassThru = $true; ErrorAction = 'Stop' }
        $ResultadoNombre = Rename-Computer @ParametrosNombre
        
        if ($ResultadoNombre) {
            Write-Log "     [OK] Nombre cambiado correctamente a $NuevoNombre." -Color Green
            Write-Log "     [!] REINICIO OBLIGATORIO para aplicar." -Color Yellow
            $RequiereReinicio = $true
        }
    } catch { Write-Log "     [X] Error al cambiar el nombre del equipo." -Color Red }
} elseif ($NuevoNombre -and ($env:COMPUTERNAME -eq $NuevoNombre)) {
    Write-Log "  -> El equipo ya tiene el nombre solicitado ($NuevoNombre). Omitiendo." -Color Green
} else { Write-Log "  -> No se solicito cambio de nombre en esta fase." -Color DarkYellow }

# ---------------------------------------------------------
# 9. WINDOWS UPDATE (SISTEMA + DRIVERS LENOVO)
# ---------------------------------------------------------
Write-Log "`n[+] Instalando actualizaciones de Windows y Drivers..." -Color Yellow
try {
    Write-Log "   -> Cargando modulo PSWindowsUpdate..." -Color Cyan
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction SilentlyContinue | Out-Null
    Install-Module -Name PSWindowsUpdate -Force -AllowClobber -ErrorAction SilentlyContinue | Out-Null
    Import-Module PSWindowsUpdate -ErrorAction Stop
    Add-WUServiceManager -ServiceID "7971f918-a847-4430-9279-4a52d1efe18d" -AddServiceFlag 7 -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    
    $RutaLogUpdates = "$CarpetaLogs\Updates_$($env:COMPUTERNAME).log"
    $SensorBateria = Get-WmiObject -Class BatteryStatus -Namespace root\wmi -ErrorAction SilentlyContinue
    
    if ($SensorBateria -and $SensorBateria.PowerOnline -eq $true) {
        Write-Log "   [OK] Cargador conectado. Descargando TODO (Parches, BIOS y Drivers)..." -Color Green
        $ResultadoUpdates = Get-WindowsUpdate -Install -AcceptAll -IgnoreReboot
        $RequiereReinicio = $true
    } else {
        Write-Log "   [!] Equipo usando bateria. Excluyendo BIOS y Drivers por seguridad." -Color DarkYellow
        $ResultadoUpdates = Get-WindowsUpdate -Install -AcceptAll -IgnoreReboot -NotCategory "Drivers","Upgrades"
    }

    if ($ResultadoUpdates) {
        $ResultadoUpdates | Out-File $RutaLogUpdates -Force
        Write-Log "   [OK] Actualizaciones instaladas y log guardado." -Color Green
    } else { Write-Log "   [~] No se encontraron actualizaciones." -Color DarkYellow }
} catch { Write-Log "   [X] Error al procesar Windows Update." -Color Red }


# ---------------------------------------------------------
# 9.5. PREPARACION DE FASE 2 (AUTOLOGON Y RUNONCE)
# ---------------------------------------------------------
if ($EjecutarFase2 -match "^[sS]$") {
    Write-Log "`n[+] Construyendo puente hacia Fase 2..." -Color Yellow

    $UsuarioAdmin = "HP" 
    $PassTemp = "Temporal123!" # Contraseña temporal, se pedira el cambio al finalizar Fase2.ps1

    # 1. Seguro Anti-Bloqueo: Forzar contraseña conocida
    try {
        net user $UsuarioAdmin $PassTemp | Out-Null
        Write-Log "  [OK] Contrasena de $UsuarioAdmin forzada a '$PassTemp' para evitar bloqueos." -Color Green
    } catch {
        Write-Log "  [X] Error al resetear la contrasena. El AutoLogon podria fallar." -Color Red
    }

    # 2. Inyeccion de AutoLogon
    try {
        $WinlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        Set-ItemProperty -Path $WinlogonPath -Name "AutoAdminLogon" -Value "1" -Type String -Force
        Set-ItemProperty -Path $WinlogonPath -Name "DefaultUserName" -Value $UsuarioAdmin -Type String -Force
        Set-ItemProperty -Path $WinlogonPath -Name "DefaultPassword" -Value $PassTemp -Type String -Force
        # Limita el autologon a 1 sola vez para que no se quede en bucle infinito en el futuro
        Set-ItemProperty -Path $WinlogonPath -Name "AutoLogonCount" -Value 1 -Type DWord -Force
        Write-Log "  [OK] Inicio de sesion automatico configurado." -Color Green
    } catch {
        Write-Log "  [X] Fallo al escribir las claves de Winlogon." -Color Red
    }

    # 3. Lanzador de Arranque (RunOnce)
    try {
        $RunOncePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
        # Llamamos a PowerShell saltando las restricciones y maximizando la ventana
        $ComandoFase2 = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Maximized -File `"C:\Deploy_Plenergy\Scripts\Fase2.ps1`""
        Set-ItemProperty -Path $RunOncePath -Name "DespliegueFase2" -Value $ComandoFase2 -Type String -Force
        Write-Log "  [OK] Fase 2 programada en RunOnce exitosamente." -Color Green
        
        # Como vamos a Fase 2, el reinicio de Fase 1 se vuelve obligatorio
        $AutoReinicio = $true 
    } catch {
        Write-Log "  [X] Fallo al programar el RunOnce." -Color Red
    }
} else {
    Write-Log "`n[-] Puente a Fase 2 omitido (El usuario marco 'N')." -Color DarkGray
}

# ---------------------------------------------------------
# 10. FINALIZACIÓN Y REINICIO
# ---------------------------------------------------------
Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Log "Fin de maquetado de equipo Fase 1" -Color Green
Write-Host "========================================================" -ForegroundColor Cyan

$wshell = New-Object -ComObject Wscript.Shell

if ($AutoReinicio) {
    Write-Log "`n[!] Lanzando aviso de reinicio automatico (60s)..." -Color Yellow
    # 1 (Aceptar/Cancelar) + 48 (Alerta) + 4096 (Siempre visible)
    $BotonPulsado = $wshell.Popup("El despliegue ha finalizado.`n`nEl equipo se reiniciara en 1 minuto.`n`n[Aceptar] = Reiniciar AHORA`n[Cancelar] = NO reiniciar", 60, "Reinicio Automatico", 1 + 48 + 4096)
    
    if ($BotonPulsado -eq 2) {
        Write-Log "  -> [V] Reinicio CANCELADO. Hazlo manualmente." -Color DarkGray
    } else {
        Write-Log "  -> Procediendo con el reinicio..." -Color Red
        Restart-Computer -Force
    }
} else {
    if ($RequiereReinicio) {
        Write-Log "`n[!] Solicitando confirmacion de reinicio requerido..." -Color Yellow
        # 0 (Espera infinita). 4 (Si/No) + 48 (Alerta). El valor 6 significa que pulsó "Sí".
        $BotonPulsado = $wshell.Popup("El equipo NECESITA reiniciarse para aplicar los cambios.`n`n¿Deseas reiniciar AHORA?", 0, "Reinicio Requerido", 4 + 48 + 4096)
        if ($BotonPulsado -eq 6) { 
            Write-Log "  -> Procediendo con el reinicio..." -Color Red
            Restart-Computer -Force 
        } else {
            Write-Log "  -> [V] Reinicio Pospuesto. Hazlo manualmente." -Color DarkGray
        }
    } else {
        Write-Log "Revisa Windows Update antes de continuar." -Color Yellow
        # 4 (Si/No) + 64 (Informacion)
        $BotonPulsado = $wshell.Popup("Despliegue finalizado sin reinicio obligatorio.`nRevisa Windows Update.`n`n¿Deseas reiniciar por si acaso?", 0, "Reinicio Opcional", 4 + 64 + 4096)
        if ($BotonPulsado -eq 6) { 
            Write-Log "  -> Procediendo con el reinicio..." -Color Red
            Restart-Computer -Force 
        } else {
            Write-Log "  -> [V] Reinicio Omitido." -Color DarkGray
        }
    }
}