"""
Execução segura de comandos externos.
"""

import logging
import shutil
import os
from subprocess import run, CalledProcessError
from typing import List, Optional

logger = logging.getLogger(__name__)

def run_command(cmd: List[str], capture_output: bool = True, env: Optional[dict] = None) -> str:
    """
    Executa comando sem shell=True. Retorna stdout ou lança CalledProcessError / FileNotFoundError.
    Usa shutil.which para localizar o executável e fornece logs úteis se não encontrado.
    """
    logger.debug("Executando comando: %s", cmd)

    exe = shutil.which(cmd[0])
    if exe is None:
        path_env = os.environ.get("PATH", "")
        logger.error("Executável '%s' não encontrado no PATH do processo.", cmd[0])
        logger.error("PATH atual (%d entradas):\n%s", len(path_env.split(os.pathsep)),
                     "\n".join(path_env.split(os.pathsep)))
        raise FileNotFoundError(f"Executável '{cmd[0]}' não encontrado no PATH do processo.")

    full_cmd = [exe] + list(cmd[1:])
    logger.debug("Comando resolvido para: %s", full_cmd)

    try:
        result = run(full_cmd, capture_output=capture_output, text=True, env=env, check=True)
    except FileNotFoundError:
        logger.exception("FileNotFoundError ao tentar executar: %s", full_cmd)
        raise
    except CalledProcessError as e:
        logger.error("Comando '%s' retornou código %s", full_cmd, e.returncode)
        logger.error("stdout:\n%s", e.stdout or "")
        logger.error("stderr:\n%s", e.stderr or "")
        raise

    out = result.stdout.strip() if capture_output else ""
    logger.debug("Saída: %s", out)
    return out