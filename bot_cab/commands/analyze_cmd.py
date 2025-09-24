import logging
from pathlib import Path
from bot_cab.utils.io import unzip_solution
from bot_cab.processing.processor import Processor
from bot_cab.processing.rules_engine import RulesEngine
from bot_cab.output.csv_export import CSVExporter
from bot_cab.output.md_builder import MarkdownResponseBuilder

def run_analysis(args) -> int:
    """
    Executa o fluxo de análise (subcomando `analisar`):
      1) descompacta a solution
      2) executa cada desktop flow via Processor
      3) aplica regras via RulesEngine
      4) gera CSVs opcionais e relatório Markdown
    Retorna 0 se nenhuma issue, 1 caso contrário.
    """
    logger = logging.getLogger("bot_cab.analyze")
    logger.info("Iniciando análise da Solution '%s'", args.solution_name)

    temp_dir = unzip_solution(args.solution_zip_path)
    logger.debug("Solution descompactada em %s", temp_dir)

    processor = Processor(args, temp_dir)

    all_issue_groups = []
    for flow in processor.get_desktop_flows_name():
        logger.info("Processando Desktop Flow: %s", flow)
        result = processor.process(flow)

        engine = RulesEngine(
            details=result["details"],
            actions=result["actions"],
            unzipped_folder=Path(temp_dir),
            prefix=result["prefix"],
        )
        groups, has_issues = engine.analyze_issues()
        all_issue_groups.append((result, groups, has_issues))

        if args.export_path:
            exporter = CSVExporter(result["actions"], args.export_path, flow)
            exporter.export_csv()

    md_builder = MarkdownResponseBuilder(args.output_markdown)
    results = [r for (r, _, _) in all_issue_groups]
    issues = [g for (_, g, _) in all_issue_groups]
    md_builder.build(results, issues)

    exit_code = 1 if any(has for (_, _, has) in all_issue_groups) else 0
    logger.info("Análise concluída. exit_code=%d", exit_code)
    return exit_code
