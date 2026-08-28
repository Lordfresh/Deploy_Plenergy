@echo off
TITLE Lanzador Maquetador Plenergy
color 0B
echo Preparando el entorno de maquetacion...

:: Autoelevacion a Administrador y ejecucion silenciosa apuntando a la carpeta Scripts
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0Scripts\MenuPlenergy.ps1""' -Verb RunAs; exit } else { & ""%~dp0Scripts\MenuPlenergy.ps1"" }"

exit