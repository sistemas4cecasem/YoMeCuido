# Auditoría interna de reglas Firestore

Archivo no versionado usado para guiar el endurecimiento de reglas.

## Colecciones reales

- `users/{uid}`: perfil privado con `username`, `usernameNormalized`, `email`, `role`, `totalPoints`, `createdAt`, `updatedAt`.
- `usernames/{usernameNormalized}`: reserva de nombre de usuario con `uid`.
- `users/{uid}/categoryProgress/{categoryId}`: progreso de categoría.
- `users/{uid}/categoryProgress/{categoryId}/activities/{activityId}`: progreso de actividad.
- `users/{uid}/categoryProgress/{categoryId}/activities/{activityId}/attempts/{attemptId}`: intentos de actividad.
- `users/{uid}/categoryProgress/{categoryId}/exams/{examId}`: progreso de examen.
- `users/{uid}/categoryProgress/{categoryId}/exams/{examId}/attempts/{attemptId}`: intentos de examen.
- `categories/{categoryId}` y subcolecciones `lessonPages`, `activities`, `questions`, `examConfig`: contenido educativo.

## Queries reales

- Contenido: `categories.orderBy('order')`, `lessonPages.orderBy('order')`, `activities.orderBy('order')`, `questions.where('activityId', isEqualTo: ...)`, documentos `examConfig/final`.
- Progreso: listar `users/{uid}/categoryProgress`, listar actividades y exámenes por categoría.
- Perfil: `users/{uid}.get()`, `usernames/{usernameNormalized}.get()`.

## Escrituras reales

- Perfil nuevo/completo/cambio de username mediante transacción con reserva en `usernames`.
- Teoría vista mediante `arrayUnion` sobre `viewedLessonPageIds`.
- Finalización de actividad mediante transacción que crea intento finalizado, actualiza actividad, categoría y `users/{uid}.totalPoints`.
- Finalización de examen mediante transacción que crea intento finalizado y actualiza examen/categoría sin tocar puntos.

## Riesgos detectados

- `firestore.rules` no incluía `totalPoints` como campo válido de perfil.
- Las reglas de actividad no incluían `activityPoints` ni `questionScores`.
- Las reglas de intento no incluían `attemptNumber` ni `earnedPoints`.
- Los intentos permitían `update`, aunque el flujo actual puede crear el intento ya finalizado.
- `questionScores` usa un mapa dinámico; Firestore Rules no permite iterar todas las claves dinámicas con robustez. Se validará forma general, tamaño, monotonicidad del mapa y límites de puntos acumulados; la validación profunda por pregunta queda como límite aceptado hasta mover autoridad completa a servidor.
