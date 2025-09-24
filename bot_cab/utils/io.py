"""
Operações de I/O (unzip de solução).
"""

import logging
import zipfile
from pathlib import Path

logger = logging.getLogger(__name__)

def unzip_solution(zip_path: Path, dest_dir: Path = None) -> Path:
    """
    Extrai zip_path em dest_dir (ou em um diretório temporário se None). Retorna o path usado.
    """
    if dest_dir is None:
        dest_dir = Path(zip_path).parent / "unzipped"
    logger.info("Descompactando %s em %s", zip_path, dest_dir)
    try:
        with zipfile.ZipFile(zip_path, 'r') as z:
            z.extractall(dest_dir)
    except zipfile.BadZipFile:
        logger.error("Arquivo ZIP inválido: %s", zip_path)
        raise
    return dest_dir
