# ---------------------------------------------------------------------
# Cria/reseta client secrets e prepara ConnectionReferences + EnvironmentVariables
# - Se não encontrar applicationId na Service Connection, cria um App Registration automaticamente
# - Gera novo client secret e usa para criar/atualizar conexões via pac
# - Opcional: grava secret no Azure Key Vault (--keyvault)
#
# Uso:
#   scripts/pac/import_prep_connections.sh \
#     --env-from "<env URL>" \
#     --env-to "<env URL>" \
#     --settings-file "<deployment-settings.json>" \
#     --ado-service-connection "<service-connection-id>" \
#     [--application-id <appId>] \
#     [--tenant-id <tenantId>] \
#     [--app-display-name <displayNameForNewApp>] \
#     [--debug]
#
# Observações importantes:
# - Criar App Registration requer privilégios em Azure AD (Application Administrator / Global Admin etc.).
# - O script NÃO imprime o client secret nos logs. Use --keyvault para salvar o secret de maneira segura.
# - Use com cuidado em produção; revise permissões e política de governança do seu tenant.
# ---------------------------------------------------------------------
set -euo pipefail
trap 'echo "❌ Erro na linha $LINENO"; exit 1' ERR

# --- Helpers ---
die(){ echo "❌ $*" >&2; exit 1; }
info(){ echo "ℹ️  $*"; }
warn(){ echo "⚠️  $*" >&2; }
debug(){ if [[ "${DEBUG:-0}" == "1" ]]; then echo "DEBUG: $*" >&2; fi; }

# --- Parse args ---
envFrom=""
envTo=""
settingsFile=""
adoSC=""
APPLICATION_ID=""
TENANT_ID=""
APP_DISPLAY_NAME=""
DEBUG="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-from) envFrom="$2"; shift 2;;
    --env-to) envTo="$2"; shift 2;;
    --settings-file) settingsFile="$2"; shift 2;;
    --ado-service-connection) adoSC="$2"; shift 2;;
    --application-id) APPLICATION_ID="$2"; shift 2;;
    --tenant-id) TENANT_ID="$2"; shift 2;;
    --app-display-name) APP_DISPLAY_NAME="$2"; shift 2;;
    --debug) DEBUG="1"; shift 1;;
    -h|--help)
      cat <<EOF
Uso:
  $0 --env-from <ENV_FROM> --env-to <ENV_TO> --settings-file <FILE> --ado-service-connection <ID>
     [--application-id <APP_ID>] [--tenant-id <TENANT_ID>] 

Descrição:
  - Se application-id não for encontrado na Service Connection, o script criará um App Registration
    com display name informado por --app-display-name (ou "pipeline-auto-app-<ts>").
  - Gera novo client secret e usa para criar/atualizar conexões via pac.
EOF
      exit 0;;
    *) die "Parâmetro inválido: $1";;
  esac
done

: "${envFrom:?--env-from é obrigatório}"
: "${envTo:?--env-to é obrigatório}"
: "${settingsFile:?--settings-file é obrigatório}"
: "${adoSC:?--ado-service-connection é obrigatório}"

debug "envFrom=${envFrom} envTo=${envTo} settingsFile=${settingsFile} adoSC=${adoSC} APPLICATION_ID=${APPLICATION_ID} TENANT_ID=${TENANT_ID} APP_DISPLAY_NAME=${APP_DISPLAY_NAME}"

# --- Dependencies ---
command -v jq >/dev/null || die "🔧 jq não encontrado"
command -v az >/dev/null || die "🔧 az CLI não encontrado"
command -v pac >/dev/null || die "🔧 pac CLI não encontrado"

# --- Resolve AZDO_ORG / AZDO_PROJECT (fallbacks)
AZDO_ORG="${AZDO_ORG:-${SYSTEM_TEAMFOUNDATIONCOLLECTIONURI:-${System_CollectionUri:-}}}"
AZDO_PROJECT="${AZDO_PROJECT:-${SYSTEM_TEAMPROJECT:-${System.TeamProject:-}}}"
info "AZDO_ORG = ${AZDO_ORG:-<vazia>}"
info "AZDO_PROJECT = ${AZDO_PROJECT:-<vazio>}"

