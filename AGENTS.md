# Repository Guidelines

## Project Structure & Module Organization
`lib/` houses the core orchestration modules (`Pipeline`, providers, steps, meta generator). Tests mirror the library under `test/` with `*_test.exs` suites and helper fixtures. YAML workflows live in `pipelines/`, while ready-to-run demos and scripts sit in `examples/` and `scripts/`. Generated artifacts such as `_build/`, `workspace/`, and `outputs/` are disposable and should stay out of commits. Reference documentation, diagrams, and long-form guides are collected under `docs/` and top-level `.md` briefs.

## Build, Test, and Development Commands
Run `mix deps.get` once per Elixir version upgrade to sync dependencies, followed by `mix compile` to verify clean builds. Execute `mix test` for the full suite; append `--cover` when checking coverage before a release. Use `mix credo --strict` for style checks and `mix dialyzer` to regenerate PLTs and surface type warnings (ensure `priv/plts/` is cached locally). `mix pipeline.run pipelines/demo.yaml` exercises end-to-end execution; reset state with `rm -rf workspace outputs` when needed. Generate docs locally via `mix docs`.

## Coding Style & Naming Conventions
Adopt idiomatic Elixir: two-space indentation, trailing commas in multi-line lists, and descriptive module names under the `Pipeline.*` namespace. Always format with `mix format` before committing. Keep YAML filenames snake_case describing their purpose (e.g., `research_paper_improvement_pipeline.yaml`). Module attributes label configuration constants; avoid magic strings in pipeline steps by extracting helper functions.

## Testing Guidelines
Unit and integration specs belong in `test/` using ExUnit’s `describe` blocks for context. Name files after the module under test (`pipeline_executor_test.exs`) and expose helpers through `test/support/` when shared. Mock external providers via `Pipeline.TestMode` or stubs in `test/fixtures/`. Target coverage >= 90% on core executors; include regression cases for new pipeline step types and YAML schema changes.

## Commit & Pull Request Guidelines
Commit subjects follow imperative, <=72-character summaries (`fix dialyzer plt path`), with optional body paragraphs outlining rationale and trade-offs. Group logical changes and keep generated files out of diffs. Pull requests should include: objective overview, testing evidence (`mix test`, `mix credo`), linked issues, and screenshots for CLI demos when behavior shifts. Flag configuration or env variable updates in a dedicated checklist so deployment docs stay current.

## Security & Configuration Tips
Never commit provider API keys or workspace artifacts; rely on environment variables (`CLAUDE_API_KEY`, `GEMINI_API_KEY`, `PIPELINE_WORKSPACE_DIR`). Default configs live in `config/`—duplicate into `config/local.exs` for machine-specific overrides. When sharing pipeline YAML, scrub prompts that may leak sensitive instructions, and document any required IAM scopes in the PR description.
