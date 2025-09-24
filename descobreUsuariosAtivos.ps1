Add-Type -AssemblyName System.Windows.Forms
$cred = Get-Credential
# Configuração do formulário
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Descobre Usuarios Locais Ativos'
$form.Size = New-Object System.Drawing.Size(700,520)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

# Label e campo para lista de computadores (um por linha)
$labelComputers = New-Object System.Windows.Forms.Label
$labelComputers.Text = 'Computadores (um por linha):'
$labelComputers.AutoSize = $true
$labelComputers.Location = New-Object System.Drawing.Point(15,15)
$form.Controls.Add($labelComputers)

$textBoxComputers = New-Object System.Windows.Forms.TextBox
$textBoxComputers.Location = New-Object System.Drawing.Point(15,35)
$textBoxComputers.Size = New-Object System.Drawing.Size(660,150)
$textBoxComputers.Multiline = $true
$textBoxComputers.ScrollBars = 'Vertical'
$form.Controls.Add($textBoxComputers)

# Botões
$buttonStart = New-Object System.Windows.Forms.Button
$buttonStart.Text = 'Verificar'
$buttonStart.Location = New-Object System.Drawing.Point(15,195)
$buttonStart.Size = New-Object System.Drawing.Size(200,32)
$form.Controls.Add($buttonStart)

$buttonClear = New-Object System.Windows.Forms.Button
$buttonClear.Text = 'Limpar Resultados'
$buttonClear.Location = New-Object System.Drawing.Point(225,195)
$buttonClear.Size = New-Object System.Drawing.Size(200,32)
$form.Controls.Add($buttonClear)

# Caixa de resultados (somente texto, sem cores)
$textBoxResults = New-Object System.Windows.Forms.TextBox
$textBoxResults.Location = New-Object System.Drawing.Point(15,235)
$textBoxResults.Size = New-Object System.Drawing.Size(660,240)
$textBoxResults.Multiline = $true
$textBoxResults.ReadOnly = $true
$textBoxResults.ScrollBars = 'Vertical'
$form.Controls.Add($textBoxResults)

# Lista de contas a excluir (padrões)
$excludedUsers = @("Administrador","Convidado","DefaultAccount","WDAGUtilityAccount")

# Função auxiliar para escrever resultados na UI
function Append-Result {
    param([string]$line)
    $textBoxResults.AppendText($line + [Environment]::NewLine) | Out-Null
}

# Evento limpar
$buttonClear.Add_Click({
    $textBoxResults.Clear()
})

# Evento iniciar
$buttonStart.Add_Click({
    $buttonStart.Enabled = $false
    $textBoxResults.Clear()

    # Ler lista de computadores da caixa de texto
    $computers = $textBoxComputers.Text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

    if ($computers.Count -eq 0) {
        Append-Result "[ERRO] Informe ao menos um computador."
        $buttonStart.Enabled = $true
        return
    }

    # Solicita credenciais (uma vez)
    

    foreach ($computer in $computers) {
        # Testa conectividade
        if (-not (Test-Connection -ComputerName $computer -Count 1 -Quiet)) {
            Append-Result "[OK] $computer inacessível (ping falhou)."
            continue
        }

        $session = $null
        try {
            $session = New-CimSession -ComputerName $computer -Credential $cred -ErrorAction Stop

            # Obter usuários locais ativos
            $localUsers = Get-CimInstance -CimSession $session -ClassName Win32_UserAccount -Filter "LocalAccount=True AND Disabled=False"

            # Tentar obter membros do grupo Administradores local para excluir
            $adminNames = @()
            try {
                $adminGroup = Get-CimInstance -CimSession $session -ClassName Win32_Group -Filter "LocalAccount=True AND Name='Administrators'" -ErrorAction Stop
                if ($adminGroup) {
                    $adminMembers = Get-CimAssociatedInstance -CimSession $session -InputObject $adminGroup -Association Win32_GroupUser -ResultClassName Win32_UserAccount -ErrorAction Stop
                    if ($adminMembers) { $adminNames = $adminMembers | Select-Object -ExpandProperty Name }
                }
            } catch {
                # Não interrompe; se falhar, segue sem excluir membros do grupo Administrators
            }

            if ($null -eq $localUsers -or $localUsers.Count -eq 0) {
                Append-Result "[OK] Nenhum usuário local ativo encontrado em $computer"
            } else {
                # Excluir contas padrão e membros do grupo Administrators
                $filtered = $localUsers | Where-Object { ($excludedUsers -notcontains $_.Name) -and ($adminNames -notcontains $_.Name) }

                if ($filtered.Count -gt 0) {
                    Append-Result "[OK] $($filtered.Count) usuário(s) local(is) ativo(s) (não administradores) encontrado(s) em $computer"
                    foreach ($u in $filtered) {
                        Append-Result " - $($u.Name)"
                    }
                } else {
                    #Append-Result "[OK] Nenhum usuário local ativo (exceto padrões e administradores) em $computer"
                }
            }
        }
        catch [System.UnauthorizedAccessException] {
            Append-Result "[ERRO] Acesso negado ao computador $computer"
        }
        catch [System.Runtime.InteropServices.COMException] {
            Append-Result "[ERRO] RPC/WMI indisponível no computador $computer"
        }
        catch {
            Append-Result "[ERRO] Erro ao verificar ${computer}: $($_.Exception.Message)"
        }
        finally {
            if ($session) { Remove-CimSession -CimSession $session -ErrorAction SilentlyContinue }
        }
    }

    Append-Result ""
    Append-Result "Verificação finalizada."
    $buttonStart.Enabled = $true
})

# Mostrar formulário
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()
