#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# scripts/pac/test_connection.sh
#
# Script de diagnóstico completo para validar:
#  - variáveis de ambiente de OIDC do Azure DevOps
#  - Azure CLI service principal login
#  - endpoint OIDC do DevOps
#  - sessão PAC CLI (profiles & env)
#  - conexão ao Dataverse (pac env who)
#
# Uso:
#   chmod +x scripts/pac/test_connection.sh
#   scripts/pac/test_connection.sh \
#     --environment-name "<ENV_NAME>" \
#     --environment-url  "<ENV_URL>" \
#     --application-id   "<APP_ID>" \
#     --tenant-id        "<TENANT_ID>"
# -----------------------------------------------------------------------------
set -euo pipefail
trap 'echo "❌ Erro no script em linha $LINENO"; exit 1' ERR

usage() {
  cat <<EOF
Uso: $0 \\
  --environment-name <nome>   (ex: DEV, QA…)       \\
  --environment-url  <url>    (ex: https://<org>.crm.dynamics.com) \\
  --application-id   <appId>  (Service Principal) \\
  --tenant-id        <tenant> (Azure Tenant GUID) \\
EOF
  exit 2
}

# --- Parser de parâmetros ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment-name) envName="$2"; shift 2;;
    --environment-url)  envUrl="$2";  shift 2;;
    --application-id)   appId="$2";   shift 2;;
    --tenant-id)        tenantId="$2";shift 2;;
    *) echo "Parâmetro desconhecido: $1"; usage;;
  esac
done

# --- Validação de parâmetros ---
: "${envName:?--environment-name é obrigatório}"
: "${envUrl:?--environment-url é obrigatório}"
: "${appId:?--application-id é obrigatório}"
: "${tenantId:?--tenant-id é obrigatório}"

echo "===== Variáveis de Ambiente OIDC ====="
token="${SYSTEM_ACCESSTOKEN:-}"
echo "System.AccessToken length: ${#token}"
echo "PAC_ADO_ID_TOKEN_REQUEST_TOKEN: ${PAC_ADO_ID_TOKEN_REQUEST_TOKEN:-<não definida>}"
echo "PAC_ADO_ID_TOKEN_REQUEST_URL:   ${PAC_ADO_ID_TOKEN_REQUEST_URL:-<não definida>}"
echo "servicePrincipalId: ${servicePrincipalId:-<não definida>}"
echo "idToken:           ${idToken:-<não definida>}"
echo "tenantId:          ${tenantId:-<não definida>}"

# --- Teste de Service Principal no Azure AD ---
echo "===== Verificar Service Principal no Azure AD ====="
az ad sp show --id "$appId" --query "{appId:appId, displayName:displayName}" -o table || echo "❌ SP não encontrado ou sem acesso"

# --- Azure CLI account info ---
echo
echo "===== Sessão Azure CLI ativa ====="
az account show --query "{name:name, user:user.name, tenantId:tenantId}" -o table

# --- Teste do endpoint OIDC DevOps ---
echo
echo "===== Testar endpoint OIDC ====="
if curl -fs -H "Authorization: Bearer $SYSTEM_ACCESSTOKEN" \
       "$PAC_ADO_ID_TOKEN_REQUEST_URL" \
       -o /dev/null; then
  echo "✅ Endpoint OIDC respondeu sem erro (HTTP 2xx)"
else
  echo "❌ Falha ao acessar endpoint OIDC"
fi

# --- Login federado no Azure CLI (re-teste) ---
echo
echo "===== Login federado no Azure CLI ====="
az login --service-principal \
  --username "$servicePrincipalId" \
  --federated-token "$idToken" \
  --tenant "$tenantId" \
  --only-show-errors

# --- Autenticação PAC CLI federated ---
echo
echo "===== PAC CLI auth federated ====="
pac auth create \
  --name testProfile \
  --environment "$envName" \
  --applicationId "$appId" \
  --tenant "$tenantId" \
  --azureDevOpsFederated \
pac auth select --name testProfile

# --- Mostrar perfil ativo PAC CLI ---
echo
echo "===== PAC CLI profile ativo ====="
pac auth who

# --- Mostrar environment PAC CLI (Dataverse) ---
echo
echo "===== PAC CLI environment ativo ====="
pac env who --environment "$envName" --json | jq . || echo "❌ pac env who falhou"

# --- Teste de conexão simples via pac solution list (sem alterar nada) ---
echo
echo "===== Testar conexão Dataverse (listar soluções) ====="
if pac solution list --environment "$envName" --top 1 --query "[0].uniquename" -o tsv >/dev/null; then
  echo "✅ Conexão ao Dataverse bem-sucedida"
else
  echo "❌ Falha ao conectar ao Dataverse"
fi

echo
echo "🎉 Todos os testes concluídos."
