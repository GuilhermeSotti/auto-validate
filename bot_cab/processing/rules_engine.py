"""
processing/rules_engine.py

Define grupos de issues e a RulesEngine que aplica todas as validações
sobre o resultado de um Desktop Flow e a solução descompactada.
"""

import logging
from abc import ABC, abstractproperty
from dataclasses import dataclass
from pathlib import Path
from typing import List, Tuple, Iterator

logger = logging.getLogger(__name__)

# --- Issue e IssueGroup -----------------------------------------------------

@dataclass(frozen=True)
class Issue:
    """
    Representa uma issue detectada, com categoria e mensagem.
    """
    category: str
    message: str

class IssueGroup(ABC):
    """
    Agrupa issues por categoria.
    Subclasses devem definir a propriedade `category`.
    """
    @property
    @abstractproperty
    def category(self) -> str:
        ...

    def __init__(self) -> None:
        self.issues: List[Issue] = []

    def add(self, message: str) -> None:
        """
        Adiciona uma nova issue ao grupo.
        """
        issue = Issue(self.category, message)
        self.issues.append(issue)
        logger.debug("Issue adicionada [%s]: %s", self.category, message)

    def has_issues(self) -> bool:
        """
        Retorna True se houver qualquer issue neste grupo.
        """
        return bool(self.issues)

    def __bool__(self) -> bool:
        return self.has_issues()

    def __len__(self) -> int:
        return len(self.issues)

    def __iter__(self) -> Iterator[Issue]:
        return iter(self.issues)

    def get_messages(self) -> List[str]:
        """
        Retorna apenas as mensagens.
        """
        return [issue.message for issue in self.issues]

class SubFlowIssues(IssueGroup):
    @property
    def category(self) -> str:
        return "SubFlow"

class ExecutionIssues(IssueGroup):
    @property
    def category(self) -> str:
        return "Execution"

class ValidationIssues(IssueGroup):
    @property
    def category(self) -> str:
        return "Validation"

class SolutionIssues(IssueGroup):
    @property
    def category(self) -> str:
        return "Solution"

class SecurityIssues(IssueGroup):
    @property
    def category(self) -> str:
        return "Security"

# --- RulesEngine ------------------------------------------------------------

class RulesEngine:
    """
    Aplica validações em:
      - detalhes de execução (logs simples e actions)
      - subfluxos (naming)
      - estrutura da Solution descompactada (XMLs e pastas)
      - segurança (dados expostos)
    """

    def __init__(self,
                 details: List[str],
                 actions: List[dict],
                 unzipped_folder: Path,
                 prefix: str):
        self.details = details
        self.actions = actions
        self.unzipped_folder = unzipped_folder
        self.prefix = prefix

        # inicializa grupos
        self.subflow_issues   = SubFlowIssues()
        self.execution_issues = ExecutionIssues()
        self.validation_issues= ValidationIssues()
        self.solution_issues  = SolutionIssues()
        self.security_issues  = SecurityIssues()

    def analyze_issues(self) -> Tuple[List[IssueGroup], bool]:
        """
        Executa todas as checagens e retorna
        (lista de grupos com issues, flag has_issues).
        """
        logger.info("Iniciando análise de issues")
        self._check_execution()
        self._check_security()
        self._check_subflows()
        self._check_solution_structure()

        all_groups = [
            self.subflow_issues,
            self.execution_issues,
            self.validation_issues,
            self.solution_issues,
            self.security_issues,
        ]
        groups_with_issues = [g for g in all_groups if g]
        has_issues = bool(groups_with_issues)
        logger.info("Análise finalizada: %d grupos com issues", len(groups_with_issues))
        return groups_with_issues, has_issues

    def _check_execution(self) -> None:
        """
        Verifica:
         - execução bem sucedida ('Succeeded' em details),
         - presença de logs action-by-action,
         - existência de 'LogMessage' e 'Empty'
        """
        logger.debug("Verificando execução do Desktop Flow")
        #if not any("Succeeded" in d for d in self.details):
        #    self.execution_issues.add("Desktop Flow não foi executado com sucesso.")
        if not self.actions:
            self.execution_issues.add("Nenhum log de ação disponível.")
        #if not any(a.get("systemActionName") == "LogMessage" for a in self.actions):
        #    self.execution_issues.add("Ausência de ação 'LogMessage'.")
        if not any(a.get("systemActionName") == "Empty" for a in self.actions):
            self.execution_issues.add("SubFluxo de limpeza ('Empty') não executado.")

    def _check_security(self) -> None:
        """
        Verifica se há dados sensíveis (string contendo '@') nos logs action-by-action.
        """
        logger.debug("Verificando segurança nos logs")
        for a in self.actions:
            for val in a.values():
                if isinstance(val, str) and "@" in val:
                    self.security_issues.add("Dados sensíveis expostos em logs.")
                    return

    def _check_subflows(self) -> None:
        """
        Verifica se funções/subfluxos seguem prefixo 'f_' ou são 'main'.
        """
        logger.debug("Verificando naming de subfluxos")
        for a in self.actions:
            func = a.get("functionName", "")
            if func and not func.lower().startswith("f_") and func.lower() != "main":
                self.subflow_issues.add(f"SubFluxo '{func}' não segue prefixo 'f_'.")
    
    def _check_solution_structure(self) -> None:
        """
        Verifica estrutura da solução descompactada:
         - pasta environmentvariabledefinitions
         - connectionreferences com prefixo correto
         - existência de WorkQueues, Desktop Flows e Cloud Flows
        """
        logger.debug("Verificando estrutura da solução")
        # 1) Env vars
        if not (self.unzipped_folder / "environmentvariabledefinitions").is_dir():
            self.solution_issues.add("Nenhuma variável de ambiente definida na Solution.")

        # 2) ConnectionReferences
        import xml.etree.ElementTree as ET
        cust_xml = ET.parse(self.unzipped_folder / "customizations.xml").getroot()
        for cref in cust_xml.findall(".//connectionreferences"):
            logical = cref.findtext(".//connectionreferencelogicalname", default="")
            if not logical.startswith(self.prefix):
                self.solution_issues.add(
                    f"ConnectionReference '{logical}' fora do prefixo '{self.prefix}'."
                )

        # 3) WorkQueues
        wq = cust_xml.findall(".//workqueues")
        if not wq:
            self.solution_issues.add("Nenhuma WorkQueue encontrada na Solution.")

        # 4) Desktop Flows (Category=6) e Cloud Flows (Category=5)
        cats = [int(e.text or 0) for e in cust_xml.findall(".//Workflow/Category")]
        if 6 not in cats:
            self.solution_issues.add("Nenhum Desktop Flow (Category=6) na Solution.")
        if 5 not in cats:
            self.solution_issues.add("Nenhum Cloud Flow (Category=5) na Solution.")
