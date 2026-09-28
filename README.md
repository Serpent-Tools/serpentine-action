# serpentine-action

[![Test](https://github.com/Serpent-Tools/serpentine-action/actions/workflows/test.yml/badge.svg)](https://github.com/Serpent-Tools/serpentine-action/actions/workflows/test.yml)

GitHub Actions for [serpentine](https://github.com/Serpent-Tools/serpentine), a workflow runner
built around a graph of nodes written in its own DSL, snek.

- `Serpent-Tools/serpentine-action` downloads serpentine and runs a pipeline.
- `Serpent-Tools/serpentine-action/setup` downloads serpentine and puts it on `PATH`.

Both need a Linux runner with a docker or podman daemon, such as `ubuntu-latest` or
`ubuntu-24.04-arm`.

## Running a pipeline

```yaml
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: Serpent-Tools/serpentine-action@v1
```

That runs the `DEFAULT` entry point of `./main.snek`, caching to the GitHub Actions cache. Point it
at another pipeline or entry point to split a job:

```yaml
      - uses: Serpent-Tools/serpentine-action@v1
        with:
          pipeline: ci/main.snek
          entry-point: PR_BLOCKERS
```

### Inputs

| input | default | effect |
| --- | --- | --- |
| `version` | `latest` | The release to install, with or without a leading `v`. |
| `pipeline` | `./main.snek` | `--pipeline`, the pipeline file to run. |
| `entry-point` | `DEFAULT` | `--entry-point`, the exported label to execute. |
| `jobs` | `1` | `--jobs`, how many `Exec` nodes may run at once. |
| `cache-backend` | `github` | `--cache-backend`: `auto`, `fs`, `github` or `none`. |
| `cache-folder` | — | `--cache-folder`, where the `fs` backend stores its cache. |
| `working-directory` | `.` | The directory to run serpentine from. |
| `args` | — | Extra arguments, split the way a shell splits a command line. |

`jobs` defaults to 1 rather than serpentine's 2, which keeps `--output auto` on the GitHub renderer
and folds each command into its own collapsible log group. Raise it once your caches are warm, at
the cost of that grouping.

### Outputs

| output | description |
| --- | --- |
| `version` | The version that was installed, without a leading `v`. |
| `binary` | The full path of the serpentine binary. |

## Installing serpentine only

```yaml
      - uses: Serpent-Tools/serpentine-action/setup@v1
        with:
          version: latest
      - run: serpentine run --entry-point LINTS
```

Outputs are `version`, `path` (the directory added to `PATH`) and `binary`. Downloads land in the
runner tool cache and are checked against the `SHA256SUMS` published with the release.

## Caching

The default `github` backend keeps serpentine's layer cache in the GitHub Actions cache, and needs
nothing on your side. To cache somewhere else, switch to the `fs` backend and manage the folder
yourself:

```yaml
      - uses: actions/cache@v4
        with:
          path: /tmp/serpentine_cache
          key: serpentine-${{ github.sha }}
          restore-keys: serpentine-
      - uses: Serpent-Tools/serpentine-action@v1
        with:
          cache-backend: fs
          cache-folder: /tmp/serpentine_cache
```

Either way the cache is written in standalone mode, so it carries its container layers and survives
the move between runners. See the [caching chapter](https://serpentine.vivax.dev/caching) for what
ends up in there.

## Versioning

`@v1` follows every `v1.x.y` release of this repository. Pin the action by commit SHA if you want it
to hold still, and pin `version:` to an exact serpentine release if you want your pipelines to.