AZURE_DEVOPS_PAT="${SYSTEM_ACCESSTOKEN:-${SYSTEM_ACCESS_TOKEN:-}}"
if [[ -n "${AZURE_DEVOPS_PAT:-}" ]]; then
  export AZURE_DEVOPS_EXT_PAT="$AZURE_DEVOPS_PAT"
  debug "AZURE_DEVOPS_EXT_PAT length: ${#AZURE_DEVOPS_EXT_PAT}"
else
  warn "SYSTEM_ACCESS_TOKEN não disponível; az devops API pode falhar. Ative 'Allow scripts to access the OAuth token' no pipeline."
fi

info "🔐 Tentando obter Service Connection ${adoSC} do Azure DevOps..."
scJson=""
if az devops service-endpoint show --id "${adoSC}" --organization "${AZDO_ORG}" --project "${AZDO_PROJECT}" -o json >/tmp/__sc.json 2>/dev/null; then
  scJson="$(cat /tmp/__sc.json)"
  debug "ServiceConnection JSON: $(echo "$scJson" | jq -c '.' 2>/dev/null || true)"
else
  warn "Falha ao obter Service Connection via 'az devops service-endpoint show'. Seguindo para fallback/criação de App se necessário."
fi

sc_appid=""
sc_tenantid=""
if [[ -n "${scJson}" ]]; then
  sc_appid=$(echo "$scJson" | jq -r '.authorization.parameters.serviceprincipalid // .authorization.parameters.servicePrincipalId // .authorization.parameters.clientId // .authorization.parameters.appId // empty' 2>/dev/null || true)
  sc_tenantid=$(echo "$scJson" | jq -r '.authorization.parameters.tenantid // .authorization.parameters.tenantId // empty' 2>/dev/null || true)
fi

applicationId="${APPLICATION_ID:-${sc_appid:-}}"
tenantId="${TENANT_ID:-${sc_tenantid:-}}"

if [[ -z "$APP_DISPLAY_NAME" ]]; then
  TS=$(date +%s)
  APP_DISPLAY_NAME="pipeline-auto-app-${TS}"
fi

info "applicationId pré-determinado: ${applicationId:-<vazio>}"
info "tenantId pré-determinado: ${tenantId:-<vazio>}"

NEW_CLIENT_SECRET=""
CREATED_APP_ID=""
if [[ -z "$applicationId" ]]; then
  info "🔧 applicationId não encontrado na Service Connection. Criando um App Registration automaticamente..."
  debug "az ad app create --display-name \"$APP_DISPLAY_NAME\""
  CREATED_APP_ID=$(az ad app create --display-name "$APP_DISPLAY_NAME" --query appId -o tsv 2>/dev/null || true)

  if [[ -z "$CREATED_APP_ID" ]]; then
    die "Falha ao criar App Registration. Verifique permissões (Application Administrator/Global Admin) para criar App Registrations."
  fi
  info "✔️ App Registration criado: appId=$CREATED_APP_ID"
  az ad sp create --id "$CREATED_APP_ID" >/dev/null 2>&1 || true
  tenantId="${tenantId:-$(az account show --query tenantId -o tsv 2>/dev/null || true)}"
  if [[ -z "$tenantId" ]]; then
    warn "tenantId não determinado automaticamente; você pode fornecer --tenant-id. Continuando, mas pac/tenant calls podem exigir tenant."
  fi
  info "🔁 Gerando client secret para o App criado..."
  NEW_CLIENT_SECRET=$(az ad app credential reset --id "$CREATED_APP_ID" --append --years 2 --query password -o tsv 2>/dev/null || true)
  if [[ -z "$NEW_CLIENT_SECRET" ]]; then
    NEW_CLIENT_SECRET=$(az ad sp credential reset --name "$CREATED_APP_ID" --append --years 2 --query password -o tsv 2>/dev/null || true)
  fi
  if [[ -z "$NEW_CLIENT_SECRET" ]]; then
    die "Falha ao gerar client secret para o App criado. Verifique permissões e políticas do AAD."
  fi
  info "✔️ Novo client secret gerado para o App criado (não exibido por segurança)."
  applicationId="$CREATED_APP_ID"
