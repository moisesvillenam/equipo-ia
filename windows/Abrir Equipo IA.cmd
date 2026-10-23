@echo off
setlocal
title Equipo IA
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0EquipoIA.ps1"
if errorlevel 1 (
  echo.
  echo No se pudo abrir Equipo IA. Conserva este mensaje para pedir ayuda.
  pause
)
