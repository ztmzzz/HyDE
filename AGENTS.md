# Repository Guidelines

## Project Structure & Module Organization
- `Configs/` holds default dotfiles and base configs (`.config/`, `.local/`, `.gtkrc-2.0`, `.zshenv`).
- `Scripts/` contains install/restore tooling and package lists (`install.sh`, `restore_cfg.sh`, `themepatcher.sh`, `pkg_core.lst`, `pkg_extra.lst`), plus `hydevm/` for VM testing and `migrations/`.
- `Source/` stores assets and documentation (`assets/` images, `docs/` translated READMEs, `arcs/` packaged themes/fonts, `misc/`).

## Build, Test, and Development Commands
- `cd Scripts && ./install.sh`: full install (default behavior is equivalent to `-irs`).
- `cd Scripts && ./install.sh -r`: restore configs after updates.
- `cd Scripts && ./install.sh -t`: dry-run to verify steps without executing.
- `cd Scripts && ./uninstall.sh`: remove HyDE.
- `cd Scripts && ./themepatcher.sh`: apply themes listed in `Scripts/themepatcher.lst`.
- `Scripts/hydevm/hydevm.sh`: launch HydeVM for testing; on Nix, `nix run .` is supported.

## Coding Style & Naming Conventions
- Bash scripts live in `Scripts/` and use `#!/usr/bin/env bash`; keep 4-space indentation and existing ShellCheck directives (for example, `# shellcheck disable=...`).
- Package/config lists use `.lst` or `.psv` (see `Scripts/pkg_core.lst`, `Scripts/restore_cfg.psv`); follow current ordering and naming patterns.
- Keep new configs aligned with the `Configs/` layout and HyDE dotfile naming.

## Testing Guidelines
- Automated tests are not defined; changes are validated by manual installs/restores.
- Prefer HydeVM for safe testing (`Scripts/hydevm/README.md`), especially for installer or config changes.
- For release testing, follow `TESTING.md` (use `dev` or `rc` branches, then run `./install.sh` or `./install.sh -r`).

## Commit & Pull Request Guidelines
- Commit messages: imperative summary, optional body for context, wrap at 72 chars; use typed prefixes like `feat:`, `fix:`, `docs:`, `refactor:`, `chore:` per `COMMIT_MESSAGE_GUIDELINES.md`.
- PRs must target `dev` (not `master`). Include a clear summary, issue links (e.g., `Fixes #123`), dependency notes, and screenshots when UI changes apply.
- Update `CHANGELOG.md` for user-visible changes and complete the PR template checklist.
