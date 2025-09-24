"""
FetchXmlClient: lida com templates FetchXML e invocação do PAC CLI.
"""

import logging
from pathlib import Path
import xml.etree.ElementTree as ET
from typing import Callable, Dict

logger = logging.getLogger(__name__)

class FetchXmlClient:
    """
    Cliente para executar fetchxml via PAC CLI e parsear resultados básicos.
    """

    def __init__(self, env_url: str, run_cmd: Callable[[list[str], bool], str]):
        self.env_url = env_url
        self.run_cmd = run_cmd

    def fetch(self, template_path: Path, replacements: Dict[str, str]) -> str:
        """
        Carrega o template XML, aplica substituições e executa:
          pac env fetch --environment <env_url> --xmlFile <temp_file>
        Retorna o stdout cru.
        """
        tree = ET.parse(template_path)
        root = tree.getroot()

        for key, val in replacements.items():
            attr = "name" if key == "flow_name" else "flowsessionid"
            for cond in root.findall(f".//condition[@attribute='{attr}']"):
                cond.set("value", val)

        tree.write(template_path, encoding="utf-8", xml_declaration=True)

        logger.debug("Executando FetchXML: %s", template_path)
        result = self.run_cmd([
            "pac", "env", "fetch",
            "--environment", self.env_url,
            "--xmlFile", str(template_path)
        ])
        return result

    def parse_runs(self, raw: str) -> dict:
        """
        Converte a saída bruta em JSON-Python via regex e retorna dict com key 'runs'.
        """
        import re
        pattern = re.compile(r"([A-Fa-f0-9-]{35,36})\s+(\d{1,2}/\d{1,2}/\d{4}\s+\d{1,2}:\d{2}\s+(?:AM|PM))?")
        runs = []
        for line in raw.splitlines():
            m = pattern.search(line)
            if m:
                runs.append({
                    "flowsessionid": m.group(1),
                    "startedon": m.group(2) or ""
                })
        return {"runs": runs}
