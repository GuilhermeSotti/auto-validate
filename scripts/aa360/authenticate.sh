#
# Autentica na API do AA360 e exporta token para Azure DevOps
#
# Variáveis esperadas:
#   AA_API_URL
#   AA_CLIENT_ID
#   AA_CLIENT_SECRET

set -euo pipefail

echo "🔒 Autenticando no AA360..."

response=$(curl -s -X POST "${AA_API_URL}/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"clientId\":\"${AA_CLIENT_ID}\",\"clientSecret\":\"${AA_CLIENT_SECRET}\"}")

token=$(echo "${response}" | jq -r .token)
if [[ -z "$token" || "$token" == "null" ]]; then
  echo "❌ Falha ao obter token de autenticação"
  echo "Response: $response"
  exit 1
fi

echo "##vso[task.setvariable variable=aaToken;issecret=true]${token}"
echo "✅ Autenticação bem-sucedida"
