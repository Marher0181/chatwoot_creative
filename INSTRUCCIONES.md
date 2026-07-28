# Instrucciones — Fork custom de Chatwoot sobre Docker

Corres Chatwoot en Docker y quieres usar tu versión con las personalizaciones de
`custom/` en lugar de la imagen oficial.

## Cómo funciona (el método real)

- La imagen custom es un **overlay delgado sobre la imagen oficial**: parte de
  `chatwoot/chatwoot:<versión>` y solo le copia `custom/` + `config/application.rb`
  (ver `Dockerfile.custom`). Como tus cambios son **solo Ruby** (policies, finders,
  listeners, config), **no se recompila nada** → el build tarda segundos y evita el bug
  de compilación de Chatwoot (bootsnap 1.16 vs Ruby 3.4/prism).
- La imagen se publica en **GHCR** (público): `ghcr.io/marher0181/chatwoot-custom`.
- **Máquina de desarrollo** → git (mergear versiones) + construir overlay + `push`.
- **Servidor de producción** → cambiar el `image:`, `pull`, migrar.
- **Tus datos se conservan** siempre: postgres/redis/storage viven en volúmenes Docker,
  no en la imagen.

## Referencia rápida

- Imagen: `ghcr.io/marher0181/chatwoot-custom:<versión>` (versión actual: `4.16.2`)
- Base oficial: `chatwoot/chatwoot:v<versión>`
- Dockerfile del overlay: `Dockerfile.custom`

---

# A · Máquina de desarrollo

Aquí se actualiza el código, se construye la imagen overlay y se publica en GHCR.

## A.1 · Prerrequisitos (una vez)

```bash
git clone git@github.com:Marher0181/chatwoot_creative.git
cd chatwoot_creative
git checkout feat/assignee-only-visibility
git remote -v      # confirma que 'upstream' apunta a chatwoot/chatwoot
```

Login en GHCR para poder hacer `push` (necesita un Personal Access Token *classic* con
scope **`write:packages`**):

```bash
echo <TU_PAT> | docker login ghcr.io -u marher0181 --password-stdin
```

## A.2 · Publicar una versión nueva (ej. v4.17.0)

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
- Aparece `action_cable_listener.rb` → revisa ese módulo (ver A.4).

**4. Mergea la versión nueva:**

```bash
git merge v4.17.0 --no-edit
```

**5. Construye la imagen overlay** (base = imagen oficial de esa versión):

```bash
docker build -f Dockerfile.custom \
  --build-arg CHATWOOT_VERSION=v4.17.0 \
  -t ghcr.io/marher0181/chatwoot-custom:4.17.0 .
```

**6. Publica en GHCR:**

```bash
docker push ghcr.io/marher0181/chatwoot-custom:4.17.0
```

**7. Sube el código a origin:**

```bash
git push origin feat/assignee-only-visibility
```

## A.3 · Hacer público el paquete (solo la primera vez, o por versión si es privado)

GitHub → tu perfil → **Packages** → `chatwoot-custom` → *Package settings* →
**Change visibility → Public**. Así prod hace `pull` sin credenciales.

## A.4 · Si el merge (paso 4) da conflicto

Solo puede pasar en 2 sitios, y son raros:

- **`config/application.rb`** → quédate con las líneas de upstream **y** conserva el bloque
  `if Rails.root.join('custom').exist?`. Luego `git add config/application.rb`.
- **`custom/app/listeners/custom/action_cable_listener.rb`** (si el paso 3 avisó que upstream
  cambió los métodos de eventos) → copia el cuerpo nuevo del método desde el core y vuelve a
  cambiar solo la línea de tokens a `conversation_tokens(...)`. Marcado con comentario `ponytail:`.

Después: `git commit` y continúa en el paso 5.

---

# B · Servidor de producción

Tu prod usa `~/chatwoot/docker-compose.yml` (tuyo, no el del repo). Usuario de postgres: `chatwoot`.

## B.1 · Prerrequisitos (una vez)

- Estar en la carpeta del compose con tu `.env`:

  ```bash
  cd ~/chatwoot
  ls docker-compose.yml .env
  ```

- El paquete debe estar **público** en GHCR (paso A.3) → no hace falta `docker login` en prod.

## B.2 · Primer despliegue (reapuntar de imagen oficial → custom)

**1. Backup de la BD:**

```bash
docker compose exec -T postgres pg_dump -U chatwoot chatwoot > ~/backup_chatwoot_$(date +%F).sql
```

**2. Cambia el `image:` en `~/chatwoot/docker-compose.yml`** (el anchor `base`, ¡una sola vez `image:`!):

```yaml
  base: &base
    image: ghcr.io/marher0181/chatwoot-custom:4.16.2   # antes: chatwoot/chatwoot:latest
```

**3. Baja la imagen y recrea:**

```bash
docker compose pull
docker compose up -d
```

**4. Migraciones (manual — tu compose no las corre solo):**

```bash
docker compose exec rails bundle exec rails db:chatwoot_prepare
docker compose restart rails sidekiq
```

**5. Verifica:**

```bash
docker compose exec rails cat config/version.rb
docker compose exec rails bundle exec rails runner \
  'puts [ConversationPolicy, ConversationFinder, ActionCableListener, NotificationListener].map { |k| k.ancestors.any? { |a| a.name.to_s.start_with?("Custom::") } }.inspect'
```

Esperado: la versión correcta y `[true, true, true, true]`.

## B.3 · Actualizar a una versión ya publicada

Después de completar la parte A (build + push de la versión nueva):

```bash
cd ~/chatwoot
# edita docker-compose.yml -> image: ghcr.io/marher0181/chatwoot-custom:<nueva-versión>
docker compose pull
docker compose up -d
docker compose exec rails bundle exec rails db:chatwoot_prepare
docker compose restart rails sidekiq
```

> Si reusas el MISMO tag (reconstruiste sin cambiar versión), `docker compose pull` puede no
> traer la nueva. Fuerza con: `docker pull ghcr.io/marher0181/chatwoot-custom:<tag>` y luego `up -d`.

## B.4 · Rollback a la imagen oficial

Vuelve la línea del `image:` a la versión oficial conocida y recrea:

```yaml
    image: chatwoot/chatwoot:v4.16.1
```

```bash
docker compose up -d
```

(Tus datos siguen intactos. Si algo quedó mal en la BD, restaura el backup del paso B.2.1.)

## B.5 · Si el disco se llena (`no space left on device`)

```bash
df -h /
docker system df
docker system prune -af      # borra imágenes sin usar, contenedores parados y caché
```

`prune -af` no toca las imágenes de contenedores en ejecución. Si aun así falta espacio,
hay que ampliar el volumen EBS desde AWS (EC2 → Volumes → Modify) + `sudo growpart` + `sudo resize2fs`.
