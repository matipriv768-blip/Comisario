import sys
from lupa import luajit21 as lj

APP = sys.argv[1]
HARNESS = 'test/harness.lua'
results = []


def scenario(name, body, pre=''):
    lua = lj.LuaRuntime(unpack_returned_tuples=True)
    if pre:
        lua.execute(pre)
    lua.execute("local f = assert(loadfile('%s')); f('%s')" % (HARNESS, APP))
    try:
        ok = lua.execute(body)
        err = ''
        if not ok:
            err = 'mensajes: ' + ' // '.join(list(lua.eval('T.messages').values())[-4:])
            log = lua.eval('logText()')
            if 'ERROR' in log:
                err += ' LOG: ' + log[log.find('ERROR'):][:300]
        results.append((name, bool(ok), err))
    except Exception as e:  # noqa
        results.append((name, False, str(e)[:300]))


# ---------------------------------------------------------------- basicos
scenario('carga y dibuja las tres ventanas sin errores', '''
  draw(); run(1); draw(); run(6)
  return T.uiCalls > 40 and not logText():find('ERROR')
''')

scenario('el mensaje grande del juego nunca lleva tildes (su fuente puede no tenerlas)', '''
  local c = place(0, 0, 150); c.gas = 1
  for n = 1, 4 do c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(4) end
  T.sim.raceSessionType = 2; c.wheelsOutside = 4; run(1)
  return #T.messages >= 5 and not T.messageNotAscii and lastMsg():find('VUELTA INVALIDADA') ~= nil
''')

scenario('limites: 3 avisos y a la cuarta salida, levantar; cada salida suma 1x', '''
  local c = place(0, 0, 150); c.gas = 1
  for n = 1, 4 do c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(4) end
  return lastMsg():find('LEVANTA EL PIE') ~= nil and msgCount('AVISO %d/3 LIMITES') == 3 and screen():find('4x') ~= nil
''')

scenario('limites: una salida larga cuenta una sola vez', '''
  local c = place(0, 0, 150)
  c.wheelsOutside = 4; run(6)
  return #T.messages == 1 and T.messages[1]:find('AVISO 1/3') ~= nil
''')

scenario('limites: 2 ruedas fuera o salida lenta no cuentan', '''
  local c = place(0, 0, 150)
  c.wheelsOutside = 2; run(2)
  place(0, 0, 20); c.wheelsOutside = 4; run(2)
  place(0, 0, 150); c.wheelsOutside = 4; run(0.2); c.wheelsOutside = 0; run(1)
  return #T.messages == 0
''')

scenario('limites con sancion "Ninguna": avisa la salida y suma puntos, sin escalera', '''
  preset('iRacing')
  local c = place(0, 0, 150)
  for n = 1, 6 do c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(4) end
  return msgCount('SALIDA DE PISTA') == 6 and msgCount('LEVANTA') == 0 and screen():find('6x') ~= nil
''')

scenario('practica: solo avisa, sin sancion', '''
  T.sim.raceSessionType = 1
  local c = place(0, 0, 150)
  for n = 1, 6 do c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(4) end
  return msgCount('SANCION') == 0 and msgCount('LEVANTA') == 0 and msgCount('DRIVE') == 0 and #T.messages == 6
''')

scenario('levantar: cumplida al soltar el acelerador 3 s', '''
  local c = place(0, 0, 150); c.gas = 1
  press('Levantar'); run(1); c.gas = 0; run(3.2)
  return lastMsg():find('SANCION CUMPLIDA') ~= nil
''')

scenario('levantar: no cumplida en plazo suma 10 s', '''
  local c = place(0, 0, 150); c.gas = 1
  press('Levantar'); run(27)
  return lastMsg():find('SANCION %+10 s') ~= nil and screen():find('%+10 s') ~= nil
''')

scenario('pits: exceso da drive-through, y pasar sin parar lo cumple', '''
  local c = place(0, 0, 120); c.gas = 1
  c.isInPitlane = true; run(1)
  local got = lastMsg():find('DRIVE%-THROUGH') ~= nil and lastMsg():find('120 km/h') ~= nil
  place(0, 0, 78); run(5)
  c.isInPitlane = false; place(0, 0, 200); run(20)
  local pending = not lastMsg():find('CUMPLIDA')
  c.lapCount = 1
  c.isInPitlane = true; place(0, 0, 78); run(15)
  c.isInPitlane = false; place(0, 0, 200); run(1)
  return got and pending and lastMsg():find('SANCION CUMPLIDA') ~= nil
''')

scenario('pits: a 82 km/h con limite 80 y margen 3 no sanciona', '''
  local c = place(0, 0, 82)
  c.isInPitlane = true; run(10)
  return #T.messages == 0
''')

scenario('drive-through: detenerse en boxes no vale', '''
  local c = place(0, 0, 150); c.gas = 1
  press('Drive-through'); run(2)
  c.isInPitlane = true; place(0, 0, 60); run(2); place(0, 0, 0); run(3); place(0, 0, 60); run(2)
  c.isInPitlane = false; place(0, 0, 150); run(1)
  return lastMsg():find('NO VALIDO') ~= nil
''')

scenario('drive-through: sin cumplir en 3 vueltas suma 30 s', '''
  local c = place(0, 0, 150); c.gas = 1; c.lapCount = 1
  run(1); press('Drive-through')
  c.lapCount = 2; run(1); c.lapCount = 3; run(1); c.lapCount = 4; run(1)
  local stillPending = not lastMsg():find('SANCION %+30')
  c.lapCount = 5; run(0.1)
  return stillPending and msgCount('SANCION %+30 s') == 1
''')

scenario('salida en falso: moverse antes de la largada da drive-through', '''
  newSession()
  T.sim.isSessionStarted = false; T.sim.timeToSessionStart = 4000
  run(1); place(0, 3, 15); run(0.5)
  return lastMsg():find('Salida en falso') ~= nil
''')

scenario('salida limpia: quieto hasta la largada no sanciona', '''
  newSession()
  T.sim.isSessionStarted = false; T.sim.timeToSessionStart = 4000
  run(2)
  T.sim.isSessionStarted = true; T.sim.timeToSessionStart = -10
  place(0, 30, 80); run(2)
  return #T.messages == 0
''')

scenario('pausa y repeticion: no cuenta nada', '''
  local c = place(0, 0, 150)
  T.sim.isPaused = true; c.wheelsOutside = 4; run(3)
  T.sim.isPaused = false; T.sim.isReplayActive = true; run(3)
  draw()
  return #T.messages == 0
''')

scenario('offline no se envia ningun mensaje de red', '''
  local c = place(0, 0, 150); c.gas = 1
  for n = 1, 4 do c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(4) end
  run(20)
  return #T.sent == 0
''')

scenario('reinicio de sesion borra contadores', '''
  local c = place(0, 0, 150)
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(1)
  newSession()
  local c2 = place(0, 0, 150)
  c2.wheelsOutside = 4; run(1)
  return lastMsg():find('AVISO 1/3') ~= nil
''')

# ---------------------------------------------------------------- contactos
scenario('roce (chapa chapa): 5 km/h de diferencia no sanciona ni suma puntos', '''
  place(0, 0, 150); place(1, 4.5, 145); run(0.5)
  hit(0); run(5)
  local s = screen()
  return #T.messages == 0 and s:find('Roce con Piloto1') ~= nil and s:find('Incidentes: | 0x') ~= nil
''')

scenario('contacto evitable: investigacion, aviso y 2x; el segundo ya es +5 s', '''
  place(0, 0, 170); place(1, 4.5, 150); run(0.5)
  hit(0); run(1)
  local investigating = lastMsg():find('BAJO INVESTIGACION') ~= nil
  run(3)
  local warned = lastMsg():find('AVISO POR CONTACTO') ~= nil and lastMsg():find('2x') ~= nil
  run(5); hit(0); run(4)
  return investigating and warned and lastMsg():find('SANCION %+5 s') ~= nil and screen():find('4x') ~= nil
''')

scenario('choque fuerte por alcance: drive-through directo y 4x', '''
  place(0, 0, 200); place(1, 4.5, 150); run(0.5)
  hit(0); run(1)
  return msgCount('DRIVE%-THROUGH') == 1 and lastMsg():find('Causar un choque con Piloto1') ~= nil and screen():find('4x') ~= nil
''')

scenario('la IA te choca por detras: sancion para ella, nada para ti', '''
  place(0, 4.5, 150); place(1, 0, 200); run(0.5)
  hit(0); run(1)
  local c = T.cars[0]
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0   -- te sacaron de pista: no cuenta
  local s = screen()
  return lastMsg():find('SANCION A PILOTO1') ~= nil and msgCount('AVISO') == 0 and s:find('Incidentes: | 0x') ~= nil
''')

scenario('lado a lado: incidente de carrera sin sancion', '''
  place(0, 0, 200, 0); place(1, 0.5, 150, 2); run(0.5)
  hit(0); run(4)
  return #T.messages == 1 and lastMsg():find('INCIDENTE DE CARRERA') ~= nil and msgCount('DRIVE') == 0
''')

scenario('investigacion: si el golpeado se sale de pista, pasa a choque fuerte', '''
  place(0, 0, 170); place(1, 4.5, 150); run(0.5)
  hit(0); run(0.5)
  T.cars[1].wheelsOutside = 4; run(0.5)
  return msgCount('DRIVE%-THROUGH') == 1 and lastMsg():find('perdio el control') ~= nil
''')

scenario('reglamento iRacing: contacto suma 4x a los dos, sin sancion directa', '''
  preset('iRacing')
  place(0, 0, 170); place(1, 4.5, 150); run(0.5)
  hit(0); run(4)
  local s = screen()
  local _, both = s:gsub('4x', '')
  return msgCount('CONTACTO') == 1 and msgCount('SANCION') == 0 and msgCount('DRIVE') == 0 and both >= 2
''')

scenario('muro: golpe sin autos cerca suma 2x', '''
  local c = place(0, 0, 150); run(0.5)
  wallHit(0, 150, 110); run(4)
  return lastMsg():find('GOLPE CONTRA EL MURO') ~= nil and screen():find('Incidentes: | 2x') ~= nil
''')

scenario('salir al pasto con "colision" pero sin perder velocidad de golpe: es salida de pista, no muro', '''
  local c = place(0, 0, 150); run(0.5)
  c.wheelsOutside = 4; c.collisionDepth = 0.05
  for n = 1, 30 do place(0, 0, 150 - n); run(0.1) end      -- frena en el pasto: 10 km/h por segundo
  c.collisionDepth = 0; c.wheelsOutside = 0; run(4)
  return msgCount('MURO') == 0 and msgCount('LIMITES DE PISTA') == 1 and screen():find('Incidentes: | 1x') ~= nil
''')

scenario('frenada fuerte sobre un piano con "colision": no es muro', '''
  local c = place(0, 0, 200); run(0.5)
  c.collisionDepth = 0.05
  for n = 1, 20 do place(0, 0, 200 - n * 2.6); run(0.05) end   -- 1,5 g de frenada
  c.collisionDepth = 0; run(2)
  return #T.messages == 0
''')

scenario('auto cerca pero no pegado (3 m al lado): no cuenta como contacto entre autos', '''
  place(0, 0, 200, 0); place(1, 0.5, 150, 3); run(0.5)
  hit(0); run(4)
  return #T.messages == 0 and screen():find('Roce') == nil
''')

scenario('trompo: perdida de control suma 2x', '''
  local c = place(0, 0, 100); run(0.5)
  c.look = vec3(1, 0, 0); run(1); c.look = vec3(0, 0, 1); run(4)
  return msgCount('PERDIDA DE CONTROL') == 1 and screen():find('Incidentes: | 2x') ~= nil
''')

scenario('incidentes seguidos: muro y salida en 3 s cuentan solo el mayor (2x)', '''
  T.cfg.incSum = false
  local c = place(0, 0, 150); run(0.5)
  wallHit(0, 150, 110); c.wheelsOutside = 4; run(1.5); c.wheelsOutside = 0; run(4)
  return screen():find('Incidentes: | 2x') ~= nil
''')

scenario('limite de incidentes: a los 12x, drive-through', '''
  local c = place(0, 0, 150); run(0.5)
  for n = 1, 6 do wallHit(0, 150, 110); run(5) end
  return msgCount('GOLPE CONTRA EL MURO') == 6 and msgCount('DRIVE%-THROUGH') == 1 and lastMsg():find('DRIVE%-THROUGH | Limite de incidentes %(12x%)') ~= nil
''')

scenario('la IA tambien es vigilada: sus salidas suman puntos y sancion', '''
  local a = place(1, 300, 150)
  place(0, 0, 150)
  for n = 1, 4 do a.wheelsOutside = 4; run(1); a.wheelsOutside = 0; run(4) end
  local s = screen()
  return s:find('Sancion a Piloto1') ~= nil and s:find('4x') ~= nil and #T.messages == 0
''')

scenario('IA sin vigilar: sus salidas y choques entre ellas no cuentan', '''
  T.clickRadio = 'No vigilarla'; script.windowSettings(0.016); T.clickRadio = nil
  local a = place(1, 300, 200); place(2, 304.5, 150); place(0, 0, 150); run(0.5)
  hit(1)
  for n = 1, 4 do a.wheelsOutside = 4; run(1); a.wheelsOutside = 0; run(4) end
  local s = screen()
  return s:find('Piloto1:') == nil and s:find('Sancion a') == nil and s:find('sin vigilar') ~= nil
''')

scenario('choque entre dos autos de la IA: sancion al que alcanza', '''
  place(0, 0, 150); place(1, 300, 200); place(2, 304.5, 150); run(0.5)
  hit(1); run(1)
  return screen():find('Sancion a Piloto1') ~= nil and #T.messages == 0
''')

# ---------------------------------------------------------------- final de carrera
scenario('fin de carrera: drive-through pendiente se convierte en tiempo', '''
  local c = place(0, 0, 150); c.gas = 1
  press('Drive-through'); run(1)
  c.isRaceFinished = true; run(6)
  return lastMsg():find('CARRERA TERMINADA') ~= nil and lastMsg():find('%+30 s') ~= nil and logText():find('RESUMEN') ~= nil
''')

