<#
.SYNOPSIS
  Exibe banner de QA aprovado ou reprovado.
.PARAMETER Type
  'success' ou 'failed'.
#>
param(
  [Parameter(Mandatory)]
  [ValidateSet('success','failed')]
  [string]$Type
)
$ErrorActionPreference = 'Stop'
switch ($Type) {
  'success' { Write-Host "✅ QA aprovado. PR será mesclado."; break }
  'failed'  { Write-Host "❌ QA reprovado. PR será abandonado."; break }
}
