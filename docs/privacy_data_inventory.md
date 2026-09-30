# Inventario de privacidad — estado de Fase 5.4

Este documento describe el código actual. Es material preparatorio para revisión institucional, una futura política web y el formulario Data Safety; no determina por sí solo las respuestas jurídicas de Google Play. El aviso visible en la app tiene una única fuente en `assets/data/privacy_notice.json`.

## Datos y visibilidad

| Tipo de dato | ¿Se recopila? | Uso | Compartido / visible | Opcional u obligatorio | Eliminable | Ubicación |
| --- | --- | --- | --- | --- | --- | --- |
| Correo electrónico, UID y estado de verificación | Sí | Registro, autenticación, verificación y recuperación | El correo no aparece en Ranking; Firebase Authentication lo procesa. El UID también sirve como clave técnica de documentos. | Cuenta requerida; correo y UID obligatorios | Sí, con el flujo de eliminación | Firebase Authentication; correo duplicado en `users/{uid}` |
| Contraseña | Se introduce para registro, acceso, reautenticación y recuperación; la app no la guarda en el perfil | Autenticación gestionada por Firebase Authentication | No visible a otras personas desde la app | Obligatoria para cuenta con correo | Se elimina la cuenta de Authentication | Firebase Authentication, no Firestore de YoMeCuido |
| Nombre de usuario y forma normalizada | Sí | Perfil, reserva de nombre y Ranking | El nombre visible aparece en Ranking para personas autenticadas. La reserva puede consultarse individualmente por usuarios autenticados; la forma normalizada no aparece en Ranking. | Nombre requerido para perfil completo | Sí | `users/{uid}`, `usernames/{usernameNormalized}`, `leaderboard/{uid}` |
| Rol, fechas de perfil y estado `active/deleting` | Sí | Control del perfil y ciclo de eliminación | Privados en `users/{uid}` | Generados por la app | Sí | `users/{uid}` |
| Puntaje total y última adjudicación de puntos | Sí | Puntuación y consistencia de adjudicación | Puntaje total visible en Ranking para personas autenticadas; detalle de adjudicación privado | Generados al usar actividades | Sí | `users/{uid}` (`totalPoints`, `lastActivityAward`); `leaderboard/{uid}` |
| Progreso por categoría, páginas teóricas vistas y desbloqueos derivados | Sí | Reanudar aprendizaje y habilitar contenido | Privados del titular | Generados al usar la lección | Sí | `users/{uid}/categoryProgress/...` |
| Actividades, intentos, respuestas enviadas y resultados | Sí | Evaluación, sincronización y seguimiento educativo | Privados del titular | Generados al responder | Sí | Subcolecciones `activities`, `attempts`, `answerSubmissions` bajo el progreso; pendientes en almacenamiento local |
| Exámenes, preguntas seleccionadas, pruebas de evaluación y resultados | Sí | Evaluación y puntuación de exámenes | Privados del titular | Generados al rendir un examen | Sí | Subcolecciones `exams`, `attempts`, `proofs`, `answerSubmissions` bajo el progreso; pendientes en almacenamiento local |
| Registro de Ranking | Sí | Mostrar clasificación | Nombre y puntaje se muestran a personas autenticadas. El documento `leaderboard/{uid}` revela el UID técnico a clientes autenticados con acceso a Firestore; también contiene `updatedAt`, pero no correo. | Generado al participar | Sí | Cloud Firestore `leaderboard/{uid}` |
| Respuestas e intentos pendientes sin sincronizar | Sí, temporalmente en el dispositivo | Continuar y sincronizar intentos | No se muestran a otras personas desde la app | Solo si hay trabajo pendiente | Sí, por UID durante eliminación | `SharedPreferences` (`pending_quiz_attempts_v1`) |
| Estado de conectividad | Se consulta localmente | Detectar conexión para operaciones de la app | No se almacena como dato de perfil ni se envía a un backend propio | Técnico | No aplica | `connectivity_plus` y sondeo de disponibilidad de Firebase |
| Señales técnicas de protección de acceso | Sí, mediante el SDK | Proteger solicitudes a Firebase | Firebase App Check interviene en la validación; no se muestra en Ranking | Técnico | Su conservación depende del proveedor; revisar antes de completar Data Safety | Firebase App Check |