scenario('clasificacion corregida: la IA que gano en pista pierde el puesto por su sancion', '''
  place(0, 4.5, 150); place(1, 0, 200); place(2, 600, 150); run(0.5)
  hit(0); run(1)                                  -- Piloto1 te choca: 20 s
  T.cars[1].racePosition = 1; T.cars[0].racePosition = 2; T.cars[2].racePosition = 3
  T.cars[1].lapCount = 5; T.cars[1].isRaceFinished = true; run(3)      -- gana en pista
  T.cars[0].lapCount = 5; T.cars[0].isRaceFinished = true; run(1)      -- llegas 3 s despues
  local s = screen()
  local you, rival = s:find('TU'), s:find('Piloto1 |', 1, true)
  return s:find('corregida') ~= nil and you ~= nil and rival ~= nil and you < rival and s:find('ganador') ~= nil
''')

scenario('corte forzado: usa la fisica solo si el juego lo permite', '''
  T.physicsAllowed = true
  T.cfg.forceCut = true
  place(0, 0, 150)
  press('Levantar')
  return #T.forcedCuts == 1 and T.forcedCuts[1] == 3
''')

scenario('todos los botones de ajustes funcionan sin error', '''
  place(0, 0, 100)
  for _, b in ipairs({'Aviso', 'Tiempo', 'Levantar', 'Drive-through', 'Rival 1: levantar', 'Rival 1: drive-through',
      'iRacing', 'Sanciones reales (FIA)', 'Mixto', 'Abrir todos los indicadores', 'Cerrar todos', 'Permitir en esta pista',
      'Borrar sanciones y contadores'}) do
    press(b); run(0.5); draw()
  end
  T.clickAll = true; script.windowSettings(0.016); T.clickAll = false; draw()
  run(6)
  return not logText():find('ERROR')
''')

# ---------------------------------------------------------------- la IA cumple en pista
scenario('sin permiso de la pista: la sancion de la IA va a la clasificacion y el panel lo explica', '''
  place(0, 4.5, 150); place(1, 0, 200); run(0.5)
  hit(0); run(3)
  local s = screen()
  return T.throttle[1] == nil and T.pitReq[1] == nil and s:find('%+20 s') ~= nil and s:find('no permite controlarla') ~= nil
''')

scenario('IA levanta el pie: acelerador a cero 3 s y despues queda libre, sin limite de velocidad', '''
  T.physicsAllowed = true
  place(0, 0, 150); place(1, 300, 180); run(0.5)
  press('Rival 1: levantar'); run(1)
  local lifting = last(T.throttle[1]) == 0
  place(1, 300, 170); run(1); place(1, 300, 162); run(1.5)
  local s = screen()
  return lifting and last(T.throttle[1]) == 1 and s:find('cumplio: levanto el pie 3 s') ~= nil and s:find('cumple en pista') ~= nil
''')

scenario('IA no levanta con un auto pegado detras: espera a que haya espacio', '''
  T.physicsAllowed = true
  place(0, 0, 150); place(1, 300, 180); place(2, 288, 180); run(0.5)
  press('Rival 1: levantar'); run(5)
  local waited = T.throttle[1] == nil and screen():find('debe levantar') ~= nil
  place(2, 200, 180); run(1)
  return waited and last(T.throttle[1]) == 0
''')

scenario('IA que levanta justo delante tuyo: aviso de precaucion y bandera amarilla', '''
  T.physicsAllowed = true
  place(0, 0, 150); place(1, 80, 180); run(0.5)
  press('Rival 1: levantar'); run(0.5)
  return lastMsg():find('ATENCION | Piloto1 levanta el pie delante tuyo') ~= nil and hudScreen():find('ATENCION') ~= nil
''')

scenario('si la IA sigue acelerando pese a la orden, la sancion pasa a la clasificacion', '''
  T.physicsAllowed = true
  place(0, 0, 150); place(1, 300, 180); run(0.5)
  press('Rival 1: levantar'); run(1)
  place(1, 300, 200); run(1.5)
  local s = screen()
  return last(T.throttle[1]) == 1 and s:find('%+3 s') ~= nil and s:find('ignora las ordenes') ~= nil
''')

scenario('IA drive-through real: se le pide entrar a pits, entra, sale y queda cumplido', '''
  T.physicsAllowed = true
  place(0, 0, 150); place(1, 300, 180); run(0.5)
  press('Rival 1: drive-through'); run(1)
  local asked = last(T.pitReq[1]) == true and screen():find('debe pits') ~= nil
  T.cars[1].isInPitlane = true; place(1, 300, 80); run(2)
  local cancelled = last(T.pitReq[1]) == false
  T.cars[1].isInPitlane = false; place(1, 300, 150); run(1)
  local s = screen()
  return asked and cancelled and s:find('cumplio: paso por pits') ~= nil and s:find('debe pits') == nil
''')

scenario('IA que no entra a pits en 3 vueltas: +20 s en la clasificacion', '''
  T.physicsAllowed = true
  place(0, 0, 150); place(1, 300, 180); run(0.5)
  press('Rival 1: drive-through'); run(1)
  T.cars[1].lapCount = 4; run(1)
  local s = screen()
  return last(T.pitReq[1]) == false and s:find('no entro a pits') ~= nil and s:find('%+20 s') ~= nil
''')

scenario('choque fuerte de la IA contigo con permiso: la mandan a pits', '''
  T.physicsAllowed = true
  place(0, 4.5, 150); place(1, 0, 200); run(0.5)
  hit(0); run(1)
  return lastMsg():find('SANCION A PILOTO1 | pasar por pits') ~= nil and last(T.pitReq[1]) == true
''')

scenario('al cerrar la app o reiniciar, la IA recupera el acelerador y se cancela el pedido de pits', '''
  T.physicsAllowed = true
  place(0, 0, 150); place(1, 300, 180); place(2, 600, 180); run(0.5)
  press('Rival 1: levantar'); run(1)
  for _, fn in ipairs(T.released) do fn() end
  return last(T.throttle[1]) == 1 and last(T.pitReq[1]) == false
''')

# ---------------------------------------------------------------- autorizacion de la pista
scenario('autorizar la pista: agrega el permiso a surfaces.ini, respalda el original y se puede deshacer', '''
  local original = '[SURFACE_0]\\r\\nKEY=ROAD\\r\\nFRICTION=0.98\\r\\nWAV_PITCH=0\\r\\n\\r\\n[SURFACE_1]\\r\\nKEY=GRASS\\r\\nWAV_PITCH=1.2\\r\\n'
  T.files[SURFACES] = original
  press('Permitir en esta pista')
  local new = T.files[SURFACES]
  local okNew = new:find('%[SURFACE_0%]\\r\\nKEY=ROAD\\r\\nFRICTION=0.98\\r\\nWAV_PITCH=extended%-0\\r\\n') ~= nil
    and new:find('%[SURFACE_1%]\\r\\nKEY=GRASS\\r\\nWAV_PITCH=1.2\\r\\n') ~= nil
    and new:find('%[_SCRIPTING_PHYSICS%]\\r\\nALLOW_APPS=1\\r\\n') ~= nil
  local backup = T.files[SURFACES .. '.comisario_respaldo'] == original
  press('Permitir en esta pista')                      -- pulsarlo dos veces no duplica nada
  local _, count = T.files[SURFACES]:gsub('ALLOW_APPS', '')
  press('Deshacer el cambio en esta pista')
  return okNew and backup and count == 1 and T.files[SURFACES] == original and T.files[SURFACES .. '.comisario_respaldo'] == nil
''')

scenario('autorizar la pista: archivo raro o carpeta sin permiso de escritura no rompe nada', '''
  T.files[SURFACES] = 'esto no es un surfaces.ini'
  press('Permitir en esta pista')
  local untouched = T.files[SURFACES] == 'esto no es un surfaces.ini' and T.files[SURFACES .. '.comisario_respaldo'] == nil
  T.files[SURFACES] = '[SURFACE_0]\\nKEY=ROAD\\n'
  T.readOnly = true
  press('Permitir en esta pista')
  T.readOnly = false
  T.texts = {}; script.windowSettings(0.016)
  return untouched and T.files[SURFACES] == '[SURFACE_0]\\nKEY=ROAD\\n' and table.concat(T.texts, ' '):find('No pude guardar') ~= nil
''')

scenario('autorizar la pista con trazado (layout): usa la carpeta del trazado', '''
  T.layout = 'gp'
  local path = 'C:/logs\\\\pista_test\\\\gp\\\\data\\\\surfaces.ini'
  T.files[path] = '[SURFACE_0]\\nKEY=ROAD\\n\\n[_SCRIPTING_PHYSICS]\\nALLOW_TOOLS=1\\n'
  press('Permitir en esta pista')
  local new = T.files[path]
  return new:find('%[SURFACE_0%]\\nKEY=ROAD\\n\\nWAV_PITCH=extended%-0') ~= nil and new:find('ALLOW_TOOLS=1\\nALLOW_APPS=1\\n') ~= nil
''')

# ---------------------------------------------------------------- indicadores
# ---------------------------------------------------------------- perdida de control seguida de golpe
scenario('trompo y despues muro: se cuentan los dos (2x + 2x)', '''
  local c = place(0, 0, 120); run(0.5)
  c.look = vec3(1, 0, 0); run(1)
  wallHit(0, 90, 40); c.look = vec3(0, 0, 1); run(3)
  return msgCount('PERDIDA DE CONTROL') == 1 and msgCount('GOLPE CONTRA EL MURO | %+2x de incidente %(llevas 4x%)') == 1
''')

scenario('trompo y despues muro con la regla de iRacing: 2x y el aviso explica por que no suma', '''
  T.cfg.incSum = false
  local c = place(0, 0, 120); run(0.5)
  c.look = vec3(1, 0, 0); run(1)
  wallHit(0, 90, 40); c.look = vec3(0, 0, 1); run(3)
  return lastMsg():find('GOLPE CONTRA EL MURO | Sin puntos extra') ~= nil and screen():find('Incidentes: | 2x') ~= nil
''')

scenario('pierdes el control y chocas a un auto que iba a tu lado: la culpa es tuya', '''
  local c = place(0, 0, 150, 0); place(1, 1, 100, 2); run(0.5)
  c.look = vec3(1, 0, 0); run(0.6)                   -- trompo
  hit(0); run(1)
  return msgCount('PERDIDA DE CONTROL') == 1 and msgCount('INCIDENTE DE CARRERA') == 0
    and msgCount('DRIVE%-THROUGH | Causar un choque con Piloto1') == 1 and screen():find('6x') ~= nil
''')

scenario('pierdes el control y el golpe llega antes de que se marque el trompo: igual es culpa tuya', '''
  local c = place(0, 0, 150, 0); place(1, 1, 100, 2); run(0.5)
  c.look = vec3(1, 0, 0); run(0.2)                   -- recien empezando a deslizar
  hit(0); run(1)
  return msgCount('INCIDENTE DE CARRERA') == 0 and msgCount('DRIVE%-THROUGH | Causar un choque con Piloto1') == 1
''')

scenario('un bot pierde el control y te choca: la culpa es del bot', '''
  place(0, 0, 100, 0); local a = place(1, 1, 150, 2); run(0.5)
  a.look = vec3(1, 0, 0); run(0.6)
  hit(0); run(1)
  return lastMsg():find('SANCION A PILOTO1') ~= nil and msgCount('DRIVE%-THROUGH') == 0 and screen():find('Incidentes: | 0x') ~= nil
''')

scenario('te chocan, pierdes el control y tocas a un tercero: no cargas con la culpa', '''
  place(0, 4.5, 150); place(1, 0, 200); place(2, 4.5, 150, 30); run(0.5)
  hit(0); run(0.5)                                   -- Piloto1 te choca por detras
  local c = T.cars[0]; c.look = vec3(1, 0, 0)
  place(1, -200, 150); place(2, 5, 100, 2); run(0.6)  -- sales trompeado hacia Piloto2
  hit(0); run(1)
  return msgCount('DRIVE%-THROUGH') == 0 and msgCount('LEVANTA') == 0 and screen():find('Incidentes: | 0x') ~= nil
''')

# ---------------------------------------------------------------- indicadores
scenario('indicadores en carrera sin incidentes: solo la barra de estado', '''
  place(0, 0, 150); run(0.5)
  local idle = hudScreen()
  T.cfg.hudPlace = true
  local sample = hudScreen()
  return idle:find('AVISO') == nil and idle:find('SANCION PENDIENTE') == nil and idle:find('CARRERA | LIMITES | INC 0x / 12') ~= nil
    and sample:find('AVISO DEL COMISARIO') ~= nil and sample:find('SANCION PENDIENTE') ~= nil
''')

scenario('indicadores: una salida muestra el aviso explicado y actualiza la barra', '''
  local c = place(0, 0, 150)
  c.wheelsOutside = 4; run(1)
  local s = hudScreen()
  return s:find('AVISO 1/3 LIMITES DE PISTA | Saliste de la pista. Te quedan 2 avisos') ~= nil and s:find('INC 1x / 12') ~= nil
''')

scenario('indicadores: drive-through dice que hacer y cuantas vueltas quedan; al entrar a pits cambia la instruccion', '''
  local c = place(0, 0, 150); c.gas = 1
  press('Drive-through'); run(9)
  local s = hudScreen()
  local pending = s:find('SANCION PENDIENTE | DRIVE%-THROUGH | Pasa por pits sin parar | VUELTAS PARA CUMPLIR: 3') ~= nil
  c.lapCount = 3; run(0.1)
  local lastChance = hudScreen():find('ULTIMA OPORTUNIDAD') ~= nil
  c.isInPitlane = true; place(0, 0, 70); run(1)
  local inPits = hudScreen():find('Sigue sin parar hasta salir de pits') ~= nil
  c.isInPitlane = false; place(0, 0, 150); run(0.5)
  local done = hudScreen()
  return pending and lastChance and inPits and done:find('SANCION CUMPLIDA') ~= nil and done:find('SANCION PENDIENTE') == nil
''')

