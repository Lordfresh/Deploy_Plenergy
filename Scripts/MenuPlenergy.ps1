[console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ---------------------------------------------------------
# 0. CONTROL DE INSTANCIA UNICA
# ---------------------------------------------------------
$createdNew = $false
$mutex = [System.Threading.Mutex]::new($true, "Global\PlenergyMaquetadorMutex", [ref]$createdNew)

if (-not $createdNew) {
    Write-Host "`n[!] ATENCION: El Maquetador de Plenergy YA esta en ejecucion en otra ventana." -ForegroundColor Red
    Write-Host "    Cerrando esta ventana duplicada en 3 segundos..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    exit
}

# ---------------------------------------------------------
# 1. ENTORNO DE DESPLIEGUE LOCAL Y LOGS
# ---------------------------------------------------------
$RutaBase       = "C:\Deploy_Plenergy"
$CarpetaScripts = "$RutaBase\Scripts"
$CarpetaLogs    = "$RutaBase\Logs"

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

$NumeroSerie = (Get-CimInstance Win32_BIOS).SerialNumber
$FechaNombre = (Get-Date).ToString("yyyy-MM-dd")

if (-not (Test-Path $CarpetaLogs)) { New-Item -Path $CarpetaLogs -ItemType Directory -Force | Out-Null }
$global:RutaArchivoLog = "$CarpetaLogs\SN-${NumeroSerie}_MenuPrincipal_${FechaNombre}.log"

Write-Log "--- SESION INICIADA: MENU PRINCIPAL ---" -Nivel INFO -Silencioso

# ---------------------------------------------------------
# 2. CREACION DEL LANZADOR TEMPORAL EN ESCRITORIO
# ---------------------------------------------------------
$RutaLanzador = "$RutaBase\MaquetadorPlenergy.bat"
$RutaAccesoDirecto = "C:\Users\Public\Desktop\Lanzador Maquetador.lnk"

if (Test-Path $RutaLanzador) {
    if (-not (Test-Path $RutaAccesoDirecto)) {
        try {
            $WshShell = New-Object -comObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut($RutaAccesoDirecto)
            $Shortcut.TargetPath = $RutaLanzador
            $Shortcut.WorkingDirectory = $RutaBase
            $Shortcut.Description = "Lanzador Temporal Plenergy"
            $Shortcut.IconLocation = "powershell.exe, 0" 
            $Shortcut.Save()
            Write-Log "`n [!] Acceso directo temporal creado en el escritorio." -Color Cyan
        } catch {
            Write-Log "`n [X] No se pudo crear el acceso directo." -Color Red
        }
    }
}

# ========================================================================
# EXTRACCION RAPIDA DEL ID DE ANYDESK
# ========================================================================
$RutaAnyDeskExe = "C:\Program Files (x86)\AnyDesk\AnyDesk.exe"
$RutaTxtID = "$RutaBase\AnyDesk_ID.txt"
$ID_AnyDesk = "No instalado/Pendiente"

if (Test-Path $RutaAnyDeskExe) {
    $ID_Temporal = (& $RutaAnyDeskExe --get-id | ForEach-Object { $_ }) -join ""
    if (-not [string]::IsNullOrWhiteSpace($ID_Temporal)) {
        $ID_AnyDesk = $ID_Temporal.Trim()
    } elseif (Test-Path $RutaTxtID) {
        $ID_AnyDesk = (Get-Content $RutaTxtID).Trim()
    }
}

# ========================================================================
# BUCLE PARA MENU
# ========================================================================
while ($true) {
    
    Clear-Host    
    Write-Host '  ____  _       ' -NoNewline -ForegroundColor Yellow; Write-Host '                        ' -ForegroundColor DarkYellow
    Write-Host ' |  _ \| | ___ _' -NoNewline -ForegroundColor Yellow; Write-Host ' __   ___ _ __ __ _ _   _ ' -ForegroundColor DarkYellow
    Write-Host ' | |_) | |/ _ \ ' -NoNewline -ForegroundColor Yellow; Write-Host '''_ \ / _ \ ''__/ _` | | | |' -ForegroundColor DarkYellow
    Write-Host ' |  __/| |  __/ ' -NoNewline -ForegroundColor Yellow; Write-Host '| | |  __/ | | (_| | |_| |' -ForegroundColor DarkYellow
    Write-Host ' |_|   |_|\___|_' -NoNewline -ForegroundColor Yellow; Write-Host '| |_|\___|_|  \__, |\__, |' -ForegroundColor DarkYellow
    Write-Host '                ' -NoNewline -ForegroundColor Yellow; Write-Host '             |___/ |___/ ' -ForegroundColor DarkYellow
    Write-Host ""
    
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "                   BIENVENIDO AL MAQUETADOR v2.0                  " -ForegroundColor White 
    Write-Host "                     AnyDesk ID: $ID_AnyDesk                      " -ForegroundColor Green
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host " 1. Fase 1: Maquetacion y Copia de Archivos" -ForegroundColor White
    Write-Host " 2. Fase 2: Securizacion e Impresoras" -ForegroundColor White
    Write-Host " 3. Modulo: Solo Impresoras" -ForegroundColor White
    Write-Host " 4. Ejecutar script de forma personalizada (Work in progress)"  -ForegroundColor DarkGray
    Write-Host " 5. Maquetado completo autonomo (Work in progress)" -ForegroundColor DarkGray
    Write-Host " 6. Auditoria (Checklist de comprobacion del PC)" -ForegroundColor White
    Write-Host " 7. Tutoriales y Documentacion" -ForegroundColor DarkGray
    Write-Host " 0. Salir" -ForegroundColor Red
    Write-Host "==================================================================" -ForegroundColor Cyan
    
    $OpcionMenu = Read-Host "`n > Selecciona una opcion [0-7]"
    if ($OpcionMenu) { $OpcionMenu = $OpcionMenu.Trim() }

    switch ($OpcionMenu) {
       "1" {
            Clear-Host
            Write-Host "==================================================================" -ForegroundColor Cyan
            Write-Host " RESUMEN DE TAREAS: FASE 1" -ForegroundColor Green
            Write-Host "==================================================================" -ForegroundColor Cyan
            Write-Host " Esta fase ejecutara de forma automatica:" -ForegroundColor White
            Write-Host "  - Configuracion de Wi-Fi y creacion de usuario local (SISTEMAS)." -ForegroundColor Gray
            Write-Host "  - Desinstalacion de McAfee y limpieza de Windows (UWP, OneDrive)." -ForegroundColor Gray
            Write-Host "  - Despliegue de software (AnyDesk, PDF24, Chrome, KeePass, etc)." -ForegroundColor Gray
            Write-Host "  - Copia de drivers de impresoras al disco local." -ForegroundColor Gray
            Write-Host "  - Personalizacion corporativa (Fondos y salvapantallas)." -ForegroundColor Gray
            Write-Host "  - Renombrado del equipo e instalacion de Windows Update." -ForegroundColor Gray
            Write-Host "==================================================================" -ForegroundColor Cyan
            
            $Confirma = Read-Host "`n[?] Vas a lanzar la Fase 1. ¿Seguro? [S/N]"
            if ($Confirma -match "^[sS]$") {
                Clear-Host
                Write-Log ">>> INICIANDO FASE 1..." -Color Yellow
                $ScriptFase1 = "$CarpetaScripts\Fase1.ps1"
                
                if (Test-Path $ScriptFase1) { & $ScriptFase1 } 
                else { Write-Log "`n[X] ERROR: No se encontro $ScriptFase1" -Color Red }
                Read-Host "`n> Presiona ENTER para volver al menu..."
            }
        }
        
        "2" {
            Clear-Host
            Write-Host "==================================================================" -ForegroundColor Cyan
            Write-Host " RESUMEN DE TAREAS: FASE 2 (SECURIZACION)" -ForegroundColor Green
            Write-Host "==================================================================" -ForegroundColor Cyan
            Write-Host " Esta fase ejecutara de forma automatica:" -ForegroundColor White
            Write-Host "  - Integracion o renombrado en el Dominio Corporativo." -ForegroundColor Gray
            Write-Host "  - Activacion de BitLocker y guardado de claves en local." -ForegroundColor Gray
            Write-Host "  - Inyeccion de perfiles VPN (FortiClient) en el registro." -ForegroundColor Gray
            Write-Host "  - Modulo de Impresoras (Seleccion e instalacion)." -ForegroundColor Gray
            Write-Host "  - Limpieza profunda y eliminacion final de OneDrive." -ForegroundColor Gray
            Write-Host "  - Instalacion de seguridad (CrowdStrike Falcon y ESET)." -ForegroundColor Gray
            Write-Host "==================================================================" -ForegroundColor Cyan
            
            $Confirma = Read-Host "`n[?] Vas a lanzar la Fase 2 (Securizacion). ¿Seguro? [S/N]"
            if ($Confirma -match "^[sS]$") {
                Clear-Host
                Write-Log ">>> INICIANDO FASE 2..." -Color Yellow
                $ScriptFase2 = "$CarpetaScripts\Fase2.ps1"
                
                if (Test-Path $ScriptFase2) { & $ScriptFase2 } 
                else { Write-Log "`n[X] ERROR: No se encontro $ScriptFase2" -Color Red }
                Read-Host "`n> Presiona ENTER para volver al menu..."
            }
        }
        
        "3" {
            Clear-Host
            Write-Log ">>> INICIANDO MODULO DE IMPRESORAS..." -Color Cyan
            $ScriptImpresoras = "$CarpetaScripts\Impresoras_Plenergy.ps1"
            
            if (Test-Path $ScriptImpresoras) { & $ScriptImpresoras } 
            else { Write-Log "`n[X] ERROR: No se encontro $ScriptImpresoras" -Color Red }
            Read-Host "`n> Presiona ENTER para volver al menu..."
        }
        
        "4" {
            Clear-Host
            Write-Log ">>> MODO PERSONALIZADO..." -Color Yellow
            Write-Host "`n[En construccion] Aqui pondremos el selector de scripts personalizados." -ForegroundColor Gray
            Read-Host "`n> Presiona ENTER para volver al menu..."
        }
        
        "5" {
            Clear-Host
            Write-Log ">>> MAQUETADO AUTONOMO (WIP)..." -Color DarkGray
            Write-Host "`n(Work in progress) Esta opcion ejecutara todo de forma continua en el futuro." -ForegroundColor DarkGray
            Read-Host "`n> Presiona ENTER para volver al menu..."
        }
        
        "6" {
            $Confirma = Read-Host "`n[?] Vas a lanzar la Auditoria. ¿Seguro? [S/N]"
            if ($Confirma -match "^[sS]$") {
                Clear-Host
                Write-Log ">>> EJECUTANDO AUDITORIA DEL SISTEMA..." -Color Cyan
                $ScriptAuditoria = "$CarpetaScripts\Auditoria.ps1"
                
                if (Test-Path $ScriptAuditoria) { & $ScriptAuditoria } 
                else { Write-Log "`n[X] ERROR: No se encontro $ScriptAuditoria" -Color Red }
                Read-Host "`n> Presiona ENTER para volver al menu..."
            }
        }
        
        "7" {
            Clear-Host
            Write-Log ">>> ABRIENDO TUTORIALES..." -Color Cyan
            Write-Host "`n[En construccion] Aqui podras vincular tu PDF o base de conocimientos." -ForegroundColor Gray
            Read-Host "`n> Presiona ENTER para volver al menu..."
        }
        
        "0" {
            Write-Log "`n[V] Saliendo del Maquetador de Plenergy.`n" -Color Green
            Start-Sleep -Seconds 2
            
            if ($mutex) {
                $mutex.ReleaseMutex()
                $mutex.Dispose()
            }
            exit 
        }
        
        default {
            Write-Host "`n[!] Opcion no valida. Por favor, selecciona un numero del 0 al 7." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
}