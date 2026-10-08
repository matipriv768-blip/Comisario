"""Pruebas del script del servidor (comisario_servidor.lua)."""
import sys
from lupa import luajit21 as lj

SCRIPT = sys.argv[1]
results = []


def scenario(name, body, pre=''):
    lua = lj.LuaRuntime(unpack_returned_tuples=True)
    if pre:
        lua.execute(pre)
    lua.execute("local f = assert(loadfile('test/harness.lua')); f('%s')" % SCRIPT)
    lua.execute("T.sim.isOnlineRace = true; LINK = T.shared['comisario:enlace:7|shared']")
    # el aviso de version sale en el primer cuadro: se guarda aparte para no contarlo como mensaje de carrera
    lua.execute('''
      T.versionMsgs = {}
      local realSet = ac.setMessage
      ac.setMessage = function (a, b)
        if tostring(a):find('^COMISARIO SERVIDOR') or tostring(a):find('^COMISARIO SERVER') then T.versionMsgs[#T.versionMsgs + 1] = tostring(a) .. ' | ' .. tostring(b) return end
        return realSet(a, b)
      end
    ''')
    try:
        ok = lua.execute(body)
        results.append((name, bool(ok), '' if ok else 'mensajes: ' + ' // '.join(list(lua.eval('T.messages').values())[-3:])))
    except Exception as e:  # noqa
        results.append((name, False, str(e)[:300]))


scenario('formacion: sobre el limite se suelta el acelerador; bajo el limite, no', '''
  place(0, 0, 90); run(2)
  local calm = #T.forcedCuts == 0 and lastMsg():find('VUELTA DE FORMACION | Maximo 100 km/h') ~= nil
  place(0, 0, 130); run(1)
  local cut = #T.forcedCuts > 30 and T.forcedCuts[1] == 0.1
  local n = #T.forcedCuts
  place(0, 0, 99); run(1)
  return calm and cut and #T.forcedCuts == n
''')

scenario('bandera verde cuando un auto completa la vuelta: el limite desaparece', '''
  place(0, 0, 130); run(1)
  local n = #T.forcedCuts
  T.cars[1].lapCount = 1; run(0.5)
  place(0, 0, 250); run(3)
  return n > 0 and #T.forcedCuts == n and lastMsg():find('BANDERA VERDE') ~= nil and #T.messages == 2
''')

scenario('en pits, en practica o antes de la largada no limita', '''
  local c = place(0, 0, 150)
  c.isInPitlane = true; run(1); c.isInPitlane = false
  T.sim.raceSessionType = 1; run(1)
  T.sim.raceSessionType = 3; T.sim.isSessionStarted = false; run(1)
  return #T.forcedCuts == 0
''')

scenario('nueva carrera en el mismo servidor: otra vez hay formacion', '''
  place(0, 0, 130); run(1); T.cars[1].lapCount = 1; run(1)
  T.sim.isSessionStarted = false; run(0.5)
  T.cars[1].lapCount = 0; T.sim.isSessionStarted = true
  local n = #T.forcedCuts
  run(1)
  return #T.forcedCuts > n and msgCount('VUELTA DE FORMACION') == 2
''')

scenario('velocidad ajustable desde las opciones del servidor', '''
  place(0, 0, 70); run(1)
  local cut = #T.forcedCuts > 0 and lastMsg():find('Maximo 60 km/h') ~= nil
  return cut and LINK.srvMode == 2 and LINK.srvSpeed == 60 and LINK.srvTick > 30
''', pre='SCRIPT_CFG = { rollingStart = 1, lockStart = 1, formationSpeed = 60 }')

scenario('con rollingStart = 0 el script no hace nada y avisa a la app que la salida es parada', '''
  place(0, 0, 200); run(2)
  return #T.forcedCuts == 0 and #T.messages == 0 and LINK.srvMode == 1
''', pre='SCRIPT_CFG = { rollingStart = 0, lockStart = 1, formationSpeed = 100 }')

