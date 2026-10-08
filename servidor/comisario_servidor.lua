--[[
  COMISARIO SERVIDOR 1.10  -  script online para Assetto Corsa (Custom Shaders Patch)

  El servidor le envia este archivo a cada piloto al conectarse. No hay que instalarlo.
  Impone la salida lanzada a todos, tengan o no la app Comisario:
    - La primera vuelta de la carrera es de formacion.
    - Durante la formacion el auto no puede pasar de la velocidad fijada: al superarla,
      el script suelta el acelerador por el piloto, igual que un limitador de pits.
    - Cuando al primer auto le faltan 100 metros para la meta, sale la bandera verde y el limite
      desaparece, para que el auto ya este libre al cruzarla.

  Tambien hace cumplir la amarilla total y la bandera roja que decreta el director de carrera
  desde la app Comisario: mientras duren, el auto no puede pasar de la velocidad que el fije.

  Salida lanzada corta (startMeters):
    - En vez de dar una vuelta completa de formacion, cada auto es llevado a la ultima parte
      de la pista, en fila y en el orden de la grilla, a "startMeters" metros de la meta el primero.
    - El traslado se hace apenas carga la carrera, durante la cuenta regresiva: el auto espera las luces
      en la fila, con los controles bloqueados. Si el juego no lo permite, se hace al apagarse las luces.
    - Desde ahi ruedan a la velocidad de formacion hasta la bandera verde. No hay que sumar una vuelta.

  Tipo de salida:
    - Si el piloto tiene la app Comisario, vale el tipo de salida elegido en la app
      (el del director de carrera, si hay uno).
    - Si no tiene la app, vale rollingStart de aqui abajo.
    - Con lockStart = 1 manda siempre rollingStart, diga lo que diga la app.

  Administrador (adminPass):
    - Si el servidor tiene una clave, solo el piloto que la escriba en su app Comisario puede fijar
      el reglamento, el tipo de salida y las banderas. Los demas no pueden cambiarlos.
    - Con requireApp = 1, quien no tenga la app activa queda limitado a 60 km/h.
    - Un piloto descalificado por la app es enviado a pits y su auto queda sin controles hasta el final.

  Velocidad de la formacion:
    - Si el piloto tiene la app Comisario, vale la velocidad puesta en la app
      (la del director de carrera, si hay uno).
    - Si no tiene la app, vale formationSpeed de aqui abajo.

  Ajustes, en las opciones extra de CSP del servidor:

    [SCRIPT_...]
    SCRIPT = 'direccion web de este archivo'
    rollingStart = 1         ; 1 = salida lanzada, 0 = salida parada normal
    lockStart = 0            ; 1 = el servidor impone rollingStart y la app no puede cambiarlo
    formationSpeed = 100     ; velocidad maxima en la formacion, en km/h
    greenMeters = 100        ; la verde sale cuando al lider le faltan estos metros para la meta (0 = en la meta)
    startMeters = 0          ; salida lanzada corta: metros antes de la meta donde parte el primero (0 = vuelta completa)
    adminPass = ''           ; clave de administrador (vacia = sin administrador: manda quien se marque director)
    requireApp = 0           ; 1 = sin la app Comisario activa, el auto no pasa de 60 km/h
    language = 'es'          ; idioma de los mensajes de este script: 'es' = espanol, 'en' = ingles

  Codigo propio, escrito desde cero.
]]

local settings = ac.configValues({ rollingStart = 1, lockStart = 0, formationSpeed = 100, greenMeters = 100, startMeters = 0,
  adminPass = '', requireApp = 0, language = 'es' })
