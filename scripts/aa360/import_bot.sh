# Importa o .botpkg em um ambiente do AA360
#
# Variáveis esperadas:
#   AA_API_URL
#   aaToken
#   BOT_NAME
#   ENVIRONMENT
#   PIPELINE_WORKSPACE  # caminho base, ex.: $(Pipeline.Workspace)

set -euo pipefail

input_file="${PIPELINE_WORKSPACE}/bot/${BOT_NAME}.botpkg"

if [[ ! -f "$input_file" ]]; then
  echo "❌ Arquivo não encontrado: $input_file"
  exit 1
fi

echo "📥 Importando bot para ambiente '${ENVIRONMENT}'..."

curl -s -X POST "${AA_API_URL}/bots/import" \
  -H "Authorization: Bearer ${aaToken}" \
  -F "file=@${input_file}" \
  -F "environmentName=${ENVIRONMENT}" \
  | jq .

echo "✅ Importação concluída"
