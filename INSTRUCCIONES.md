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

## Actualizaciones futuras (ej. v4.16.3)

```bash
git fetch upstream --tags
git merge v4.16.3 --no-edit           # custom/ no choca
# edita el tag en docker-compose.custom.yaml -> chatwoot-custom:4.16.3
dc up -d --build
```
