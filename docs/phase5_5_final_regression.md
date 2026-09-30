# Fase 5.5 — Regresión final y estado de cierre

Validación realizada el 29 y 30 de septiembre de 2026 sobre `yomecuido-1dc1a`, con una cuenta desechable creada desde la aplicación. Este reporte contiene solo cantidades y tipos de datos; omite correo, UID, nombre de usuario, contraseña y respuestas.

## Resultado del flujo real

| Comprobación | Resultado |
| --- | --- |
| Rules locales frente a la versión remota activa | Coinciden; no se desplegaron cambios durante esta subfase. |
| Registro y aviso de privacidad desde Registro | Cuenta creada desde la UI; aviso accesible sin bloquear el alta. |
| Firebase Auth, perfil, reserva y Ranking tras el alta | Los cuatro existían; el correo quedó verificado. |
| Uso de la app | Teoría abierta y una actividad completada; se generaron progreso, intento, respuestas y puntos. El Ranking mostró nombre y puntos, no correo. |
| Aviso desde Perfil | Accesible; explica Ranking y eliminación y enlaza la acción de borrar cuenta. |
| Cancelación | No inició eliminación; perfil y Ranking continuaron presentes. |
| Contraseña incorrecta | Mensaje controlado; perfil y Ranking continuaron presentes y la cuenta no entró en `deleting`. Los perfiles antiguos sin campo `accountState` se interpretan como `active` por el modelo. |
| Contraseña correcta y eliminación | Reautenticación y flujo completo desde la UI; retorno a la pantalla de acceso. |
| Auth y login posterior | La identidad dejó de existir; el intento de acceso fue rechazado sin recrear perfil, reserva ni Ranking. |

Inventario remoto antes de borrar: 1 perfil, 1 reserva, 1 documento de Ranking, 1 progreso de categoría, 1 actividad, 1 intento de actividad y 1 `answerSubmission`. Perfil y Ranking tenían puntos. No se creó examen.

Lectura remota después de borrar: 0 en Auth, perfil, reserva, Ranking, progreso de categoría, actividad, intento y `answerSubmission`. Se consultaron también las rutas conocidas de categoría y actividad tras desaparecer sus padres; ambas dieron 0. Las rutas de exámenes no habían sido usadas. No se generó un `pending` local en la prueba real porque hubiera requerido manipular artificialmente otro intento; la limpieza selectiva por UID se verificó con la prueba automatizada.

## Regresión automatizada

- Las 7 pruebas originales de ciclo de registro cubren éxito, fallos, reversión segura y reintentos. Una prueba adicional recorre eliminación y nuevo registro con el mismo nombre liberado usando dobles locales de Firebase; no se creó otra cuenta real.
- Las pruebas de eliminación cubren orden de reautenticación, borrado y Auth final; reinicio tras fallos de cada etapa, idempotencia, `requires-recent-login` y recuperación cuando solo queda Auth.
- La prueba del almacén conserva perfil, progreso, Ranking y reserva de otro UID. La prueba de pendientes elimina solo los registros del UID borrado y conserva los del otro.
- La suite de Rules cubre transición irreversible a `deleting`, bloqueo de nuevas escrituras, borrado del titular y denegación a terceros o sin Auth, así como protección del contenido global y de `answerKeys`.

## Logs, permisos y privacidad

En los logs del proceso de la app no se encontraron el correo, UID, nombre de usuario ni contraseña de prueba, respuestas, rutas personales, `FirebaseException` cruda o trazas innecesarias. **Excepción:** el proveedor `AndroidDebugProvider` de Firebase App Check emitió su secreto de depuración en `logcat` (se observaron líneas con formato de token). No se reproduce ni conserva ese valor en el reporte. `lib/main.dart` selecciona ese proveedor solo en `kDebugMode`; la compilación no debug selecciona `AndroidPlayIntegrityProvider`. El requisito literal de Fase 5.5 de que no aparezcan tokens en los logs de la prueba queda **sin cumplir**; no se modificó la configuración de App Check, fuera del alcance de esta fase.

El manifiesto fusionado de release conserva únicamente `INTERNET`, `ACCESS_NETWORK_STATE` y `READ_GSERVICES`; no aparecieron permisos sensibles nuevos. El inventario de privacidad y el aviso siguen describiendo los datos, el Ranking y el borrado observados. Siguen pendientes la identidad legal exacta, el canal oficial de privacidad, el domicilio/contacto, la revisión institucional y el Data Safety definitivo.

El archivo temporal local usado para automatizar la cuenta desechable permanece fuera del repositorio: la revisión automática rechazó tanto la retirada del directorio como el borrado individual de sus archivos. La contraseña de prueba está protegida mediante DPAPI. Esto no afecta el borrado remoto, pero requiere limpieza local manual cuando se permita.

## Auditoría histórica de solo lectura

Se compararon las colecciones superiores de Auth, `users`, `usernames` y `leaderboard` sin escribir ni borrar datos. Existían 4 identidades Auth, 5 perfiles, 5 reservas y 5 registros de Ranking. Se detectaron **1 perfil sin identidad Auth** y **1 reserva de nombre sin perfil coincidente**. No se encontraron Auth sin perfil, perfiles sin reserva o Ranking, Ranking sin perfil ni perfiles en `deleting`. Estas dos posibles inconsistencias históricas quedan como **deuda de limpieza supervisada**; no se atribuyen a la cuenta desechable recién eliminada y no se hizo limpieza automática.

## Estado

La eliminación real y la regresión funcional pasaron. **El cierre formal estricto de Fase 5 queda pendiente** por la emisión del secreto de depuración de App Check en `logcat`; las inconsistencias históricas se documentan por separado y no bloquearían por sí solas el cierre técnico. No se inició Fase 6.

Suites finales: `dart format .` aplicado; `flutter analyze` sin observaciones; `flutter test` con 412 pruebas aprobadas; Rules con 84 casos aprobados; migración con 5 y backfill con 2; `git diff --check` sin errores. `git status --short` conserva los cambios no confirmados de las subfases previas y añade este reporte y dos comprobaciones de regresión: progreso ajeno y reutilización del nombre liberado.
