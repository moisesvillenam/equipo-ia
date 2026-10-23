# Instalación por usuario; no necesita elevar la aplicación ni modifica perfiles.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
$source = Split-Path $PSScriptRoot -Parent
$destination = Join-Path $env:LOCALAPPDATA 'Programs\EquipoIA'
$answer = [Windows.Forms.MessageBox]::Show("Se copiará Equipo IA a:`r`n$destination`r`n`r`nSe creará un acceso directo en el escritorio. Ubuntu y los agentes se configuran después desde la aplicación. ¿Instalar?", 'Instalar Equipo IA', 'YesNo', 'Question')
if ($answer -ne 'Yes') { exit 0 }
if ([IO.Path]::GetFullPath($source).TrimEnd('\') -eq [IO.Path]::GetFullPath($destination).TrimEnd('\')) {
    [void][Windows.Forms.MessageBox]::Show('La aplicación ya está en la carpeta de instalación.', 'Equipo IA')
    exit 0
}
[void][IO.Directory]::CreateDirectory($destination)
$entries = @('windows', 'desktop', 'bin', 'examples', 'config', 'docs', 'equipo-ia.sh', 'equipo-pruebas.sh', 'equipo-publicar.sh', 'install.sh', 'demo.sh', 'README.md', 'LICENSE', 'NOTICE')
foreach ($entry in $entries) {
    $item = Join-Path $source $entry
    if (Test-Path -LiteralPath $item) {
        if ((Get-Item -LiteralPath $item).PSIsContainer) {
            $target = Join-Path $destination $entry
            [void][IO.Directory]::CreateDirectory($target)
            Get-ChildItem -LiteralPath $item -Force | Copy-Item -Destination $target -Recurse -Force
        } else { Copy-Item -LiteralPath $item -Destination $destination -Force }
    }
}
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Equipo IA.lnk'))
$shortcut.TargetPath = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$scriptPath = Join-Path $destination 'windows\EquipoIA.ps1'
$shortcut.Arguments = '-NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "' + $scriptPath + '"'
$shortcut.WorkingDirectory = $destination
$shortcut.Description = 'Equipo IA: preparar y revisar cambios en tus proyectos'
$shortcut.Save()
[void][Windows.Forms.MessageBox]::Show('Instalado. Abre Equipo IA desde el escritorio y sigue Preparación.', 'Equipo IA')
