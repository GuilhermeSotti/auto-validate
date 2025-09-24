# -----------------------------------------------------------------------------
# Exporta uma solução gerenciada do Power Platform:
# - Autentica no Azure & PAC CLI (federated)
# - Define versão
# - Exporta, cria settings, unpack, sanitiza e pack
#
# PARÂMETROS:
#   --solution-name    Nome da solução
#   --source-dir       Diretório de checkout
#   --output-dir       Diretório de staging de artefatos
# -----------------------------------------------------------------------------
set -euo pipefail
trap 'echo "❌ Erro no script em linha $LINENO"; exit 1' ERR

while [[ $# -gt 0 ]]; do
  case $1 in
    --solution-name)    solName="$2";    shift 2;;
    --owner-solution)   ownerSolution="$2"; shift 2;;
    --source-dir)       srcDir="$2";     shift 2;;
    --output-dir)       outDir="$2";     shift 2;;
    *) echo "Parâmetro desconhecido: $1"; exit 1;;
  esac
done

: "${solName:?--solution-name é obrigatório}"
: "${srcDir:?--source-dir é obrigatório}"
: "${outDir:?--output-dir é obrigatório}"

timestamp="1.0.${BUILD_BUILDID}"
solSrc="${srcDir}/solutions/${solName}"
solOut="${outDir}/solutions/${solName}"
exportZip="$solSrc/${solName}_${timestamp}_managed_${timestamp}_${ownerSolution}.zip"
managedDir="$solOut/${solName}_managed"

mkdir -p "$solSrc" "$solOut"

echo "⬇️ Exportar solução gerenciada para $exportZip"
pac solution export \
  --name "$solName" \
  --path "$exportZip" \
  --managed true \
  --include autonumbering,calendar,customization,emailtracking,externalapplications,general,isvconfig,marketing,outlooksynchronization,relationshiproles,sales \
  --async

echo "⚙️ Criar deployment-settings.json"
pac solution create-settings \
  --solution-zip "$exportZip" \
  --settings-file "$solOut/deployment-settings.json"

echo "📂 Unpack solução gerenciada em $managedDir"
pac solution unpack \
  --zipfile "$exportZip" \
  --folder "$managedDir" \
  --packagetype Managed

echo "✨ Sanitizar XML (remover bytes nulos)"
find "$managedDir" -type f -name "*.xml" \
  -exec bash -c 'tr -d "\000" < "$0" > "$0.tmp" && mv "$0.tmp" "$0"' {} \;

echo "🔁 Packar solução gerenciada em ${solOut}/${solName}_managed.zip"
pac solution pack \
  --folder "$managedDir" \
  --zipfile "$solOut/${solName}_managed.zip" \
  --packagetype Managed

echo "✅ Exportação concluída com sucesso"