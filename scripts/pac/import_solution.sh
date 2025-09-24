# -----------------------------------------------------------------------------
# Importa solução managed e espera conclusão
# para o ambiente especificado
#
# PARÂMETROS:
#   --solution-name    Nome da solução
#   --env-to           Ambiente de destino
#   --solution-zip     Caminho para o arquivo ZIP da solução
#   --settings-file    Caminho para o arquivo de settings
#   --timeout          Tempo máximo de espera (em minutos)
# -----------------------------------------------------------------------------
set -euo pipefail
trap 'echo "❌ Erro na linha $LINENO"; exit 1' ERR

# Parâmetros
while [[ $# -gt 0 ]]; do
  case $1 in
    --solution-name) solName="$2";    shift 2;;
    --env-to)        envTo="$2";      shift 2;;
    --solution-zip)  solZip="$2";     shift 2;;
    --settings-file) settingsFile="$2"; shift 2;;
    --timeout)       timeoutMin="$2"; shift 2;;
    *) echo "Parâmetro inválido: $1"; exit 1;;
  esac
done

: "${solName:?--solution-name é obrigatório}"
: "${envTo:?--env-to é obrigatório}"
: "${solZip:?--solution-zip é obrigatório}"
: "${settingsFile:?--settings-file é obrigatório}"
: "${timeoutMin:-5}"

pac solution delete \
  --solution-name "$solName" \
  --environment "$envTo" || {
    echo "⚠️ Aviso: não foi possível deletar a solução '$solName' em '$envTo' (prosseguindo)."
  }
  
echo "🚀 Importando $solName em $envTo"
pac solution import \
  --path "$solZip" \
  --environment "$envTo" \
  --async \
  --force-overwrite \
  --publish-changes \
  --activate-plugins
  #--settings-file "$settingsFile"
