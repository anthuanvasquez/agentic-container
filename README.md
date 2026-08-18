# Agentic Container

Imagen de devcontainer reutilizable para ejecutar **GitHub Copilot CLI** de forma segura y consistente en cualquier proyecto.

## Uso en otro repositorio

Añade `.devcontainer/devcontainer.json` en el proyecto objetivo:

```json
{
  "name": "Agentic Container",
  "image": "ghcr.io/anthuanvasquez/agentic-container:latest",
  "remoteUser": "node",
  "workspaceFolder": "/workspaces/${localWorkspaceFolderBasename}",
  "postCreateCommand": "bash /usr/local/bin/health-check.sh",
  "postStartCommand": "bash /usr/local/bin/setup-git-hook.sh"
}
```

El proyecto se monta automáticamente en `/workspaces/<nombre-del-repo>`, y Copilot CLI corre dentro del mismo entorno con todas las herramientas necesarias.

## Autenticación

Ejecuta dentro del contenedor:

```bash
gh auth login
copilot auth login
```

## Publicación

La imagen se publica automáticamente en GHCR desde este repositorio:

- `ghcr.io/anthuanvasquez/agentic-container:latest`
- `ghcr.io/anthuanvasquez/agentic-container:<semver>`
- `ghcr.io/anthuanvasquez/agentic-container:<sha>`

## Desarrollo local

Abre este repositorio en VS Code con Dev Containers. El `devcontainer.json` local construye la imagen desde el Dockerfile.

## Incluye

- Node.js 22
- GitHub CLI (`gh`)
- GitHub Copilot CLI (`copilot`)
- `npm`, `pnpm`, `python3`, `jq`, `yq`, `fzf`, `ripgrep`, `fd-find`
- Configuración endurecida de `npm`/`pnpm` contra ataques a la cadena de suministro
- Firewall de salida opcional (GitHub + registries comunes)
- Protección de ramas `main`/`master` vía hook de Git

## Seguridad de paquetes

La imagen configura `.npmrc` y `.pnpmrc` con valores conservadores:

- `ignore-scripts=true`: no ejecuta scripts de lifecycle automáticamente.
- `save-exact=true`: versiones fijas por defecto.
- Registro oficial de npm por defecto.
- `maxsockets=1`: menos conexiones concurrentes a registries.

Si un proyecto necesita ejecutar scripts de postinstall, hazlo explícito:

```bash
npm install
npm run postinstall   # o el script que corresponda
```

## Firewall opcional

Añade al `.devcontainer.json` del proyecto consumidor:

```json
{
  "containerEnv": {
    "FIREWALL_ENABLED": "true"
  },
  "runArgs": [
    "--cap-add=NET_ADMIN",
    "--cap-add=NET_RAW"
  ]
}
```

Cuando está activo, solo se permite tráfico a:

- Infraestructura de GitHub (rangos IP oficiales + dominios)
- Registries: npm, GitHub Packages, PyPI, crates.io, Docker Hub, bun, uv/poetry
- DNS y redes Docker locales

Todo lo demás se bloquea por defecto.
