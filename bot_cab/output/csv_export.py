"""
Exporta logs de ações para CSV (robusto contra keys variáveis entre linhas).
"""

import csv
import json
import logging
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Dict, Any, Union

logger = logging.getLogger(__name__)

def _sanitize_filename(name: str) -> str:
    safe = re.sub(r"[^\w\-\. ]+", "_", name)
    safe = re.sub(r"\s+", "_", safe).strip("_")
    return safe or "export"

@dataclass
class CSVExporter:
    actions: List[Dict[Any, Any]]
    output_dir: Union[Path, str]
    desktop_flow: str
    _filename: Path = field(init=False)

    def __post_init__(self) -> None:
        if not isinstance(self.output_dir, Path):
            self.output_dir = Path(self.output_dir)

        self.output_dir.mkdir(parents=True, exist_ok=True)

        safe = _sanitize_filename(self.desktop_flow)
        self._filename = self.output_dir / f"{safe}.csv"

    def _normalize_row_keys(self, row: Dict[Any, Any]) -> Dict[str, Any]:
        """
        Converte keys para str e serializa valores complexos (dict/list) para JSON.
        """
        norm: Dict[str, Any] = {}
        for k, v in row.items():
            key = str(k)
            if isinstance(v, (dict, list)):
                try:
                    norm[key] = json.dumps(v, ensure_ascii=False)
                except Exception:
                    norm[key] = str(v)
            else:
                norm[key] = v
        return norm

    def export_csv(self) -> None:
        if not self.actions:
            logger.warning("Nenhum dado para exportar para CSV.")
            return

        normalized_rows: List[Dict[str, Any]] = []
        fieldnames_set = set()
        for idx, row in enumerate(self.actions):
            if not isinstance(row, dict):
                logger.warning("Ignorando action[%d]: não é dict: %r", idx, row)
                continue
            norm = self._normalize_row_keys(row)
            normalized_rows.append(norm)
            fieldnames_set.update(norm.keys())

        if not normalized_rows:
            logger.warning("Após normalização não há linhas válidas para exportar.")
            return

        fieldnames = sorted(fieldnames_set)

        try:
            self._filename.parent.mkdir(parents=True, exist_ok=True)
            with self._filename.open("w", newline="", encoding="utf-8") as f:
                w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
                w.writeheader()
                for idx, row in enumerate(normalized_rows):
                    safe_row = {k: row.get(k, "") for k in fieldnames}
                    try:
                        w.writerow(safe_row)
                    except Exception as e:
                        logger.error("Falha ao gravar linha %d no CSV: %s — linha: %r", idx, e, row)
            logger.info("CSV salvo em %s", self._filename)
        except Exception as e:
            logger.error("Falha ao gravar CSV: %s", e)
            raise
