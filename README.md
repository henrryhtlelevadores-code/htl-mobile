# HTL Técnicos (Flutter)

App móvil para técnicos de campo de HTL Elevadores. Implementa el flujo de
`TECHNICIAN_APP_SPEC.md` sobre el mismo modelo de datos y reglas que la vista
web del técnico (`src/features/technician/`).

## Cómo correrla

```bash
cd mobile
flutter pub get

# Contra el backend desplegado en Vercel (https://htl-elevadores.vercel.app):
flutter run

# Contra el backend local (next dev en tu PC, desde el emulador de Android):
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000

# Modo demostración (datos en memoria, no necesita backend):
flutter run --dart-define=USE_MOCK=true
```

El valor por defecto de `API_BASE_URL` es el dominio de producción en Vercel.
En el emulador de Android, `http://10.0.2.2:3000` apunta al `next dev` de tu PC.

En el login solo se escribe el usuario; la app completa el correo con
`@htl-elevadores.com` (cámbialo con `--dart-define=EMAIL_DOMAIN=...`). Si se
escribe un correo completo, se usa tal cual.

### Permisos

Al entrar, la app pide de una vez cámara, micrófono y ubicación (y en iOS,
fotos), con `permission_handler`. En Android la galería usa el selector del
sistema, que no necesita permiso.

En iOS, `permission_handler` solo pide los permisos habilitados en el
`ios/Podfile`. Al compilar para iOS por primera vez (en una Mac), añade dentro
de `post_install`, en el bucle de cada target:

```ruby
target.build_configurations.each do |config|
  config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)',
    'PERMISSION_CAMERA=1', 'PERMISSION_MICROPHONE=1',
    'PERMISSION_LOCATION_WHENINUSE=1', 'PERMISSION_PHOTOS=1']
end
```

## Flujo

| # | Pantalla | Qué hace | Acción del backend |
|---|---|---|---|
| 1 | Login | Correo + contraseña, guarda el token en almacenamiento seguro | `POST /auth/login` |
| 2 | Mis órdenes | Lista de OTs asignadas, indicador de cambios sin sincronizar | `GET /work-orders` |
| 3 | Detalle OT (revisar) | Cliente, sede, contacto, equipos. Botón **Iniciar trabajo** | `POST /work-orders/:id/start` |
| 4 | Equipo | Pasos en orden; cada uno se desbloquea al aprobar el anterior | — |
| 5 | Seguridad | Sí / No / N/A (observación obligatoria en "No"). **Aceptar todos** marca "Sí" en las pendientes. **Aprobar seguridad** adjunta el GPS sin hacer esperar | `saveSafetyItem`, `completeElevatorSafety` |
| 6 | Tareas | Por módulo (M1..M8 / General). Aprobar tarea, **Aprobar todo** el módulo o **Aprobar todas**, omitir, no aplica, foto por tarea | `updateWorkOrderTask`, `bulkUpdateModuleTasks` |
| 7 | Fotos | Antes / Después / Punto de atención. **Mínimo 4 solo en preventivo**; correctivo sin mínimo | `addElevatorPhoto`, `removeElevatorPhoto` |
| 8 | Hallazgos | Nota escrita, foto del hallazgo y **notas de voz** | `updateElevatorFindings`, audio (nuevo) |
| 9 | Finalizar equipo | "Marcar todas" o "Dejar como están" | `completeElevator` |
| 10 | Cerrar OT | Estado final por equipo, nombre de quien recibe y firma | `completeWorkOrder` |

## Estructura

