<p align="center"><img src="docs/logo.png" width="220" alt="Comisario"></p>

# Comisario

Comisario de carrera para **Assetto Corsa**: una app Lua de Custom Shaders Patch que vigila límites de pista, contactos, banderas y sanciones, offline contra la IA y online con amigos.

*Race steward for Assetto Corsa (Custom Shaders Patch Lua app): track limits, contacts, flags and penalties, offline and online. The app can be switched to English in its settings; the documentation is in Spanish.*

**[English version](README.en.md)**

![Interfaz en pantalla](docs/interfaz.png)

## Qué hace

- **Límites de pista**: toda salida, o solo el atajo con ventaja (si sueltas y pierdes velocidad, no cuenta).
- **Contactos graduados** por diferencia de velocidad: roce, contacto y choque fuerte, con culpa para quien alcanza por detrás.
- **Puntos de incidente** al estilo iRacing, con máximo configurable y descalificación al pasarlo.
- **Sanciones**: tiempo, levantar el pie, drive-through, stop and go y descalificación. Plazo en vueltas para cumplir.
- **Devolver la posición** tras un contacto, un adelantamiento por fuera de la pista o con bandera amarilla.
- **Banderas**: verde, amarilla, azul, blanca, a cuadros y negra, más amarilla total y roja decretadas por la dirección de carrera.
- **Salida parada o lanzada**: con vuelta de formación completa o corta (los autos parten en fila cerca de la meta), velocímetro contra el límite y semáforo verde.
- **Sesiones**: en práctica solo cuenta, en clasificación solo invalida la vuelta, en carrera sanciona.
- **IA**: también es vigilada y cumple en pista, si la pista permite controlarla (sin probar todavía en el juego; ver más abajo).
- **Online**: cada piloto es vigilado por su propia app y todas se avisan entre sí. Un director de carrera impone su reglamento y las banderas a todo el servidor.
- **Un reglamento por defecto**, con cada valor ajustable: sanciones de tiempo para los límites de pista y los contactos, y drive-through, stop and go o descalificación para pits, salida en falso y banderas.
- **Ganador con las sanciones aplicadas**: al terminar, la app anuncia quién ganó de verdad.
- **Español e inglés**: el idioma se elige en los ajustes; agregar otro es sumar una tabla de textos al final de `Comisario.lua`.
- **Administrador**: con una clave en las opciones del servidor, solo quien la tenga fija el reglamento, el tipo de salida y las banderas.

## Requisitos

- Assetto Corsa en PC con Content Manager.
- Custom Shaders Patch con las apps Lua activas. Probado con la versión 0.2.11.

## Instalación

1. Descarga `Comisario-1.5.0.zip` desde la sección Releases.
2. Arrástralo a la ventana de Content Manager y pulsa "Install".
3. En pista, abre "Comisario" desde la barra de apps. El engranaje de la ventana abre los ajustes.

Instalación manual: copia la carpeta `apps` dentro de la carpeta `assettocorsa` del juego.

La guía completa está en [`apps/lua/Comisario/LEEME.txt`](apps/lua/Comisario/LEEME.txt).

## Ajustes

El engranaje de la ventana abre los ajustes. Arriba se elige el idioma (español o inglés). Se muestran las opciones principales de cada pestaña; "Mostrar todas las opciones" agrega las finas.

![Ventana de ajustes](docs/ajustes.png)

*Las imágenes de esta página son dibujos hechos con el simulador de pruebas, no capturas del juego.*

## Servidor (opcional)

`servidor/comisario_servidor.lua` es un script online que el servidor reparte a cada piloto. Hace cumplir cortando el acelerador la velocidad de la formación, de la amarilla total y de la bandera roja. En la salida corta lleva cada auto a su lugar en la fila, y manda a pits al descalificado, con el auto sin controles. También guarda la clave de administrador. Los pasos están en [`servidor/INSTRUCCIONES_SERVIDOR.txt`](servidor/INSTRUCCIONES_SERVIDOR.txt).

Sin el script, todo lo demás funciona igual: la app avisa y sanciona.

## Estado del proyecto y límites conocidos

Conviene saber esto antes de usarlo en una liga:

- Probado en el juego por su autor solo, sin IA en pista, y en un servidor propio con uno o dos pilotos: sanciones, salida lanzada corta, envío a pits del descalificado, administrador, interfaz fija e íconos. No se ha probado con grillas grandes ni en servidores públicos.
- Las banderas con varios autos en pista, la dirección de carrera entre varios pilotos y el aviso de ganador solo están verificados con el simulador de pruebas de este repositorio.
- La descalificación no expulsa a nadie del servidor: deja al piloto último en la clasificación de Comisario y, con el script del servidor, en pits con el auto sin controles. La tabla final del juego no cambia.
- La clave de administrador frena a un piloto común, no a alguien que modifique el código de su app: todo corre en el PC de cada piloto.
- Online, cada piloto necesita la app. Quien no la tenga no es vigilado.
- No incluye cruce de la línea de salida de pits, DRS ni coche de seguridad.
- La vuelta de formación completa cuenta como vuelta de carrera para el juego; la salida corta no.
- La salida corta lleva los autos a la fila durante la cuenta regresiva. Conviene dejar la salida en falso del servidor en "auto bloqueado hasta la largada": con las otras opciones no está probado.
- Todo lo relacionado con la IA (sus sanciones, que cumpla en pista, la salida lanzada contra bots) solo está verificado con el simulador de pruebas: no se ha probado en el juego con bots. Si lo pruebas, se agradece el reporte.
- Controlar a la IA requiere autorizar la pista (la app modifica `surfaces.ini` y guarda un respaldo).

## Desarrollo

La lógica se prueba fuera del juego con un simulador de la API de CSP (`test/harness.lua`). Se necesita Python 3 y el paquete `lupa`:

```
pip install lupa
python3 test/check_i18n.py apps/lua/Comisario/Comisario.lua
python3 test/run_tests.py apps/lua/Comisario/Comisario.lua
python3 test/run_online.py apps/lua/Comisario/Comisario.lua
python3 test/run_server.py servidor/comisario_servidor.lua
```

`check_i18n.py` revisa que cada texto tenga su traducción al inglés. `test/preview_settings.py` dibuja la ventana de ajustes para revisar el diseño (necesita `pillow`).

## Estructura

| Carpeta | Contenido |
|---|---|
| `apps/lua/Comisario/` | La app: `Comisario.lua`, el manifiesto, la guía `LEEME.txt` y los íconos (`img/`). Es lo que se instala. |
| `servidor/` | Script online opcional para el servidor y sus instrucciones. |
| `test/` | Simulador de la API de CSP y las pruebas. |
| `arte/` | Fuentes vectoriales de los íconos y los scripts que los generan. |
| `docs/` | Imágenes de esta página. |

Ver [CONTRIBUTING.md](CONTRIBUTING.md) para proponer cambios.

## Créditos

Creado por Matías ([matipriv768-blip](https://github.com/matipriv768-blip)). El código y los íconos se hicieron con asistencia de Claude, de Anthropic; el logo se generó con Canva.

Comisario es un proyecto independiente. No está afiliado a Real Penalty, iRacing, la FIA, Kunos Simulazioni ni a los autores de Custom Shaders Patch o Content Manager, y no usa código ni archivos de esos proyectos. Algunas reglas (atajo con ventaja, escala de sanciones por velocidad) usan los mismos valores públicos de configuración de Real Penalty.

## Licencia

[MIT](LICENSE). Puedes usarlo, modificarlo y redistribuirlo, manteniendo el aviso de autoría.
