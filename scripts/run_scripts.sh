#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# run_local.sh
#
# Orquestrador para executar TODOS os scripts Bash localmente,
# usando autenticação Azure CLI standard (client secret ou interactive),
# e PAC CLI no modo 'standard' (client secret).
#
# Antes de rodar, exporte ou defina estas variáveis de ambiente:
#   AZURE_CLIENT_ID       (Service Principal AppId)
#   AZURE_CLIENT_SECRET   (Service Principal Secret)
#   AZURE_TENANT_ID       (Tenant ID)
#   ENV_NAME              (nome do ambiente Power Platform, ex: DEV)
#   ENV_URL               (URL do Dataverse, ex: https://meuorg.crm.dynamics.com)
#   SOLUTION_NAME         (nome da solution a exportar/importar)
#
# E ajuste caminhos abaixo se necessário.
# -----------------------------------------------------------------------------
set -euo pipefail
trap 'echo "❌ Erro na linha $LINENO"; exit 1' ERR

# ————————————————————————————————————————————————————————————————
# 1) Validação de variáveis de ambiente local
: "${AZURE_CLIENT_ID:?AZURE_CLIENT_ID não definido}"
: "${AZURE_CLIENT_SECRET:?AZURE_CLIENT_SECRET não definido}"
: "${AZURE_TENANT_ID:?AZURE_TENANT_ID não definido}"
: "${ENV_NAME:?ENV_NAME não definido}"
: "${ENV_URL:?ENV_URL não definido}"
: "${SOLUTION_NAME:?SOLUTION_NAME não definido}"

echo "✅ Variáveis obrigatórias presentes:"
echo "   AZURE_CLIENT_ID=$AZURE_CLIENT_ID"
echo "   AZURE_TENANT_ID=$AZURE_CLIENT_ID"
echo "   ENV_NAME=$ENV_NAME"
echo "   ENV_URL=$ENV_URL"
echo "   SOLUTION_NAME=$SOLUTION_NAME"
echo

# Diretórios
SRC_DIR="$(pwd)"
OUT_DIR="${SRC_DIR}/_artifact_staging"
SCRIPTS_DIR="${SRC_DIR}/scripts/pac"
mkdir -p "$OUT_DIR"

# ————————————————————————————————————————————————————————————————
# 2) Login no Azure CLI (Service Principal ou interativo)
echo "🔐 Fazendo login no Azure CLI (Service Principal)…"
az login --service-principal \
  --username "$AZURE_CLIENT_ID" \
  --password "$AZURE_CLIENT_SECRET" \
  --tenant   "$AZURE_TENANT_ID" \
  --only-show-errors

echo "ℹ️ Conta logada:"
az account show --query "{name:name, user:user.name, tenantId:tenantId}" -o table
echo

# ————————————————————————————————————————————————————————————————
# 3) Autenticação no PAC CLI (standard)
echo "🔐 Autenticando PAC CLI no modo standard (Client Secret)…"
pac auth create \
  --name localAuth \
  --environment "$ENV_URL" \
  --applicationId "$AZURE_CLIENT_ID" \
  --clientSecret  "$AZURE_CLIENT_SECRET" \
  --tenant        "$AZURE_TENANT_ID"
pac auth select --name localAuth
echo "👤 Perfil PAC ativo:"
pac auth who
echo

# ————————————————————————————————————————————————————————————————
# 4) Pré-requisitos PAC (normalização de nomes e vars)
echo "➤ Executando pre_requisites_pac.sh"
bash "$SCRIPTS_DIR/pre_requisites_pac.sh" \
  --environment-name "$ENV_NAME" \
  --application-id   "$AZURE_CLIENT_ID" \
  --tenant-id        "$AZURE_TENANT_ID"
echo

# ————————————————————————————————————————————————————————————————
# 5) Exportar solução
echo "➤ Exportando solução Managed"
bash "$SCRIPTS_DIR/export_solution.sh" \
  --solution-name   "$SOLUTION_NAME" \
  --source-dir      "$SRC_DIR" \
  --output-dir      "$OUT_DIR" \
  --environment-url "$ENV_URL" \
  --application-id  "$AZURE_CLIENT_ID" \
  --tenant-id       "$AZURE_TENANT_ID"
echo

# ————————————————————————————————————————————————————————————————
# 6) Importar em QA
echo "➤ Importando solução em QA"
bash "$SCRIPTS_DIR/import_solution.sh" \
  --solution-name      "$SOLUTION_NAME" \
  --settings-file      "$OUT_DIR/deployment-settings.json" \
  --solution-zip-path  "$OUT_DIR/solutions/$SOLUTION_NAME/${SOLUTION_NAME}_1.0.${BUILD_BUILDID}.zip" \
  --environment-name-to "$ENV_NAME" \
  --environment-name-from "DEV" \
  --application-id     "$AZURE_CLIENT_ID" \
  --tenant-id          "$AZURE_TENANT_ID"
echo

# ————————————————————————————————————————————————————————————————
# 7) Compartilhar Apps e Flows
echo "➤ Compartilhando Apps e Flows"
bash "$SCRIPTS_DIR/share_apps_flows.sh" \
  --environment-name-to   "$ENV_NAME" \
  --environment-name-from "DEV" \
  --solution-name         "$SOLUTION_NAME" \
  --share-emails          "user1@contoso.com,user2@contoso.com" \
  --application-id        "$AZURE_CLIENT_ID" \
  --tenant-id             "$AZURE_TENANT_ID"
echo

# ————————————————————————————————————————————————————————————————
# 8) Validar solução em QA
echo "➤ Validando solução em QA"
bash "$SCRIPTS_DIR/validate_solution.sh" \
  --solution-name   "$SOLUTION_NAME" \
  --environment-url "$ENV_URL" \
  --environment-name "$ENV_NAME" \
  --application-id  "$AZURE_CLIENT_ID" \
  --tenant-id       "$AZURE_TENANT_ID" \
  --output-dir      "$OUT_DIR"
echo

# ————————————————————————————————————————————————————————————————
# 9) Criar Pull Request
echo "➤ Criando Pull Request"
bash "$SCRIPTS_DIR/pr_request.sh" \
  --solution-name "$SOLUTION_NAME" \
  --reviewers     "team@contoso.com"
echo

# ————————————————————————————————————————————————————————————————
# 10) Processar resultado do PR (sucesso simulado)
echo "➤ Processando resultado do PR"
bash "$SCRIPTS_DIR/pr_result.sh" \
  --solution-name "$SOLUTION_NAME" \
  --result-type    "success"
echo

echo "🎉 Execução local concluída com sucesso!"
