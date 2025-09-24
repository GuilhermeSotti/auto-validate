# -----------------------------------------------------------------------------
# Compartilha Apps e Flows, e reaplica ConnectionRefs
# e EnvironmentVariables para o ambiente de destino
#
# PARÂMETROS:
#   --solution-name    Nome da solução
#   --env-from         Ambiente de origem
#   --share-emails     Lista de emails separados por vírgula para compartilhar
# -----------------------------------------------------------------------------
set -euo pipefail
trap 'echo "❌ Erro na linha $LINENO"; exit 1' ERR

# Parâmetros
while [[ $# -gt 0 ]]; do
  case $1 in
    --solution-name) solName="$2";     shift 2;;
    --env-from)      envFrom="$2";     shift 2;;
    --share-emails)  shareCsv="$2";    shift 2;;
    *) echo "Param inválido: $1"; exit 1;;
  esac
done

: "${solName:?--solution-name é obrigatório}"
: "${envFrom:?--env-from é obrigatório}"
: "${shareCsv:?--share-emails é obrigatório}"

echo "🔄 Compartilhando Apps e Flows da solução '$solName' no ambiente '$envFrom'"
IFS=';' read -r -a emails <<< "$shareCsv"
for email in "${emails[@]}"; do
  echo "🔗 Compartilhando com: $email"
  userId=$(az ad user show --id "$email" --query id -o tsv)
  apps=$(pac canvas list --environment "$envFrom" --query "[?contains(DisplayName,'$solName')].AppName" -o tsv)
  for app in $apps; do
    echo "🔄 Compartilhando App: $app"
    pac canvas share --environment "$envFrom" --app "$app" --principal-object-id "$userId" --principal-type User --role CanUse
  done
  flows=$(pac flow list --environment "$envFrom" --query "[?contains(DisplayName,'$solName')].FlowName" -o tsv)
  for flow in $flows; do
    echo "🔄 Compartilhando Flow: $flow"
    pac flow share --environment "$envFrom" --flow "$flow" --principal-object-id "$userId" --principal-type User --role CanUse
  done
done

echo "✅ Recursos compartilhados"
