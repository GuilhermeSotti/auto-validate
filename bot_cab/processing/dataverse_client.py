"""
DataverseClient: obtém logs action-by-action via REST usando Azure CLI token.
"""

import logging
import requests
from typing import Any, Dict, List

from bot_cab.utils.auth import get_token, authenticate_az_cli

logger = logging.getLogger(__name__)

class DataverseClient:
    """
    Cliente para chamadas REST ao Dataverse.
    """

    def __init__(self,
                 env_url: str,
                 tenant_id: str):
        self.env_url = env_url
        self.tenant_id = tenant_id

    def get_action_logs(self, session_id: str, timeout: int = 30) -> List[Dict[str, Any]]:
        """
        Retorna a lista de 'actions' de uma Flow Session via API REST.
        """
        authenticate_az_cli()
        token = get_token(
            environment_url=self.env_url
        )

        url = f"{self.env_url}/api/data/v9.2/flowsessions({session_id})/additionalcontext/$value"

        headers = {
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "Content-Type": "application/json; charset=utf-8",
            "OData-MaxVersion": "4.0",
            "OData-Version": "4.0"
        }

        logger.debug("Requisitando action logs: %s", url)
        resp = requests.get(url, headers=headers, timeout=timeout)
        resp.raise_for_status()

        try:
            data = resp.json()
            return data.get("actions", [])
        except ValueError:
            logger.error("Falha ao decodificar JSON de action logs")
            return []
