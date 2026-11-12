# App Store y Google Play: qué exige cada regla y cómo la cumple la app

Revisión hecha en noviembre de 2026 contra los [Lineamientos de revisión de apps de Apple](https://developer.apple.com/app-store/review/guidelines/la/) y las [políticas del Programa para Desarrolladores de Google Play](https://play.google.com/developer-content-policy/).

Alcance de la revisión: los lineamientos de Apple se leyeron completos en su página. De Google Play solo se pudo abrir la página de «Abuso de dispositivos y redes» (la regla de no actualizarse fuera de la tienda); el resto de lo que aquí se dice de Play sale del conocimiento general de sus políticas y **hay que confirmarlo en el Centro de políticas antes de publicar**. Las dos tiendas cambian sus reglas varias veces al año.

## Lo que ya se decidió en el código por estas reglas

| Regla | Qué pide | Cómo queda en la app |
| --- | --- | --- |
| Apple 2.5.2 · Play «Abuso de dispositivos y redes» | Una app no puede descargar ni instalar código que cambie su funcionalidad, ni actualizarse por un medio distinto a la tienda. | Se **quitó** la pantalla de actualización fuera de tienda (descarga, verificación SHA-256 e instalador). La app no pide `REQUEST_INSTALL_PACKAGES`. Las actualizaciones llegan solo por las tiendas. |
| Apple 5.1.5 y 5.1.1(ii) · Play «Datos del usuario» (divulgación destacada) | Avisar y obtener el consentimiento **antes** de recolectar ubicación o imágenes, diciendo qué se recolecta y para qué. | Antes del primer registro que pida ubicación o foto se muestra una pantalla propia (`ConsentimientoScreen`) que explica qué se captura, cuándo, quién lo ve y cómo retirarlo. Solo después aparece el permiso del sistema. La aceptación se guarda en el servidor con la versión del aviso (`acceptConsent`). |
| Apple 5.1.1(iv) y 5.1.2(i) | No forzar el consentimiento: si la persona se niega, la app debe seguir sirviendo. | Nada bloquea el registro. Sin consentimiento o sin permiso el registro se guarda y queda marcado. Se puede retirar el consentimiento en Más › Mis datos de captura. |
| Apple 5.1.1(iii) · Play «Permisos» | Pedir solo los datos y permisos indispensables. | Ubicación: una sola lectura en primer plano al registrar (nunca en segundo plano). Cámara: solo al tocar el botón; la foto no pasa por la galería ni se guarda en el teléfono. No se piden contactos, galería, micrófono ni almacenamiento. |
| Apple 2.5.4 | Los modos en segundo plano solo para su fin declarado. | La app no declara ningún modo en segundo plano. Los registros pendientes se envían al abrir la app o mientras está abierta. |
| Apple 2.5.14 | Indicación clara cuando se usa la cámara. | La foto se toma con la cámara del sistema, a pantalla completa, y se muestra una vista previa para aceptarla o repetirla. |
| Apple 5.1.1(i) · Play «Datos del usuario» | Política de privacidad accesible dentro de la app y en la ficha de la tienda. | «Privacidad y ayuda» se abre desde la pantalla de acceso, sin sesión, y desde Más. Muestra el aviso de privacidad vigente del servidor (`getPublicLegalText`). |
| Apple 5.1.1(v) · Play «Eliminación de cuentas» | Si la app permite crear cuentas, debe permitir pedir su eliminación. | La app **no** crea cuentas: las da de alta el empleador. «Privacidad y ayuda» explica cómo pedir el acceso, la corrección o la eliminación de los datos y de la cuenta, con el contacto público de la organización. Ver riesgos abajo. |
| Apple 2.1 y 2.3.1 | Sin contenido de marcador ni funciones ocultas. | El modo de demostración (servidor y capturas simuladas, herramientas para simular estados) solo existe si se compila con `--dart-define=LAPSO_DEMO=true`. Una compilación normal no lo incluye. |
| Apple 5.1.2 · Play «Datos del usuario» | No compartir datos con terceros sin permiso. | La app solo habla con el servidor de Lapso. No lleva publicidad, analítica ni SDK de terceros que recolecten datos. |
| Apple 4.2 | Más que una página web empaquetada. | Registro nativo con QR, ubicación, foto y modo sin conexión. |
| Apple 4.8 | Ofrecer un inicio de sesión alterno si se usan redes sociales. | No aplica: la app usa solo la cuenta que da la organización (número de empleado y PIN). |
| Apple 3.1.1 y 3.1.3(c) | Compras dentro de la app. | No hay compras ni enlaces para comprar. El servicio lo contrata la organización. |

## Lo que falta antes de enviar a revisión

Nada de esto se resuelve con código de la app.

1. **Cuenta de demostración (Apple 2.1 · Play «Acceso a la app»).** Las dos tiendas piden una organización, un número de empleado y un PIN que funcionen durante la revisión, con el servidor arriba. Hay que pedírselos a backend y escribirlos en App Store Connect y en Play Console. Conviene un centro que pida QR, ubicación y foto y un QR de prueba que el revisor pueda escanear desde una imagen.
2. **Aviso de privacidad revisado y con dirección pública.** Las dos tiendas piden la URL del aviso en la ficha. Hoy el servidor marca los textos como «Borrador técnico: pendiente de revisión legal» y la app lo muestra así; publicar con un aviso en borrador es motivo probable de rechazo.
3. **Formularios de datos.** «Privacidad de la app» en App Store Connect y «Seguridad de los datos» en Play Console. Lo que la app recolecta: ubicación precisa (opcional), fotos (opcional), identificadores de la cuenta (número de empleado) y los registros de jornada. Todo ligado a la persona, cifrado en tránsito, sin fines de publicidad ni rastreo y sin compartir con terceros. Los plazos de conservación y el procedimiento de eliminación los debe confirmar backend.
4. **Notas para el revisor.** Explicar que es una app para empleados de organizaciones clientes (Apple 3.1.3(c)), que las cuentas las crea el empleador (4.8 y 5.1.1(v)) y para qué se usan la cámara y la ubicación.
5. **Carpetas de plataforma.** Permisos, textos de permiso, íconos, firma y versiones mínimas: ver [plataformas.md](plataformas.md).
6. **Prueba en teléfonos reales** de iOS y Android: permisos negados, sin conexión, cámara y QR.

## Riesgos que conviene decidir pronto

- **Eliminación de cuenta (Apple 5.1.1(v)).** La regla habla de apps que permiten *crear* cuentas, y aquí no se crean. Aun así Apple a veces la pide a apps empresariales. Tener el contacto público de la organización capturado en el servidor (`public_contact_email`) es lo que hace que la pantalla muestre a quién escribir.
- **Trámites en la web.** Corregir un registro y confirmar el periodo hoy abren el navegador. Es válido, pero el contrato 0.9.0 ya tiene esas operaciones; hacerlos nativos refuerza 4.2.
- **Versión mínima.** Sin actualización propia, hace falta que el servidor diga cuál es la versión mínima soportada para pedirle a la persona que actualice desde la tienda. No está en el contrato.
- **Herramientas de vigilancia (Play).** La política sobre apps de monitoreo se dirige a las que rastrean a una persona sin que lo sepa. Aquí cada captura la inicia el propio trabajador y se le avisa antes; no debería aplicar, pero conviene describirlo así en la ficha.
- **Nivel de API de Android.** Play exige compilar contra un nivel de API reciente y lo sube cada año. Hay que revisar el vigente el día de publicar.

## Fuentes

- [App Store Review Guidelines (español)](https://developer.apple.com/app-store/review/guidelines/la/)
- [Google Play: Abuso de dispositivos y redes](https://support.google.com/googleplay/android-developer/answer/9888379?hl=en)
- [Google Play: Centro de políticas para desarrolladores](https://play.google.com/developer-content-policy/)