fi

if [[ -n "${APPLICATION_ID:-}" && -z "${CLIENT_SECRET:-}" && -z "${NEW_CLIENT_SECRET:-}" ]]; then
  info "🔁 Gerando (reset) client secret para applicationId fornecido (${APPLICATION_ID})..."
  NEW_CLIENT_SECRET=$(az ad app credential reset --id "${APPLICATION_ID}" --append --years 2 --query password -o tsv 2>/dev/null || true)
  if [[ -z "$NEW_CLIENT_SECRET" ]]; then
    NEW_CLIENT_SECRET=$(az ad sp credential reset --name "${APPLICATION_ID}" --append --years 2 --query password -o tsv 2>/dev/null || true)
  fi
  if [[ -z "$NEW_CLIENT_SECRET" ]]; then
    die "Não foi possível gerar client secret para applicationId fornecido. Verifique permissões."
  fi
  applicationId="${APPLICATION_ID}"
  info "✔️ Novo client secret gerado (não exibido)."
fi

if [[ -n "${CLIENT_SECRET:-}" ]]; then
  debug "CLIENT_SECRET fornecido via env; usando-o em vez do secret gerado."
  PROVIDED_CLIENT_SECRET="$CLIENT_SECRET"
  USE_CLIENT_SECRET="${CLIENT_SECRET}"
else
  USE_CLIENT_SECRET="${NEW_CLIENT_SECRET:-}"
fi

if [[ -z "$USE_CLIENT_SECRET" ]]; then
  die "client secret não disponível. Forneça CLIENT_SECRET como variável do pipeline ou permita criar/reset automático (verifique permissões)."
fi

info "✔️ applicationId que será usada: $applicationId"
debug "tenantId a usar: ${tenantId:-<vazio>}"

info "🔁 Processando ConnectionReferences do arquivo $settingsFile"
if [[ ! -f "$settingsFile" ]]; then
  die "Arquivo $settingsFile não encontrado"
fi

mapfile -t connEntries < <(jq -c '.ConnectionReferences[]' "$settingsFile" 2>/dev/null || true)
if [[ "${#connEntries[@]}" -eq 0 ]]; then
  warn "Nenhuma ConnectionReference encontrada no settings file."
fi

