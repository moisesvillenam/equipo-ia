@echo off
setlocal
title Instalar Equipo IA
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Instalar.ps1"
if errorlevel 1 pause
