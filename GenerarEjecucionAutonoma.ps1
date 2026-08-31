Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# =========================================================
# LECTURA DINÁMICA DE IMPRESORAS
# =========================================================
$RutaScriptImpresoras = "$PSScriptRoot\Scripts\Impresoras_Plenergy.ps1"
$ListaDinamicaImpresoras = @()

if (Test-Path $RutaScriptImpresoras) {
    $Contenido = Get-Content $RutaScriptImpresoras -Encoding UTF8
    $Coincidencias = $Contenido | Select-String -Pattern 'Nombre\s*=\s*"(.*?)"' -AllMatches
    foreach ($Match in $Coincidencias.Matches) { $ListaDinamicaImpresoras += $Match.Groups[1].Value }
}
if ($ListaDinamicaImpresoras.Count -eq 0) { $ListaDinamicaImpresoras = @("XEROX SUR", "XEROX NORTE", "XEROX PLANTA 1", "XEROX RRHH") }

# =========================================================
# CONSTRUCCION DE LA INTERFAZ
# =========================================================
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Generador Modo Autónomo Plenergy"
$Form.Size = New-Object System.Drawing.Size(480, 790)
$Form.StartPosition = "CenterScreen"
$Form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$Form.MinimumSize = New-Object System.Drawing.Size(460, 790)

# --- PANEL DESPLIEGUE E IDENTIDAD ---
$GroupId = New-Object System.Windows.Forms.GroupBox
$GroupId.Text = "Flujo de Despliegue e Identidad"
$GroupId.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$GroupId.Bounds = New-Object System.Drawing.Rectangle(10, 10, 440, 240)

$ChkReinicio = New-Object System.Windows.Forms.CheckBox
$ChkReinicio.Text = "Auto-Reinicio al terminar"
$ChkReinicio.Location = New-Object System.Drawing.Point(15, 30); $ChkReinicio.AutoSize = $true; $ChkReinicio.Checked = $true

$ChkFase2 = New-Object System.Windows.Forms.CheckBox
$ChkFase2.Text = "Ejecutar Fase 2 (Securización)"
$ChkFase2.Location = New-Object System.Drawing.Point(200, 30); $ChkFase2.AutoSize = $true; $ChkFase2.Checked = $true

$LblEmpresa = New-Object System.Windows.Forms.Label
$LblEmpresa.Text = "División:"; $LblEmpresa.Location = New-Object System.Drawing.Point(15, 65); $LblEmpresa.AutoSize = $true

$ComboEmpresa = New-Object System.Windows.Forms.ComboBox
$ComboEmpresa.Items.AddRange(@("1 - Plenergy ES", "2 - Plenergy PT", "3 - Plainco"))
$ComboEmpresa.SelectedIndex = 0
$ComboEmpresa.Location = New-Object System.Drawing.Point(170, 62)
$ComboEmpresa.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$ComboEmpresa.Width = 240

$LblPrefijo = New-Object System.Windows.Forms.Label
$LblPrefijo.Text = "Prefijo Equipo:"; $LblPrefijo.Location = New-Object System.Drawing.Point(15, 100); $LblPrefijo.AutoSize = $true

$TxtPrefijo = New-Object System.Windows.Forms.TextBox
$TxtPrefijo.Location = New-Object System.Drawing.Point(170, 97)
$TxtPrefijo.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$TxtPrefijo.Width = 240; $TxtPrefijo.ForeColor = [System.Drawing.Color]::Gray; $TxtPrefijo.Text = "PLENERGY-"
$TxtPrefijo.Add_Enter({ if ($this.ForeColor.Name -eq "Gray") { $this.Text = ""; $this.ForeColor = [System.Drawing.Color]::Black } })
$TxtPrefijo.Add_Leave({ if ([string]::IsNullOrWhiteSpace($this.Text)) { $this.Text = "PLENERGY-"; $this.ForeColor = [System.Drawing.Color]::Gray } })

$LblPassSys = New-Object System.Windows.Forms.Label
$LblPassSys.Text = "Contraseña SISTEMAS:"; $LblPassSys.Location = New-Object System.Drawing.Point(15, 135); $LblPassSys.AutoSize = $true

$TxtPassSys = New-Object System.Windows.Forms.TextBox
$TxtPassSys.Location = New-Object System.Drawing.Point(170, 132)
$TxtPassSys.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$TxtPassSys.Width = 240; $TxtPassSys.PasswordChar = "*"

