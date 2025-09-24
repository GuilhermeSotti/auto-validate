"""
Autenticação PAC CLI e Azure CLI (robusta para pipelines com federated/OIDC).
"""
from __future__ import annotations

import shutil
import logging
from typing import Optional

from bot_cab.utils.run import run_command
from azure.identity import DefaultAzureCredential

logger = logging.getLogger(__name__)

def get_token(
    environment_url: str
) -> str:
    """
    Retorna um token a ser usado como federated token.
    - Se id_token já foi fornecido, retorna ele (não loga).
    - Caso contrário, tenta obter via AzurePipelinesCredential (quando disponível),
      ou via AzureCliCredential como fallback.
    """
    
    try:
        logger.info("Tentando obter token com AzurePipelinesCredential (OIDC).")
        cred = DefaultAzureCredential()
        tk = cred.get_token(f"{environment_url}/.default")
        logger.info(f"Token obtido via AzurePipelinesCredential. {tk.token}")
        return tk.token
    except Exception as e:
        logger.warning("Falha ao obter token via AzurePipelinesCredential: %s", e)

    raise RuntimeError(
        "Não foi possível obter federated token automaticamente. "
        "Forneça 'id_token' via variável de ambiente (e.g. idToken / ID_TOKEN / AZURE_FEDERATED_TOKEN) "
        "ou cheque as credenciais do agente."
    )


def authenticate_pac_cli(
    environment_name: str,
    pac_auth_mode: str = "standard",
    application_id: Optional[str] = None,
    tenant_id: Optional[str] = None
) -> None:
    """
    Autentica o PAC CLI para o environment dado.
    - pac_auth_mode: 'standard' ou 'federated'
    - Para 'federated' tenta usar id_token (se fornecido) ou obter token via AzurePipelinesCredential/AzureCliCredential.
    """

    if not shutil.which("pac"):
        logger.error("PAC CLI ('pac') não encontrado no PATH.")
        raise RuntimeError("Instale o PAC CLI e assegure-se de que 'pac' esteja no PATH.")

    try:
        current = run_command(["pac", "auth", "who"])
    except Exception:
        current = ""
    if environment_name and (environment_name in current):
        logger.debug("PAC CLI já autenticado para %s", environment_name)
        return

    if pac_auth_mode == "federated":
        cmd = [
            "pac", "auth", "create",
            "--name", environment_name,
            "--applicationId", application_id,
            "--tenant", tenant_id,
            "--azureDevOpsFederated",
        ]
    else:
        cmd = [
            "pac", "auth", "create", 
            "--name", environment_name
        ]

    try:
        logger.debug("Executando comando pac auth create (nome=%s).", environment_name)
        run_command(cmd, capture_output=False)
        try:
            run_command(["pac", "auth", "select", "--name", environment_name], capture_output=False)
        except Exception:
            logger.warning("Falha ao selecionar profile PAC '%s' (talvez já esteja selecionado).", environment_name)
    except Exception as e:
        logger.exception("Falha ao criar/selecionar profile PAC: %s", e)
        raise

    logger.info("PAC CLI autenticado/profile criado para %s", environment_name)


def authenticate_az_cli() -> None:
    """
    Verifica se a Azure CLI está disponível e mostra a conta atual; lança se não estiver.
    """
    if not shutil.which("az"):
        logger.error("Azure CLI ('az') não encontrado no PATH.")
        raise RuntimeError("Instale o Azure CLI e assegure-se de que 'az' esteja no PATH.")

    try:
        out = run_command(["az", "account", "show"], capture_output=True)
        logger.debug("Azure CLI account show OK.")
        return out
    except Exception as e:
        logger.exception("Falha ao executar 'az account show': %s", e)
        raise
