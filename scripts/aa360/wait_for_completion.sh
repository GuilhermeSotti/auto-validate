# Aguarda a conclusão da execução do bot
#
# Variáveis esperadas:
#   AA_API_URL
#   aaToken
#   runId
#   RUN_TIMEOUT

set -euo pipefail

echo "⏳ Aguardando conclusão do runId=${runId} (timeout ${RUN_TIMEOUT}s)..."

elapsed=0
while (( elapsed < RUN_TIMEOUT )); do
  status=$(curl -s "${AA_API_URL}/runs/${runId}" \
    -H "Authorization: Bearer ${aaToken}" \
    | jq -r .status)
  echo "Status atual: $status"
  if [[ "$status" == "Completed" || "$status" == "Failed" ]]; then
    break
  fi
  sleep 10
  elapsed=$(( elapsed + 10 ))
done

if [[ "$status" != "Completed" ]]; then
  echo "❌ Execução finalizada com status '$status'"
  exit 1
fi

echo "✅ Execução concluída com sucesso"
