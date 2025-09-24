# -----------------------------------------------------------------------------
# Instala pip e requisitos Python de forma robusta
# -----------------------------------------------------------------------------
set -euo pipefail
trap 'echo "❌ Erro no script em linha $LINENO"; exit 1' ERR

while [[ $# -gt 0 ]]; do
  case $1 in
    --requirements-path)
      reqPath="$2"; shift 2;;
    *) echo "Parâmetro desconhecido: $1"; exit 1;;
  esac
done

echo "📣 Iniciando diagnóstico de Python/pip..."

echo ">>> which python:"
which python || which python3 || true
echo ">>> python --version:"
python --version 2>&1 || true

echo ">>> pip --version:"
pip --version 2>&1 || true
echo ">>> python -m pip --version:"
python -m pip --version 2>&1 || true

if [[ ! -f "$reqPath" ]]; then
  echo "❌ requirements.txt não encontrado em: $reqPath"
  ls -la "$(dirname "$reqPath")" || true
  exit 1
fi

echo "🔄 Instalando requisitos com o mesmo Python que será usado (python -m pip)"
python -m pip install --upgrade pip --disable-pip-version-check --no-cache-dir || {
  echo "⚠️ Falha ao atualizar pip (continuando tentativa de instalação)"
}
python -m pip install --no-cache-dir -r "$reqPath" --upgrade --force-reinstall || {
  echo "❌ pip install retornou erro. Verifique logs acima."
}