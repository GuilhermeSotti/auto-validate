"""
Gera e salva relatório Markdown (versão simples e direta).
"""

import logging
from pathlib import Path
from typing import List, Union, Dict, Any
from bot_cab.processing.rules_engine import IssueGroup

logger = logging.getLogger(__name__)

class MarkdownResponseBuilder:
    def __init__(self, output_path: str) -> None:
        self.output_path = Path(output_path)

    def build(self, results: List[Union[dict, str]], issues: List[List[IssueGroup]]) -> None:
        normalized = self._normalize_results(results)
        md = self.render_markdown(normalized, issues)
        self.save(md)

    def _normalize_results(self, results: List[Union[dict, str]]) -> List[Dict[str, Any]]:
        out: List[Dict[str, Any]] = []
        for r in results:
            if isinstance(r, dict):
                out.append(r)
            else:
                out.append({
                    "desktop_flow": str(r),
                    "session_id": "N/A",
                    "start_time": "N/A",
                    "actions": []
                })
        return out

    def render_markdown(self, results: List[Dict[str, Any]], issues: List[List[IssueGroup]]) -> str:
        lines: List[str] = ["# Relatório Bot_CAB\n"]

        for result, issue in zip(results, issues):
            flow = result.get("desktop_flow", "N/A")
            sess = result.get("session_id", "N/A")
            ts = result.get("start_time", "N/A")
            actions = result.get("actions", []) or []

            lines += [f"## Flow: {flow}", f"- Session ID: {sess}", f"- Início: {ts}", ""]
            lines += ["### Actions", "|Name|Status|Início|Fim|", "|---|---|---|---|"]
            for a in actions:
                if isinstance(a, dict):
                    lines.append(
                        f"|{a.get('systemActionName','')}|{a.get('status','')}|{a.get('startTime','')}|{a.get('endTime','')}|"
                    )
                else:
                    lines.append(f"|{str(a)}||||")
            lines.append("")

            if issue:
                lines.append("### ⚠️ Issues")
                for grp in issue:
                    if isinstance(grp, IssueGroup):
                        category = grp.category
                        messages = grp.get_messages()
                    else:
                        category = str(grp)
                        messages = []
                    lines.append(f"#### {category}")
                    if messages:
                        for msg in messages:
                            lines.append(f"- {msg}")
                    else:
                        lines.append("- (sem mensagens)")
                    lines.append("")
            else:
                lines.append("### ✅ Nenhuma Issue Encontrada\n")

        return "\n".join(lines)

    def save(self, content: str) -> None:
        self.output_path.parent.mkdir(parents=True, exist_ok=True)
        self.output_path.write_text(content, encoding="utf-8")
        logger.info("Relatório salvo em %s", self.output_path)