scenario('la velocidad de la app Comisario manda sobre la del servidor mientras la app responda', """
  LINK.appSpeed = 70
  place(0, 0, 80)
  T.sim.isSessionStarted = false                        -- la app ya estaba corriendo antes de la largada
  run(0.2, function () LINK.appTick = (LINK.appTick + 1) % 60000 end)
  T.sim.isSessionStarted = true
  run(1, function () LINK.appTick = (LINK.appTick + 1) % 60000 end)
  local cut = #T.forcedCuts > 30 and lastMsg():find('Maximo 70 km/h') ~= nil
  place(0, 0, 65); local n = #T.forcedCuts
  run(1, function () LINK.appTick = (LINK.appTick + 1) % 60000 end)
  local calm = #T.forcedCuts == n
  place(0, 0, 80); run(2.5); n = #T.forcedCuts         -- la app sigue respondiendo hace menos de 3 s
  run(2)                                                -- la app se cerro: vuelve el limite del servidor (100)
  local back = #T.forcedCuts - n < 60
  n = #T.forcedCuts; run(1)
  return cut and calm and back and #T.forcedCuts == n and LINK.srvSpeed == 100
""")

scenario('la app puede llegar por cualquiera de los tres enlaces', """
  local ok = true
  run(0.1)
  for _, space in ipairs({ 'def', 'server_script', 'shared' }) do
    local l = T.shared['comisario:enlace:7|' .. space]
    if not l or l.srvMode ~= 0 or l.srvTick < 1 then ok = false end
  end
  local l = T.shared['comisario:enlace:7|server_script']
  l.appSpeed = 60; place(0, 0, 65)
  run(1, function () l.appTick = (l.appTick + 1) % 60000 end)
  return ok and #T.forcedCuts > 30
""", pre='')

scenario('bandera verde 100 m antes de la meta por posicion en pista, sin esperar al contador de vueltas', """
  local c = place(0, 0, 130); c.splinePosition = 0.99; run(0.5)
  c.splinePosition = 0.03; run(0.5)                     -- de la grilla a la meta: sigue la formacion
  local n1 = #T.forcedCuts
  c.splinePosition = 0.55; run(0.5); c.splinePosition = 0.97; run(0.5)
  local limiting = #T.forcedCuts > n1 and msgCount('BANDERA VERDE') == 0
  c.splinePosition = 0.985; run(0.05)
  local n2 = #T.forcedCuts
  run(1)
  return limiting and c.lapCount == 0 and lastMsg():find('BANDERA VERDE') ~= nil and #T.forcedCuts == n2
""")

scenario('greenMeters = 0: la verde sale recien al cruzar la meta; la app puede pedir otra distancia', """
  local c = place(0, 0, 130); c.splinePosition = 0.55; run(0.5); c.splinePosition = 0.995; run(0.5)
  local held = msgCount('BANDERA VERDE') == 0
  LINK.appGreen = 200                                    -- la app pide la verde 200 m antes
  c.splinePosition = 0.97
  run(0.2, function () LINK.appTick = (LINK.appTick + 1) % 60000 end)
  return held and lastMsg():find('BANDERA VERDE') ~= nil
""", pre='SCRIPT_CFG = { rollingStart = 1, formationSpeed = 100, greenMeters = 0 }')

scenario('amarilla total decretada en la app: el limitador corta sobre esa velocidad, tambien con la carrera ya lanzada', """
  T.cars[1].lapCount = 1; place(0, 0, 200); run(1)      -- carrera lanzada: sin limite
  local free = #T.forcedCuts == 0
  LINK.appLimit = 80
  run(1, function () LINK.appTick = (LINK.appTick + 1) % 60000 end)
  local cut = #T.forcedCuts > 30
  place(0, 0, 75); local n = #T.forcedCuts
  run(1, function () LINK.appTick = (LINK.appTick + 1) % 60000 end)
  local calm = #T.forcedCuts == n
  LINK.appLimit = 0; place(0, 0, 200)
  run(1, function () LINK.appTick = (LINK.appTick + 1) % 60000 end)
  return free and cut and calm and #T.forcedCuts == n
""")

scenario('amarilla total tambien con salida parada (rollingStart = 0) y en practica', """
  T.sim.raceSessionType = 1
  LINK.appLimit = 60; place(0, 0, 100)
  run(1, function () LINK.appTick = (LINK.appTick + 1) % 60000 end)
  return #T.forcedCuts > 30 and #T.messages == 0
""", pre='SCRIPT_CFG = { rollingStart = 0, formationSpeed = 100 }')

