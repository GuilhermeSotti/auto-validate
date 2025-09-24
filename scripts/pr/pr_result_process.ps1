<#
.SYNOPSIS
  Busca PR ativo e executa merge/abandon conforme resultado (versão robusta).
.PARAMETER Type
  'success' ou 'failed' (aceita variações: succes, ok, failure...)
.PARAMETER SolutionName
  Nome da solução (parte da branch). Ex: RPA_Center_Prova_de_Conceito
.PARAMETER OrgUrl, Project, Repo, TargetBranch
.PARAMETER PrId
  Opcional: se informado, usa diretamente este PR id (evita pesquisa).
#>
param(
  [Parameter(Mandatory=$true)][string]$Type,
  [Parameter(Mandatory=$true)][string]$SolutionName,
  [Parameter(Mandatory=$true)][string]$OrgUrl,
  [Parameter(Mandatory=$true)][string]$Project,
  [Parameter(Mandatory=$true)][string]$Repo,
  [Parameter(Mandatory=$true)][string]$TargetBranch,
  [int]$PrId
)

$ErrorActionPreference = 'Stop'

function Normalize-Type($t) {
  $s = $t.ToLower().Trim()
  switch ($s) {
    { $_ -in @('success','succes','ok','passed') } { return 'success' }
    { $_ -in @('fail','failed','failure','nok') } { return 'failed' }
    default { throw "Parâmetro -Type inválido: '$t'. Use 'success' ou 'failed'." }
  }
}

try {
  $Type = Normalize-Type $Type
  $srcBranch = "pr/$SolutionName"
  Write-Host "🔎 Procurando PR: $srcBranch → $TargetBranch (Type='$Type')"

  if ($PrId) {
    Write-Host "ℹ️ Usando PR explicitamente informado: $PrId"
    $PR = az repos pr show --id $PrId --org $OrgUrl --project $Project --repository $Repo -o json | ConvertFrom-Json
  } else {
    $maxAttempts = 6
    $attempt = 0
    $PR = $null
    while ($attempt -lt $maxAttempts -and -not $PR) {
      $attempt++
      $prJson = az repos pr list `
        --org $OrgUrl `
        --project $Project `
        --repository $Repo `
        --source-branch $srcBranch `
        --target-branch $TargetBranch `
        --status active `
        --query '[0]' -o json
      if ($prJson -and $prJson -ne 'null') {
        $PR = $prJson | ConvertFrom-Json
        break
      }
      Start-Sleep -Seconds (5 * $attempt)  # backoff incremental
    }

    if (-not $PR) {
      Write-Host "⚠️ Não foi encontrado PR com status 'active'. Fazendo fallback (status=all) ..."
      $allJson = az repos pr list `
        --org $OrgUrl `
        --project $Project `
        --repository $Repo `
        --source-branch $srcBranch `
        --target-branch $TargetBranch `
        --status all -o json
      $all = $allJson | ConvertFrom-Json
      if ($all -and $all.Count -gt 0) {
        $PR = $all | Sort-Object { [datetime]$_.creationDate } -Descending | Select-Object -First 1
        Write-Host "ℹ️ Fallback encontrou PR #$($PR.pullRequestId) com status '$($PR.status)' (creationDate=$($PR.creationDate))."
      } else {
        Write-Error "Nenhum PR (active ou all) encontrado para $srcBranch → $TargetBranch. Saída de 'az repos pr list --status all' era vazia."
      }
    }
  }

  if (-not $PR) {
    throw "Nenhum PR ativo encontrado (após retries e fallback)."
  }

  $PR_ID = $PR.pullRequestId
  $PR_STATUS = $PR.status
  Write-Host "✅ PR encontrado: #$PR_ID (status: $PR_STATUS, source: $($PR.sourceRefName))"

  if ($Type -eq 'success') {
    if ($PR_STATUS -eq 'active') {
      Write-Host "✅ Completando PR #$PR_ID (definindo auto-complete)..."
      az repos pr update `
        --id $PR_ID `
        --org $OrgUrl `
        --project $Project `
        --squash true `
        --auto-complete true `
        --merge-commit-message "Squash merge automatizado" | Out-Null
      Write-Host "✔️ Auto-complete definido para PR #$PR_ID"
    } elseif ($PR_STATUS -in @('completed','abandoned','merged')) {
      Write-Host "ℹ️ PR #$PR_ID já está com status '$PR_STATUS'. Nenhuma ação necessária."
    } else {
      Write-Host "ℹ️ PR #$PR_ID tem status '$PR_STATUS'. Definindo auto-complete de qualquer forma..."
      az repos pr update --id $PR_ID --org $OrgUrl --project $Project --auto-complete true | Out-Null
      Write-Host "✔️ Auto-complete definido."
    }
  } else {
    if ($PR_STATUS -eq 'active') {
      Write-Host "❌ Abandonando PR #$PR_ID..."
      az repos pr update `
        --id $PR_ID `
        --org $OrgUrl `
        --project $Project `
        --status abandoned `
        --delete-source-branch true | Out-Null
      Write-Host "✔️ PR #$PR_ID abandonado."
    } else {
      Write-Host "ℹ️ PR #$PR_ID não está ativo (status=$PR_STATUS). Nenhuma ação necessária para 'failed'."
    }
  }

  Write-Host "✔️ Ação no PR concluída com sucesso"
} catch {
  Write-Error "🛑 Falha ao processar PR: $_"
  exit 1
}
