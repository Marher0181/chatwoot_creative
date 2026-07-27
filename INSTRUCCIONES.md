# Instrucciones — Fork custom de Chatwoot sobre Docker

Corres Chatwoot en Docker y quieres usar tu versión con las personalizaciones de
`custom/` en lugar de la imagen oficial (`chatwoot/chatwoot`).

**Cómo se reparte el trabajo:**

- **Máquina de desarrollo** → solo git: mergear versiones nuevas de Chatwoot y hacer push.
- **Servidor de producción** → `git pull` + construir y levantar la imagen custom.
- **Tus datos se conservan** siempre: postgres, redis y storage viven en volúmenes Docker,
  no en la imagen. Cambiar de imagen no los borra.

---

## Referencia rápida

El comando de compose siempre lleva **los dos** `-f` (si omites el segundo, vuelves a la
imagen oficial). Define este alias una vez en el shell del servidor:

```bash
alias dc='docker compose -f docker-compose.production.yaml -f docker-compose.custom.yaml'
```

A partir de ahí: `dc up -d --build`, `dc logs -f rails`, `dc ps`, etc.

---

# A · Máquina de desarrollo

Aquí **no se usa Docker**. Solo se actualiza el código y se sube a `origin`.

## A.1 · Prerrequisitos (una vez)

```bash
git clone git@github.com:Marher0181/chatwoot_creative.git
cd chatwoot_creative
git checkout feat/assignee-only-visibility
git remote -v      # confirma que 'upstream' apunta a chatwoot/chatwoot
```

## A.2 · Actualizar a una versión nueva de Chatwoot (ej. v4.17.0)

**1. Árbol limpio y en la rama correcta:**

```bash
git status        # debe estar limpio; si hay algo tuyo, commitéalo antes
git checkout feat/assignee-only-visibility
```

**2. Trae las versiones nuevas de upstream:**

```bash
git fetch upstream --tags
```

**3. (Recomendado) Comprueba si la versión toca tus archivos:**

```bash
git diff --stat v4.16.2 v4.17.0 -- \
  app/finders/conversation_finder.rb \
  app/policies/conversation_policy.rb \
  app/listeners/action_cable_listener.rb \
  app/listeners/notification_listener.rb \
  config/application.rb
```

- **Vacío** → merge 100% limpio.
- Aparece `action_cable_listener.rb` → revisa ese módulo (ver A.3).

**4. Mergea la versión nueva:**

```bash
git merge v4.17.0 --no-edit
```

**5. Actualiza el tag de la imagen** en `docker-compose.custom.yaml` (en las DOS apariciones):

```yaml
    image: chatwoot-custom:4.17.0   # cambia 4.16.2 -> 4.17.0
```

**6. Sube los cambios:**

```bash
git push origin feat/assignee-only-visibility
```

## A.3 · Si el merge (paso 4) da conflicto

Solo puede pasar en 2 sitios, y son raros:

- **`config/application.rb`** → quédate con las líneas de upstream **y** conserva el bloque
  `if ChatwootApp.custom?`. Luego `git add config/application.rb`.
- **`custom/app/listeners/custom/action_cable_listener.rb`** (si el paso 3 avisó que upstream
  cambió los métodos de eventos) → copia el cuerpo nuevo del método desde el core y vuelve a
  cambiar solo la línea de tokens a `conversation_tokens(...)`. Está marcado con el comentario
  `ponytail:` que lo explica.

Después: `git commit` y continúa en el paso 5.

---

# B · Servidor de producción

## B.1 · Prerrequisitos (una vez)

- El repo del fork debe estar en el host, en la misma carpeta donde está tu `.env`:

  ```bash
  cd /ruta/donde/está/tu/docker-compose
  git clone git@github.com:Marher0181/chatwoot_creative.git .
  git checkout feat/assignee-only-visibility
  ```

  Si ya tienes el repo: `git fetch origin && git checkout feat/assignee-only-visibility && git pull`

- Confirma que tu `.env` sigue en la carpeta (el compose lo usa con `env_file: .env`).
- Define el alias `dc` (ver "Referencia rápida").

## B.2 · Primera vez: reapuntar de la imagen oficial → custom

**1. Backup de la base de datos:**

```bash
docker compose -f docker-compose.production.yaml exec -T postgres \
  pg_dump -U postgres chatwoot > backup_$(date +%F).sql
```

**2. Detén los contenedores de app (NO borres volúmenes):**

```bash
docker compose -f docker-compose.production.yaml stop rails sidekiq
```

> Nunca uses `down -v`: el `-v` borra los volúmenes (perderías la base de datos).

**3. Construye la imagen custom y levanta reapuntando:**

```bash
dc up -d --build
```

**4. Migraciones** (el entrypoint las corre solo; para forzarlas):

```bash
dc exec rails bundle exec rails db:chatwoot_prepare
```

**5. Verifica:**

```bash
dc images rails sidekiq     # debe mostrar chatwoot-custom:<versión>
dc exec rails bundle exec rails runner 'puts ConversationPolicy.ancestors.include?(Custom::ConversationPolicy)'
```

El segundo comando debe imprimir `true`.

## B.3 · Desplegar una actualización ya mergeada en desarrollo

Después de completar la parte A y hacer push:

```bash
git pull origin feat/assignee-only-visibility
dc up -d --build
dc exec rails bundle exec rails runner 'puts ConversationPolicy.ancestors.include?(Custom::ConversationPolicy)'
```

## B.4 · Rollback a la imagen oficial

```bash
docker compose -f docker-compose.production.yaml up -d rails sidekiq
```

(sin el segundo `-f` vuelve a `chatwoot/chatwoot`). Tus datos siguen intactos.

## B.5 · Uso diario

Usa **siempre** el alias `dc` (o los dos `-f`) para cualquier operación:

```bash
dc ps
dc logs -f rails
dc restart rails
```

Si usas `docker compose` con un solo `-f`, volverás sin querer a la imagen oficial.
