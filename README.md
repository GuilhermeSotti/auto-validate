# Bot_CAB

> Ferramenta CLI para análise de Solutions e Desktop Flows no Power Platform  
> Gera relatórios em Markdown e exporta logs em CSV, integrada a pipelines Azure DevOps.

---

## 🚀 Visão Geral

- **analisar**  
  - Descompacta a Solution (.zip)  
  - Busca última execução de cada Desktop Flow (FetchXML + PAC CLI)  
  - Coleta logs action-by-action via API REST (Dataverse)  
  - Aplica um conjunto de regras (naming, segurança, estrutura)  
  - Gera relatório Markdown (`MarkdownResponseBuilder`)  
  - (Opcional) exporta CSV de logs (`CSVExporter`)

- **logs**  
  - Exporta apenas os logs de uma sessão específica em CSV.

---

## 📦 Instalação

1. Clone o repositório:  
   ```bash
   git clone https://seurepositorio/vale-devops/bot_cab.git
   cd bot_cab
   ```

2. Prepare um ambiente Python 3.8+:  
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   ```

3. (Opcional) Instale localmente:  
   ```bash
   pip install -e .
   ```

---

## ⚙️ Uso

### Help geral

```bash
python3 -m bot_cab.main --help
```

### Análise de solução

```bash
python3 -m bot_cab.main analisar   --environment-url    "https://meuorg.crm.dynamics.com"   --environment-name   "DEV"   --application-id     "<APP_ID>"   --tenant-id          "<TENANT_ID>"   --pac-auth-mode      federated   --solution-name      "MinhaSolution"   --solution-zip-path  "./build/MinhaSolution.zip"   --output-markdown    "./reports/MinhaSolution.md"   --export-path        "./reports/logs"
```

### Exportar logs de sessão

```bash
python3 -m bot_cab.main logs   --environment-url   "https://meuorg.crm.dynamics.com"   --flow-session-id   "<SESSION_ID>"   --export-path       "./reports/logs.csv"
```

---

## 🔧 Pipeline Azure DevOps

O template `templates/validate.yml` invoca:

```yaml
- task: AzureCLI@2
  inputs:
    azureSubscription: ${{ parameters.connAzTask }}
    addSpnToEnvironment: true
    scriptType: bash
    scriptLocation: inlineScript
    inlineScript: |
      chmod +x scripts/validate/run_analysis.sh
      scripts/validate/run_analysis.sh \
        --solution-name    "${{ parameters.solutionName }}" \
        --environment-url  "${{ parameters.environmentUrlDev }}" \
        --environment-name "${{ parameters.environmentName }}" \
        --application-id   "${{ parameters.appId }}" \
        --output-dir       "${{ parameters.artifactDir }}" \
        --base-dir         "${{ parameters.directory }}"
  env:
    PAC_ADO_ID_TOKEN_REQUEST_TOKEN: $(System.AccessToken)
    PAC_ADO_ID_TOKEN_REQUEST_URL: >-
      $(System.OidcRequestUri)?serviceConnectionId=${{ parameters.conn }}&api-version=7.2-preview.1
    SERVICE_PRINCIPAL_ID: ${{ parameters.appIdAz }}
```

Ele gera:
- Artefato `solution-analysis` com relatório Markdown em `$(output-dir)/solutions/<solution>/resumo_<solution>.md`
- Variável `hasIssues=true|false` para controle de fluxo.

---

## 📂 Estrutura do Projeto

```
bot_cab/
├─ cli/
│  └─ input_handler.py
├─ commands/
│  ├─ analyze_cmd.py
│  └─ logs_cmd.py
├─ config/
│  ├─ constants.py
│  └─ enums.py
├─ processing/
│  ├─ fetchxml_client.py
│  ├─ dataverse_client.py
│  ├─ processor.py
│  ├─ analyze.py
│  └─ rules_engine.py
├─ output/
│  ├─ csv_exporter.py
│  └─ md_builder.py
└─ utils/
   ├─ run.py
   ├─ auth.py
   ├─ io.py
   └─ tempdir.py
```

---

## 🧪 Testes (próximos passos)

- Adicionar testes unitários com **pytest** para:
  - `RulesEngine` (cada `_check_*`)  
  - `FetchXmlClient` (mock de `run_command`)  
  - `DataverseClient` (mock de `requests`)  
  - `Processor` (integração de clientes)  

---

## 📄 Licença

MIT © Vale
