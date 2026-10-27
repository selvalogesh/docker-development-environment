# devenv

One shared Ubuntu development container that VS Code connects to. Every project lives in
`/workspaces` inside it, so your host stays clean and every machine gets the same toolchain.

- Ubuntu 24.04, non-root `dev` user with passwordless `sudo`
- Node via nvm (several versions side by side), with pnpm and yarn through corepack
- Python 3 with pip, venv and pipx
- Optional Rust and Go
- git, build-essential, curl, jq, vim, nano and other basics
- Persistent volumes for projects, VS Code server/extensions and shell history, so rebuilding
  the image never loses work

## Requirements

- Docker Desktop (or Docker Engine with the Compose plugin)
- VS Code with the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension

## Quick start

```sh
git clone https://github.com/selvalogesh/docker-development-environment.git
cd docker-development-environment
cp .env.example .env    # optional, see Configuration
```

Then pick one way to connect:

**Open this folder in VS Code → "Dev Containers: Reopen in Container".**
VS Code builds the image, starts the container and opens `/workspaces`.

**Or run it yourself and attach.**

```sh
docker compose up -d
```

In VS Code: "Dev Containers: Attach to Running Container…" → `devenv`, then
File → Open Folder → `/workspaces/<project>`. Each project can have its own VS Code window, all
attached to the same container.

Closing VS Code leaves the container running. Stop it with `docker compose stop`.

## Working with projects

Clone straight into the container from its terminal:

```sh
cd /workspaces
git clone https://github.com/you/project.git
```

VS Code forwards your host's git credentials, SSH agent and `.gitconfig` into the container, so
`git push` works without setting anything up inside it. Ports your apps listen on are forwarded to
`localhost` automatically.

Switch Node versions per shell with `nvm use 20`, or add an `.nvmrc` to a project.

## Configuration

Settings live in `.env` (copy `.env.example`). Rebuild after changing build options:

```sh
docker compose up -d --build
```

| Variable | Default | Purpose |
|---|---|---|
| `WORKSPACE` | `workspaces` volume | Where `/workspaces` comes from. Set a host path such as `E:/VSCode` to bind-mount existing folders. |
| `NODE_VERSIONS` | `lts/* 20` | Node versions to install; the first is the default |
| `INSTALL_PYTHON` | `true` | Python 3, pip, venv, pipx |
| `INSTALL_RUST` | `false` | rustup with rustfmt and clippy |
| `INSTALL_GO` | `false` | Latest Go release |
| `TZ` | `UTC` | Container time zone, e.g. `Asia/Kolkata` |
| `USER_UID` / `USER_GID` | `1000` | Match your host user when bind-mounting on Linux |

### Volume or host folder?

On Windows and macOS, a named volume is much faster than a bind mount, which matters for
`npm install`, builds and file watchers. Use a host folder only when tools outside the container
need to see the files.

To back up the projects volume to a tarball in the current folder:

```sh
docker run --rm -v devenv_workspaces:/w -v "$PWD":/backup ubuntu tar czf /backup/workspaces.tgz -C /w .
```

## Adding tools

Edit the `Dockerfile` and run `docker compose up -d --build`. Things installed by hand inside the
container are lost on rebuild, except what is under `/workspaces`.
