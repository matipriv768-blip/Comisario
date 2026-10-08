-- Simulador minimo de la API de CSP para probar la logica de Comisario fuera del juego.
local APP = ...

-- las pruebas comparan texto sin tildes
local FOLD = { ['\195\161'] = 'a', ['\195\169'] = 'e', ['\195\173'] = 'i', ['\195\179'] = 'o', ['\195\186'] = 'u', ['\195\177'] = 'n',
  ['\195\129'] = 'A', ['\195\137'] = 'E', ['\195\141'] = 'I', ['\195\147'] = 'O', ['\195\154'] = 'U', ['\195\145'] = 'N' }
function fold(text) return (tostring(text):gsub('\195[\128-\191]', FOLD)) end

-- vectores y colores -------------------------------------------------------
local V3 = {}
V3.__index = V3
function vec3(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, V3) end
function V3:distance(o) return math.sqrt((self.x - o.x) ^ 2 + (self.y - o.y) ^ 2 + (self.z - o.z) ^ 2) end
local V2 = {}
V2.__index = V2
V2.__add = function (a, b) return vec2(a.x + (type(b) == 'number' and b or b.x), a.y + (type(b) == 'number' and b or b.y)) end
function vec2(x, y) return setmetatable({ x = x or 0, y = y or 0 }, V2) end
function rgbm(r, g, b, m) return { r = r, g = g, b = b, mult = m } end

-- estado simulado -----------------------------------------------------------
T = {}                      -- lo que el test manipula
T.messages = {}             -- mensajes del juego (ac.setMessage)
T.saved = {}                -- archivos guardados
T.uiCalls = 0
T.texts = {}
T.physicsAllowed = false
T.forcedCuts = {}
T.throttle = {}             -- limites de acelerador puestos a la IA: T.throttle[i] = { 0, 0, 1 }
T.pitReq = {}               -- pedidos de entrada a pits
T.aiCaps = {}               -- limites de velocidad puestos a la IA
T.files = {}                -- archivos del "disco"
T.windows = {}              -- ventanas abiertas con ac.setWindowOpen
T.layout = ''
T.time = 0
T.aiCapFail = false
T.sessionLaps = 5
T.released = {}
T.images = {}               -- imagenes dibujadas con ui.drawImage
T.imageRects = {}           -- lo mismo, con el rectangulo donde se dibujo cada una
T.labels = {}               -- textos de casillas, opciones, botones y deslizadores
T.calls = {}                -- cuantas veces se llamo a cada funcion de dibujo
T.textPos = {}              -- donde se dibujo cada texto por ultima vez

local function newCar(i)
  return {
    index = i, wheelsOutside = 0, isInPitlane = false, isInPit = false, speedKmh = 0, gas = 0,
    lapCount = 0, splinePosition = 0, collidedWith = -1, position = vec3(0, 0, 0),
    isRaceFinished = false, racePosition = i + 1, sessionID = i, isConnected = true,
    velocity = vec3(0, 0, 0), look = vec3(0, 0, 1), collisionDepth = 0, bestLapTimeMs = 90000, previousLapTimeMs = 0,
  }
end
T.cars = { [0] = newCar(0), [1] = newCar(1), [2] = newCar(2) }
T.newCar = newCar             -- las pruebas pueden agregar mas autos
T.cars[1].position = vec3(0, 0, 300); T.cars[2].position = vec3(0, 0, 600)
T.sim = {
  raceSessionType = 3, isSessionStarted = true, timeToSessionStart = -1000,
  isPaused = false, isReplayActive = false, isOnlineRace = false, carsCount = 3, currentSessionIndex = 0,
  trackLengthM = 5000,
}
T.sessionCallbacks = {}