$LblPassHP = New-Object System.Windows.Forms.Label
$LblPassHP.Text = "Contraseña HP:"; $LblPassHP.Location = New-Object System.Drawing.Point(15, 170); $LblPassHP.AutoSize = $true

$TxtPassHP = New-Object System.Windows.Forms.TextBox
$TxtPassHP.Location = New-Object System.Drawing.Point(170, 167)
$TxtPassHP.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$TxtPassHP.Width = 240; $TxtPassHP.PasswordChar = "*"

# --- CAJA DE CONTRASEÑA DOMINIO (Comentada hasta que la necesites) ---
# $LblPassDom = New-Object System.Windows.Forms.Label
# $LblPassDom.Text = "Contraseña Dominio:"; $LblPassDom.Location = New-Object System.Drawing.Point(15, 205); $LblPassDom.AutoSize = $true
# $TxtPassDom = New-Object System.Windows.Forms.TextBox
# $TxtPassDom.Location = New-Object System.Drawing.Point(170, 202)
# $TxtPassDom.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
# $TxtPassDom.Width = 240; $TxtPassDom.PasswordChar = "*"
# Descomentar la linea de abajo para agregarla visualmente al grupo:
# $GroupId.Controls.AddRange(@($LblPassDom, $TxtPassDom))

$GroupId.Controls.AddRange(@($ChkReinicio, $ChkFase2, $LblEmpresa, $ComboEmpresa, $LblPrefijo, $TxtPrefijo, $LblPassSys, $TxtPassSys, $LblPassHP, $TxtPassHP))

# --- PANEL SEGURIDAD E IMPRESORAS ---
$GroupSeg = New-Object System.Windows.Forms.GroupBox
$GroupSeg.Text = "Seguridad, Limpieza e Impresoras"
$GroupSeg.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
$GroupSeg.Bounds = New-Object System.Drawing.Rectangle(10, 260, 440, 370)

$ChkBitLocker = New-Object System.Windows.Forms.CheckBox
$ChkBitLocker.Text = "Cifrar con BitLocker"; $ChkBitLocker.Location = New-Object System.Drawing.Point(15, 30); $ChkBitLocker.AutoSize = $true; $ChkBitLocker.Checked = $true

$ChkVPN = New-Object System.Windows.Forms.CheckBox
$ChkVPN.Text = "Perfiles VPN (FortiClient)"; $ChkVPN.Location = New-Object System.Drawing.Point(230, 30); $ChkVPN.AutoSize = $true; $ChkVPN.Checked = $true

$ChkMcAfee = New-Object System.Windows.Forms.CheckBox
$ChkMcAfee.Text = "Purgar McAfee"; $ChkMcAfee.Location = New-Object System.Drawing.Point(15, 65); $ChkMcAfee.AutoSize = $true; $ChkMcAfee.Checked = $true

$ChkEset = New-Object System.Windows.Forms.CheckBox
$ChkEset.Text = "Instalar ESET"; $ChkEset.Location = New-Object System.Drawing.Point(230, 65); $ChkEset.AutoSize = $true; $ChkEset.Checked = $true

$ChkCrowd = New-Object System.Windows.Forms.CheckBox
$ChkCrowd.Text = "Instalar CrowdStrike"; $ChkCrowd.Location = New-Object System.Drawing.Point(15, 100); $ChkCrowd.AutoSize = $true; $ChkCrowd.Checked = $true

$LblCID = New-Object System.Windows.Forms.Label
$LblCID.Text = "CID:"; $LblCID.Location = New-Object System.Drawing.Point(15, 135); $LblCID.AutoSize = $true

$TxtCID = New-Object System.Windows.Forms.TextBox
$TxtCID.Location = New-Object System.Drawing.Point(60, 132)
$TxtCID.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$TxtCID.Width = 350; $TxtCID.Text = "ABC123XYZ"
$ChkCrowd.Add_CheckedChanged({ $TxtCID.Enabled = $this.Checked })

$LblImpresorasTxt = New-Object System.Windows.Forms.Label
$LblImpresorasTxt.Text = "IDs manuales (Ej: 1,3 o T):"; $LblImpresorasTxt.Location = New-Object System.Drawing.Point(15, 175); $LblImpresorasTxt.AutoSize = $true

