# Cómo contribuir

Gracias por querer mejorar Comisario. Se aceptan reportes de errores, ideas y cambios de código.

## Reportar un error

Abre un issue con:

- Versión de Comisario, de Custom Shaders Patch y de Content Manager.
- Pista, auto y tipo de sesión (práctica, clasificación o carrera; offline u online).
- Qué pasó y qué esperabas que pasara. Un video corto ayuda mucho.
- El archivo `comisario_log.txt`, que la app guarda en la carpeta de registros de Assetto Corsa (Documentos/Assetto Corsa/logs).

## Proponer un cambio de código

1. Haz un fork y crea una rama para tu cambio.
2. Corre las tres series de pruebas y la revisión de traducciones, y verifica que pasen (ver README).
3. Si agregas o cambias una regla, agrega una prueba que falle sin tu cambio.
4. Abre un pull request explicando qué cambia y cómo lo probaste, en el simulador y, si pudiste, en el juego.

## Criterios del código

- Toda la app vive en `apps/lua/Comisario/Comisario.lua`, ordenada en secciones numeradas.
- Solo se usan funciones de la API de CSP que estén verificadas en el SDK oficial (`acc-lua-sdk`). Las dudosas van dentro de `pcall`.
- Los textos que ve el piloto se escriben en español dentro de `tr('...')`, y su traducción va en la tabla `EN` del final del archivo, con los mismos huecos (`%s`, `%d`) en el mismo orden. `python3 test/check_i18n.py apps/lua/Comisario/Comisario.lua` avisa si falta alguna. El mensaje grande del juego no admite tildes: pasa por `plain()`.
- Un archivo Lua admite 200 variables locales sueltas y la app está cerca de ese tope: las piezas nuevas van dentro de una tabla (como `W` para los ajustes o `HX` para los indicadores).
- `python3 test/preview_settings.py salida.png es` dibuja la ventana de ajustes para revisar que nada se monte ni se salga.
- Los ajustes nuevos se agregan a `ac.storage` con un valor por defecto que no cambie el comportamiento anterior. Si forman parte del reglamento, también van en `RULE_KEYS`, y hay que subir el número de la clave `comisario:reglas:N` porque cambia el formato del mensaje online.
- Los mensajes online viajan por el chat del servidor: menos de 175 bytes y al menos 200 ms entre uno y otro.
- No se acepta código copiado de otros plugins.