scenario('indicadores: levantar el pie muestra el avance y el plazo', '''
  local c = place(0, 0, 150); c.gas = 1
  press('Levantar'); run(0.5); c.gas = 0; run(1.5)
  local s = hudScreen()
  return s:find('LEVANTA EL PIE | Suelta el acelerador 3 segundos. Plazo: 23 s | 1.5 / 3 s') ~= nil
''')

scenario('indicadores: dos sanciones pendientes se numeran, y el tiempo de sancion aparece en la barra', '''
  place(0, 0, 150).gas = 1
  press('Drive-through'); press('Levantar'); press('Tiempo'); run(0.5)
  local s = hudScreen()
  return s:find('1 de 2') ~= nil and s:find('%+5 s') ~= nil
''')

scenario('abrir y cerrar todos los indicadores desde los ajustes (con todas las opciones a la vista)', '''
  press('Abrir todos los indicadores')
  local hidden = T.windows.hud_msg ~= true       -- en la vista simple esos botones no estan
  T.cfg.setAll = true
  press('Abrir todos los indicadores')
  local opened = T.windows.hud_msg == true and T.windows.hud_pen == true and T.windows.hud_status == true
  press('Cerrar todos')
  return hidden and opened and T.windows.hud_status == false
''')

# ---------------------------------------------------------------- practica y clasificacion
scenario('practica: se ve, cuenta salidas e incidentes, y no sanciona nada', '''
  T.sim.raceSessionType = 1
  local c = place(0, 0, 150); place(1, 4.5, 100); run(0.5)
  for n = 1, 5 do c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(4) end
  hit(0); run(4)                                    -- choque fuerte por alcance
  c.isInPitlane = true; place(0, 0, 120); run(1); c.isInPitlane = false
  local s = hudScreen()
  return s:find('PRACTICA | SOLO CUENTA | SALIDAS 5 | INC 9x') ~= nil and screen():find('solo se cuenta, sin sanciones') ~= nil
    and msgCount('SANCION') == 0 and msgCount('DRIVE') == 0 and msgCount('LEVANTA') == 0 and msgCount('INVALIDADA') == 0
''')

scenario('clasificacion: salirse invalida la vuelta, sin otra sancion', '''
  T.sim.raceSessionType = 2
  local c = place(0, 0, 150); run(0.5)
  local before = hudScreen():find('CLASIFICACION | VUELTA VALIDA') ~= nil
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(2)
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(2)     -- segunda salida en la misma vuelta
  local s = hudScreen()
  return before and msgCount('VUELTA INVALIDADA | Limites de pista. El tiempo de esta vuelta no cuenta') == 1
    and s:find('VUELTA INVALIDA') ~= nil and T.spoiled == 1
    and msgCount('LEVANTA') == 0 and msgCount('SANCION') == 0 and msgCount('AVISO') == 0
''')

scenario('clasificacion: la vuelta invalidada no cuenta como mejor tiempo; la siguiente limpia si', '''
  T.sim.raceSessionType = 2
  local c = place(0, 0, 150); run(0.5)
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(1)
  c.previousLapTimeMs = 88000; c.lapCount = 1; run(0.5)        -- termina la vuelta invalidada (1:28.000)
  local s1 = hudScreen()
  c.previousLapTimeMs = 90500; c.lapCount = 2; run(0.5)        -- vuelta limpia (1:30.500)
  local s2 = hudScreen()
  return s1:find('MEJOR') == nil and s1:find('VUELTA VALIDA') ~= nil and screen():find('Vuelta 1 no cuenta: 1:28.000') ~= nil
    and s2:find('MEJOR 1:30.500') ~= nil
''')

scenario('clasificacion: causar un choque invalida la vuelta, sin drive-through', '''
  T.sim.raceSessionType = 2
  place(0, 0, 200); place(1, 4.5, 150); run(0.5)
  hit(0); run(1)
  return msgCount('VUELTA INVALIDADA | Causar un choque con Piloto1') == 1 and msgCount('DRIVE') == 0
''')

scenario('clasificacion: si un bot te choca, tu vuelta sigue valida', '''
  T.sim.raceSessionType = 2
  place(0, 4.5, 150); place(1, 0, 200); run(0.5)
  hit(0); run(4)
  return msgCount('INVALIDADA') == 0 and hudScreen():find('VUELTA VALIDA') ~= nil
''')

scenario('clasificacion: exceso en pits solo avisa', '''
  T.sim.raceSessionType = 2
  local c = place(0, 0, 120); c.isInPitlane = true; run(1)
  return msgCount('VELOCIDAD EN PITS') == 1 and msgCount('DRIVE') == 0
''')

scenario('con la opcion desmarcada, practica sanciona igual que carrera', '''
  T.sim.raceSessionType = 1
  T.cfg.raceOnly = false
  local c = place(0, 0, 150); c.gas = 1
  for n = 1, 4 do c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(4) end
  return msgCount('LEVANTA EL PIE') == 1
''')

# ---------------------------------------------------------------- sanciones reales y maximo de 17 puntos
scenario('maximo de puntos: con 17x sigues en carrera, al pasarlo quedas descalificado', '''
  preset('iRacing')
  local c = place(0, 0, 150)
  for n = 1, 17 do c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(4) end
  local at17 = msgCount('DESCALIFICADO') == 0 and hudScreen():find('INC 17x / 17') ~= nil
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(1)
  local h = hudScreen()
  return at17 and lastMsg():find('DESCALIFICADO | Pasaste el maximo de 17 puntos de incidente %(llevas 18x%)') ~= nil
    and h:find('BANDERA NEGRA | Quedas en pits, con el auto bloqueado') ~= nil and screen():find('DSQ') ~= nil
''')

scenario('reglamento de sanciones reales: tres avisos, cuarta salida +5 s, quinta +10 s', '''
  preset('Sanciones reales (FIA)')
  local c = place(0, 0, 150)
  for n = 1, 5 do c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(4) end
  return msgCount('AVISO %d/3 LIMITES') == 3 and msgCount('SANCION %+5 s | Limites de pista') == 1
    and msgCount('SANCION %+10 s | Limites de pista') == 1 and screen():find('%+15 s') ~= nil
''')

scenario('reglamento de sanciones reales: causar un choque son +10 s', '''
  preset('Sanciones reales (FIA)')
  place(0, 0, 200); place(1, 4.5, 150); run(0.5)
  hit(0); run(1)
  return msgCount('SANCION %+10 s | Causar un choque con Piloto1') == 1 and msgCount('DRIVE') == 0
''')

scenario('al actualizar la app se aplica una vez el reglamento por defecto: cuarta salida con ventaja, +5 s', '''
  local c = place(0, 0, 150)
  for n = 1, 4 do c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(4) end
  local pen = lastMsg():find('SANCION %+5 s | Limites de pista') ~= nil and msgCount('DRIVE') == 0
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(4)
  return pen and lastMsg():find('AVISO 1/3') ~= nil and T.cfg.rulesVersion == 8 and T.cfg.tlMode == 2 and T.cfg.tlPenalty == 1
    and T.cfg.dtLaps == 3 and T.cfg.incDQ == 17 and T.cfg.gbPenalty == 1 and T.cfg.ctHeavyPenalty == 1 and T.cfg.dtFailDQ == true
''', pre='FRESH_INSTALL = true')

scenario('la actualizacion reemplaza el reglamento guardado, pero respeta el tipo de salida y sus valores', '''
  return T.cfg.tlPenalty == 1 and T.cfg.tlWarnings == 3 and T.cfg.startMode == 2 and T.cfg.formSpeed == 70 and T.cfg.formGreen == 50
    and T.cfg.hudScale == 1.5
''', pre='FRESH_INSTALL = true; STORED = { tlPenalty = 3, tlWarnings = 1, startMode = 2, formSpeed = 70, formGreen = 50, hudScale = 1.5 }')

scenario('boton para restablecer el reglamento por defecto', '''
  T.cfg.tlPenalty = 3; T.cfg.incDQ = 40; T.cfg.formSpeed = 70
  press('Restablecer el reglamento por defecto')
  return T.cfg.tlPenalty == 1 and T.cfg.incDQ == 17 and T.cfg.tlMode == 2 and T.cfg.formSpeed == 70
''')

# ---------------------------------------------------------------- ganador y descalificacion
scenario('ganador: cruzas primero con +5 s y el segundo llega a 2 s: gana el segundo', '''
  T.sessionLaps = 5; T.sim.carsCount = 2; T.cfg.tlPenalty = 1; T.cfg.tlWarnings = 0
  local c = place(0, 0, 150); c.lapCount = 2
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(4)
  local pen = msgCount('SANCION %+5 s') == 1
  c.lapCount = 5; c.isRaceFinished = true; run(2)
  local waiting = msgCount('GANA') == 0
  T.cars[1].lapCount = 5; T.cars[1].isRaceFinished = true; run(2)
  return pen and waiting and lastMsg():find('GANADOR: Piloto1 | Cruzaste primero la meta, pero tienes %+5 s de sancion') ~= nil
    and msgCount('GANADOR') == 1 and not T.messageNotAscii
''')

scenario('ganador: con +5 s pero 8 s de ventaja, ganas igual', '''
  T.sessionLaps = 5; T.sim.carsCount = 2; T.cfg.tlPenalty = 1; T.cfg.tlWarnings = 0
  local c = place(0, 0, 150); c.lapCount = 2
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(4)
  c.lapCount = 5; c.isRaceFinished = true; run(8)
  T.cars[1].lapCount = 5; T.cars[1].isRaceFinished = true; run(6)
  return lastMsg():find('GANASTE LA CARRERA | Resultado con las sanciones aplicadas') ~= nil
''')

scenario('ganador: un descalificado que cruza primero no gana', '''
  T.sessionLaps = 5; T.sim.carsCount = 2; T.cfg.incDQ = 1; T.cfg.incSum = true
  local c = place(0, 0, 150); c.lapCount = 2
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(5); c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(2)
  local dq = msgCount('DESCALIFICADO') == 1
  c.lapCount = 5; c.isRaceFinished = true; run(1)
  T.cars[1].lapCount = 5; T.cars[1].isRaceFinished = true; run(6)
  return dq and lastMsg():find('GANADOR: Piloto1 | Cruzaste primero la meta, pero estas descalificado') ~= nil
''')

scenario('adelantamiento ilegal en la ultima curva: la posicion sin devolver al terminar pasa a tiempo y pierdes la carrera', '''
  T.sessionLaps = 5; T.sim.carsCount = 2; T.cfg.gbPenalty = 1
  local c = place(0, 0, 170); c.lapCount = 4; local o = place(1, 20, 150); o.lapCount = 4; run(0.5)
  c.wheelsOutside = 4; run(0.3); place(0, 35, 170); c.wheelsOutside = 0; run(2)
  local asked = lastMsg():find('DEVUELVE LA POSICION') ~= nil
  c.lapCount = 5; c.isRaceFinished = true; run(1)
  o.lapCount = 5; o.isRaceFinished = true; run(6)
  return asked and lastMsg():find('GANADOR: Piloto1 | Cruzaste primero la meta, pero tienes %+5 s de sancion') ~= nil
    and screen():find('Posicion sin devolver') == nil
''')

scenario('descalificado con un drive-through pendiente: la sancion se borra y no sale "no valido" al quedar parado en pits', """
  T.cfg.incDQ = 2; T.cfg.incStep = 2; T.cfg.incPenalty = 3; T.physicsAllowed = true
  local c = place(0, 0, 150)
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(5)
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(5)
  local dt = msgCount('DRIVE%-THROUGH') >= 1 and msgCount('DESCALIFICADO') == 0
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(3)
  local dq = msgCount('DESCALIFICADO') == 1 and c.isInPitlane
  c.speedKmh = 0; run(5)
  c.isInPitlane = false; place(0, 0, 60); run(1)
  return dt and dq and msgCount('NO VALIDO') == 0
""")

scenario('descalificado offline con permiso en la pista: va a pits; si vuelve a salir, de nuevo a pits y sin pasar de 50 km/h', '''
  T.cfg.incDQ = 1; T.physicsAllowed = true
  local c = place(0, 0, 150)
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(5)
  local free = #T.pitTeleports == 0 and #T.forcedCuts == 0
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(1)
  local sent = #T.pitTeleports == 1 and T.pitTeleports[1].i == 0 and T.pitTeleports[1].set == 'PIT' and c.isInPitlane
  run(10)
  local stays = #T.pitTeleports == 1 and T.noInput == true          -- en pits queda sin controles
  c.isInPitlane = false; place(0, 0, 150); run(3)            -- vuelve a salir a la pista
  local again = #T.pitTeleports == 2 and c.isInPitlane
  T.pitTeleportFail = true; c.isInPitlane = false; place(0, 0, 150); run(8)   -- si el juego no deja moverlo, al menos no corre
  return free and sent and stays and again and #T.forcedCuts > 60
''')

scenario('descalificado offline: al empezar otra sesion, el auto recupera los controles', '''
  T.cfg.incDQ = 1; T.physicsAllowed = true
  local c = place(0, 0, 150)
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(5); c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(3)
  local locked = T.noInput == true
  newSession(); place(0, 0, 100); run(1)
  return locked and T.noInput == false
''')

scenario('salida corta: el lugar en la fila cuenta solo autos conectados (puesto 14 de grilla, pero solo: primero)', '''
  T.cfg.startMode = 2; T.cfg.formShort = true; T.physicsAllowed = true; T.sim.carsCount = 3
  newSession(); T.sim.timeToSessionStart = -100
  T.cars[0].racePosition = 14; T.cars[1].racePosition = 3; T.cars[1].isConnected = false; T.cars[2].racePosition = 20
  run(0.5)
  local z = {}
  for _, t in ipairs(T.teleports) do z[t.i] = t.z end
  return math.abs(z[0] - 3000) < 1 and math.abs(z[2] - 2990) < 1 and hudScreen():find('MANTEN P1') ~= nil
''')

scenario('descalificado offline sin permiso en la pista: no se puede mover el auto y no hay error', '''
  T.cfg.incDQ = 1
  local c = place(0, 0, 150)
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(5); c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(3)
  return #T.pitTeleports == 0 and msgCount('DESCALIFICADO') == 1 and not logText():find('ERROR')
''')

