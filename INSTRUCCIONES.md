# Instrucciones — Fork custom de Chatwoot sobre Docker

Corres Chatwoot en Docker y quieres usar tu versión con las personalizaciones de
`custom/` en lugar de la imagen oficial.

## Cómo funciona (el método real)

- La imagen custom es un **overlay delgado sobre la imagen oficial**: parte de
  `chatwoot/chatwoot:<versión>` y solo le copia `custom/` + `config/application.rb`
  (ver `Dockerfile.custom`). Como tus cambios son **solo Ruby** (policies, finders,
  listeners, services, builders, config), **no se recompila nada** → el build tarda segundos
  y evita el bug de compilación de Chatwoot (bootsnap 1.16 vs Ruby 3.4/prism).
- ⚠️ **Lo único que viaja en la imagen es `custom/` y `config/application.rb`.** Todo el resto
  (`app/`, `lib/`, `enterprise/`, frontend) lo aporta la imagen oficial intacta. Editar un
  archivo de `app/` y desplegar **no cambia nada en producción, y no da ningún error** — el
  build pasa, el deploy pasa, y el comportamiento sigue igual. Cada personalización va como
  módulo `Custom::` dentro de `custom/app/`, anteponiéndose a la clase de core. Antes de
  construir, corre el chequeo del paso **A.5.2**.
- La imagen se publica en **GHCR** (público): `ghcr.io/marher0181/chatwoot-custom`.
- **Máquina de desarrollo** → git (mergear versiones) + construir overlay + `push`.
- **Servidor de producción** → cambiar el `image:`, `pull`, migrar.
- **Tus datos se conservan** siempre: postgres/redis/storage viven en volúmenes Docker,
  no en la imagen.

## Referencia rápida

- Imagen: `ghcr.io/marher0181/chatwoot-custom:<versión>` (versión actual: `4.16.2`)
- Base oficial: `chatwoot/chatwoot:v<versión>`
- Dockerfile del overlay: `Dockerfile.custom`
- Rama de producción: `feat/assignee-only-visibility`
- **Convención de tags:**
  - Subir de versión de Chatwoot → el tag es la versión: `4.17.0` (ver **A.2**).
  - Cambio de código propio sin subir de versión → sufijo incremental: `4.16.2-ig-1`,
    `4.16.2-ig-2`… (ver **A.5**). Nunca reutilices un tag ya publicado: `docker compose pull`
    puede quedarse con la imagen vieja en caché y creerás que desplegaste algo que no.

## Qué está personalizado (módulos `Custom::`)

Cada uno se antepone a una clase de core. Los que core no expone vía `prepend_mod_with` van
cableados a mano en `custom/config/initializers/01_prepend_custom_modules.rb`.

| Módulo `Custom::` | Clase de core | Para qué |
|---|---|---|
| `ConversationPolicy` | `ConversationPolicy` | visibilidad solo del asignado |
| `ConversationFinder` | `ConversationFinder` | idem, en los listados |
| `ActionCableListener` | `ActionCableListener` | no filtrar eventos a agentes ajenos |
| `NotificationListener` | `NotificationListener` | idem, en notificaciones |
| `Messages::Facebook::MessageBuilder` | idem | nombre real del contacto vía `/page/conversations` |
| `Messages::Instagram::BaseMessageBuilder` | idem | guardar el referral del anuncio |
| `Instagram::MessageText` | idem | no perder el mensaje si falla el perfil |
| `Instagram::Messenger::MessageText` | idem | idem, canal vía página de Facebook |

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
  app/builders/messages/facebook/message_builder.rb \
  app/builders/messages/instagram/base_message_builder.rb \
  app/services/instagram/message_text.rb \
  app/services/instagram/messenger/message_text.rb \
  config/application.rb
```

- **Vacío** → merge 100% limpio.
- Aparece `action_cable_listener.rb` → revisa ese módulo (ver A.4).
- Aparece un archivo de Instagram/Facebook → revisa el módulo `Custom::` correspondiente: los
  overrides llaman a `super` y a helpers privados de core (`message_params`,
  `fetch_instagram_user`, `unknown_user`, `message`), así que si core los renombra el override
  deja de aplicar en silencio.

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

## A.5 · Desplegar un cambio de código propio (sin subir de versión de Chatwoot)

Este es el flujo para tus propios arreglos, distinto de A.2 (que es para subir de versión de
Chatwoot). Los comandos de abajo usan como ejemplo el cambio de Instagram: rama
`feat/instagram-ads-referral`, versión de Chatwoot `v4.16.2`, tag nuevo `4.16.2-ig-1`.
Sustituye esos tres valores por los tuyos.

**1. Árbol limpio y rama de producción actualizada:**

```bash
cd ~/chatwoot_creative                        # tu clon de desarrollo
git status                                    # debe estar limpio
git checkout feat/assignee-only-visibility
git pull origin feat/assignee-only-visibility
```

**2. Confirma que el cambio vive en `custom/`** — este es el paso que se olvida y hace que el
deploy no sirva de nada:

```bash
git diff --name-only HEAD..feat/instagram-ads-referral -- app/ lib/ enterprise/
```

- **Sin salida** → correcto, todo está en `custom/`. Continúa.
- **Sale algún archivo** → **PARA.** Eso no entra en la imagen overlay: el build va a pasar, el
  deploy va a pasar y en producción no va a cambiar nada. Reescríbelo como módulo `Custom::` en
  `custom/app/` y cabléalo en `custom/config/initializers/01_prepend_custom_modules.rb`.

**3. Mergea tu rama de trabajo:**

```bash
git merge feat/instagram-ads-referral --no-edit
```

**4. Elige el tag nuevo.** La versión de Chatwoot no cambia, así que el tag lleva sufijo
incremental: `4.16.2-ig-1`, `4.16.2-ig-2`… Para ver los ya publicados: GitHub → tu perfil →
**Packages** → `chatwoot-custom`. **Nunca reutilices un tag publicado.**

**5. Construye el overlay** (`CHATWOOT_VERSION` = la misma versión oficial que ya corre en prod):

```bash
docker build -f Dockerfile.custom \
  --build-arg CHATWOOT_VERSION=v4.16.2 \
  -t ghcr.io/marher0181/chatwoot-custom:4.16.2-ig-1 .
