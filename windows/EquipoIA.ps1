# Equipo IA para Windows. Interfaz local: Windows PowerShell 5.1 y WinForms.
# SPDX-License-Identifier: Apache-2.0
param([switch]$SmokeTest)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:Root = Split-Path $PSScriptRoot -Parent
$script:Operation = $null
$script:CurrentJob = $null
$script:JobId = ''
$script:LastPoll = [DateTime]::MinValue
$script:HistoryItems = @()
$script:Wsl = Join-Path $env:WINDIR 'System32\wsl.exe'
$script:Preferences = Join-Path $env:LOCALAPPDATA 'EquipoIA\preferencias.json'
$script:Accent = [Drawing.ColorTranslator]::FromHtml('#13796D')
$script:Ink = [Drawing.ColorTranslator]::FromHtml('#14283D')

# ProcessStartInfo de .NET Framework no tiene ArgumentList. Cotizar cada argumento
# con las reglas de CommandLineToArgvW, incluido el caso de barras antes de comillas.
function Quote-NativeArgument([string]$Value) {
    if ($Value -notmatch '[\s"]' -and $Value.Length -gt 0) { return $Value }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function New-NativeProcess([string]$File, [string[]]$Arguments, [switch]$Visible, [switch]$Unicode) {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $File
    $info.Arguments = (($Arguments | ForEach-Object { Quote-NativeArgument $_ }) -join ' ')
    $info.UseShellExecute = [bool]$Visible
    $info.CreateNoWindow = -not $Visible
    if (-not $Visible) {
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        $encoding = New-Object Text.UTF8Encoding($false)
        if ($Unicode) { $encoding = [Text.Encoding]::Unicode }
        $info.StandardOutputEncoding = $encoding
        $info.StandardErrorEncoding = $encoding
    }
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    return $process
}

function Notice([string]$Message) {
    [void][Windows.Forms.MessageBox]::Show($script:Form, $Message, 'Equipo IA', 'OK', 'Information')
}

function Confirm([string]$Message) {
    return [Windows.Forms.MessageBox]::Show($script:Form, $Message, 'Equipo IA', 'YesNo', 'Question', 'Button2') -eq 'Yes'
}

function Set-Busy([string]$Message) {
    $script:Footer.Text = $Message
    $script:Progress.Visible = ($null -ne $script:Operation)
}

function Selected-Distro {
    $name = $script:Distro.Text.Trim()
    if (-not $name -or $name -match '[\r\n\x00]' -or $name.StartsWith('-')) {
        throw 'Selecciona tu distribución de Ubuntu en Preparación.'
    }
    return $name
}

function Save-Preferences {
    $parent = Split-Path $script:Preferences -Parent
    [void][IO.Directory]::CreateDirectory($parent)
    $value = @{ distribution = $script:Distro.Text; project = $script:ProjectPath.Text }
    [IO.File]::WriteAllText($script:Preferences, ($value | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
}

function Begin-Process($Process, [scriptblock]$Callback, [string]$Message, [switch]$Json, [int]$Timeout = 45) {
    if ($null -ne $script:Operation) { throw 'Espera a que termine la comprobación actual.' }
    [void]$Process.Start()
    $script:Operation = @{
        Process = $Process; Output = $Process.StandardOutput.ReadToEndAsync()
        Error = $Process.StandardError.ReadToEndAsync(); Callback = $Callback
        Json = [bool]$Json; Deadline = [DateTime]::UtcNow.AddSeconds($Timeout)
    }
    Set-Busy $Message
}

function Bridge([hashtable]$Request, [scriptblock]$Callback, [string]$Message = 'Comprobando...') {
    if (-not (Test-Path -LiteralPath $script:Wsl)) { throw 'Primero instala Ubuntu con el botón de Preparación.' }
    $distroName = Selected-Distro
    $payload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($Request | ConvertTo-Json -Depth 8 -Compress)))
    $bridgePath = Join-Path $script:Root 'desktop\bridge.py'
    # El texto de tarea y las rutas son argumentos; no forman parte del programa Bash.
    $runner = 'export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"; exec python3 "$(wslpath -u "$1")" "$2"'
    $process = New-NativeProcess $script:Wsl @('--distribution', $distroName, '--exec', 'bash', '-lc', $runner, 'equipo-ia', $bridgePath, $payload)
    Begin-Process $process $Callback $Message -Json -Timeout 120
}

function Guard([scriptblock]$Action) {
    try { & $Action } catch { Set-Busy 'Revisa el aviso para continuar.'; Notice $_.Exception.Message }
}

function Setup-Action([string]$Action) {
    if ($null -ne $script:Operation) { throw 'Espera a que termine la comprobación actual.' }
    $distroName = Selected-Distro
    $setupPath = Join-Path $script:Root 'desktop\setup.sh'
    $runner = 'export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"; bash "$(wslpath -u "$1")" "$2"; result=$?; printf "\nPulsa Enter para cerrar esta ventana..."; read -r respuesta; exit "$result"'
    $arguments = @('--distribution', $distroName)
    if ($Action -eq 'base') { $arguments += @('--user', 'root') }
    $arguments += @('--exec', 'bash', '-lc', $runner, 'equipo-ia', $setupPath, $Action)
    $process = New-NativeProcess $script:Wsl $arguments -Visible
    [void]$process.Start()
    Set-Busy 'Completa la ventana de preparación. Después pulsa Comprobar.'
}

function Scan-Environment {
    Bridge @{ action = 'diagnose' } {
        param($data)
        $lines = New-Object 'Collections.Generic.List[string]'
        $lines.Add('Ubuntu respondió correctamente.')
        if ($data.user_is_root) { $lines.Add('Abre Ubuntu y crea/configura tu usuario habitual antes de conectar Codex.') }
        if ($data.ready) { $lines.Add('Motor: herramientas básicas disponibles.') }
        else { $lines.Add('Faltan herramientas: ' + ($data.missing -join ', ') + '. Pulsa Preparar herramientas.') }
        if ($data.tools.node -and $data.tools.npm) { $lines.Add('Ejemplo de práctica: Node y npm disponibles.') }
        else { $lines.Add('Para el ejemplo faltan Node/npm. Pulsa Preparar herramientas.') }
        $labels = @{ conectado = 'sesión conectada'; sin_sesion = 'instalado, falta conectar tu cuenta'; no_instalado = 'falta instalar'; no_comprobado = 'no se pudo comprobar la sesión' }
        $lines.Add('Codex: ' + $labels[$data.codex_auth] + '.')
        $lines.Add('OpenCode: ' + $(if ($data.tools.opencode) { 'instalado.' } else { 'opcional, no detectado.' }))
        $lines.Add('AGY: ' + $(if ($data.tools.agy) { 'instalado; comprueba su sesión en su herramienta.' } else { 'opcional, no detectado.' }))
        $script:EnvironmentStatus.Text = $lines -join "`r`n"
        Save-Preferences
        Set-Busy 'Comprobación terminada. Puedes continuar con tu proyecto o con el ejemplo.'
    } 'Comprobando herramientas y conexión de Codex...'
}

function Show-Project($data) {
    $script:ProjectPath.Text = $data.project
    $script:ProjectStatus.Text = "Versión: $($data.commit.Substring(0, 8))  |  Rama: $($data.branch)`r`n" + $(if ($data.clean) { 'Listo: no hay cambios pendientes.' } else { "Hay cambios pendientes que debes guardar o revisar:`r`n$($data.changes)" })
    Save-Preferences
}

function Show-Result($data) {
    $script:CurrentJob = $data
    $script:JobId = $data.id
    $labels = @{ PREPARANDO = 'Preparando tu tarea'; EN_CURSO = 'El equipo está trabajando'; VALIDADO = 'Propuesta lista para revisar'; REVISION_MANUAL = 'Hace falta una revisión humana'; RECHAZADO = 'La propuesta no superó los controles'; SIN_CAMBIOS = 'No se propusieron cambios'; ERROR = 'No se pudo completar la tarea' }
    $title = $labels[$data.status]
    if ($data.applied) { $title = 'Cambios aplicados a tu carpeta' }
    if ($data.PSObject.Properties['saved_commit']) { $title = 'Versión guardada; puedes pedir otra tarea' }
    if ($data.demo) { $title = 'EJEMPLO SIMULADO · ' + $title }
    $script:ResultTitle.Text = $title
    $reason = ''
    if ($data.PSObject.Properties['reason']) { $reason = $data.reason }
    $script:ResultSummary.Text = "$reason`r`nProyecto: $($data.project)`r`nArchivos: $($data.files -join ', ')"
    if ($data.tests.PSObject.Properties['current_tests']) {
        $script:ResultSummary.Text += "`r`nAntes: $($data.tests.baseline_tests)  |  Propuesta: $($data.tests.current_tests)  |  Control: $($data.tests.control_tests)"
    }
    $script:Patch.Text = $data.patch.Replace("`n", "`r`n")
    $script:Review.Text = $data.review.Replace("`n", "`r`n")
    $script:Acta.Text = $data.acta.Replace("`n", "`r`n")
    $script:Log.Text = $data.log.Replace("`n", "`r`n")
    $script:ApplyButton.Enabled = [bool]$data.can_apply
    $script:SaveButton.Enabled = $data.applied -and -not $data.PSObject.Properties['saved_commit']
    if ($data.status -notin @('PREPARANDO', 'EN_CURSO')) { Set-Busy 'Resultado disponible. Revisa los cambios y el informe antes de decidir.' }
    else { Set-Busy 'El equipo trabaja en una copia. Puedes consultar el registro mientras termina.' }
}

function Poll-Result {
    if ($script:JobId) {
        Bridge @{ action = 'status'; id = $script:JobId } { param($data) Show-Result $data } 'Consultando el resultado...'
    }
}

function Start-Task([bool]$Demo) {
    if ($null -ne $script:Operation) { throw 'Espera a que termine la comprobación actual.' }
    if (-not $script:ProjectPath.Text.Trim()) { throw 'Selecciona un proyecto o crea el ejemplo de práctica.' }
    if ($script:Task.Text.Trim().Length -lt 3) { throw 'Escribe qué quieres mejorar.' }
    if (-not $Demo) {
        if (-not (Confirm 'Se ejecutarán agentes con tus cuentas y las pruebas de este proyecto. Puede consumir uso de tu servicio de IA. Los cambios se preparan en una copia y requieren tu aprobación para aplicarlos. ¿Iniciar la tarea?')) { return }
    }
    $programmer = @('codex', 'opencode')[$script:Programmer.SelectedIndex]
    $reviewer = @('codex', 'agy')[$script:Reviewer.SelectedIndex]
    $request = @{ action = 'start'; project = $script:ProjectPath.Text; task = $script:Task.Text; programmer = $programmer; reviewer = $reviewer; demo = $Demo; npm_ci = $script:NpmCi.Checked }
    Bridge $request {
        param($data)
        $script:JobId = $data.id
        $script:CurrentJob = $null
        $script:ApplyButton.Enabled = $false
        $script:SaveButton.Enabled = $false
        $script:Patch.Clear(); $script:Review.Clear(); $script:Acta.Clear(); $script:Log.Clear()
        $script:ResultTitle.Text = 'Preparando tu tarea...'
        $script:ResultSummary.Text = 'Los resultados aparecerán aquí. Puedes cerrar y recuperar la tarea desde Historial.'
        $script:Tabs.SelectedTab = $script:ResultsPage
        Save-Preferences
    } 'Preparando una copia de tu proyecto...'
}

function Make-Label([string]$Text, [int]$Height = 35, [int]$Size = 10, [bool]$Bold = $false) {
    $control = New-Object Windows.Forms.Label
    $control.Text = $Text; $control.Dock = 'Top'; $control.Height = $Height
    $control.ForeColor = $script:Ink
    $style = [Drawing.FontStyle]::Regular
    if ($Bold) { $style = [Drawing.FontStyle]::Bold }
    $control.Font = New-Object Drawing.Font('Segoe UI', $Size, $style)
    $control.Padding = New-Object Windows.Forms.Padding(0, 5, 0, 3)
    return $control
}

function Make-Button([string]$Text, [scriptblock]$Action, [int]$Width = 190) {
    $button = New-Object Windows.Forms.Button
    $button.Text = $Text; $button.Width = $Width; $button.Height = 39
    $button.FlatStyle = 'Flat'; $button.FlatAppearance.BorderSize = 0
    $button.BackColor = $script:Accent; $button.ForeColor = [Drawing.Color]::White
    $button.Margin = New-Object Windows.Forms.Padding(0, 4, 10, 4)
    $button.Tag = $Action
    $button.Add_Click({ param($sender, $eventArgs) Guard $sender.Tag })
    return $button
}

function Make-Flow([int]$Height = 50) {
    $flow = New-Object Windows.Forms.FlowLayoutPanel
    $flow.Dock = 'Top'; $flow.Height = $Height; $flow.WrapContents = $true
    return $flow
}

function Make-Column($Parent) {
    $panel = New-Object Windows.Forms.TableLayoutPanel
    $panel.ColumnCount = 1; $panel.RowCount = 0; $panel.AutoSize = $true
    $panel.AutoSizeMode = 'GrowAndShrink'; $panel.Dock = 'Top'
    $panel.Padding = New-Object Windows.Forms.Padding(22)
    [void]$panel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent', 100)))
    $Parent.Controls.Add($panel)
    return $panel
}

function Add-Row($Column, $Control) {
    $Control.Dock = 'Top'
    $row = $Column.RowCount; $Column.RowCount++
    [void]$Column.RowStyles.Add((New-Object Windows.Forms.RowStyle('AutoSize')))
    $Column.Controls.Add($Control, 0, $row)
}

function Make-Page([string]$Title) {
    $page = New-Object Windows.Forms.TabPage
    $page.Text = $Title; $page.BackColor = [Drawing.Color]::White; $page.AutoScroll = $true
    [void]$script:Tabs.TabPages.Add($page)
    return $page
}

$script:Form = New-Object Windows.Forms.Form
$script:Form.Text = 'Equipo IA · Windows · Vista previa'
$script:Form.Size = New-Object Drawing.Size(1120, 860)
$script:Form.MinimumSize = New-Object Drawing.Size(960, 720)
$script:Form.StartPosition = 'CenterScreen'
$script:Form.Font = New-Object Drawing.Font('Segoe UI', 10)
$script:Form.AutoScaleMode = 'Dpi'
$header = New-Object Windows.Forms.Panel
$header.Dock = 'Top'; $header.Height = 94; $header.BackColor = $script:Ink
$heading = Make-Label 'Equipo IA' 46 24 $true
$heading.ForeColor = [Drawing.Color]::White; $heading.Padding = New-Object Windows.Forms.Padding(24, 8, 0, 0)
$subtitle = Make-Label 'Describe una mejora. Revisa la propuesta. Tú decides cuándo aplicarla.' 35
$subtitle.ForeColor = [Drawing.Color]::White; $subtitle.Padding = New-Object Windows.Forms.Padding(26, 3, 0, 0)
$header.Controls.Add($subtitle); $header.Controls.Add($heading)
$script:Tabs = New-Object Windows.Forms.TabControl
$script:Tabs.Dock = 'Fill'; $script:Tabs.Padding = New-Object Drawing.Point(16, 8)
$statusBar = New-Object Windows.Forms.StatusStrip
$script:Footer = New-Object Windows.Forms.ToolStripStatusLabel
$script:Footer.Spring = $true; $script:Footer.TextAlign = 'MiddleLeft'
$script:Footer.Text = 'Empieza por Preparación o ejecuta un ejemplo cuando Ubuntu esté listo.'
$script:Progress = New-Object Windows.Forms.ToolStripProgressBar
$script:Progress.Style = 'Marquee'; $script:Progress.Visible = $false
[void]$statusBar.Items.Add($script:Footer); [void]$statusBar.Items.Add($script:Progress)
$script:Form.Controls.Add($script:Tabs); $script:Form.Controls.Add($statusBar); $script:Form.Controls.Add($header)

# Preparación: acciones guiadas con explicaciones antes de instalar.
$setupPage = Make-Page '1  Preparación'
$setup = Make-Column $setupPage
Add-Row $setup (Make-Label 'Prepara este equipo una sola vez' 46 20 $true)
Add-Row $setup (Make-Label 'La ventana funciona en Windows. Ubuntu ejecuta los agentes y las comprobaciones. Cada persona utiliza su propia cuenta de IA.' 47)
$distroRow = Make-Flow 48
$script:Distro = New-Object Windows.Forms.ComboBox
$script:Distro.Width = 225; $script:Distro.Text = 'Ubuntu'; $script:Distro.Margin = New-Object Windows.Forms.Padding(0, 8, 12, 0)
$distroRow.Controls.Add($script:Distro)
$distroRow.Controls.Add((Make-Button 'Buscar Ubuntu instalado' {
    if (-not (Test-Path -LiteralPath $script:Wsl)) { throw 'Todavía no está instalado WSL. Usa Instalar Ubuntu.' }
    $process = New-NativeProcess $script:Wsl @('--list', '--quiet') -Unicode
    Begin-Process $process {
        param($text)
        $names = @($text.Replace([string][char]0, '') -split "`r?`n" | Where-Object { $_.Trim() })
        $script:Distro.Items.Clear()
        foreach ($name in $names) { [void]$script:Distro.Items.Add($name.Trim()) }
        if ($names.Count -gt 0) { $script:Distro.SelectedIndex = 0; Set-Busy 'Selecciona la distribución que usarás y pulsa Comprobar.' }
        else { Notice 'No se encontró una distribución. Usa Instalar Ubuntu y completa su primer inicio.' }
    } 'Buscando distribuciones de WSL...'
} 215))
$distroRow.Controls.Add((Make-Button 'Comprobar' { Scan-Environment } 135))
Add-Row $setup $distroRow
$script:EnvironmentStatus = Make-Label 'Pulsa Comprobar para ver qué herramientas faltan. Si todavía no tienes Ubuntu, empieza con el paso A.' 150
$script:EnvironmentStatus.BackColor = [Drawing.ColorTranslator]::FromHtml('#EDF5F3')
$script:EnvironmentStatus.Padding = New-Object Windows.Forms.Padding(14)
Add-Row $setup $script:EnvironmentStatus
Add-Row $setup (Make-Label 'A · Ubuntu y herramientas' 33 12 $true)
$baseRow = Make-Flow
$baseRow.Controls.Add((Make-Button 'Instalar Ubuntu' {
    if (Confirm 'Windows instalará WSL y Ubuntu. Pedirá permiso de administrador y puede requerir reiniciar. Después abre Ubuntu y crea tu usuario. ¿Continuar?') {
        $info = New-Object Diagnostics.ProcessStartInfo
        $info.FileName = $script:Wsl; $info.Arguments = '--install -d Ubuntu'; $info.UseShellExecute = $true; $info.Verb = 'runas'
        [void][Diagnostics.Process]::Start($info)
        Notice 'Completa la instalación. Si Windows lo indica, reinicia; después abre Ubuntu una vez para crear tu usuario y vuelve a esta aplicación.'
    }
}))
$baseRow.Controls.Add((Make-Button 'Abrir Ubuntu' {
    $process = New-NativeProcess $script:Wsl @('--distribution', (Selected-Distro)) -Visible
    [void]$process.Start()
}))
$baseRow.Controls.Add((Make-Button 'Preparar herramientas' {
    if (Confirm 'Se instalarán Git, Python, Node, npm, curl y utilidades dentro de la distribución seleccionada usando sus paquetes oficiales. Necesita Internet. ¿Continuar?') { Setup-Action 'base' }
} 215))
Add-Row $setup $baseRow
Add-Row $setup (Make-Label 'B · Conecta tu cuenta de Codex' 33 12 $true)
Add-Row $setup (Make-Label 'Codex puede programar y revisar en sesiones distintas. Sus condiciones de acceso y consumo dependen de tu cuenta. La aplicación no guarda tu contraseña.' 45)
$accountRow = Make-Flow
$accountRow.Controls.Add((Make-Button 'Instalar Codex' {
    if (Confirm 'Se descargará y ejecutará el instalador oficial de Codex desde chatgpt.com dentro de Ubuntu, para tu usuario. ¿Continuar?') { Setup-Action 'codex' }
}))
$accountRow.Controls.Add((Make-Button 'Conectar mi cuenta' { Setup-Action 'login' }))
$accountRow.Controls.Add((Make-Button 'Conectar con código' {
    Notice 'Usa esta alternativa si el inicio con navegador no funciona. Sigue el enlace y código de la ventana. Tu cuenta o administrador debe permitir el acceso por código de dispositivo.'
    Setup-Action 'login-device'
} 215))
Add-Row $setup $accountRow
Add-Row $setup (Make-Label 'Si ya usas OpenCode o AGY, puedes seleccionarlos en Proyecto. Deben estar instalados y conectados dentro de la misma distribución. Su instalación no se automatiza en esta versión.' 49)

# Proyecto y petición.
$projectPage = Make-Page '2  Proyecto y tarea'
$projectColumn = Make-Column $projectPage
Add-Row $projectColumn (Make-Label '¿Qué quieres mejorar?' 46 20 $true)
Add-Row $projectColumn (Make-Label 'Selecciona un proyecto Git que ya tenga una versión guardada y sus pruebas preparadas. Para empezar sin configurar agentes, usa el ejemplo simulado.' 47)
$script:ProjectPath = New-Object Windows.Forms.TextBox
$script:ProjectPath.Height = 32
Add-Row $projectColumn $script:ProjectPath
$projectButtons = Make-Flow
$projectButtons.Controls.Add((Make-Button 'Elegir carpeta' {
    $dialog = New-Object Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Selecciona la carpeta de tu proyecto Git'; $dialog.ShowNewFolderButton = $false
    if ($dialog.ShowDialog($script:Form) -eq 'OK') { $script:ProjectPath.Text = $dialog.SelectedPath; $script:ProjectStatus.Text = 'Pulsa Revisar proyecto para comprobar la carpeta.' }
    $dialog.Dispose()
}))
$projectButtons.Controls.Add((Make-Button 'Revisar proyecto' {
    Bridge @{ action = 'project'; project = $script:ProjectPath.Text } { param($data) Show-Project $data } 'Revisando la carpeta y su versión...'
}))
$projectButtons.Controls.Add((Make-Button 'Crear proyecto de práctica' {
    Bridge @{ action = 'example' } { param($data) Show-Project $data; $script:Task.Text = $data.suggested_task } 'Creando un ejemplo con su historial y pruebas...'
} 250))
Add-Row $projectColumn $projectButtons
$script:ProjectStatus = Make-Label 'Puedes seleccionar una carpeta de Windows o escribir una ruta de Ubuntu, por ejemplo ~/proyecto.' 72
Add-Row $projectColumn $script:ProjectStatus
Add-Row $projectColumn (Make-Label 'Describe el cambio y cómo debería comportarse' 31 12 $true)
$script:Task = New-Object Windows.Forms.TextBox
$script:Task.Multiline = $true; $script:Task.AcceptsReturn = $true; $script:Task.ScrollBars = 'Vertical'; $script:Task.Height = 125
Add-Row $projectColumn $script:Task
$agentRow = Make-Flow 54
$agentRow.Controls.Add((Make-Label 'Programa:' 31))
# Las etiquetas en FlowLayoutPanel no deben ocupar todo el ancho.
$agentRow.Controls[0].Dock = 'None'; $agentRow.Controls[0].Width = 90
$script:Programmer = New-Object Windows.Forms.ComboBox
$script:Programmer.DropDownStyle = 'DropDownList'; $script:Programmer.Width = 165
[void]$script:Programmer.Items.AddRange(@('Codex', 'OpenCode')); $script:Programmer.SelectedIndex = 0
$agentRow.Controls.Add($script:Programmer)
$reviewLabel = Make-Label 'Revisa:' 31; $reviewLabel.Dock = 'None'; $reviewLabel.Width = 75
$agentRow.Controls.Add($reviewLabel)
$script:Reviewer = New-Object Windows.Forms.ComboBox
$script:Reviewer.DropDownStyle = 'DropDownList'; $script:Reviewer.Width = 190
[void]$script:Reviewer.Items.AddRange(@('Codex (otra sesión)', 'AGY')); $script:Reviewer.SelectedIndex = 0
$agentRow.Controls.Add($script:Reviewer)
Add-Row $projectColumn $agentRow
$script:NpmCi = New-Object Windows.Forms.CheckBox
$script:NpmCi.Text = 'Permitir instalar las dependencias npm del proyecto en las copias de pruebas (npm ci).'
$script:NpmCi.Height = 34
Add-Row $projectColumn $script:NpmCi
Add-Row $projectColumn (Make-Label 'Las pruebas ejecutan código del proyecto. Trabaja con proyectos de confianza. La copia temporal no es un aislamiento completo de tu equipo.' 44)
$runRow = Make-Flow
$runRow.Controls.Add((Make-Button 'Preparar mejora con IA' { Start-Task $false } 230))
$runRow.Controls.Add((Make-Button 'Probar ejemplo sin cuenta' {
    Bridge @{ action = 'example' } {
        param($data)
        Show-Project $data; $script:Task.Text = $data.suggested_task
        Start-Task $true
    } 'Creando un ejemplo para la demostración...'
} 250))
Add-Row $projectColumn $runRow
Add-Row $projectColumn (Make-Label 'El ejemplo simulado no usa IA real ni consume tu cuenta. Para probar IA real en el mismo tipo de proyecto, crea un proyecto de práctica y pulsa Preparar mejora con IA.' 48)

# Resultados: el parche siempre se muestra antes de habilitar la decisión humana.
$script:ResultsPage = Make-Page '3  Resultados'
$results = New-Object Windows.Forms.TableLayoutPanel
$results.Dock = 'Fill'; $results.ColumnCount = 1; $results.RowCount = 4; $results.Padding = New-Object Windows.Forms.Padding(20)
[void]$results.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent', 100)))
foreach ($height in @(55, 112, 56)) { [void]$results.RowStyles.Add((New-Object Windows.Forms.RowStyle('Absolute', $height))) }
[void]$results.RowStyles.Add((New-Object Windows.Forms.RowStyle('Percent', 100)))
$script:ResultTitle = Make-Label 'Aquí aparecerá tu propuesta' 52 19 $true
$script:ResultSummary = Make-Label 'Primero ejecuta una tarea o abre una ejecución del historial.' 110
$resultButtons = Make-Flow 55
$script:ApplyButton = Make-Button 'Aplicar esta propuesta' {
    if ($null -eq $script:CurrentJob -or -not $script:CurrentJob.can_apply) { throw 'Primero abre una propuesta validada.' }
    if (Confirm "Se aplicará el parche que estás revisando a:`r`n$($script:CurrentJob.project)`r`n`r`nNo se publicará ni se guardará un commit automáticamente. ¿Aplicar?") {
        Bridge @{ action = 'apply'; id = $script:JobId; patch_hash = $script:CurrentJob.patch_hash; confirmation = 'APLICAR' } {
            param($data) Notice $data.message; Poll-Result
        } 'Comprobando y aplicando la propuesta...'
    }
} 220
$script:ApplyButton.Enabled = $false
$resultButtons.Controls.Add($script:ApplyButton)
$script:SaveButton = Make-Button 'Guardar versión local' {
    if (Confirm 'Git guardará una versión local con los archivos de esta propuesta. Solo se permite si no hubo cambios adicionales después de aplicarla. No se publicará en Internet. ¿Guardar?') {
        Bridge @{ action = 'checkpoint'; id = $script:JobId; confirmation = 'GUARDAR' } {
            param($data) Notice $data.message; Poll-Result
        } 'Guardando una versión local...'
    }
} 220
$script:SaveButton.Enabled = $false; $resultButtons.Controls.Add($script:SaveButton)
$resultButtons.Controls.Add((Make-Button 'Actualizar' { Poll-Result } 140))
$detailTabs = New-Object Windows.Forms.TabControl
$detailTabs.Dock = 'Fill'
foreach ($entry in @(@('Cambios', 'Patch'), @('Revisión', 'Review'), @('Informe completo', 'Acta'), @('Registro', 'Log'))) {
    $page = New-Object Windows.Forms.TabPage; $page.Text = $entry[0]
    $box = New-Object Windows.Forms.TextBox
    $box.Multiline = $true; $box.ReadOnly = $true; $box.ScrollBars = 'Both'; $box.WordWrap = $false; $box.Dock = 'Fill'
    $box.Font = New-Object Drawing.Font('Consolas', 10); $box.BackColor = [Drawing.Color]::White
    $box.MaxLength = 2000000
    $page.Controls.Add($box); [void]$detailTabs.TabPages.Add($page)
    Set-Variable -Scope Script -Name $entry[1] -Value $box
}
$results.Controls.Add($script:ResultTitle, 0, 0); $results.Controls.Add($script:ResultSummary, 0, 1)
$results.Controls.Add($resultButtons, 0, 2); $results.Controls.Add($detailTabs, 0, 3)
$script:ResultsPage.Controls.Add($results)

$historyPage = Make-Page 'Historial'
$historyColumn = Make-Column $historyPage
Add-Row $historyColumn (Make-Label 'Recupera tus últimas tareas' 46 20 $true)
Add-Row $historyColumn (Make-Label 'Los resultados se guardan dentro de Ubuntu. Una tarea en curso continúa aunque cierres la ventana; vuelve a abrirla desde aquí.' 45)
$historyButtons = Make-Flow
$historyButtons.Controls.Add((Make-Button 'Actualizar historial' {
    Bridge @{ action = 'history' } {
        param($data)
        $script:HistoryItems = @($data.jobs)
        $script:HistoryList.Items.Clear()
        foreach ($job in $script:HistoryItems) {
            $kind = if ($job.demo) { 'Ejemplo' } else { 'IA' }
            [void]$script:HistoryList.Items.Add("[$kind · $($job.status)] $($job.task) — $($job.project)")
        }
        Set-Busy 'Historial actualizado. Selecciona una tarea para abrirla.'
    } 'Cargando las últimas tareas...'
} 220))
$historyButtons.Controls.Add((Make-Button 'Abrir tarea seleccionada' {
    $index = $script:HistoryList.SelectedIndex
    if ($index -lt 0) { throw 'Selecciona una tarea de la lista.' }
    $script:JobId = $script:HistoryItems[$index].id
    $script:Tabs.SelectedTab = $script:ResultsPage
    Poll-Result
} 250))
Add-Row $historyColumn $historyButtons
$script:HistoryList = New-Object Windows.Forms.ListBox
$script:HistoryList.Height = 420; $script:HistoryList.HorizontalScrollbar = $true
Add-Row $historyColumn $script:HistoryList

# E/S asíncrona: el timer nunca espera a un proceso ni lee una tubería bloqueante.
$script:Timer = New-Object Windows.Forms.Timer
$script:Timer.Interval = 250
$script:Timer.Add_Tick({
    if ($null -ne $script:Operation) {
        $op = $script:Operation
        if ([DateTime]::UtcNow -gt $op.Deadline -and -not $op.Process.HasExited) {
            try { $op.Process.Kill() } catch { }
            $script:Operation = $null
            Set-Busy 'La comprobación tardó demasiado. Revisa Ubuntu y vuelve a intentarlo.'
            return
        }
        if ($op.Process.HasExited -and $op.Output.IsCompleted -and $op.Error.IsCompleted) {
            $script:Operation = $null
            Guard {
                $stdout = $op.Output.Result; $stderr = $op.Error.Result
                $exitCode = $op.Process.ExitCode; $op.Process.Dispose()
                if ($op.Json) {
                    $line = @($stdout -split "`r?`n" | Where-Object { $_.Trim() }) | Select-Object -Last 1
                    try { $response = $line | ConvertFrom-Json } catch { throw "No se pudo comunicar con Ubuntu. Completa Preparación.`r`n$stdout`r`n$stderr" }
                    if ($null -eq $response -or -not $response.ok) {
                        if ($null -ne $response) { throw $response.error }
                        throw "Ubuntu no devolvió un resultado. Revisa Preparación.`r`n$stderr"
                    }
                    & $op.Callback $response.data
                } else {
                    if ($exitCode -ne 0) { throw "$stdout`r`n$stderr" }
                    & $op.Callback $stdout
                }
                $script:Progress.Visible = ($null -ne $script:Operation)
            }
        }
    } elseif ($script:JobId -and $script:Tabs.SelectedTab -eq $script:ResultsPage -and ([DateTime]::UtcNow - $script:LastPoll).TotalSeconds -ge 2) {
        if ($null -eq $script:CurrentJob -or $script:CurrentJob.status -in @('PREPARANDO', 'EN_CURSO')) {
            $script:LastPoll = [DateTime]::UtcNow
            Guard { Poll-Result }
        }
    }
})
$script:Form.Add_FormClosing({
    try { Save-Preferences } catch { }
    $script:Timer.Stop()
    if ($null -ne $script:Operation -and -not $script:Operation.Process.HasExited) {
        try { $script:Operation.Process.Kill() } catch { }
    }
})
if (Test-Path -LiteralPath $script:Preferences) {
    try {
        $preferences = [IO.File]::ReadAllText($script:Preferences) | ConvertFrom-Json
        $script:Distro.Text = $preferences.distribution
        $script:ProjectPath.Text = $preferences.project
    } catch { }
}
if ($SmokeTest) {
    $script:Form.CreateControl()
    $script:Form.PerformLayout()
    $script:Form.Dispose()
    Write-Output 'Interfaz construida correctamente.'
    exit 0
}
$script:Timer.Start()
[void]$script:Form.ShowDialog()
$script:Timer.Dispose(); $script:Form.Dispose()