# ---------------------------------------------------------------- salida lanzada corta
scenario('salida corta offline: los autos van a la fila en orden de grilla, a 500 m de la meta el primero', '''
  T.cfg.startMode = 2; T.cfg.formShort = true; T.physicsAllowed = true
  T.cars[0].racePosition = 2; T.cars[1].racePosition = 1; T.cars[2].racePosition = 3
  newSession(); T.cars[0].racePosition = 2; T.cars[1].racePosition = 1; T.cars[2].racePosition = 3
  T.sim.timeToSessionStart = -100
  for i = 0, 2 do T.cars[i].splinePosition = 0.98 end
  run(0.5)
  -- la meta esta en z = 3500 (posicion 1,0): 500 m antes es z = 3000
  local z = {}
  local facing = true
  for _, t in ipairs(T.teleports) do
    z[t.i] = t.z
    if math.abs(t.dir.z + 1) > 0.001 then facing = false end      -- el juego recibe la direccion de la cola del auto
  end
  return facing and #T.teleports == 3 and math.abs(z[1] - 3000) < 1 and math.abs(z[0] - 2990) < 1 and math.abs(z[2] - 2980) < 1
    and lastMsg():find('SALIDA LANZADA | Manten tu puesto y no pases de 100 km/h. Se larga cuando el lider llegue a la meta') ~= nil
''')

scenario('salida corta: verde cuando el lider llega a 100 m de la meta, sin dar la vuelta; despues de la meta se puede adelantar', '''
  T.cfg.startMode = 2; T.cfg.formShort = true; T.physicsAllowed = true; T.sim.carsCount = 2
  newSession(); T.sim.timeToSessionStart = -100
  T.cars[0].racePosition = 2; T.cars[1].racePosition = 1
  T.cars[0].splinePosition = 0.985; T.cars[1].splinePosition = 0.99      -- en la grilla, pegados a la meta
  run(1)
  local noGreenAtGrid = msgCount('BANDERA VERDE') == 0
  place(1, 3200, 90); place(0, 3190, 90); run(2)                          -- ruedan en fila: faltan 300 m
  local rolling = msgCount('BANDERA VERDE') == 0
  place(1, 3420, 95); place(0, 3410, 95); run(0.1)                        -- al lider le faltan 80 m
  local green = lastMsg():find('BANDERA VERDE') ~= nil
  T.cars[1].splinePosition = 0.02; T.cars[0].splinePosition = 0.01; run(1) -- cruzan la meta (el contador sigue en 0)
  T.cars[0].splinePosition = 0.05; T.cars[1].splinePosition = 0.04; run(3) -- ahora si puedes pasarlo
  return noGreenAtGrid and rolling and green and msgCount('DEVUELVE') == 0 and T.cars[0].lapCount == 0
''')

scenario('salida corta: adelantar antes de la meta sigue prohibido', '''
  T.cfg.startMode = 2; T.cfg.formShort = true; T.physicsAllowed = true; T.sim.carsCount = 2
  newSession(); T.sim.timeToSessionStart = -100
  T.cars[0].racePosition = 2; T.cars[1].racePosition = 1
  run(1); place(1, 3200, 90); place(0, 3190, 90); run(4)
  place(1, 3250, 90); place(0, 3270, 95); run(2)
  return lastMsg():find('DEVUELVE LA POSICION') ~= nil and lastMsg():find('Adelantamiento antes de la largada') ~= nil
''')

scenario('salida corta: mientras los autos se acomodan en la fila (primeros segundos) no se cuenta adelantamiento', '''
  T.cfg.startMode = 2; T.cfg.formShort = true; T.sim.carsCount = 2; T.sim.isOnlineRace = true
  newSession(); T.sim.isOnlineRace = true; T.sim.carsCount = 2; T.sim.timeToSessionStart = -100
  T.cars[0].racePosition = 2; T.cars[1].racePosition = 1
  T.cars[0].splinePosition = 0.985; local o = place(1, 3000, 40)          -- al otro ya lo movieron; a ti todavia no
  run(2.5)
  place(0, 2990, 40); run(3)                                              -- ahora si quedas detras de el
  return msgCount('DEVUELVE') == 0 and msgCount('STOP AND GO') == 0
''')

scenario('salida corta sin permiso para mover autos (online sin script): se hace la vuelta de formacion completa', '''
  T.cfg.startMode = 2; T.cfg.formShort = true; T.sim.carsCount = 1; T.sim.isOnlineRace = true
  newSession(); T.sim.isOnlineRace = true; T.sim.timeToSessionStart = -100
  local c = place(0, 0, 90); c.splinePosition = 0.985; run(4)
  local fell = #T.teleports == 0 and screen():find('Salida corta no disponible') ~= nil and msgCount('BANDERA VERDE') == 0
  c.splinePosition = 0.5; run(1); c.splinePosition = 0.985; run(0.2)
  return fell and lastMsg():find('BANDERA VERDE') ~= nil
''')

# ---------------------------------------------------------------- reglamento Real Penalty
scenario('RP: atajo sin soltar da aviso; los numeros del reglamento son los de Real Penalty', '''
  preset('Real Penalty')
  local c = place(0, 0, 150)
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(0.9)
  local early = #T.messages == 0                      -- aun corre el segundo para soltar
  run(0.3)
  return early and lastMsg():find('AVISO 1/3 LIMITES DE PISTA | Atajo con ventaja') ~= nil
    and T.cfg.pitLimit == 82 and T.cfg.dtFailSec == 20 and T.cfg.tlSlowRatio == 90 and T.cfg.endLaps == 1
''')

scenario('RP: si sueltas y vuelves a menos del 90% de la velocidad, no hay aviso', '''
  preset('Real Penalty')
  local c = place(0, 0, 150)
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(0.3); place(0, 0, 130); run(2)
  local s = screen()
  return msgCount('AVISO') == 0 and s:find('0/3 avisos') ~= nil and s:find('sin ventaja') ~= nil and s:find('1x') ~= nil
''')

scenario('RP: perder solo un 5% no alcanza: aviso', '''
  preset('Real Penalty')
  local c = place(0, 0, 150)
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(0.3); place(0, 0, 142); run(2)
  return msgCount('AVISO 1/3') == 1
''')

scenario('RP: una salida de mas de 3 s es accidente: suma el punto de incidente pero no da aviso', '''
  preset('Real Penalty')
  local c = place(0, 0, 150)
  c.wheelsOutside = 4; run(5); c.wheelsOutside = 0; run(3)
  local s = screen()
  return msgCount('AVISO') == 0 and s:find('0/3 avisos') ~= nil and s:find('1x') ~= nil
''')

scenario('RP: cuarto atajo es drive-through con 2 vueltas y los avisos vuelven a cero', '''
  preset('Real Penalty')
  local c = place(0, 0, 150)
  for n = 1, 4 do c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(5) end
  local dt = lastMsg():find('DRIVE%-THROUGH | Limites de pista. Pasa por pits sin detenerte, tienes 2 vueltas') ~= nil
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(5)
  return dt and msgCount('AVISO %d/3') == 4 and lastMsg():find('AVISO 1/3') ~= nil
''')

scenario('RP: dos atajos pegados (menos de 3 s) cuentan como uno', '''
  preset('Real Penalty')
  local c = place(0, 0, 150)
  c.wheelsOutside = 4; run(0.5); c.wheelsOutside = 0; run(1.5)
  c.wheelsOutside = 4; run(0.5); c.wheelsOutside = 0; run(4)
  return msgCount('AVISO') == 1
''')

scenario('RP pits: 81 km/h nada, 90 drive-through, 150 stop and go de 10 s, 210 descalificacion', '''
  preset('Real Penalty')
  local c = place(0, 0, 81); c.isInPitlane = true; run(2)
  local none = #T.messages == 0
  place(0, 0, 90); run(1)
  local dt = lastMsg():find('DRIVE%-THROUGH | Exceso en pits: 90 km/h %(limite 82%)') ~= nil
  c.isInPitlane = false; run(1); c.isInPitlane = true; place(0, 0, 150); run(1)
  local sg = lastMsg():find('STOP AND GO 10 s | Exceso en pits: 150') ~= nil
  c.isInPitlane = false; run(1); c.isInPitlane = true; place(0, 0, 210); run(1)
  return none and dt and sg and lastMsg():find('DESCALIFICADO | Exceso en pits: 210') ~= nil
''')

scenario('RP salida en falso: la sancion sale con la luz verde y depende de la velocidad (30 km/h: drive-through)', '''
  preset('Real Penalty')
  T.sim.isSessionStarted = false; T.sim.timeToSessionStart = 4000
  place(0, 0, 0); run(0.2); place(0, 3, 30); run(0.5)
  local warned = lastMsg():find('SALIDA EN FALSO') ~= nil and msgCount('DRIVE') == 0
  T.sim.isSessionStarted = true; T.sim.timeToSessionStart = -10; run(0.2)
  return warned and lastMsg():find('DRIVE%-THROUGH | Salida en falso %(30 km/h') ~= nil
''')

scenario('RP salida en falso a 120 km/h: stop and go de 10 s', '''
  preset('Real Penalty')
  T.sim.isSessionStarted = false; T.sim.timeToSessionStart = 4000
  place(0, 0, 0); run(0.2); place(0, 3, 30); run(0.5); place(0, 20, 120); run(0.5); place(0, 30, 90); run(0.2)
  T.sim.isSessionStarted = true; T.sim.timeToSessionStart = -10; run(0.2)
  return lastMsg():find('STOP AND GO 10 s | Salida en falso %(120 km/h') ~= nil and msgCount('STOP AND GO') == 1
''')

scenario('RP: drive-through sin cumplir en 2 vueltas es descalificacion', '''
  preset('Real Penalty')
  T.sessionLaps = 20
  local c = place(0, 0, 90); c.isInPitlane = true; run(1); c.isInPitlane = false; place(0, 0, 150); run(1)
  c.lapCount = 2; run(1)
  local still = msgCount('DESCALIFICADO') == 0
  c.lapCount = 3; run(1)
  return still and lastMsg():find('DESCALIFICADO | Drive%-through no cumplido en 2 vueltas') ~= nil
''')

scenario('RP ultimas 3 vueltas: el drive-through se puede dejar y pasa a +20 s, sin descalificar', '''
  preset('Real Penalty')
  T.sessionLaps = 10
  local c = place(0, 0, 150); c.lapCount = 7; run(1)
  c.isInPitlane = true; place(0, 0, 90); run(1); c.isInPitlane = false; place(0, 0, 150); run(1)
  local told = lastMsg():find('quedan pocas vueltas: cumplelo o termina la carrera con %+20 s') ~= nil
  c.lapCount = 9; run(1); c.lapCount = 10; c.isRaceFinished = true; run(1)
  return told and msgCount('DESCALIFICADO') == 0 and lastMsg():find('CARRERA TERMINADA | Sancion total: %+20 s') ~= nil
''')

scenario('RP ultimas vueltas: un stop and go de 10 s sin cumplir pasa a +30 s; con 4 vueltas por delante no hay rebaja', '''
  preset('Real Penalty')
  T.sessionLaps = 10
  local c = place(0, 0, 150); c.lapCount = 6; run(1)
  c.isInPitlane = true; place(0, 0, 90); run(1); c.isInPitlane = false; place(0, 0, 150); run(1)
  local normal = lastMsg():find('tienes 2 vueltas') ~= nil
  c.isInPitlane = true; place(0, 0, 60); run(3); c.isInPitlane = false; place(0, 0, 150); run(1)   -- lo cumple
  c.lapCount = 8; run(1)
  c.isInPitlane = true; place(0, 0, 150); run(1); c.isInPitlane = false; run(1)
  local late = lastMsg():find('STOP AND GO 10 s') ~= nil and lastMsg():find('con %+30 s') ~= nil
  c.lapCount = 10; c.isRaceFinished = true; run(1)
  return normal and late and lastMsg():find('Sancion total: %+30 s') ~= nil
''')

scenario('final de carrera con 2 vueltas extra: la sancion recibida a 4 vueltas del final no descalifica', '''
  preset('Real Penalty'); T.cfg.endLaps = 2
  T.sessionLaps = 10
  local c = place(0, 0, 150); c.lapCount = 6; run(1)
  c.isInPitlane = true; place(0, 0, 90); run(1); c.isInPitlane = false; place(0, 0, 150); run(1)
  c.lapCount = 9; run(2)
  return msgCount('quedan pocas vueltas') == 1 and msgCount('DESCALIFICADO') == 0 and screen():find('DESCALIFICADO') == nil
''')

scenario('RP formacion: pasar el limite es drive-through; pasarlo por mas de un 25% es stop and go de 30 s', '''
  preset('Real Penalty')
  T.cfg.startMode = 2; T.cfg.formSpeed = 100; T.sim.carsCount = 1
  newSession(); T.sim.timeToSessionStart = -100
  place(0, 0, 90); run(1); place(0, 0, 115); run(2.5)
  local dt = lastMsg():find('DRIVE%-THROUGH | Exceso de velocidad en la vuelta de formacion') ~= nil
  newSession(); T.sim.timeToSessionStart = -100
  place(0, 0, 90); run(1); place(0, 0, 140); run(2.5)
  return dt and lastMsg():find('STOP AND GO 30 s | Exceso de velocidad en la vuelta de formacion') ~= nil
''')

scenario('salida lanzada: la bandera verde sale 100 m antes de la meta, sin esperar al contador de vueltas', '''
  T.cfg.startMode = 2; T.sim.carsCount = 1
  newSession(); T.sim.timeToSessionStart = -100
  local c = place(0, 0, 90); c.splinePosition = 0.99; run(1)   -- en la grilla, pegado a la meta: no es la largada
  c.splinePosition = 0.02; run(1)
  local notYet = msgCount('BANDERA VERDE') == 0
  c.splinePosition = 0.5; run(1); c.splinePosition = 0.97; run(1)        -- faltan 150 m
  local stillNot = msgCount('BANDERA VERDE') == 0
  c.splinePosition = 0.985; run(0.05)                                   -- faltan 75 m
  return notYet and stillNot and c.lapCount == 0 and lastMsg():find('BANDERA VERDE') ~= nil
''')

