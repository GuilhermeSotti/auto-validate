"""
Context manager para TemporaryDirectory.
"""

from tempfile import TemporaryDirectory
from pathlib import Path
from contextlib import contextmanager

@contextmanager
def create_tempdir(prefix: str = "sol_"):
    with TemporaryDirectory(prefix=prefix) as td:
        yield Path(td)