$TxtImpresoras = New-Object System.Windows.Forms.TextBox
$TxtImpresoras.Location = New-Object System.Drawing.Point(170, 172)
$TxtImpresoras.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$TxtImpresoras.Width = 240

$LblImpresorasLista = New-Object System.Windows.Forms.Label
$LblImpresorasLista.Text = "Seleccionar Impresoras:"; $LblImpresorasLista.Location = New-Object System.Drawing.Point(15, 210); $LblImpresorasLista.AutoSize = $true

$ChkTodasImpresoras = New-Object System.Windows.Forms.CheckBox
$ChkTodasImpresoras.Text = "Marcar TODAS"; $ChkTodasImpresoras.Location = New-Object System.Drawing.Point(170, 208); $ChkTodasImpresoras.AutoSize = $true
$ChkTodasImpresoras.ForeColor = [System.Drawing.Color]::DodgerBlue

$ListaCheckImpresoras = New-Object System.Windows.Forms.CheckedListBox
$ListaCheckImpresoras.Location = New-Object System.Drawing.Point(170, 230)
$ListaCheckImpresoras.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
$ListaCheckImpresoras.Width = 240; $ListaCheckImpresoras.Height = 120
$ListaCheckImpresoras.CheckOnClick = $true
$ListaCheckImpresoras.Items.AddRange($ListaDinamicaImpresoras)

$ChkTodasImpresoras.Add_CheckedChanged({
    for ($i = 0; $i -lt $ListaCheckImpresoras.Items.Count; $i++) { $ListaCheckImpresoras.SetItemChecked($i, $this.Checked) }
})

$GroupSeg.Controls.AddRange(@($ChkBitLocker, $ChkVPN, $ChkMcAfee, $ChkEset, $ChkCrowd, $LblCID, $TxtCID, $LblImpresorasTxt, $TxtImpresoras, $LblImpresorasLista, $ChkTodasImpresoras, $ListaCheckImpresoras))

# --- ZONA DE GUARDADO Y NOMBRE DE ARCHIVO ---
$LblArchivo = New-Object System.Windows.Forms.Label
$LblArchivo.Text = "Nombre del Archivo:"; $LblArchivo.Location = New-Object System.Drawing.Point(15, 645); $LblArchivo.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left; $LblArchivo.AutoSize = $true

$TxtArchivo = New-Object System.Windows.Forms.TextBox
$TxtArchivo.Location = New-Object System.Drawing.Point(140, 642)
$TxtArchivo.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$TxtArchivo.Width = 175; $TxtArchivo.ForeColor = [System.Drawing.Color]::Gray; $TxtArchivo.Text = "Opcional (Ej: Equipo01)"
$TxtArchivo.Add_Enter({ if ($this.ForeColor.Name -eq "Gray") { $this.Text = ""; $this.ForeColor = [System.Drawing.Color]::Black } })
$TxtArchivo.Add_Leave({ if ([string]::IsNullOrWhiteSpace($this.Text)) { $this.Text = "Opcional (Ej: Equipo01)"; $this.ForeColor = [System.Drawing.Color]::Gray } })

$LblExtension = New-Object System.Windows.Forms.Label
$LblExtension.Text = "_AutoDespliegue.json"; $LblExtension.Location = New-Object System.Drawing.Point(320, 645)
$LblExtension.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right; $LblExtension.AutoSize = $true; $LblExtension.ForeColor = [System.Drawing.Color]::DarkGray

# --- BOTÓN GENERAR ---
$BtnGenerar = New-Object System.Windows.Forms.Button
$BtnGenerar.Text = "Generar Archivo de AutoDespliegue"
$BtnGenerar.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$BtnGenerar.Bounds = New-Object System.Drawing.Rectangle(10, 680, 440, 50)
$BtnGenerar.BackColor = [System.Drawing.Color]::DodgerBlue
$BtnGenerar.ForeColor = [System.Drawing.Color]::White
$BtnGenerar.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