scenario('salida lanzada con la verde en la meta (0 m): no sale antes de cruzarla', '''
  T.cfg.startMode = 2; T.cfg.formGreen = 0; T.sim.carsCount = 1
  newSession(); T.sim.timeToSessionStart = -100
  local c = place(0, 0, 90); c.splinePosition = 0.5; run(1); c.splinePosition = 0.995; run(1)
  local notYet = msgCount('BANDERA VERDE') == 0
  c.splinePosition = 0.01; run(0.05)
  return notYet and lastMsg():find('BANDERA VERDE') ~= nil
''')

scenario('muro: tocar fondo en una bajada frenando y doblando fuerte no es un golpe', '''
  -- 3 g sostenidos durante medio segundo con "colision" marcada: la velocidad cambia 53 km/h, pero de a poco
  local c = place(0, 0, 220); run(0.2)
  c.collisionDepth = 0.03
  local vx, vz = 0, 220 / 3.6
  run(0.5, function ()
    vz = vz - 2.4 * 9.81 / 60; vx = vx + 1.8 * 9.81 / 60
    c.velocity = vec3(vx, 0, vz); c.speedKmh = math.sqrt(vx * vx + vz * vz) * 3.6
  end)
  c.collisionDepth = 0; run(2)
  return #T.messages == 0 and screen():find('0x') ~= nil
''')

scenario('muro: un golpe de verdad en plena frenada si cuenta', '''
  local c = place(0, 0, 220); run(0.2)
  c.collisionDepth = 0.03
  local vz = 220 / 3.6
  run(0.1, function () vz = vz - 2 * 9.81 / 60; c.velocity = vec3(0, 0, vz); c.speedKmh = vz * 3.6 end)
  vz = vz - 30 / 3.6; c.velocity = vec3(0, 0, vz); c.speedKmh = vz * 3.6; run(0.1)
  c.collisionDepth = 0; run(2)
  return msgCount('GOLPE CONTRA EL MURO') == 1
''')

scenario('los reglamentos anteriores vuelven al modo clasico despues de usar Real Penalty', '''
  preset('Real Penalty'); preset('Sanciones reales (FIA)')
  local c = place(0, 0, 150)
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(0.3); place(0, 0, 100); run(3)
  return T.cfg.tlMode == 1 and T.cfg.tiers == false and T.cfg.pitLimit == 80 and T.cfg.dtLaps == 3
    and lastMsg():find('AVISO 1/3 LIMITES DE PISTA | Saliste de la pista') ~= nil
''')

scenario('stop and go: detenerse 10 s en pits lo cumple; salir antes no vale', '''
  T.cfg.pitPenalty = 4
  local c = place(0, 0, 120); c.isInPitlane = true; run(1)            -- exceso en pits: stop and go
  local issued = lastMsg():find('STOP AND GO 10 s | Exceso en pits') ~= nil
  c.isInPitlane = false; place(0, 0, 150); run(2)
  local waiting = hudScreen():find('STOP AND GO | Entra a pits y detente 10 s | VUELTAS PARA CUMPLIR: 3') ~= nil
  c.isInPitlane = true; place(0, 0, 60); run(1); place(0, 0, 0); run(4)
  local counting = hudScreen():find('Detente por completo en pits | 4 / 10 s') ~= nil
  place(0, 0, 60); run(1); c.isInPitlane = false; place(0, 0, 150); run(0.5)
  local invalid = lastMsg():find('STOP AND GO NO VALIDO | Debias detenerte 10 s en pits y estuviste 4') ~= nil
  c.isInPitlane = true; place(0, 0, 60); run(1); place(0, 0, 0); run(10.5); place(0, 0, 60); run(1)
  c.isInPitlane = false; place(0, 0, 150); run(0.5)
  return issued and waiting and counting and invalid and lastMsg():find('SANCION CUMPLIDA | Stop and go') ~= nil
''')

scenario('no cumplir un drive-through con la regla real: descalificacion', '''
  T.cfg.dtFailDQ = true
  local c = place(0, 0, 150); c.gas = 1; c.lapCount = 1; run(1)
  press('Drive-through')
  c.lapCount = 5; run(0.5)
  return lastMsg():find('DESCALIFICADO | Drive%-through no cumplido en 3 vueltas') ~= nil and hudScreen():find('BANDERA NEGRA') ~= nil
    and msgCount('SANCION %+30') == 0
''')

scenario('sancion configurable por salida en falso', '''
  newSession(); T.cfg.jumpPenalty = 1
  T.sim.isSessionStarted = false; T.sim.timeToSessionStart = 4000
  run(1); place(0, 3, 15); run(0.5)
  return lastMsg():find('SANCION %+5 s | Salida en falso') ~= nil
''')

# ---------------------------------------------------------------- devolver la posicion
scenario('contacto con el que ganas el puesto: se pide devolverlo, y al dejar pasar no hay sancion', '''
  place(0, 0, 170); place(1, 4.5, 150); run(0.5)
  hit(0); run(0.5)
  place(0, 20, 170); run(3)                           -- quedaste delante de Piloto1
  local asked = lastMsg():find('DEVUELVE LA POSICION | Deja pasar a Piloto1 antes de 20 s. Motivo: Contacto evitable con Piloto1') ~= nil
  local h = hudScreen()
  local shown = h:find('ORDEN DEL COMISARIO | DEVUELVE LA POSICION | Deja pasar a Piloto1') ~= nil
  place(0, 0, 120); place(1, 30, 150); run(1)         -- lo dejas pasar
  return asked and shown and lastMsg():find('POSICION DEVUELTA | Sin sancion') ~= nil and msgCount('DRIVE') == 0
    and msgCount('SANCION %+') == 0 and hudScreen():find('DEVUELVE') == nil
''')

scenario('no devolver la posicion en el plazo: drive-through', '''
  place(0, 0, 170); place(1, 4.5, 150); run(0.5)
  hit(0); run(0.5); place(0, 20, 170); run(3)
  local before = msgCount('DRIVE%-THROUGH')
  run(21)
  return before == 0 and lastMsg():find('DRIVE%-THROUGH | No devolviste la posicion a Piloto1') ~= nil
''')

scenario('si el golpeado queda detenido, ya no se puede devolver: sancion directa', '''
  place(0, 0, 170); place(1, 4.5, 150); run(0.5)
  hit(0); run(0.5); place(0, 20, 170); run(3)
  place(1, 4.5, 0); run(6)
  return lastMsg():find('DRIVE%-THROUGH | Contacto evitable con Piloto1 %(quedo detenido%)') ~= nil
''')

scenario('adelantar por fuera de la pista: hay que devolver el puesto', '''
  local c = place(0, 0, 170); place(1, 20, 150); run(0.5)
  c.wheelsOutside = 4; run(0.3)                       -- te sales con Piloto1 justo delante
  place(0, 35, 170); c.wheelsOutside = 0; run(2)      -- vuelves a la pista delante de el
  return lastMsg():find('DEVUELVE LA POSICION | Deja pasar a Piloto1 antes de 20 s. Motivo: Adelantamiento por fuera de la pista') ~= nil
''')

scenario('salirse y volver detras del mismo auto no es adelantamiento', '''
  local c = place(0, 0, 170); place(1, 20, 150); run(0.5)
  c.wheelsOutside = 4; run(0.3); c.wheelsOutside = 0; run(3)
  return msgCount('DEVUELVE') == 0
''')

scenario('con "devolver la posicion" apagado, adelantar por fuera es sancion directa', '''
  T.cfg.gbEnabled = false
  local c = place(0, 0, 170); place(1, 20, 150); run(0.5)
  c.wheelsOutside = 4; run(0.3); place(0, 35, 170); c.wheelsOutside = 0; run(2)
  return msgCount('DEVUELVE') == 0 and lastMsg():find('DRIVE%-THROUGH | Adelantamiento por fuera de la pista') ~= nil
''')

scenario('carrera terminada con una posicion sin devolver: pasa a tiempo', '''
  local c = place(0, 0, 170); place(1, 20, 150); run(0.5)
  c.wheelsOutside = 4; run(0.3); place(0, 35, 170); c.wheelsOutside = 0; run(2)
  c.isRaceFinished = true; run(1)
  return lastMsg():find('CARRERA TERMINADA | Sancion total: %+30 s') ~= nil
''')

# ---------------------------------------------------------------- salida lanzada
scenario('salida lanzada contra la IA: formacion con limite de velocidad y bandera verde cuando el lider cruza la meta', '''
  T.physicsAllowed = true; T.cfg.startMode = 2
  newSession(); T.sim.timeToSessionStart = -100
  T.cars[0].racePosition = 2; T.cars[1].racePosition = 1; T.cars[2].racePosition = 3
  place(0, 0, 60); place(1, 10, 60); place(2, -10, 60); run(1)
  local formation = lastMsg():find('VUELTA DE FORMACION | Manten tu puesto y no pases de 100 km/h') ~= nil
    and T.aiCaps[1][1] == 100 and T.aiCaps[2][1] == 100
  local bar = hudScreen():find('CARRERA | FORMACION | MAX 100 km/h | MANTEN P2') ~= nil
  run(20)
  local quiet = #T.messages == 1
  T.cars[1].lapCount = 1; run(0.5)
  -- a la verde queda libre solo el que ya cruzo la meta; el de atras sigue limitado hasta cruzarla
  local green = lastMsg():find('BANDERA VERDE | Carrera lanzada. Puedes adelantar despues de cruzar la meta') ~= nil
    and last(T.aiCaps[1]) == math.huge and last(T.aiCaps[2]) ~= math.huge
  local bar2 = hudScreen():find('VERDE | ADELANTA DESPUES DE LA META') ~= nil
  T.cars[0].lapCount = 1; T.cars[2].lapCount = 1; run(8)   -- cruzan la meta: ya es carrera normal
  return formation and bar and quiet and green and bar2 and hudScreen():find('VERDE') == nil and last(T.aiCaps[2]) == math.huge
''')

scenario('salida lanzada: correr en la formacion es sancion', '''
  T.physicsAllowed = true; T.cfg.startMode = 2
  newSession(); T.sim.timeToSessionStart = -100
  place(0, 0, 60); run(1)
  place(0, 0, 105); run(5)                             -- dentro del margen
  local ok = #T.messages == 1
  place(0, 0, 150); run(3)
  return ok and lastMsg():find('DRIVE%-THROUGH | Exceso de velocidad en la vuelta de formacion') ~= nil
''')

scenario('salida lanzada: adelantar antes de la meta obliga a devolver el puesto', '''
  T.physicsAllowed = true; T.cfg.startMode = 2
  newSession(); T.sim.timeToSessionStart = -100
  T.cars[0].racePosition = 2; T.cars[1].racePosition = 1
  place(0, 0, 60); place(1, 10, 60); run(1)
  place(0, 30, 90); run(2)                             -- pasas al que largo delante
  return lastMsg():find('DEVUELVE LA POSICION | Deja pasar a Piloto1 antes de 20 s. Motivo: Adelantamiento antes de la largada') ~= nil
''')

scenario('salida lanzada contra la IA sin permiso de la pista: avisa y usa la salida parada', '''
  T.cfg.startMode = 2
  newSession(); T.sim.timeToSessionStart = -100
  place(0, 0, 150); run(5)
  return #T.messages == 1 and lastMsg():find('SALIDA LANZADA NO DISPONIBLE') ~= nil and T.aiCaps[1] == nil
''')

scenario('salida lanzada: no se revisa la salida en falso, y en salida parada no hay formacion', '''
  T.physicsAllowed = true; T.cfg.startMode = 2
  newSession()
  T.sim.isSessionStarted = false; T.sim.timeToSessionStart = 4000
  run(1); place(0, 3, 15); run(0.5)
  local noJump = #T.messages == 0
  T.cfg.startMode = 1
  newSession(); T.sim.isSessionStarted = true; T.sim.timeToSessionStart = -100
  place(0, 0, 150); run(5)
  return noJump and #T.messages == 0
''')

# ---------------------------------------------------------------- cronometro de salidas de pista
scenario('la misma salida no se cuenta dos veces aunque el auto pise la pista un instante', '''
  local c = place(0, 0, 150)
  c.wheelsOutside = 4; run(1)
  c.wheelsOutside = 2; run(0.5); c.wheelsOutside = 4; run(1)      -- toca la pista y vuelve a salir
  c.wheelsOutside = 3; run(0.2); c.wheelsOutside = 4; run(1)      -- parpadeo de una rueda
  c.wheelsOutside = 0; run(2); c.wheelsOutside = 4; run(1)        -- vuelve 2 s y sale otra vez: sigue siendo la misma
  c.wheelsOutside = 0; run(2); c.wheelsOutside = 4; run(1)        -- otra vez 2 s: el cronometro parte de cero cada vez
  local once = #T.messages == 1 and screen():find('salidas 1') ~= nil
  c.wheelsOutside = 0; run(3.5); c.wheelsOutside = 4; run(1)      -- mas de 3 s en pista: ahora si es una salida nueva
  return once and #T.messages == 2 and lastMsg():find('AVISO 2/3') ~= nil
''')

scenario('el tiempo de espera entre salidas se puede ajustar', '''
  T.cfg.tlCooldown = 1
  local c = place(0, 0, 150)
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(1.5); c.wheelsOutside = 4; run(1)
  return #T.messages == 2
''')

# ---------------------------------------------------------------- banderas
FL = "T.cfg.flEnabled = true; T.sim.timeToSessionStart = -20000; "

scenario('amarilla: auto detenido 200 m adelante; al despejarse sale verde y despues nada', FL + '''
  place(0, 0, 150); place(1, 200, 0); run(0.5)
  local y = lastMsg():find('BANDERA AMARILLA | Piloto1 detenido o sin control a 200 m. Prohibido adelantar') ~= nil
    and hudScreen():find('AMARILLA') ~= nil and screen():find('Bandera: | AMARILLA') ~= nil
  place(1, 200, 150); run(2.5)
  local g = hudScreen():find('| VERDE |') ~= nil and hudScreen():find('NO ADELANTAR') == nil
  run(6)
  return y and g and hudScreen():find('VERDE') == nil and #T.messages == 1 and not T.messageNotAscii
''')

