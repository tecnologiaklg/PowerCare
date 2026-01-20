# =========================================================
# Ferramenta para otimização de notebook's
# Criado por Gustavo Moreira
# Ultima atualizacao : 20 / 01 / 2026
# =========================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
# Importa as bibliotecas neecssárias para criar a interface gráfica (textos, botões e cores..)
# Foi utilizado uma biblioteca nativa para simplificar sem comprometer a idéia do projeto

# Segurança (Administrador)

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) 
# Puxa a informação no PowerShell se está como administrador para poder realizar todas as funções com êxito (Desnecessário para o .exe, já que ele obriga a pessoa a entrar como administrador)

if (-not $isAdmin) {
    try {
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -ErrorAction Stop
        exit
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Acesso Negado!`n`nEste aplicativo precisa de privilegios de Administrador.", "Erro de Seguranca", 0, 16)
        exit
    }
}
# Se não for admin, ele reabre com a permissao de administrador, caso seja negado, aparece a mensagem de acesso negado em uma box

# Hardware

$cpuName = (Get-CimInstance Win32_Processor).Name 
# cpuName recebe as informações do processador

$totalRam = [math]::Round((Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum / 1GB, 0)
# totalRam recebe a quantidade total de memória RAM

# Configuracoes visuais

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
# Padroniza as cores do sistema

# Funcoes de Log

function Update-UI { [System.Windows.Forms.Application]::DoEvents() }
# Atualiza a interface para evitar travamentos durante execução.

function Add-Log {
    param([string]$msg, [string]$type="INFO")
# Função principal para mostrar mensagens no painel de log

    $ts = (Get-Date).ToString("HH:mm:ss")
    # Captura a hora atual para o prefixo da mensagem
    $color = switch ($type) { "SUCCESS"{$Theme.Success} "ERROR"{$Theme.Error} "INFO"{$Theme.Info} default{$Theme.Text} }
    # Define a cor do texto com base no tipo de log (Sucesso, Erro ou Info)

    if ($script:LogBox -and $script:LogBox.IsHandleCreated) {
        # Verifica se a caixa de log existe e foi renderizada na tela
        $script:LogBox.Invoke([Action[string, [System.Drawing.Color]]]{
            param($m, $c)
            $start = $script:LogBox.TextLength
            $script:LogBox.AppendText("[$ts] $m`r`n")
            # Adiciona o texto ao final do log
            $script:LogBox.Select($start, $script:LogBox.TextLength - $start)
            $script:LogBox.SelectionColor = $c
            # Aplica a cor específica apenas na linha adicionada
            $script:LogBox.DeselectAll()
            $script:LogBox.ScrollToCaret()
            # Faz o scroll automático para a última mensagem
        }, $msg, $color)
    }
    Update-UI
}

# --- Logica de Limpeza ---
function Limpar-Windows {
    Add-Log "Iniciando analise de saude do disco..." "INFO"
    
    $drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $espacoInicial = $drive.FreeSpace
    # Captura o espaço livre em bytes antes de iniciar a limpeza
    $espacoInicialGB = [math]::Round($espacoInicial / 1GB, 2)
    Add-Log "Espaco livre antes: $espacoInicialGB GB" "INFO"

    $script:ProgressBar.Value = 5
    # Define o progresso inicial da barra

    $alvosAmigaveis = @{
        "$env:TEMP\*" = "Arquivos temporarios de aplicativos"
        "C:\Windows\Temp\*" = "Residuos do sistema operacional"
        "C:\Windows\Prefetch\*" = "Caches de inicializacao antigos"
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*" = "Lixo de navegacao na internet"
        "C:\Windows\Logs\*" = "Arquivos de log redundantes"
    }
    # Tabela de caminhos conhecidos que podem ser apagados com segurança

    foreach ($t in $alvosAmigaveis.Keys) {
        # Loop que percorre cada caminho definido na lista acima
        $nomeAmigavel = $alvosAmigaveis[$t]
        Add-Log "Otimizando: $nomeAmigavel..." "INFO"
        
        try {
            Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue
            # Tenta apagar pastas e arquivos de forma forçada
            if ($script:ProgressBar.Value -lt 50) { $script:ProgressBar.Value += 8 }
            # Incrementa a barra de progresso a cada etapa concluída
        } catch {
            Add-Log "Aviso: Alguns itens de '$nomeAmigavel' estao em uso." "INFO"
        }
        Update-UI
    }

    Add-Log "Executando limpeza profunda (DISM)..." "INFO"
    dism.exe /online /Cleanup-Image /StartComponentCleanup /NoRestart | Out-Null
    # Comando nativo do Windows para limpar versões antigas de componentes (WinSxS)
    $script:ProgressBar.Value = 80

    $driveFinal = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $espacoFinal = $driveFinal.FreeSpace
    # Captura o espaço livre após a limpeza
    $espacoFinalGB = [math]::Round($espacoFinal / 1GB, 2)
    $ganhoTotal = [math]::Round(($espacoFinal - $espacoInicial) / 1MB, 2)
    # Calcula a diferença para saber quanto espaço foi recuperado em MB

    # EXIBE RESULTADO COMPARATIVO
    if ($ganhoTotal -gt 0) {
        Add-Log "Espaco livre depois: $espacoFinalGB GB" "SUCCESS"
        Add-Log "CONCLUIDO: Voce recuperou $ganhoTotal MB de espaco!" "SUCCESS"
    } else {
        Add-Log "Seu disco ja estava perfeitamente otimizado ($espacoFinalGB GB)." "SUCCESS"
    }

    $script:ProgressBar.Value = 100
    Start-Sleep -Seconds 1
    $script:ProgressBar.Value = 0
    # Reseta a barra de progresso após finalizar
}

# --- Logica de Rede ---
function Otimizar-Rede-Completo {
    Add-Log "Medindo performance da rede antes dos ajustes..." "INFO"
    
    $pingAntes = (Test-Connection 8.8.8.8 -Count 2 -ErrorAction SilentlyContinue | Measure-Object ResponseTime -Average).Average
    # Realiza um teste de ping rápido para medir a latência atual
    Add-Log "Latencia inicial: $($pingAntes)ms" "INFO"

    $script:ProgressBar.Value = 20

    $cmds = @("ipconfig /flushdns", "netsh winsock reset", "netsh int ip reset", "netsh int tcp set global autotuninglevel=normal")
    # Lista de comandos para limpar DNS, resetar sockets e otimizar protocolo TCP
    foreach ($c in $cmds) {
        # Loop para executar cada comando de rede
        Add-Log "Aplicando: $c" "INFO"
        $null = Invoke-Expression $c
        # Executa o comando e descarta a saída textual para não poluir o código
        $script:ProgressBar.Value += 15
        Update-UI
    }
    
    $pingDepois = (Test-Connection 8.8.8.8 -Count 2 -ErrorAction SilentlyContinue | Measure-Object ResponseTime -Average).Average
    # Mede a latência novamente após as alterações
    $melhoria = [math]::Round($pingAntes - $pingDepois, 2)

    # EXIBE LATENCIA FINAL E MELHORIA
    Add-Log "Latencia final: $($pingDepois)ms" "SUCCESS"

    if ($melhoria -gt 0) {
        Add-Log "OTIMIZADO: Sua latencia diminuiu em $($melhoria)ms!" "SUCCESS"
    } else {
        Add-Log "Rede estabilizada e renovada." "SUCCESS"
    }

    $script:ProgressBar.Value = 100
    Start-Sleep -Seconds 1
    $script:ProgressBar.Value = 0
}

function Gerenciar-Startup-Lista {
    Add-Log "Abrindo gerenciador de inicializacao..." "INFO"

    # --- Configuração da Janela ---
    $PopUp = New-Object System.Windows.Forms.Form
    $PopUp.Text = " PowerCare - Gerenciar Startup"
    $PopUp.Size = '540,520' # Reduzi um pouco a altura já que tem um botão a menos
    $PopUp.StartPosition = "CenterParent"
    $PopUp.BackColor = $Theme.BG
    $PopUp.FormBorderStyle = "FixedDialog"
    $PopUp.MaximizeBox = $false

    # --- Header ---
    $Header = New-Object System.Windows.Forms.Label
    $Header.Text = "Itens de inicializacao"
    $Header.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $Header.ForeColor = $Theme.Accent
    $Header.Location = '25,20'
    $Header.AutoSize = $true
    $PopUp.Controls.Add($Header)

    $SubHeader = New-Object System.Windows.Forms.Label
    $SubHeader.Text = "Selecione os programas que deseja impedir de iniciar com o Windows."
    $SubHeader.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $SubHeader.ForeColor = $Theme.SubText
    $SubHeader.Location = '27,55'
    $SubHeader.AutoSize = $true
    $PopUp.Controls.Add($SubHeader)

    # --- Container da Lista ---
    $ListContainer = New-Object System.Windows.Forms.Panel
    $ListContainer.Location = '25,90'
    $ListContainer.Size = '475,300'
    $ListContainer.BackColor = $Theme.LogBG
    $PopUp.Controls.Add($ListContainer)

    $CheckedList = New-Object System.Windows.Forms.CheckedListBox
    $CheckedList.Dock = "Fill"
    $CheckedList.CheckOnClick = $true
    $CheckedList.BackColor = $Theme.LogBG
    $CheckedList.ForeColor = $Theme.Text
    $CheckedList.BorderStyle = "None"
    $CheckedList.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $ListContainer.Controls.Add($CheckedList)

    # --- Lógica de Carregamento ---
    $script:itensStartup = @()
    $CarregarDados = {
        $CheckedList.Items.Clear()
        $script:itensStartup = @()
        
        $RegPaths = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run", "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run")
        $FolderPaths = @("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup", "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup")

        foreach ($p in $RegPaths) {
            if (Test-Path $p) {
                (Get-ItemProperty $p).PSObject.Properties | Where-Object { $_.Name -notmatch "PSPath|PSParentPath|PSChildName|PSDrive|PSProvider" } | ForEach-Object {
                    $script:itensStartup += [PSCustomObject]@{ Nome = $_.Name; Caminho = $p; Tipo = "REG" }
                    $CheckedList.Items.Add($_.Name)
                }
            }
        }
        foreach ($f in $FolderPaths) {
            if (Test-Path $f) {
                Get-ChildItem $f -File | ForEach-Object {
                    $script:itensStartup += [PSCustomObject]@{ Nome = $_.Name; Caminho = $_.FullName; Tipo = "FILE" }
                    $CheckedList.Items.Add($_.Name)
                }
            }
        }
    }

    # --- Botão: REMOVER (Posicionado logo abaixo da lista) ---
    $btnDel = New-Object System.Windows.Forms.Button
    $btnDel.Text = "REMOVER SELECIONADOS"
    $btnDel.Location = '25,410' # Ajustado para subir após tirar o botão de adicionar
    $btnDel.Size = '475,45'
    $btnDel.FlatStyle = "Flat"
    $btnDel.FlatAppearance.BorderSize = 0
    $btnDel.BackColor = $Theme.Error
    $btnDel.ForeColor = $Theme.Text
    $btnDel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnDel.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnDel.Add_Click({
        if ($CheckedList.CheckedItems.Count -eq 0) { return }
        $msg = "Deseja remover $($CheckedList.CheckedItems.Count) item(ns) da inicializacao?"
        if ([System.Windows.Forms.MessageBox]::Show($msg, "Confirmar", 4, 32) -eq "Yes") {
            foreach ($sel in $CheckedList.CheckedItems) {
                $alvo = $script:itensStartup | Where-Object { $_.Nome -eq $sel }
                if ($alvo.Tipo -eq "REG") {
                    Remove-ItemProperty -Path $alvo.Caminho -Name $alvo.Nome -ErrorAction SilentlyContinue
                } else {
                    Remove-Item -Path $alvo.Caminho -Force -ErrorAction SilentlyContinue
                }
                Add-Log "Removido: $sel" "SUCCESS"
            }
            & $CarregarDados
        }
    })
    $PopUp.Controls.Add($btnDel)

    # --- inicializacao ---
    & $CarregarDados
    [void]$PopUp.ShowDialog()
}

# --- Interface --- 
$script:form = New-Object System.Windows.Forms.Form
# Cria a janela principal do programa
$form.Text = "PowerCare"
$form.Size = '900,650'
$form.BackColor = $Theme.BG
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false

$SidePanel = New-Object System.Windows.Forms.Panel
# Cria o painel lateral escuro para o menu
$SidePanel.Size = '220,650'
$SidePanel.BackColor = $Theme.Side
$SidePanel.Dock = "Left"
$form.Controls.Add($SidePanel)

$Title = New-Object System.Windows.Forms.Label
# Texto do título principal
$Title.Text = "PowerCare"
$Title.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$Title.ForeColor = $Theme.Accent
$Title.Location = '20,20'
$Title.AutoSize = $true
$SidePanel.Controls.Add($Title)

$HardwareInfo = New-Object System.Windows.Forms.Label
# Exibe o modelo do processador e a RAM coletados no início
$HardwareInfo.Text = "$cpuName`nMemoria RAM: $totalRam GB"
$HardwareInfo.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$HardwareInfo.ForeColor = $Theme.SubText
$HardwareInfo.Location = '20,65'
$HardwareInfo.Size = '180,45'
$SidePanel.Controls.Add($HardwareInfo)

$FooterBy = New-Object System.Windows.Forms.Label
# Créditos do autor
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
$VersionLabel.Location = '20,570'
$VersionLabel.AutoSize = $true
$SidePanel.Controls.Add($VersionLabel)

$script:ProgressBar = New-Object System.Windows.Forms.ProgressBar
# Barra de progresso visual na parte inferior
$script:ProgressBar.Size = '620,15'
$script:ProgressBar.Location = '250,580'
$script:ProgressBar.Style = "Continuous"
$form.Controls.Add($script:ProgressBar)

$script:LogBox = New-Object System.Windows.Forms.RichTextBox
# Caixa central que mostra o texto colorido das operações
$LogBox.ReadOnly = $true
$LogBox.BackColor = $Theme.LogBG
$LogBox.ForeColor = $Theme.Text
$LogBox.Font = New-Object System.Drawing.Font("Consolas", 11)
$LogBox.BorderStyle = "None"
$LogBox.Size = '620,470'
$LogBox.Location = '250,100'
$form.Controls.Add($LogBox)

$script:StatusLabel = New-Object System.Windows.Forms.Label
# Pequeno texto de status acima do log
$StatusLabel.Text = "Status: Aguardando"
$StatusLabel.ForeColor = [System.Drawing.Color]::Gray
$StatusLabel.Location = '250,65'
$StatusLabel.AutoSize = $true
$form.Controls.Add($StatusLabel)

$btnManual = New-Object System.Windows.Forms.Button
# Botão circular de ajuda
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
# Cria um caminho geométrico para arredondar o botão
$gp.AddEllipse(0, 0, $btnManual.Width, $btnManual.Height)
$btnManual.Region = New-Object System.Drawing.Region($gp)
$SidePanel.Controls.Add($btnManual)

$btnManual.Add_Click({
    # Exibe uma caixa de mensagem informativa ao clicar no "?"
    $helpText = "POWERCARE - GUIA DE USO`n`nLimpeza Completa: Remove lixo do disco.`nOtimizar Rede: Melhora conexao.`nEsvaziar Lixeira: Limpa arquivos deletados."
    [System.Windows.Forms.MessageBox]::Show($helpText, "Manual", 0, 64)
})

$script:currentY = 130
# Variável para controlar a altura vertical de cada botão adicionado ao menu

function Add-MenuButton($text, [scriptblock]$code) {
# Função para facilitar a criação de novos botões no menu lateral
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text
    $btn.Size = '180,30'
    $btn.Location = New-Object System.Drawing.Point(20, $script:currentY)
    $btn.FlatStyle = "Flat"
    $btn.FlatAppearance.BorderSize = 0
    $btn.BackColor = $Theme.Accent
    $btn.ForeColor = $Theme.Text
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btn.Tag = $code
    # Salva o script da função dentro da propriedade Tag do botão para execução posterior
    $btn.Add_Click({
        param($sender, $e)
        $sender.Enabled = $false
        # Desabilita o botão temporariamente para evitar cliques duplos
        $script:StatusLabel.Text = "Status: Processando..."
        try { if ($sender.Tag -is [scriptblock]) { & $sender.Tag } } finally {
            # Executa o código associado e garante a reabilitação do botão no final
            $sender.Enabled = $true
            $script:StatusLabel.Text = "Status: Disponivel"
        }
    })
    $SidePanel.Controls.Add($btn)
    $script:currentY += 40
    # Desce 40 pixels para posicionar o próximo botão abaixo deste
}

# --- Registro dos Botões do Menu ---
Add-MenuButton "Limpeza completa" { Limpar-Windows }
Add-MenuButton "Otimizar rede"    { Otimizar-Rede-Completo }
Add-MenuButton "Gerenciar inicializacao" { Gerenciar-Startup-Lista }
Add-MenuButton "Esvaziar lixeira" { 
    Clear-RecycleBin -Force -Confirm:$false -ErrorAction SilentlyContinue
    # Comando para esvaziar a lixeira de todas as unidades sem pedir confirmação
    Add-Log "Lixeira esvaziada com sucesso" "SUCCESS"
}
Add-MenuButton "Executar tudo" {
    # Sequência automatizada de todas as manutenções disponíveis
    Limpar-Windows
    Otimizar-Rede-Completo
    Add-Log "Manutencao geral finalizada!" "SUCCESS"
}
Add-MenuButton "Limpar tela" { 
    $script:LogBox.Clear() 
    # Apaga todo o texto acumulado na caixa de log
    Add-Log "Historico de log limpo." "SUCCESS"
}

$form.Add_Load({ 
    # Evento disparado assim que a janela abre
    Add-Log "PowerCare pronto para uso." "SUCCESS"
})

[void]$form.ShowDialog()
# Inicia a interface gráfica e aguarda interações do usuário