# Instrucciones — Reapuntar Docker de Chatwoot original → imagen custom

Estás corriendo la imagen oficial (`chatwoot/chatwoot`). Estos pasos la reemplazan por
tu imagen construida desde este fork (incluye la carpeta `custom/`). **Tus datos se
conservan**: postgres, redis y storage viven en volúmenes Docker, no en la imagen.

---

## 0. Prerrequisitos (una sola vez)

- El código de este fork debe estar en el host de prod (misma carpeta donde está tu `.env`):
  ```bash
  cd /ruta/donde/está/tu/docker-compose
  git clone git@github.com:Marher0181/chatwoot_creative.git .   # si aún no está
  git checkout feat/assignee-only-visibility
  ```
  Si ya tienes el repo, solo:
  ```bash
  git fetch origin && git checkout feat/assignee-only-visibility && git pull
  ```
- Confirma que tu `.env` sigue en la carpeta (el compose lo usa con `env_file: .env`).

---

## 1. Backup antes de tocar nada (importante)

```bash
docker compose -f docker-compose.production.yaml exec -T postgres \
  pg_dump -U postgres chatwoot > backup_$(date +%F).sql
```

---

## 2. Detener los contenedores de app (NO borres volúmenes)

```bash
docker compose -f docker-compose.production.yaml stop rails sidekiq
```
> Nunca uses `down -v`: `-v` borra los volúmenes (perderías la base de datos).

---

## 3. Construir la imagen custom y levantar reapuntando

Un solo comando construye la imagen desde el fork y arranca `rails` + `sidekiq`
usándola (gracias al override `docker-compose.custom.yaml`):

```bash
docker compose \
  -f docker-compose.production.yaml \
  -f docker-compose.custom.yaml \
  up -d --build
```

- `-f docker-compose.custom.yaml` es lo que reapunta la imagen (de `chatwoot/chatwoot`
  a `chatwoot-custom:4.16.2`).
- `--build` fuerza la construcción con tu `custom/` dentro.

---

## 4. Migraciones de base de datos

El entrypoint `rails.sh` corre las migraciones al arrancar. Para forzarlas manualmente:

```bash
docker compose -f docker-compose.production.yaml -f docker-compose.custom.yaml \
  exec rails bundle exec rails db:chatwoot_prepare
```

---

## 5. Verificar

Que la imagen en uso sea la custom:
```bash
docker compose -f docker-compose.production.yaml -f docker-compose.custom.yaml \
  images rails sidekiq
```
(debe mostrar `chatwoot-custom:4.16.2`)

Que el overlay custom esté activo:
```bash
docker compose -f docker-compose.production.yaml -f docker-compose.custom.yaml \
  exec rails bundle exec rails runner 'puts ConversationPolicy.ancestors.include?(Custom::ConversationPolicy)'
```
Debe imprimir `true`.

---

## 6. Si algo falla — volver a la imagen oficial (rollback)

```bash
docker compose -f docker-compose.production.yaml up -d rails sidekiq
```
(sin el `-f docker-compose.custom.yaml` vuelve a `chatwoot/chatwoot`)

---

## IMPORTANTE: usa SIEMPRE los dos `-f` juntos

De ahora en adelante, para cualquier operación (up, restart, logs, exec) usa los dos
archivos, o volverás sin querer a la imagen oficial:

```bash
docker compose -f docker-compose.production.yaml -f docker-compose.custom.yaml <comando>
```

Atajo opcional — exporta esto en tu shell y usa `dc` en vez de todo el comando:
```bash
alias dc='docker compose -f docker-compose.production.yaml -f docker-compose.custom.yaml'
# luego: dc up -d --build   |   dc logs -f rails   |   dc ps
```

---

## Actualizaciones futuras — proceso completo (ej. v4.17.0)

Tu trabajo en `custom/` **no se toca** en ninguna actualización: vive en archivos que
upstream no tiene.

### En tu máquina de desarrollo

**1. Árbol limpio y en la rama correcta:**

```bash
git status        # debe estar limpio; si hay algo tuyo, commitéalo antes
git checkout feat/assignee-only-visibility
```

**2. Trae las versiones nuevas de upstream:**

```bash
git fetch upstream --tags
```

**3. (Recomendado) Comprueba antes si la versión toca tus archivos:**

```bash
git diff --stat v4.16.2 v4.17.0 -- \
  app/finders/conversation_finder.rb \
  app/policies/conversation_policy.rb \
  app/listeners/action_cable_listener.rb \
  app/listeners/notification_listener.rb \
  config/application.rb
```

- **Vacío** → merge 100% limpio.
- Aparece `action_cable_listener.rb` → revisa solo ese módulo (ver "Si hay conflicto").

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

### En el host de producción

**7. Trae el código y reconstruye:**

```bash
git pull origin feat/assignee-only-visibility
dc up -d --build
```

**8. Verifica:**

```bash
dc exec rails bundle exec rails runner 'puts ConversationPolicy.ancestors.include?(Custom::ConversationPolicy)'
```

→ debe imprimir `true`.

### Si el paso 4 da conflicto

Solo puede pasar en 2 sitios, y son raros:

- **`config/application.rb`** → quédate con las líneas de upstream **y** conserva el bloque
  `if ChatwootApp.custom?`. Luego `git add config/application.rb`.
- **`custom/app/listeners/custom/action_cable_listener.rb`** (si el paso 3 avisó que upstream
  cambió los métodos de eventos) → copia el cuerpo nuevo del método desde el core y vuelve a
  cambiar solo la línea de tokens a `conversation_tokens(...)`. Está marcado con el comentario
  `ponytail:` que lo explica.

Después: `git commit` y continúa en el paso 5.
