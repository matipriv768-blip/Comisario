# Cambios

## 1.5.1
- Offline, salida corta: los autos van a la fila durante la cuenta regresiva, igual que online. Antes aparecían en la grilla y saltaban a la fila al apagarse las luces.
- Offline, formación: cada auto de la IA anda al ritmo del que tiene delante, así nadie adelanta antes de la largada. Si alguno se adelanta, frena hasta que el otro vuelva a quedar delante.
- Después de la bandera verde, cada auto de la IA queda libre recién al cruzar la meta (antes se soltaban todos a la vez, antes de la meta).
- Corregido: después de una salida corta saltaba la bandera azul al cruzar la meta. La azul ahora usa el avance medido por la app y no el contador de vueltas del juego.
- Corregido: al reiniciar la carrera desde el menú quedaban sanciones, puntos y banderas de la carrera anterior.

## 1.5.0
- Idioma: la app completa se puede usar en español o en inglés (ajustes, avisos, panel e indicadores). Se elige arriba de los ajustes.
- Ajustes nuevos: nombre corto a la izquierda y control a la derecha, explicación al pasar el mouse, lista desplegable para el tipo de sanción y resumen del reglamento en uso. Se muestran solo las opciones principales; "Mostrar todas las opciones" agrega el resto.
- Indicadores más nítidos: contorno propio del juego en vez de copias del texto, todo dibujado en píxeles enteros, íconos en tres tamaños y escala según el alto de la pantalla.
- La columna de indicadores baja al 22 % de la pantalla para no tapar el espejo virtual.
- Script del servidor 1.10: opción `language = 'en'` para sus mensajes.
- Para quien traduce: `test/check_i18n.py` revisa que no falte ninguna traducción.

## 1.4.1
- Corregido: un descalificado con un drive-through pendiente recibía el aviso "drive-through no válido" al quedar detenido en pits. Ahora las sanciones pendientes se borran al descalificar.
- Script del servidor 1.8: al entrar al servidor muestra qué versión está cargada, para comprobar que el enlace del gist entrega la última.
- Script del servidor 1.9: en la salida corta el auto va a la fila apenas carga la carrera, durante la cuenta regresiva, y espera las luces ahí con los controles bloqueados. Antes aparecía en la grilla y saltaba a la fila al apagarse las luces.

## 1.4.0
- Interfaz fija: los indicadores van en una columna en un lugar fijo de la pantalla, elegido en los ajustes, y ya no son ventanas que se mueven.
- Estilo sin fondo: solo el ícono y las letras, con contorno oscuro. El fondo se puede volver a activar.
- El semáforo verde dura 8 segundos.

## 1.3.1
- Corregido: en la salida corta el auto quedaba mirando en sentido contrario.
- Corregido: después de la bandera verde, el script volvía a llevar los autos a la fila una y otra vez.
- El lugar en la fila cuenta solo los autos conectados, no los cupos vacíos del servidor.
- Quien entra con la carrera en marcha no es llevado a la fila.
- El descalificado queda en pits con los controles del auto bloqueados.
- Script del servidor 1.7.

## 1.3.0
- Salida lanzada corta: al largar, los autos van en fila a la última parte de la pista en vez de dar la vuelta de formación completa.
- Indicador de largada: velocidad contra el límite durante la formación (y durante la amarilla total o la roja) y semáforo verde al largar.
- El descalificado es enviado a pits, y de nuevo cada vez que vuelva a salir.
- Script del servidor 1.6.

## 1.2.0
- Íconos nuevos para las ocho banderas y las ocho sanciones, y logo nuevo.
- El cartel de sanción pendiente muestra el ícono y qué hay que hacer.
- Opción para volver a las banderas simples dibujadas.

## 1.1.0
- Un solo reglamento por defecto, más suave: límites de pista y contactos se sancionan con tiempo en vez de drive-through. Se quitaron los reglamentos de partida.
- Aviso del ganador con las sanciones aplicadas.
- Descalificación efectiva: el descalificado queda limitado a 50 km/h (con el script del servidor, u offline con la pista autorizada).
- Administrador: `adminPass` en el servidor; solo quien tenga la clave fija reglamento, salida y banderas, y los demás no pueden cambiarlos ni apagar la app. `requireApp` limita a 60 km/h a quien entre sin la app.
- Script del servidor 1.5.

## 1.0.2
- Corregido: tocar fondo en una bajada frenando o doblando fuerte se contaba como golpe contra el muro. Ahora solo cuenta un cambio de velocidad imposible para los neumáticos (más de 6 g).
- Salida lanzada: la bandera verde sale 100 m antes de la meta (ajustable), para que el limitador ya esté suelto al cruzarla.
- Con el script del servidor, el tipo de salida (parada o lanzada) se elige en la app; `lockStart = 1` en el servidor lo bloquea.
- Script del servidor 1.4.

## 1.0.0
- Banderas: verde, amarilla (auto detenido o sin control adelante), azul, blanca, a cuadros y negra.
- Prohibido adelantar con bandera amarilla: devolver el puesto o sanción.
- Dirección de carrera: amarilla total y bandera roja, offline o decretadas por el director para todo el servidor.
- Script del servidor: corta el acelerador sobre la velocidad de la amarilla total y la roja.
- Publicado como código abierto con licencia MIT.

## 0.8.0
- Reglamento Real Penalty: atajo con ventaja, escala de sanciones por velocidad, plazo de 2 vueltas y regla de las últimas vueltas.
- Script del servidor 1.1: la velocidad de formación la fija la app; bandera verde sin retraso al cruzar la meta.

## 0.1 a 0.7 (betas)
- Límites de pista, velocidad en pits y salida en falso.
- Contactos graduados, culpa, puntos de incidente y sanciones a elección.
- La IA cumple en pista; corregido el falso golpe contra el muro al salir de la pista.
- Indicadores en pantalla; práctica solo cuenta y clasificación solo invalida la vuelta.
- Online entre apps, con director de carrera.
- Salida parada o lanzada, devolver la posición, stop and go, descalificación y máximo de puntos de incidente.
- Script del servidor que impone la salida lanzada; cronómetro para no contar dos veces la misma salida de pista.
