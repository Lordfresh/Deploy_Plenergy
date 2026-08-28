@echo off
TITLE Preparacion Zero Touch Plenergy

echo [1] Iniciando script de PPKG... > C:\Log_PPKG.txt
echo [i] Directorio de trabajo del PPKG: %~dp0 >> C:\Log_PPKG.txt

echo [2] Extrayendo archivos de maquetacion... >> C:\Log_PPKG.txt
powershell.exe -ExecutionPolicy Bypass -Command "Expand-Archive -Path '%~dp0Deploy_Plenergy.zip' -DestinationPath 'C:\' -Force" >> C:\Log_PPKG.txt 2>&1

echo [3] Instalando AnyDesk... >> C:\Log_PPKG.txt
"%~dp0AnyDesk.exe" --install "C:\Program Files (x86)\AnyDesk" --start-with-win --silent >> C:\Log_PPKG.txt 2>&1
echo [4] Configurando Registro AutoLogon... >> C:\Log_PPKG.txt
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_SZ /d 1 /f >> C:\Log_PPKG.txt 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName /t REG_SZ /d "HP" /f >> C:\Log_PPKG.txt 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /t REG_SZ /d "FineAdmin2022" /f >> C:\Log_PPKG.txt 2>&1

echo [5] Suprimiendo pantallas de privacidad (Telemetria, Lapiz, etc)... >> C:\Log_PPKG.txt
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OOBE" /v DisablePrivacyExperience /t REG_DWORD /d 1 /f >> C:\Log_PPKG.txt 2>&1

echo [6] Configurando RunOnce para arrancar el menu... >> C:\Log_PPKG.txt
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v "LanzadorPlenergy" /t REG_SZ /d "C:\Deploy_Plenergy\MaquetadorPlenergy.bat" /f >> C:\Log_PPKG.txt 2>&1

echo [7] Fin de la preparacion. >> C:\Log_PPKG.txt
exit