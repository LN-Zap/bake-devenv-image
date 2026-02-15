# bake-devenv-image

GitHub Action to prepare Devenv runner image activation assets and optional cache cleanup before snapshot creation.

It converts a resolved Devenv environment into a reusable activation script, so runtime jobs can start quickly without repeating full activation work.

## Counterpart action

`bake-devenv-image` is the build-time counterpart to `setup-devenv`:
- Use `bake-devenv-image` while preparing runner images.
- Use `setup-devenv` in runtime jobs to apply/verify activation.

Repository:
- https://github.com/LN-Zap/setup-devenv

## Scope and prerequisites

This action prepares activation assets and cache metrics for image baking.

It does not by itself:
- install Nix
- install `devenv`
- run your image/snapshot orchestration platform

Your workflow must provide a ready `devenv` command first. For background and recommended base setup, see:
- https://devenv.sh/integrations/github-actions/

## Usage

```yaml
- uses: actions/checkout@v5

# Typical prerequisites on GitHub-hosted runners.
- uses: cachix/install-nix-action@v31
- uses: cachix/cachix-action@v16
  with:
    name: devenv
- run: nix profile install nixpkgs#devenv

- uses: LN-Zap/bake-devenv-image
  with:
    snapshot_name: my-repo-devenv
    activation_script_path: /home/runner/copilot-devenv-activate.sh
    slim_caches: 'true'
    cache_paths: |
      $HOME/.npm
      $HOME/.cache/pip
```

## Inputs

| Name | Required | Default | Description |
| --- | --- | --- | --- |
| `snapshot_name` | no | `project-devenv` | Snapshot name label for reporting. |
| `activation_script_path` | no | `/home/runner/copilot-devenv-activate.sh` | Output path for generated activation script. |
| `slim_caches` | no | `true` | Whether transient caches are removed before snapshot. |
| `cache_paths` | no | `''` | Newline-delimited cache paths to remove when slimming. |

## Outputs

| Name | Description |
| --- | --- |
| `activation_script_written` | `yes` or `no` for executable activation script output. |
| `cache_bytes_removed` | Approximate sum of bytes removed from configured cache paths. |
| `snapshot_name` | Echoes the snapshot name label. |
