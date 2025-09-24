# Inicia uma execução do bot via API do AA360
#
# Variáveis esperadas:
#   AA_API_URL
#   aaToken
#   BOT_NAME

set -euo pipefail

echo "▶️ Iniciando execução do bot '${BOT_NAME}'..."

run_response=$(curl -s -X POST "${AA_API_URL}/runs" \
  -H "Authorization: Bearer ${aaToken}" \
  -H "Content-Type: application/json" \
  -d "{\"botName\":\"${BOT_NAME}\"}")

runId=$(echo "${run_response}" | jq -r .runId)
if [[ -z "$runId" || "$runId" == "null" ]]; then
  echo "❌ Falha ao iniciar execução do bot"
  echo "Response: $run_response"
  exit 1
fi

echo "##vso[task.setvariable variable=runId]${runId}"
echo "✅ Bot em execução: runId=${runId}"