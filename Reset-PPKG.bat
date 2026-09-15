@echo off
TITLE Purgar PPKG - Plenergy

:: --- SOLICITAR PERMISOS DE ADMINISTRADOR AUTOMATICAMENTE ---
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Solicitando privilegios de Administrador...
    powershell.exe -ExecutionPolicy Bypass -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)
:: -----------------------------------------------------------

echo =======================================================
echo   ELIMINANDO PAQUETES DE APROVISIONAMIENTO ANTERIORES
echo =======================================================
echo.
echo Buscando paquetes en el registro de Windows...

:: 1. Crear script PowerShell temporal en la carpeta TEMP
echo $Nombres = @('Postformateo', 'PostformateoAutonomo', 'FormateoSinBloatware') > "%TEMP%\PurgaPPKG.ps1"
echo $Paquetes = Get-ProvisioningPackage -ErrorAction SilentlyContinue >> "%TEMP%\PurgaPPKG.ps1"
echo foreach ($Pkg in $Paquetes) { >> "%TEMP%\PurgaPPKG.ps1"
echo     foreach ($Nombre in $Nombres) { >> "%TEMP%\PurgaPPKG.ps1"
echo         if ($Pkg.PackageName -match $Nombre) { >> "%TEMP%\PurgaPPKG.ps1"
echo             Write-Host "[X] Destruyendo: $($Pkg.PackageName)" -ForegroundColor Yellow >> "%TEMP%\PurgaPPKG.ps1"
echo             $ID = $Pkg.PackageId.ToString() >> "%TEMP%\PurgaPPKG.ps1"
echo             try { >> "%TEMP%\PurgaPPKG.ps1"
echo                 Uninstall-ProvisioningPackage -PackageId $ID -ErrorAction Stop ^| Out-Null >> "%TEMP%\PurgaPPKG.ps1"
echo             } catch { >> "%TEMP%\PurgaPPKG.ps1"
echo                 Write-Host "    [!] Limpieza profunda requerida. Forzando por WMI..." -ForegroundColor DarkGray >> "%TEMP%\PurgaPPKG.ps1"
echo                 Get-WmiObject -Namespace root\cimv2\mdm\dmmap -Class MDM_ProvisioningPackage -ErrorAction SilentlyContinue ^| Where-Object { $_.PackageID -eq $ID } ^| Remove-WmiObject -ErrorAction SilentlyContinue >> "%TEMP%\PurgaPPKG.ps1"
echo             } >> "%TEMP%\PurgaPPKG.ps1"
echo         } >> "%TEMP%\PurgaPPKG.ps1"
echo     } >> "%TEMP%\PurgaPPKG.ps1"
echo } >> "%TEMP%\PurgaPPKG.ps1"

:: 2. Ejecutar el script limpiamente
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%TEMP%\PurgaPPKG.ps1"

:: 3. Borrar el rastro
del "%TEMP%\PurgaPPKG.ps1"

echo.
echo [OK] Limpieza finalizada. El equipo esta listo para el nuevo despliegue.
pause