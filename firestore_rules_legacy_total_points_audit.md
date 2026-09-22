# Auditoría local: perfiles antiguos sin totalPoints

## Hallazgo

Algunos perfiles creados antes de la puntuación personal pueden tener
`username`, `usernameNormalized`, `email`, `role`, `createdAt` y `updatedAt`,
pero no `totalPoints`.

La app lee esos perfiles como `totalPoints = 0`, pero la primera consolidación
de una actividad actualiza `users/{uid}.totalPoints`. Las reglas anteriores
exigían que `resource.data.totalPoints` ya fuera un entero, por lo que Firestore
rechazaba el guardado aunque la transacción de progreso fuera válida.

## Ajuste

Se agregó una transición limitada para perfiles antiguos completos que sólo
permite añadir `totalPoints` y actualizar `updatedAt`.

Restricciones conservadas:

- El usuario debe ser dueño del documento.
- `username`, `usernameNormalized`, `email`, `role` y `createdAt` no pueden
  cambiar.
- `role` debe permanecer en `user`.
- `totalPoints` debe ser entero entre 0 y 100 para esa primera consolidación.
- No se permite agregar campos arbitrarios.

## Validación

- `npm run test:rules`
- `npx -y firebase-tools@latest deploy --only firestore:rules --dry-run`
- `flutter analyze`
- `flutter test test/app/category_progress_controller_test.dart test/data/repositories/category_progress_repository_test.dart`

Las reglas fueron desplegadas con:

- `npx -y firebase-tools@latest deploy --only firestore:rules`
