"""
Enumera categorias de issues detectadas pelo Bot_CAB.
"""

from enum import Enum
from typing import List

class IssueCategory(str, Enum):
    ACTION     = "Action"
    SUBFLOW    = "SubFlow"
    CONFIG     = "Config"
    EXECUTION  = "Execution"
    SOLUTION   = "Solution"
    SECURITY   = "Security"
    VALIDATION = "Validation"

    @classmethod
    def list(cls) -> List[str]:
        return [member.value for member in cls]
