#!/bin/bash
set -euo pipefail

# is_safe_project_command() — returns 0 if command matches a safe project pattern, 1 otherwise
# $1: full command string
is_safe_project_command() {
    local cmd="$1"

    local -a patterns=(
        # just recipes (root)
        "^just (list|changelog|vars|serve-docs|test-server-check|test|pytest|jstest|test-cov|build|vscode|schematic|dev|devrun|docker|lint|stubs|inits|rust|ipykernel|build-docs|build-docs-full|_cli)( |$)"

        # package managers — run scripts and queries only, never install (lifecycle scripts)
        "^npm (run (test|test:(unit|unit:watch|unit:ui|unit:coverage|integration|integration:coverage|webview|webview:ui|coverage)|build|prod|compile|lint|typecheck|typecheck:(src|unit|integration)|check:undefined|coverage:merge)|test|ls|list|outdated|view|info|explain|why|pack|audit)( |$)"
        "^yarn (run|test|info|why|list|outdated|dlx)( |$)"
        "^pnpm (run (test|build|lint|typecheck|compile)|test|list|outdated|why|audit)( |$)"
        "^bun (run (test|build|lint|typecheck|compile)|test)( |$)"
        "^npx (tsc|eslint|vitest|prettier|playwright)( |$)"

        # cargo — build/test/check only, not install or run
        "^cargo (test|check|clippy|build|fmt|doc)( |$)"

        # python/uv
        "^uv run (pytest|pyright|maturin|pre-commit|ruff|mkdocs)( |$)"
        "^uv (sync|venv|pip install|pip list|pip show|tool)( |$)"
        "^python3? -m (py_compile|pytest|json\.tool)( |$)"

        # github cli (read-only)
        "^gh (pr (view|list|diff|checks|status)|issue (view|list|status)|repo (view|list)|run (view|list|watch))( |$)"
        "^gh api (GET |/)"

        # build tools — version checks and syntax checks only, not eval (-e)
        "^(node|ruby|perl) -(v|c)( |$)"
        "^trunk (build|serve)( |$)"
        "^wasm-bindgen "
        "^wasm-opt "
        "^maturin (build|develop)( |$)"
    )

    for pattern in "${patterns[@]}"; do
        if [[ "$cmd" =~ $pattern ]]; then
            return 0
        fi
    done

    return 1
}