TICK = "function () LINK.appTick = (LINK.appTick + 1) % 60000 end"

scenario('la app elige salida parada: no hay formacion ni limitador aunque el servidor diga lanzada', """
  LINK.appMode = 1
  T.sim.isSessionStarted = false; run(0.2, %s); T.sim.isSessionStarted = true
  place(0, 0, 200); run(2, %s)
  return #T.forcedCuts == 0 and #T.messages == 0 and LINK.srvMode == 0
""" % (TICK, TICK))

scenario('la app elige salida lanzada aunque el servidor diga parada', """
  LINK.appMode = 2
  T.sim.isSessionStarted = false; run(0.2, %s); T.sim.isSessionStarted = true
  place(0, 0, 130); run(1, %s)
  return #T.forcedCuts > 30 and lastMsg():find('VUELTA DE FORMACION') ~= nil
""" % (TICK, TICK), pre='SCRIPT_CFG = { rollingStart = 0, formationSpeed = 100 }')

scenario('lockStart = 1: el servidor impone la lanzada aunque la app pida parada', """
  LINK.appMode = 1
  T.sim.isSessionStarted = false; run(0.2, %s); T.sim.isSessionStarted = true
  place(0, 0, 130); run(1, %s)
  return #T.forcedCuts > 30 and LINK.srvMode == 2
""" % (TICK, TICK), pre='SCRIPT_CFG = { rollingStart = 1, lockStart = 1, formationSpeed = 100 }')

scenario('sin app (o con la app cerrada) vale el tipo de salida del servidor', """
  LINK.appMode = 1                                       -- quedo escrito, pero la app ya no responde
  place(0, 0, 130); run(1)
  return #T.forcedCuts > 30
""")

scenario('clave de administrador: el script deja su huella para la app; sin clave, la huella es 0', """
  run(0.1)
  local h = 5381
  for n = 1, #'secreto' do h = (h * 33 + ('secreto'):byte(n)) % 4294967296 end
  return LINK.srvAuth == h and h > 0
""", pre="SCRIPT_CFG = { rollingStart = 1, formationSpeed = 100, adminPass = 'secreto' }")

scenario('sin clave de administrador la huella es 0', """
  run(0.1)
  return LINK.srvAuth == 0
""")

scenario('requireApp = 1: sin la app activa, pasados 30 s el auto no pasa de 60 km/h; con la app, corre libre', """
  T.cars[1].lapCount = 1; place(0, 0, 150)              -- carrera ya lanzada
  run(20)
  local grace = #T.forcedCuts == 0
  run(12)
  local capped = #T.forcedCuts > 30 and lastMsg():find('COMISARIO OBLIGATORIO') ~= nil
  place(0, 0, 55); local n = #T.forcedCuts; run(1)
  local slowOk = #T.forcedCuts == n
  LINK.appOn = 1; place(0, 0, 150)
  run(1, %s); n = #T.forcedCuts
  run(2, %s)
  local free = #T.forcedCuts == n
  LINK.appOn = 0                                         -- apago el comisario en la app
  run(1, %s)
  return grace and capped and slowOk and free and #T.forcedCuts > n
""" % (TICK, TICK, TICK), pre='SCRIPT_CFG = { rollingStart = 1, formationSpeed = 100, requireApp = 1 }')

scenario('sin requireApp, quien no tiene la app corre libre con la carrera lanzada', """
  T.cars[1].lapCount = 1; place(0, 0, 150); run(40)
  return #T.forcedCuts == 0
""")

