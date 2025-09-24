"""
Processor: orquestra fetchXML, Dataverse REST, unzip e retorno de resultados.
"""
import logging
from pathlib import Path
from dateutil import parser as date_parser

from bot_cab.utils.auth import authenticate_pac_cli, authenticate_az_cli
from bot_cab.processing.fetchxml_client import FetchXmlClient
from bot_cab.processing.dataverse_client import DataverseClient
from bot_cab.config.constants import FETCH_LAST_RUN_FILE, FETCH_LOGS_FILE

logger = logging.getLogger(__name__)

class Processor:
    def __init__(self, args, unzip_dir: Path):
        self.args = args
        self.unzip_dir = unzip_dir

        authenticate_pac_cli(
            environment_name=args.environment_name,
            pac_auth_mode=args.pac_auth_mode,
            application_id=args.application_id,
            tenant_id=args.tenant_id
        )
        authenticate_az_cli()

        self.fetch_client = FetchXmlClient(
            env_url=args.environment_url,
            run_cmd=lambda cmd: __import__("bot_cab.utils.run", fromlist=["run_command"]).run_command(cmd)
        )
        self.dataverse = DataverseClient(
            env_url=args.environment_url,
            tenant_id=args.tenant_id
        )

    def get_desktop_flows_name(self) -> list[str]:
        from xml.etree.ElementTree import parse
        cust = parse(self.unzip_dir / "customizations.xml").getroot()
        flows = [
            wf.attrib.get("Name").strip()
            for wf in cust.findall(".//Workflow")
            if wf.findtext("Category") == "6"
        ]
        logger.debug("Desktop flows encontrados: %s", flows)
        return flows

    def process(self, flow_name: str) -> dict:
        if not flow_name:
            raise ValueError("flow_name é obrigatório")

        raw_last = self.fetch_client.fetch(
            template_path=Path(FETCH_LAST_RUN_FILE),
            replacements={"flow_name": flow_name}
        )
        runs = self.fetch_client.parse_runs(raw_last)
        runs0 = runs["runs"][0]
        session_id = runs0["flowsessionid"]
        start_time = self._parse_datetime(runs0["startedon"])

        raw_logs = self.fetch_client.fetch(
            template_path=Path(FETCH_LOGS_FILE),
            replacements={"flow_name": flow_name, "session_id": session_id}
        )
        details = raw_logs.splitlines()

        actions = self.dataverse.get_action_logs(session_id)

        return {
            "desktop_flow": flow_name,
            "session_id": session_id,
            "start_time": start_time,
            "details": details,
            "actions": actions,
            "solution_xml": str(self.unzip_dir / "solution.xml"),
            "customizations_xml": str(self.unzip_dir / "customizations.xml"),
            "prefix": ""
        }

    def _parse_datetime(self, timestr: str) -> str:
        try:
            dt = date_parser.parse(timestr)
            return dt.strftime("%Y-%m-%d %H:%M:%S")
        except Exception:
            logger.warning("Falha ao parsear data '%s'", timestr)
            return timestr
