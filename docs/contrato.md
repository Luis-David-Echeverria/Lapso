# La app contra el contrato 0.9.0

El contrato vive en el repositorio `Lapso-Contrato`, carpeta `api/`. Esta es la relación entre lo que la app hace y las operaciones que usa, y lo que sigue abierto con backend.

## Operaciones que la app ya usa

| Pantalla o función | Operación |
| --- | --- |
| Tu organización (código o enlace) | `getPublicTenant` |
| Tu organización (QR) | `resolveQr` |
| Inicio de sesión, cuenta bloqueada | `loginWithPin` |
| Volver a entrar sin escribir el PIN | `getMe` |
| Cambiar PIN (obligatorio o voluntario) | `changePin` |
| Cerrar sesión | `logout` |
| Mi jornada | `getMyToday` |
| Qué evidencia pedir, consentimientos, modo sin conexión | `getMyCaptureSettings` |
| Registrar entrada, salida, pausa y reanudación | `clockIn`, `clockOut`, `breakStart`, `breakEnd` |
| Foto del registro | `uploadEvidencePhoto` |
| Enviar registros sin conexión | `syncOfflineEvents` |
| Registros rechazados | `listMyOfflineRejections` |
| Historial | `getMyTimesheets` |
| Aceptar o retirar una captura | `acceptConsent`, `revokeConsent` |
| Quién vio mis datos | `listMyEvidenceViews` |
| Mis fotos | `getMyEventPhoto` |
| Aviso de privacidad y otros textos | `getPublicLegalText` |
| Contacto de soporte | `getBranding` |

## Operaciones del contrato que la app todavía no usa

Tienen servicio, falta la pantalla. Hoy corregir un registro y confirmar el periodo se hacen en la web.

| Función | Operaciones |
| --- | --- |
| Pedir, retirar y objetar correcciones | `listMyCorrections`, `createMyCorrection`, `cancelMyCorrection`, `objectCorrection` |
| Confirmar u objetar el periodo | `getMyPeriod`, `confirmMyPeriod`, `objectMyPeriod` |
| Avisos | `listMyNotices`, `markNoticesRead` |
| Mi horario | `getMySchedule` |
| Recuperar el PIN | `requestPinRecovery` |
| Detalle de la evidencia de un registro | `getMyEventEvidence` |

## Decisiones de la app que salen del contrato

- **Los botones los decide el servidor.** Mi jornada muestra lo que trae `allowed_actions`. Por eso la salida se puede registrar durante una pausa.
- **Qué evidencia pedir** sale de `capabilities` (modo, `event_types` y `active`). Si una captura no está activa, la app no pide el permiso del sistema.
- **Idempotencia.** Cada toque genera un UUID que viaja como `Idempotency-Key`. Si no hay red, ese mismo UUID es el `idempotency_key` del evento en la cola, así que un reintento nunca duplica.
- **Sin conexión.** Solo si `offline.allowed` es verdadero. La cola se guarda cifrada en el teléfono, por organización y empleado, y se envía en lotes de hasta 50. Un evento sin conexión va sin foto, porque `uploadEvidencePhoto` necesita red y el `photo_id` dura 5 minutos.
- **Reloj.** La app manda `monotonic_ms`, `monotonic_session` y `clock_reference` con la última hora del servidor conocida. La referencia no sobrevive a cerrar la app.
- **Sesión.** La cookie `flu3nce_session` se guarda en el almacén cifrado. Un 401 en cualquier operación regresa a la pantalla de acceso; un 403 `PIN_CHANGE_REQUIRED`, a cambiar el PIN.
- **Sin red al abrir.** Se muestra la última copia de `getMe`, `getMyToday` y `getMyCaptureSettings`, con el aviso «Sin conexión».
- **Horas.** Se muestran en la zona del teléfono, no en la del centro. Solo difiere si el teléfono está en otra zona horaria.

## Supuestos por confirmar con backend

1. **Formato del QR.** La app asume una dirección cuyo último tramo es el token y cuyo parámetro `k` es el código cambiante; también acepta el token solo (`parseQrPayload` en `lib/domain/rules.dart`).
2. **Formato del enlace de organización.** La app acepta el identificador tal cual, o un enlace que lo trae al final de la ruta o en `?tenant=` (`parseOrganizationCode`).
3. **Bloqueo.** El 423 no dice cuánto falta; la app muestra una cuenta regresiva de 15 minutos desde que lo recibe, como aproximación.
4. **Reglas del PIN.** La app valida seis dígitos, no todos iguales, no secuencia, no grupos repetidos, no el número de empleado y no el PIN actual. Las reglas reales están en `dominio.md` sección 10, que no viene en la entrega.
5. **Jornada de 16 horas o más.** La app ofrece «es una jornada nueva» (`clockIn`) o «sigo en la misma» (`clockOut`). Falta saber si el servidor todavía acepta `clockOut`.
6. **Centro del QR.** `resolveQr` no devuelve el identificador del centro, así que la app no puede pedir `getMyCaptureSettings` para el centro escaneado y usa las reglas del centro asignado.

## Lo que el contrato no trae y la app necesita

- Tiempo restante del bloqueo en el 423 (`Retry-After`).
- Vigencia de la sesión y si se renueva con el uso.
- Versión mínima soportada de la app, para pedir que se actualice desde la tienda.
- Operaciones para leer y aceptar el acuerdo de medio de registro (existen `AGREEMENT_PENDING` y `AGREEMENT_VERSION_STALE`, pero no la operación).
- Catálogo de tipos de aviso (`Notice.kind`) y qué trae `ref` en cada uno.
- Registro del dispositivo para notificaciones push, si se van a usar.
- Cuenta y organización de prueba para la revisión de las tiendas.