scenario('salida corta desde el servidor: al largar, el auto va a su lugar en la fila y rige el limite de formacion', """
  T.cars[0].racePosition = 3; T.cars[1].racePosition = 1; T.cars[2].racePosition = 2
  T.cars[0].splinePosition = 0.985; T.cars[1].splinePosition = 0.99
  T.sim.isSessionStarted = false; run(0.2); T.sim.isSessionStarted = true
  run(0.1)
  local moved = #T.teleports == 1 and T.teleports[1].i == 0 and math.abs(T.teleports[1].z - 2980) < 1
    and math.abs(T.teleports[1].dir.z + 1) < 0.001 and lastMsg():find('SALIDA LANZADA | Maximo 100 km/h') ~= nil
  run(3)                                                 -- el otro auto sigue en la grilla, pegado a la meta: no es la verde
  local noGreen = msgCount('BANDERA VERDE') == 0 and #T.teleports == 1
  place(0, 3100, 130); run(1)
  local capped = #T.forcedCuts > 30
  place(1, 3200, 90); run(1); place(1, 3420, 95); run(0.1)   -- el lider rueda y llega a 80 m de la meta
  local n = #T.forcedCuts
  place(0, 3300, 200); run(1)
  return moved and noGreen and capped and lastMsg():find('BANDERA VERDE') ~= nil and #T.forcedCuts == n and T.cars[1].lapCount == 0
""", pre='SCRIPT_CFG = { rollingStart = 1, formationSpeed = 100, greenMeters = 100, startMeters = 500, twoWide = 0 }')

scenario('salida corta: la distancia la fija la app; con 0 en la app se hace la vuelta completa aunque el servidor diga otra cosa', """
  LINK.appStart = 800; LINK.appMode = 2
  T.sim.isSessionStarted = false; run(0.2, %s); T.sim.isSessionStarted = true
  run(0.2, %s)
  local far = #T.teleports == 1 and math.abs(T.teleports[1].z - 2700) < 1
  T.sim.isSessionStarted = false; LINK.appStart = 0; run(0.5, %s); T.sim.isSessionStarted = true
  run(0.5, %s)
  return far and #T.teleports == 1 and msgCount('VUELTA DE FORMACION') == 1
""" % (TICK, TICK, TICK, TICK), pre='SCRIPT_CFG = { rollingStart = 1, formationSpeed = 100, startMeters = 500, twoWide = 0 }')

scenario('sin startMeters ni app, la salida lanzada sigue siendo de vuelta completa y nadie es movido', """
  place(0, 0, 90); run(2)
  return #T.teleports == 0 and lastMsg():find('VUELTA DE FORMACION') ~= nil
""")

scenario('descalificado por la app: el script lo manda a pits, y de nuevo si vuelve a salir', """
  T.cars[1].lapCount = 1; local c = place(0, 0, 150)
  run(1, %s)
  local none = #T.pitTeleports == 0
  LINK.appDq = 1; LINK.appLimit = 50
  run(1, %s)
  local sent = #T.pitTeleports == 1 and T.pitTeleports[1].set == 'PIT' and lastMsg():find('DESCALIFICADO | Fuiste enviado a pits') ~= nil
  run(10, %s)
  local stays = #T.pitTeleports == 1 and T.noInput == true        -- en pits queda sin controles
  c.isInPitlane = false; place(0, 0, 150)
  run(1, %s)
  local again = #T.pitTeleports == 2
  LINK.appDq = 0                                                   -- sesion nueva: la app ya no lo tiene descalificado
  run(0.5, %s)
  return none and sent and stays and again and T.noInput == false
""" % (TICK, TICK, TICK, TICK, TICK))

SHORT = 'SCRIPT_CFG = { rollingStart = 1, formationSpeed = 100, greenMeters = 100, startMeters = 500, twoWide = 0 }'
SHORT2 = 'SCRIPT_CFG = { rollingStart = 1, formationSpeed = 100, greenMeters = 100, startMeters = 500 }'

scenario('salida corta: despues de la bandera verde nadie vuelve a ser llevado a la fila, aunque el contador de vueltas siga en 0', """
  T.sim.carsCount = 1; T.cars[0].racePosition = 14
  T.sim.isSessionStarted = false; run(0.2); T.sim.isSessionStarted = true
  run(2)
  local first = #T.teleports == 1 and math.abs(T.teleports[1].z - 3000) < 1     -- puesto 14 de grilla, pero corre solo
  place(0, 3200, 70); run(2); place(0, 3420, 70); run(0.2)
  local green = lastMsg():find('BANDERA VERDE') ~= nil
  local c = T.cars[0]
  c.splinePosition = 0.02; c.speedKmh = 150; run(1)       -- cruza la meta
  c.splinePosition = 0.30; c.speedKmh = 220; run(3)       -- sigue la vuelta: el contador del juego no ha subido
  c.splinePosition = 0.70; run(3); c.splinePosition = 0.92; run(3)
  return first and green and c.lapCount == 0 and #T.teleports == 1 and msgCount('SALIDA LANZADA') == 1 and #T.forcedCuts == 0
""", pre=SHORT)

