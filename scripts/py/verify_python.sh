# -----------------------------------------------------------------------------
# Verifica versões de Python e pip
# -----------------------------------------------------------------------------
set -euo pipefail
trap 'echo "❌ Erro no script em linha $LINENO"; exit 1' ERR

echo "🐍 Versão do Python:"
python --version

echo "📦 Versão do pip:"
pip --version

echo "✅ Verificação concluída"
