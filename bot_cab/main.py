"""
Entry-point para o Bot_CAB CLI.
Define subcomandos 'analisar' e 'logs'.
"""

import sys
import logging

from bot_cab.cli.input_handler import CLIInputHandler
from bot_cab.commands.analyze_cmd import run_analysis
from bot_cab.commands.logs_cmd import run_logs

def setup_logging(verbose: bool) -> None:
    level = logging.DEBUG if verbose else logging.INFO
    fmt = "%(asctime)s %(levelname)s %(name)s: %(message)s"
    logging.basicConfig(level=level, format=fmt)

def main() -> int:
    handler = CLIInputHandler()
    args = handler.parse()
    setup_logging(args.verbose)
    logger = logging.getLogger("bot_cab")

    logger.debug("Parâmetros iniciais: %s", args)

    try:
        if args.command == "analisar":
            return run_analysis(args)
        elif args.command == "logs":
            return run_logs(args)
        else:
            handler.parser.error(f"Subcomando desconhecido: {args.command}")
    except Exception as e:
        logger.error("Erro fatal: %s", e, exc_info=True)
        return 2

if __name__ == "__main__":
    sys.exit(main())
