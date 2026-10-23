# Ejecutar en Windows PowerShell 5.1. No instala WSL ni conecta cuentas.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$app = Join-Path $PSScriptRoot 'EquipoIA.ps1'
foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1') {
    $tokens = $null; $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw ($errors | Out-String) }
}
Write-Output 'Sintaxis PowerShell: correcta.'

# Cargar únicamente las dos funciones de transporte del código de la aplicación.
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($app, [ref]$tokens, [ref]$errors)
foreach ($name in @('Quote-NativeArgument', 'New-NativeProcess')) {
    $definition = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }, $true)
    . ([scriptblock]::Create($definition.Extent.Text))
}
$python = (Get-Command python.exe -ErrorAction Stop).Source
$values = @('', 'normal', 'con espacios', 'C:\carpeta con espacios\', 'comilla"dentro', 'barra\"comilla', 'español 漢字', '$(no ejecutar); & echo no', "primera`nsegunda")
$code = 'import json,sys; print(json.dumps(sys.argv[1:], ensure_ascii=False))'
$process = New-NativeProcess $python (@('-X', 'utf8', '-c', $code) + $values)
[void]$process.Start()
$outputTask = $process.StandardOutput.ReadToEndAsync()
$errorTask = $process.StandardError.ReadToEndAsync()
if (-not $process.WaitForExit(15000)) { $process.Kill(); throw 'Timeout del test de argumentos.' }
if ($process.ExitCode -ne 0) { throw $errorTask.Result }
$received = @($outputTask.Result | ConvertFrom-Json)
if ($received.Count -ne $values.Count) { throw 'Se perdieron argumentos.' }
for ($index = 0; $index -lt $values.Count; $index++) {
    if ($received[$index] -cne $values[$index]) { throw "Argumento alterado en la posición $index" }
}
$process.Dispose()
Write-Output 'Argumentos, rutas y Unicode: correctos.'

$hostExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
& $hostExe -NoProfile -STA -ExecutionPolicy Bypass -File $app -SmokeTest
if ($LASTEXITCODE -ne 0) { throw 'No se pudo construir la interfaz WinForms.' }
Write-Output 'Prueba de construcción WinForms: correcta.'