for entry in "${connEntries[@]}"; do
  _jq() { echo "$entry" | jq -r "$1"; }

  logicalName=$(_jq '.LogicalName')
  connectorId=$(_jq '.ConnectorId')

  info "🔍 ConnectionReference: $logicalName ($connectorId)"

  existingTable=$(pac connection list --environment "$envFrom" 2>/dev/null || true)
  debug "pac connection list raw (primeiras linhas):"
  debug "$(printf '%s\n' "$existingTable" | sed -n '1,8p')"

  connId=$(echo "$existingTable" | tail -n +3 | awk -v cid="$connectorId" '$0 ~ cid { print $1; exit }' || true)
  if [[ -z "$connId" ]]; then
    connId=$(echo "$existingTable" | tail -n +3 | awk -v name="$logicalName" '$2==name { print $1; exit }' || true)
  fi

  if [[ -z "$connId" ]]; then
    info "🔗 Conexão não encontrada; criando: $logicalName"
    if pac connection create \
      --environment "$envFrom" \
      --tenant-id "${tenantId:-}" \
      --name "$logicalName" \
      --application-id "$applicationId" \
      --client-secret "$USE_CLIENT_SECRET" \
      >/dev/null 2>&1; then
      info "✔️ pac connection create concluído para $logicalName"
    else
      die "Falha ao criar connection via pac. Verifique se o conector aceita autenticação por Service Principal e se o Application User existe no Dataverse."
    fi

    existingTable=$(pac connection list --environment "$envFrom")
    connId=$(echo "$existingTable" | tail -n +3 | awk -v name="$logicalName" '$2==name { print $1; exit }' || true)
  else
    info "🔁 Conexão existente encontrada (id $connId). Tentando atualizar com novo secret..."
    if pac connection update --id "$connId" \
         --environment "$envFrom" \
         --application-id "$applicationId" \
         --client-secret "$USE_CLIENT_SECRET" \
         --tenant-id "${tenantId:-}" >/dev/null 2>&1; then
      info "✔️ pac connection update concluído para $logicalName"
    else
      warn "pac connection update falhou; não será recriada automaticamente para evitar impacto. Atualize manualmente no Power Platform Admin Center se necessário."
    fi
  fi

  if [[ -z "$connId" ]]; then
    die "Não foi possível obter connId para $logicalName após tentativas."
  fi

  tmp=$(mktemp)
  jq --arg ln "$logicalName" --arg id "$connId" \
    '(.ConnectionReferences[] | select(.LogicalName==$ln) | .ConnectionId) |= $id' \
    "$settingsFile" > "$tmp" && mv "$tmp" "$settingsFile"

  info "🔗 ConnectionReference '$logicalName' atualizada no settings-file -> connId=$connId"
done

info "🔄 Atualizando EnvironmentVariables"
existingEVs=$(pac env fetch --environment "$envTo" --xml "<fetch version='1.0' mapping='logical' no-lock='true'><entity name='environmentvariablevalue'><attribute name='schemaname'/><attribute name='value'/></entity></fetch>" 2>/dev/null || true)
debug "existingEVs preview: $(echo "$existingEVs" | head -n 5 | sed -n '1,5p' || true)"

for entry in $(jq -r '.EnvironmentVariables[] | @base64' "$settingsFile"); do
  _jq() { echo "$entry" | base64 --decode | jq -r "$1"; }
  schemaName=$(_jq '.SchemaName')

  value=$(echo "$existingEVs" | jq -r --arg sn "$schemaName" '.entities[] | select(.schemaname==$sn) | .value // empty' 2>/dev/null || true)

  if [[ -z "$value" ]]; then
    info "⚠️  EnvironmentVariable '$schemaName' não encontrada no ambiente destino; mantendo valor original no arquivo."
    continue
  fi

  info "🔗 Atualizando EnvironmentVariable: $schemaName -> (valor copiado do ambiente)"
  tmp=$(mktemp)
  jq --arg sn "$schemaName" --arg val "$value" \
    '(.EnvironmentVariables[] | select(.SchemaName==$sn) | .Value) |= $val' \
    "$settingsFile" > "$tmp" && mv "$tmp" "$settingsFile"
done

if [[ -n "${NEW_CLIENT_SECRET:-}" ]]; then
  unset NEW_CLIENT_SECRET || true
fi
if [[ -n "${USE_CLIENT_SECRET:-}" ]]; then
  unset USE_CLIENT_SECRET || true
fi
if [[ -n "${PROVIDED_CLIENT_SECRET:-}" ]]; then
  unset PROVIDED_CLIENT_SECRET || true
fi

info "✅ Processamento finalizado com sucesso."
info "🔔 Observações finais:"
info "  - applicationId usado: ${applicationId}"
if [[ -n "${CREATED_APP_ID:-}" ]]; then
  info "  - Um novo App Registration foi criado: ${CREATED_APP_ID}"
  info "  - Lembre-se de: adicionar esse App como 'Application User' no Dataverse (Power Platform Admin Center) e atribuir Role adequada."
fi

exit 0
