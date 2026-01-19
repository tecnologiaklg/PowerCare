# =========================================================
# TOOLKIT OTIMIZADOR
# Criado por Gustavo Moreira
# Última atualização : 19 / 01 / 2026
# Versão 1.0
# =========================================================

$OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Seguranca: Verificacao com Aviso Visual ---
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    try {
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -ErrorAction Stop
        exit
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Acesso Negado!`n`nEste aplicativo precisa de privilegios de Administrador para realizar as otimizacoes.", "Erro de Seguranca", 0, 16)
        exit
    }
}

# --- Hardware: Coleta de Dados ---
$cpuName = (Get-CimInstance Win32_Processor).Name
$totalRam = [math]::Round((Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum / 1GB, 0)

# --- Configuracoes visuais ---
$Theme = @{
    BG      = [System.Drawing.Color]::FromArgb(20, 20, 20)
    Side    = [System.Drawing.Color]::FromArgb(30, 30, 30)
    Accent  = [System.Drawing.Color]::FromArgb(0, 122, 204)
    Text    = [System.Drawing.Color]::White
    LogBG   = [System.Drawing.Color]::FromArgb(10, 10, 10)
    Success = [System.Drawing.Color]::LimeGreen
    Error   = [System.Drawing.Color]::Tomato
    Info    = [System.Drawing.Color]::DeepSkyBlue
    SubText = [System.Drawing.Color]::FromArgb(150, 150, 150)
}

# --- Funcoes de Log ---
function Update-UI { [System.Windows.Forms.Application]::DoEvents() }

function Add-Log {
    param([string]$msg, [string]$type="INFO")
    $ts = (Get-Date).ToString("HH:mm:ss")
    $color = switch ($type) { "SUCCESS"{$Theme.Success} "ERROR"{$Theme.Error} "INFO"{$Theme.Info} default{$Theme.Text} }

    if ($script:LogBox -and $script:LogBox.IsHandleCreated) {
        $script:LogBox.Invoke([Action[string, [System.Drawing.Color]]]{
            param($m, $c)
            $start = $script:LogBox.TextLength
            $script:LogBox.AppendText("[$ts] $m`r`n")
            $script:LogBox.Select($start, $script:LogBox.TextLength - $start)
            $script:LogBox.SelectionColor = $c
            $script:LogBox.DeselectAll()
            $script:LogBox.ScrollToCaret()
        }, $msg, $color)
    }
    Update-UI
}

# --- Logica de Limpeza Avancada ---
function Limpar-Windows {
    Add-Log "Iniciando limpeza avancada de arquivos" "INFO"
    $script:ProgressBar.Value = 10
    $totalLiberado = 0
    $targets = @(
        "$env:TEMP\*",
        "C:\Windows\Temp\*",
        "C:\Windows\Prefetch\*",
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*",
        "C:\Windows\Logs\*" 
    )

    foreach ($t in $targets) {
        $files = Get-ChildItem $t -Recurse -ErrorAction SilentlyContinue
        foreach ($f in $files) { if ($f.Length) { $totalLiberado += $f.Length } }
        try {
            Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue
            Add-Log "Limpando: $t" "SUCCESS"
            if ($script:ProgressBar.Value -lt 60) { $script:ProgressBar.Value += 5 }
        } catch { }
    }

    # Motor DISM (WinSxS)
    Add-Log "Otimizando base de componentes (DISM)..." "INFO"
    dism.exe /online /Cleanup-Image /StartComponentCleanup /NoRestart | Out-Null
    $script:ProgressBar.Value = 80

    $mb = [math]::Round($totalLiberado / 1MB, 2)
    Add-Log "Limpeza concluida! Recuperado: $mb MB" "SUCCESS"
    
    Add-Log "Otimizando sistema de atualizacoes" "INFO"
    try {
        Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
        Remove-Item "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
        Start-Service wuauserv -ErrorAction SilentlyContinue
        Add-Log "Atualizacoes otimizadas com sucesso" "SUCCESS"
    } catch { }
    
    $script:ProgressBar.Value = 100
    Start-Sleep -Seconds 1
    $script:ProgressBar.Value = 0
}



# --- Logica de Rede e Latencia ---
function Otimizar-Rede-Completo {
    Add-Log "Melhorando conexao de rede" "INFO"
    $script:ProgressBar.Value = 20
    $adapters = Get-NetAdapter | Where-Object Status -eq "Up"
    foreach ($a in $adapters) { Add-Log "Conexao detectada: $($a.Name)" "INFO" }

    # Comandos de Auto-Tuning
    $cmds = @(
        "ipconfig /flushdns", 
        "netsh winsock reset", 
        "netsh int ip reset", 
        "netsh int tcp set global autotuninglevel=normal",
        "arp -d *"
    )
    foreach ($c in $cmds) {
        Add-Log "Aplicando ajuste: $c" "INFO"
        $null = Invoke-Expression $c
        $script:ProgressBar.Value += 15
        Update-UI
        Start-Sleep -Milliseconds 200
    }
    
    Add-Log "Testando latencia..." "INFO"
    $targets = @(
        @{ Nome = "Google"; IP = "8.8.8.8" },
        @{ Nome = "Cloudflare"; IP = "1.1.1.1" }
    )

    foreach ($t in $targets) {
        try {
            $ping = Test-Connection -ComputerName $t.IP -Count 2 -ErrorAction SilentlyContinue
            if ($ping) {
                $avg = [math]::Round(($ping | Measure-Object ResponseTime -Average).Average, 2)
                Add-Log "Resposta de $($t.Nome): $($avg)ms" "SUCCESS"
            }
        } catch { }
    }
    Add-Log "Rede otimizada!" "SUCCESS"
    $script:ProgressBar.Value = 100
    Start-Sleep -Seconds 1
    $script:ProgressBar.Value = 0
}

# --- Interface ---
$script:form = New-Object System.Windows.Forms.Form
$form.Text = "PowerCare"
$form.Size = '900,650'
$form.BackColor = $Theme.BG
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false

$SidePanel = New-Object System.Windows.Forms.Panel
$SidePanel.Size = '220,650'
$SidePanel.BackColor = $Theme.Side
$SidePanel.Dock = "Left"
$form.Controls.Add($SidePanel)

$Title = New-Object System.Windows.Forms.Label
$Title.Text = "PowerCare"
$Title.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$Title.ForeColor = $Theme.Accent
$Title.Location = '20,20'
$Title.AutoSize = $true
$SidePanel.Controls.Add($Title)

# --- Hardware: Exibicao no Topo ---
$HardwareInfo = New-Object System.Windows.Forms.Label
$HardwareInfo.Text = "$cpuName`nMemoria RAM: $totalRam GB"
$HardwareInfo.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$HardwareInfo.ForeColor = $Theme.SubText
$HardwareInfo.Location = '20,65'
$HardwareInfo.Size = '180,45'
$SidePanel.Controls.Add($HardwareInfo)

$FooterBy = New-Object System.Windows.Forms.Label
$FooterBy.Text = "by: Gustavo Moreira"
$FooterBy.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$FooterBy.ForeColor = $Theme.SubText
$FooterBy.Location = '20,550'
$FooterBy.AutoSize = $true
$SidePanel.Controls.Add($FooterBy)

$VersionLabel = New-Object System.Windows.Forms.Label
$VersionLabel.Text = "Versao 1.0"
$VersionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$VersionLabel.ForeColor = $Theme.SubText
$VersionLabel.Location = '20,570' # Y alterado para 570
$VersionLabel.AutoSize = $true
$SidePanel.Controls.Add($VersionLabel)

# --- Interface: Barra de Progresso ---
$script:ProgressBar = New-Object System.Windows.Forms.ProgressBar
$script:ProgressBar.Size = '620,15'
$script:ProgressBar.Location = '250,580'
$script:ProgressBar.Style = "Continuous"
$form.Controls.Add($script:ProgressBar)

$script:LogBox = New-Object System.Windows.Forms.RichTextBox
$LogBox.ReadOnly = $true
$LogBox.BackColor = $Theme.LogBG
$LogBox.ForeColor = $Theme.Text
$LogBox.Font = New-Object System.Drawing.Font("Consolas", 11)
$LogBox.BorderStyle = "None"
$LogBox.Size = '620,470'
$LogBox.Location = '250,100'
$form.Controls.Add($LogBox)

$script:StatusLabel = New-Object System.Windows.Forms.Label
$StatusLabel.Text = "Status: Aguardando"
$StatusLabel.ForeColor = [System.Drawing.Color]::Gray
$StatusLabel.Location = '250,65'
$StatusLabel.AutoSize = $true
$form.Controls.Add($StatusLabel)

# --- Botao de Ajuda (Manual) ---
$btnManual = New-Object System.Windows.Forms.Button
$btnManual.Text = "?"
$btnManual.Size = '32,32'
$btnManual.Location = '170,550'
$btnManual.FlatStyle = "Flat"
$btnManual.FlatAppearance.BorderSize = 0
$btnManual.BackColor = $Theme.Info
$btnManual.ForeColor = $Theme.BG
$btnManual.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$btnManual.Cursor = [System.Windows.Forms.Cursors]::Hand

$gp = New-Object System.Drawing.Drawing2D.GraphicsPath
$gp.AddEllipse(0, 0, $btnManual.Width, $btnManual.Height)
$btnManual.Region = New-Object System.Drawing.Region($gp)

$btnManual.Add_MouseEnter({ $btnManual.BackColor = [System.Drawing.Color]::White })
$btnManual.Add_MouseLeave({ $btnManual.BackColor = $Theme.Info })

$btnManual.Add_Click({
    $helpText = @"
POWERCARE v1.0 - GUIA DE USO
 
Utiliza ferramentas nativas do Windows para otimizacao segura.

O QUE CADA BOTAO FAZ:
- Limpeza Completa: Exclui caches temporarios e limpa a base do sistema (WinSxS).
- Otimizar Rede: Limpa DNS e reseta protocolos TCP/IP para reduzir lag.
- Esvaziar Lixeira: Limpa arquivos descartados.
- Executar Tudo: Ciclo completo de manutencao (Não esvazia lixeira).

QUANDO USAR:
- Windows lento: Botao "Limpeza Completa".
- Internet oscilando ou Lag: Botao "Otimizar Rede".
- Manutencao Preventiva: Executar Tudo 1x por semana.
"@
    [System.Windows.Forms.MessageBox]::Show($helpText, "Manual de Instrucoes", 0, 64)
})
$SidePanel.Controls.Add($btnManual)

$script:currentY = 130
function Add-MenuButton($text, [scriptblock]$code) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text
    $btn.Size = '180,45'
    $btn.Location = New-Object System.Drawing.Point(20, $script:currentY)
    $btn.FlatStyle = "Flat"
    $btn.FlatAppearance.BorderSize = 0
    $btn.BackColor = $Theme.Accent
    $btn.ForeColor = $Theme.Text
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btn.Tag = $code
    $btn.Add_Click({
        param($sender, $e)
        $sender.Enabled = $false
        $script:StatusLabel.Text = "Status: Processando..."
        try { if ($sender.Tag -is [scriptblock]) { & $sender.Tag } } finally {
            $sender.Enabled = $true
            $script:StatusLabel.Text = "Status: Disponivel"
        }
    })
    $SidePanel.Controls.Add($btn)
    $script:currentY += 60
}

Add-MenuButton "Limpeza Completa" { Limpar-Windows }
Add-MenuButton "Otimizar Rede"    { Otimizar-Rede-Completo }
Add-MenuButton "Esvaziar Lixeira" { 
    Clear-RecycleBin -Force -Confirm:$false -ErrorAction SilentlyContinue
    Add-Log "Lixeira esvaziada com sucesso" "SUCCESS"
}
Add-MenuButton "Executar Tudo" {
    Limpar-Windows
    Otimizar-Rede-Completo
    Add-Log "Manutencao geral finalizada!" "SUCCESS"
}
Add-MenuButton "Limpar Tela Log" { 
    $script:LogBox.Clear() 
    Add-Log "Historico de log limpo." "SUCCESS"
}

$form.Add_Load({ 
    Add-Log "PowerCare pronto para uso." "SUCCESS"
})

[void]$form.ShowDialog()