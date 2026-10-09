# Cambios

## 1.6.0
- Radar de la formación: debajo del velocímetro, la distancia al auto que tienes que seguir (el de adelante en tu columna o, si eres el segundo de una fila doble, el que va a tu lado), con una barra y un aviso: BIEN, ACÉRCATE, ABRE ESPACIO o TE ADELANTASTE. La distancia buena es la que tenías al quedar en la fila, así sirve offline y online. Se apaga en Largada > Radar de distancia.
- Pelotón más compacto offline: el líder de la IA sube de velocidad de a poco y afloja si la fila se estira, para que todos lleguen juntos a la verde.
- Formación más corta: el tramo recto para armar la fila se busca hasta 400 m más atrás (antes 600 m).
- Script del servidor 1.12: la fila online se arma igual que offline (tramo recto, pareja cerca de la línea de la IA con el segundo 4 m detrás, nadie sobre el piano). Si no caben dos autos, va en una sola fila; todos los pilotos llegan a la misma decisión.

## 1.5.8
- Fila doble escalonada: el segundo de cada fila va 4 m detrás del primero, como en una grilla real. Con los dos exactamente lado a lado, la IA de la pole no arrancaba (visto dos veces en Spa) y frenaba a toda la fila.
- Si uno o pocos autos de la IA quedan detenidos en la formación, la app lleva solo esos a la línea de la IA, un par de metros más adelante, y deja al resto donde está. Rearmar toda la fila en una columna queda solo para cuando casi toda la IA está detenida.
- Adelantar en la formación a un auto que se salió de la pista ya no obliga a devolver el puesto.

## 1.5.7
- Salida corta offline: la fila se arma en un tramo recto. Si donde se eligió partir la pista es curva, el primero parte en el primer tramo recto más atrás (hasta 600 m más). En una curva la línea de la IA pasa por encima del piano y los autos quedaban sobre él (Spa, 500 m antes de la meta).
- El registro anota a cuántos metros de la meta parte el primero y cuánto dobla la pista en la zona de la fila.

## 1.5.6
- Salida corta offline: ningún auto parte sobre el piano. Si la línea de la IA va pegada a un borde (en Spa, a 0,5 m), la fila se corre hacia adentro lo justo para que los autos queden en la pista.
- Fila doble: la pareja puede alejarse hasta 5 m de la línea de la IA (en Spa la IA arrancó a 3 m y no a 8 m). La pole y los impares van del lado más cercano a esa línea, como en una largada real.
- La vigilancia de la formación revisa todos los autos de la IA, no solo el primero: si uno queda detenido mientras el de delante ya anda, se le despierta y, si sigue igual, se arma una sola fila.

## 1.5.5
- Fila doble offline: la pareja de cada fila ahora va pegada a la línea de la IA (1,9 m a cada lado) y no al centro de la pista. En la prueba en Spa los autos que quedaron lejos de esa línea no arrancaban, y los que quedaron cerca sí. Si la línea va pegada a un borde y la pareja no cabe cerca de ella, la fila se arma en una columna desde el principio, sin moverla a mitad de la formación.
- El registro anota el espacio que hay a cada lado de la línea de la IA donde se arma la fila.
- La vigilancia de la formación espera un poco más después de despertar a la IA antes de pasar a una sola fila.

## 1.5.4
- Corregido: offline, con la fila doble la IA podía quedarse detenida en la fila y el juego terminaba retirándola (visto en Spa). Ahora cada auto movido se "despierta" en el motor de física, y si a los pocos segundos de la formación la IA de adelante sigue sin moverse, la app la vuelve a despertar; si tampoco arranca, arma la fila en una sola columna, y como último recurso le quita el límite de velocidad. Todo queda anotado en el registro.
- La fila doble solo se arma donde caben dos autos lado a lado: si la pista es angosta en ese punto o al costado hay un muro o desnivel, toda la fila va en una columna (antes el segundo de cada fila quedaba a 6 m del de delante).
- Corregido: un auto retirado que el juego manda a pits podía hacer salir la bandera verde antes de tiempo.
- El script del servidor no cambia (sigue en 1.11).

## 1.5.3
- Salida lanzada corta en dos filas: 1 y 2 lado a lado, 3 y 4 en la fila siguiente, respetando el orden de la grilla. Offline se elige en la app (Largada > Dos filas); online lo hace el script del servidor 1.11 (opción `twoWide`, activada por defecto). La IA tiende a ponerse en una sola fila al avanzar.
- Corregido: con la bandera verde la IA que larga delante del jugador seguía limitada y lo obligaba a pasarla antes de la meta. Ahora queda libre con la verde; la de atrás sigue sin poder pasar al de delante hasta la meta.
- En la fila doble, quedar unos metros detrás del que larga al lado no cuenta como adelantamiento.
- Script del servidor 1.11: fila doble.

## 1.5.2
- Corregido: offline, con la bandera verde la IA de delante seguía limitada hasta cruzar la meta, y al acelerar quedabas obligado a pasarla (y a devolver el puesto). Ahora con la verde todos aceleran; cada auto de la IA sigue sin poder pasar al de delante hasta la meta, y el primero de la fila queda libre de inmediato.
- El registro anota si el juego deja mover los autos a la fila durante la cuenta regresiva. Si no lo deja, se espera a las luces sin dejar los controles bloqueados.

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
