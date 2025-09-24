import logging
import os

from bot_cab.utils.auth import authenticate_az_cli, get_token
from bot_cab.output.csv_export import CSVExporter
from bot_cab.processing.dataverse_client import DataverseClient

logger = logging.getLogger("bot_cab.logs")


def run_logs(args) -> int:
    """
    Subcomando `logs`:
      1) autentica no Azure CLI
      2) obtém token Dataverse via get_token()
      3) recupera action-by-action logs via Processor.get_action_logs()
      4) exporta em CSV com CSVExporter
    """

    logger.info("Iniciando exportação de logs da sessão %s", args.flow_session_id)

    try:
        authenticate_az_cli()
    except Exception as e:
        logger.error("Falha ao autenticar Azure CLI: %s", e, exc_info=True)
        return 1

    proc = DataverseClient(args.environment_url, args.tenant_id)

    try:
        token = get_token(
            environment_url=args.environment_url
        )
        os.environ["AZURE_AUTH_ACCESS_TOKEN"] = token
        actions = proc.get_action_logs(args.flow_session_id)
    except Exception as e:
        logger.error("Erro ao obter logs action-by-action: %s", e, exc_info=True)
        return 1

    try:
        exporter = CSVExporter(actions, args.export_path, args.flow_session_id)
        exporter.export_csv()
    except Exception as e:
        logger.error("Falha ao exportar CSV: %s", e, exc_info=True)
        return 1

    logger.info("Logs exportados com sucesso em '%s_%s.csv'", args.export_path, args.flow_session_id)
    return 0
