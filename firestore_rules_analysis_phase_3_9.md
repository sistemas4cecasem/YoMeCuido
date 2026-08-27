# Analisis de reglas Firestore - contenido educativo

## Instancia objetivo

- Proyecto: `yomecuido-1dc1a`
- Base: `(default)`
- Tipo: `FIRESTORE_NATIVE`
- Edicion: `STANDARD`
- Ubicacion: `southamerica-west1`

## Rutas actuales de usuario

- `users/{uid}`
- `users/{uid}/categoryProgress/{categoryId}`
- `users/{uid}/categoryProgress/{categoryId}/activities/{activityId}`
- `users/{uid}/categoryProgress/{categoryId}/activities/{activityId}/attempts/{attemptId}`
- `users/{uid}/categoryProgress/{categoryId}/exams/{examId}`
- `users/{uid}/categoryProgress/{categoryId}/exams/{examId}/attempts/{attemptId}`

Las reglas de usuario se mantienen bajo propiedad estricta del `uid`.

## Rutas nuevas de contenido educativo

- `categories/{categoryId}`
- `categories/{categoryId}/lessonPages/{lessonPageId}`
- `categories/{categoryId}/activities/{activityId}`
- `categories/{categoryId}/questions/{questionId}`
- `categories/{categoryId}/examConfig/final`

El contenido queda separado de documentos de usuario. Las opciones se mantienen
embebidas dentro de cada pregunta porque son pequeñas y pertenecen a una sola
pregunta.

## Consultas previstas

- Categorias: `categories.orderBy('order')`
- Teoria: `categories/{categoryId}/lessonPages.orderBy('order')`
- Actividades: `categories/{categoryId}/activities.orderBy('order')`
- Preguntas de actividad: `categories/{categoryId}/questions.where('activityId', isEqualTo: activityId)`
- Banco completo de examen: `categories/{categoryId}/questions.get()`
- Configuracion de examen: `categories/{categoryId}/examConfig/final.get()`

No se requieren indices compuestos para estas consultas iniciales porque usan
orden o igualdad sobre un solo campo.

## Politica de acceso

- Lectura de contenido: usuarios autenticados.
- Escritura de contenido: denegada al cliente.
- Escritura administrativa futura: Firebase Admin SDK, seed o herramienta
  confiable fuera de las reglas cliente.

## Revision critica de ataques

- Lectura publica sin autenticacion: denegada porque `categories` exige `isSignedIn()`.
- Escritura de contenido por usuario autenticado: denegada con `allow write: if false`.
- Corrupcion por update con campos extra o strings gigantes: no aplica al cliente porque no hay escritura permitida.
- Usuario B leyendo progreso de Usuario A: denegado por `isOwner(userId)`.
- Usuario B escribiendo progreso de Usuario A: denegado por `isOwner(userId)` y existencia del perfil propietario.
- Schema pollution en usuario/progreso: las reglas existentes mantienen `hasOnly(...)` en create y update.
- Orphaned subcollection access en progreso: las reglas existentes requieren `userProfileExists(userId)`.
- Mezcla de PII y contenido publico: no ocurre; `users/{uid}` conserva email y solo lo lee su propietario.
- Query mismatch para contenido: `allow read` autenticado permite `get` y `list` de las consultas previstas.

## Riesgo residual

Las reglas no validan la forma de documentos de contenido porque ningun cliente
normal puede escribirlos. La validacion de forma del contenido queda en mappers,
pruebas y el futuro proceso de seed administrativo.
