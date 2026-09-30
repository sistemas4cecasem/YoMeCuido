# Fase 5.2 — Ciclo de vida de datos y contrato para eliminar una cuenta

## Estado del registro

`createUserWithEmailAndPassword` crea primero la identidad de Auth. Una única transacción de Firestore reserva `usernames/{usernameNormalized}` y escribe `users/{uid}` y `leaderboard/{uid}`. La lectura `fetchProfile` que seguía al commit podía fallar aunque las tres escrituras hubieran terminado. El alta ahora devuelve el perfil formado **antes** de la transacción y no hace esa lectura. Sus timestamps son `null` en ese valor de retorno porque los valores definitivos los asigna el servidor; la siguiente carga normal del perfil lee los timestamps persistidos.

Los errores comprobables antes del commit, como un nombre inválido o ya reservado, permiten revertir el Auth recién creado. Si la llamada de transacción falla de forma que el commit pudo haber ocurrido, no se elimina Auth: se conserva la identidad para volver a iniciar sesión y recuperar o completar el perfil. Esta distinción evita crear documentos huérfanos al interpretar un error de transporte como prueba de que Firestore no escribió. La transacción protege la atomicidad de los tres documentos en Firestore, pero Auth y Firestore no comparten una transacción. Si falla el propio `User.delete()` durante una reversión segura, el Auth puede quedar pendiente de recuperación; no debe describirse como un rollback atómico garantizado.

## Inventario y clasificación

| Ruta o almacén | Acción | Datos / condición mínima del futuro `delete` |
|---|---|---|
| `users/{uid}/categoryProgress/{categoryId}/activities/{activityId}/answerSubmissions/{attemptId}` | **Eliminar: sí** | Respuestas y resultados. `request.auth.uid == uid`. |
| `users/{uid}/categoryProgress/{categoryId}/activities/{activityId}/attempts/{attemptId}` | **Eliminar: sí** | Historial y resultados. `request.auth.uid == uid`. |
| `users/{uid}/categoryProgress/{categoryId}/activities/{activityId}` | **Eliminar: sí** | Progreso y puntaje de actividad. `request.auth.uid == uid`. |
| `users/{uid}/categoryProgress/{categoryId}/exams/{examId}/attempts/{attemptId}/proofs/{part}` | **Eliminar: sí** | Evidencia de aciertos por parte. `request.auth.uid == uid`. |
| `users/{uid}/categoryProgress/{categoryId}/exams/{examId}/answerSubmissions/{attemptId}` | **Eliminar: sí** | Respuestas del examen. `request.auth.uid == uid`. |
| `users/{uid}/categoryProgress/{categoryId}/exams/{examId}/attempts/{attemptId}` | **Eliminar: sí** | Historial y resultados del examen. `request.auth.uid == uid`. |
| `users/{uid}/categoryProgress/{categoryId}/exams/{examId}` | **Eliminar: sí** | Progreso de examen. `request.auth.uid == uid`. |
| `users/{uid}/categoryProgress/{categoryId}` | **Eliminar: sí** | Progreso de categoría y teoría. `request.auth.uid == uid`. |
| `leaderboard/{uid}` | **Eliminar: sí** | Nombre y puntos visibles a usuarios autenticados. `request.auth.uid == uid`. |
| `usernames/{usernameNormalized}` | **Eliminar: sí** | Reserva de nombre que contiene `uid`; exigir `resource.data.uid == request.auth.uid` y que el perfil propio aún asocie ese nombre. |
| `users/{uid}` | **Eliminar: sí, al final de Firestore** | Email, nombre, rol, puntos y fechas. `request.auth.uid == uid`. |
| `pending_quiz_attempts_v1` | **Eliminar: sí, solo entradas del `uid`** | Respuestas e intentos del dispositivo. No está sujeto a Firestore Rules. |
| Firebase Authentication | **Eliminar: sí, último paso** | Identidad de email/contraseña. Requiere sesión reciente. |
| `categories/{categoryId}` y `lessonPages`, `activities`, `questions`, `examConfig`, `answerKeys` | **Conservar: delete no** | Contenido global; sigue prohibido escribir o eliminarlo desde el cliente. |

El `uid` del ranking está en el ID de documento; el perfil no guarda un campo `uid`. No hay documento independiente de desbloqueos ni de progreso de categorías superiores: son derivados del progreso por categoría. Los `attempts` actuales guardan resultados e IDs de preguntas; las respuestas enviadas están en `answerSubmissions`. Un formato histórico podría contener otros campos, por lo que el borrado debe recorrer documentos reales y no depender solo de los modelos actuales.

## Orden para 5.3 en Spark

