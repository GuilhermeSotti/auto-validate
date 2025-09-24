"""
Define a interface de linha de comando (CLI) do Bot_CAB.
"""

import argparse
class CLIInputHandler:
    def __init__(self) -> None:
        parser = argparse.ArgumentParser(
            prog="bot_cab",
            description="Bot_CAB: analisar solução Power Platform ou exportar logs"
        )
        parser.add_argument(
            "-v", "--verbose",
            action="store_true",
            help="habilita logs de depuração"
        )

        subparsers = parser.add_subparsers(
            dest="command",
            required=True,
            help="subcomando a executar"
        )

        # analisar
        pa = subparsers.add_parser("analisar", help="Analisa solução e gera relatório")
        auth = pa.add_argument_group("Autenticação")
        auth.add_argument("--environment-url",   dest="environment_url",   required=True)
        auth.add_argument("--environment-name",  dest="environment_name",  required=True)
        auth.add_argument("--application-id",    dest="application_id",    required=True)
        auth.add_argument("--tenant-id",         dest="tenant_id",         required=True)
        auth.add_argument("--pac-auth-mode",     dest="pac_auth_mode",
                          choices=["standard","federated"], default="standard")

        op = pa.add_argument_group("Operação")
        op.add_argument("--solution-name",       dest="solution_name",     required=True)
        op.add_argument("--solution-zip-path",   dest="solution_zip_path", required=True)
        op.add_argument("--output-markdown",     dest="output_markdown",   required=True)
        op.add_argument("--export-path",         dest="export_path")

        # logs
        pl = subparsers.add_parser("logs", help="Exporta logs de uma sessão de Flow")
        pl.add_argument("--environment-url",     dest="environment_url",   required=True)
        pl.add_argument("--flow-session-id",     dest="flow_session_id",   required=True)
        pl.add_argument("--export-path",         dest="export_path",       required=True)
        pl.add_argument("--pac-auth-mode",     dest="pac_auth_mode",
                          choices=["standard","federated"], default="standard")
        pl.add_argument("--tenant-id",         dest="tenant_id",         required=False)
        pl.add_argument("--environment-name",  dest="environment_name",  required=False)
        pl.add_argument("--id-token",          dest="id_token",          required=False)
        pl.add_argument("--application-id",    dest="application_id",    required=False)

        self.parser = parser

    def parse(self):
        args = self.parser.parse_args()
        if args.command == "analisar":
            if args.pac_auth_mode == "standard" and not args.application_id:
                self.parser.error("--application-id é obrigatório com pac-auth-mode=standard")
        return args
