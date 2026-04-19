# AGENTS

## Scope
- `numtide/blueprint` layout.
- Launcher logic in `packages/opencode-sandbox/`
- NixOS module in `modules/nixos/opencode-sandbox.nix`
- Shared wrapper helpers in `lib/default.nix`

## Rules
- Read the relevant files before changing them.
- Prefer the smallest correct change.
- Keep the CLI contract strict:
  - sandbox args before `--`
  - opencode args after `--`
- Prefer CLI arguments over package overrides.
- VM must remain ephemeral.
- Assume multiple `opencode-sandbox` instances may run concurrently; avoid designs that increase sqlite lock contention.
- Keep wrapper generation logic shared via `lib/default.nix`; do not duplicate wrapper construction across module/devshell code.
- Preserve the two-stage Blueprint module export so the module captures this flake when imported by another flake.
- Verify README examples against actual Nix types and generated file formats.

## Verify
- Always run `nix build .#opencode-sandbox-test` unless changes are to docs only
- Launcher tests and the NixOS module tests are in separate files
- All tests are run by this one convenient package
- For specific verification scenarios run `nix run .#opencode-sandbox -- <launcher args> -- <opencode args>`