```
lib/
  main.dart                 arranque, cola offline
  app.dart                  rutas (go_router) y tema
  core/
    config.dart             API_BASE_URL, USE_MOCK
    api_client.dart         Dio + Authorization: Bearer
    session_store.dart      token en flutter_secure_storage
    offline_store.dart      copia local de las OTs (trabajo sin señal)
    sync_queue.dart         cola persistente de envíos en segundo plano
    providers.dart          Riverpod + WorkOrderController (reglas, local primero)
  data/
    models.dart             espejo de los tipos de queries.ts
    technician_repository.dart       contrato
    api_technician_repository.dart   implementación REST
    mock_technician_repository.dart  datos de demostración
  features/
    auth/ work_orders/ execution/ safety/ tasks/ findings/ closing/
  widgets/
    photo_capture.dart      cámara + compresión (1600 px, JPEG 82)
    audio_recorder.dart     grabación y reproducción de notas de voz
```

## Sin internet (local primero)

La app está pensada para trabajar todo el día sin señal (sótanos, cuartos de
máquinas):

- **Descarga previa.** Al abrir "Mis órdenes" con señal se descarga cada OT
  completa (equipos, tareas, plantilla de seguridad) a `offline/` en el
  teléfono. Con un token vigente (7 días) la app abre sin señal.
- **Todo en segundo plano.** Iniciar, responder seguridad, aprobar tareas,
  fotos, audios, finalizar y cerrar se aplican en pantalla al instante, se
  guardan en la copia local y se encolan en `sync_queue.json`. Nada espera al
  servidor. "Aceptar todos" y "Aprobar todas" van en **un solo envío**, igual
  que en la web.
- **Reglas validadas en el teléfono.** Como no hay respuesta del servidor, la
  app aplica las mismas reglas que el backend: seguridad completa antes de
  tareas, observación en cada "No", mínimo de fotos en preventivo, todos los
  equipos finalizados antes de cerrar.
- **Sincronización.** La cola envía en orden cuando vuelve la señal, con
  reintentos. Un 401 la pausa hasta volver a iniciar sesión. Un error de
  validación se descarta para no bloquear el resto. El ícono de la nube en
  "Mis órdenes" muestra cuántos cambios faltan enviar.
- **IDs y horas del teléfono.** Ítems de seguridad, fotos y audios llevan un
  ID generado en la app, y cada cambio lleva la hora real en que se hizo
  (`answeredAt`, `completedAt`...), no la hora en que llegó al servidor.
  Cada envío lleva `Idempotency-Key` para que un reintento no duplique nada.

## Endpoints del backend

Ya existen en el proyecto web (`src/app/api/mobile/v1`, lógica en
`src/features/mobile`). El login devuelve `{ token, expiresAt, user }`; el
token tiene el formato `v2.mobile.<userId>.<versión>.<exp>.<firma>`, dura 7
días y se renueva con `POST /auth/refresh` al abrir la app con señal. Solo
pueden entrar usuarios cuyo rol tenga el permiso `work_orders:field`.

Respuestas de error: `{ success: false, message }` con 401 (sesión inválida:
la cola se detiene), otros 4xx (la petición no es válida: se descarta) o 5xx
(reintentar).

Todos bajo `/api/mobile/v1`, con `Authorization: Bearer <token>`. Envuelven las
server actions existentes, con estos agregados para el modo sin internet:

| Ruta | Cuerpo | Envuelve |
|---|---|---|
| `POST /auth/login` | `{ email, password }` | `loginAction` |
| `GET /work-orders` | — | `getTechnicianWorkOrders` |
| `GET /work-orders/:id` | — | `getTechnicianWorkOrderExecution` + por equipo `safetyTemplate: [{question, orderIndex}]` (plantilla activa) y `audios` |
| `POST /work-orders/:id/start` | `{ startedAt, elevators: [{ id, safetyItems: [{id, question, orderIndex}] }] }` | `startWorkOrder`, creando los ítems con los IDs que manda la app |
| `POST /elevators/:id/safety/items` | `{ items: [{ id, response, observations, answeredAt }] }` | `saveSafetyItem` en lote |
| `POST /elevators/:id/safety/complete` | `{ completedAt, geolocation }` | `completeElevatorSafety` |
| `POST /elevators/:id/tasks` | `{ tasks: [{ id, status, isCompleted, observations, completedAt }] }` | `updateWorkOrderTask` en lote |
| `POST /elevators/:id/findings` | `{ findings }` | `updateElevatorFindings` |
| `POST /elevators/:id/photos` | multipart `file, id, tag, description?, taskId?, createdAt` | `addElevatorPhoto` con ID de la app |
| `DELETE /photos/:id` | — | `removeElevatorPhoto` |
| `POST /elevators/:id/audios` | multipart `file, id, durationMs, createdAt` | **nuevo** (ver Audio) |
| `POST /elevators/:id/complete` | `{ mode, completedAt }` | `completeElevator` |
| `POST /work-orders/:id/complete` | `{ clientName, signatureDataUrl, elevatorStatuses, completedAt }` | `completeWorkOrder` |

