set -euo pipefail
trap 'echo "❌ Erro no script em linha $LINENO"; exit 1' ERR

usage() {
  echo "Uso: $0 --environment-name <nome> --application-id <AppId> --tenant-id <TenantId>"
  exit 2
}

# Parser de argumentos
while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment-name) environmentName="$2"; shift 2;;
    --application-id)   appId="$2";          shift 2;;
    --tenant-id)        tenantIdArg="$2";    shift 2;;
    *) echo "Parâmetro desconhecido: $1"; usage;;
  esac
done

: "${environmentName:?--environment-name é obrigatório}"
: "${appId:?--application-id é obrigatório}"
: "${tenantIdArg:?--tenant-id é obrigatório}"

environmentDev=$(printf "%s" "$environmentName" | tr ' ' '_' | awk '{ print toupper($0) }')
IFS='_' read -r prefix envGroup envType <<<"$environmentDev"
isCitizen=false
if [[ "${envGroup^^}" == "CITIZEN" ]]; then
  isCitizen=true
fi

envQA="${prefix}_${envGroup}_QA"
envProd="${prefix}_${envGroup}_PRD"

echo "environmentDev=$environmentDev"
echo "prefix=$prefix"
echo "envGroup=$envGroup"
echo "envType=$envType"
echo "isCitizen=$isCitizen"
echo "envQA=$envQA"
echo "envProd=$envProd"

who_json="$(pac env who --json 2>/dev/null || pac org who --json 2>/dev/null || true)"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq não encontrado — instalando jq..."
  sudo apt-get update -y
  sudo apt-get install -y jq
fi

if [[ -n "${who_json// /}" && "${who_json}" != "null" ]]; then
  echo "➡️ Informações do profile ativo obtidas via 'pac ... who'."
  currentUrl=$(printf "%s" "$who_json" | jq -r '
    .Url // .url
    // .OrganizationUrl // .organizationUrl // .OrgUrl // .orgUrl
    // .WebApiUrl // .webApiUrl // .environmentUrlDev // .environmentUrlDev
    // ""
  ' 2>/dev/null || true)
  if [[ -z "$currentUrl" ]]; then
    currentUrl=$(printf "%s" "$who_json" | jq -r '
      ( . | paths(scalars) as $p | (getpath($p) | select(type=="string")) ) 
      | select(test("https?://")) 
      | . 
      | first
    ' 2>/dev/null || true)
  fi

  currentUrl=$(printf "%s" "$currentUrl" | tr -d '\r')
  echo "Profile URL detectado: ${currentUrl:-<vazio>}"
else
  echo "⚠️ 'pac ... who' não retornou dados válidos. Iremos tentar a listagem global com 'pac admin list --json'."
  currentUrl=""
fi

if [[ -n "$currentUrl" ]]; then
  devUrl="$currentUrl"
  qaUrl=""
  prodUrl=""
else

  envs_json="$(pac admin list --json 2>/dev/null || pac org list --json 2>/dev/null || echo '[]')"

  find_url_from_admin() {
    local target="$1"
    if [[ -z "$target" ]]; then
      echo ""
      return
    fi
    printf "%s" "$envs_json" | jq -r --arg name "$target" '
      map( . as $it |
        { nm: ( ($it.name // $it.displayName // $it.uniqueName // $it.uniquename) | tostring ), obj: $it }
      )
      | map(select((.nm|ascii_upcase) == ($name|ascii_upcase)))
      | .[0]?.obj
      | (.url // .environmentUrlDev // .Url // .crmUrl // .ApiUrl // .webApiUrl) // ""
    ' 2>/dev/null || true
  }

  devUrl="$(find_url_from_admin "$environmentDev" | tr -d '\r')"
  qaUrl="$(find_url_from_admin "$envQA" | tr -d '\r')"
  prodUrl="$(find_url_from_admin "$envProd" | tr -d '\r')"
fi

if [[ -n "$currentUrl" ]]; then
  envs_json="$(pac admin list --json 2>/dev/null || pac org list --json 2>/dev/null || echo '[]')"
  if [[ -n "${envs_json// /}" && "${envs_json}" != "null" ]]; then
    find_url_from_admin() {
      local target="$1"
      if [[ -z "$target" ]]; then
        echo ""
        return
      fi
      printf "%s" "$envs_json" | jq -r --arg name "$target" '
        map( . as $it |
          { nm: ( ($it.name // $it.displayName // $it.uniqueName // $it.uniquename) | tostring ), obj: $it }
        )
        | map(select((.nm|ascii_upcase) == ($name|ascii_upcase)))
        | .[0]?.obj
        | (.url // .environmentUrlDev // .Url // .crmUrl // .ApiUrl // .webApiUrl) // ""
      ' 2>/dev/null || true
    }
    qaUrl="$(find_url_from_admin "$envQA" | tr -d '\r')"
    prodUrl="$(find_url_from_admin "$envProd" | tr -d '\r')"
  fi
fi

devUrl="${devUrl:-}"
qaUrl="${qaUrl:-}"
prodUrl="${prodUrl:-}"

echo "Dev URL  : ${devUrl:-<não encontrado>}"
echo "QA URL   : ${qaUrl:-<não encontrado>}"
echo "Prod URL : ${prodUrl:-<não encontrado>}"

set +x

echo "##vso[task.setvariable variable=environmentDev;isOutput=true]$environmentDev"
echo "##vso[task.setvariable variable=isCitizen;isOutput=true]$isCitizen"
echo "##vso[task.setvariable variable=envQA;isOutput=true]$envQA"
echo "##vso[task.setvariable variable=envProd;isOutput=true]$envProd"
echo "##vso[task.setvariable variable=environmentUrlDev;isOutput=true]$devUrl"
echo "##vso[task.setvariable variable=environmentUrlDevQA;isOutput=true]$qaUrl"
echo "##vso[task.setvariable variable=environmentUrlDevPRD;isOutput=true]$prodUrl"

set -x

echo "✅ URLs resolvidas e variáveis expostas."