```

Debe tardar segundos. Si se pone a compilar gemas o assets, `CHATWOOT_VERSION` está mal.

**6. Comprueba que los módulos quedaron dentro de la imagen, antes de publicar:**

```bash
docker run --rm --entrypoint ls \
  ghcr.io/marher0181/chatwoot-custom:4.16.2-ig-1 -R /app/custom/app
```

Deben aparecer tus archivos nuevos. Si falta alguno, el `COPY` del `Dockerfile.custom` no lo
recogió (¿está el archivo commiteado?).

**7. Publica en GHCR:**

```bash
echo <TU_PAT> | docker login ghcr.io -u marher0181 --password-stdin   # si no estás logueado
docker push ghcr.io/marher0181/chatwoot-custom:4.16.2-ig-1
```

**8. Sube el código a origin:**

```bash
git push origin feat/assignee-only-visibility
```

**9. En producción, apunta a la imagen nueva:**

```bash
ssh <tu-servidor>
cd ~/chatwoot
cp docker-compose.yml docker-compose.yml.bak      # para el rollback del paso 12
# edita el anchor `base` -> image: ghcr.io/marher0181/chatwoot-custom:4.16.2-ig-1
docker compose pull
docker compose up -d
```

**Migraciones:** solo si el cambio toca la BD. Los módulos `Custom::` de Instagram/Facebook no la
tocan, así que puedes saltarte `db:chatwoot_prepare`. Si dudas, correrlo es idempotente y seguro.

**10. Verifica que el overlay está activo** → ver **B.6**. Si alguna clase sale `FALTA`, el
prepend no se aplicó y el deploy no sirvió: revisa el paso 2 y el initializer.

**11. Verifica el cambio en la app.** Para el arreglo de Instagram: escribe al negocio desde el
anuncio con una cuenta que nunca haya escrito antes, y confirma que (a) el mensaje aparece en la
conversación y (b) puedes responder sin el aviso de la ventana de 24 horas. Y para medir cuántos
leads llegan sin perfil accesible:

```bash
docker compose logs --since=24h rails | grep "FORK: perfil de IG"
```

**12. Si algo salió mal — rollback inmediato:**

```bash
cd ~/chatwoot
cp docker-compose.yml.bak docker-compose.yml     # vuelve al tag anterior
docker compose up -d
```

No hace falta tocar la BD si no corriste migraciones.

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
```

y comprueba el overlay con **B.6**.

## B.3 · Actualizar a una versión ya publicada

Para un cambio de código propio, el flujo completo (dev + prod) está en **A.5**.

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

## B.6 · Verificar que el overlay está activo

Comprueba que cada clase de core tiene su módulo `Custom::` antepuesto. Es la única forma de
saber que el deploy realmente aplicó tus cambios: si el overlay no cargó, la app arranca igual
y se comporta como la oficial, sin ningún error visible.

```bash
cd ~/chatwoot
docker compose exec rails bundle exec rails runner '
[ConversationPolicy, ConversationFinder, ActionCableListener, NotificationListener,
 Messages::Facebook::MessageBuilder, Messages::Instagram::BaseMessageBuilder,
 Instagram::MessageText, Instagram::Messenger::MessageText].each do |klass|
  ok = klass.ancestors.any? { |mod| mod.name.to_s.start_with?("Custom::") }
  puts format("%-6s %s", ok ? "OK" : "FALTA", klass)
end'
```

Esperado: `OK` en las ocho. Si sale algún `FALTA`:

1. ¿El módulo está en `custom/app/` y commiteado? (paso **A.5.2**)
2. ¿Está cableado en `custom/config/initializers/01_prepend_custom_modules.rb`? Solo se
   auto-antepone lo que core expone vía `prepend_mod_with`; el resto va a mano.
3. ¿La imagen que corre es el tag nuevo? `docker compose config | grep image:`
4. ¿El archivo llegó a la imagen? `docker compose exec rails ls -R /app/custom/app`

Cuando agregues un módulo `Custom::` nuevo, añade su clase a la lista de arriba y a la tabla de
**Qué está personalizado**.
