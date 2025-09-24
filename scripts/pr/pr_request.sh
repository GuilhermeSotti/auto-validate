set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "ERRO: solutionName obrigatório. Uso: $0 <solutionName> [baseBranch]"
  exit 2
fi

SOLUTION_NAME="$1"
BASE="${2:-main}"
BRANCH="pr/${SOLUTION_NAME}"

REQUESTED_FOR="${BUILD_REQUESTEDFOR:-}"
REQUESTED_FOR_EMAIL="${BUILD_REQUESTEDFOREMAIL:-}"
REQUESTED_BY="${BUILD_REQUESTEDBY:-}"
BUILD_ID="${BUILD_BUILDID:-local}"

GIT_NAME="${REQUESTED_FOR:-${REQUESTED_BY:-Azure Pipelines CI}}"
GIT_EMAIL="${REQUESTED_FOR_EMAIL:-build@azuredevops}"
if [ -z "$GIT_EMAIL" ] && [ -n "$REQUESTED_BY" ]; then
  GIT_EMAIL="${REQUESTED_BY}@noreply"
fi

git config user.name  "$GIT_NAME"
git config user.email "$GIT_EMAIL"

echo "==> Fetch remoto..."
git fetch --prune origin

BASE_REF=$(git rev-parse --verify "origin/${BASE}" 2>/dev/null || true)
if [ -z "$BASE_REF" ]; then
  echo "ERRO: não foi possível encontrar origin/${BASE}. Abortando."
  exit 3
fi

echo "==> Adicionando tudo ao index (incluindo arquivos não rastreados)..."
git add -A

COMMIT_MSG="Pipeline changes for ${SOLUTION_NAME} (Build ${BUILD_ID})"

TREE_HASH=$(git write-tree)
BASE_TREE_HASH=$(git rev-parse "origin/${BASE}^{tree}")

if [ "$TREE_HASH" = "$BASE_TREE_HASH" ]; then
  echo "==> Nenhuma alteração detectada em relação ao origin/${BASE}. Criando commit vazio (checkpoint)..."
  NEW_COMMIT=$(echo "${COMMIT_MSG} (empty commit - checkpoint)" | \
    GIT_AUTHOR_NAME="$GIT_NAME" GIT_AUTHOR_EMAIL="$GIT_EMAIL" git commit-tree "$BASE_TREE_HASH" -p "$BASE_REF")
else
  echo "==> Criando commit com a árvore atual e parent origin/${BASE}..."
  NEW_COMMIT=$(echo "${COMMIT_MSG}" | \
    GIT_AUTHOR_NAME="$GIT_NAME" GIT_AUTHOR_EMAIL="$GIT_EMAIL" git commit-tree "$TREE_HASH" -p "$BASE_REF")
fi

echo "==> Commit criado: $NEW_COMMIT"

git update-ref "refs/heads/${BRANCH}" "$NEW_COMMIT"

echo "==> Detalhes do commit criado:"
git --no-pager show --name-status --pretty=format:"Commit: %H%nAuthor: %an <%ae>%nDate: %ad%nMessage: %s%n" "$NEW_COMMIT"

echo "==> Push forçado para origin/$BRANCH"
git push -u origin "refs/heads/${BRANCH}:refs/heads/${BRANCH}" --force

echo "##vso[task.setvariable variable=PR_BRANCH_CREATED]true"
echo "##vso[task.setvariable variable=PR_BRANCH_NAME]${BRANCH}"

echo "==> Branch '${BRANCH}' pronta no remoto (apontando para commit $NEW_COMMIT)."