ac = {
  SessionType = { Undefined = 0, Practice = 1, Qualify = 2, Race = 3, Hotlap = 4 },
  FolderID = { Logs = 7, ContentTracks = 15 },
  getTrackLayout = function () return T.layout end,
  setWindowOpen = function (id, open) T.windows[id] = open end,
  lapTimeToString = function (ms) return string.format('%d:%06.3f', math.floor(ms / 60000), (ms % 60000) / 1000) end,
  markLapAsSpoiled = function (v) T.spoiled = (T.spoiled or 0) + 1 end,
  storage = function (defaults)
    local t = {}
    for k, v in pairs(defaults) do t[k] = v end
    -- las pruebas parten con los valores base, como alguien que ya tenia la app; FRESH_INSTALL simula una actualizacion
    if t.rulesVersion ~= nil and not FRESH_INSTALL then t.rulesVersion = 99 end
    -- las pruebas antiguas se escribieron con los valores de fabrica anteriores a la 1.1
    if t.rulesVersion ~= nil and not FRESH_INSTALL then
      for k, v in pairs({ tlMinTime = 0.4, tlMinSpeed = 50, tlPenalty = 2, tlMode = 1, tlReset = false, pitLimit = 80,
        pitTolerance = 3, tiers = false, gbPenalty = 3, ctHeavyPenalty = 3, incStep = 12, dtFailSec = 30, dtFailDQ = false,
        endLaps = 0, formShort = false, hudBg = true, hudFixed = false, uiVersion = 99, formTwoWide = false }) do t[k] = v end
    end
    -- ajustes que el piloto ya tenia guardados antes de actualizar
    if STORED then for k, v in pairs(STORED) do t[k] = v end end
    -- las pruebas antiguas corren sin banderas de pista; FLAGS_ON las activa
    if t.flEnabled ~= nil and not FLAGS_ON then t.flEnabled = false end
    T.cfg = t
    return t
  end,
  getSim = function () return T.sim end,
  getUI = function () return { windowSize = vec2(T.screenW or 1920, T.screenH or 1080), uiScale = 1, dt = 0.016 } end,
  getCar = function (i) return T.cars[i] end,
  getDriverName = function (i) return (T.names and T.names[i]) or ('Piloto' .. i) end,
  getTrackID = function () return 'pista_test' end,
  getCarID = function () return 'auto_test' end,
  getFolder = function () return 'C:/logs' end,
  setMessage = function (a, b)
    if a:find('[\128-\255]') or (b or ''):find('[\128-\255]') then T.messageNotAscii = true end
    T.messages[#T.messages + 1] = a .. ' | ' .. (b or '')
  end,
  onSessionStart = function (fn) T.sessionCallbacks[#T.sessionCallbacks + 1] = fn end,
  log = function () end,
  getSession = function () return { laps = T.sessionLaps } end,
  onRelease = function (fn) T.released[#T.released + 1] = fn end,
}
io.save = function (path, data)
  if T.readOnly then return end
  T.saved[path] = data; T.files[path] = data
end
io.load = function (path) return T.files[path] end
io.fileExists = function (path) return T.files[path] ~= nil end
io.deleteFile = function (path) T.files[path] = nil end
os.preciseClock = function () T.time = T.time + 10; return T.time end
T.teleports = {}            -- autos movidos con physics.setCarPosition: { i, z }
T.pitTeleports = {}         -- autos enviados a pits
ac.SpawnSet = { Start = 'START', Pits = 'PIT' }
-- la pista de prueba es una recta de 5000 m: la posicion 0,3 de la pista esta en z = 0 (igual que place)
ac.trackProgressToWorldCoordinate = function (v) return vec3(0, 0, (v - 0.3) * 5000) end
-- ancho de la pista a cada lado de la linea de la IA: 6 m y 6 m (T.noSides simula un juego que no lo informa)
ac.getTrackAISplineSides = function (v)
  if T.noSides then error('sin datos') end
  return vec2(6, 6)
end
physics = {
  setCarPosition = function (i, pos, dir)
    if T.teleportFail then error('no permitido') end
    local c = T.cars[i]
    c.position = vec3(pos.x, pos.y, pos.z); c.velocity = vec3(0, 0, 0); c.speedKmh = 0
    c.splinePosition = 0.3 + pos.z / 5000
    c.look = vec3(-dir.x, -dir.y, -dir.z)      -- el juego recibe la direccion de la cola: el auto mira al reves de ella
    T.teleports[#T.teleports + 1] = { i = i, z = pos.z, dir = dir }
  end,
  setCarNoInput = function (v) T.noInput = v; T.noInputCalls = (T.noInputCalls or 0) + 1 end,
  teleportCarTo = function (i, set)
    if T.pitTeleportFail then error('no permitido') end
    T.cars[i].isInPitlane = true; T.cars[i].speedKmh = 0
    T.pitTeleports[#T.pitTeleports + 1] = { i = i, set = set }
  end,
  allowed = function () return T.physicsAllowed end,
  forceUserThrottleFor = function (s, v) T.forcedCuts[#T.forcedCuts + 1] = s end,
  setAIThrottleLimit = function (i, limit)
    if T.aiCapFail then error('physics no permitido') end
    T.throttle[i] = T.throttle[i] or {}
    table.insert(T.throttle[i], limit)
  end,
  setAITopSpeed = function (i, kmh)
    T.aiCaps[i] = T.aiCaps[i] or {}
    table.insert(T.aiCaps[i], kmh)
  end,
  setAIPitStopRequest = function (i, on)
    T.pitReq[i] = T.pitReq[i] or {}
    table.insert(T.pitReq[i], on)
  end,
}

-- mensajes online: se guardan en T.sent y la prueba los reparte entre los jugadores
T.events, T.sent, T.now, T.lastSend = {}, {}, 0, -100
local function item(kind, size) return { kind = kind, size = size } end
ac.StructItem = {
  key = function (k) return { key = k } end,
  byte = function () return item('u', 1) end, uint16 = function () return item('u', 2) end, uint32 = function () return item('u', 4) end,
  int16 = function () return item('i', 2) end, string = function (n) return item('s', n) end,
}
-- memoria compartida entre scripts del mismo juego (app y script del servidor)
T.shared = {}
ac.SharedNamespace = { Global = '', ServerScript = 'server_script', Shared = 'shared' }
T.linkSpaces = nil          -- si se define, solo esos espacios quedan conectados de verdad (el resto son memorias aisladas)
ac.connect = function (layout, keepLive, namespace)
  local key
  for _, v in pairs(layout) do if type(v) == 'table' and v.key then key = v.key end end
  local space = namespace or 'def'
  key = key .. '|' .. space
  if T.linkSpaces and not T.linkSpaces[space] then key = key .. '|' .. tostring(SIDE or 'x') end
  local t = T.shared[key] or {}
  for name, def in pairs(layout) do if type(def) == 'table' and def.kind and t[name] == nil then t[name] = 0 end end
  T.shared[key] = t
  return t
end
ac.configValues = function (layout) return SCRIPT_CFG or layout end
ac.OnlineEvent = function (layout, callback)
  local key
  for _, v in pairs(layout) do if type(v) == 'table' and v.key then key = v.key end end
  T.events[key] = callback
  return function (data)
    local bytes = 0
    for name, def in pairs(layout) do
      if def.kind then
        local v = data[name]
        bytes = bytes + def.size
        if v == nil then T.netViolation = 'falta el campo ' .. name
        elseif def.kind == 's' then
          if #v >= def.size then T.netViolation = 'texto mas largo que el campo' end
          if v:find('[\128-\255]') then T.netViolation = 'texto con tildes' end
        elseif v ~= math.floor(v) or v < (def.kind == 'i' and -32768 or 0) or v >= 2 ^ (8 * def.size) / (def.kind == 'i' and 2 or 1) then
          T.netViolation = 'valor fuera de rango en ' .. name .. ': ' .. tostring(v)
        end
      end
    end
    for name in pairs(data) do if not layout[name] then T.netViolation = 'campo desconocido ' .. name end end
    if bytes >= 175 then T.netViolation = 'mensaje de ' .. bytes .. ' bytes' end
    if T.now - T.lastSend < 0.2 then T.netViolation = 'dos mensajes en menos de 200 ms' end
    T.lastSend = T.now
    T.sent[#T.sent + 1] = { key = key, data = data }
    return true
  end
end

-- interfaz: todas las funciones existen y cuentan llamadas; las que devuelven valor lo hacen
local known = {
  text = 1, textColored = 1, textWrapped = 1, pushFont = 1, popFont = 1, sameLine = 1, separator = 1,
  drawRectFilled = 1, setCursor = 1, setNextItemWidth = 1,
  columns = 1, nextColumn = 1, setColumnWidth = 1,
  dwriteDrawText = 1, drawTriangleFilled = 1, drawRect = 1, pushDWriteFont = 1, popDWriteFont = 1, drawCircleFilled = 1,
  -- ventana de ajustes 1.5 (todas con uso comprobado en las apps oficiales de CSP)
  header = 1, bulletText = 1, alignTextToFramePadding = 1, offsetCursorY = 1, dummy = 1, setTooltip = 1,
  pushStyleColor = 1, popStyleColor = 1, setCursorX = 1,
}
ui = setmetatable({
  Font = { Small = 1, Title = 6 },
  getCursor = function () return vec2(0, 0) end,
  measureDWriteText = function (text, size) return vec2(#text * size * 0.5, size) end,
  availableSpaceX = function () return 380 end,
  slider = function (label, value, min, max, format)
    if type(format) == 'string' then T.labels[#T.labels + 1] = fold(format) end
    local key = label:sub(3)
    if T.setCfg and T.setCfg[key] ~= nil then return T.setCfg[key], true end
    return value, false
  end,
  checkbox = function (label, value)
    T.labels[#T.labels + 1] = fold(label)
    if T.setCfg then
      for k, v in pairs(T.setCfg) do
        if type(v) == 'boolean' and T.cfg[k] == value and v ~= value and T.checkLabel and label:find(T.checkLabel, 1, true) then return true end
      end
    end
    return T.clickAll or false
  end,
  drawImage = function (path, p1, p2)
    T.images[#T.images + 1] = path
    T.imageRects[#T.imageRects + 1] = { path = path, p1 = p1, p2 = p2 }
  end,
  -- contorno propio del juego: existe salvo que la prueba simule una version que no lo trae (NO_OUTLINE)
  beginOutline = (not NO_OUTLINE) and function () T.calls.beginOutline = (T.calls.beginOutline or 0) + 1 end or nil,
  endOutline = (not NO_OUTLINE) and function (color)
    if type(color) ~= 'table' then error('endOutline sin color') end
    T.calls.endOutline = (T.calls.endOutline or 0) + 1
  end or nil,
  InputTextFlags = { Password = 0x8000 },
  StyleColor = { Text = 0 },
  measureText = function (text) return vec2(#fold(text) * 6.6, 15) end,
  -- T.hoverAll simula el mouse encima de todo: asi se recorren todas las explicaciones
  itemHovered = function () return T.hoverAll or false end,
  -- lista desplegable: T.openCombos la abre; T.clickSelect elige la opcion con ese texto
  combo = function (label, preview, flags, content)
    if content == nil then content = flags end
    if type(preview) == 'string' then T.texts[#T.texts + 1] = fold(preview) end
    if T.openCombos or T.clickSelect then
      T.comboNow = label
      content()
      T.comboNow = nil
    end
  end,
  selectable = function (label, selected)
    T.texts[#T.texts + 1] = fold(label)
    return T.clickSelect ~= nil and T.clickSelect[1] == T.comboNow and T.clickSelect[2] == fold(label)
  end,
  inputText = function (label, str)
    if T.typeText ~= nil then return T.typeText, true, false end
    return str, false, false
  end,
  radioButton = function (label)
    T.labels[#T.labels + 1] = fold(label)
    return T.clickRadio ~= nil and fold(label):find(T.clickRadio, 1, true) == 1
  end,
  button = function (label)
    T.labels[#T.labels + 1] = fold(label)
    return T.clickButton == fold(label)
  end,
  tabBar = function (id, fn) fn() end,
  tabItem = function (label, fn)
    T.labels[#T.labels + 1] = fold(label)
    fn()
  end,
}, {
  __index = function (t, k)
    if not known[k] then error('Funcion de ui no verificada: ui.' .. tostring(k), 2) end
    return function (a, b, c)
      T.uiCalls = T.uiCalls + 1
      T.calls[k] = (T.calls[k] or 0) + 1
      if k == 'dwriteDrawText' and type(c) == 'table' then T.textPos[fold(a)] = c end
      if type(a) == 'string' and k ~= 'pushDWriteFont' then T.texts[#T.texts + 1] = fold(a) end
    end
  end,
})
script = {}

-- cargar la app --------------------------------------------------------------
local chunk, err = loadfile(APP)
if not chunk then error(err) end
chunk()

-- utilidades del test --------------------------------------------------------
function run(seconds, fn)
  local dt = 1 / 60
  local n = math.floor(seconds / dt + 0.5)
  for i = 1, n do
    if fn then fn(i * dt) end
    T.now = T.now + dt
    script.update(dt)
  end
end
function lastMsg() return T.messages[#T.messages] or '' end
function hud()
  script.windowHudMessage(0.016); script.windowHudPenalty(0.016); script.windowHudStatus(0.016); script.windowHudStart(0.016)
  if script.fullscreenUI then script.fullscreenUI(0.016) end
end
function draw() script.windowMain(0.016); script.windowSettings(0.016); script.windowStandings(0.016); hud() end
-- texto de los indicadores sueltos
function hudScreen()
  T.texts = {}
  hud()
  -- sin fondo, cada texto se dibuja varias veces (el contorno): se deja una sola
  local out = {}
  for _, t in ipairs(T.texts) do
    if out[#out] ~= t then out[#out + 1] = t end
  end
  return table.concat(out, ' | ')
end
SURFACES = 'C:/logs\\pista_test\\data\\surfaces.ini'
function last(list) return list and list[#list] end
-- coloca un auto: z = metros a lo largo de la recta, x = metros hacia el lado, kmh = velocidad hacia delante
function place(i, z, kmh, x)
  local c = T.cars[i]
  c.position = vec3(x or 0, 0, z)
  c.velocity = vec3(0, 0, kmh / 3.6)
  c.speedKmh = kmh
  c.splinePosition = 0.3 + z / 5000
  return c
end
-- golpe entre el jugador y el auto j durante unos cuadros
function hit(i, frames)
  local c = T.cars[i]
  c.collisionDepth = 0.05; run((frames or 3) / 60); c.collisionDepth = 0
end
function msgCount(pattern)
  local n = 0
  for _, m in ipairs(T.messages) do if m:find(pattern) then n = n + 1 end end
  return n
end
-- reglamentos de partida de versiones anteriores: ya no estan en la app, pero las pruebas los siguen usando
local PRESETS = {
  {
    name = 'Real Penalty',
    hint = 'Las reglas y los números de Real Penalty: solo cuenta el atajo con ventaja (si sueltas y pierdes un 10% de velocidad, no hay aviso), 3 avisos y después drive-through; pits a más de 82 km/h y salida en falso con sanción según la velocidad (drive-through, stop and go de 10 s o descalificación); 2 vueltas para cumplir o descalificación; en las últimas 3 vueltas la sanción se puede cambiar por +20 s. Real Penalty no sanciona contactos: los tuyos quedan como estén en sus pestañas.',
    values = { bfPenalty = 0, tlEnabled = true, tlMode = 2, tlWheels = 4, tlMinTime = 0.1, tlMinSpeed = 40, tlCooldown = 3, tlMaxTime = 3,
      tlSlowRatio = 90, tlPostTime = 1, tlWarnings = 3, tlPenalty = 3, tlReset = true, tlDouble = false, pitEnabled = true,
      pitLimit = 82, pitTolerance = 0, pitPenalty = 3, jumpEnabled = true, jumpPenalty = 3, tiers = true, dtLaps = 2,
      dtFailSec = 20, dtFailDQ = true, endLaps = 1, sgSec = 10 },
  },
  {
    name = 'Sanciones reales (FIA)',
    hint = 'Como en las carreras reales: 3 avisos por límites y después +5 s y +10 s; causar un choque, +10 s; ganar un puesto con un contacto o por fuera de la pista, devolverlo o drive-through; no ceder el paso con bandera azul en 20 s, +5 s; no cumplir una sanción, descalificación. Máximo 17 puntos de incidente.',
    values = { yfPass = true, yfPenalty = 3, bfPenalty = 1, bfSec = 20, tlMode = 1, tlReset = false, tiers = false, endLaps = 0, pitLimit = 80, pitTolerance = 3, tlMinTime = 0.4, tlMinSpeed = 50, dtLaps = 3, dtFailSec = 30, incEnabled = true, incSum = true, incOff = 1, incSpin = 2, incWall = 2, incContact = 2, incHeavy = 4, incStep = 0,
      incPenalty = 3, incDQ = 17, faultMode = 1, tlWarnings = 3, tlPenalty = 1, tlDouble = true, ctWarnings = 1, ctMedPenalty = 1,
      ctHeavyPenalty = 1, ctReview = true, timeSec = 5, gbEnabled = true, gbSec = 20, gbPenalty = 3, passOffEnabled = true,
      pitPenalty = 3, jumpPenalty = 3, dtFailDQ = true, sgSec = 10 },
  },
  {
    name = 'iRacing',
    hint = 'Solo puntos de incidente, sin culpa: 1x salida, 2x trompo o muro, 4x choque. Un roce no suma. Al pasar los 17 puntos, descalificación.',
    values = { yfPass = false, bfPenalty = 0, tlMode = 1, tlReset = false, tiers = false, endLaps = 0, pitLimit = 80, pitTolerance = 3, tlMinTime = 0.4, tlMinSpeed = 50, dtLaps = 3, dtFailSec = 30, incEnabled = true, incSum = false, incOff = 1, incSpin = 2, incWall = 2, incContact = 4, incHeavy = 4, incStep = 0,
      incPenalty = 3, incDQ = 17, faultMode = 2, tlPenalty = 0, tlDouble = false, ctMedPenalty = 0, ctHeavyPenalty = 0,
      ctReview = false, gbEnabled = false, passOffEnabled = false, pitPenalty = 3, jumpPenalty = 3, dtFailDQ = false },
  },
  {
    name = 'Mixto',
    hint = 'Más suave: levantar el pie por límites de pista, drive-through cada 12 puntos y tiempo si no cumples. Máximo 17 puntos.',
    values = { yfPass = true, yfPenalty = 3, bfPenalty = 0, tlMode = 1, tlReset = false, tiers = false, endLaps = 0, pitLimit = 80, pitTolerance = 3, tlMinTime = 0.4, tlMinSpeed = 50, dtLaps = 3, dtFailSec = 30, incEnabled = true, incSum = true, incOff = 1, incSpin = 2, incWall = 2, incContact = 2, incHeavy = 4, incStep = 12,
      incPenalty = 3, incDQ = 17, faultMode = 1, tlWarnings = 3, tlPenalty = 2, tlDouble = false, ctWarnings = 1, ctMedPenalty = 1,
      ctHeavyPenalty = 3, ctReview = true, timeSec = 5, gbEnabled = true, gbSec = 20, gbPenalty = 3, passOffEnabled = true,
      pitPenalty = 3, jumpPenalty = 3, dtFailDQ = false, sgSec = 10 },
  },
}

function preset(name)
  for _, p in ipairs(PRESETS) do
    if fold(p.name) == name then
      for k, v in pairs(p.values) do T.cfg[k] = v end
      return
    end
  end
  error('reglamento desconocido: ' .. name)
end
function press(label) T.clickButton = label; script.windowSettings(0.016); T.clickButton = nil end
function newSession()
  for _, fn in ipairs(T.sessionCallbacks) do fn(0, false) end
  T.cars[0] = newCar(0); T.cars[1] = newCar(1); T.cars[2] = newCar(2)
  T.cars[1].position = vec3(0, 0, 300); T.cars[2].position = vec3(0, 0, 600)
  T.messages = {}
end
function logText() return fold(T.saved['C:/logs/comisario_log.txt'] or '') end

-- texto que se ve en las ventanas (panel y clasificacion)
function screen()
  T.texts = {}
  script.windowMain(0.016); script.windowStandings(0.016)
  return table.concat(T.texts, ' | ')
end

-- golpe real contra el muro: el auto pierde velocidad de golpe
function wallHit(i, kmhBefore, kmhAfter)
  local c = T.cars[i]
  place(i, c.position.z, kmhBefore); run(3 / 60)
  c.collisionDepth = 0.05; run(2 / 60)
  place(i, c.position.z, kmhAfter); run(3 / 60)
  c.collisionDepth = 0
  place(i, c.position.z, kmhBefore)
end