Todos deben ser idempotentes (repetir el mismo envío no cambia nada).

**Regla de fotos:** la API móvil exige 4 fotos solo en `PREV`, igual que la
app. (La vista web del técnico las sigue exigiendo también en `CORR`.)

## Audio: grabar, guardar en R2 y transcribir

**En el teléfono** se graba con el paquete `record` en AAC mono 16 kHz a 32 kbps
(unos 240 KB por minuto, máximo 5 minutos por nota). El técnico puede
escucharla antes de que se suba. No se transcribe en el teléfono.

**Sin señal** el audio queda guardado en el teléfono y se puede escuchar. Se
sube solo cuando vuelve la conexión, junto con el resto de la cola.

**En el servidor:** hoy el audio se guarda en el bucket privado de R2 y se
registra en `work_order_elevator_audios` con `transcriptStatus = 'NONE'`; la
app lo recibe con una URL firmada de una hora. La transcripción sigue siendo
una propuesta, no implementada:

1. `POST /elevators/:id/audios` recibe el archivo y lo sube a R2 con la misma
   `uploadToR2` de las fotos, en una clave tipo
   `work-orders/{ot}/{equipo}/audio-{ts}-{rand}.m4a` (mismo patrón que `buildElevatorPhotoKey`).
2. Guarda una fila en una tabla nueva `work_order_elevator_audios`
   (`id, workOrderElevatorId, url, durationMs, transcript, transcriptStatus, createdAt`)
   con `transcriptStatus = 'PENDING'` y responde de inmediato.
3. Transcribe con **Whisper en Cloudflare Workers AI**
   (`@cf/openai/whisper-large-v3-turbo`, idioma `es`) llamándolo por su API
   REST con el token de la cuenta, y **guarda el texto en la base de datos**
   (`transcript`, `transcriptStatus = 'DONE'`). Si falla queda `FAILED` y se
   puede reintentar; el audio nunca se pierde.
4. La próxima vez que la app descarga la OT trae el texto; el técnico lo puede
   agregar a la nota del hallazgo con un toque. El administrador ve audio y
   texto en la web.

Costo de referencia: Workers AI cobra por "neurons" y trae una cuota diaria
gratuita; Whisper turbo cuesta del orden de US$0.0005 por minuto de audio
(confirmar en la página de precios de Cloudflare). 100 minutos de notas al día
saldrían en centavos al mes, y probablemente dentro de la cuota gratuita.

## Por qué en la web aparece "observa observa observa…"

`use-voice-input.ts` usa la Web Speech API de Chrome con
`continuous = true` e `interimResults = true`, y en cada evento **agrega** al
texto acumulado los resultados finales desde `event.resultIndex`. En Chrome de
Android ese índice vuelve a 0 y la lista de resultados se reenvía completa en
cada evento, así que las mismas frases finales se suman una y otra vez. Por eso
una palabra aparece muchas veces.

El arreglo en la web es reconstruir el texto desde cero en cada evento
(recorrer `event.results` desde 0 y quedarse con los finales) en lugar de
concatenar. La app móvil no tiene ese problema porque no hace dictado en vivo:
graba el audio completo y Whisper lo transcribe una sola vez.
