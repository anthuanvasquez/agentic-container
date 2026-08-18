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
- `npm`, `python3`, `jq`, `yq`, `fzf`, `ripgrep`, `fd-find`
- Protección de ramas `main`/`master` vía hook de Git
