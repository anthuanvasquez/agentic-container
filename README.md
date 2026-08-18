# AI Devcontainer

Devcontainer para trabajar con agentes de IA en un entorno consistente, con herramientas preconfiguradas y bootstrap automatizado.

## Incluye

- VS Code Dev Containers con usuario `node`.
- Feature de skills globales:
	- `ghcr.io/anthuanvasquez/skills/skills:0.1.1`
	- `platforms: all`
- CLIs instaladas en `postCreate`:
	- `@earendil-works/pi-coding-agent`
	- `@github/copilot`
	- `@google/gemini-cli`
- Inicializacion de hook de Git en `postStart` para proteger commits directos a `main/master`.

## Flujo de bootstrap

1. Build del contenedor y activacion de Features (incluyendo skills).
2. `postCreateCommand` ejecuta `.devcontainer/scripts/post-create.sh`.
3. `post-create.sh`:
	 - instala CLIs globales,
	 - ejecuta `.devcontainer/scripts/health-check.sh`,
	 - guarda log en `~/.agents/logs/post-create.log`.
4. `postStartCommand` ejecuta `.devcontainer/scripts/setup-git-hook.sh`.

## Health Check

Script central de verificacion: `.devcontainer/scripts/health-check.sh`.

Valida:

- Comandos disponibles: `npm`, `pi`, `copilot`, `gemini`.
- Directorios esperados: `~/.pi`, `~/.copilot`, `~/.gemini`, `~/.agents/skills`.

Salida de estado:

- `~/.agents/bootstrap-health.status`

## Comandos utiles

Re-ejecutar bootstrap post-create:

```bash
bash .devcontainer/scripts/post-create.sh
```

Ejecutar health check manual:

```bash
bash .devcontainer/scripts/health-check.sh
```

Reinstalar hook de Git:

```bash
bash .devcontainer/scripts/setup-git-hook.sh
```

## Estructura relevante

- `.devcontainer/devcontainer.json`: orquestacion del entorno.
- `.devcontainer/scripts/post-create.sh`: bootstrap resilient para `postCreate`.
- `.devcontainer/scripts/health-check.sh`: validacion centralizada del setup.
- `.devcontainer/scripts/setup-git-hook.sh`: proteccion de ramas en commit.
- `.devcontainer/templates/`: plantillas de configuracion para agentes.