local baseRolling = (tonumber(settings.rollingStart) or 1) ~= 0
local lockStart = (tonumber(settings.lockStart) or 0) ~= 0
local rolling = baseRolling
local baseLimit = math.max(40, math.min(250, tonumber(settings.formationSpeed) or 100))
local limit = baseLimit
local baseGreen = math.max(0, math.min(250, tonumber(settings.greenMeters) or 100))
local greenMeters = baseGreen
local requireApp = (tonumber(settings.requireApp) or 0) ~= 0
local baseStart = math.max(0, math.min(3000, tonumber(settings.startMeters) or 0))
local startMeters = baseStart
local GRID_GAP = 10      -- metros entre un auto y el siguiente en la fila de la salida corta
local NO_APP_SPEED = 60

-- Huella numerica de la clave de administrador (la misma cuenta que hace la app). 0 = sin administrador.
local function hashKey(text)
  local h = 5381
  text = tostring(text or '')
  for n = 1, #text do h = (h * 33 + text:byte(n)) % 4294967296 end
  return h == 0 and 1 or h
end
local adminPass = tostring(settings.adminPass or '')
local auth = adminPass ~= '' and hashKey(adminPass) or 0

-- Enlace con la app Comisario del mismo piloto. No esta documentado en que "espacio" quedan
-- los datos de un script de servidor, asi que se prueban los tres posibles y se usa el que responda.
local links = {}
do
  local I = ac.StructItem
  local spaces = { false }
  pcall(function ()
    spaces[#spaces + 1] = ac.SharedNamespace.ServerScript
    spaces[#spaces + 1] = ac.SharedNamespace.Shared
  end)
  for _, space in ipairs(spaces) do
    pcall(function ()
      local layout = { I.key('comisario:enlace:7'), srvMode = I.byte(), srvSpeed = I.byte(), srvTick = I.uint16(),
        srvAuth = I.uint32(), appMode = I.byte(), appSpeed = I.byte(), appLimit = I.byte(), appGreen = I.byte(),
        appOn = I.byte(), appDq = I.byte(), appStart = I.uint16(), appTick = I.uint16() }
      local l
      if space then l = ac.connect(layout, true, space) else l = ac.connect(layout) end
      if l then links[#links + 1] = { data = l, appTick = -1, appSeen = -100 } end
    end)
  end
end

local phase = 'idle'   -- idle = sin carrera, formation = vuelta de formacion, green = carrera lanzada
local tick = 0
local now = 0
local midLap = {}      -- autos que ya pasaron por la mitad de la vuelta de formacion
local controlLimit = 0 -- amarilla total, bandera roja o descalificacion decretada en la app: velocidad maxima (0 = no hay)
local appActive = false -- la app Comisario del piloto esta abierta y activa
local nagAt = -100
local appDq = false     -- la app descalifico a este piloto
local inputLocked = false -- los controles del auto estan bloqueados por descalificacion
local dqAt = nil        -- cuando se le envio a pits por ultima vez
local startedAt = 0     -- momento en que largo la carrera (para la salida corta)
-- cuenta regresiva de la carrera: en la salida corta el auto va a la fila apenas carga la carrera
local preAt = nil       -- desde cuando se esta en la cuenta regresiva
local prePlaced = false -- el auto ya fue llevado a la fila durante la cuenta regresiva
local preFailed = false -- el juego no dejo moverlo: se intentara al largar, como antes
local preLocked = false -- controles bloqueados mientras espera las luces
local preFixes = 0      -- veces que se le devolvio a su lugar por haberse movido
local preFixAt = 0
local gridPos, gridDir = nil, nil  -- donde estaba en la grilla, por si se cambia a salida parada

-- Mensajes en ingles (language = 'en'). La clave es el texto en espanol; los %s son huecos para numeros.
local EN = {
  ['COMISARIO SERVIDOR %s'] = 'COMISARIO SERVER %s',
  ['Script del servidor cargado'] = 'Server script loaded',
  ['COMISARIO OBLIGATORIO'] = 'COMISARIO REQUIRED',
  ['Abre y activa la app Comisario: sin ella no pasas de %s km/h'] = 'Open and enable the Comisario app: without it you cannot go over %s km/h',
  ['DESCALIFICADO'] = 'DISQUALIFIED',
  ['Fuiste enviado a pits. No puedes volver a la carrera'] = 'You were sent to the pits. You cannot rejoin the race',
  ['SALIDA LANZADA'] = 'ROLLING START',
  ['VUELTA DE FORMACION'] = 'FORMATION LAP',
  ['Espera las luces. Despues, maximo %s km/h hasta la bandera verde'] = 'Wait for the lights. Then, maximum %s km/h until the green flag',
  ['Maximo %s km/h. Manten tu puesto hasta la bandera verde'] = 'Maximum %s km/h. Hold your position until the green flag',
  ['BANDERA VERDE'] = 'GREEN FLAG',
  ['Carrera lanzada'] = 'Race is on',
}
local english = tostring(settings.language or 'es'):lower():sub(1, 2) == 'en'
local function tr(text, ...)
  if english then text = EN[text] or text end
  if select('#', ...) == 0 then return text end
  return string.format(text, ...)
end

local function show(title, text)
  pcall(function () ac.setMessage(title, text) end)
end

-- Deja escrito lo que impone el servidor y lee la velocidad que pide la app.
local function syncApp()
  tick = (tick + 1) % 60000
  local appSpeed, appLimit, appGreen, appMode, appOn, dq, appStart = nil, 0, nil, 0, false, false, nil
  for _, l in ipairs(links) do
    pcall(function ()
      -- 0 = la app elige el tipo de salida; 1 o 2 = el servidor lo impone
      l.data.srvMode = lockStart and (baseRolling and 2 or 1) or 0
      l.data.srvSpeed = baseLimit
      l.data.srvAuth = auth
      l.data.srvTick = tick
      local t = l.data.appTick
      if l.appTick == -1 then
        l.appTick = t            -- primera lectura: todavia no se sabe si la app esta
      elseif t ~= l.appTick then
        l.appTick = t
        l.appSeen = now
      end
      if now - l.appSeen < 3 then
        if l.data.appSpeed >= 40 then appSpeed = l.data.appSpeed end
        if l.data.appLimit >= 30 then appLimit = l.data.appLimit end
        appGreen = l.data.appGreen
        appMode = l.data.appMode
        if l.data.appOn == 1 then appOn = true end
        if l.data.appDq == 1 then dq = true end
        appStart = l.data.appStart
      end
    end)
  end
  limit = appSpeed or baseLimit
  controlLimit = appLimit
  greenMeters = appGreen or baseGreen
  appActive = appOn
  appDq = dq
  startMeters = appStart or baseStart
  if lockStart or (appMode ~= 1 and appMode ~= 2) then
    rolling = baseRolling
  else
    rolling = appMode == 2
  end
end

-- Envia el auto a su box. Se prueban las dos formas que ofrece el juego.
local function toPits()
  local ok = pcall(function () physics.teleportCarTo(0, ac.SpawnSet.Pits) end)
  if not ok then pcall(function () ac.tryToTeleportToPits() end) end
end

-- Salida lanzada corta: lleva el auto a su lugar en la fila, antes de la ultima parte de la pista.
-- Devuelve la posicion en la pista (0 a 1) donde quedo, o nil si no se pudo.
local function formationSpot(car, len)
  -- lugar en la fila: cuantos autos conectados largan delante de este, mas uno
  -- (el puesto de grilla del juego cuenta tambien los cupos vacios del servidor)
  local slot = 1
  local sim = ac.getSim()
  for i = 1, sim.carsCount - 1 do
    local c = ac.getCar(i)
    if c and c.isConnected ~= false and (c.racePosition or 999) < (car.racePosition or 1) then slot = slot + 1 end
  end
  local meters = math.max(startMeters, greenMeters + 100) + (slot - 1) * GRID_GAP
  local sp = 1 - meters / len
  if sp < 0.05 then return nil end
  return sp
end

local function toFormation(car, len)
  local sp = formationSpot(car, len)
  if not sp then return nil end
  local ok = pcall(function ()
    local a = ac.trackProgressToWorldCoordinate(sp)
    local b = ac.trackProgressToWorldCoordinate(sp + 2 / len)
    local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
    local d = math.sqrt(dx * dx + dy * dy + dz * dz)
    if d < 0.001 then error('sin direccion') end
    -- el juego espera la direccion al reves: hacia donde apunta la cola del auto
    physics.setCarPosition(0, vec3(a.x, a.y + 0.2, a.z), vec3(-dx / d, -dy / d, -dz / d))
  end)
  return ok and sp or nil
end

-- por encima de la velocidad dada se suelta el acelerador un instante, como un limitador de pits
local function cap(car, kmh)
  if car.speedKmh > kmh and not car.isInPitlane then
    pcall(function () physics.forceUserThrottleFor(0.1, 0) end)
  end
end

local function releasePre()
  if preLocked then
    preLocked = false
    pcall(function () physics.setCarNoInput(false) end)
  end
end

local SCRIPT_VERSION = '1.10'
local versionShown = false

function script.update(dt)
  local sim = ac.getSim()
  local car = ac.getCar(0)
  now = now + dt
  syncApp()
  -- al entrar al servidor se avisa que version del script esta cargada (sirve para comprobar el enlace del gist)
  if not versionShown and now > 3 then
    versionShown = true
    pcall(function () ac.log('Comisario servidor ' .. SCRIPT_VERSION .. ' cargado') end)
    -- en plena carrera no se muestra, para no tapar los avisos de la largada
    if sim.raceSessionType ~= ac.SessionType.Race then
      show(tr('COMISARIO SERVIDOR %s', SCRIPT_VERSION), tr('Script del servidor cargado'))
    end
  end

  if not car then return end
  -- amarilla total o roja: vale en cualquier sesion ya iniciada
  if controlLimit > 0 and sim.isSessionStarted then cap(car, controlLimit) end

  -- app obligatoria: se dan 30 segundos al entrar para que cargue
  if requireApp and not appActive and now > 30 and sim.isSessionStarted then
    cap(car, NO_APP_SPEED)
    if now - nagAt > 20 then
      nagAt = now
      show(tr('COMISARIO OBLIGATORIO'), tr('Abre y activa la app Comisario: sin ella no pasas de %s km/h', NO_APP_SPEED))
    end
  end

  -- descalificado: se le envia a pits, y de nuevo cada vez que vuelva a salir a la pista
  if appDq and sim.isSessionStarted then
    if not dqAt or (not car.isInPitlane and now - dqAt > 6) then
      dqAt = now
      toPits()
      show(tr('DESCALIFICADO'), tr('Fuiste enviado a pits. No puedes volver a la carrera'))
    end
    -- en pits, el auto queda sin controles: no puede acelerar ni moverse
    if not inputLocked and now - dqAt > 0.5 then
      inputLocked = true
      pcall(function () physics.setCarNoInput(true) end)
    end
  else
    dqAt = nil
    if inputLocked then
      inputLocked = false
      pcall(function () physics.setCarNoInput(false) end)
    end
  end

  local len = (sim.trackLengthM and sim.trackLengthM > 100) and sim.trackLengthM or 4000
  local short = startMeters > 0

  -- Cuenta regresiva de la carrera. Con salida corta el auto va a la fila de inmediato, sin esperar
  -- a que se apaguen las luces en la grilla, y espera ahi con los controles bloqueados.
  if sim.raceSessionType ~= ac.SessionType.Race then
    releasePre()
    preAt, prePlaced, preFailed, preFixes, gridPos = nil, false, false, 0, nil
  elseif not sim.isSessionStarted then
    if phase ~= 'idle' then
      -- la carrera se reinicio: se empieza de nuevo
      preAt, prePlaced, preFailed, preFixes, gridPos = nil, false, false, 0, nil
    end
    if rolling and short and not appDq then
      preAt = preAt or now
      if not prePlaced and not preFailed and now - preAt > 1.5 then
        pcall(function ()
          gridPos = vec3(car.position.x, car.position.y, car.position.z)
          gridDir = vec3(car.look.x, car.look.y, car.look.z)
        end)
        if toFormation(car, len) then
          prePlaced = true
          preFixAt = now
          preLocked = true
          pcall(function () physics.setCarNoInput(true) end)
          show(tr('SALIDA LANZADA'), tr('Espera las luces. Despues, maximo %s km/h hasta la bandera verde', limit))
        else
          preFailed = true
        end
      elseif prePlaced and preFixes < 5 and now - preFixAt > 2 then
        -- si el auto se fue rodando (pendiente) o el juego lo devolvio a la grilla, se le vuelve a poner
        local spot = formationSpot(car, len)
        if spot and math.abs(car.splinePosition - spot) * len > 3 then
          preFixes = preFixes + 1
          preFixAt = now
          toFormation(car, len)
        end
      end
    elseif prePlaced then
      -- se cambio a salida parada durante la cuenta regresiva: de vuelta a la grilla
      releasePre()
      if gridPos and gridDir then
        pcall(function () physics.setCarPosition(0, gridPos, vec3(-gridDir.x, -gridDir.y, -gridDir.z)) end)
      end
      preAt, prePlaced, preFixes = nil, false, 0
    end
  else
    releasePre()
  end

  if not rolling then return end
  if sim.raceSessionType ~= ac.SessionType.Race or not sim.isSessionStarted then
    phase = 'idle'
    midLap = {}
    return
  end
  -- una vez dada la bandera verde, la largada termino: no se vuelve a la formacion en esta carrera
  if phase == 'green' then return end
  -- si el script se carga con la carrera ya en marcha (alguien que entra tarde), no hay formacion
  if phase == 'idle' and sim.timeToSessionStart < -4000 then
    phase = 'green'
    return
  end

  -- La formacion termina cuando cualquier auto llega a la meta. Se mira la posicion en la pista
  -- (el contador de vueltas del juego puede llegar con retraso) y, por si acaso, tambien el contador.
  -- La verde sale unos metros antes de la meta: asi el acelerador ya esta libre al cruzarla.
  local early = greenMeters > 0 and (1 - greenMeters / len) or 2
  local crossed = false
  for i = 0, sim.carsCount - 1 do
    local c = ac.getCar(i)
    if c then
      local sp = c.splinePosition
      if short then
        -- salida corta: cuenta el auto que ya esta en la fila (despues del teletransporte), antes del punto de la verde
        if now - startedAt > 1.5 and sp < early and sp < 0.999 and sp > 1 - (math.max(startMeters, greenMeters + 100) + 400) / len then
          midLap[i] = true
        end
      elseif sp > 0.4 and sp < 0.7 then
        midLap[i] = true
      end
      if c.lapCount >= 1 or (midLap[i] and (sp < 0.15 or sp >= early)) then
        crossed = true
        break
      end
    end
  end

  if crossed then
    if phase == 'formation' then
      phase = 'green'
      show(tr('BANDERA VERDE'), tr('Carrera lanzada'))
    end
    return
  end

  if phase ~= 'formation' then
    phase = 'formation'
    startedAt = now
    midLap = {}
    if short and not appDq then
      -- si ya espero las luces en su lugar de la fila, no se le mueve de nuevo
      local spot = prePlaced and formationSpot(car, len) or nil
      if not (spot and math.abs(car.splinePosition - spot) * len < 8) then toFormation(car, len) end
    end
    preAt, prePlaced, preFailed, preFixes, gridPos = nil, false, false, 0, nil
    show(short and tr('SALIDA LANZADA') or tr('VUELTA DE FORMACION'), tr('Maximo %s km/h. Manten tu puesto hasta la bandera verde', limit))
  end

  cap(car, limit)
end
