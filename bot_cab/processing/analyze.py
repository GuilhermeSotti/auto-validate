"""
RulesEngine: aplica regras de validação à saída de Processor.
"""

import logging
from pathlib import Path
from typing import List, Tuple

from bot_cab.processing.rules_engine import (
    SubFlowIssues,
    ExecutionIssues,
    ValidationIssues,
    SolutionIssues,
    SecurityIssues,
    IssueGroup,
)

logger = logging.getLogger(__name__)

class RulesEngine:
    def __init__(self, result: dict, unzipped_folder: Path):
        required = ["details", "actions", "desktop_flow"]
        missing = [r for r in required if r not in result]
        if missing:
            raise ValueError(f"Faltam campos em result: {missing}")

        self.details = result["details"]
        self.actions = result["actions"]
        self.desktop_flow = result["desktop_flow"]
        self.unzipped_folder = unzipped_folder

        self.subflow_issues   = SubFlowIssues()
        self.execution_issues = ExecutionIssues()
        self.validation_issues= ValidationIssues()
        self.solution_issues  = SolutionIssues()
        self.security_issues  = SecurityIssues()

    def analyze_issues(self) -> Tuple[List[IssueGroup], bool]:
        logger.info("Analisando issues para flow %s", self.desktop_flow)
        self._check_execution()
        self._check_security()
        self._check_subflows()
        self._check_solution_structure()

        groups = [
            self.subflow_issues,
            self.execution_issues,
            self.validation_issues,
            self.solution_issues,
            self.security_issues,
        ]
        res = [g for g in groups if g]
        return res, bool(res)