1. Mantener al usuario autenticado, comprobar conectividad efectiva y reautenticar con `EmailAuthProvider.credential(email: correoActual, password: contraseñaIntroducida)` seguido de `currentUser.reauthenticateWithCredential(credential)`. No persistir ni registrar la contraseña.
2. Entrar en modo de eliminación: suspender nuevas actividades, reservas, sincronización de `pending` y escrituras de perfil/ranking. Tras una interrupción, detectar la continuación antes de reactivar estos flujos. Este control debe quedar respaldado por las reglas y un estado recuperable; una bandera solo en memoria no basta.
3. Enumerar `categoryProgress` del `uid`. Para cada actividad, enumerar y borrar primero `answerSubmissions` y `attempts`, luego su documento de actividad. Para cada examen, borrar `proofs` de cada intento, `answerSubmissions`, `attempts` y finalmente el examen. Borrar después el documento de `categoryProgress`.
4. Borrar `leaderboard/{uid}` y `usernames/{usernameNormalized}` mientras el perfil todavía existe; borrar `users/{uid}` al final de Firestore. No basta con borrar un padre: Firestore no borra sus subcolecciones automáticamente.
5. Verificar desde el servidor que no quedan documentos en las rutas enumeradas, incluidos ranking y reserva. La verificación no puede basarse únicamente en la caché ni en el éxito de un batch.
6. Eliminar únicamente las entradas locales del `uid` en `pending_quiz_attempts_v1`, conservando las de otros usuarios.
7. Volver a comprobar que la reautenticación sigue siendo reciente y ejecutar `currentUser.delete()` **al final**. Si devuelve `requires-recent-login`, repetir la reautenticación y este paso, sin restaurar datos borrados.

Las reglas de 5.3 deben permitir esos `delete` solo al titular y seguir denegando borrados ajenos y de contenido global. La regla actual de `usernames` únicamente permite quitar la reserva durante un cambio de nombre: necesitará una rama propia para la eliminación de cuenta. Se debe probar cada ruta, incluidos los anidados, con usuario dueño, ajeno y sin autenticar. **No se cambian Rules en 5.2.**

## Reintentos y fallos parciales

Cada etapa debe enumerar de nuevo lo que existe y tratar un documento ausente como ya procesado. No debe escribir de nuevo perfiles, progreso, ranking ni submissions para "compensar" un borrado. Se deben borrar hojas antes que padres, en lotes acotados, con comprobación de resultado en servidor. Si se pierde Internet, falla una etapa o se cierra la app, detener el proceso, conservar Auth y reanudar desde el inventario restante cuando vuelva la conexión. No afirmar éxito hasta verificar todos los datos remotos y completar Auth.

Si Firestore ya quedó vacío pero falla el borrado de Auth, conservar la sesión en modo de eliminación y permitir reautenticación y reintento de Auth. La app no debe enviar a `CompleteProfileScreen` ni recrear `users`, `leaderboard` o progreso durante ese intervalo. El diseño de 5.3 necesita una señal durable y reglas que impidan esas recreaciones durante el proceso; su ciclo de vida debe resolverse sin dejar una nueva colección personal huérfana. En Spark, Auth y Firestore no pueden confirmarse en una única transacción desde el cliente, así que el contrato garantiza un proceso **reintentable y verificable**, no atomicidad absoluta ante todos los cortes de red o cierres.

`pending` al **logout**: conservar para recuperar intentos de ese `uid` al volver a iniciar sesión. Al **cambiar de usuario**: no sincronizar ni mostrar intentos de otro `uid`; conservarlos separados. Al **eliminar la cuenta**: detener sincronización y borrar solo los registros del `uid` tras verificar la limpieza remota y antes de Auth. La caché interna de Firestore es distinta: no limpiarla globalmente en 5.2; en 5.3 se debe revisar su comportamiento en el dispositivo y evitar que datos de un usuario anterior se muestren a otro, sin usar la caché como prueba de borrado remoto.

## Datos históricos y condiciones previas

No se ha consultado producción. Una auditoría posterior de huérfanos requeriría, en un entorno administrativo autorizado y primero en modo de solo lectura, comparar IDs de Auth con `users`, `leaderboard` y los `uid` de `usernames`, y enumerar subcolecciones incluso bajo padres inexistentes. No ejecutar limpieza masiva como parte de 5.2.

Antes de implementar 5.3, confirmar que las Rules locales coinciden con las desplegadas, diseñar y probar el estado durable de eliminación y definir cómo continuar si falla Auth después de borrar Firestore. Ninguno exige cambiar de Spark, pero sí pruebas de interrupción y de aislamiento entre usuarios.