scenario('sin amarilla: auto detenido lejos, en pits, detras, o en los primeros segundos de la largada', FL + '''
  place(0, 0, 150); place(1, 500, 0); run(1)
  local c = place(1, 200, 0); c.isInPitlane = true; run(1); c.isInPitlane = false
  place(1, -100, 0); run(1)
  T.sim.timeToSessionStart = -5000; place(1, 200, 0); run(1)
  return #T.messages == 0 and hudScreen():find('AMARILLA') == nil
''')

scenario('adelantar con amarilla: hay que devolver el puesto; pasar al auto detenido no es falta', FL + '''
  place(0, 0, 120); place(1, 250, 0); place(2, 30, 120); run(1)
  place(0, 260, 120); place(2, 240, 120); place(1, 250, 0)       -- pasaste a los dos
  place(1, 200, 0); run(2)
  local asked = msgCount('DEVUELVE LA POSICION | Deja pasar a Piloto2') == 1 and lastMsg():find('Adelantamiento con bandera amarilla') ~= nil
    and msgCount('Deja pasar a Piloto1') == 0
  place(1, 5000, 150); run(21)
  return asked and lastMsg():find('DRIVE%-THROUGH | No devolviste la posicion a Piloto2') ~= nil
''')

scenario('con "prohibido adelantar" apagado, o en practica, adelantar con amarilla no se sanciona', FL + '''
  T.cfg.yfPass = false
  place(0, 0, 120); place(1, 250, 0); place(2, 30, 120); run(1)
  place(0, 260, 120); place(2, 240, 120); run(2)
  local off = msgCount('DEVUELVE') == 0
  T.cfg.yfPass = true; newSession(); T.sim.raceSessionType = 1
  place(0, 0, 120); place(1, 250, 0); place(2, 30, 120); run(1)
  place(0, 260, 120); place(2, 240, 120); run(2)
  return off and msgCount('DEVUELVE') == 0 and msgCount('BANDERA AMARILLA') == 1
''')

scenario('azul en carrera: solo si el de atras te saca una vuelta', FL + '''
  place(0, 0, 150); place(1, -20, 160); run(1)
  local same = #T.messages == 0
  -- el de atras da una vuelta completa mas que tu y vuelve a quedar justo detras
  local o = T.cars[1]
  for k = 1, 200 do o.splinePosition = (o.splinePosition + 0.005) % 1; run(1 / 60) end
  o.lapCount = 1; run(0.5)
  return same and lastMsg():find('BANDERA AZUL | Deja pasar a Piloto1, te saca una vuelta') ~= nil
    and hudScreen():find('AZUL') ~= nil and msgCount('BANDERA AZUL') == 1
''')

scenario('azul: no ceder el paso en 20 s se sanciona una vez; por defecto es solo aviso', FL + '''
  place(0, 0, 150); local o = place(1, -20, 160); o.lapCount = 1; run(25)
  local warnOnly = msgCount('SANCION') == 0
  newSession(); T.cfg.bfPenalty = 1
  place(0, 0, 150); o = place(1, -20, 160); o.lapCount = 1; run(19)
  local notYet = msgCount('SANCION') == 0
  run(10)
  return warnOnly and notYet and msgCount('SANCION %+5 s | No cediste el paso a Piloto1 con bandera azul') == 1
''')

scenario('azul fuera de carrera: viene alguien mucho mas rapido', FL + '''
  T.sim.raceSessionType = 2
  place(0, 0, 100); place(1, -20, 120); run(1)
  local none = #T.messages == 0
  place(1, -20, 200); run(0.5)
  return none and lastMsg():find('BANDERA AZUL | Deja pasar a Piloto1, viene mas rapido') ~= nil
''')

scenario('blanca en la ultima vuelta y a cuadros en la meta', FL + '''
  T.sessionLaps = 5
  local c = place(0, 0, 150); c.lapCount = 3; run(1)
  local none = #T.messages == 0
  c.lapCount = 4; run(1)
  local white = lastMsg():find('ULTIMA VUELTA') ~= nil and hudScreen():find('ULTIMA VUELTA') ~= nil
  c.lapCount = 5; c.isRaceFinished = true; run(1)
  return none and white and hudScreen():find('META') ~= nil and msgCount('ULTIMA VUELTA') == 1 and not T.messageNotAscii
''')

scenario('direccion de carrera: amarilla total con limite, sancion por correr y vuelta a verde', FL + '''
  local function click(b) T.clickButton = b; script.windowMain(0.016); T.clickButton = nil end
  place(0, 0, 150); run(1)
  click('Amarilla total'); run(1)
  local fcy = lastMsg():find('AMARILLA TOTAL | Maximo 80 km/h y prohibido adelantar') ~= nil and hudScreen():find('AMARILLA TOTAL') ~= nil
  place(0, 0, 85); run(15)
  local calm = msgCount('DRIVE') == 0
  place(0, 0, 150); run(4)
  local pen = lastMsg():find('DRIVE%-THROUGH | Exceso de velocidad con amarilla total') ~= nil
  run(10)
  click('Verde'); run(0.5)
  return fcy and calm and pen and msgCount('DRIVE') == 1 and lastMsg():find('BANDERA VERDE | Pista libre') ~= nil
    and hudScreen():find('AMARILLA TOTAL') == nil
''')

scenario('bandera roja: se anuncia, hay 8 s para frenar y no se puede adelantar', FL + '''
  local function click(b) T.clickButton = b; script.windowMain(0.016); T.clickButton = nil end
  place(0, 0, 150); place(1, 40, 150); run(1)
  click('Roja'); run(6)
  local red = msgCount('BANDERA ROJA | Sesion detenida: maximo 80 km/h') == 1 and hudScreen():find('ROJA') ~= nil and msgCount('DRIVE') == 0
  place(0, 0, 70); place(1, 40, 70); run(3)
  place(0, 60, 80); place(1, 40, 70); run(2)
  return red and lastMsg():find('DEVUELVE LA POSICION') ~= nil and lastMsg():find('Adelantamiento con bandera roja') ~= nil
''')

scenario('amarilla total contra la IA: se le baja la velocidad si la pista lo permite y se le suelta con la verde', FL + '''
  local function click(b) T.clickButton = b; script.windowMain(0.016); T.clickButton = nil end
  T.physicsAllowed = true
  place(0, 0, 70); run(1)
  click('Amarilla total'); run(1)
  local capped = last(T.aiCaps[1]) == 80 and last(T.aiCaps[2]) == 80
  click('Verde'); run(1)
  return capped and last(T.aiCaps[1]) == math.huge
''')

scenario('descalificado: bandera negra; con las banderas apagadas no aparece ninguna', FL + '''
  T.cfg.incDQ = 1
  local c = place(0, 0, 150); place(1, 200, 0)
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(5)
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(1)
  local black = hudScreen():find('NEGRA') ~= nil
  newSession(); T.cfg.flEnabled = false; T.cfg.incDQ = 17
  place(0, 0, 150); place(1, 200, 0); run(2)
  return black and msgCount('BANDERA') == 0 and hudScreen():find('AMARILLA') == nil and screen():find('Bandera:') == nil
''')

# ---------------------------------------------------------------- iconos
scenario('iconos: con la carpeta img se dibujan las imagenes de cada bandera y sancion; el cartel dice que hacer', '''
  T.files['C:/logs/img/aviso.png'] = 'x'
  T.cfg.flEnabled = true; T.sim.timeToSessionStart = -20000; T.cfg.pitPenalty = 3
  local function has(name) for _, f in ipairs(T.images) do if f == 'C:/logs/img/' .. name .. '.png' then return true end end return false end
  place(0, 0, 150); place(1, 200, 0); run(0.5); hud()
  local yellow = has('bandera_amarilla')
  place(1, 200, 150); run(8)
  local c = place(0, 0, 120); c.isInPitlane = true; run(1); c.isInPitlane = false; place(0, 0, 150); run(1); T.images = {}
  local h = hudScreen()
  return yellow and has('drive_through') and h:find('DRIVE%-THROUGH | Pasa por pits sin parar') ~= nil
''')

scenario('iconos: sin la carpeta img, o con la opcion apagada, se usan las banderas dibujadas', '''
  local c = place(0, 0, 120); c.isInPitlane = true; run(1); c.isInPitlane = false; place(0, 0, 150); run(1)
  hud()
  local none = #T.images == 0
  return none and hudScreen():find('DRIVE%-THROUGH') ~= nil and not logText():find('ERROR')
''')

scenario('iconos apagados en los ajustes: no se dibuja ninguna imagen', '''
  T.files['C:/logs/img/aviso.png'] = 'x'; T.cfg.hudIcons = false
  local c = place(0, 0, 120); c.isInPitlane = true; run(1); c.isInPitlane = false; place(0, 0, 150); run(1)
  hud()
  return #T.images == 0
''')

# ---------------------------------------------------------------- indicador de largada
scenario('indicador de largada: en la formacion muestra tu velocidad contra el limite; al largar, el semaforo', '''
  T.cfg.startMode = 2; T.cfg.formSpeed = 90; T.sim.carsCount = 1
  local before = hudScreen():find('MAX 90') == nil
  newSession(); T.sim.timeToSessionStart = -100
  local c = place(0, 0, 84); c.racePosition = 3; run(1)
  local h = hudScreen()
  local forming = h:find('VUELTA DE FORMACION | MANTEN P1 | 84 | km/h | MAX 90') ~= nil   -- puesto 3 de grilla, pero corre solo
  c.splinePosition = 0.5; run(1); c.splinePosition = 0.985; run(0.2)
  local circles = T.uiCalls; hud(); circles = T.uiCalls - circles
  local h2 = hudScreen()
  run(5); local c1 = T.uiCalls; hud(); c1 = T.uiCalls - c1          -- a los 5 s el semaforo sigue encendido
  run(4); local c2 = T.uiCalls; hud(); c2 = T.uiCalls - c2          -- a los 9 s ya se apago
  return before and forming and h2:find('MAX 90') == nil and circles > c2 + 9 and c1 > c2 + 9
''')

scenario('indicador de largada: con amarilla total muestra la velocidad contra el limite de la bandera', '''
  T.cfg.flEnabled = true; T.cfg.fcySpeed = 70
  place(0, 0, 95); run(1)
  T.clickButton = 'Amarilla total'; script.windowMain(0.016); T.clickButton = nil; run(1)
  local on = hudScreen():find('AMARILLA TOTAL | NO ADELANTAR | 95 | km/h | MAX 70') ~= nil
  T.clickButton = 'Verde'; script.windowMain(0.016); T.clickButton = nil; run(1)
  return on and hudScreen():find('MAX 70') == nil
''')

# ---------------------------------------------------------------- interfaz fija y sin fondo
scenario('interfaz fija: los indicadores se dibujan en una columna centrada en el punto elegido, no en ventanas', '''
  T.cfg.hudFixed = true; T.cfg.hudX = 50; T.cfg.hudY = 10; T.cfg.hudBg = true
  local c = place(0, 0, 120); c.isInPitlane = true; run(1); c.isInPitlane = false; place(0, 0, 150); run(1)
  T.texts = {}
  script.windowHudMessage(0.016); script.windowHudPenalty(0.016); script.windowHudStatus(0.016); script.windowHudStart(0.016)
  local windowsEmpty = #T.texts == 0
  script.fullscreenUI(0.016); script.fullscreenUI(0.016)
  local h = hudScreen()
  local all = h:find('CARRERA') ~= nil and h:find('DRIVE%-THROUGH | Exceso en pits') ~= nil and h:find('SANCION PENDIENTE | DRIVE%-THROUGH | Pasa por pits sin parar') ~= nil
  local pStatus, pPen = T.textPos['CARRERA'], T.textPos['SANCION PENDIENTE']
  -- pantalla de 1920 x 1080: la columna parte en y = 108 y esta centrada en x = 960; la sancion va debajo del estado
  local placed = pStatus.y >= 108 and pStatus.y < 130 and pStatus.x > 700 and pStatus.x < 960 and pPen.y > pStatus.y + 60 and pPen.x > 700 and pPen.x < 960
  T.cfg.hudX = 20; T.cfg.hudY = 50; script.fullscreenUI(0.016)
  local moved = T.textPos['CARRERA'].y >= 540 and T.textPos['CARRERA'].x < 384
  return windowsEmpty and all and placed and moved and not logText():find('ERROR')
''')

scenario('interfaz fija apagada: vuelven las ventanas sueltas y la pantalla completa no dibuja nada', '''
  T.cfg.hudFixed = false
  local c = place(0, 0, 120); c.isInPitlane = true; run(1); c.isInPitlane = false; place(0, 0, 150); run(1)
  T.texts = {}; script.fullscreenUI(0.016)
  local none = #T.texts == 0
  T.texts = {}; script.windowHudPenalty(0.016)
  return none and #T.texts > 2
''')

scenario('sin fondo: no se dibujan los rectangulos de los carteles y las letras llevan el contorno del juego, una sola vez por cuadro', '''
  T.cfg.hudFixed = true
  local c = place(0, 0, 120); c.isInPitlane = true; run(1); c.isInPitlane = false; place(0, 0, 150); run(1)
  T.cfg.hudBg = true; T.calls = {}; script.fullscreenUI(0.016)
  local rectsBg, textsBg, outBg = T.calls.drawRectFilled or 0, T.calls.dwriteDrawText or 0, T.calls.beginOutline or 0
  T.cfg.hudBg = false; T.calls = {}; script.fullscreenUI(0.016)
  local rects, texts, out1, out2 = T.calls.drawRectFilled or 0, T.calls.dwriteDrawText or 0, T.calls.beginOutline, T.calls.endOutline
  local h = hudScreen()
  return rectsBg >= rects + 6 and texts == textsBg and outBg == 0 and out1 == 1 and out2 == 1
    and h:find('SANCION PENDIENTE | DRIVE%-THROUGH | Pasa por pits sin parar') ~= nil
''')