**Visible no equivale a compartido con terceros.** El Ranking es una función entre usuarios autenticados. Firebase es proveedor técnico integrado para autenticación, Firestore y App Check. La clasificación definitiva de «compartido» en Play debe revisarse con los criterios vigentes de Google y con la institución.

## Alcance comprobado en el repositorio

- `lib/data/models/user_profile.dart`, `lib/data/repositories/user_profile_repository.dart`: perfil, reserva y estado de cuenta.
- `lib/data/repositories/category_progress_repository.dart`, `lib/data/models/pending_quiz_attempt.dart`: progreso, respuestas, intentos, exámenes y puntos.
- `lib/data/repositories/leaderboard_repository.dart`, `lib/features/ranking/ranking_screen.dart`, `firestore.rules`: Ranking. La regla permite `get/list` de `leaderboard` solo con sesión; el perfil completo permite `get` solo al titular.
- `lib/data/repositories/account_deletion_repository.dart`: borrado de datos personales, Ranking, reserva, perfil, pendientes locales y cuenta Auth, con recuperación tras interrupción.
- `pubspec.yaml` y `lib/shared/services/connectivity_service.dart`: Firebase Authentication, Cloud Firestore, Firebase App Check, `connectivity_plus` y `shared_preferences`. No hay integración de Analytics, Crashlytics, anuncios ni servicio comercial de datos en el código actual.
- Manifiesto fusionado de release: `INTERNET`, `ACCESS_NETWORK_STATE`, `READ_GSERVICES`. No se observaron permisos sensibles para ubicación, contactos, cámara, micrófono, galería, archivos personales, SMS, llamadas o biometría. `android/app/src/main/AndroidManifest.xml` no agrega permisos de ejecución.

## Conservación y eliminación

No existe un período fijo de retención definido por la aplicación. Los datos asociados permanecen mientras exista la cuenta y el flujo de Perfil > Eliminar cuenta elimina los recursos enumerados arriba. Si el proceso se interrumpe, se puede continuar. El flujo no elimina contenido educativo compartido ni promete borrar instantáneamente cualquier caché interna de los SDK o registros técnicos que gestione el proveedor. Los plazos y obligaciones institucionales siguen pendientes de revisión.

Como contexto técnico, [Firebase documenta que Firestore en Android mantiene persistencia local por defecto](https://firebase.google.com/docs/firestore/manage-data/enable-offline?hl=es-419) y que [App Check protege el acceso a recursos backend](https://firebase.google.com/products/app-check). Estas referencias no sustituyen una revisión institucional de privacidad.

## Revisión de logs y errores

Se buscaron `print`, `debugPrint`, `log`, `logger`, `stackTrace` y `FirebaseException` en `lib/`. Los mensajes conservados son solo de depuración y contienen etapa y motivo técnico enumerado, sin UID, correo, usuario, respuestas, contraseña, tokens, identificadores de documentos, mensajes crudos de Firebase ni trazas. Las excepciones técnicas se capturan para traducir fallos; las pantallas muestran mensajes definidos por la aplicación. Los errores de eliminación muestran categorías de fallo, no la excepción de Firebase.

## Datos institucionales pendientes

- Identidad legal exacta del responsable del tratamiento: `[PENDIENTE DE DEFINIR]`. El identificador Android `org.cecasem.yomecuido` vincula el proyecto con CECASEM, pero no acredita razón social.
- Canal oficial de consultas de privacidad y ejercicio de derechos: `[PENDIENTE DE DEFINIR]`.
- Domicilio y otros datos de contacto requeridos para una política definitiva: `[PENDIENTE DE DEFINIR]`.
- Revisión institucional/jurídica de plazos, obligaciones y formulario Data Safety antes de publicación: `[PENDIENTE DE DEFINIR]`.
