# Crashlytics: validacion controlada de Fase 6.4

## Seguridad del procedimiento

Solo Android debug con `--dart-define=YMC_CRASHLYTICS_QA=true`. No hay botones,
emision al arrancar, crashes fatales ni activacion de Analytics. Los handlers y
operaciones de la app mantienen NoOp, tambien durante QA.

Usar un AVD nuevo o una instalacion dedicada y verificada sin datos personales.
Nunca limpiar una instalacion real para preparar QA. La confirmacion del comando
no certifica por si sola que el dispositivo este limpio: debe comprobarlo el
desarrollador antes de ejecutar.

La prueba usa `ymc_crashlytics_qa_64`, separado del AVD existente. Firebase:
`yomecuido-1dc1a`; Android: `org.cecasem.yomecuido`; version: `1.0.0 (1)`.
No se inicio sesion ni se agregaron datos personales, identificadores o claves
personalizadas. El SDK puede agregar metadatos tecnicos nativos de instalacion,
sesion, version, dispositivo y sistema; el contrato propio no los sanitiza.

## Comando de desarrollo

Conectar al Dart VM Service de ese dispositivo mediante un reenvio ADB local.
Obtener el isolate `main` con `getVM` e invocar
`ext.yomecuido.crashlyticsQa` indicando `isolateId` y la accion. No guardar la URL
autenticada del servicio ni logs completos. La respuesta contiene solo fase,
estado de recopilacion, servicio habitual y ausencia/presencia de sesion.

1. `action=status`: verificar `idle`, `collectionEnabled=false`, `signedOut=true`.
2. `action=emit&confirm=YMC_CRASHLYTICS_QA_NONFATAL&isolated=true`: comprueba que
   no hay reportes anteriores, marca el intento antes de emitir, registra un
   unico evento sintetico no fatal y desactiva recopilacion en `finally`.
3. Esperar la persistencia del evento del SDK antes de cerrar normalmente la
   sesion de pruebas. Reiniciar la misma instalacion QA sin limpiar sus datos ni
   instalar aun el APK normal. No volver a invocar `emit`.
4. Reconectar al nuevo VM Service. Verificar `recorded` y recopilacion `false`.
   `action=submit&confirm=YMC_CRASHLYTICS_QA_NONFATAL&isolated=true` envia solo
   despues del reinicio y con recopilacion desactivada. No descarta el reporte.
5. Buscar `YMC_CRASHLYTICS_QA_NONFATAL` en Firebase Console, app Android correcta.
   Comprobar no fatal, un evento, version/build, traza sintetica y ausencia de
   identificadores personalizados. Un `HTTP 200` del transporte o `submitted`
   no sustituyen esta comprobacion.
6. Solo despues de confirmar Console:
   `action=restore&confirm=YMC_CRASHLYTICS_QA_NONFATAL&consoleReceived=true`.
   Desactiva, descarta pendientes restantes y marca `restored`.
7. Compilar e instalar el APK normal sin bandera QA, reiniciar y verificar
   preferencia nativa `false`, ausencia del comando QA y ausencia de reportes
   innecesarios. No borrar la instalacion para aparentar restauracion.

Si falla o queda incierto el registro, `attempted` bloquea nuevas emisiones.
No resetear ese marcador ni generar otro evento para completar esta validacion.
Si Console no confirma, dejar recopilacion apagada y la subfase pendiente.

## Evidencia actual

- Emision: una llamada aceptada por el SDK; no fatal, identificador y traza fijos.
- Preferencia nativa: `firebase_crashlytics_collection_enabled=false`, verificada
  tras la emision y durante el reinicio QA; manifiesto comun tambien `false`.
- Envio: sesion cerrada entregada a DataTransport; transporte responde HTTP 200.
- Console: recepcion confirmada de exactamente un evento no fatal, version
  `1.0.0 (1)`, en el proyecto y app indicados. La traza contiene solo
  `YoMeCuidoDiagnostic.record (crashlytics_observability_service.dart:1)`.
  La unica clave del SDK es `flutter_error_exception`, con el marcador fijo;
  no hay logs ni breadcrumbs. Dispositivo nativo: Google
  `Sdk_gphone64_x86_64`, Android 16. No se uso una cuenta de Authentication.
- Evidencia remota: [evento QA en Firebase Console](https://console.firebase.google.com/project/yomecuido-1dc1a/crashlytics/app/android:org.cecasem.yomecuido/issues/f7bbfcacc2fcfb58143162a6ad2bba71).
- Restauracion: comando `restore` aceptado con fase `restored`, recopilacion
  `false`, servicio habitual NoOp y sin sesion Auth. Despues se instalo el APK
  debug normal sin borrar datos y se verifico su arranque en frio: preferencia
  persistente `false`, comando QA ausente del VM Service, cero archivos de
  eventos/reportes pendientes y cero excepciones fatales en AndroidRuntime.
  La app permanecio en ejecucion. Se retiro el reenvio ADB y se cerro solo el
  emulador aislado; el AVD preexistente no se modifico.
- Release: APK ARM64 compilado pasando la bandera QA; AOT no contiene el comando
  ni el identificador de prueba, y el manifiesto conserva recopilacion `false`.
- APK debug normal: compilado e instalado sin bandera; no es una compilacion de
  distribucion.
- Regresion: formato y analisis OK; Flutter 478, Rules 84, migracion 5, backfill 2.

Fuentes: [control de reportes Flutter](https://firebase.google.com/docs/crashlytics/flutter/customize-crash-reports)
y [validacion Android](https://firebase.google.com/docs/crashlytics/android/get-started).
No se cambiaron dependencias, Rules, App Check, firma de produccion, scoring,
pipeline, eliminacion de cuentas ni plan Spark.
La consola de facturacion confirma Spark, sin costo (USD 0). Fase 6 cerrada;
no se habilita recopilacion permanente ni se inicia Fase 7.