scenario('sin fondo, en un juego que no trae el contorno: se dibuja a mano con ocho copias oscuras de cada texto', '''
  T.cfg.hudFixed = true
  local c = place(0, 0, 120); c.isInPitlane = true; run(1); c.isInPitlane = false; place(0, 0, 150); run(1)
  T.cfg.hudBg = true; T.calls = {}; script.fullscreenUI(0.016)
  local textsBg = T.calls.dwriteDrawText or 0
  T.cfg.hudBg = false; T.calls = {}; script.fullscreenUI(0.016)
  return textsBg > 5 and T.calls.dwriteDrawText == textsBg * 9 and not logText():find('ERROR')
''', pre='NO_OUTLINE = true')

scenario('al actualizar desde antes de la 1.4 se aplica una vez la interfaz fija sin fondo y se cierran las ventanas sueltas', '''
  local first = T.cfg.hudFixed == true and T.cfg.hudBg == false and T.cfg.uiVersion == 3 and T.cfg.hudY == 22
    and T.windows.hud_msg == false and T.windows.hud_pen == false and T.windows.hud_status == false and T.windows.hud_start == false
  return first
''', pre='FRESH_INSTALL = true; STORED = { hudBg = true, hudFixed = false }')


# ---------------------------------------------------------------- 1.5: posicion, nitidez, idioma y ajustes
scenario('al actualizar desde la 1.4, la columna baja del 10% al 22% para no tapar el espejo virtual', '''
  return T.cfg.hudY == 22 and T.cfg.uiVersion == 3 and T.cfg.hudX == 50 and T.cfg.hudFixed == true
''', pre='FRESH_INSTALL = true; STORED = { uiVersion = 2, hudY = 10, hudBg = false, hudFixed = true }')

scenario('al actualizar, quien ya habia elegido otra altura la conserva', '''
  return T.cfg.hudY == 40 and T.cfg.uiVersion == 3
''', pre='FRESH_INSTALL = true; STORED = { uiVersion = 2, hudY = 40, hudBg = false, hudFixed = true }')

scenario('nitidez: los textos y los iconos se dibujan siempre en pixeles enteros, con cualquier tamano', '''
  T.files['C:/logs/img/aviso.png'] = 'x'
  T.cfg.hudFixed = true; T.cfg.hudBg = false; T.cfg.hudPlace = true
  local function whole(v) return math.abs(v - math.floor(v + 0.5)) < 1e-6 end
  local ok, seen = true, 0
  for _, scale in ipairs({ 0.6, 0.85, 1, 1.3, 1.75, 2.5 }) do
    T.cfg.hudScale = scale
    T.textPos = {}; T.imageRects = {}
    script.fullscreenUI(0.016); script.fullscreenUI(0.016)
    for _, p in pairs(T.textPos) do
      seen = seen + 1
      if not (whole(p.x) and whole(p.y)) then ok = false end
    end
    for _, r in ipairs(T.imageRects) do
      seen = seen + 1
      if not (whole(r.p1.x) and whole(r.p1.y) and whole(r.p2.x) and whole(r.p2.y)) then ok = false end
    end
  end
  return ok and seen > 60 and not logText():find('ERROR')
''')

scenario('nitidez: de cada icono se usa la imagen del tamano mas cercano al que se dibuja', '''
  for _, f in ipairs({ 'img/aviso.png', 'img/48/aviso.png', 'img/80/aviso.png', 'img/160/aviso.png' }) do T.files['C:/logs/' .. f] = 'x' end
  T.cfg.hudFixed = true; T.cfg.hudPlace = true
  local function dirs()
    T.images = {}; script.fullscreenUI(0.016)
    local d = {}
    for _, f in ipairs(T.images) do d[f:match('img/(%d*)/?[%w_]+%.png$')] = true end
    return d
  end
  T.cfg.hudScale = 1
  local small = dirs()           -- la barra de estado usa la de 48 y los carteles la de 80
  T.cfg.hudScale = 2.5
  local big = dirs()             -- con todo mas grande se pasa a la de 160 y a la original
  return small['48'] and small['80'] and not small['160'] and not small['']
    and big['160'] and big[''] and not big['48'] and not big['80']
''')

scenario('pantallas grandes: en 4K los indicadores crecen en proporcion', '''
  T.cfg.hudFixed = true; T.cfg.hudBg = true
  local c = place(0, 0, 120); c.isInPitlane = true; run(1); c.isInPitlane = false; place(0, 0, 150); run(1)
  script.fullscreenUI(0.016); script.fullscreenUI(0.016)
  local a, b = T.textPos['CARRERA'], T.textPos['SANCION PENDIENTE']
  local gap1080 = b.y - a.y
  T.screenW, T.screenH = 3840, 2160
  script.fullscreenUI(0.016); script.fullscreenUI(0.016)
  a, b = T.textPos['CARRERA'], T.textPos['SANCION PENDIENTE']
  local gap4k = b.y - a.y
  return gap1080 > 60 and math.abs(gap4k - gap1080 * 2) <= 3 and a.y >= 2160 * 0.22 - 1
''')

scenario('ingles: avisos, sanciones, panel e indicadores salen en ingles', '''
  T.cfg.lang = 2
  T.cfg.tlPenalty = 1; T.cfg.tlWarnings = 1
  local c = place(0, 0, 150); c.gas = 1
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(5)
  local warn = lastMsg():find('WARNING 1/1 TRACK LIMITS | You went off track. The next one is a penalty', 1, true) ~= nil
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(2)
  local pen = lastMsg():find('PENALTY +5 s | Track limits. Added to your final time', 1, true) ~= nil
  c.isInPitlane = true; place(0, 0, 120); run(1); c.isInPitlane = false; place(0, 0, 150); run(1)
  local dt = lastMsg():find('DRIVE-THROUGH | Pit lane speeding: 120 km/h (limit 80). Drive through the pits without stopping, you have 3 laps', 1, true) ~= nil
  local h = hudScreen()
  local hudOk = h:find('RACE', 1, true) ~= nil and h:find('PENDING PENALTY | DRIVE-THROUGH | Drive through the pits without stopping', 1, true) ~= nil
    and h:find('LAPS TO SERVE IT: 3', 1, true) ~= nil
  local s = screen()
  local panel = s:find('Race - penalties active', 1, true) ~= nil and s:find('Time penalty:', 1, true) ~= nil
    and s:find('Track limits:', 1, true) ~= nil
  return warn and pen and dt and hudOk and panel and not logText():find('ERROR')
''')

scenario('ingles: el icono de cada aviso es el mismo que en espanol', '''
  T.files['C:/logs/img/aviso.png'] = 'x'
  T.cfg.lang = 2; T.cfg.tlPenalty = 1; T.cfg.tlWarnings = 0; T.cfg.hudFixed = true
  local c = place(0, 0, 150); c.gas = 1
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(1)
  T.images = {}; script.fullscreenUI(0.016)
  local time = false
  for _, f in ipairs(T.images) do if f:find('tiempo.png', 1, true) then time = true end end
  return lastMsg():find('PENALTY +5 s', 1, true) ~= nil and time
''')

scenario('ingles: la ventana de ajustes completa, con todas las ayudas y listas abiertas, no deja textos en espanol', '''
  T.cfg.lang = 2; T.cfg.setAll = true; T.hoverAll = true; T.openCombos = true
  T.texts = {}; T.labels = {}; script.windowSettings(0.016); script.windowMain(0.016); script.windowStandings(0.016)
  local all = ' ' .. table.concat(T.texts, ' | ') .. ' | ' .. table.concat(T.labels, ' | ') .. ' '
  local spanish = nil
  for _, w in ipairs({ ' de ', ' la ', ' el ', ' los ', ' con ', ' sin ', ' que ', ' para ', 'Sancion', 'Vigilar', 'pista', 'vuelta', 'Aviso', 'Ninguna' }) do
    if all:find(w, 1, true) then spanish = w end
  end
  local english = all:find('When it penalises', 1, true) and all:find('Warnings before a penalty', 1, true)
    and all:find('Show all options', 1, true) and all:find('%.0f m from the line', 1, true) and all:find('Rolling##', 1, true)
    and all:find('Home###', 1, true) and all:find('Full course yellow', 1, true)
    and all:find('None', 1, true) and all:find('Start type', 1, true) and all:find('Rules in use', 1, true)
  if spanish then error('quedo en espanol: ' .. spanish) end
  return english ~= nil and #T.texts > 150 and #T.labels > 90 and not logText():find('ERROR')
''')

scenario('el idioma se cambia desde los ajustes y el selector se ve siempre en los dos idiomas', '''
  T.texts = {}; script.windowSettings(0.016)
  local es = table.concat(T.texts, ' | ')
  T.clickRadio = 'English'; script.windowSettings(0.016); T.clickRadio = nil
  local changed = T.cfg.lang == 2
  T.texts = {}; script.windowSettings(0.016)
  local en = table.concat(T.texts, ' | ')
  T.clickRadio = 'Espanol'; script.windowSettings(0.016); T.clickRadio = nil
  return es:find('Reglamento en uso', 1, true) ~= nil and changed and en:find('Rules in use', 1, true) ~= nil
    and en:find('Reglamento en uso', 1, true) == nil and T.cfg.lang == 1
''')

scenario('ajustes: la vista simple muestra menos de la mitad de las opciones; con "todas las opciones" aparecen las finas', '''
  local function count()
    T.calls = {}; T.texts = {}; script.windowSettings(0.016)
    return (T.calls.setNextItemWidth or 0), table.concat(T.texts, ' | ')
  end
  local simple, textSimple = count()
  T.cfg.setAll = true
  local full, textFull = count()
  return simple >= 15 and simple * 2 < full and textSimple:find('Ruedas fuera para contar', 1, true) == nil
    and textFull:find('Ruedas fuera para contar', 1, true) ~= nil and textSimple:find('Avisos antes de sancionar', 1, true) ~= nil
''')

scenario('ajustes: cada explicacion aparece solo al pasar el mouse por encima', '''
  T.calls = {}; script.windowSettings(0.016)
  local quiet = (T.calls.setTooltip or 0) == 0
  T.hoverAll = true; T.calls = {}; T.texts = {}; script.windowSettings(0.016)
  local tips = table.concat(T.texts, ' | ')
  return quiet and T.calls.setTooltip > 20 and tips:find('Apagado, la app no vigila ni sanciona', 1, true) ~= nil
''')

scenario('ajustes: el tipo de sancion se elige en una lista desplegable', '''
  T.cfg.tlPenalty = 1
  T.clickSelect = { '##tlPenalty', 'Drive-through' }; script.windowSettings(0.016); T.clickSelect = nil
  local dt = T.cfg.tlPenalty == 3
  T.clickSelect = { '##tlPenalty', 'Ninguna' }; script.windowSettings(0.016); T.clickSelect = nil
  local none = T.cfg.tlPenalty == 0
  T.clickSelect = { '##gbPenalty', 'Stop and go' }; script.windowSettings(0.016); T.clickSelect = nil
  return dt and none and T.cfg.gbPenalty == 4 and T.cfg.ctMedPenalty ~= 4
''')

scenario('ajustes: los deslizadores cambian su valor y los enteros quedan sin decimales', '''
  T.setCfg = { pitLimit = 60.4, tlMinTime = 0.7, hudY = 30.6 }; script.windowSettings(0.016); T.setCfg = nil
  T.cfg.setAll = true
  T.setCfg = { tlMinTime = 0.7 }; script.windowSettings(0.016); T.setCfg = nil
  return T.cfg.pitLimit == 60 and T.cfg.hudY == 31 and math.abs(T.cfg.tlMinTime - 0.7) < 1e-6
''')

scenario('ajustes: el resumen del reglamento se arma con los valores en uso', '''
  T.cfg.tlWarnings = 2; T.cfg.tlPenalty = 3; T.cfg.pitLimit = 60; T.cfg.incDQ = 9; T.cfg.dtFailDQ = true; T.cfg.dtLaps = 2
  T.cfg.ctWarnings = 1; T.cfg.ctMedPenalty = 1
  T.texts = {}; script.windowSettings(0.016)
  local t = table.concat(T.texts, ' | ')
  T.cfg.tlWarnings = 0; T.texts = {}; script.windowSettings(0.016)
  local direct = table.concat(T.texts, ' | '):find('Limites de pista: drive-through, sin aviso previo', 1, true) ~= nil
  return direct and t:find('Contacto evitable: 1 aviso y despues tiempo', 1, true) ~= nil
    and t:find('Limites de pista: 2 avisos y despues drive-through', 1, true) ~= nil and t:find('Pits: limite de 60 km/h', 1, true) ~= nil
    and t:find('Mas de 9 puntos de incidente: descalificacion', 1, true) ~= nil
    and t:find('No cumplir un drive-through en 2 vueltas: descalificacion', 1, true) ~= nil
''')


# ---------------------------------------------------------------- 1.5.1: salida lanzada offline con IA
SHORT_AI = '''
  T.cfg.startMode = 2; T.cfg.formShort = true; T.physicsAllowed = true; T.sim.carsCount = 3
  T.cars[0].racePosition = 2; T.cars[1].racePosition = 1; T.cars[2].racePosition = 3
  newSession(); T.cars[0].racePosition = 2; T.cars[1].racePosition = 1; T.cars[2].racePosition = 3
'''

scenario('offline, salida corta: los autos van a la fila durante la cuenta regresiva y el jugador espera sin controles', SHORT_AI + '''
  T.sim.isSessionStarted = false; T.sim.timeToSessionStart = 15000
  for i = 0, 2 do T.cars[i].splinePosition = 0.98 end
  run(1)
  local waits = #T.teleports == 0
  run(1)
  local z = {}
  for _, t in ipairs(T.teleports) do z[t.i] = t.z end
  local placed = #T.teleports == 3 and math.abs(z[1] - 3000) < 1 and math.abs(z[0] - 2990) < 1 and math.abs(z[2] - 2980) < 1
    and T.noInput == true
  run(10)
  T.sim.isSessionStarted = true; T.sim.timeToSessionStart = -100; run(1)
  return waits and placed and #T.teleports == 3 and T.noInput == false
    and lastMsg():find('SALIDA LANZADA | Manten tu puesto', 1, true) ~= nil and not logText():find('ERROR')
''')