scenario('quien entra con la carrera ya en marcha no es llevado a la fila ni limitado', """
  T.sim.timeToSessionStart = -90000; T.sim.carsCount = 1
  place(0, 1000, 180); run(3)
  return #T.teleports == 0 and #T.messages == 0 and #T.forcedCuts == 0
""", pre=SHORT)

scenario('salida corta: en la cuenta regresiva el auto va de inmediato a la fila y espera las luces sin controles; al largar no se le mueve otra vez', """
  T.sim.carsCount = 1
  T.sim.isSessionStarted = false
  place(0, 3450, 0)                                 -- la grilla, junto a la meta
  run(1)
  local waits = #T.teleports == 0                   -- primero se deja que el juego termine de poner los autos
  run(1.5)
  local moved = #T.teleports == 1 and math.abs(T.teleports[1].z - 3000) < 1 and T.noInput == true
    and lastMsg():find('SALIDA LANZADA | Espera las luces') ~= nil
  run(12)                                           -- el resto de la cuenta regresiva
  local still = #T.teleports == 1
  T.sim.isSessionStarted = true; run(1)
  local started = #T.teleports == 1 and T.noInput == false and lastMsg():find('Maximo 100 km/h') ~= nil
  place(0, 3200, 130); run(1)
  local capped = #T.forcedCuts > 30
  place(0, 3420, 70); run(0.3)
  return waits and moved and still and started and capped and lastMsg():find('BANDERA VERDE') ~= nil
""", pre=SHORT)

scenario('cuenta regresiva: si el juego devuelve el auto a la grilla se insiste pocas veces, y al largar se le lleva igual a la fila', """
  T.sim.carsCount = 1
  T.sim.isSessionStarted = false
  place(0, 3450, 0); run(3)
  local first = #T.teleports == 1
  for k = 1, 12 do place(0, 3450, 0); run(2.5) end   -- el juego lo devuelve una y otra vez
  local limited = #T.teleports == 6
  place(0, 3450, 0)
  T.sim.isSessionStarted = true; run(1)
  return first and limited and #T.teleports == 7 and math.abs(T.cars[0].position.z - 3000) < 1 and T.noInput == false
""", pre=SHORT)

scenario('cuenta regresiva: si el juego no deja mover el auto, no se bloquean los controles y se intenta al largar como antes', """
  T.sim.carsCount = 1
  T.sim.isSessionStarted = false; T.teleportFail = true
  place(0, 3450, 0); run(6)
  local nothing = #T.teleports == 0 and T.noInput ~= true and #T.messages == 0
  T.teleportFail = false
  T.sim.isSessionStarted = true; run(1)
  return nothing and #T.teleports == 1
""", pre=SHORT)

scenario('cuenta regresiva: si se cambia a salida parada, el auto vuelve a su lugar de la grilla con los controles libres', """
  T.sim.carsCount = 1
  T.sim.isSessionStarted = false
  LINK.appMode = 2; LINK.appStart = 500; LINK.appOn = 1
  place(0, 3450, 0); run(3, %s)
  local moved = #T.teleports == 1 and T.noInput == true
  LINK.appMode = 1; run(1, %s)
  local back = #T.teleports == 2 and math.abs(T.cars[0].position.z - 3450) < 1 and T.cars[0].look.z > 0.9 and T.noInput == false
  T.sim.isSessionStarted = true; run(2, %s)
  return moved and back and #T.teleports == 2 and #T.forcedCuts == 0
""" % (TICK, TICK, TICK), pre=SHORT)

scenario('cuenta regresiva con vuelta de formacion completa o salida parada: nadie es movido', """
  T.sim.isSessionStarted = false
  place(0, 3450, 0); run(8)
  return #T.teleports == 0 and T.noInput ~= true and #T.messages == 0
""")

scenario('cuenta regresiva: el segundo de la grilla queda 10 m detras del primero', """
  T.sim.carsCount = 2; T.cars[0].racePosition = 2; T.cars[1].racePosition = 1
  T.sim.isSessionStarted = false
  place(0, 3440, 0); run(3)
  return #T.teleports == 1 and math.abs(T.teleports[1].z - 2990) < 1
""", pre=SHORT)

