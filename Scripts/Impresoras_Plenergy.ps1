[console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " MODULO DE IMPRESORAS CORPORATIVAS (PLENERGY)" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Cyan

# 1. Definicion de Impresoras con sus ips
$Impresoras = @(
    @{ Nombre = "XEROX SUR"; IP = "192.168.1.8" },
    @{ Nombre = "XEROX NORTE"; IP = "192.168.1.7" },
    @{ Nombre = "XEROX PLANTA 1"; IP = "172.27.206.10" },
    @{ Nombre = "XEROX RRHH"; IP = "172.27.206.8" }
)

# 2. Rutas del driver base de Xerox (Corregido)
$CarpetaDriversLocal = "C:\IMPRESORAS\AltaLink_C8030-C8070_5.639.3.0_PS_x64"
$RutaINF = "$CarpetaDriversLocal\AltaLink_C8030-C8070_5.639.3.0_PS_x64_Driver.inf"
$NombreBaseDriver = "Xerox AltaLink C8030 PS" 

# 3. Validacion de pre-requisitos locales[cite: 3]
Write-Host "`n[+] Verificando pre-requisitos de instalacion..." -ForegroundColor Yellow

if (Test-Path $CarpetaDriversLocal) {
    Write-Host "  [V] OK: Carpeta de drivers localizada en el disco local." -ForegroundColor Green
} else {
    Write-Host "  [X] ERROR FATAL: No se encuentra la carpeta de drivers." -ForegroundColor Red
    Write-Host "      Ruta buscada: $CarpetaDriversLocal" -ForegroundColor DarkGray
    Write-Host "      Asegurate de haber ejecutado la Fase 1 o de tener la carpeta copiada." -ForegroundColor Yellow
    
    Read-Host "`n  > Pulsa ENTER para volver al menu principal..."
    return 
}

# =========================================================
# 4. LOGICA DE SELECCION (HIBRIDA AUTONOMA / MANUAL)
# =========================================================
$ImpresorasAInstalar = @()

# Si detecta variables globales del JSON, asume el control silencioso
if ($global:Auto_ImpresorasTodas -eq $true) {
    Write-Host "`n  [+] Despliegue Autonomo: Instalando TODAS las impresoras por directiva JSON." -ForegroundColor Magenta
    $ImpresorasAInstalar = $Impresoras
} elseif ($null -ne $global:Auto_ImpresorasIds -and $global:Auto_ImpresorasIds.Count -gt 0) {
    Write-Host "`n  [+] Despliegue Autonomo: Instalando impresoras especificas ($($global:Auto_ImpresorasIds -join ', '))." -ForegroundColor Magenta
    foreach ($Num in $global:Auto_ImpresorasIds) {
        $IndiceReal = [int]$Num - 1
        if ($IndiceReal -ge 0 -and $IndiceReal -lt $Impresoras.Count) {
            $ImpresorasAInstalar += $Impresoras[$IndiceReal]
        }
    }
} else {
    # MODO MANUAL: Si no hay JSON, muestra el menu interactivo
    Write-Host "`nImpresoras disponibles:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $Impresoras.Count; $i++) {
        Write-Host "  [$($i + 1)] $($Impresoras[$i].Nombre) (IP: $($Impresoras[$i].IP))"
    }

    Write-Host "`nOpciones de seleccion:" -ForegroundColor Gray
    Write-Host " - Escribe 'T' para instalarlas TODAS."
    Write-Host " - Escribe numeros separados por comas (Ej: 1,3)."
    Write-Host " - Pulsa ENTER vacio para OMITIR la instalacion."

    $Seleccion = Read-Host "`n> Tu seleccion"

    if ([string]::IsNullOrWhiteSpace($Seleccion)) {
        Write-Host "  -> Omitiendo instalacion de impresoras." -ForegroundColor DarkGray
        return 
    }

    if ($Seleccion -match "^[tT]$") {
        $ImpresorasAInstalar = $Impresoras
    } else {
        $Indices = $Seleccion -split ","
        foreach ($Num in $Indices) {
            $IndiceReal = [int]$Num.Trim() - 1
            if ($IndiceReal -ge 0 -and $IndiceReal -lt $Impresoras.Count) {
                $ImpresorasAInstalar += $Impresoras[$IndiceReal]
            }
        }
    }
}

if ($ImpresorasAInstalar.Count -eq 0) {
    Write-Host "  [X] Seleccion no valida. Cancelando impresoras." -ForegroundColor Red
    return
}

# 6. Inyeccion del Driver Base en Windows[cite: 3]
if (Test-Path $RutaINF) {
    Write-Host "`n  -> Inyectando driver base de Xerox en el almacen de Windows..." -ForegroundColor Cyan
    Start-Process -FilePath "pnputil.exe" -ArgumentList "/add-driver `"$RutaINF`"" -Wait -NoNewWindow
    Add-PrinterDriver -Name $NombreBaseDriver -ErrorAction SilentlyContinue
} else {
    Write-Host "  [X] ERROR FATAL: No se encuentra el archivo .inf en $RutaINF" -ForegroundColor Red
    return
}

# 7. Bucle de Instalacion con comprobacion de red[cite: 3]
foreach ($Imp in $ImpresorasAInstalar) {
    Write-Host "`n[+] Procesando: $($Imp.Nombre) ($($Imp.IP))" -ForegroundColor Yellow
    Write-Host "  -> Haciendo ping a $($Imp.IP) (3 intentos)... " -NoNewline
    
    ping.exe -n 3 -w 1000 $Imp.IP | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "¡OK!" -ForegroundColor Green
        $Instalar = $true
    } else {
    Write-Host "FALLO (No responde en 3 intentos)" -ForegroundColor Red
    if ($global:Auto_ImpresorasTodas -or $global:Auto_ImpresorasIds) {
        Write-Host "     -> [Auto] Forzando instalacion de puerto sin conexion..." -ForegroundColor Magenta
        $Instalar = $true
    } else {
        $Forzar = Read-Host "  [?] El equipo no ve la impresora. Instalar puerto de todas formas? [S/N]"
        $Instalar = ($Forzar -match "^[sS]$")
    }
}
    
    if ($Instalar) {
        try {
            $NombrePuerto = "IP_$($Imp.IP)"
            $PuertoExistente = Get-PrinterPort -Name $NombrePuerto -ErrorAction SilentlyContinue
            
            if (-not $PuertoExistente) {
                Add-PrinterPort -Name $NombrePuerto -PrinterHostAddress $Imp.IP
                Write-Host "     - Puerto TCP/IP creado ($NombrePuerto)." -ForegroundColor Gray
            }
            
            Add-Printer -Name $Imp.Nombre -PortName $NombrePuerto -DriverName $NombreBaseDriver -ErrorAction Stop
            Write-Host "     [V] Impresora instalada correctamente." -ForegroundColor Green
        } catch {
            Write-Host "     [X] Fallo al instalar: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "     -> Instalacion cancelada por el operador." -ForegroundColor DarkGray
    }
}

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " FIN DEL MODULO DE IMPRESORAS" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Cyan