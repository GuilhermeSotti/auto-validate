# -----------------------------------------------------------------------------
# Wrapper que executa o Bot_CAB para análise de solução e seta variável hasIssues
# para indicar se houve problemas
#
# PARÂMETROS:
#   --solution-name    Nome da solução
#   --environment-url  URL do ambiente
#   --environment-name Nome do ambiente
#   --application-id   ID do aplicativo (PAC CLI)
#   --output-dir       Diretório de saída para relatórios
#   --base-dir         Diretório base para soluções
# -----------------------------------------------------------------------------

set -euo pipefail
trap 'echo "❌ Erro no script em linha $LINENO"; exit 1' ERR

# Parsing de parâmetros
while [[ $# -gt 0 ]]; do
  case $1 in
    --solution-name)    solName="$2"; shift 2;;
    --environment-url)  envUrl="$2"; shift 2;;
    --environment-name) envName="$2"; shift 2;;
    --application-id)   appId="$2"; shift 2;;
    --output-dir)       outDir="$2"; shift 2;;
    --base-dir)         baseDir="$2"; shift 2;;
    *) echo "Parâmetro desconhecido: $1"; exit 1;;
  esac
done

: "${solName:?--solution-name é obrigatório}"
: "${envUrl:?--environment-url é obrigatório}"
: "${envName:?--environment-name é obrigatório}"
: "${appId:?--application-id é obrigatório}"
: "${outDir:?--output-dir é obrigatório}"
: "${baseDir:?--base-dir é obrigatório}"

reportDir="${outDir}/solutions/${solName}"
pathZip="${baseDir}/bot_cab/solutions/${solName}/${solName}_managed.zip"

mkdir -p "$reportDir"

echo "🔄 Iniciando análise da solução '$solName' no ambiente '$envName'"
python3 -m bot_cab.main analisar \
  --environment-url  "$envUrl" \
  --environment-name "$envName" \
  --application-id   "$appId" \
  --tenant-id        "$tenantId" \
  --pac-auth-mode    federated \
  --solution-name    "$solName" \
  --solution-zip-path "$pathZip" \
  --output-markdown  "${reportDir}/resumo_${solName}.md" \
  --export-path      "" 

exit_code=$?

if (( exit_code == 1 )); then
  echo "##vso[task.setvariable variable=hasIssues]true"
elif (( exit_code == 0 )); then
  echo "##vso[task.setvariable variable=hasIssues]false"
else
  echo "##vso[task.setvariable variable=hasIssues]true"
fi

exit $exit_code