scenario('carrera reiniciada: en la nueva cuenta regresiva el auto vuelve a ir a la fila', """
  T.sim.carsCount = 1
  T.sim.isSessionStarted = false; place(0, 3450, 0); run(3)
  T.sim.isSessionStarted = true; run(2); place(0, 3420, 70); run(0.3)
  local green = lastMsg():find('BANDERA VERDE') ~= nil
  place(0, 500, 200); run(5)
  T.sim.isSessionStarted = false; place(0, 3450, 0); run(3)
  return green and #T.teleports == 2 and T.noInput == true
""", pre=SHORT)

scenario('al cargar, el script avisa una sola vez que version es', """
  T.sim.raceSessionType = ac.SessionType.Practice
  place(0, 0, 50); run(8)
  local shown = #T.versionMsgs == 1 and T.versionMsgs[1]:find('COMISARIO SERVIDOR 1.11', 1, true) ~= nil
  T.sim.raceSessionType = ac.SessionType.Race; run(8)
  return shown and #T.versionMsgs == 1
""")

scenario('si el script se carga en plena carrera, el aviso de version no tapa los mensajes de la largada', """
  place(0, 0, 50); run(8)
  return #T.versionMsgs == 0 and lastMsg():find('VUELTA DE FORMACION') ~= nil
""")

scenario("language = 'en': los mensajes del script salen en ingles", """
  T.sim.carsCount = 1
  T.sim.isSessionStarted = false; place(0, 3450, 0); run(3)
  local wait = lastMsg() == 'ROLLING START | Wait for the lights. Then, maximum 100 km/h until the green flag'
  T.sim.isSessionStarted = true; run(1)
  local form = lastMsg() == 'ROLLING START | Maximum 100 km/h. Hold your position until the green flag'
  place(0, 3200, 70); run(2); place(0, 3420, 70); run(0.3)
  return wait and form and lastMsg() == 'GREEN FLAG | Race is on'
""", pre="SCRIPT_CFG = { rollingStart = 1, formationSpeed = 100, greenMeters = 100, startMeters = 500, language = 'en' }")

scenario("language = 'en': el aviso de version tambien", """
  T.sim.raceSessionType = ac.SessionType.Practice
  place(0, 0, 50); run(8)
  return #T.versionMsgs == 1 and T.versionMsgs[1] == 'COMISARIO SERVER 1.11 | Server script loaded'
""", pre="SCRIPT_CFG = { language = 'EN' }")

scenario('fila doble (por defecto): el 1 y el 2 lado a lado, el 3 en la fila siguiente', """
  T.sim.carsCount = 3; T.cars[0].racePosition = 2; T.cars[1].racePosition = 1; T.cars[2].racePosition = 3
  T.sim.isSessionStarted = false; place(0, 3440, 0); run(3)
  local second = #T.teleports == 1 and math.abs(T.teleports[1].z - 3000) < 0.5 and math.abs(T.cars[0].position.x - 2.6) < 0.01
  T.cars[0].racePosition = 3; T.cars[2].racePosition = 2
  T.sim.isSessionStarted = true; run(0.5); T.sim.isSessionStarted = false; place(0, 3440, 0); run(3)
  local third = math.abs(last(T.teleports).z - 2988) < 0.5 and math.abs(T.cars[0].position.x + 2.6) < 0.01
  return second and third
""", pre=SHORT2)

scenario('fila doble sin el ancho de la pista: el segundo de la fila va 6 m detras, en la linea', """
  T.noSides = true
  T.sim.carsCount = 2; T.cars[0].racePosition = 2; T.cars[1].racePosition = 1
  T.sim.isSessionStarted = false; place(0, 3440, 0); run(8)
  return #T.teleports == 1 and math.abs(T.teleports[1].z - 2994) < 0.5 and T.cars[0].position.x == 0
""", pre=SHORT2)

fails = 0
for name, ok, err in results:
    print(('OK    ' if ok else 'FALLA ') + name + (('\n        -> ' + err) if err else ''))
    fails += 0 if ok else 1
print('\n%d de %d pruebas del script del servidor correctas' % (len(results) - fails, len(results)))
sys.exit(1 if fails else 0)