$BtnGenerar.Add_Click({

    # ========================================================
    # MOTOR RSA (CANDADO PUBLICO) - DESCOMENTAR PARA ACTIVAR
    # ========================================================
    # $ClavePublicaXML = "<RSAKeyValue><Modulus>PEGAR_AQUI_EL_XML_CORTO</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>"
    # $RSA_Cifrado = New-Object System.Security.Cryptography.RSACryptoServiceProvider
    # $RSA_Cifrado.FromXmlString($ClavePublicaXML)
    #
    # function Cifrar-RSA ($Texto) {
    #     if ([string]::IsNullOrWhiteSpace($Texto)) { return $null }
    #     $BytesTexto = [System.Text.Encoding]::UTF8.GetBytes($Texto)
    #     $BytesCifrados = $RSA_Cifrado.Encrypt($BytesTexto, $false)
    #     return [Convert]::ToBase64String($BytesCifrados)
    # }

    $InstalarTodas = $false
    $ImpresorasArray = @()
    $TextoImp = $TxtImpresoras.Text.Trim()

    if ($TextoImp -match "^[tT]$") {
        $InstalarTodas = $true
    } elseif (-not [string]::IsNullOrWhiteSpace($TextoImp)) {
        $TextoImp -split "," | ForEach-Object { try { $ImpresorasArray += [int]$_.Trim() } catch {} }
    } else {
        if ($ListaCheckImpresoras.CheckedItems.Count -eq $ListaCheckImpresoras.Items.Count -and $ListaCheckImpresoras.Items.Count -gt 0) {
            $InstalarTodas = $true
        } else {
            foreach ($index in $ListaCheckImpresoras.CheckedIndices) { $ImpresorasArray += ($index + 1) }
        }
    }

    $PrefijoFinal = if ($TxtPrefijo.ForeColor.Name -eq "Gray" -or [string]::IsNullOrWhiteSpace($TxtPrefijo.Text)) { $null } else { $TxtPrefijo.Text.Trim() }

    $DatosJson = [ordered]@{
        Despliegue = @{ AutoReinicio = $ChkReinicio.Checked; ContinuarFase2 = $ChkFase2.Checked }
        Identidad = @{
            PrefijoEquipo = $PrefijoFinal
            DivisionEmpresa = [int]$ComboEmpresa.Text.Substring(0,1)
            PasswordSistemas = if ($TxtPassSys.Text) { $TxtPassSys.Text } else { $null }
            PasswordHP = if ($TxtPassHP.Text) { $TxtPassHP.Text } else { $null }
            
            # --- CUANDO ACTIVES RSA, DESCOMENTA LA LÍNEA DE ABAJO ---
            # PasswordDominio = Cifrar-RSA $TxtPassDom.Text
        }
        Limpieza = @{ DesinstalarMcAfee = $ChkMcAfee.Checked; LimpiarBloatware = $true }
        Seguridad = @{
            ActivarBitLocker = $ChkBitLocker.Checked
            ConfigurarVPN = $ChkVPN.Checked
            InstalarEset = $ChkEset.Checked
            InstalarCrowdStrike = $ChkCrowd.Checked
            CID_CrowdStrike = if ($ChkCrowd.Checked -and $TxtCID.Text) { $TxtCID.Text.Trim() } else { $null }
        }
        Impresoras = @{ InstalarTodas = $InstalarTodas; ImpresorasId = $ImpresorasArray }
    }

    $NombrePersonalizado = if ($TxtArchivo.ForeColor.Name -eq "Gray" -or [string]::IsNullOrWhiteSpace($TxtArchivo.Text)) { "" } else { $TxtArchivo.Text.Trim() + "_" }
    $RutaGuardado = "$PSScriptRoot\${NombrePersonalizado}AutoDespliegue.json"
    
    $DatosJson | ConvertTo-Json -Depth 5 | Out-File -FilePath $RutaGuardado -Encoding UTF8 -Force
    
    $MensajeAviso = "JSON generado exitosamente en:`n$RutaGuardado`n`n[!] IMPORTANTE:`nAsegúrate de que este archivo esté en la raíz de tu PENDRIVE de maquetado o en C:\Deploy_Plenergy para que el script lo detecte automáticamente."
    [System.Windows.Forms.MessageBox]::Show($MensajeAviso, "Modo Autónomo Plenergy", 0, [System.Windows.Forms.MessageBoxIcon]::Information)
    $Form.Close()
})

$Form.Controls.AddRange(@($GroupId, $GroupSeg, $LblArchivo, $TxtArchivo, $LblExtension, $BtnGenerar))
$Form.ShowDialog() | Out-Null