scenario('offline, salida corta: sin permiso de la pista no se mueve a nadie ni se bloquean los controles en la cuenta regresiva', SHORT_AI + '''
  T.physicsAllowed = false
  T.sim.isSessionStarted = false; T.sim.timeToSessionStart = 15000
  run(5)
  return #T.teleports == 0 and T.noInput ~= true
''')

scenario('offline, formacion: la IA anda al ritmo del auto que tiene delante y no adelanta', SHORT_AI + '''
  T.sim.timeToSessionStart = -100; run(0.5)
  -- fila: 1 (IA), 0 (tu), 2 (IA). Tu vas lento a 50 km/h; la IA de atras queda pegada a 8 m
  place(1, 3000, 100); place(0, 2990, 50); place(2, 2982, 100); run(1)
  local tight = last(T.aiCaps[2]) < 50
  place(2, 2950, 100); run(1)                              -- 40 m detras: puede acercarse
  local free = last(T.aiCaps[2]) == 100
  place(2, 2995, 60); run(1)                               -- se te puso delante: frena para que vuelvas a pasar
  local back = last(T.aiCaps[2]) == 30
  return tight and free and back and last(T.aiCaps[1]) == 100
''')

scenario('offline, salida corta: despues de la verde la IA sigue limitada hasta cruzar la meta', SHORT_AI + '''
  T.sim.timeToSessionStart = -100; run(0.5)
  place(1, 3300, 100); place(0, 3290, 100); place(2, 3280, 100); run(2)
  place(1, 3420, 100); place(0, 3410, 100); place(2, 3400, 100); run(0.5)
  -- con la verde el primero de la fila queda libre; el de atras sigue sin poder pasarte hasta la meta
  local green = lastMsg():find('BANDERA VERDE') ~= nil and last(T.aiCaps[1]) == math.huge and last(T.aiCaps[2]) < 100
  T.cars[2].splinePosition = 0.995; run(0.3); T.cars[2].splinePosition = 0.005; run(0.5)
  return green and last(T.aiCaps[2]) == math.huge
''')

scenario('offline, salida corta: con la verde la IA de delante acelera junto contigo y no te obliga a pasarla antes de la meta', SHORT_AI + '''
  T.cars[0].racePosition = 3; T.cars[1].racePosition = 1; T.cars[2].racePosition = 2
  newSession(); T.cars[0].racePosition = 3; T.cars[1].racePosition = 1; T.cars[2].racePosition = 2
  T.sim.timeToSessionStart = -100; run(0.5)
  -- fila: 1 (IA), 2 (IA), 0 (tu)
  place(1, 3300, 100); place(2, 3290, 100); place(0, 3280, 100); run(2)
  place(1, 3420, 100); place(2, 3410, 100); place(0, 3400, 100); run(0.5)
  -- verde: el primero se va a 160 y el segundo puede seguirlo por encima del limite de la formacion
  place(1, 3440, 160); place(2, 3425, 150); place(0, 3412, 150); run(0.5)
  return lastMsg():find('BANDERA VERDE') ~= nil and last(T.aiCaps[1]) == math.huge and last(T.aiCaps[2]) > 150
    and msgCount('DEVUELVE') == 0
''')

scenario('salida corta: al cruzar la meta no salta la bandera azul aunque el contador de vueltas no coincida', FL + '''
  T.cfg.startMode = 2; T.cfg.formShort = true; T.physicsAllowed = true; T.sim.carsCount = 2
  T.cars[0].racePosition = 2; T.cars[1].racePosition = 1
  newSession(); T.cars[0].racePosition = 2; T.cars[1].racePosition = 1
  T.sim.isSessionStarted = false; T.sim.timeToSessionStart = 15000
  T.cars[0].splinePosition = 0.985; T.cars[1].splinePosition = 0.99; run(3)
  T.sim.isSessionStarted = true; T.sim.timeToSessionStart = -20000; run(1)
  -- ruedan hasta la meta; el juego cuenta la vuelta del otro pero no la tuya
  for k = 1, 60 do
    T.cars[1].splinePosition = (T.cars[1].splinePosition + 0.002) % 1
    T.cars[0].splinePosition = (T.cars[0].splinePosition + 0.002) % 1
    T.cars[1].speedKmh, T.cars[0].speedKmh = 150, 150
    run(1 / 60)
  end
  T.cars[1].lapCount = 1
  place(1, T.cars[0].position.z - 15, 200); T.cars[1].splinePosition = T.cars[0].splinePosition - 15 / 5000; run(2)
  return msgCount('BANDERA AZUL') == 0
''')

scenario('carrera reiniciada desde el menu: se borran sanciones y contadores aunque el juego no avise', '''
  local c = place(0, 0, 150)
  c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(5)
  local had = screen():find('INC 0x') == nil and hudScreen():find('INC 1x') ~= nil
  T.sim.isSessionStarted = false; T.sim.timeToSessionStart = 15000; run(1)
  return had and hudScreen():find('INC 0x') ~= nil
''')


# ---------------------------------------------------------------- 1.5.3: fila doble
TWO = '''
  T.cfg.startMode = 2; T.cfg.formShort = true; T.cfg.formTwoWide = true; T.physicsAllowed = true; T.sim.carsCount = 3
  T.cars[0].racePosition = 2; T.cars[1].racePosition = 1; T.cars[2].racePosition = 3
  newSession(); T.cars[0].racePosition = 2; T.cars[1].racePosition = 1; T.cars[2].racePosition = 3
'''

scenario('fila doble: 1 y 2 lado a lado a 500 m de la meta, el 3 en la fila siguiente, todos mirando hacia adelante', TWO + '''
  T.sim.timeToSessionStart = -100
  for i = 0, 2 do T.cars[i].splinePosition = 0.98 end
  run(0.5)
  local p = {}
  local facing = true
  for _, t in ipairs(T.teleports) do
    p[t.i] = T.cars[t.i].position
    if math.abs(t.dir.z + 1) > 0.001 then facing = false end
  end
  return facing and #T.teleports == 3
    and math.abs(p[1].z - 3000) < 0.5 and math.abs(p[0].z - 3000) < 0.5 and math.abs(p[2].z - 2988) < 0.5
    and math.abs(p[1].x - p[0].x) > 4.5 and math.abs(p[1].x - p[2].x) < 0.5 and math.abs(p[1].x) < 3 and math.abs(p[0].x) < 3
''')

scenario('fila doble sin el ancho de la pista: toda la fila va en una columna a 10 m, sin salirse de la linea', TWO + '''
  T.noSides = true; T.cfg.writeLog = true; T.sim.isSessionStarted = false; T.sim.timeToSessionStart = 15000
  for i = 0, 2 do T.cars[i].splinePosition = 0.98 end
  run(6)
  local p = {}
  for _, t in ipairs(T.teleports) do p[t.i] = T.cars[t.i].position end
  return math.abs(p[1].z - 3000) < 0.5 and math.abs(p[0].z - 2990) < 0.5 and math.abs(p[2].z - 2980) < 0.5
    and p[0].x == 0 and p[1].x == 0 and logText():find('una fila', 1, true) ~= nil and not logText():find('ERROR')
''')

scenario('fila doble en una pista angosta (7 m): una sola columna', TWO + '''
  T.sides = vec2(3.5, 3.5); T.sim.isSessionStarted = false; T.sim.timeToSessionStart = 15000
  for i = 0, 2 do T.cars[i].splinePosition = 0.98 end
  run(2)
  return T.cars[0].position.x == 0 and T.cars[1].position.x == 0 and math.abs(T.cars[0].position.z - 2990) < 0.5
''')

scenario('fila doble con un muro o desnivel al lado: no se pone un auto ahi, una sola columna', TWO + '''
  T.groundD = 0.5; T.sim.isSessionStarted = false; T.sim.timeToSessionStart = 15000
  for i = 0, 2 do T.cars[i].splinePosition = 0.98 end
  run(2)
  return T.cars[0].position.x == 0 and T.cars[1].position.x == 0 and math.abs(T.cars[2].position.z - 2980) < 0.5
''')

scenario('fila doble: cada auto movido se despierta en el motor de fisica', TWO + '''
  T.sim.isSessionStarted = false; T.sim.timeToSessionStart = 15000
  for i = 0, 2 do T.cars[i].splinePosition = 0.98 end
  run(2)
  return T.awake and T.awake[0] and T.awake[1] and T.awake[2] and math.abs(T.cars[0].position.x - T.cars[1].position.x) > 4.5
''')

scenario('formacion: si la IA no arranca se la despierta, despues se arma una sola fila y al final se la suelta', TWO + '''
  T.sim.carsCount = 4
  newSession(); T.cars[3] = T.newCar(3); T.cars[0].racePosition = 3; T.cars[1].racePosition = 1; T.cars[2].racePosition = 2; T.cars[3].racePosition = 4
  T.cfg.writeLog = true; T.sim.isSessionStarted = false; T.sim.timeToSessionStart = 15000
  for i = 0, 3 do T.cars[i].splinePosition = 0.98 end
  run(2)
  T.sim.isSessionStarted = true; T.sim.timeToSessionStart = -100
  T.awake = {}
  run(4)                                                    -- nadie se mueve
  local woke = (T.awake[1] or 0) >= 1
  local beside = math.abs(T.cars[1].position.x - T.cars[2].position.x) > 4.5
  run(2.5)
  local single = T.cars[1].position.x == 0 and T.cars[2].position.x == 0 and math.abs(T.cars[2].position.z - 2990) < 0.5
    and math.abs(T.cars[0].position.z - 2980) < 0.5 and msgCount('una sola fila') + (screen():find('una sola fila', 1, true) and 1 or 0) >= 0
  run(4.5)
  return woke and beside and single and last(T.aiCaps[1]) == math.huge and last(T.aiCaps[3]) == math.huge
    and lastMsg():find('BANDERA VERDE') == nil and not logText():find('ERROR')
    and logText():find('se despierta a la IA', 1, true) ~= nil and logText():find('se arma una sola fila', 1, true) ~= nil
''')

scenario('formacion: la IA que avanza no activa la vigilancia', TWO + '''
  T.cfg.writeLog = true; T.sim.timeToSessionStart = -100; run(0.5)
  for k = 1, 40 do
    place(1, 3000 + k * 4, 50, 2.6); place(0, 3000 + k * 4, 50, -2.6); place(2, 2988 + k * 4, 50, 2.6); run(0.25)
  end
  return not logText():find('no arranca', 1, true) and T.cars[1].position.x ~= 0
''')

scenario('formacion: un auto retirado que el juego manda a pits no hace salir la verde', TWO + '''
  T.sim.timeToSessionStart = -100; run(0.5)
  place(1, 3000, 50, 2.6); place(0, 3000, 50, -2.6); place(2, 2988, 50, 2.6); run(3)
  -- el 2 se retira: el juego lo pone en su box, pasado la meta y detenido
  T.cars[2].isInPit = true; T.cars[2].isInPitlane = true; T.cars[2].speedKmh = 0; T.cars[2].splinePosition = 0.02; run(2)
  return lastMsg():find('BANDERA VERDE') == nil
''')

scenario('fila doble: quedar unos metros detras del que larga a tu lado no es adelantamiento', TWO + '''
  T.sim.timeToSessionStart = -100; run(0.5)
  place(1, 3200, 60, -2.6); place(0, 3205, 60, 2.6); place(2, 3188, 60, -2.6); run(5)
  return msgCount('DEVUELVE') == 0
''')

scenario('fila doble: la IA de al lado se mantiene a tu altura y la de atras sigue a la de su columna', TWO + '''
  T.sim.carsCount = 4
  newSession(); T.cars[3] = T.newCar(3); T.cars[0].racePosition = 1; T.cars[1].racePosition = 2; T.cars[2].racePosition = 3; T.cars[3].racePosition = 4
  T.sim.timeToSessionStart = -100; run(0.5)
  -- fila: 0 (tu) y 1 a tu lado; 2 detras de ti y 3 detras de 1. Vas a 50
  place(0, 3200, 50, -2.6); place(1, 3200, 100, 2.6); place(2, 3188, 100, -2.6); place(3, 3170, 100, 2.6); run(1)
  local beside = last(T.aiCaps[1]) <= 51 and last(T.aiCaps[1]) >= 45
  local behind = last(T.aiCaps[2]) < 50
  local column = last(T.aiCaps[3]) > 60                    -- 30 m detras de su auto de referencia: puede acercarse
  return beside and behind and column
''')

scenario('con la verde, la IA que larga delante de ti queda libre y la de atras no puede pasarte hasta la meta', TWO + '''
  T.cars[0].racePosition = 3; T.cars[1].racePosition = 1; T.cars[2].racePosition = 2
  T.sim.carsCount = 4
  newSession(); T.cars[3] = T.newCar(3); T.cars[0].racePosition = 3; T.cars[1].racePosition = 1; T.cars[2].racePosition = 2; T.cars[3].racePosition = 4
  T.sim.timeToSessionStart = -100; run(0.5)
  place(1, 3300, 100, -2.6); place(2, 3300, 100, 2.6); place(0, 3288, 100, -2.6); place(3, 3288, 100, 2.6); run(2)
  place(1, 3420, 100, -2.6); place(2, 3420, 100, 2.6); place(0, 3408, 100, -2.6); place(3, 3408, 100, 2.6); run(0.5)
  local green = lastMsg():find('BANDERA VERDE') ~= nil
  return green and last(T.aiCaps[1]) == math.huge and last(T.aiCaps[2]) == math.huge and last(T.aiCaps[3]) ~= math.huge
''')

fails = 0
for name, ok, err in results:
    print(('OK    ' if ok else 'FALLA ') + name + (('\n        -> ' + err) if err else ''))
    fails += 0 if ok else 1
print('\n%d de %d pruebas correctas' % (len(results) - fails, len(results)))
sys.exit(1 if fails else 0)
