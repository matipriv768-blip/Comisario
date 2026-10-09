--[[
  COMISARIO  -  comisario de carrera para Assetto Corsa (app Lua de Custom Shaders Patch)
  Version 1.6.2  -  offline (contra la IA) y online (con amigos que tengan la app)

  Que hace:
    1. Limites de pista, velocidad en pits y salida en falso.
       Banderas: verde, amarilla, azul, blanca, a cuadros, negra, amarilla total y roja.
    2. Contactos graduados por fuerza: roce, contacto y choque fuerte.
    3. Culpa: quien alcanza por detras es el responsable; lado a lado es incidente de carrera.
    4. Puntos de incidente al estilo iRacing (1x, 2x, 4x) con limite configurable.
    5. La IA tambien es vigilada y cumple igual que tu: suelta el acelerador o entra a pits.
    6. Sanciones a eleccion: ninguna, tiempo, levantar el pie o drive-through.
    7. Clasificacion corregida con los tiempos de sancion.
    8. Indicadores sueltos en pantalla: aviso, sancion pendiente y barra de estado.
    9. Practica: solo cuenta. Clasificacion: solo invalida la vuelta. Carrera: sanciones completas.
   10. Salida parada o lanzada (con vuelta de formacion).
   11. Devolver la posicion: tras un contacto o un adelantamiento por fuera de la pista.
   12. Sanciones reales: tiempo, drive-through, stop and go y descalificacion.
   13. Online: cada piloto es vigilado por su propia app y todas se avisan entre si.
       Un director de carrera puede imponer su reglamento a todo el servidor.

  Codigo propio, escrito desde cero. No usa codigo ni archivos de otros plugins.
]]

local VERSION = '1.6.2'

-- ---------------------------------------------------------------------------
-- 1. AJUSTES (se guardan solos entre sesiones)
-- ---------------------------------------------------------------------------

local DEFAULTS = {
  enabled = true,          -- comisario activo
  raceOnly = true,         -- practica: solo cuenta; clasificacion: solo invalida la vuelta; carrera: sanciona

  -- inteligencia artificial
  aiMode = 2,              -- 0 = no vigilar a la IA, 1 = sancion solo en la clasificacion, 2 = cumple en pista
  aiPitDt = true,          -- drive-through de la IA: mandarla a pits de verdad
  aiDtSec = 20,            -- segundos de sancion si la IA no puede cumplir un drive-through
  showAiEvents = true,     -- mostrar en el panel los incidentes de la IA

  -- limites de pista
  tlEnabled = true,
  tlWheels = 4,            -- ruedas fuera para contar la salida (3 o 4)
  tlMinTime = 0.1,         -- segundos fuera de pista para contar
  tlMinSpeed = 40,         -- km/h minimos para contar
  tlCooldown = 3,          -- segundos de vuelta en pista antes de que pueda contarse otra salida
  tlWarnings = 3,          -- avisos permitidos antes de sancionar
  tlPenalty = 1,           -- 0 = ninguna, 1 = tiempo, 2 = levantar el pie, 3 = drive-through
  tlMode = 2,              -- 1 = toda salida cuenta; 2 = solo cuenta el atajo con ganancia (como Real Penalty)
  tlMaxTime = 3,           -- modo 2: una salida mas larga que esto se toma como accidente y no cuenta
  tlSlowRatio = 90,        -- modo 2: si vuelves a menos de este % de la velocidad con que saliste, no cuenta
  tlPostTime = 1,          -- modo 2: segundos despues de volver a la pista en que aun puedes soltar para que no cuente
  tlReset = true,          -- despues de una sancion por limites, los avisos vuelven a cero

  -- pits y salida
  pitEnabled = true,
  pitLimit = 82,
  pitTolerance = 0,
  pitPenalty = 3,
  jumpEnabled = true,
  jumpPenalty = 3,         -- sancion por salida en falso o por correr en la vuelta de formacion
  tiers = true,            -- escala de Real Penalty: la sancion en pits, salida en falso y formacion depende de la velocidad

  -- salida y devolucion de posicion
  startMode = 1,           -- 1 = salida parada, 2 = salida lanzada con vuelta de formacion
  formSpeed = 100,         -- velocidad maxima en la vuelta de formacion (km/h)
  formGreen = 100,         -- la bandera verde sale cuando al lider le faltan estos metros para la meta (0 = en la meta)
  formShort = true,        -- salida lanzada corta: los autos parten en fila cerca del final de la vuelta, sin dar la vuelta completa
  formStartM = 500,        -- salida corta: metros antes de la meta donde parte el primero
  formTwoWide = true,      -- salida corta offline: dos filas (1 y 2 lado a lado, 3 y 4 detras...); sin marcar, una sola fila
  formRadar = true,        -- en la formacion, indicador de distancia al auto de adelante
  gbEnabled = true,        -- pedir que se devuelva la posicion antes de sancionar
  gbSec = 20,              -- segundos para devolverla
  gbPenalty = 1,           -- sancion si no se devuelve
  passOffEnabled = true,   -- vigilar adelantamientos por fuera de la pista

  -- contactos
  ctEnabled = true,
  ctLight = 10,            -- bajo esta velocidad relativa (km/h) es un roce sin sancion
  ctHeavy = 30,            -- sobre esta velocidad relativa (km/h) es un choque fuerte
  wallMinKmh = 15,         -- km/h que hay que perder de golpe para que cuente como golpe contra el muro
  faultMode = 1,           -- 1 = con culpa (el que alcanza), 2 = sin culpa (iRacing: puntos para los dos)
  ctReview = true,         -- investigar: si la victima pierde el auto, el contacto pasa a choque fuerte
  ctWarnings = 1,          -- avisos por contacto evitable antes de sancionar
  ctMedPenalty = 1,        -- sancion por contacto evitable (tras los avisos)
  ctHeavyPenalty = 1,      -- sancion por causar un choque fuerte

  -- puntos de incidente
  incEnabled = true,
  incOff = 1,              -- salida de pista
  incSpin = 2,             -- perdida de control
  incWall = 2,             -- golpe contra el muro
  incContact = 2,          -- contacto con otro auto
  incHeavy = 4,            -- choque fuerte con otro auto
  incSum = true,           -- true = sumar todos los incidentes; false = de varios seguidos solo cuenta el mayor (iRacing)
  incStep = 0,             -- sancion cada tantos puntos (0 = sin limite)
  incPenalty = 3,          -- sancion al llegar al limite
  incDQ = 17,              -- maximo de puntos: al pasarlo, descalificacion (0 = sin maximo)

  -- sanciones
  timeSec = 5,
  liftSec = 3,
  liftWindow = 25,
  liftFailSec = 10,
  dtLaps = 3,
  dtFailSec = 20,
  dtFailDQ = true,         -- no cumplir un drive-through o stop and go: descalificacion en vez de tiempo
  endLaps = 1,             -- una sancion recibida en las ultimas (plazo + esto) vueltas se puede cambiar por tiempo; 0 = no
  sgSec = 10,              -- segundos detenido en un stop and go
  tlDouble = false,        -- limites de pista: desde la segunda sancion de tiempo, el doble
  forceCut = false,        -- experimental: el juego corta el acelerador por ti

  -- banderas
  flEnabled = true,        -- mostrar banderas (verde, amarilla, azul, blanca, a cuadros)
  yfDist = 300,            -- amarilla: metros hacia delante en que un auto detenido o sin control es peligro
  yfPass = true,           -- sancionar adelantar con bandera amarilla (primero se pide devolver el puesto)
  yfPenalty = 3,           -- sancion por adelantar o correr con amarilla total o roja
  bfEnabled = true,        -- bandera azul cuando viene alguien que te saca una vuelta
  bfSec = 20,              -- segundos con azul sin ceder el paso antes de sancionar
  bfPenalty = 0,           -- sancion por no ceder el paso (0 = solo aviso)
  fcySpeed = 80,           -- velocidad maxima con amarilla total o bandera roja (km/h)

  showSystemMsg = true,
  writeLog = true,

  -- indicadores en pantalla
  hudScale = 1,            -- tamano de los indicadores
  hudBg = false,           -- fondo oscuro detras del texto (sin fondo: solo icono y letras con sombra)
  hudFixed = true,         -- interfaz fija: los indicadores van en una columna en un lugar fijo de la pantalla
  hudX = 50,               -- interfaz fija: centro de la columna, en % del ancho de la pantalla
  hudY = 22,               -- interfaz fija: borde superior de la columna, en % del alto de la pantalla
  uiVersion = 0,           -- para aplicar una sola vez el estilo nuevo al actualizar la app
  hudIcons = true,         -- usar los iconos de banderas y sanciones (carpeta img); si no, banderas simples dibujadas
  lang = 1,                -- idioma de la app: 1 = espanol, 2 = ingles
  setAll = false,          -- ajustes: mostrar todas las opciones (sin marcar, solo las principales)
  hudPlace = false,        -- modo colocar: muestra todos los indicadores con un ejemplo
  startHudShown = false,   -- el indicador de largada ya se abrio una vez por su cuenta

  -- online
  director = false,        -- soy el director de carrera: mis reglas valen para todo el servidor

  adminKey = '',           -- clave de administrador, para servidores que la piden

  rulesVersion = 0,        -- para aplicar una sola vez el reglamento nuevo al actualizar la app
}
-- copia de los valores de fabrica: es el reglamento por defecto
local FACTORY = {}
for k, v in pairs(DEFAULTS) do FACTORY[k] = v end
local stored = ac.storage(DEFAULTS)

-- Online, el reglamento del director de carrera reemplaza al propio mientras dure la sesion.
-- "cfg" lee primero esas reglas y despues los ajustes guardados; al escribir, siempre guarda los propios.
local ruleOverride = nil
local serverAuth = 0         -- huella de la clave de administrador del servidor (0 = el servidor no tiene administrador)
local lockedNow = false      -- estoy en un servidor con administrador y no soy yo: no puedo cambiar el reglamento
local RULE_SET = {}          -- nombres de los ajustes que forman el reglamento (se llena mas abajo)

-- Huella numerica de un texto. No es seguridad de banco: solo evita que la clave viaje tal cual.
local function hashKey(text)
  local h = 5381
  text = tostring(text or '')
  for n = 1, #text do h = (h * 33 + text:byte(n)) % 4294967296 end
  return h == 0 and 1 or h
end

local function isAdmin()
  return serverAuth ~= 0 and stored.adminKey ~= '' and hashKey(stored.adminKey) == serverAuth
end
local serverOverride = nil   -- lo que impone el script del servidor: el tipo de salida (solo con lockStart = 1)
local serverLinked = false   -- el script del servidor esta respondiendo
local cfg = setmetatable({}, {
  __index = function (_, key)
    if serverOverride then
      local v = serverOverride[key]
      if v ~= nil then return v end
    end
    if ruleOverride then
      local v = ruleOverride[key]
      if v ~= nil then return v end
    end
    if lockedNow then
      -- con administrador en el servidor, un piloto no puede apagar el comisario ni usar reglas propias:
      -- mientras no llegue el reglamento del administrador vale el reglamento por defecto
      if key == 'enabled' then return true end
      if RULE_SET[key] then return FACTORY[key] end
    end
    return stored[key]
  end,
  __newindex = function (_, key, value) stored[key] = value end,
})

-- IDIOMA. Los textos se escriben en espanol dentro de tr(); con el idioma en ingles se busca cada uno
-- en la tabla EN (al final del archivo). Si falta una traduccion, el texto sale en espanol.
-- Para agregar otro idioma basta con otra tabla como EN y una opcion mas en los ajustes.
local EN = {}                  -- se llena al final del archivo
local function tr(text, ...)
  -- stored.lang: 1 = espanol (los textos tal cual), 2 = ingles
  if stored.lang == 2 then text = EN[text] or text end
  if select('#', ...) == 0 then return text end
  return string.format(text, ...)
end
-- marca un texto que se traduce mas tarde, al mostrarlo (listas de nombres)
local function N_(text) return text end

local KIND_NONE, KIND_TIME, KIND_LIFT, KIND_DT, KIND_SG, KIND_DQ = 0, 1, 2, 3, 4, 5
-- Escala de Real Penalty: la sancion depende de la velocidad a la que se cometio la falta.
--   pits:            hasta 100 km/h drive-through, hasta 200 stop and go de 10 s, mas que eso descalificacion
--   salida en falso: hasta 50 km/h drive-through, hasta 200 stop and go de 10 s, mas que eso descalificacion
--   formacion:       sobre el limite drive-through; sobre 1,25 veces el limite o adelantar, stop and go de 30 s
local RP = { pit1 = 100, pit2 = 200, jump1 = 50, jump2 = 200, sgSec = 10, formSg = 30, formRatio = 1.25 }
local KIND_NAMES = { [0] = N_('Ninguna'), N_('Tiempo'), N_('Levantar el pie'), 'Drive-through', 'Stop and go' }

-- ---------------------------------------------------------------------------
-- 2. ESTADO DE LA SESION
-- ---------------------------------------------------------------------------

local S                    -- estado de la sesion actual
local online = false       -- true en un servidor: solo se vigila el auto propio
local curSim = nil         -- datos de la simulacion en el cuadro actual
local clock = 0            -- reloj propio en segundos (no avanza en pausa)
local lastError = nil
local logLines = {}
local logDirty = false
local logSaveTimer = 0

local COL_WHITE  = rgbm(1, 1, 1, 1)
local COL_DIM    = rgbm(1, 1, 1, 0.6)
local COL_GREY   = rgbm(0.75, 0.78, 0.82, 1)
local COL_GREEN  = rgbm(0.25, 0.85, 0.35, 1)
local COL_YELLOW = rgbm(1, 0.82, 0.1, 1)
local COL_ORANGE = rgbm(1, 0.5, 0.1, 1)
local COL_RED    = rgbm(0.95, 0.2, 0.2, 1)
local BG_GREY    = rgbm(0.25, 0.27, 0.3, 0.9)
local BG_YELLOW  = rgbm(0.75, 0.55, 0, 0.9)
local BG_ORANGE  = rgbm(0.8, 0.35, 0, 0.9)
local BG_RED     = rgbm(0.7, 0.08, 0.08, 0.9)
local BG_GREEN   = rgbm(0.1, 0.5, 0.2, 0.9)

-- Estado de un piloto (el indice 0 es el jugador, el resto es la IA).
local function newDriver()
  return {
    points = 0,            -- puntos de incidente
    incWinEnd = 0,         -- fin de la ventana de incidente (solo cuenta el mayor)
    incWinMax = 0,
    victimUntil = 0,       -- hasta cuando se le perdona lo que le pase por un golpe ajeno
    tlWarnings = 0, tlCuts = 0, tlTimer = 0, tlCounted = false, tlPens = 0, tlBack = 0,
    aheadMark = -100,      -- ultima vez que iba delante del que lo choco
    ctWarnings = 0, contacts = 0, spins = 0,
    spinTimer = 0, spinCd = 0, lastSpin = -100, wallCd = 0, wallWatch = nil,
    timePenalty = 0,       -- segundos de sancion en la clasificacion
    penCount = 0,          -- sanciones recibidas
    served = 0,            -- sanciones cumplidas
    dq = false,            -- descalificado
    penalties = {},        -- sanciones pendientes (solo jugador)
    aiPens = {},           -- sanciones que la IA tiene que cumplir en pista
    hasApp = false,        -- online: ese piloto tiene el Comisario y manda su estado
    lastSeen = -100, remotePending = 0, isDirector = false,
    pvx = nil, pvy = 0, pvz = 0, prevSpeed = 0,
    finishClock = nil, finishLaps = nil, estimated = false,
  }
end

local function resetSession()
  S = {
    d = {},                -- pilotos
    pairCd = {},           -- espera entre contactos de la misma pareja
    reviews = {},          -- contactos bajo investigacion
    events = {},           -- ultimos eventos para el panel
    deferred = {},         -- sanciones por limite de incidentes pendientes de aplicar
    banner = nil,
    flag = nil,            -- bandera del aviso: { kind, untilTime }
    rf = nil,              -- bandera de pista vigente: { kind, label }
    rfs = { ahead = {}, passT = {}, passed = {}, bluePunished = {}, yellowUntil = -100, blueUntil = -100, greenUntil = -100,
      whiteUntil = -100, lastYellowMsg = -100, blueT = 0 },
    ctl = { state = 0, speed = 80, at = 0, since = 0, overT = 0 },   -- direccion de carrera: 0 verde, 1 amarilla total, 2 roja
    giveback = nil,        -- posicion que hay que devolver: { j, name, reason, kind, deadline... }
    off = nil,             -- salida de pista en curso: autos que iban justo delante
    form = nil,            -- salida lanzada: { phase = 'formation' | 'green' | 'done', ... }
    invalidLap = nil,      -- numero de la vuelta invalidada (clasificacion)
    invalidCount = 0,
    bestValid = nil,       -- mejor vuelta valida en milisegundos
    lapSeen = 0,
    pitTimer = 0, pitFlagged = false, pitTopSpeed = 0,
    jumpChecked = false, jumpRef = nil, jumpTop = nil, raceLaps = 0,
    finished = false,      -- el jugador termino la carrera
    finishedAt = 0, winnerDone = false, winner = nil,
    aiControl = nil,       -- nil = sin probar, true = funciona, false = el juego no lo permite
    lastLapCount = 0,
  }
end
resetSession()

local function D(i)
  local d = S.d[i]
  if not d then
    d = newDriver()
    S.d[i] = d
  end
  return d
end

-- ---------------------------------------------------------------------------
-- 3. UTILIDADES
-- ---------------------------------------------------------------------------

local function round(v) return math.floor(v + 0.5) end

-- Quita tildes y enes: el mensaje grande del juego usa una fuente que puede no traerlas.
local FOLD = { ['\195\161'] = 'a', ['\195\169'] = 'e', ['\195\173'] = 'i', ['\195\179'] = 'o', ['\195\186'] = 'u', ['\195\177'] = 'n',
  ['\195\129'] = 'A', ['\195\137'] = 'E', ['\195\141'] = 'I', ['\195\147'] = 'O', ['\195\154'] = 'U', ['\195\145'] = 'N' }
local function plain(text)
  return (text:gsub('\195[\128-\191]', FOLD))
end

local function sessionName(sim)
  local t = sim.raceSessionType
  if t == ac.SessionType.Race then return tr('Carrera') end
  if t == ac.SessionType.Qualify then return tr('Clasificación') end
  if t == ac.SessionType.Practice then return tr('Práctica') end
  if t == ac.SessionType.Hotlap then return 'Hotlap' end
  return tr('Sesión')
end

local function isRace(sim)
  return sim.raceSessionType == ac.SessionType.Race
end

-- Que hace el comisario segun la sesion:
--   'race'     sanciones completas
--   'qualy'    solo invalida la vuelta
--   'practice' solo cuenta
local function sessionMode()
  if not curSim then return 'practice' end
  if not cfg.raceOnly then return 'race' end
  local t = curSim.raceSessionType
  if t == ac.SessionType.Race then return 'race' end
  if t == ac.SessionType.Qualify then return 'qualy' end
  return 'practice'
end

local function penaltiesActive()
  return curSim ~= nil and sessionMode() == 'race'
end

local function lapStr(ms)
  local ok, text = pcall(ac.lapTimeToString, ms, true)
  if ok and text then return text end
  return string.format('%d:%06.3f', math.floor(ms / 60000), (ms % 60000) / 1000)
end

local function driverName(i)
  if i == 0 then return tr('Tú') end
  local ok, name = pcall(ac.getDriverName, i)
  if ok and name and name ~= '' then return name end
  return tr('Auto %s', i)
end

local function logPath()
  return ac.getFolder(ac.FolderID.Logs) .. '/comisario_log.txt'
end

local function addLog(text)
  logLines[#logLines + 1] = os.date('%H:%M:%S') .. '  ' .. text
  if #logLines > 600 then table.remove(logLines, 1) end
  logDirty = true
end

local function saveLog()
  if not cfg.writeLog or not logDirty then return end
  logDirty = false
  pcall(function () io.save(logPath(), table.concat(logLines, '\n') .. '\n') end)
end

local function pushEvent(level, text, lap, isAi)
  table.insert(S.events, 1, { text = text, level = level, lap = lap, ai = isAi })
  if #S.events > 40 then table.remove(S.events) end
end

-- Icono que acompana a un aviso, segun de que se trate.
local ICON_BY_TITLE = {
  { N_('SANCIÓN CUMPLIDA'), 'ok' }, { N_('POSICIÓN DEVUELTA'), 'ok' }, { N_('SANCIÓN +'), 'time' }, { N_('LEVANTA EL PIE'), 'lift' },
  { 'DRIVE-THROUGH', 'dt' }, { 'STOP AND GO', 'sg' }, { N_('DEVUELVE LA POSICIÓN'), 'giveback' }, { N_('DESCALIFICADO'), 'dq' },
}
local function iconFor(level, title)
  for _, e in ipairs(ICON_BY_TITLE) do
    -- el titulo ya viene en el idioma elegido: se compara con el comienzo traducido
    local head = tr(e[1])
    if title:sub(1, #head) == head or title:sub(1, #e[1]) == e[1] then return e[2] end
  end
  return level == 0 and 'green' or (level == 1 and 'warn' or 'pen')
end

-- Evento que le importa al jugador: panel, aviso grande, mensaje del juego y archivo.
local function announce(level, title, detail, lap, flagKind)
  local line = title
  if detail and detail ~= '' then line = line .. ' - ' .. detail end
  pushEvent(level, line, lap, false)
  S.banner = { title = title, detail = detail or '', level = level, start = clock, untilTime = clock + 7 }
  S.flag = { kind = flagKind or iconFor(level, title), untilTime = clock + 7 }
  if cfg.showSystemMsg then
    pcall(function () ac.setMessage(plain(title), plain(detail or '')) end)
  end
  addLog((lap and ('V' .. lap .. '  ') or '') .. line)
end

-- Evento menor o de la IA: solo lista del panel y archivo.
local function note(level, text, lap, isAi)
  if not isAi or cfg.showAiEvents then pushEvent(level, text, lap, isAi) end
  addLog((lap and ('V' .. lap .. '  ') or '') .. text)
end

-- ---------------------------------------------------------------------------
-- 3b. ONLINE: las apps de los pilotos se avisan entre si
--     Cada app vigila solo a su propio auto y le cuenta al resto lo que paso.
--     Los mensajes viajan escondidos en el chat del servidor: tienen que ser
--     cortos (menos de 175 bytes) y espaciados (aqui, uno cada 0,6 s).
-- ---------------------------------------------------------------------------

-- Ajustes que forman el reglamento y que el director de carrera impone a todos.
local RULE_KEYS = { 'raceOnly', 'tlEnabled', 'tlWheels', 'tlMinTime', 'tlMinSpeed', 'tlWarnings', 'tlPenalty',
  'pitEnabled', 'pitLimit', 'pitTolerance', 'pitPenalty', 'jumpEnabled', 'ctEnabled', 'ctLight', 'ctHeavy',
  'wallMinKmh', 'faultMode', 'ctReview', 'ctWarnings', 'ctMedPenalty', 'ctHeavyPenalty', 'incEnabled', 'incOff',
  'incSpin', 'incWall', 'incContact', 'incHeavy', 'incSum', 'incStep', 'incPenalty', 'incDQ', 'timeSec', 'liftSec',
  'liftWindow', 'liftFailSec', 'dtLaps', 'dtFailSec', 'jumpPenalty', 'startMode', 'formSpeed', 'gbEnabled', 'gbSec',
  'gbPenalty', 'passOffEnabled', 'dtFailDQ', 'sgSec', 'tlDouble', 'tlCooldown', 'tlMode', 'tlMaxTime', 'tlSlowRatio',
  'tlPostTime', 'tlReset', 'tiers', 'endLaps', 'flEnabled', 'yfDist', 'yfPass', 'yfPenalty', 'bfEnabled', 'bfSec',
  'bfPenalty', 'fcySpeed', 'formGreen', 'formShort', 'formStartM' }
-- valores que no caben en un byte tal cual: se multiplican al enviar y se dividen al recibir
local RULE_SCALE = { tlMinTime = 10, yfDist = 0.1, formStartM = 0.1 }
for _, key in ipairs(RULE_KEYS) do RULE_SET[key] = true end

-- Quien manda en el servidor: con administrador, solo el que tiene la clave; sin administrador, quien se marque director.
local function amDirector()
  if serverAuth ~= 0 then return isAdmin() end
  return stored.director
end

local net = {
  ok = false,              -- el juego acepto crear los mensajes
  outbox = {},             -- mensajes en espera de salir
  sendTimer = 0, stateTimer = 0, rulesTimer = 100,
  lastState = '',
  rulesFrom = nil,         -- nombre del director cuyas reglas se estan usando
  rulesAt = -100,
  shareAbout = nil,        -- auto afectado por lo que se esta anunciando (la victima de un contacto)
}
local evState, evNote, evRules, evControl
local applyControl         -- se define mas abajo, en la seccion de banderas

local function watchOthers()
  return not online and cfg.aiMode ~= 0
end

local function netQueue(tag, fn)
  if tag ~= 'note' then
    for _, m in ipairs(net.outbox) do
      if m.tag == tag then
        m.fn = fn
        return
      end
    end
  end
  if #net.outbox >= 12 then table.remove(net.outbox, 1) end
  net.outbox[#net.outbox + 1] = { tag = tag, fn = fn }
end

-- Le cuenta a los demas pilotos algo que le paso a este auto.
local function share(level, text)
  if not online or not net.ok then return end
  local about = -1
  if net.shareAbout then
    local c = ac.getCar(net.shareAbout)
    if c then about = c.sessionID end
  end
  local msg = plain(text):sub(1, 96)
  netQueue('note', function () evNote{ comLevel = level, comAbout = about, comText = msg } end)
end

local function onState(sender, data)
  if not sender or sender.index == 0 then return end
  local d = D(sender.index)
  d.hasApp = true
  d.lastSeen = clock
  d.points, d.timePenalty, d.tlWarnings = data.comPoints, data.comTime, data.comWarn
  d.tlCuts, d.contacts, d.served, d.penCount = data.comCuts, data.comContacts, data.comServed, data.comPens
  d.remotePending = data.comPending
  local flags = data.comFlags
  d.dq = flags % 2 == 1
  d.isDirector = math.floor(flags / 2) % 2 == 1
end

local function onNote(sender, data)
  if not sender or sender.index == 0 then return end
  local me = ac.getCar(0)
  local name = driverName(sender.index)
  local text = tostring(data.comText)
  if me and data.comAbout == me.sessionID then
    -- algo que te afecta: por ejemplo, la sancion al que te choco
    announce(0, string.upper(name), text, me.lapCount + 1)
  else
    note(4, name .. ': ' .. text, nil, true)
  end
end

-- Direccion de carrera: el director decreta amarilla total, bandera roja o verde para todos.
local function onControl(sender, data)
  if not sender or sender.index == 0 then return end
  if serverAuth ~= 0 and data.ctlAuth ~= serverAuth then return end   -- no viene del administrador
  local me = ac.getCar(0)
  if amDirector() and me and me.sessionID < sender.sessionID then return end
  S.ctl.remote = true
  applyControl(data.ctlState, data.ctlSpeed, driverName(sender.index))
end

local function onRules(sender, data)
  if not sender or sender.index == 0 then return end
  local me = ac.getCar(0)
  if serverAuth ~= 0 and data.comAuth ~= serverAuth then return end   -- no viene del administrador
  -- si hay dos directores, mandan las reglas del que tiene el numero de puesto mas bajo en el servidor
  if amDirector() and me and me.sessionID < sender.sessionID then return end
  local rules = {}
  for _, key in ipairs(RULE_KEYS) do
    local v = data[key]
    if type(stored[key]) == 'boolean' then rules[key] = v ~= 0
    elseif RULE_SCALE[key] then rules[key] = v / RULE_SCALE[key]
    else rules[key] = v end
  end
  local name = driverName(sender.index)
  if net.rulesFrom ~= name then
    addLog('Reglamento del director de carrera: ' .. name)
    note(4, tr('Se usa el reglamento de %s, director de carrera', name), nil, true)
  end
  ruleOverride = rules
  net.rulesFrom = name
  net.rulesAt = clock
end

pcall(function ()
  local I = ac.StructItem
  evState = ac.OnlineEvent({ I.key('comisario:estado:1'), comPoints = I.uint16(), comTime = I.uint16(), comWarn = I.byte(),
    comCuts = I.uint16(), comContacts = I.uint16(), comServed = I.byte(), comPens = I.byte(), comPending = I.byte(),
    comFlags = I.byte() }, onState)
  evNote = ac.OnlineEvent({ I.key('comisario:nota:1'), comLevel = I.byte(), comAbout = I.int16(), comText = I.string(100) }, onNote)
  local layout = { I.key('comisario:reglas:8'), comAuth = I.uint32() }
  for _, key in ipairs(RULE_KEYS) do layout[key] = I.byte() end
  evRules = ac.OnlineEvent(layout, onRules)
  evControl = ac.OnlineEvent({ I.key('comisario:control:2'), ctlState = I.byte(), ctlSpeed = I.byte(), ctlAuth = I.uint32() }, onControl)
  net.ok = true
end)

local function byteOf(v) return math.max(0, math.min(255, math.floor(v + 0.5))) end

-- Enlace con el script del servidor (comisario_servidor.lua), si el servidor lo tiene puesto.
-- Ese script corre en el juego de cada piloto: deja aqui el tipo de salida que impone y lee de aqui
-- la velocidad de formacion de la app. No esta documentado en que "espacio" quedan los datos de un
-- script de servidor, asi que se abren los tres posibles y se usa el que responda.
local srvLinks, srvSeen, appTick = {}, -100, 0
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
      if l then srvLinks[#srvLinks + 1] = { data = l, tick = -1 } end
    end)
  end
end

local DQ_SPEED = 50   -- km/h maximos de un descalificado, para que solo pueda volver a pits

local function readServer()
  appTick = (appTick + 1) % 60000
  local mode, linked, auth = 0, false, 0
  -- tipo de salida que pide la app (la del director, si hay uno): 1 = parada, 2 = lanzada.
  -- Un piloto bloqueado que aun no recibe el reglamento del administrador no opina: vale lo del servidor.
  local wanted = 0
  if cfg.enabled and not (lockedNow and not ruleOverride) then
    wanted = (ruleOverride and ruleOverride.startMode) or stored.startMode
    if wanted ~= 2 then wanted = 1 end
  end
  -- limite que la app le pide al limitador: amarilla total, roja o, si esta descalificado, 50 km/h hasta el final
  local limitKmh = 0
  if cfg.enabled then
    if cfg.flEnabled and S.ctl.state ~= 0 then limitKmh = math.max(30, math.min(250, S.ctl.speed)) end
    if D(0).dq and (limitKmh == 0 or limitKmh > DQ_SPEED) then limitKmh = DQ_SPEED end
  end
  for _, l in ipairs(srvLinks) do
    pcall(function ()
      l.data.appMode = wanted
      -- la velocidad de formacion de la app (o del director) es la que usa el limitador del servidor
      l.data.appSpeed = cfg.enabled and math.max(40, math.min(250, math.floor(cfg.formSpeed + 0.5))) or 0
      l.data.appLimit = limitKmh
      l.data.appOn = cfg.enabled and 1 or 0
      l.data.appDq = (cfg.enabled and D(0).dq) and 1 or 0
      -- salida lanzada corta: metros antes de la meta donde parte el primero (0 = vuelta de formacion completa)
      l.data.appStart = cfg.formShort and math.max(0, math.min(3000, math.floor(cfg.formStartM + 0.5))) or 0
      l.data.appGreen = math.max(0, math.min(250, math.floor(cfg.formGreen + 0.5)))
      l.data.appTick = appTick
      local t = l.data.srvTick
      if t ~= l.tick then
        l.tick = t
        srvSeen = clock
        l.seen = clock
      end
      if l.seen and clock - l.seen < 3 then
        linked = true
        if l.data.srvMode > 0 then mode = l.data.srvMode end
        if l.data.srvAuth ~= 0 then auth = l.data.srvAuth end
      end
    end)
  end
  serverLinked = online and linked
  serverAuth = serverLinked and auth or 0
  lockedNow = serverAuth ~= 0 and not isAdmin()
  if online and mode > 0 then
    if not serverOverride then
      addLog('Enlace con el servidor: impone la salida ' .. (mode == 2 and 'lanzada' or 'parada'))
    end
    serverOverride = { startMode = mode }
  else
    serverOverride = nil
  end
end

local function netUpdate(dt)
  if not net.ok then return end
  local d = D(0)
  local p = d.penalties[1]
  local flags = (d.dq and 1 or 0) + (amDirector() and 2 or 0)
  local snap = table.concat({ d.points, d.timePenalty, d.tlWarnings, d.tlCuts, d.contacts, d.served, d.penCount,
    p and p.kind or 0, flags }, ',')
  net.stateTimer = net.stateTimer + dt
  -- el estado sale cuando cambia (como maximo una vez por segundo) y, si no, cada 6 s
  if (snap ~= net.lastState and net.stateTimer > 1) or net.stateTimer > 6 then
    net.stateTimer = 0
    net.lastState = snap
    netQueue('state', function ()
      local dd = D(0)
      local pp = dd.penalties[1]
      evState{ comPoints = math.min(dd.points, 65000), comTime = math.min(dd.timePenalty, 65000),
        comWarn = byteOf(dd.tlWarnings), comCuts = math.min(dd.tlCuts, 65000), comContacts = math.min(dd.contacts, 65000),
        comServed = byteOf(dd.served), comPens = byteOf(dd.penCount), comPending = pp and pp.kind or 0,
        comFlags = (dd.dq and 1 or 0) + (amDirector() and 2 or 0) }
    end)
  end
  -- el director reenvia su reglamento cada 12 s, para que tambien lo reciba quien entra tarde
  if amDirector() and not ruleOverride then
    net.rulesTimer = net.rulesTimer + dt
    if net.rulesTimer > 12 then
      net.rulesTimer = 0
      netQueue('rules', function ()
        local msg = { comAuth = serverAuth }
        for _, key in ipairs(RULE_KEYS) do
          local v = stored[key]
          if type(v) == 'boolean' then msg[key] = v and 1 or 0
          elseif RULE_SCALE[key] then msg[key] = byteOf(v * RULE_SCALE[key])
          else msg[key] = byteOf(v) end
        end
        evRules(msg)
      end)
    end
  end
  -- el director repite el estado de la pista cada 5 s (y al instante cuando lo cambia)
  if amDirector() then
    net.ctlTimer = (net.ctlTimer or 100) + dt
    if net.ctlTimer > 5 then
      net.ctlTimer = 0
      netQueue('ctl', function () evControl{ ctlState = S.ctl.state, ctlSpeed = byteOf(S.ctl.speed), ctlAuth = serverAuth } end)
    end
  elseif S.ctl.remote and S.ctl.state ~= 0 and clock - S.ctl.at > 20 then
    S.ctl.remote = false
    applyControl(0, S.ctl.speed, nil)
    note(4, tr('El director de carrera ya no esta: bandera verde'), nil, true)
  end
  -- si el director se fue, vuelven las reglas propias
  if ruleOverride and clock - net.rulesAt > 40 and not lockedNow then
    ruleOverride = nil
    net.rulesFrom = nil
    note(4, tr('El director de carrera ya no esta: vuelven tus reglas'), nil, true)
  end
  net.sendTimer = net.sendTimer + dt
  if net.sendTimer >= 0.6 and #net.outbox > 0 then
    net.sendTimer = 0
    local m = table.remove(net.outbox, 1)
    pcall(m.fn)
  end
end

-- Clasificacion: la unica sancion es que el tiempo de la vuelta no cuenta.
local function invalidateLap(car, reason)
  local lap = car.lapCount + 1
  if S.invalidLap == lap then
    note(2, tr('Vuelta %s ya estaba invalidada: %s', lap, reason), lap, false)
    return
  end
  S.invalidLap = lap
  S.invalidCount = S.invalidCount + 1
  pcall(function () ac.markLapAsSpoiled(true) end)   -- le pide al juego que tampoco registre esta vuelta
  announce(2, tr('VUELTA INVALIDADA'), tr('%s. El tiempo de esta vuelta no cuenta', reason), lap)
  share(2, tr('vuelta invalidada: %s', reason))
end

local function vlen(x, y, z) return math.sqrt(x * x + y * y + z * z) end

local function dist(a, b)
  return vlen(a.x - b.x, a.y - b.y, a.z - b.z)
end

-- Diferencia de avance en la vuelta entre dos autos, entre -0,5 y 0,5.
local function wrapDiff(a, b)
  local d = a - b
  if d > 0.5 then d = d - 1 elseif d < -0.5 then d = d + 1 end
  return d
end

-- Metros que el auto "other" va delante de "me" siguiendo la pista (negativo si va detras).
local function metersAhead(other, me)
  local len = curSim and curSim.trackLengthM or 0
  if not len or len < 100 then len = 4000 end
  return wrapDiff(other.splinePosition, me.splinePosition) * len
end

-- ---------------------------------------------------------------------------
-- 4. SANCIONES AL JUGADOR
-- ---------------------------------------------------------------------------

local function addTime(seconds, reason, lap)
  local d = D(0)
  d.timePenalty = d.timePenalty + seconds
  announce(3, tr('SANCIÓN +%s s', seconds), tr('%s. Se suma a tu tiempo final', reason), lap)
  share(3, '+' .. seconds .. ' s: ' .. reason)
end

local function tryForceCut(seconds)
  if not cfg.forceCut then return false end
  local ok, res = pcall(function ()
    if not physics.allowed() then return false end
    physics.forceUserThrottleFor(seconds, 0)
    return true
  end)
  return ok and res == true
end

-- Ultimas vueltas: una sancion recibida tan cerca del final se puede dejar sin cumplir y pasa a tiempo.
local function lateRace(car)
  if cfg.endLaps <= 0 or not S.raceLaps or S.raceLaps <= 0 then return false end
  return S.raceLaps - car.lapCount <= cfg.dtLaps + cfg.endLaps
end

-- "sgSeconds" permite un stop and go de duracion distinta a la de los ajustes (escala de Real Penalty).
local function issuePenalty(kind, reason, car, timeMult, sgSeconds)
  if kind == KIND_NONE then return end
  local d = D(0)
  local lap = car.lapCount + 1
  d.penCount = d.penCount + 1
  if kind == KIND_DQ then
    d.dq = true
    announce(3, tr('DESCALIFICADO'), reason, lap)
    share(3, tr('descalificado: %s', reason))
    return
  end
  local sgNeed = sgSeconds or cfg.sgSec
  local late = (kind == KIND_DT or kind == KIND_SG) and lateRace(car)
  local term = late and tr('quedan pocas vueltas: cúmplelo o termina la carrera con +%s s',
    cfg.dtFailSec + (kind == KIND_SG and sgNeed or 0)) or tr('tienes %s vueltas', cfg.dtLaps)
  if car.isRaceFinished then
    addTime((kind == KIND_DT or kind == KIND_SG) and cfg.dtFailSec or cfg.timeSec * (timeMult or 1), reason, lap)
    return
  end
  if kind == KIND_TIME then
    addTime(cfg.timeSec * (timeMult or 1), reason, lap)
  elseif kind == KIND_LIFT then
    local forced = tryForceCut(cfg.liftSec)
    table.insert(d.penalties, {
      kind = KIND_LIFT, reason = reason, lap = lap,
      need = cfg.liftSec, done = 0, deadline = clock + cfg.liftWindow, forced = forced,
    })
    announce(2, tr('LEVANTA EL PIE %s s', cfg.liftSec), tr('%s. Suelta el acelerador antes de %s s', reason, cfg.liftWindow), lap)
    share(2, tr('levantar el pie: %s', reason))
  elseif kind == KIND_SG then
    table.insert(d.penalties, {
      kind = KIND_SG, reason = reason, lap = lap,
      lapIssued = car.lapCount, phase = car.isInPitlane and 'skip' or 'wait', stopT = 0, need = sgNeed, late = late,
    })
    announce(3, tr('STOP AND GO %s s', sgNeed), tr('%s. Entra a pits y detente %s segundos, %s', reason, sgNeed, term), lap)
    share(3, 'stop and go: ' .. reason)
  else
    table.insert(d.penalties, {
      kind = KIND_DT, reason = reason, lap = lap,
      lapIssued = car.lapCount, phase = car.isInPitlane and 'skip' or 'wait', stopped = false, late = late,
    })
    announce(3, 'DRIVE-THROUGH', tr('%s. Pasa por pits sin detenerte, %s', reason, term), lap)
    share(3, 'drive-through: ' .. reason)
  end
end

local function updatePenalties(dt, car)
  local d = D(0)
  -- un descalificado ya no tiene nada que cumplir: se borran las sanciones pendientes
  if d.dq then
    if #d.penalties > 0 then d.penalties = {} end
    return
  end
  local firstLift = true
  local i = 1
  while i <= #d.penalties do
    local p = d.penalties[i]
    local remove = false

    if p.kind == KIND_LIFT then
      if firstLift then
        firstLift = false
        if p.forced then
          p.done = p.done + dt
        elseif car.gas < 0.1 and car.speedKmh > 30 and not car.isInPitlane then
          p.done = p.done + dt
        end
        if p.done >= p.need then
          d.served = d.served + 1
          announce(0, tr('SANCIÓN CUMPLIDA'), tr('Levantar el pie'), car.lapCount + 1)
          share(0, tr('cumplio: levantar el pie'))
          remove = true
        elseif clock > p.deadline then
          addTime(cfg.liftFailSec, tr('No levantaste el pie a tiempo'), car.lapCount + 1)
          remove = true
        end
      else
        p.deadline = p.deadline + dt
      end

    elseif p.kind == KIND_DT or p.kind == KIND_SG then
      local name = p.kind == KIND_SG and 'Stop and go' or 'Drive-through'
      if p.phase == 'skip' then
        if not car.isInPitlane then p.phase = 'wait' end
      elseif p.phase == 'wait' then
        if car.isInPitlane then
          p.phase = 'in'
          p.stopped = false
          p.stopT = 0
        elseif not p.late and car.lapCount > p.lapIssued + cfg.dtLaps then
          if cfg.dtFailDQ then
            -- como en las carreras reales: no cumplir la sancion es bandera negra
            d.dq = true
            announce(3, tr('DESCALIFICADO'), tr('%s no cumplido en %s vueltas', name, cfg.dtLaps), car.lapCount + 1)
            share(3, tr('descalificado: %s', tr('%s no cumplido', name)))
          else
            addTime(cfg.dtFailSec, tr('%s no cumplido', name), car.lapCount + 1)
          end
          remove = true
        end
      elseif p.phase == 'in' then
        if p.kind == KIND_SG then
          if car.speedKmh < 2 then p.stopT = p.stopT + dt end
        elseif car.speedKmh < 5 then
          p.stopped = true
        end
        if not car.isInPitlane then
          if p.kind == KIND_SG then
            if p.stopT >= p.need then
              d.served = d.served + 1
              announce(0, tr('SANCIÓN CUMPLIDA'), 'Stop and go', car.lapCount + 1)
              share(0, tr('cumplio: stop and go'))
              remove = true
            else
              p.phase = 'wait'
              announce(2, tr('STOP AND GO NO VÁLIDO'), tr('Debías detenerte %d s en pits y estuviste %.0f', p.need, p.stopT),
                car.lapCount + 1)
            end
          elseif p.stopped then
            p.phase = 'wait'
            announce(2, tr('DRIVE-THROUGH NO VÁLIDO'), tr('Te detuviste en boxes. Hay que pasar sin parar'), car.lapCount + 1)
          else
            d.served = d.served + 1
            announce(0, tr('SANCIÓN CUMPLIDA'), 'Drive-through', car.lapCount + 1)
            share(0, tr('cumplio: drive-through'))
            remove = true
          end
        end
      end
    end

    if remove then table.remove(d.penalties, i) else i = i + 1 end
  end
end

-- Devolver la posicion: antes de sancionar, se da un plazo para dejar pasar al perjudicado.
-- "strict" = el puesto se gano con un golpe: si el otro queda detenido, la sancion se aplica igual.
local function startGiveback(j, reason, kind, mult, strict, car, sgSeconds)
  local name = driverName(j)
  if S.giveback or not cfg.gbEnabled then
    issuePenalty(kind, reason, car, mult, sgSeconds)
    return
  end
  S.giveback = { j = j, name = name, reason = reason, kind = kind, mult = mult, strict = strict, sgSec = sgSeconds,
    deadline = clock + cfg.gbSec, total = cfg.gbSec, okT = 0, stopT = 0 }
  announce(2, tr('DEVUELVE LA POSICIÓN'), tr('Deja pasar a %s antes de %s s. Motivo: %s', name, cfg.gbSec, reason),
    car.lapCount + 1)
  local keep = net.shareAbout
  net.shareAbout = j
  share(2, tr('debe devolver la posicion a %s', name))
  net.shareAbout = keep
end

local function updateGiveback(dt, car)
  local gb = S.giveback
  if not gb then return end
  local o = ac.getCar(gb.j)
  local lap = car.lapCount + 1
  if not o or o.isConnected == false or o.isInPitlane or car.isInPitlane then
    S.giveback = nil
    announce(0, tr('ORDEN ANULADA'), tr('%s ya no está en pista. Sin sanción', gb.name), lap)
    return
  end
  -- devuelta: el otro auto va otra vez delante
  if metersAhead(o, car) > 3 then gb.okT = gb.okT + dt else gb.okT = 0 end
  if gb.okT > 0.5 then
    S.giveback = nil
    announce(0, tr('POSICIÓN DEVUELTA'), tr('Sin sanción. %s recuperó su puesto', gb.name), lap)
    share(0, tr('devolvio la posicion a %s', gb.name))
    return
  end
  -- el otro quedo detenido: ya no hay a quien devolverle el puesto
  if o.speedKmh < 20 then gb.stopT = gb.stopT + dt else gb.stopT = 0 end
  if gb.stopT > 5 then
    S.giveback = nil
    if gb.strict then
      issuePenalty(gb.kind, tr('%s (quedó detenido)', gb.reason), car, gb.mult, gb.sgSec)
    else
      announce(0, tr('ORDEN ANULADA'), tr('%s quedó detenido. Sin sanción', gb.name), lap)
    end
    return
  end
  if clock > gb.deadline then
    S.giveback = nil
    if gb.kind == KIND_NONE then
      announce(1, tr('POSICIÓN NO DEVUELTA'), tr('No dejaste pasar a %s', gb.name), lap)
    else
      issuePenalty(gb.kind, tr('No devolviste la posición a %s', gb.name), car, gb.mult, gb.sgSec)
    end
  end
end

-- ---------------------------------------------------------------------------
-- 5. SANCIONES A LA IA
-- ---------------------------------------------------------------------------

-- El juego solo deja que una app controle a la IA si la pista lo permite (ver "control de la IA en la pista" mas abajo).
local function physicsOk()
  local ok, res = pcall(function () return physics.allowed() end)
  return ok and res == true
end

-- true si la IA puede cumplir sanciones en pista
local function aiOnTrack()
  return cfg.aiMode == 2 and S.aiControl ~= false and physicsOk()
end

local function aiThrottle(i, limit)
  return pcall(function () physics.setAIThrottleLimit(i, limit) end)
end

local function aiPitRequest(i, on)
  return pcall(function () physics.setAIPitStopRequest(i, on) end)
end

-- Segundos que recibe la IA en la clasificacion cuando no puede cumplir en pista.
local function kindSeconds(kind, timeMult)
  if kind == KIND_TIME then return cfg.timeSec * (timeMult or 1) end
  if kind == KIND_LIFT then return cfg.liftSec end
  if kind == KIND_DT then return cfg.aiDtSec end
  if kind == KIND_SG then return cfg.aiDtSec + cfg.sgSec end
  return 0
end

-- Sancion a un auto de la IA. Cumple igual que el jugador:
--   tiempo        -> segundos en la clasificacion
--   levantar      -> suelta el acelerador en pista
--   drive-through -> entra a pits
-- Si el juego no deja controlarla, todo pasa a segundos en la clasificacion.
local function aiPenalty(i, car, kind, timeMult, reason, tellPlayer)
  if kind == KIND_NONE or cfg.aiMode == 0 then return end
  local d = D(i)
  d.penCount = d.penCount + 1
  local how
  local onTrack = aiOnTrack() and not d.finishClock
  if kind == KIND_LIFT and onTrack then
    table.insert(d.aiPens, { kind = KIND_LIFT, need = cfg.liftSec, t = 0, state = 'wait', deadline = clock + 40 })
    how = tr('levantar el pie %s s', cfg.liftSec)
  elseif (kind == KIND_DT or kind == KIND_SG) and onTrack and cfg.aiPitDt then
    table.insert(d.aiPens, { kind = KIND_DT, lapIssued = car.lapCount, state = car.isInPitlane and 'skip' or 'wait' })
    aiPitRequest(i, true)
    how = tr('pasar por pits')
  else
    local seconds = kindSeconds(kind, timeMult)
    d.timePenalty = d.timePenalty + seconds
    how = tr('+%s s en la clasificación', seconds)
  end
  if tellPlayer then
    announce(0, tr('SANCIÓN A %s', string.upper(driverName(i))), how .. ' - ' .. reason, car.lapCount + 1)
  else
    note(4, tr('Sanción a %s: %s', driverName(i), how .. ' - ' .. reason), car.lapCount + 1, true)
  end
end

-- true si hay un auto pegado detras (hasta 25 m): no conviene soltar el acelerador justo ahi
local function carCloseBehind(i, car, n)
  local p, l = car.position, car.look
  for k = 0, n - 1 do
    if k ~= i then
      local o = ac.getCar(k)
      if o then
        local rx, ry, rz = o.position.x - p.x, o.position.y - p.y, o.position.z - p.z
        local along = rx * l.x + ry * l.y + rz * l.z
        if along < 0 and along > -25 then
          local dd = vlen(rx, ry, rz)
          if math.sqrt(math.max(0, dd * dd - along * along)) < 4 then return true end
        end
      end
    end
  end
  return false
end

-- Avisa al jugador si el auto que va a soltar el acelerador esta justo delante.
local function warnPlayerAhead(i, car)
  local me = ac.getCar(0)
  if not me then return end
  local rx, ry, rz = car.position.x - me.position.x, car.position.y - me.position.y, car.position.z - me.position.z
  local along = rx * me.look.x + ry * me.look.y + rz * me.look.z
  if along > 0 and along < 150 and vlen(rx, ry, rz) < 160 then
    announce(1, tr('ATENCIÓN'), tr('%s levanta el pie delante tuyo', driverName(i)), me.lapCount + 1)
    S.flag = { kind = 'yellow', untilTime = clock + 5 }
  end
end

-- El juego ignoro la orden: desde ahora las sanciones de la IA van a la clasificacion.
local function aiControlFailed(why)
  if S.aiControl ~= false then
    addLog('Control de la IA: no funciona (' .. why .. '), las sanciones pasan a la clasificación')
  end
  S.aiControl = false
end

local function updateAiPenalties(dt, i, car, running, n)
  local d = D(i)
  local p = d.aiPens[1]
  if not p then return end
  local done, toTime = false, 0

  if p.kind == KIND_LIFT then
    if p.state == 'wait' then
      if d.finishClock or clock > p.deadline then
        done, toTime = true, cfg.liftSec          -- no hubo un momento seguro: pasa a tiempo
      elseif running and not car.isInPitlane and car.speedKmh > 80 and not carCloseBehind(i, car, n) then
        if aiThrottle(i, 0) then
          p.state, p.t, p.startSpeed, p.resend = 'lift', 0, car.speedKmh, 0
          warnPlayerAhead(i, car)
        else
          aiControlFailed('el juego rechazó la orden')
          done, toTime = true, cfg.liftSec
        end
      end
    else
      p.t = p.t + dt
      p.resend = p.resend + dt
      if p.resend > 0.25 then
        p.resend = 0
        aiThrottle(i, 0)
      end
      if p.t > 1.5 and car.speedKmh > p.startSpeed + 8 then
        -- sigue acelerando: el juego no esta obedeciendo
        aiThrottle(i, 1)
        aiControlFailed('la IA siguió acelerando')
        done, toTime = true, cfg.liftSec
      elseif p.t >= p.need then
        aiThrottle(i, 1)
        d.served = d.served + 1
        note(4, tr('%s cumplió: levantó el pie %s s', driverName(i), p.need), car.lapCount + 1, true)
        done = true
      elseif car.isInPitlane or d.finishClock then
        aiThrottle(i, 1)
        done, toTime = true, cfg.liftSec
      end
    end

  elseif p.kind == KIND_DT then
    if p.state == 'skip' then
      if not car.isInPitlane then p.state = 'wait' end
    elseif p.state == 'wait' then
      if car.isInPitlane then
        p.state = 'in'
        aiPitRequest(i, false)
      elseif d.finishClock or car.lapCount > p.lapIssued + cfg.dtLaps then
        aiPitRequest(i, false)
        done, toTime = true, cfg.aiDtSec
        note(4, tr('%s no entró a pits: +%s s en la clasificación', driverName(i), cfg.aiDtSec), car.lapCount + 1, true)
      end
    elseif not car.isInPitlane then
      d.served = d.served + 1
      note(4, tr('%s cumplió: pasó por pits', driverName(i)), car.lapCount + 1, true)
      done = true
    end
  end

  if done then
    d.timePenalty = d.timePenalty + toTime
    table.remove(d.aiPens, 1)
  end
end

-- Devuelve el control normal a todos los autos de la IA.
local function releaseAllAi()
  if not S then return end
  if S.preLock then
    S.preLock = false
    pcall(function () physics.setCarNoInput(false) end)
  end
  if S.form and S.form.aiCapped then
    S.form.aiCapped = false
    for i = 1, 60 do
      if not ac.getCar(i) then break end
      pcall(function () physics.setAITopSpeed(i, math.huge) end)
    end
  end
  if S.ctl and S.ctl.aiCapped then
    S.ctl.aiCapped = false
    for i = 1, 60 do
      if not ac.getCar(i) then break end
      pcall(function () physics.setAITopSpeed(i, math.huge) end)
    end
  end
  for i, d in pairs(S.d) do
    if i ~= 0 and #d.aiPens > 0 then
      aiThrottle(i, 1)
      aiPitRequest(i, false)
    end
  end
end

-- ---------------------------------------------------------------------------
-- 6. SANCION SEGUN EL PILOTO Y PUNTOS DE INCIDENTE
-- ---------------------------------------------------------------------------

-- Aplica una sancion al jugador o a la IA segun corresponda.
local function penalize(i, car, kind, reason, timeMult, tellPlayer)
  if kind == KIND_NONE then return end
  if online and i ~= 0 then return end   -- a los demas los sanciona su propia app
  if i == 0 then
    issuePenalty(kind, reason, car, timeMult)
  else
    aiPenalty(i, car, kind, timeMult, reason, tellPlayer)
  end
end

local function disqualify(i, car)
  local d = D(i)
  d.dq = true
  if i == 0 then
    announce(3, tr('DESCALIFICADO'), tr('Pasaste el máximo de %s puntos de incidente (llevas %sx)', cfg.incDQ, d.points),
      car.lapCount + 1)
    share(3, tr('descalificado con %s puntos de incidente', d.points))
  else
    note(3, tr('%s descalificado por %s puntos de incidente', driverName(i), d.points), car.lapCount + 1, true)
  end
end

-- Suma puntos de incidente. Segun el ajuste, se suman todos o, como en iRacing,
-- de varios incidentes seguidos (3 segundos) solo cuenta el mayor.
-- Devuelve cuantos puntos se sumaron de verdad.
local function addIncident(i, car, pts)
  if not cfg.incEnabled or pts <= 0 then return 0 end
  if online and i ~= 0 then return 0 end
  local d = D(i)
  local add = pts
  if cfg.incSum then
    add = pts
  elseif clock < d.incWinEnd then
    add = math.max(0, pts - d.incWinMax)
    if pts > d.incWinMax then d.incWinMax = pts end
  else
    d.incWinEnd = clock + 3
    d.incWinMax = pts
  end
  if add <= 0 then return 0 end
  local before = d.points
  d.points = before + add
  -- la consecuencia de llegar al limite se aplica al final del cuadro,
  -- para que su aviso no quede tapado por el del incidente que la provoco
  if penaltiesActive() and not d.dq then
    if cfg.incDQ > 0 and d.points > cfg.incDQ then
      table.insert(S.deferred, { i = i, dq = true })
    elseif cfg.incStep > 0 and math.floor(d.points / cfg.incStep) > math.floor(before / cfg.incStep) then
      table.insert(S.deferred, { i = i, dq = false, points = d.points })
    end
  end
  return add
end

local function applyDeferred()
  if #S.deferred == 0 then return end
  local list = S.deferred
  S.deferred = {}
  for _, e in ipairs(list) do
    local car = ac.getCar(e.i)
    if car and not D(e.i).dq then
      if e.dq then
        disqualify(e.i, car)
      else
        penalize(e.i, car, cfg.incPenalty, tr('Límite de incidentes (%sx)', e.points), 1, false)
      end
    end
  end
end

local function ptsText(i, add)
  if not cfg.incEnabled then return '' end
  return tr('+%sx de incidente (llevas %sx)', add, D(i).points)
end

-- Texto para el aviso de un incidente: puntos sumados, o por que no sumo.
local function incidentDetail(i, add)
  if not cfg.incEnabled then return '' end
  if add > 0 then return ptsText(i, add) end
  return tr('Sin puntos extra: ya contaba un incidente mayor (llevas %sx)', D(i).points)
end

-- true si el auto va sin control: trompeado hace poco o deslizando de lado ahora mismo
local function outOfControl(i)
  local d = D(i)
  return clock - d.lastSpin < 5 or d.spinTimer > 0.1
end

-- ---------------------------------------------------------------------------
-- 7. DETECCION: LIMITES DE PISTA, TROMPOS, PITS Y SALIDA
-- ---------------------------------------------------------------------------

-- Consecuencia de una salida que cuenta: aviso y, pasados los avisos, sancion.
local function registerCut(i, car, d, add, gain)
  d.tlCuts = d.tlCuts + 1
  local lap = car.lapCount + 1
  local pts = add > 0 and ptsText(i, add) or ''
  local what = gain and tr('Atajo con ventaja') or tr('Saliste de la pista')

  if not penaltiesActive() then
    if i == 0 then
      if sessionMode() == 'qualy' then
        invalidateLap(car, tr('Límites de pista'))
      else
        announce(1, tr('LÍMITES DE PISTA'), tr('Salida número %s. En práctica solo se cuenta', d.tlCuts), lap)
      end
    end
    return
  end

  if cfg.tlPenalty == KIND_NONE then
    if i == 0 then announce(1, tr('SALIDA DE PISTA'), pts, lap) end
    return
  end

  d.tlWarnings = d.tlWarnings + 1
  if d.tlWarnings <= cfg.tlWarnings then
    if i == 0 then
      local left = cfg.tlWarnings - d.tlWarnings
      local detail = left > 0 and (what .. '. ' .. (left == 1 and tr('Te queda 1 aviso') or tr('Te quedan %s avisos', left)))
        or (what .. '. ' .. tr('La próxima salida es sanción'))
      if pts ~= '' then detail = detail .. '. ' .. pts end
      announce(1, tr('AVISO %s/%s LÍMITES DE PISTA', d.tlWarnings, cfg.tlWarnings), detail, lap)
      share(1, tr('aviso %s/%s por limites de pista', d.tlWarnings, cfg.tlWarnings))
    end
  else
    d.tlPens = d.tlPens + 1
    if cfg.tlReset then d.tlWarnings = 0 end
    penalize(i, car, cfg.tlPenalty, tr('Límites de pista'), (cfg.tlDouble and d.tlPens >= 2) and 2 or 1, false)
  end
end

-- Modo "atajo con ventaja" (como Real Penalty): la salida solo cuenta si no perdiste velocidad.
-- Se compara la velocidad al salir con la mas baja desde que vuelves a la pista y durante un instante mas.
-- Una salida larga se toma como accidente y no cuenta.
local function checkCutGain(dt, i, car, d, out)
  if out then
    if not d.cutOut then
      local v0 = d.cutPost and d.cutPost.v0 or math.max(d.prevSpeed or 0, car.speedKmh)
      d.cutOut = { t = 0, v0 = v0 }
      d.cutPost = nil
    end
    d.cutOut.t = d.cutOut.t + dt
    return
  end
  if d.cutOut then
    local o = d.cutOut
    d.cutOut = nil
    if o.t >= cfg.tlMinTime and o.t <= cfg.tlMaxTime and o.v0 >= cfg.tlMinSpeed and clock >= d.victimUntil
      and clock - (d.cutLast or -100) >= cfg.tlCooldown then
      d.cutPost = { v0 = o.v0, vmin = car.speedKmh, t = 0 }
    end
  end
  local p = d.cutPost
  if not p then return end
  p.t = p.t + dt
  if car.speedKmh < p.vmin then p.vmin = car.speedKmh end
  if p.t < cfg.tlPostTime then return end
  d.cutPost = nil
  if p.vmin >= p.v0 * cfg.tlSlowRatio / 100 then
    d.cutLast = clock
    registerCut(i, car, d, 0, true)
  elseif i == 0 then
    note(0, tr('Salida de pista sin ventaja: soltaste a tiempo'), car.lapCount + 1, false)
  end
end

local function checkTrackLimits(dt, i, car)
  if not cfg.tlEnabled then return end
  local d = D(i)
  local out = car.wheelsOutside >= cfg.tlWheels and not car.isInPitlane
  if cfg.tlMode == 2 then checkCutGain(dt, i, car, d, out) end
  if not out then
    d.tlTimer = 0
    if d.tlCounted then
      -- cronometro invisible: la misma salida no se cuenta dos veces aunque el auto pise la pista un instante.
      -- Solo despues de unos segundos seguidos de vuelta en pista puede contarse una salida nueva.
      d.tlBack = d.tlBack + dt
      if d.tlBack >= cfg.tlCooldown then d.tlCounted = false end
    end
    return
  end
  d.tlBack = 0
  if d.tlCounted then return end
  if car.speedKmh < cfg.tlMinSpeed then return end
  d.tlTimer = d.tlTimer + dt
  if d.tlTimer < cfg.tlMinTime then return end
  d.tlCounted = true

  -- si lo sacaron de pista con un golpe, no es culpa suya
  if clock < d.victimUntil then return end

  local add = addIncident(i, car, cfg.incOff)
  if cfg.tlMode == 2 then
    -- el punto de incidente se cuenta siempre; el aviso, solo si hubo ventaja (lo decide checkCutGain)
    if add > 0 and i == 0 then note(1, tr('Salida de pista. %s', ptsText(i, add)), car.lapCount + 1, false) end
    return
  end
  registerCut(i, car, d, add, false)
end

-- Adelantar por fuera de la pista: si al volver quedaste delante de alguien que iba justo delante, hay que devolverle el puesto.
local function checkOffTrackPass(car, n)
  if not cfg.passOffEnabled or not penaltiesActive() then
    S.off = nil
    return
  end
  local out = car.wheelsOutside >= cfg.tlWheels and not car.isInPitlane
  local o = S.off
  if out then
    if not o then
      local list = {}
      for j = 1, n - 1 do
        local c = ac.getCar(j)
        if c and not c.isInPitlane and c.speedKmh > 30 then
          local m = metersAhead(c, car)
          if m > 0 and m < 40 then list[#list + 1] = j end
        end
      end
      S.off = { list = list, back = nil }
    else
      o.back = nil
    end
  elseif o then
    if #o.list == 0 or car.speedKmh < 30 then
      S.off = nil
    elseif not o.back then
      o.back = clock + 1.5          -- se espera un momento a que la situacion se asiente
    elseif clock >= o.back then
      S.off = nil
      if clock < D(0).victimUntil then return end
      for _, j in ipairs(o.list) do
        local c = ac.getCar(j)
        if c and not c.isInPitlane and c.speedKmh > 30 and metersAhead(c, car) < -2 then
          startGiveback(j, tr('Adelantamiento por fuera de la pista'), cfg.gbPenalty, 1, false, car)
          return
        end
      end
    end
  end
end

-- Perdida de control: el auto se mueve de lado o hacia atras a buena velocidad.
local function checkSpin(dt, i, car)
  local d = D(i)
  if car.speedKmh < 40 or car.isInPitlane then
    d.spinTimer = 0
    return
  end
  local v, l = car.velocity, car.look
  local len = vlen(v.x, v.y, v.z)
  if len < 1 then return end
  local forward = (v.x * l.x + v.y * l.y + v.z * l.z) / len
  if forward > 0.3 then
    d.spinTimer = 0
    return
  end
  d.spinTimer = d.spinTimer + dt
  if d.spinTimer < 0.3 or clock < d.spinCd then return end
  d.spinCd = clock + 6
  d.lastSpin = clock
  d.spins = d.spins + 1
  if clock < d.victimUntil then return end
  local add = addIncident(i, car, cfg.incSpin)
  if i == 0 then
    announce(1, tr('PÉRDIDA DE CONTROL'), incidentDetail(i, add), car.lapCount + 1)
  elseif add > 0 then
    note(4, tr('%s: pérdida de control %s', driverName(i), ptsText(i, add)), car.lapCount + 1, true)
  end
end

local function checkPitSpeed(dt, car)
  if not cfg.pitEnabled then return end
  if not car.isInPitlane then
    S.pitTimer = 0
    S.pitFlagged = false
    S.pitTopSpeed = 0
    return
  end
  if S.pitFlagged then return end
  if car.speedKmh > cfg.pitLimit + cfg.pitTolerance then
    S.pitTimer = S.pitTimer + dt
    if car.speedKmh > S.pitTopSpeed then S.pitTopSpeed = car.speedKmh end
    if S.pitTimer > 0.5 then
      S.pitFlagged = true
      local reason = tr('Exceso en pits: %s km/h (límite %s)', round(S.pitTopSpeed), cfg.pitLimit)
      if penaltiesActive() and cfg.tiers then
        local top = S.pitTopSpeed
        if top < RP.pit1 then issuePenalty(KIND_DT, reason, car)
        elseif top < RP.pit2 then issuePenalty(KIND_SG, reason, car, 1, RP.sgSec)
        else issuePenalty(KIND_DQ, reason, car) end
      elseif penaltiesActive() and cfg.pitPenalty ~= KIND_NONE then
        issuePenalty(cfg.pitPenalty, reason, car)
      else
        announce(1, tr('VELOCIDAD EN PITS'), tr('%s. Sin sanción en esta sesión', reason), car.lapCount + 1)
      end
    end
  else
    S.pitTimer = 0
  end
end

local function checkJumpStart(sim, car)
  if not cfg.jumpEnabled or S.jumpChecked or not isRace(sim) or cfg.startMode == 2 then return end
  local t = sim.timeToSessionStart   -- milisegundos que faltan para la largada
  if t <= 0 then
    S.jumpChecked = true
    if S.jumpTop then
      -- escala de Real Penalty: cuenta la velocidad maxima alcanzada antes de la luz verde
      local reason = tr('Salida en falso (%s km/h antes de la luz verde)', round(S.jumpTop))
      if S.jumpTop < RP.jump1 then issuePenalty(KIND_DT, reason, car)
      elseif S.jumpTop < RP.jump2 then issuePenalty(KIND_SG, reason, car, 1, RP.sgSec)
      else issuePenalty(KIND_DQ, reason, car) end
    end
    return
  end
  if S.jumpTop then
    if car.speedKmh > S.jumpTop then S.jumpTop = car.speedKmh end
    return
  end
  if t > 5000 then return end
  if not S.jumpRef then
    S.jumpRef = vec3(car.position.x, car.position.y, car.position.z)
    return
  end
  if car.speedKmh > 3 and dist(car.position, S.jumpRef) > 0.8 then
    if cfg.tiers and penaltiesActive() then
      S.jumpTop = car.speedKmh
      announce(2, tr('SALIDA EN FALSO'), tr('Te moviste antes de la luz verde. La sanción depende de la velocidad que alcances'), 1)
      return
    end
    S.jumpChecked = true
    issuePenalty(cfg.jumpPenalty, tr('Salida en falso'), car)
  end
end

-- ---------------------------------------------------------------------------
-- 8. DETECCION: CONTACTOS
-- ---------------------------------------------------------------------------

local LEVEL_NAMES = { [0] = 'roce', 'contacto', 'choque fuerte' }

-- Veredicto de un contacto con culpable.
local function verdictBody(g, v, level, upgraded)
  local carG, carV = ac.getCar(g), ac.getCar(v)
  if not carG or not carV then return end
  local dg = D(g)
  local lap = carG.lapCount + 1
  local add = addIncident(g, carG, level == 2 and cfg.incHeavy or cfg.incContact)
  local pts = add > 0 and ('. ' .. ptsText(g, add)) or ''
  local playerInvolved = g == 0 or v == 0
  local what
  if v == 0 then
    what = level == 2 and tr('Causar un choque contigo') or tr('Contacto evitable contigo')
  else
    what = level == 2 and tr('Causar un choque con %s', driverName(v)) or tr('Contacto evitable con %s', driverName(v))
  end
  if upgraded then what = tr('%s (perdió el control)', what) end

  if not penaltiesActive() then
    if g == 0 and sessionMode() == 'qualy' then
      invalidateLap(carG, what)
    elseif playerInvolved then
      announce(1, tr('CONTACTO'), tr('%s. En esta sesión solo se cuenta', what), lap)
    end
    return
  end

  if level == 2 then
    if cfg.ctHeavyPenalty == KIND_NONE then
      if playerInvolved then announce(2, tr('CHOQUE'), what .. pts, lap) end
    else
      if g == 0 and pts ~= '' then note(2, tr('Choque con %s', driverName(v)) .. pts, lap, false) end
      penalize(g, carG, cfg.ctHeavyPenalty, what, 2, v == 0)
    end
    return
  end

  -- si con el contacto le ganaste el puesto, primero se te pide devolverlo
  if g == 0 and cfg.gbEnabled and clock - D(v).aheadMark < 8 and metersAhead(carV, carG) < -1 and carV.speedKmh > 20 then
    startGiveback(v, what, cfg.gbPenalty, 1, true, carG)
    return
  end

  -- contacto medio: primero avisos, despues sancion
  dg.ctWarnings = dg.ctWarnings + 1
  if dg.ctWarnings <= cfg.ctWarnings or cfg.ctMedPenalty == KIND_NONE then
    if g == 0 then
      announce(1, tr('AVISO POR CONTACTO'), what .. pts, lap)
      share(1, tr('aviso: %s', what))
    elseif v == 0 then
      announce(0, tr('AVISO A %s', string.upper(driverName(g))), tr('Por el contacto contigo'), lap)
    else
      note(4, tr('Aviso a %s: %s', driverName(g), what), lap, true)
    end
  else
    penalize(g, carG, cfg.ctMedPenalty, what, 1, v == 0)
  end
end

local function verdict(g, v, level, upgraded)
  if online and g ~= 0 then
    -- online, al otro piloto lo juzga su propia app
    local me = ac.getCar(0)
    if v == 0 and me then
      note(4, tr('Contacto con %s: la sanción la decide su Comisario', driverName(g)), me.lapCount + 1, false)
    end
    return
  end
  net.shareAbout = (online and v ~= 0) and v or nil
  verdictBody(g, v, level, upgraded)
  net.shareAbout = nil
end

local function carContact(a, b)
  local carA, carB = ac.getCar(a), ac.getCar(b)
  if not carA or not carB then return end
  local da, db = D(a), D(b)
  da.contacts = da.contacts + 1
  db.contacts = db.contacts + 1

  -- fuerza del golpe: velocidad relativa justo antes del contacto
  local ax, ay, az, bx, by, bz
  if da.pvx and db.pvx then
    ax, ay, az, bx, by, bz = da.pvx, da.pvy, da.pvz, db.pvx, db.pvy, db.pvz
  else
    ax, ay, az = carA.velocity.x, carA.velocity.y, carA.velocity.z
    bx, by, bz = carB.velocity.x, carB.velocity.y, carB.velocity.z
  end
  local rel = vlen(ax - bx, ay - by, az - bz) * 3.6
  local level = 0
  if rel >= cfg.ctHeavy then level = 2 elseif rel >= cfg.ctLight then level = 1 end

  local playerInvolved = a == 0
  local other = b
  local lap = carA.lapCount + 1
  addLog(string.format('Contacto %s - %s  %.0f km/h relativos  (%s)', driverName(a), driverName(b), rel, LEVEL_NAMES[level]))

  if level == 0 then
    if playerInvolved then pushEvent(4, tr('Roce con %s, sin sanción', driverName(other)), lap, false) end
    return
  end

  -- modo sin culpa (iRacing): puntos para los dos, sin sancion directa
  if cfg.faultMode == 2 then
    local pts = level == 2 and cfg.incHeavy or cfg.incContact
    local addA = addIncident(a, carA, pts)
    addIncident(b, carB, pts)
    if playerInvolved then
      announce(level == 2 and 2 or 1, level == 2 and tr('CHOQUE') or tr('CONTACTO'),
        tr('Con %s', driverName(other)) .. (addA > 0 and ('. ' .. ptsText(0, addA)) or ''), lap)
    end
    return
  end

  -- modo con culpa
  local spA, spB = vlen(ax, ay, az) * 3.6, vlen(bx, by, bz) * 3.6
  local g, v
  local lostA = outOfControl(a) and clock >= da.victimUntil
  local lostB = outOfControl(b) and clock >= db.victimUntil
  local lostControl = false
  if lostA ~= lostB then
    -- uno de los dos venia sin control: ese responde por el golpe
    if lostA then g, v = a, b else g, v = b, a end
    lostControl = true
  else
    -- si no, responde el que venia detras y mas rapido
    local la, lb = carA.look, carB.look
    local px, py, pz = carB.position.x - carA.position.x, carB.position.y - carA.position.y, carB.position.z - carA.position.z
    local bAhead = px * la.x + py * la.y + pz * la.z     -- metros que B va delante de A
    local aAhead = -(px * lb.x + py * lb.y + pz * lb.z)  -- metros que A va delante de B
    if bAhead > 3 and spA > spB + 3 then g, v = a, b
    elseif aAhead > 3 and spB > spA + 3 then g, v = b, a end
  end

  if not g then
    -- lado a lado: incidente de carrera, nadie es sancionado
    -- quien venia golpeado por otro no suma puntos por lo que pase despues
    if level == 2 then
      if clock >= da.victimUntil then addIncident(a, carA, cfg.incContact) end
      if clock >= db.victimUntil then addIncident(b, carB, cfg.incContact) end
    end
    if playerInvolved then
      announce(1, tr('INCIDENTE DE CARRERA'), tr('Contacto lado a lado con %s, sin sanción', driverName(other)), lap)
    end
    return
  end

  D(v).victimUntil = clock + 5
  if (g == a and metersAhead(carB, carA) or metersAhead(carA, carB)) > 0 then D(v).aheadMark = clock end
  if lostControl then
    addLog('  culpa de ' .. driverName(g) .. ': venía sin control')
  end
  if level == 1 and cfg.ctReview then
    table.insert(S.reviews, { g = g, v = v, start = clock, untilTime = clock + 3 })
    if playerInvolved then
      announce(1, tr('INCIDENTE BAJO INVESTIGACIÓN'), tr('Contacto con %s', driverName(other)), lap)
    end
  else
    verdict(g, v, level, false)
  end
end

-- Si la victima pierde el auto o se sale tras el golpe, el contacto pasa a choque fuerte.
local function updateReviews()
  local i = 1
  while i <= #S.reviews do
    local r = S.reviews[i]
    local victim = ac.getCar(r.v)
    local lost = victim and (D(r.v).lastSpin >= r.start or victim.wheelsOutside >= 4)
    if lost then
      verdict(r.g, r.v, 2, true)
      table.remove(S.reviews, i)
    elseif clock >= r.untilTime then
      verdict(r.g, r.v, 1, false)
      table.remove(S.reviews, i)
    else
      i = i + 1
    end
  end
end

local function wallContact(i, car, lost)
  local d = D(i)
  addLog(string.format('Muro: %s perdió %.0f km/h de golpe', driverName(i), lost))
  if clock < d.victimUntil then return end
  local add = addIncident(i, car, cfg.incWall)
  if i == 0 then
    announce(1, tr('GOLPE CONTRA EL MURO'), incidentDetail(i, add), car.lapCount + 1)
  elseif add > 0 then
    note(4, tr('%s: golpe contra el muro %s', driverName(i), ptsText(i, add)), car.lapCount + 1, true)
  end
end

local function checkCollisions(sim)
  if not cfg.ctEnabled then return end
  local n = sim.carsCount
  for i = 0, n - 1 do
    local car = ac.getCar(i)
    if car and car.collisionDepth > 0 and (i == 0 or watchOthers()) then
      -- el otro implicado es el auto mas cercano que este pegado: hasta 5,3 m a lo largo y 2,4 m de lado
      local j, best = nil, 1e9
      local p, l = car.position, car.look
      for k = 0, n - 1 do
        if k ~= i then
          local o = ac.getCar(k)
          if o then
            local rx, ry, rz = o.position.x - p.x, o.position.y - p.y, o.position.z - p.z
            local along = rx * l.x + ry * l.y + rz * l.z
            local dd = vlen(rx, ry, rz)
            local side = math.sqrt(math.max(0, dd * dd - along * along))
            if math.abs(along) < 5.3 and side < 2.4 and dd < best then j, best = k, dd end
          end
        end
      end
      if j then
        local a, b = math.min(i, j), math.max(i, j)
        if a == 0 or watchOthers() then
          local key = a * 1000 + b
          if (S.pairCd[key] or 0) <= clock then
            S.pairCd[key] = clock + 4
            carContact(a, b)
          end
        end
      else
        -- sin autos cerca puede ser el muro, pero el juego tambien marca "colision" al pisar pasto o pianos.
        -- Solo cuenta si en los proximos instantes el auto pierde velocidad de golpe.
        local d = D(i)
        if not d.wallWatch and clock >= d.wallCd and d.prevSpeed > 30 and d.pvx then
          d.wallWatch = { lost = 0, untilTime = clock + 0.25 }
        end
      end
    end
  end
end

-- Confirma o descarta un posible golpe contra el muro.
-- Frenar fuerte, doblar o tocar fondo en una bajada tambien cambian la velocidad, pero nunca mas rapido
-- de lo que aguantan los neumaticos. Un golpe de verdad la cambia de un cuadro a otro. Por eso solo se
-- suma el cambio de los cuadros en que la desaceleracion pasa de WALL_G (imposible sin chocar con algo).
local WALL_G = 6
local function updateWallWatch(i, car, dt)
  local d = D(i)
  local w = d.wallWatch
  if not w then return end
  if d.pvx and dt > 0 then
    local v = car.velocity
    local dv = vlen(v.x - d.pvx, v.y - d.pvy, v.z - d.pvz)
    if dv / dt >= WALL_G * 9.81 then w.lost = w.lost + dv * 3.6 end
  end
  if w.lost >= cfg.wallMinKmh then
    d.wallWatch = nil
    d.wallCd = clock + 4
    wallContact(i, car, w.lost)
  elseif clock > w.untilTime then
    d.wallWatch = nil
  end
end

-- ---------------------------------------------------------------------------
-- 8b. SALIDA LANZADA
--     El juego siempre larga con semaforo. Con esta opcion, la primera vuelta es de formacion:
--     se mantiene el puesto y la velocidad, y la carrera se larga cuando el lider cruza la meta.
-- ---------------------------------------------------------------------------

local GRID_GAP = 10   -- metros entre un auto y el siguiente en la fila de la salida corta
-- Fila doble: los autos van de a dos, uno al lado del otro. ROW_GAP es la distancia entre una fila y la siguiente
-- y LANE la distancia de cada auto al centro de la pareja. La IA que queda lejos de su linea no arranca (en Spa
-- arranco a 3 m y no a 8 m): por eso la pareja va cerca de esa linea y no al centro de la pista. EDGE es lo minimo
-- del centro del auto al borde y FAR lo mas lejos de la linea que puede quedar un auto.
-- STAGGER: el segundo de cada fila va unos metros detras del primero, como en una grilla de verdad. Exactamente
-- lado a lado, la IA de la pole no arrancaba (Spa, 1.5.4 y 1.5.7).
local FORM2 = { ROW_GAP = 12, LANE = 1.9, EDGE = 1.5, FAR = 5, STAGGER = 4 }

-- Lugar "slot" de la largada: metros antes de la meta y lado (1 o -1; 0 = al centro, una sola fila)
function FORM2.spot(slot, twoWide)
  slot = math.max(1, slot or 1)
  if twoWide and not FORM2.single then
    local even = slot % 2 == 0
    return FORM2.startMeters() + (math.ceil(slot / 2) - 1) * FORM2.ROW_GAP + (even and FORM2.STAGGER or 0), even and -1 or 1
  end
  return FORM2.startMeters() + (slot - 1) * GRID_GAP, 0
end

-- en una fila doble, dos lugares de la misma fila van lado a lado
function FORM2.sameRow(a, b)
  return cfg.formTwoWide and not FORM2.single and math.ceil(a / 2) == math.ceil(b / 2)
end

-- Distancia hacia el lado (desde la linea de la IA) para un auto de la fila doble, o nil si no caben dos autos
-- cerca de la linea o el juego no informa el ancho. w.x es el espacio hacia el lado +1 y w.y hacia el -1
-- (igual que en la app DynamicReturn de CSP).
-- Espacio desde la linea de la IA hacia el lado +1 y hacia el -1 (en la direccion (-dz, dx) de la pista).
-- El juego entrega los dos numeros en el orden contrario al que se supuso hasta la 1.6.1 (en Monza un auto quedo
-- en el pasto y el radar mandaba al lado equivocado). Si aun asi algun auto queda con ruedas fuera al ponerlo en
-- la fila, RS.checkSides prueba el otro orden.
FORM2.flip = true
function FORM2.sides(sp)
  local ok, w = pcall(ac.getTrackAISplineSides, sp)
  if not ok or not w or not (w.x > 0 and w.y > 0) or w.x + w.y > 50 then return nil end
  if FORM2.flip then return w.y, w.x end
  return w.x, w.y
end

-- centro entre las dos columnas de la fila doble, medido desde la linea de la IA (nil si no hay fila doble ahi)
function FORM2.pairCenter(sp)
  local a, b = FORM2.lateral(sp, 1), FORM2.lateral(sp, -1)
  if not a or not b then return nil end
  return (a + b) / 2
end

function FORM2.lateral(sp, side)
  local wp, wm = FORM2.sides(sp)
  if not wp then
    return side == 0 and 0 or nil          -- sin datos: una columna justo sobre la linea, como siempre
  end
  local w = { x = wp, y = wm }
  if not FORM2.logged then
    FORM2.logged = true
    addLog(string.format('Fila: espacio desde la linea de la IA hacia cada lado %.1f m y %.1f m', w.x, w.y))
  end
  if side == 0 then
    -- una sola columna: sobre la linea, pero si esta va pegada a un borde el auto se corre hacia adentro
    local lo, hi = FORM2.EDGE - w.y, w.x - FORM2.EDGE
    if lo > hi then return 0 end
    return math.max(lo, math.min(hi, 0))
  end
  -- la pareja ocupa de c - LANE a c + LANE; c se corre lo justo para que ninguno quede cerca de un borde
  local room = FORM2.LANE + FORM2.EDGE
  local lo, hi = room - w.y, w.x - room
  if lo > hi then return nil end
  local c = math.max(lo, math.min(hi, 0))
  if math.abs(c) + FORM2.LANE > FORM2.FAR then return nil end
  -- la pole (y los impares) van del lado mas cercano a la linea de la IA, como en una largada real
  local near = c > 0 and -1 or 1
  return c + side * near * FORM2.LANE
end

-- Altura del asfalto en el punto corrido hacia el lado. nil si ahi hay algo mucho mas alto o mas bajo que la
-- linea de la IA (un muro, una zanja): el auto no se pone ahi.
function FORM2.ground(x, y, z)
  local ok, d = pcall(physics.raycastTrack, vec3(x, y + 3, z), vec3(0, -1, 0), 8)
  if not ok or type(d) ~= 'number' or d <= 0 then return y end
  local g = y + 3 - d
  if math.abs(g - y) > 1.2 then return nil end
  return g
end

local function trackLen(sim)
  return (sim.trackLengthM and sim.trackLengthM > 100) and sim.trackLengthM or 4000
end

-- Metros antes de la meta donde parte el primero de la fila (siempre antes del punto de la bandera verde).
local function formStartMeters()
  return math.max(cfg.formStartM, cfg.formGreen + 100)
end
-- donde parte el primero: lo elegido en los ajustes, o un poco mas atras si ahi la pista es curva (ver pickStart)
FORM2.startMeters = function () return FORM2.start or formStartMeters() end

-- Busca donde armar la fila offline: el primer tramo recto entre la distancia elegida y 400 m mas atras. En una
-- curva la linea de la IA corta por el piano y los autos quedaban encima de el (Spa, 500 m antes de la meta).
function FORM2.pickStart(len, n)
  FORM2.start = nil
  local base = formStartMeters()
  local two = cfg.formTwoWide and not FORM2.single
  local span = (two and (math.ceil(n / 2) - 1) * FORM2.ROW_GAP or (n - 1) * GRID_GAP) + 40
  local function heading(m)
    local sp = 1 - m / len
    local a = ac.trackProgressToWorldCoordinate(sp)
    local b = ac.trackProgressToWorldCoordinate(sp + 2 / len)
    return math.atan2(b.x - a.x, b.z - a.z)
  end
  local bestD, bestDev = base, math.huge
  local ok = pcall(function ()
    for d = base, base + 400, 20 do
      if (d + span) / len > 0.9 then break end
      local h0 = heading(d)
      local dev = 0
      for m = d - 40, d + span, 10 do
        local dh = math.abs(heading(m) - h0)
        if dh > math.pi then dh = 2 * math.pi - dh end
        if dh > dev then dev = dh end
      end
      if dev < bestDev then bestD, bestDev = d, dev end
      if dev < math.rad(6) then break end
    end
  end)
  if ok and bestD ~= base then FORM2.start = bestD end
  addLog(string.format('Fila: el primero parte a %.0f m de la meta (curva en la zona de la fila: %.0f grados)',
    FORM2.startMeters(), ok and math.deg(bestDev) or -1))
end

-- Salida lanzada corta: pone un auto en su lugar de la fila. Solo funciona si el juego deja mover autos.
local function placeInFormation(i, slot, len)
  local meters, side = FORM2.spot(slot, cfg.formTwoWide)
  local sp = 1 - meters / len
  if sp < 0.05 then return false end
  return pcall(function ()
    if not physics.allowed() then error('sin permiso') end
    local a = ac.trackProgressToWorldCoordinate(sp)
    local b = ac.trackProgressToWorldCoordinate(sp + 2 / len)
    local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
    local dd = vlen(dx, dy, dz)
    if dd < 0.001 then error('sin direccion') end
    local px, py, pz = a.x, a.y, a.z
    -- corrimiento hacia un lado de la linea de la IA (fila doble, o una columna lejos del borde)
    local off = FORM2.lateral(sp, side)
    local lx, lz = -dz / dd, dx / dd
    local ll = math.sqrt(lx * lx + lz * lz)
    local gy = off and ll > 0.001 and FORM2.ground(px + lx / ll * off, py, pz + lz / ll * off)
    if side ~= 0 and not gy then
      -- no cabe un auto al lado en este punto: toda la fila pasa a una columna (quien llamo la vuelve a armar)
      FORM2.single = true
      error('sin espacio para la fila doble')
    end
    if gy and off ~= 0 then
      px, py, pz = px + lx / ll * off, gy, pz + lz / ll * off
    end
    -- el juego espera la direccion al reves: hacia donde apunta la cola del auto
    physics.setCarPosition(i, vec3(px, py + 0.2, pz), vec3(-dx / dd, -dy / dd, -dz / dd))
    -- un auto movido queda "dormido" en el motor de fisica hasta que algo lo toca: se le despierta
    pcall(physics.awakeCar, i)
  end)
end

-- RS: salida lanzada offline (fila en la cuenta regresiva, IA en orden) y avance de cada auto en la carrera.
local RS = {}

-- posicion en la pista (0 a 1) del lugar "slot" de la fila
function RS.slotSpline(slot, len)
  local meters = FORM2.spot(slot, cfg.formTwoWide)
  return 1 - meters / len
end

-- Avance de cada auto en vueltas, medido por la app. No usa el contador de vueltas del juego, que despues de
-- una salida corta no siempre coincide entre autos. Un salto grande de un cuadro a otro es un teletransporte
-- (la fila de la salida corta, el envio a pits) y no se cuenta.
function RS.progress(sim, n)
  local len = (sim.trackLengthM and sim.trackLengthM > 100) and sim.trackLengthM or 4000
  S.prog = S.prog or {}
  S.progSp = S.progSp or {}
  for i = 0, n - 1 do
    local c = ac.getCar(i)
    if c then
      local sp = c.splinePosition
      local prev = S.progSp[i]
      if S.prog[i] == nil then
        -- antes de largar todos cuentan desde la meta: los que esperan detras de ella van en negativo
        if isRace(sim) and not sim.isSessionStarted then
          S.prog[i] = sp > 0.5 and sp - 1 or sp
        else
          S.prog[i] = c.lapCount + sp
        end
      elseif prev and sim.isSessionStarted then
        local dsp = sp - prev
        if dsp < -0.5 then dsp = dsp + 1 elseif dsp > 0.5 then dsp = dsp - 1 end
        if math.abs(dsp) * len < 30 then S.prog[i] = S.prog[i] + dsp end
      end
      S.progSp[i] = sp
    end
  end
end

-- Lugar real en la largada: cuantos autos conectados parten delante, mas uno.
-- El puesto de grilla del juego cuenta tambien los cupos vacios del servidor.
local function startSlot(i, n)
  local me = ac.getCar(i)
  if not me then return 1 end
  local slot = 1
  for j = 0, n - 1 do
    local c = j ~= i and ac.getCar(j) or nil
    if c and c.isConnected ~= false and (c.racePosition or 999) < (me.racePosition or 1) then slot = slot + 1 end
  end
  return slot
end

-- Lleva a todos a su lugar de la fila. Con skipNear no se mueve a quien ya esta en su lugar. Si la fila doble
-- no cabe en esta pista, se vuelve a armar entera en una sola columna.
function RS.placeAll(n, len, skipNear)
  local wasSingle = FORM2.single
  local moved = 0
  for i = 0, n - 1 do
    local c = ac.getCar(i)
    local want = c and RS.slotSpline(startSlot(i, n), len)
    if c and not (skipNear and math.abs(c.splinePosition - want) * len < 8) and placeInFormation(i, startSlot(i, n), len) then
      moved = moved + 1
    end
  end
  if FORM2.single and not wasSingle then
    addLog('Fila doble: la pista es muy angosta en ese punto para dos autos lado a lado; se arma una sola fila')
    return RS.placeAll(n, len, false)
  end
  return moved
end

-- Offline, salida corta: los autos van a la fila apenas carga la carrera, durante la cuenta regresiva,
-- y el jugador espera las luces ahi con los controles bloqueados. Asi nadie aparece en la grilla.
function RS.preStart(sim, car, n)
  if online or cfg.startMode ~= 2 or not cfg.formShort or not isRace(sim) or not penaltiesActive() then return end
  if sim.isSessionStarted or not physicsOk() then return end
  S.preAt = S.preAt or clock
  if clock - S.preAt < 1.5 then return end
  local len = trackLen(sim)
  if not S.prePlaced then
    S.prePlaced = true
    S.preFixes, S.preFixAt = 0, clock
    FORM2.single, FORM2.logged = nil, nil
    FORM2.pickStart(len, n)
    local moved = RS.placeAll(n, len, false)
    addLog(string.format('Cuenta regresiva: %d de %d autos llevados a la fila (%s)', moved, n,
      (cfg.formTwoWide and not FORM2.single) and 'dos filas' or 'una fila'))
    S.preLock = true
    pcall(function () physics.setCarNoInput(true) end)
  elseif S.preFixes >= 5 and S.preLock then
    -- el juego los sigue devolviendo a la grilla: se espera a las luces y se hace al largar
    addLog('Cuenta regresiva: el juego mantiene los autos en la grilla; se llevan a la fila al largar')
    S.preLock = false
    pcall(function () physics.setCarNoInput(false) end)
  elseif RS.checkSides(n, len) then
    -- se probo el otro orden del ancho de la pista: la fila se armo de nuevo
  elseif S.preFixes < 5 and clock - S.preFixAt > 2 then
    -- si el juego devolvio algun auto a la grilla, se le vuelve a poner en la fila (pocas veces)
    S.preFixAt = clock
    for i = 0, n - 1 do
      local c = ac.getCar(i)
      if c and math.abs(c.splinePosition - RS.slotSpline(startSlot(i, n), len)) * len > 3 then
        S.preFixes = S.preFixes + 1
        placeInFormation(i, startSlot(i, n), len)
      end
    end
  end
end

-- Un segundo despues de armar la fila se cuentan los autos con ruedas fuera de la pista. Si hay alguno, se prueba
-- el otro orden del ancho a cada lado; si con ese quedan mas autos fuera, se vuelve al primero.
function RS.outCount(n)
  local k = 0
  for i = 0, n - 1 do
    local c = ac.getCar(i)
    if c and (c.wheelsOutside or 0) >= 2 then k = k + 1 end
  end
  return k
end

function RS.checkSides(n, len)
  if S.sidesDone or clock - S.preFixAt < 1 then return false end
  local out = RS.outCount(n)
  if not S.sidesTry then
    if out == 0 then S.sidesDone = true return false end
    S.sidesTry, S.sidesOut = true, out
    FORM2.flip = not FORM2.flip
    FORM2.single, FORM2.logged = nil, nil
    RS.placeAll(n, len, false)
    S.preFixAt = clock
    addLog(string.format('Fila: %d autos con ruedas fuera de la pista; se prueba el ancho de la pista al reves', out))
    return true
  end
  S.sidesDone = true
  if out > S.sidesOut then
    FORM2.flip = not FORM2.flip
    FORM2.single, FORM2.logged = nil, nil
    RS.placeAll(n, len, false)
    S.preFixAt = clock
    addLog(string.format('Fila: al reves quedaron %d fuera; se vuelve al orden anterior', out))
    return true
  end
  addLog(string.format('Fila: al reves quedaron %d autos fuera (antes %d); se usa este orden', out, S.sidesOut))
  return false
end

-- Offline: cada auto de la IA anda a la velocidad del que tiene delante en la fila, para que nadie adelante
-- antes de la largada. Con la verde todos aceleran, pero cada uno sigue sin poder pasar al de delante hasta
-- cruzar la meta: recien ahi queda libre. El primero de la fila queda libre con la verde.
function RS.aiFollow(dt, f, n)
  if not f.aiCapped or not f.order then return end
  f.capT = (f.capT or 0) + dt
  if f.capT < 0.2 then return end
  f.capT = 0
  f.cap, f.freed, f.prevSp, f.crossed = f.cap or {}, f.freed or {}, f.prevSp or {}, f.crossed or {}
  local pending = 0
  local two = f.short and cfg.formTwoWide and not FORM2.single
  local mySlot = f.grid or 1
  local stuck, anyMoving = 0, false
  f.stuckList = {}
  -- lider de la IA en la salida corta: sube de velocidad de a poco y afloja si la fila se estira, para que el
  -- pelotón llegue junto a la verde (antes los de adelante se iban a 60 km/h mientras los de atras arrancaban)
  f.leadCap = nil
  if f.phase == 'formation' and f.short and #f.order > 1 then
    local la, lb = ac.getCar(f.order[1]), ac.getCar(f.order[#f.order])
    local stretch = 0
    if la and lb then
      local ideal = (FORM2.spot(#f.order, two)) - (FORM2.spot(1, two))
      stretch = metersAhead(la, lb) - ideal
    end
    f.leadCap = math.floor(math.max(25, math.min(cfg.formSpeed, 30 + (clock - f.startAt) * 3, cfg.formSpeed - math.max(0, stretch - 30) * 0.5)))
  end
  for p, i in ipairs(f.order) do
    local c = i ~= 0 and not f.freed[i] and ac.getCar(i) or nil
    if c then
      -- cruce de la meta: en la salida corta se ve en la posicion en la pista (el contador del juego puede no
      -- subir); en la vuelta completa, en el contador de vueltas (el primer paso por la meta no cuenta)
      local prev = f.prevSp[i]
      if f.short and prev and prev > 0.8 and c.splinePosition < 0.2 then f.crossed[i] = true end
      if c.lapCount > (f.lap0[i] or 0) then f.crossed[i] = true end
      f.prevSp[i] = c.splinePosition
      local free = false
      -- auto de referencia: el de delante en la misma columna, a "want" metros (el segundo de la fila doble va al lado del primero)
      local ref, want = f.order[p - 1], 14
      if two then ref, want = (p > 2) and f.order[p - 2] or (p == 2 and f.order[1] or nil), (p > 2) and FORM2.ROW_GAP + 2 or FORM2.STAGGER end
      local a = ref and ac.getCar(ref) or nil
      if f.phase ~= 'formation' then
        -- con la verde la IA que larga delante tuyo queda libre: si siguiera limitada, te obligaria a pasarla.
        -- La de atras sigue sin poder pasar al de delante hasta cruzar la meta.
        if f.crossed[i] or not a or p < mySlot then free = true end
        if f.greenAt and clock - f.greenAt > 40 then free = true end
      end
      if free then
        f.freed[i] = true
        pcall(function () physics.setAITopSpeed(i, math.huge) end)
      else
        pending = pending + 1
        if c.speedKmh >= 2 then anyMoving = true end
        -- detenido: no se mueve y el auto que sigue ya anda (o no tiene a quien seguir)
        if f.phase == 'formation' and c.speedKmh < 2 and not c.isInPitlane and (not a or a.speedKmh > 5) then
          stuck = stuck + 1
          f.stuckList[#f.stuckList + 1] = i
        end
        -- antes de la verde nadie pasa del limite; despues, el techo es el auto de delante
        local top = f.phase == 'formation' and cfg.formSpeed or 400
        local cap = top
        if p == 1 and f.leadCap then cap = f.leadCap end
        if a and not a.isInPitlane then
          local gap = metersAhead(a, c)
          local slack = (two and p == 2) and 3 or 0  -- el segundo de la fila puede quedar a la altura del primero
          if gap < -slack and gap > -60 then
            cap = 30                -- se adelanto: frena hasta que el otro vuelva a quedar delante
          elseif gap >= -slack and gap < 40 then
            cap = math.max(15, math.min(top, a.speedKmh + (gap - want) * 1.5))
          end
        end
        if not f.cap[i] or math.abs(f.cap[i] - cap) >= 1 then
          f.cap[i] = cap
          pcall(function () physics.setAITopSpeed(i, cap) end)
        end
      end
    end
  end
  if pending == 0 then f.aiCapped = false end
  if f.phase == 'formation' and not anyMoving and pending > 0 then stuck = math.max(stuck, pending) end
  if f.phase == 'formation' then RS.watch(f, n, stuck) end
end

-- Si la IA no arranca en la formacion: primero se la despierta, despues (en fila doble) se arma una sola
-- fila y, si aun asi no se mueve, se le quita el limite. Todo queda en el registro para poder revisarlo.
-- Lleva un auto detenido a la linea de la IA, un par de metros mas adelante, si no hay otro auto ahi.
function RS.unstick(i, len)
  local c = ac.getCar(i)
  if not c then return false end
  return pcall(function ()
    local a = ac.trackProgressToWorldCoordinate(c.splinePosition + 2 / len)
    local b = ac.trackProgressToWorldCoordinate(c.splinePosition + 4 / len)
    local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
    local dd = vlen(dx, dy, dz)
    if dd < 0.001 then error('sin direccion') end
    for j = 0, ac.getSim().carsCount - 1 do
      local o = j ~= i and ac.getCar(j)
      if o and vlen(o.position.x - a.x, o.position.y - a.y, o.position.z - a.z) < 6 then error('ocupado') end
    end
    physics.setCarPosition(i, vec3(a.x, a.y + 0.2, a.z), vec3(-dx / dd, -dy / dd, -dz / dd))
    pcall(physics.awakeCar, i)
  end)
end

function RS.watch(f, n, stuck)
  if not f.short or clock - f.startAt < 1.5 then return end
  f.stillT = stuck > 0 and (f.stillT or 0) + 0.2 or 0
  if f.stillT < ((f.wakes or 0) == 0 and 2 or 3) then return end
  f.stillT = 0
  f.wakes = (f.wakes or 0) + 1
  local parts = {}
  for p = 1, math.min(#f.order, 4) do
    local i = f.order[p]
    local c = ac.getCar(i)
    if c then
      parts[#parts + 1] = string.format('auto %d: %.0f km/h, limite %s', i, c.speedKmh, tostring(f.cap[i] or '-'))
    end
  end
  addLog('Formacion: la IA no arranca (detenidos: ' .. table.concat(f.stuckList, ', ') .. '; ' .. table.concat(parts, '; ') .. ')')
  local ai = 0
  for _, i in ipairs(f.order) do if i ~= 0 then ai = ai + 1 end end
  if f.wakes == 1 then
    for _, i in ipairs(f.order) do
      if i ~= 0 then pcall(physics.awakeCar, i) end
    end
    f.cap = {}
    addLog('Formacion: se despierta a la IA')
  elseif f.wakes <= 3 and stuck < math.max(2, math.ceil(ai / 2)) then
    -- uno o pocos autos detenidos: solo esos van a la linea de la IA; el resto de la fila sigue igual
    local len = trackLen(ac.getSim())
    for _, i in ipairs(f.stuckList) do
      addLog(string.format('Formacion: auto %d llevado a la linea de la IA: %s', i, RS.unstick(i, len) and 'si' or 'no (lugar ocupado)'))
    end
  elseif f.wakes <= 3 and cfg.formTwoWide and not FORM2.single then
    -- casi toda la IA detenida: se arma la fila de nuevo, en una sola columna
    FORM2.single = true
    RS.placeAll(n, trackLen(ac.getSim()), false)
    f.startAt, f.mid, f.cap = clock, {}, {}
    addLog('Formacion: la IA sigue detenida en la fila doble; se arma una sola fila')
    note(1, tr('La IA no arrancó en dos filas: se larga en una sola fila'), 1, false)
  elseif f.wakes <= 4 then
    for _, i in ipairs(f.order) do
      if i ~= 0 then
        f.freed[i] = true
        pcall(function () physics.setAITopSpeed(i, math.huge) end)
      end
    end
    addLog('Formacion: la IA sigue detenida; se le quita el limite de velocidad')
  end
end

local function updateRolling(dt, sim, car, n)
  if cfg.startMode ~= 2 or not isRace(sim) or not penaltiesActive() then return end
  local f = S.form
  if f and f.aiCapped and not online then RS.aiFollow(dt, f, n) end
  if not f then
    if not sim.isSessionStarted or car.lapCount > 0 or car.isInPitlane then return end
    if sim.timeToSessionStart < -4000 then
      S.form = { phase = 'done' }          -- la app se cargo con la carrera ya largada
      return
    end
    f = { phase = 'formation', overT = 0, speedPen = false, ahead = {}, passT = {}, aiCapped = false, grid = startSlot(0, n),
      short = cfg.formShort, startAt = clock, mid = {} }
    for j = 1, n - 1 do
      local c = ac.getCar(j)
      if c and c.racePosition < car.racePosition then f.ahead[#f.ahead + 1] = j end
    end
    -- orden de la fila: indices de los autos segun su lugar de partida
    f.order = {}
    for i = 0, n - 1 do
      if ac.getCar(i) then f.order[#f.order + 1] = i end
    end
    table.sort(f.order, function (x, y) return startSlot(x, n) < startSlot(y, n) end)
    f.lap0 = {}
    for _, i in ipairs(f.order) do f.lap0[i] = ac.getCar(i).lapCount end
    S.form = f
    if not online and n > 1 then
      -- contra la IA solo sirve si el juego deja limitarle la velocidad
      if physicsOk() then
        for j = 1, n - 1 do pcall(function () physics.setAITopSpeed(j, cfg.formSpeed) end) end
        f.aiCapped = true
      else
        S.form = { phase = 'done' }
        announce(1, tr('SALIDA LANZADA NO DISPONIBLE'), tr('Esta pista no permite controlar a la IA. Se usa la salida parada'), 1)
        return
      end
    end
    if f.short and not online then
      -- offline la app misma lleva los autos a la fila (online lo hace el script del servidor)
      if not S.prePlaced then
        FORM2.single = nil
        FORM2.pickStart(trackLen(sim), n)
      end
      RS.placeAll(n, trackLen(sim), S.prePlaced)
    end
    if f.short then
      announce(1, tr('SALIDA LANZADA'),
        tr('Mantén tu puesto y no pases de %s km/h. Se larga cuando el líder llegue a la meta', cfg.formSpeed), 1)
    else
      announce(1, tr('VUELTA DE FORMACIÓN'),
        tr('Mantén tu puesto y no pases de %s km/h. Se larga cuando el líder cruce la meta', cfg.formSpeed), 1)
    end
    if S.prePlaced or online then RS.pickRadar(f, n) end
    S.flag = { kind = 'yellow', untilTime = clock + 7 }
    return
  end
  if f.phase == 'done' then return end

  if f.phase == 'formation' then
    local leaderCrossed = false
    for i = 0, n - 1 do
      local c = ac.getCar(i)
      if c then
        -- el contador de vueltas puede llegar con retraso: tambien se mira la posicion en la pista
        local sp = c.splinePosition
        local len = trackLen(sim)
        -- la verde sale un poco antes de la meta, para que el auto ya este libre al cruzarla
        local early = cfg.formGreen > 0 and sp >= 1 - cfg.formGreen / len
        if f.short then
          -- salida corta: cuenta el auto que ya esta en la fila, antes del punto de la verde
          if clock - f.startAt > 1.5 and not early and sp < 0.999 and sp > 1 - (FORM2.startMeters() + 400) / len then f.mid[i] = true end
        elseif sp > 0.4 and sp < 0.7 then
          f.mid[i] = true
        end
        local rolling = c.speedKmh > 5 and not c.isInPitlane and not c.isInPit
        if rolling and (c.lapCount >= 1 or (f.mid[i] and (sp < 0.15 or early))) then leaderCrossed = true end
      end
    end
    -- salida corta: si a los 3 segundos este auto no esta en la fila, nadie lo movio (no hay script del servidor
    -- ni permiso en la pista): se sigue como una vuelta de formacion completa
    if f.short and not f.checked and clock - f.startAt > 3 then
      f.checked = true
      if not f.mid[0] then
        f.short = false
        f.mid = {}
        note(1, tr('Salida corta no disponible aquí: vuelta de formación completa'), 1, false)
      end
    end
    if leaderCrossed then
      f.phase = 'green'
      f.greenAt = clock
      S.lights = { start = clock }
      announce(0, tr('BANDERA VERDE'), car.lapCount >= 1 and tr('Carrera lanzada')
        or tr('Carrera lanzada. Puedes adelantar después de cruzar la meta'), 1)
    else
      if car.speedKmh > cfg.formSpeed + 10 and not car.isInPitlane then
        f.overT = f.overT + dt
        if car.speedKmh > (f.top or 0) then f.top = car.speedKmh end
      else
        f.overT = math.max(0, f.overT - dt)
      end
      if f.overT > 2 and not f.speedPen then
        f.speedPen = true
        local reason = tr('Exceso de velocidad en la vuelta de formación')
        if not cfg.tiers then issuePenalty(cfg.jumpPenalty, reason, car)
        elseif f.top > cfg.formSpeed * RP.formRatio then issuePenalty(KIND_SG, reason, car, 1, RP.formSg)
        else issuePenalty(KIND_DT, reason, car) end
      end
    end
  end

  -- hasta cruzar la meta no se puede adelantar a quien largo delante
  if f.phase == 'green' and car.splinePosition > 0.7 then f.nearEnd = true end
  local crossedLine = car.lapCount >= 1 or (f.phase == 'green' and f.nearEnd and car.splinePosition < 0.15)
  if crossedLine or (f.greenAt and clock - f.greenAt > 40) then
    f.phase = 'done'
    return
  end
  -- en la salida corta se dan unos segundos para que todos queden en su lugar de la fila
  if f.short and clock - f.startAt < 4 then return end
  if not S.giveback then
    for _, j in ipairs(f.ahead) do
      local c = ac.getCar(j)
      -- en la fila doble, el que larga a tu lado puede quedar unos metros detras sin que sea adelantamiento
      local tol = (f.short and FORM2.sameRow(startSlot(j, n), f.grid or 1)) and 8 or 3
      if c and c.speedKmh > 30 and not c.isInPitlane and (c.wheelsOutside or 0) < 3 and metersAhead(c, car) < -tol then
        f.passT[j] = (f.passT[j] or 0) + dt
        if f.passT[j] > 1.5 then
          f.passT[j] = 0
          if cfg.tiers then
            startGiveback(j, tr('Adelantamiento antes de la largada'), KIND_SG, 1, false, car, RP.formSg)
          else
            startGiveback(j, tr('Adelantamiento antes de la largada'), cfg.jumpPenalty, 1, false, car)
          end
          break
        end
      else
        f.passT[j] = 0
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- 8c. BANDERAS
--     Verde: pista libre.   Amarilla: peligro adelante, prohibido adelantar.
--     Azul: viene alguien que te saca una vuelta.   Blanca: ultima vuelta.   A cuadros: meta.
--     Negra: descalificado.   Amarilla total y roja: las decreta la direccion de carrera.
-- ---------------------------------------------------------------------------

local CTL_NAMES = { [0] = N_('bandera verde'), N_('amarilla total'), N_('bandera roja') }

-- Cambia el estado de la pista. "who" es el director que lo ordeno (nil si fue en este mismo juego).
applyControl = function (state, speed, who)
  local c = S.ctl
  if state ~= 1 and state ~= 2 then state = 0 end
  speed = math.max(30, math.min(250, speed or cfg.fcySpeed))
  c.at = clock
  if c.state == state then
    c.speed = speed
    return
  end
  c.state, c.speed, c.since, c.overT, c.punished = state, speed, clock, 0, false
  S.rfs.ahead, S.rfs.passT, S.rfs.passed = {}, {}, {}
  net.ctlTimer = 100
  if not cfg.enabled or not cfg.flEnabled then return end
  local car = ac.getCar(0)
  local lap = car and (car.lapCount + 1) or nil
  local by = who and tr('. Orden de %s', who) or ''
  if state == 1 then
    announce(1, tr('AMARILLA TOTAL'), tr('Máximo %s km/h y prohibido adelantar', speed) .. by, lap, 'fcy')
  elseif state == 2 then
    announce(3, tr('BANDERA ROJA'), tr('Sesión detenida: máximo %s km/h, sin adelantar, vuelve a pits', speed) .. by, lap, 'red')
  else
    S.rfs.greenUntil = clock + 6
    announce(0, tr('BANDERA VERDE'), tr('Pista libre') .. by, lap, 'green')
  end
  -- contra la IA: tambien baja la velocidad, si la pista deja controlarla
  if not online and curSim and curSim.carsCount > 1 and physicsOk() then
    for j = 1, curSim.carsCount - 1 do
      pcall(function () physics.setAITopSpeed(j, state ~= 0 and speed or math.huge) end)
    end
    c.aiCapped = state ~= 0
  end
end

local function updateFlags(dt, sim, car, n, race, laps)
  if not cfg.flEnabled then
    S.rf = nil
    return
  end
  local r = S.rfs
  local c = S.ctl
  local d = D(0)
  local lap = car.lapCount + 1
  local live = sim.isSessionStarted and not car.isRaceFinished and not car.isInPitlane
  local forming = S.form and S.form.phase == 'formation'
  -- en los primeros segundos de una largada parada todos van lentos: no es peligro
  local settled = not race or sim.timeToSessionStart < -15000

  local hazard, hazardDist = nil, 1e9
  local blueJ, blueDist = nil, 1e9
  if live and settled and not forming then
    local prog = S.prog or {}
    local myProgress = prog[0] or (car.lapCount + car.splinePosition)
    local reach = math.max(30, car.speedKmh / 3.6 * 2.5)   -- 2,5 segundos de pista
    for j = 1, n - 1 do
      local o = ac.getCar(j)
      if o and o.isConnected ~= false and not o.isInPitlane and not o.isRaceFinished then
        local ahead = metersAhead(o, car)
        local danger = o.speedKmh < 30 or (not online and outOfControl(j))
        if danger and ahead > 5 and ahead < cfg.yfDist and ahead < hazardDist then
          hazard, hazardDist = j, ahead
        end
        if cfg.bfEnabled and not danger and ahead < 0 and -ahead < reach and -ahead < blueDist then
          local lapping
          if race then
            lapping = (prog[j] or (o.lapCount + o.splinePosition)) - myProgress > 0.5
          else
            lapping = o.speedKmh > car.speedKmh + 40
          end
          if lapping then blueJ, blueDist = j, -ahead end
        end
      end
    end
  end

  -- amarilla local
  local wasYellow = clock < r.yellowUntil
  if hazard then
    r.yellowUntil = clock + 2
    if not wasYellow and clock - r.lastYellowMsg > 20 then
      r.lastYellowMsg = clock
      announce(1, tr('BANDERA AMARILLA'),
        tr('%s detenido o sin control a %s m. Prohibido adelantar', driverName(hazard), round(hazardDist)), lap, 'yellow')
    end
  elseif wasYellow and clock + dt >= r.yellowUntil then
    r.greenUntil = clock + 5
  end
  local yellow = clock < r.yellowUntil

  -- prohibido adelantar con amarilla, amarilla total o roja
  local noPass = live and (yellow or c.state ~= 0)
  if noPass then
    r.clearAt = clock + 6
    if cfg.yfPass and penaltiesActive() and not forming then
      for j = 1, n - 1 do
        local o = ac.getCar(j)
        if o and j ~= hazard and o.isConnected ~= false and not o.isInPitlane and o.speedKmh > 50
          and (online or not outOfControl(j)) then
          local a = metersAhead(o, car)
          if a > 2 and a < 80 then r.ahead[j] = clock end
          if r.ahead[j] and clock - r.ahead[j] < 6 and a < -3 and not r.passed[j] then
            r.passT[j] = (r.passT[j] or 0) + dt
            if r.passT[j] > 1.2 then
              r.passed[j] = true
              startGiveback(j, c.state == 2 and tr('Adelantamiento con bandera roja') or tr('Adelantamiento con bandera amarilla'), cfg.yfPenalty, 1, false, car)
            end
          else
            r.passT[j] = 0
          end
        end
      end
    end
  elseif r.clearAt and clock > r.clearAt then
    r.clearAt = nil
    r.ahead, r.passT, r.passed = {}, {}, {}
  end

  -- velocidad con amarilla total o roja (8 segundos de gracia para frenar)
  if c.state ~= 0 and live and penaltiesActive() and clock - c.since > 8 and car.speedKmh > c.speed + 10 then
    c.overT = c.overT + dt
    if c.overT > 3 and not c.punished then
      c.punished = true
      issuePenalty(cfg.yfPenalty, tr('Exceso de velocidad con %s', tr(CTL_NAMES[c.state])), car)
    end
  else
    c.overT = math.max(0, (c.overT or 0) - dt)
  end

  -- azul
  if blueJ then
    if r.blueJ ~= blueJ or clock >= r.blueUntil then
      if r.blueJ ~= blueJ then r.blueT = 0 end
      r.blueJ = blueJ
      if clock - (r.blueMsg or -100) > 15 or r.blueMsgJ ~= blueJ then
        r.blueMsg, r.blueMsgJ = clock, blueJ
        announce(1, tr('BANDERA AZUL'), race and tr('Deja pasar a %s, te saca una vuelta', driverName(blueJ))
          or tr('Deja pasar a %s, viene más rápido', driverName(blueJ)),
          lap, 'blue')
      end
    end
    r.blueUntil = clock + 1.5
    r.blueT = r.blueT + dt
    if race and cfg.bfPenalty ~= KIND_NONE and r.blueT > cfg.bfSec and not r.bluePunished[blueJ] then
      r.bluePunished[blueJ] = true
      issuePenalty(cfg.bfPenalty, tr('No cediste el paso a %s con bandera azul', driverName(blueJ)), car)
    end
  elseif clock >= r.blueUntil then
    r.blueJ = nil
    r.blueT = 0
  end

  -- blanca: ultima vuelta
  if race and laps > 1 and car.lapCount == laps - 1 and not r.whiteDone and not car.isRaceFinished then
    r.whiteDone = true
    r.whiteUntil = clock + 10
    announce(0, tr('ÚLTIMA VUELTA'), '', lap, 'white')
  end
  -- verde al largar
  if race and sim.isSessionStarted and not r.started then
    r.started = true
    if cfg.startMode ~= 2 and sim.timeToSessionStart > -4000 then r.greenUntil = clock + 6 end
  end

  -- la bandera vigente, por orden de importancia
  local rf
  if d.dq then rf = { kind = 'black', label = tr('NEGRA') }
  elseif car.isRaceFinished then rf = { kind = 'check', label = tr('META') }
  elseif c.state == 2 then rf = { kind = 'red', label = tr('ROJA · MÁX %s', c.speed) }
  elseif c.state == 1 then rf = { kind = 'fcy', label = tr('AMARILLA TOTAL · MÁX %s', c.speed) }
  elseif yellow then rf = { kind = 'yellow', label = tr('AMARILLA · NO ADELANTAR') }
  elseif clock < r.blueUntil and r.blueJ then rf = { kind = 'blue', label = tr('AZUL · CEDE EL PASO') }
  elseif clock < r.whiteUntil then rf = { kind = 'white', label = tr('ÚLTIMA VUELTA') }
  elseif clock < r.greenUntil then rf = { kind = 'green', label = tr('VERDE') }
  end
  S.rf = rf
end

-- ---------------------------------------------------------------------------
-- 9. FIN DE CARRERA Y CLASIFICACION CORREGIDA
-- ---------------------------------------------------------------------------

local function sessionLaps(sim)
  local ok, s = pcall(ac.getSession, sim.currentSessionIndex)
  if ok and s and s.laps and s.laps > 0 then return s.laps end
  return 0
end

local function finishRace(sim, car)
  S.finished = true
  S.finishedAt = clock
  local d = D(0)
  for _, p in ipairs(d.penalties) do
    local add = p.kind == KIND_LIFT and cfg.liftFailSec or (cfg.dtFailSec + (p.kind == KIND_SG and p.late and p.need or 0))
    d.timePenalty = d.timePenalty + add
    addLog(KIND_NAMES[p.kind] .. ' pendiente al final: +' .. add .. ' s')
  end
  d.penalties = {}
  if S.giveback then
    -- posicion sin devolver al terminar: la sancion pasa a tiempo
    local gb = S.giveback
    local add = gb.kind == KIND_TIME and cfg.timeSec * (gb.mult or 1) or (gb.kind == KIND_NONE and 0 or cfg.dtFailSec)
    d.timePenalty = d.timePenalty + add
    addLog('Posicion sin devolver a ' .. gb.name .. ' al final: +' .. add .. ' s')
    S.giveback = nil
  end
  releaseAllAi()

  -- la IA que no alcanzo a cumplir en pista recibe el tiempo en la clasificacion
  for i = 1, sim.carsCount - 1 do
    local o = ac.getCar(i)
    local di = D(i)
    for _, p in ipairs(di.aiPens) do
      di.timePenalty = di.timePenalty + (p.kind == KIND_DT and cfg.aiDtSec or cfg.liftSec)
    end
    if #di.aiPens > 0 then
      aiThrottle(i, 1)
      aiPitRequest(i, false)
      di.aiPens = {}
    end
    -- los que aun no cruzan la meta: se estima cuando lo haran
    if o and not di.finishClock then
      local lapTime = (o.bestLapTimeMs and o.bestLapTimeMs > 0) and (o.bestLapTimeMs / 1000) or 100
      di.finishClock = clock + (1 - o.splinePosition) * lapTime
      di.finishLaps = o.lapCount + 1
      di.estimated = true
    end
  end

  announce(d.timePenalty > 0 and 2 or 0, tr('CARRERA TERMINADA'),
    tr('Sanción total: +%s s.  Incidentes: %sx', d.timePenalty, d.points), car.lapCount, 'check')
  addLog(string.format('RESUMEN  incidentes=%dx  salidas=%d  contactos=%d  trompos=%d  sanciones=%d  cumplidas=%d  tiempo=+%d s',
    d.points, d.tlCuts, d.contacts, d.spins, d.penCount, d.served, d.timePenalty))
  saveLog()
end

-- Lista de pilotos ordenada. Con la carrera terminada, el orden ya incluye las sanciones.
local function standings(sim)
  local rows = {}
  for i = 0, sim.carsCount - 1 do
    local car = ac.getCar(i)
    if car then
      local d = D(i)
      rows[#rows + 1] = {
        i = i, name = i == 0 and 'TÚ' or driverName(i), d = d,
        pos = car.racePosition, laps = d.finishLaps or car.lapCount,
        total = d.finishClock and (d.finishClock + d.timePenalty) or nil,
        pending = d.aiPens[1] or (d.remotePending ~= 0 and { kind = d.remotePending } or nil),
        noApp = online and i ~= 0 and not (d.hasApp and clock - d.lastSeen < 20),
      }
    end
  end
  local corrected = S.finished
  table.sort(rows, function (x, y)
    if corrected then
      if x.d.dq ~= y.d.dq then return y.d.dq end
      if x.total and y.total then
        if x.laps ~= y.laps then return x.laps > y.laps end
        if x.total ~= y.total then return x.total < y.total end
      elseif x.total or y.total then
        return x.total ~= nil
      end
    end
    return x.pos < y.pos
  end)
  return rows, corrected
end

-- Ganador de la carrera, con las sanciones ya aplicadas. Se anuncia cuando todos cruzaron la meta
-- o, como maximo, 12 segundos despues de que cruzo este auto.
local function announceWinner(sim, car)
  if clock - S.finishedAt < 3 then return end
  local allIn = true
  for i = 0, sim.carsCount - 1 do
    local c = ac.getCar(i)
    local d = D(i)
    if c and c.isConnected ~= false and not d.dq and (not d.finishClock or d.estimated) then allIn = false end
  end
  if not allIn and clock - S.finishedAt < 12 then return end
  S.winnerDone = true
  local rows = standings(sim)
  local w = rows[1]
  if not w or w.d.dq or not w.total then return end
  -- quien cruzo primero la meta en la pista
  local first = nil
  for _, r in ipairs(rows) do
    if r.d.finishClock and not r.d.estimated then
      if not first or r.laps > first.laps or (r.laps == first.laps and r.d.finishClock < first.d.finishClock) then first = r end
    end
  end
  local detail = tr('Resultado con las sanciones aplicadas')
  if first and first.i ~= w.i then
    local name, pen = driverName(first.i), first.d.timePenalty
    if first.i == 0 then
      detail = first.d.dq and tr('Cruzaste primero la meta, pero estás descalificado')
        or tr('Cruzaste primero la meta, pero tienes +%s s de sanción', pen)
    else
      detail = first.d.dq and tr('%s cruzó primero la meta, pero está descalificado', name)
        or tr('%s cruzó primero la meta, pero tiene +%s s de sanción', name, pen)
    end
  end
  S.winner = w.i == 0 and tr('TÚ') or driverName(w.i)
  announce(0, w.i == 0 and tr('GANASTE LA CARRERA') or tr('GANADOR: %s', driverName(w.i)), detail, car.lapCount, 'check')
end

-- Descalificado: no puede seguir corriendo. Online lo frena el script del servidor; offline, la app,
-- si la pista le da permiso. Queda en 50 km/h para que pueda volver a pits.
local dqInputLocked = false   -- los controles estan bloqueados por descalificacion (offline)

local function enforceDq(car)
  if not D(0).dq then
    S.dqPitAt = nil
    if dqInputLocked then
      dqInputLocked = false
      pcall(function () physics.setCarNoInput(false) end)
    end
    return
  end
  -- ya en pits, el auto queda sin controles
  if car.isInPitlane and not dqInputLocked and S.dqPitAt and clock - S.dqPitAt > 0.5 then
    pcall(function ()
      if physics.allowed() then
        physics.setCarNoInput(true)
        dqInputLocked = true
      end
    end)
  end
  if car.isInPitlane then return end
  -- se le envia a su box, y de nuevo cada vez que vuelva a salir a la pista
  if not S.dqPitAt or clock - S.dqPitAt > 6 then
    S.dqPitAt = clock
    pcall(function ()
      if physics.allowed() then physics.teleportCarTo(0, ac.SpawnSet.Pits) end
    end)
  end
  if car.speedKmh <= DQ_SPEED then return end
  pcall(function ()
    if physics.allowed() then physics.forceUserThrottleFor(0.1, 0) end
  end)
end

-- ---------------------------------------------------------------------------
-- 10. CICLO PRINCIPAL (el juego llama a esta funcion en cada cuadro)
-- ---------------------------------------------------------------------------

local function step(dt)
  local sim = ac.getSim()
  local car = ac.getCar(0)
  curSim = sim
  online = sim.isOnlineRace == true
  if not online and ruleOverride then
    ruleOverride = nil
    net.rulesFrom = nil
  end
  readServer()
  if not car then return end
  if sim.isPaused or sim.isReplayActive then return end
  if dt > 0.25 then dt = 0.25 end
  clock = clock + dt

  if car.lapCount < S.lastLapCount then
    releaseAllAi()
    resetSession()
  end
  S.lastLapCount = car.lapCount
  -- carrera reiniciada desde el menu: la cuenta regresiva vuelve a empezar y el juego no siempre avisa
  local started = sim.isSessionStarted == true
  if S.wasStarted and not started then
    releaseAllAi()
    resetSession()
  end
  S.wasStarted = started
  if S.preLock and started then
    S.preLock = false
    pcall(function () physics.setCarNoInput(false) end)
  end

  -- vuelta recien terminada: en clasificacion se anota si fue valida
  if car.lapCount > S.lapSeen then
    local done = car.lapCount
    local ms = car.previousLapTimeMs or 0
    if cfg.enabled and sessionMode() == 'qualy' and ms > 0 then
      if S.invalidLap == done then
        note(2, tr('Vuelta %s no cuenta: %s', done, lapStr(ms)), done, false)
      elseif not S.bestValid or ms < S.bestValid then
        S.bestValid = ms
        note(0, tr('Mejor vuelta válida: %s', lapStr(ms)), done, false)
      end
    end
    S.lapSeen = car.lapCount
  end

  if not cfg.enabled then return end

  checkJumpStart(sim, car)

  local n = sim.carsCount
  RS.preStart(sim, car, n)
  RS.progress(sim, n)
  local race = isRace(sim)
  local laps = race and sessionLaps(sim) or 0
  S.raceLaps = laps
  local running = sim.isSessionStarted and not car.isRaceFinished

  if running then
    checkCollisions(sim)
    updateReviews()
    checkPitSpeed(dt, car)
    updatePenalties(dt, car)
    checkOffTrackPass(car, n)
    updateGiveback(dt, car)
    updateRolling(dt, sim, car, n)
  end

  for i = 0, n - 1 do
    local c = ac.getCar(i)
    if c then
      local d = D(i)
      -- llegada a meta de cada auto
      if race and not d.finishClock and (c.isRaceFinished or (laps > 0 and c.lapCount >= laps)) then
        d.finishClock = clock
        d.finishLaps = c.lapCount
      elseif race and d.estimated and c.isRaceFinished then
        d.finishClock = clock
        d.finishLaps = c.lapCount
        d.estimated = false
      end
      if running then updateWallWatch(i, c, dt) end
      if running and (i == 0 or watchOthers()) and not d.finishClock then
        checkTrackLimits(dt, i, c)
        checkSpin(dt, i, c)
      end
      if i ~= 0 and not online then updateAiPenalties(dt, i, c, running, n) end
      -- se guarda la velocidad de este cuadro para medir el proximo golpe
      d.pvx, d.pvy, d.pvz = c.velocity.x, c.velocity.y, c.velocity.z
      d.prevSpeed = c.speedKmh
    end
  end

  applyDeferred()
  updateFlags(dt, sim, car, n, race, laps)

  if race and car.isRaceFinished and not S.finished then
    finishRace(sim, car)
  end
  if S.finished and not S.winnerDone then announceWinner(sim, car) end
  enforceDq(car)

  if online then netUpdate(dt) end

  logSaveTimer = logSaveTimer + dt
  if logSaveTimer > 5 then
    logSaveTimer = 0
    saveLog()
  end
end

function script.update(dt)
  local ok, err = pcall(step, dt)
  if not ok and lastError ~= tostring(err) then
    lastError = tostring(err)
    addLog('ERROR: ' .. lastError)
    saveLog()
  end
end

ac.onSessionStart(function ()
  saveLog()
  releaseAllAi()
  resetSession()
  local okSim, sim = pcall(ac.getSim)
  addLog('--- Nueva sesión: ' .. (okSim and sessionName(sim) or '?') ..
    '  pista=' .. tostring(ac.getTrackID()) .. '  auto=' .. tostring(ac.getCarID(0)) ..
    '  Comisario ' .. VERSION .. ' ---')
end)

-- al cerrar la app, la IA queda sin limites de velocidad
ac.onRelease(function ()
  releaseAllAi()
  saveLog()
end)

addLog('=== Comisario ' .. VERSION .. ' cargado ===')
-- Estilo nuevo (1.4): interfaz fija y sin fondo. Se aplica una vez al actualizar; despues queda como el piloto lo deje.
-- Las ventanas sueltas de los indicadores se cierran, porque con la interfaz fija ya no se usan.
if stored.uiVersion < 2 then
  stored.uiVersion = 2
  stored.hudY = 22
  stored.hudBg = false
  stored.hudFixed = true
  stored.startHudShown = true
  for _, id in ipairs({ 'hud_msg', 'hud_pen', 'hud_status', 'hud_start' }) do
    pcall(function () ac.setWindowOpen(id, false) end)
  end
end

-- 1.5: la columna baja para no tapar el espejo virtual. Solo se mueve si seguia en el lugar de fabrica anterior.
if stored.uiVersion < 3 then
  stored.uiVersion = 3
  if stored.hudY == 10 then stored.hudY = 22 end
end

-- ---------------------------------------------------------------------------
-- 11. PANEL EN PANTALLA
-- ---------------------------------------------------------------------------

local function levelColor(level)
  if level == 0 then return COL_GREEN end
  if level == 1 then return COL_YELLOW end
  if level == 2 then return COL_ORANGE end
  if level == 3 then return COL_RED end
  return COL_GREY
end

local function levelBg(level)
  if level == 0 then return BG_GREEN end
  if level == 1 then return BG_YELLOW end
  if level == 2 then return BG_ORANGE end
  if level == 3 then return BG_RED end
  return BG_GREY
end

local function drawBanner()
  local b = S.banner
  if not b or clock > b.untilTime then return end
  local c = ui.getCursor()
  local w = ui.availableSpaceX()
  ui.drawRectFilled(c, vec2(c.x + w, c.y + 46), levelBg(b.level), 6)
  ui.setCursor(vec2(c.x + 10, c.y + 5))
  ui.pushFont(ui.Font.Title)
  ui.text(b.title)
  ui.popFont()
  ui.setCursor(vec2(c.x + 10, c.y + 27))
  ui.text(b.detail)
  ui.setCursor(vec2(c.x, c.y + 52))
end

local function dtStateText(p, car)
  local lapsLeft = math.max(0, p.lapIssued + cfg.dtLaps - car.lapCount)
  if p.kind == KIND_SG and p.phase == 'in' then
    return tr('detente en pits: %.0f / %d s', p.stopT, p.need)
  end
  if p.phase == 'in' then return tr('pasando por pits, no te detengas') end
  if lapsLeft == 0 then return tr('entra a pits en esta vuelta') end
  return tr('entra a pits, quedan %s vueltas', lapsLeft)
end

local function drawPenalty(p, car)
  if p.kind == KIND_LIFT then
    local left = math.max(0, p.deadline - clock)
    ui.textColored(tr('LEVANTA EL PIE: %.1f / %d s   (quedan %.0f s)', p.done, p.need, left), COL_ORANGE)
  else
    ui.textColored((p.kind == KIND_SG and 'STOP AND GO: ' or 'DRIVE-THROUGH: ') .. dtStateText(p, car), COL_RED)
  end
  ui.textColored(tr('   Motivo: %s', p.reason), COL_DIM)
end

local function aiStatusText()
  if online then
    local count = 0
    for i, d in pairs(S.d) do
      if i ~= 0 and d.hasApp and clock - d.lastSeen < 20 then count = count + 1 end
    end
    local rules = tr('reglas: las tuyas')
    if net.rulesFrom then rules = tr('reglas: las de %s', net.rulesFrom)
    elseif serverAuth ~= 0 and isAdmin() then rules = tr('eres el administrador')
    elseif lockedNow then rules = tr('reglamento por defecto, a la espera del administrador')
    elseif stored.director then rules = tr('eres el director de carrera') end
    if serverOverride then rules = rules .. tr(', salida impuesta por el servidor')
    elseif serverLinked then rules = rules .. tr(', enlazado con el script del servidor') end
    return tr('Online: %s pilotos más con Comisario, %s', count, rules), net.ok and COL_GREEN or COL_YELLOW
  end
  if cfg.aiMode == 0 then return tr('IA: sin vigilar'), COL_DIM end
  if cfg.aiMode == 1 then return tr('IA: sanción en la clasificación'), COL_DIM end
  if S.aiControl == false then return tr('IA: el juego ignora las órdenes, sanción en la clasificación'), COL_YELLOW end
  if not physicsOk() then return tr('IA: esta pista no permite controlarla, sanción en la clasificación (ver ajustes)'), COL_YELLOW end
  return tr('IA: cumple en pista (levanta el pie o entra a pits)'), COL_GREEN
end

function script.windowMain(dt)
  local sim = ac.getSim()
  local car = ac.getCar(0)
  if not car then
    ui.text(tr('Esperando al auto...'))
    return
  end
  local d = D(0)

  ui.pushFont(ui.Font.Title)
  ui.text('COMISARIO')
  ui.popFont()
  ui.sameLine(0, 10)
  if not cfg.enabled then
    ui.textColored(tr('desactivado'), COL_DIM)
  elseif sessionMode() == 'race' then
    ui.textColored(sessionName(sim) .. tr(' - sanciones activas'), COL_GREEN)
  elseif sessionMode() == 'qualy' then
    ui.textColored(sessionName(sim) .. tr(' - solo se invalida la vuelta'), COL_YELLOW)
  else
    ui.textColored(sessionName(sim) .. tr(' - solo se cuenta, sin sanciones'), COL_YELLOW)
  end

  if lastError then
    ui.textColored(tr('Error interno (envíaselo a quien te ayuda):'), COL_RED)
    ui.textWrapped(lastError)
  end

  drawBanner()

  if cfg.enabled and cfg.flEnabled then
    local rf = S.rf
    ui.text(tr('Bandera:'))
    ui.sameLine(0, 6)
    if rf then
      ui.textColored(rf.label, (rf.kind == 'red' or rf.kind == 'black') and COL_RED
        or ((rf.kind == 'yellow' or rf.kind == 'fcy') and COL_YELLOW or (rf.kind == 'green' and COL_GREEN or COL_WHITE)))
    else
      ui.textColored(tr('pista libre'), COL_DIM)
    end
    -- direccion de carrera: offline la maneja el jugador; online, solo el director
    if not online or amDirector() then
      ui.sameLine(0, 14)
      if ui.button(tr('Amarilla total')) then applyControl(1, cfg.fcySpeed, nil) end
      ui.sameLine(0, 4)
      if ui.button(tr('Roja')) then applyControl(2, cfg.fcySpeed, nil) end
      ui.sameLine(0, 4)
      if ui.button(tr('Verde')) then applyControl(0, cfg.fcySpeed, nil) end
    end
  end

  if d.dq then ui.textColored(tr('DESCALIFICADO'), COL_RED) end
  if S.giveback then
    ui.textColored(tr('DEVUELVE LA POSICIÓN a %s (quedan %.0f s)', S.giveback.name,
      math.max(0, S.giveback.deadline - clock)), COL_ORANGE)
  end

  if cfg.incEnabled then
    ui.text(tr('Incidentes:'))
    ui.sameLine(0, 6)
    local limit = cfg.incStep > 0 and tr(' (sanción cada %sx)', cfg.incStep) or ''
    if cfg.incDQ > 0 then limit = limit .. tr(' (máximo %sx)', cfg.incDQ) end
    ui.textColored(d.points .. 'x' .. limit, d.points > 0 and COL_YELLOW or COL_GREEN)
  end

  if cfg.tlPenalty ~= KIND_NONE then
    local warnColor = COL_WHITE
    if d.tlWarnings >= cfg.tlWarnings then warnColor = COL_RED
    elseif d.tlWarnings > 0 then warnColor = COL_YELLOW end
    ui.text(tr('Límites de pista:'))
    ui.sameLine(0, 6)
    ui.textColored(tr('%s/%s avisos', math.min(d.tlWarnings, cfg.tlWarnings), cfg.tlWarnings), warnColor)
  end

  ui.text(tr('Sanción de tiempo:'))
  ui.sameLine(0, 6)
  ui.textColored('+' .. d.timePenalty .. ' s', d.timePenalty > 0 and COL_RED or COL_GREEN)
  ui.sameLine(0, 14)
  ui.textColored(tr('salidas %s  contactos %s  cumplidas %s', d.tlCuts, d.contacts, d.served), COL_DIM)

  if #d.penalties > 0 then
    ui.separator()
    for _, p in ipairs(d.penalties) do drawPenalty(p, car) end
  end

  ui.separator()
  ui.pushFont(ui.Font.Small)
  local text, color = aiStatusText()
  ui.textColored(text, color)
  if #S.events == 0 then
    ui.textColored(tr('Sin incidentes.'), COL_DIM)
  else
    for i = 1, math.min(7, #S.events) do
      local e = S.events[i]
      ui.textColored((e.lap and tr('V%s  ', e.lap) or '') .. e.text, e.ai and COL_GREY or levelColor(e.level))
    end
  end
  ui.popFont()
end

-- Segunda ventana: clasificacion con incidentes y sanciones de todos.
function script.windowStandings(dt)
  local sim = ac.getSim()
  local rows, corrected = standings(sim)
  ui.textColored(corrected and tr('Clasificación corregida con sanciones') or tr('Orden en pista (se corrige al terminar la carrera)'),
    corrected and COL_GREEN or COL_DIM)
  ui.columns(5)
  ui.setColumnWidth(0, 36)
  ui.setColumnWidth(1, 170)
  ui.setColumnWidth(2, 50)
  ui.setColumnWidth(3, 80)
  ui.textColored('Pos', COL_DIM) ui.nextColumn()
  ui.textColored(tr('Piloto'), COL_DIM) ui.nextColumn()
  ui.textColored('Inc', COL_DIM) ui.nextColumn()
  ui.textColored(tr('Sanción'), COL_DIM) ui.nextColumn()
  ui.textColored(tr('Tiempo'), COL_DIM) ui.nextColumn()
  local leader = nil
  for pos, r in ipairs(rows) do
    local color = r.i == 0 and COL_YELLOW or COL_WHITE
    ui.textColored(r.d.dq and 'DSQ' or tostring(corrected and pos or r.pos), color) ui.nextColumn()
    ui.textColored(r.name, color) ui.nextColumn()
    if r.noApp then
      ui.textColored(tr('sin app'), COL_DIM) ui.nextColumn()
    else
      ui.textColored(r.d.points .. 'x', r.d.points > 0 and COL_YELLOW or COL_DIM) ui.nextColumn()
    end
    local pen = ''
    if r.d.timePenalty > 0 then pen = '+' .. r.d.timePenalty .. ' s' end
    if r.pending then
      pen = pen .. (pen ~= '' and ' ' or '') .. (r.pending.kind == KIND_LIFT and tr('debe levantar') or tr('debe pits'))
    end
    ui.textColored(pen ~= '' and pen or '-', pen ~= '' and COL_ORANGE or COL_DIM) ui.nextColumn()
    local t = '-'
    if corrected and r.total then
      if not leader then
        leader = r
        t = tr('ganador')
      elseif r.laps < leader.laps then
        t = tr('+%s v', leader.laps - r.laps)
      else
        t = string.format('%s+%.1f s', r.d.estimated and '~' or '', r.total - leader.total)
      end
    end
    ui.textColored(t, COL_DIM) ui.nextColumn()
  end
  ui.columns(1)
end

-- ---------------------------------------------------------------------------
-- 12. INDICADORES SUELTOS (cada uno es una ventana transparente que se puede mover)
--     Aviso: que paso.  Sancion: que tienes que hacer.  Estado: como vas.
-- ---------------------------------------------------------------------------

local HUD_IDS = { 'hud_msg', 'hud_pen', 'hud_status', 'hud_start' }
local FONT_BOLD, FONT_REG = 'Segoe UI;Weight=Bold', 'Segoe UI'
local P_BG     = rgbm(0.055, 0.06, 0.075, 0.93)
local P_HEAD   = rgbm(0.13, 0.14, 0.17, 0.97)
local P_LINE   = rgbm(1, 1, 1, 0.14)
local P_MUTED  = rgbm(0.70, 0.74, 0.80, 1)
local P_BLUE   = rgbm(0.38, 0.62, 0.95, 1)
local P_PURPLE = rgbm(0.72, 0.48, 0.96, 1)

-- Los tamanos estan pensados para una pantalla de 1080 de alto; en pantallas mas grandes todo crece en proporcion.
-- HX junta el estado del dibujo de los indicadores (un archivo Lua admite pocas variables sueltas).
local HX = { k = 1, q = {}, n = 0, sizes = {}, soft = rgbm(0.92, 0.94, 0.97, 1) }
function HX.refreshScreen()
  local ok, size = pcall(function () return ac.getUI().windowSize end)
  if ok and size and size.y > 100 then HX.k = math.max(0.7, math.min(3, size.y / 1080)) end
end
local function hs(v) return v * cfg.hudScale * HX.k end
-- pixel entero: un texto o una imagen entre dos pixeles se ve borroso
local function px(v) return math.floor(v + 0.5) end

local function fade(color, alpha)
  if alpha >= 1 then return color end
  return rgbm(color.r, color.g, color.b, (color.mult or 1) * alpha)
end

-- Los textos de un cuadro se juntan en una cola y se dibujan al final, todos de una vez (HX.flush).
-- Asi van siempre encima de los iconos y, sin fondo, comparten un solo contorno: el del juego,
-- que es parejo y nitido. Si esta version del juego no lo trae, se dibuja un contorno a mano.
HX.outlineOk = pcall(function ()
  if type(ui.beginOutline) ~= 'function' or type(ui.endOutline) ~= 'function' then error('sin contorno') end
end)
HX.dirs = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }

function HX.font(bold)
  -- sin fondo todo va en negrita: las letras delgadas se pierden sobre la pista
  return (bold or not cfg.hudBg) and FONT_BOLD or FONT_REG
end

local function txt(text, size, x, y, color, bold)
  HX.n = HX.n + 1
  local q = HX.q[HX.n]
  if not q then
    q = {}
    HX.q[HX.n] = q
  end
  q[1], q[2], q[3], q[4], q[5], q[6] = text, math.max(8, px(size)), px(x), px(y), color, HX.font(bold)
end

function HX.flush()
  local n = HX.n
  HX.n = 0
  if n == 0 then return end
  local outline = not cfg.hudBg
  local native = false
  if outline and HX.outlineOk then
    native = pcall(ui.beginOutline)
    if not native then HX.outlineOk = false end
  end
  for k = 1, n do
    local q = HX.q[k]
    ui.pushDWriteFont(q[6])
    if outline and not native then
      local dark = rgbm(0, 0, 0, 0.8 * (q[5].mult or 1))
      local o = q[2] >= 24 and 2 or 1
      for _, dir in ipairs(HX.dirs) do
        ui.dwriteDrawText(q[1], q[2], vec2(q[3] + dir[1] * o, q[4] + dir[2] * o), dark)
      end
    end
    ui.dwriteDrawText(q[1], q[2], vec2(q[3], q[4]), q[5])
    ui.popDWriteFont()
  end
  if native then pcall(ui.endOutline, rgbm(0, 0, 0, 0.9)) end
end

local function tw(text, size, bold)
  size = math.max(8, px(size))
  ui.pushDWriteFont(HX.font(bold))
  local ok, m = pcall(ui.measureDWriteText, text, size)
  ui.popDWriteFont()
  if ok and m then return m.x end
  return #text * size * 0.55
end

local function panel(x, y, w, h, alpha, color)
  if cfg.hudBg then ui.drawRectFilled(vec2(x, y), vec2(x + w, y + h), fade(color or P_BG, alpha or 1), hs(4)) end
end

-- Banderas. Del comisario: blanca y negra = aviso, negra con franja roja = sancion.
-- De pista: verde, amarilla, amarilla total (con franjas), roja, azul, blanca, a cuadros y negra.
local FLAG_COLORS = {
  yellow = rgbm(1, 0.85, 0.05, 1), fcy = rgbm(1, 0.85, 0.05, 1), green = rgbm(0.15, 0.7, 0.25, 1),
  red = rgbm(0.86, 0.1, 0.1, 1), blue = rgbm(0.12, 0.38, 0.92, 1), white = rgbm(0.96, 0.96, 0.96, 1),
}
-- Iconos en imagenes (carpeta img de la app). Si la carpeta no esta, se usan las banderas dibujadas.
local ICON_FILES = {
  green = 'bandera_verde', yellow = 'bandera_amarilla', fcy = 'bandera_amarilla_total', red = 'bandera_roja',
  blue = 'bandera_azul', white = 'bandera_blanca', check = 'bandera_cuadros', black = 'bandera_negra',
  warn = 'aviso', pen = 'aviso', time = 'tiempo', lift = 'levantar', dt = 'drive_through', sg = 'stop_and_go',
  giveback = 'devolver', dq = 'descalificado', ok = 'cumplida',
}
-- lo que se dibuja a mano cuando no hay imagenes
local ICON_PLAIN = { time = 'pen', lift = 'pen', dt = 'pen', sg = 'pen', giveback = 'pen', dq = 'black', ok = 'green' }
local ICON_ASPECT = 640 / 440
local imgDir = nil     -- nil = sin buscar, false = no hay imagenes
-- Cada icono viene en varios tamanos (carpetas img/48, img/80 e img/160, ademas del grande).
-- Achicar mucho una imagen grande al dibujarla la deja dentada: se usa la mas cercana al tamano en pantalla.
local IMG_SIZES = { { dir = '48/', h = 33 }, { dir = '80/', h = 55 }, { dir = '160/', h = 110 } }

local function iconPath(kind, height)
  if not cfg.hudIcons then return nil end
  if imgDir == nil then
    imgDir = false
    local tries = {}
    pcall(function () tries[#tries + 1] = ac.getFolder(ac.FolderID.ScriptOrigin) end)
    pcall(function () tries[#tries + 1] = ac.getFolder(ac.FolderID.Root) .. '/apps/lua/Comisario' end)
    for _, dir in ipairs(tries) do
      if type(dir) == 'string' and io.fileExists(dir .. '/img/aviso.png') then
        imgDir = dir .. '/img/'
        for _, v in ipairs(IMG_SIZES) do
          if io.fileExists(imgDir .. v.dir .. 'aviso.png') then HX.sizes[#HX.sizes + 1] = v end
        end
        break
      end
    end
  end
  local file = ICON_FILES[kind]
  if not imgDir or not file then return nil end
  if height then
    for _, v in ipairs(HX.sizes) do
      if v.h >= height * 0.95 then return imgDir .. v.dir .. file .. '.png' end
    end
  end
  return imgDir .. file .. '.png'
end

local function iconsOn() return iconPath('warn') ~= nil end

local function drawFlag(x, y, w, h, kind, alpha)
  -- el icono se ajusta al alto de la caja y se centra; es un poco mas ancho por la estela
  local ih = px(h * 1.12)
  local iw = px(ih * ICON_ASPECT)
  local path = iconPath(kind, ih)
  if path then
    local x1, y1 = px(x + w / 2 - iw / 2), px(y + h / 2 - ih / 2)
    local ok = pcall(ui.drawImage, path, vec2(x1, y1), vec2(x1 + iw, y1 + ih), rgbm(1, 1, 1, alpha or 1))
    if ok then return end
  end
  kind = ICON_PLAIN[kind] or kind
  local p1, p2 = vec2(x, y), vec2(x + w, y + h)
  local dark = rgbm(0.05, 0.05, 0.05, 1)
  if kind == 'warn' then
    ui.drawRectFilled(p1, p2, fade(FLAG_COLORS.white, alpha))
    ui.drawTriangleFilled(vec2(x, y), vec2(x + w, y), vec2(x, y + h), fade(dark, alpha))
  elseif kind == 'check' then
    -- a cuadros: 4 columnas por 3 filas
    ui.drawRectFilled(p1, p2, fade(FLAG_COLORS.white, alpha))
    local cw, ch = w / 4, h / 3
    for row = 0, 2 do
      for col = 0, 3 do
        if (row + col) % 2 == 0 then
          ui.drawRectFilled(vec2(x + col * cw, y + row * ch), vec2(x + (col + 1) * cw, y + (row + 1) * ch), fade(dark, alpha))
        end
      end
    end
  elseif FLAG_COLORS[kind] then
    ui.drawRectFilled(p1, p2, fade(FLAG_COLORS[kind], alpha))
    if kind == 'fcy' then
      -- amarilla total: dos franjas oscuras para distinguirla de la amarilla local
      ui.drawRectFilled(vec2(x + w * 0.22, y), vec2(x + w * 0.34, y + h), fade(dark, alpha))
      ui.drawRectFilled(vec2(x + w * 0.66, y), vec2(x + w * 0.78, y + h), fade(dark, alpha))
    end
  else
    ui.drawRectFilled(p1, p2, fade(rgbm(0.04, 0.04, 0.04, 1), alpha))
    if kind == 'pen' then
      ui.drawRectFilled(vec2(x, y + h * 0.38), vec2(x + w, y + h * 0.62), fade(rgbm(0.9, 0.15, 0.15, 1), alpha))
    end
  end
  ui.drawRect(p1, p2, fade(rgbm(1, 1, 1, 0.55), alpha))
end

-- AVISO: bandera, titulo y una linea que explica que paso. Aparece unos segundos y se desvanece.
local function drawHudMessage(c)
  local b = S.banner
  local title, detail, level, kind, alpha
  if b and clock <= b.untilTime then
    title, detail, level = b.title, b.detail, b.level
    kind = D(0).dq and 'dq' or ((S.flag and S.flag.kind) or 'warn')
    alpha = math.max(0, math.min(1, (clock - (b.start or 0)) / 0.15, (b.untilTime - clock) / 0.6))
  elseif cfg.hudPlace then
    title, detail, level, kind, alpha = tr('AVISO DEL COMISARIO'), tr('Aquí aparece lo que pasó y por qué'), 1, 'warn', 1
  else
    return
  end
  local ts, ds = hs(22), hs(15)
  local big = iconsOn()                       -- con iconos, la imagen va mas grande
  local textX = big and hs(98) or hs(76)
  local w = math.max(hs(320), textX + math.max(tw(title, ts, true), tw(detail, ds, false)) + hs(18))
  local h = detail ~= '' and hs(62) or hs(46)
  panel(c.x, c.y, w, h, alpha)
  if cfg.hudBg then ui.drawRectFilled(vec2(c.x, c.y), vec2(c.x + hs(4), c.y + h), fade(levelColor(level), alpha)) end
  if big then
    local ih = math.min(hs(46), h - hs(8))
    drawFlag(c.x + hs(16), c.y + (h - ih) / 2, hs(68), ih, kind, alpha)
  else
    drawFlag(c.x + hs(16), c.y + (h - hs(30)) / 2, hs(44), hs(30), kind, alpha)
  end
  txt(title, ts, c.x + textX, c.y + hs(detail ~= '' and 6 or 10), fade(COL_WHITE, alpha), true)
  if detail ~= '' then txt(detail, ds, c.x + textX, c.y + hs(35), fade(cfg.hudBg and P_MUTED or HX.soft, alpha), false) end
  return w, h
end

function script.windowHudMessage(dt)
  if cfg.hudFixed then return end
  HX.refreshScreen()
  HX.n = 0
  drawHudMessage(ui.getCursor())
  HX.flush()
end

-- LARGADA: velocimetro de la formacion (tu velocidad contra el limite) y semaforo verde al largar.
-- Tambien muestra la velocidad contra el limite durante una amarilla total o una bandera roja.
local LIGHTS_SEC = 8    -- segundos que el semaforo verde queda en pantalla

local function drawHudStart(c)
  local car = ac.getCar(0)
  if not car then return end
  if not cfg.enabled and not cfg.hudPlace then return end
  local y = c.y
  local w = hs(330)

  -- semaforo: cinco luces que se encienden en verde de izquierda a derecha y parpadean dos veces
  local lt = S.lights and (clock - S.lights.start) or nil
  if cfg.hudPlace and not lt then lt = 1 end
  if lt and lt < LIGHTS_SEC then
    local alpha = math.max(0, math.min(1, (LIGHTS_SEC - lt) / 0.6))
    local h = hs(62)
    panel(c.x, y, w, h, alpha)
    local blinkOff = (lt > 1.35 and lt < 1.5) or (lt > 1.8 and lt < 1.95)
    for k = 1, 5 do
      local on = lt >= (k - 1) * 0.12 and not blinkOff
      local cx = c.x + w / 2 + (k - 3) * hs(56)
      ui.drawCircleFilled(vec2(cx, y + h / 2), hs(21), fade(rgbm(0.02, 0.02, 0.03, 1), alpha))
      ui.drawCircleFilled(vec2(cx, y + h / 2), hs(17), fade(on and rgbm(0.15, 0.95, 0.3, 1) or rgbm(0.13, 0.16, 0.14, 1), alpha))
      if on then ui.drawCircleFilled(vec2(cx - hs(5), y + h / 2 - hs(5)), hs(5), fade(rgbm(0.75, 1, 0.8, 0.9), alpha)) end
    end
    y = y + h + hs(6)
  end

  -- velocimetro: en la formacion, o con amarilla total o roja
  local limit, label, sub = nil, nil, nil
  local f = S.form
  if f and f.phase == 'formation' then
    limit, label, sub = cfg.formSpeed, f.short and tr('SALIDA LANZADA') or tr('VUELTA DE FORMACIÓN'), tr('MANTÉN P%s', tostring(f.grid or ''))
  elseif cfg.flEnabled and S.ctl.state ~= 0 then
    limit, label, sub = S.ctl.speed, S.ctl.state == 2 and tr('BANDERA ROJA') or tr('AMARILLA TOTAL'), tr('NO ADELANTAR')
  elseif cfg.hudPlace then
    limit, label, sub = cfg.formSpeed, tr('SALIDA LANZADA'), tr('MANTÉN P%s', 3)
  end
  if not limit then
    if y > c.y then return w, y - c.y - hs(6) end     -- solo el semaforo
    return
  end
  local speed = cfg.hudPlace and not (f and f.phase == 'formation') and S.ctl.state == 0 and (limit - 8) or car.speedKmh
  local color = speed <= limit and COL_GREEN or (speed <= limit + 10 and COL_YELLOW or COL_RED)
  local h = hs(80)
  panel(c.x, y, w, h, 1)
  if cfg.hudBg then ui.drawRectFilled(vec2(c.x, y), vec2(c.x + hs(4), y + h), color) end
  local soft = cfg.hudBg and P_MUTED or HX.soft
  txt(label, hs(12), c.x + hs(14), y + hs(4), soft, true)
  txt(sub, hs(12), c.x + w - tw(sub, hs(12), true) - hs(12), y + hs(4), soft, true)
  local num = string.format('%d', round(speed))
  txt(num, hs(34), c.x + hs(14), y + hs(17), color, true)
  txt('km/h', hs(14), c.x + hs(18) + tw(num, hs(34), true), y + hs(36), soft, false)
  local max = tr('MÁX %s', limit)
  txt(max, hs(20), c.x + w - tw(max, hs(20), true) - hs(12), y + hs(28), COL_WHITE, true)
  -- barra: la marca blanca es el limite
  local x1, full, by = c.x + hs(14), w - hs(28), y + h - hs(14)
  local top = limit * 1.25
  ui.drawRectFilled(vec2(x1, by), vec2(x1 + full, by + hs(6)), P_LINE, hs(3))
  ui.drawRectFilled(vec2(x1, by), vec2(x1 + full * math.max(0, math.min(1, speed / top)), by + hs(6)), color, hs(3))
  local mx = x1 + full * (limit / top)
  ui.drawRectFilled(vec2(mx - hs(1), by - hs(3)), vec2(mx + hs(1), by + hs(9)), COL_WHITE)
  local inForm = f and f.phase == 'formation'
  if cfg.formRadar and (inForm or (cfg.hudPlace and S.ctl.state == 0)) then
    if inForm and f.radar == nil and clock - f.startAt > 1.5 then RS.pickRadar(f, ac.getSim().carsCount) end
    local rh = RS.drawRadar(c, y + h + hs(6), w, f)
    if rh > 0 then return w, y + h + hs(6) + rh - c.y end
  end
  return w, y + h - c.y
end

-- RADAR DE LA FORMACION: distancia al auto que tienes que seguir (el de adelante en tu columna o, si eres el
-- segundo de una fila doble, el que va a tu lado unos metros delante). La distancia buena es la que tenias al
-- quedar en la fila, asi sirve igual offline y online, con una o dos filas.
function RS.pickRadar(f, n)
  f.radar = false
  local me = ac.getCar(0)
  if not me or not f.order then return end
  local lx, lz = me.look.x, me.look.z
  local ll = math.sqrt(lx * lx + lz * lz)
  if ll < 0.01 then return end
  lx, lz = lx / ll, lz / ll
  local mySlot = f.grid or 1
  local best, bestAlong, partner, partnerAlong = nil, math.huge, nil, math.huge
  for _, j in ipairs(f.order) do
    local c = j ~= 0 and ac.getCar(j)
    if c and startSlot(j, n) < mySlot then
      local dx, dz = c.position.x - me.position.x, c.position.z - me.position.z
      local along, side = dx * lx + dz * lz, math.abs(dx * lz - dz * lx)
      if along > 1 and along < 40 then
        if side < 1.6 then
          if along < bestAlong then best, bestAlong = j, along end
        elseif startSlot(j, n) == mySlot - 1 and along < partnerAlong then
          partner, partnerAlong = j, along
        end
      end
    end
  end
  if partner and (not best or partnerAlong < bestAlong) then best = partner end
  if best then
    f.radar = { ref = best, want = math.max(3, math.min(20, metersAhead(ac.getCar(best), me))) }
  end
  -- fila doble: tu carril es el lado contrario al del auto que larga en tu misma fila
  f.lane = nil
  local rx, rz = RS.rightOf(me)
  if rx then
    local myRow = math.ceil(mySlot / 2)
    for _, j in ipairs(f.order) do
      local c = j ~= 0 and ac.getCar(j)
      if c and math.ceil(startSlot(j, n) / 2) == myRow then
        local dx, dz = c.position.x - me.position.x, c.position.z - me.position.z
        local lat = dx * rx + dz * rz
        if math.abs(dx * lx + dz * lz) < 10 and math.abs(lat) > 2.5 and math.abs(lat) < 9 then
          f.lane = lat > 0 and -1 or 1
        end
      end
    end
  end
end

-- vector hacia la derecha del auto: de la rueda delantera izquierda a la derecha (nil si el juego no lo da)
function RS.rightOf(c)
  local ok, rx, rz = pcall(function ()
    local a, b = c.wheels[0].position, c.wheels[1].position
    return b.x - a.x, b.z - a.z
  end)
  if not ok or not rx or not rz then return nil end
  local l = math.sqrt(rx * rx + rz * rz)
  if l < 0.5 then return nil end
  return rx / l, rz / l
end

-- metros a la derecha (positivo) o a la izquierda (negativo) del centro de la pista, y el medio ancho de la pista
function RS.offCenter(c)
  local rx, rz = RS.rightOf(c)
  if not rx then return nil end
  local ok, off, half = pcall(function ()
    local sp = c.splinePosition
    local len = trackLen(ac.getSim())
    local a = ac.trackProgressToWorldCoordinate(sp)
    local b = ac.trackProgressToWorldCoordinate(sp + 2 / len)
    local dx, dz = b.x - a.x, b.z - a.z
    local dd = math.sqrt(dx * dx + dz * dz)
    if dd < 0.001 then error('sin direccion') end
    local px, pz = -dz / dd, dx / dd
    local m = FORM2.pairCenter(sp)
    if not m then error('sin fila doble') end
    local cx, cz = a.x + px * m, a.z + pz * m
    return (c.position.x - cx) * rx + (c.position.z - cz) * rz, FORM2.LANE * 2
  end)
  if not ok or not off or not half or half < 2 then return nil end
  return off, half
end

-- Linea del carril: cual te toca y donde vas (una marca blanca sobre los dos carriles). Avisa si te pasaste.
function RS.drawLane(c, y, w, lane, off, half)
  local wrong = off and ((lane < 0 and off > 0.8) or (lane > 0 and off < -0.8))
  local text
  if wrong then
    text = lane < 0 and tr('PÁSATE A LA IZQUIERDA') or tr('PÁSATE A LA DERECHA')
  else
    text = lane < 0 and tr('CARRIL IZQUIERDO') or tr('CARRIL DERECHO')
  end
  local color = wrong and COL_YELLOW or COL_WHITE
  txt(text, hs(14), c.x + hs(14), y + hs(3), color, true)
  -- los dos carriles: el tuyo en verde
  local lw, lh = hs(46), hs(12)
  local x2 = c.x + w - hs(12)
  local mid = x2 - lw
  local ly = y + hs(6)
  ui.drawRectFilled(vec2(mid - lw, ly), vec2(mid - hs(1), ly + lh), lane < 0 and fade(COL_GREEN, 0.7) or P_LINE, hs(2))
  ui.drawRectFilled(vec2(mid + hs(1), ly), vec2(x2, ly + lh), lane > 0 and fade(COL_GREEN, 0.7) or P_LINE, hs(2))
  if off then
    local px = mid + lw * math.max(-1, math.min(1, off / math.max(2, half)))
    ui.drawRectFilled(vec2(px - hs(2), ly - hs(3)), vec2(px + hs(2), ly + lh + hs(3)), color)
  end
  return wrong
end

function RS.drawRadar(c, y, w, f)
  local car = ac.getCar(0)
  local gap, want, hint, color
  local lane, off, half = f and f.lane, nil, nil
  if f and f.radar and ac.getCar(f.radar.ref) then
    gap, want = metersAhead(ac.getCar(f.radar.ref), car), f.radar.want
  elseif cfg.hudPlace and not (f and f.phase == 'formation') then
    gap, want, lane, off, half = 19, 12, -1, -2, 6
  elseif f and f.radar == false then
    gap = nil
  else
    return 0
  end
  if lane and not off then off, half = RS.offCenter(car) end
  local laneH = lane and hs(24) or 0
  local h = hs(gap and 62 or 34) + laneH
  local soft = cfg.hudBg and P_MUTED or HX.soft
  panel(c.x, y, w, h, 1)
  if not gap then
    txt(tr('LÍDER: MARCAS EL RITMO'), hs(14), c.x + hs(14), y + hs(9), COL_WHITE, true)
    if lane then RS.drawLane(c, y + hs(32), w, lane, off, half) end
    return h
  end
  local lo, hi = math.max(1, want - 3), want + 6
  if gap < 0 then hint, color = tr('TE ADELANTASTE'), COL_RED
  elseif gap < lo then hint, color = tr('ABRE ESPACIO'), COL_RED
  elseif gap > hi then hint, color = tr('ACÉRCATE'), COL_YELLOW
  else hint, color = tr('BIEN'), COL_GREEN end
  if cfg.hudBg then ui.drawRectFilled(vec2(c.x, y), vec2(c.x + hs(4), y + h), color) end
  txt(tr('DISTANCIA AL DE ADELANTE'), hs(12), c.x + hs(14), y + hs(4), soft, true)
  local num = string.format('%d m', round(math.max(-99, math.min(999, gap))))
  txt(num, hs(20), c.x + hs(14), y + hs(19), color, true)
  txt(hint, hs(16), c.x + w - tw(hint, hs(16), true) - hs(12), y + hs(21), color, true)
  -- barra: rojo muy cerca, verde la distancia buena, gris lejos; la marca blanca es donde estas
  local x1, full, by = c.x + hs(14), w - hs(28), y + h - laneH - hs(14)
  local range = want * 2 + 15
  local function xAt(m) return x1 + full * math.max(0, math.min(1, m / range)) end
  ui.drawRectFilled(vec2(x1, by), vec2(x1 + full, by + hs(6)), P_LINE, hs(3))
  ui.drawRectFilled(vec2(x1, by), vec2(xAt(lo), by + hs(6)), fade(COL_RED, 0.55), hs(3))
  ui.drawRectFilled(vec2(xAt(lo), by), vec2(xAt(hi), by + hs(6)), fade(COL_GREEN, 0.7))
  local mx = xAt(gap)
  ui.drawRectFilled(vec2(mx - hs(2), by - hs(4)), vec2(mx + hs(2), by + hs(10)), COL_WHITE)
  if lane then RS.drawLane(c, y + h - laneH - hs(2), w, lane, off, half) end
  return h
end

function script.windowHudStart(dt)
  if cfg.hudFixed then return end
  HX.refreshScreen()
  HX.n = 0
  drawHudStart(ui.getCursor())
  HX.flush()
end

-- SANCION PENDIENTE: que tienes que hacer y cuanto margen queda. Se queda en pantalla hasta que cumples.
-- Por orden de urgencia: descalificacion, posicion por devolver y, despues, la primera sancion pendiente.
local function drawHudPenalty(c)
  local car = ac.getCar(0)
  if not car then return end
  local d = D(0)
  local p = d.penalties[1]
  local gb = S.giveback
  local head, title, line, color = tr('SANCIÓN PENDIENTE'), nil, nil, COL_RED
  local icon = 'dt'
  local bar, barText, lapsLeft = nil, nil, nil     -- pie del cuadro: barra de avance o casillas de vueltas

  if d.dq then
    head, title, icon = tr('DESCALIFICADO'), tr('BANDERA NEGRA'), 'dq'
    line = tr('Quedas en pits, con el auto bloqueado')
  elseif gb then
    head, title, color, icon = tr('ORDEN DEL COMISARIO'), tr('DEVUELVE LA POSICIÓN'), COL_ORANGE, 'giveback'
    line = tr('Deja pasar a %s', gb.name)
    local left = math.max(0, gb.deadline - clock)
    bar, barText = left / gb.total, string.format('%.0f s', left)
  elseif p and p.kind == KIND_LIFT then
    title, color, icon = tr('LEVANTA EL PIE'), COL_ORANGE, 'lift'
    line = tr('Suelta el acelerador %d segundos. Plazo: %.0f s', p.need, math.max(0, p.deadline - clock))
    bar, barText = math.min(1, p.done / p.need), string.format('%.1f / %d s', p.done, p.need)
  elseif p and p.kind == KIND_SG then
    title, icon = 'STOP AND GO', 'sg'
    if p.phase == 'in' then
      line = tr('Detente por completo en pits')
      bar, barText = math.min(1, p.stopT / p.need), string.format('%.0f / %d s', p.stopT, p.need)
    else
      line = tr('Entra a pits y detente %s s', p.need)
      lapsLeft = math.max(0, p.lapIssued + cfg.dtLaps - car.lapCount)
    end
  elseif p then
    title = 'DRIVE-THROUGH'
    line = p.phase == 'in' and tr('Sigue sin parar hasta salir de pits') or tr('Pasa por pits sin parar')
    lapsLeft = math.max(0, p.lapIssued + cfg.dtLaps - car.lapCount)
  elseif cfg.hudPlace then
    title, line, lapsLeft = 'DRIVE-THROUGH', tr('Aquí aparece lo que tienes que cumplir'), cfg.dtLaps
  else
    return
  end

  local ix = iconsOn() and hs(84) or 0     -- espacio para el icono a la izquierda del titulo
  local soft = cfg.hudBg and P_MUTED or HX.soft
  local w = math.max(hs(330), tw(line, hs(15), false) + hs(30) + ix, tw(title, hs(22), true) + hs(30) + ix)
  local h, headH = hs((bar or lapsLeft) and 106 or 84), hs(22)
  panel(c.x, c.y, w, h, 1)
  panel(c.x, c.y, w, headH, 1, P_HEAD)
  if cfg.hudBg then ui.drawRectFilled(vec2(c.x, c.y), vec2(c.x + hs(4), c.y + h), color) end
  txt(head, hs(12), c.x + hs(14), c.y + hs(3), soft, true)
  if ix > 0 then drawFlag(c.x + hs(14), c.y + hs(28), hs(68), hs(46), icon, 1) end
  local count = #d.penalties + (gb and 1 or 0)
  if count > 1 and not d.dq then
    local more = tr('1 de %s', count)
    txt(more, hs(12), c.x + w - tw(more, hs(12), true) - hs(10), c.y + hs(3), soft, true)
  end
  txt(title, hs(22), c.x + hs(14) + ix, c.y + hs(25), color, true)
  txt(line, hs(15), c.x + hs(14) + ix, c.y + hs(54), COL_WHITE, false)

  local y = c.y + hs(82)
  if bar then
    local full = w - hs(28) - tw(barText, hs(13), true) - hs(10)
    local x1 = c.x + hs(14)
    ui.drawRectFilled(vec2(x1, y + hs(5)), vec2(x1 + full, y + hs(11)), P_LINE, hs(3))
    ui.drawRectFilled(vec2(x1, y + hs(5)), vec2(x1 + full * math.max(0, math.min(1, bar)), y + hs(11)), color, hs(3))
    txt(barText, hs(13), x1 + full + hs(10), y - hs(1), COL_WHITE, true)
  elseif lapsLeft then
    -- una casilla por cada vuelta que queda para cumplir
    local label = lapsLeft == 0 and tr('ÚLTIMA OPORTUNIDAD: ENTRA EN ESTA VUELTA') or tr('VUELTAS PARA CUMPLIR: %s', lapsLeft)
    txt(label, hs(12), c.x + hs(14), y, lapsLeft == 0 and COL_RED or soft, true)
    local x = c.x + hs(14) + tw(label, hs(12), true) + hs(10)
    for k = 1, cfg.dtLaps do
      ui.drawRectFilled(vec2(x, y + hs(3)), vec2(x + hs(14), y + hs(13)), k <= lapsLeft and color or P_LINE, hs(2))
      x = x + hs(18)
    end
  end
  return w, h
end

function script.windowHudPenalty(dt)
  if cfg.hudFixed then return end
  HX.refreshScreen()
  HX.n = 0
  drawHudPenalty(ui.getCursor())
  HX.flush()
end

-- ESTADO: una barra delgada con la sesion, los avisos, los puntos y el tiempo de sancion.
local function drawHudStatus(c)
  local car = ac.getCar(0)
  if not car then return end
  if not cfg.enabled and not cfg.hudPlace then return end
  local d = D(0)
  local mode = sessionMode()
  local items = {}
  local function add(text, color, bold) items[#items + 1] = { text = text, color = color, bold = bold } end
  local function sep() items[#items + 1] = { sep = true } end

  if mode == 'race' then
    add(tr('CARRERA'), COL_RED, true)
    local f = S.form
    if f and f.phase == 'formation' then
      sep()
      add(tr('FORMACIÓN'), COL_YELLOW, true)
      sep()
      add(tr('MÁX %s km/h', cfg.formSpeed), car.speedKmh > cfg.formSpeed + 10 and COL_RED or COL_WHITE, true)
      sep()
      add(tr('MANTÉN P%s', f.grid), COL_WHITE, false)
    elseif f and f.phase == 'green' then
      sep()
      add(tr('VERDE'), COL_GREEN, true)
      sep()
      add(tr('ADELANTA DESPUÉS DE LA META'), COL_WHITE, false)
    end
  elseif mode == 'qualy' then
    add(tr('CLASIFICACIÓN'), P_PURPLE, true)
    sep()
    if S.invalidLap == car.lapCount + 1 then add(tr('VUELTA INVÁLIDA'), COL_RED, true) else add(tr('VUELTA VÁLIDA'), COL_GREEN, true) end
    if S.bestValid then
      sep()
      add(tr('MEJOR %s', lapStr(S.bestValid)), COL_WHITE, false)
    end
  else
    add(tr('PRÁCTICA'), P_BLUE, true)
    sep()
    add(tr('SOLO CUENTA'), cfg.hudBg and P_MUTED or HX.soft, false)
  end

  local rf = S.rf
  if cfg.hudPlace and not rf then rf = { kind = 'yellow', label = tr('AMARILLA · NO ADELANTAR') } end
  if rf then
    sep()
    items[#items + 1] = { flag = rf.kind }
    add(rf.label, (rf.kind == 'red' or rf.kind == 'black') and COL_RED or ((rf.kind == 'yellow' or rf.kind == 'fcy') and COL_YELLOW
      or (rf.kind == 'blue' and P_BLUE or (rf.kind == 'green' and COL_GREEN or COL_WHITE))), true)
  end

  if cfg.tlEnabled then
    sep()
    if mode == 'race' and cfg.tlPenalty ~= KIND_NONE and cfg.tlWarnings >= 1 and cfg.tlWarnings <= 5 then
      add(tr('LÍMITES'), cfg.hudBg and P_MUTED or HX.soft, true)
      items[#items + 1] = { dots = cfg.tlWarnings, used = math.min(d.tlWarnings, cfg.tlWarnings) }
    elseif mode == 'race' and cfg.tlPenalty ~= KIND_NONE then
      add(tr('LÍMITES %s/%s', math.min(d.tlWarnings, cfg.tlWarnings), cfg.tlWarnings), d.tlWarnings > 0 and COL_YELLOW or COL_WHITE, true)
    else
      add(tr('SALIDAS %s', d.tlCuts), d.tlCuts > 0 and COL_YELLOW or COL_WHITE, true)
    end
  end
  if cfg.incEnabled then
    sep()
    local text = 'INC ' .. d.points .. 'x'
    if mode == 'race' then
      -- se muestra el limite mas cercano: la proxima sancion o el maximo antes de la descalificacion
      local limit = cfg.incStep > 0 and (math.floor(d.points / cfg.incStep) + 1) * cfg.incStep or nil
      if cfg.incDQ > 0 and (not limit or cfg.incDQ < limit) then limit = cfg.incDQ end
      if limit then text = text .. ' / ' .. limit end
    end
    add(text, d.points > 0 and COL_YELLOW or COL_WHITE, true)
  end
  if d.timePenalty > 0 then
    sep()
    add('+' .. d.timePenalty .. ' s', COL_RED, true)
  end
  if d.dq then
    sep()
    add(tr('DESCALIFICADO'), COL_RED, true)
  end
  if #d.penalties > 0 then
    sep()
    -- el icono de la sancion que hay que cumplir primero
    local first = d.penalties[1].kind
    items[#items + 1] = { flag = first == KIND_LIFT and 'lift' or (first == KIND_SG and 'sg' or (first == KIND_DT and 'dt' or 'pen')) }
  end

  -- medir y dibujar
  local size, pad, h = hs(15), hs(12), hs(32)
  local w = pad
  for _, it in ipairs(items) do
    if it.sep then it.w = hs(1) + pad
    elseif it.dots then it.w = it.dots * hs(15) + pad
    elseif it.flag then it.w = (iconsOn() and hs(36) or hs(26)) + pad
    else it.w = tw(it.text, size, it.bold) + pad end
    w = w + it.w
  end
  panel(c.x, c.y, w, h, 1)
  local x = c.x + pad
  for _, it in ipairs(items) do
    if it.sep then
      if cfg.hudBg then ui.drawRectFilled(vec2(x, c.y + hs(7)), vec2(x + hs(1), c.y + h - hs(7)), P_LINE) end
    elseif it.dots then
      for k = 1, it.dots do
        local used = k <= it.used
        local col = used and (it.used >= it.dots and COL_RED or COL_YELLOW) or P_LINE
        ui.drawCircleFilled(vec2(x + hs(6) + (k - 1) * hs(15), c.y + h / 2), hs(5), col)
      end
    elseif it.flag then
      if iconsOn() then drawFlag(x, c.y + hs(4), hs(34), hs(24), it.flag, 1)
      else drawFlag(x, c.y + hs(8), hs(24), hs(16), it.flag, 1) end
    else
      txt(it.text, size, x, c.y + hs(5.5), it.color, it.bold)
    end
    x = x + it.w
  end
  return w, h
end

function script.windowHudStatus(dt)
  if cfg.hudFixed then return end
  HX.refreshScreen()
  HX.n = 0
  drawHudStatus(ui.getCursor())
  HX.flush()
end

-- INTERFAZ FIJA: el juego llama a esta funcion para dibujar sobre toda la pantalla. Los cuatro indicadores
-- van en una columna (estado, largada, aviso y sancion), centrada en el punto elegido en los ajustes.
-- No son ventanas: no se pueden mover ni cerrar por accidente.
local fixedWidth = {}
local FIXED_ORDER = { { 'status', drawHudStatus }, { 'start', drawHudStart }, { 'msg', drawHudMessage }, { 'pen', drawHudPenalty } }

function script.fullscreenUI(dt)
  if not cfg.hudFixed then return end
  HX.n = 0
  local ok, err = pcall(function ()
    HX.refreshScreen()
    local size = ac.getUI().windowSize
    local cx, y = size.x * cfg.hudX / 100, size.y * cfg.hudY / 100
    for _, item in ipairs(FIXED_ORDER) do
      -- cada indicador se centra con el ancho que tuvo en el cuadro anterior
      local last = fixedWidth[item[1]] or hs(330)
      local x = px(math.max(4, math.min(size.x - last - 4, cx - last / 2)))
      local w, h = item[2](vec2(x, px(y)))
      if w and h then
        fixedWidth[item[1]] = w
        y = y + h + hs(8)
      end
    end
    HX.flush()
  end)
  if not ok and lastError ~= tostring(err) then
    lastError = tostring(err)
    addLog('ERROR: ' .. lastError)
  end
end

-- ---------------------------------------------------------------------------
-- 13. CONTROL DE LA IA EN LA PISTA
--     Assetto Corsa solo deja que una app controle a la IA si la pista lo autoriza
--     en su archivo surfaces.ini. Aqui se agrega esa autorizacion, con respaldo.
-- ---------------------------------------------------------------------------

local BACKUP_EXT = '.comisario_respaldo'
local trackInfo = { at = nil, found = false, patched = false, hasBackup = false, message = nil }

local function surfacesPath()
  local dir = ac.getFolder(ac.FolderID.ContentTracks) .. '\\' .. ac.getTrackID()
  local layout = ac.getTrackLayout()
  if layout and layout ~= '' then dir = dir .. '\\' .. layout end
  return dir .. '\\data\\surfaces.ini'
end

-- Devuelve el texto de surfaces.ini con la autorizacion agregada, o nil si el archivo no tiene la forma esperada.
local function patchSurfaces(text)
  local crlf = text:find('\r\n', 1, true) ~= nil
  local clean = text:gsub('\r\n', '\n')
  if clean:sub(-1) == '\n' then clean = clean:sub(1, -2) end
  local out = {}
  local section, sawSurface0, sawScripting, pitchDone, allowDone = nil, false, false, false, false
  local function closeSection()
    if section == 'SURFACE_0' and not pitchDone then
      out[#out + 1] = 'WAV_PITCH=extended-0'
      pitchDone = true
    elseif section == '_SCRIPTING_PHYSICS' and not allowDone then
      out[#out + 1] = 'ALLOW_APPS=1'
      allowDone = true
    end
  end
  for line in (clean .. '\n'):gmatch('(.-)\n') do
    local name = line:match('^%s*%[(.-)%]')
    if name then
      closeSection()
      section = name
      if name == 'SURFACE_0' then sawSurface0 = true end
      if name == '_SCRIPTING_PHYSICS' then sawScripting = true end
      out[#out + 1] = line
    else
      local key = line:match('^%s*([%w_]+)%s*=')
      if section == 'SURFACE_0' and key == 'WAV_PITCH' then
        out[#out + 1] = 'WAV_PITCH=extended-0'
        pitchDone = true
      elseif section == '_SCRIPTING_PHYSICS' and key == 'ALLOW_APPS' then
        out[#out + 1] = 'ALLOW_APPS=1'
        allowDone = true
      else
        out[#out + 1] = line
      end
    end
  end
  closeSection()
  if not sawSurface0 then return nil end
  if not sawScripting then
    out[#out + 1] = ''
    out[#out + 1] = '[_SCRIPTING_PHYSICS]'
    out[#out + 1] = 'ALLOW_APPS=1'
  end
  return table.concat(out, crlf and '\r\n' or '\n') .. (crlf and '\r\n' or '\n')
end

local function refreshTrackInfo(force)
  local now = os.preciseClock()
  if not force and trackInfo.at and now - trackInfo.at < 3 then return end
  trackInfo.at = now
  local path = surfacesPath()
  local ok, text = pcall(io.load, path)
  if not ok then text = nil end
  trackInfo.found = text ~= nil
  trackInfo.patched = text ~= nil and text:find('ALLOW_APPS%s*=%s*1') ~= nil
  local okB, exists = pcall(io.fileExists, path .. BACKUP_EXT)
  trackInfo.hasBackup = okB and exists == true
end

local function enableTrackPhysics()
  local path = surfacesPath()
  local ok, err = pcall(function ()
    local text = io.load(path)
    if not text then
      trackInfo.message = tr('No encontré el archivo surfaces.ini de esta pista: %s', path)
      return
    end
    local patched = patchSurfaces(text)
    if not patched then
      trackInfo.message = tr('El archivo surfaces.ini de esta pista tiene un formato que no reconozco. No lo toqué.')
      return
    end
    if not io.fileExists(path .. BACKUP_EXT) then io.save(path .. BACKUP_EXT, text) end
    io.save(path, patched)
    if io.load(path) ~= patched then
      trackInfo.message = tr('No pude guardar el cambio (puede ser un problema de permisos de la carpeta del juego).')
      return
    end
    trackInfo.message = tr('Listo. Sal de la sesión y vuelve a entrar para que el cambio funcione.')
    addLog('Control de la IA autorizado en ' .. path)
  end)
  if not ok then trackInfo.message = tr('Error al cambiar el archivo: %s', tostring(err)) end
  refreshTrackInfo(true)
end

local function restoreTrackPhysics()
  local path = surfacesPath()
  local ok, err = pcall(function ()
    local original = io.load(path .. BACKUP_EXT)
    if not original then
      trackInfo.message = tr('No hay respaldo de esta pista.')
      return
    end
    io.save(path, original)
    if io.load(path) ~= original then
      trackInfo.message = tr('No pude restaurar el archivo. El respaldo sigue en: %s', path .. BACKUP_EXT)
      return
    end
    io.deleteFile(path .. BACKUP_EXT)
    trackInfo.message = tr('Pista restaurada. El cambio se nota al volver a entrar a la sesión.')
    addLog('Control de la IA retirado de ' .. path)
  end)
  if not ok then trackInfo.message = tr('Error al restaurar el archivo: %s', tostring(err)) end
  refreshTrackInfo(true)
end

local function drawTrackPhysics()
  ui.text(tr('Control de la IA en esta pista:'))
  refreshTrackInfo(false)
  if physicsOk() then
    ui.textColored(tr('Permitido. La IA puede cumplir sus sanciones en pista.'), COL_GREEN)
  elseif trackInfo.patched then
    ui.textColored(tr('Cambio aplicado. Sal de la sesión y vuelve a entrar para que funcione.'), COL_YELLOW)
  else
    ui.textColored(tr('No permitido: por ahora las sanciones de la IA van a la clasificación.'), COL_YELLOW)
    ui.textWrapped(tr('Assetto Corsa solo deja que una app controle a la IA si la pista lo autoriza. El botón agrega esa autorización al archivo surfaces.ini de esta pista y guarda una copia del original. Mientras el cambio esté puesto, los servidores online pueden rechazar esta pista; con Deshacer queda como estaba.'))
    if ui.button(tr('Permitir en esta pista')) then enableTrackPhysics() end
  end
  if trackInfo.hasBackup then
    if ui.button(tr('Deshacer el cambio en esta pista')) then restoreTrackPhysics() end
  end
  if trackInfo.message then ui.textWrapped(trackInfo.message) end
end

-- ---------------------------------------------------------------------------
-- 14. VENTANA DE AJUSTES (boton del engranaje en la ventana)
--     Cada fila es un nombre corto a la izquierda y su control a la derecha. La explicacion aparece al
--     pasar el mouse por encima. Las opciones finas se ven solo con "Mostrar todas las opciones".
-- ---------------------------------------------------------------------------

-- W junta las piezas de la ventana (un archivo Lua admite pocas variables sueltas).
local W = { labelW = 280, ctlW = 250 }
-- El tipo de salida y sus valores no se tocan al restablecer: son eleccion de cada carrera.
W.keep = { startMode = true, formSpeed = true, formGreen = true, formShort = true, formStartM = true }

-- Reglamento por defecto: los valores con que viene la app (ver la lista de ajustes al principio).
function W.resetRules()
  for _, key in ipairs(RULE_KEYS) do
    if not W.keep[key] then stored[key] = FACTORY[key] end
  end
  addLog('Reglamento por defecto restablecido')
end

-- Al actualizar la app se aplica una sola vez el reglamento por defecto.
W.rulesVersion = 8
if stored.rulesVersion < W.rulesVersion then
  W.resetRules()
  stored.rulesVersion = W.rulesVersion
end

-- explicacion al pasar el mouse sobre lo ultimo que se dibujo
function W.tip(text)
  if text and ui.itemHovered() then ui.setTooltip(text) end
end

-- texto de ayuda, mas apagado que el resto
function W.hint(text)
  ui.pushStyleColor(ui.StyleColor.Text, COL_DIM)
  ui.textWrapped(text)
  ui.popStyleColor()
end

function W.section(text)
  ui.offsetCursorY(6)
  ui.header(text)
end

-- nombre de la fila; deja el cursor en la columna de los controles.
-- Si el nombre no cabe en su columna (otro idioma, otra letra), el control baja a la linea siguiente.
function W.label(text, tip)
  ui.alignTextToFramePadding()
  ui.text(text)
  W.tip(tip)
  local ok, size = pcall(ui.measureText, text)
  local width = (ok and size and size.x) or (#text * 7)
  if tip then
    ui.sameLine(0, 5)
    ui.textColored('(?)', COL_DIM)
    W.tip(tip)
    width = width + 26
  end
  if width <= W.labelW - 8 then
    ui.sameLine(W.labelW)
  else
    ui.setCursorX(W.labelW)
  end
end

function W.check(text, key, tip)
  if ui.checkbox(text, cfg[key]) then cfg[key] = not cfg[key] end
  W.tip(tip)
end

-- deslizador: "format" es lo que se lee dentro de la barra, por ejemplo '%.0f km/h'
function W.slider(text, key, min, max, format, tip, decimals)
  W.label(text, tip)
  ui.setNextItemWidth(W.ctlW)
  local v = ui.slider('##' .. key, cfg[key], min, max, format, not decimals)
  if not decimals then v = round(v) end
  if v ~= cfg[key] then cfg[key] = v end
end

-- opciones excluyentes en una fila; "first" es el valor de la primera.
-- Con "wide" las opciones van en una fila propia debajo del nombre (cuando son largas).
function W.radio(text, key, options, first, tip, wide)
  if wide then
    ui.text(text)
    W.tip(tip)
    if tip then
      ui.sameLine(0, 5)
      ui.textColored('(?)', COL_DIM)
      W.tip(tip)
    end
  else
    W.label(text, tip)
  end
  for n, label in ipairs(options) do
    local value = first + n - 1
    if n > 1 then ui.sameLine(0, 10) end
    if ui.radioButton(label .. '##' .. key .. n, cfg[key] == value) then cfg[key] = value end
  end
end

-- lista desplegable con el tipo de sancion
function W.kind(text, key, tip)
  W.label(text, tip)
  ui.setNextItemWidth(W.ctlW)
  ui.combo('##' .. key, tr(KIND_NAMES[cfg[key]] or KIND_NAMES[0]), function ()
    for value = 0, 4 do
      if ui.selectable(tr(KIND_NAMES[value]), cfg[key] == value) then cfg[key] = value end
    end
  end)
end

-- Resumen del reglamento en uso, con los valores de ahora.
function W.summary()
  local function kind(k) return string.lower(tr(KIND_NAMES[k] or KIND_NAMES[0])) end
  -- "3 avisos y despues tiempo", "1 aviso y despues tiempo" o "tiempo, sin aviso previo"
  local function after(n, k)
    if n == 1 then return tr('1 aviso y después %s', kind(k)) end
    if n < 1 then return tr('%s, sin aviso previo', kind(k)) end
    return tr('%s avisos y después %s', n, kind(k))
  end
  if cfg.tlEnabled and cfg.tlPenalty ~= KIND_NONE then
    ui.bulletText(tr('Límites de pista: %s', after(cfg.tlWarnings, cfg.tlPenalty)))
  else
    ui.bulletText(tr('Límites de pista: sin sanción'))
  end
  if cfg.ctEnabled then
    ui.bulletText(tr('Contacto evitable: %s', after(cfg.ctWarnings, cfg.ctMedPenalty)))
    ui.bulletText(tr('Causar un choque fuerte: %s', kind(cfg.ctHeavyPenalty)))
  else
    ui.bulletText(tr('Contactos: sin vigilar'))
  end
  if cfg.pitEnabled then
    ui.bulletText(tr('Pits: límite de %s km/h', cfg.pitLimit))
  end
  if cfg.incEnabled and cfg.incDQ > 0 then
    ui.bulletText(tr('Más de %s puntos de incidente: descalificación', cfg.incDQ))
  end
  ui.bulletText(cfg.dtFailDQ and tr('No cumplir un drive-through en %s vueltas: descalificación', cfg.dtLaps)
    or tr('No cumplir un drive-through en %s vueltas: +%s s', cfg.dtLaps, cfg.dtFailSec))
end

function W.tabStart(all)
  if serverAuth ~= 0 then
    if isAdmin() then
      ui.textColored(tr('Eres el administrador de este servidor: tu reglamento y tus banderas valen para todos.'), COL_GREEN)
    else
      ui.pushStyleColor(ui.StyleColor.Text, COL_YELLOW)
      ui.textWrapped(tr('Este servidor tiene administrador. Se usa su reglamento: lo que cambies aquí se guarda, pero no se aplica en este servidor.'))
      ui.popStyleColor()
    end
  elseif online and net.rulesFrom then
    ui.textColored(tr('En este servidor mandan las reglas de %s, director de carrera.', net.rulesFrom), COL_YELLOW)
    W.hint(tr('Lo que cambies aquí se guarda, pero no se usa hasta que salgas del servidor.'))
  end

  W.section(tr('Cuándo sanciona'))
  W.check(tr('Sancionar solo en carrera'), 'raceOnly',
    tr('Marcado: en práctica solo se cuentan las faltas y en clasificación solo se invalida la vuelta. Sin marcar: se sanciona en todas las sesiones.'))

  W.section(tr('Reglamento en uso'))
  W.summary()
  W.hint(tr('Cada valor se cambia en las otras pestañas.'))
  if ui.button(tr('Restablecer el reglamento por defecto')) then W.resetRules() end
  W.tip(tr('Vuelve a los valores con que viene la app. No cambia el tipo de salida ni la pantalla.'))

  W.section(tr('Carreras online'))
  if serverAuth == 0 then
    if ui.checkbox(tr('Soy el director de carrera'), stored.director) then stored.director = not stored.director end
    W.tip(tr('Tu reglamento y tus banderas valen para todos en el servidor. Si nadie es director, cada piloto corre con sus propias reglas.'))
  end
  W.label(tr('Clave de administrador'),
    tr('Solo si el servidor tiene una (adminPass en sus opciones). Quien la escriba fija el reglamento, el tipo de salida y las banderas; los demás no pueden cambiarlos ni apagar el comisario.'))
  pcall(function ()
    local flags = ui.InputTextFlags and ui.InputTextFlags.Password or nil
    ui.setNextItemWidth(W.ctlW)
    local text, changed = ui.inputText('##adminKey', stored.adminKey, flags)
    if changed and type(text) == 'string' then stored.adminKey = text end
  end)
  W.hint(tr('Online, cada piloto necesita esta app instalada.'))
end

function W.tabRace(all)
  if serverOverride then
    ui.pushStyleColor(ui.StyleColor.Text, COL_YELLOW)
    ui.textWrapped(serverOverride.startMode == 2
      and tr('El servidor tiene la salida bloqueada en lanzada (lockStart = 1). Lo que elijas aquí no se usa en este servidor.')
      or tr('El servidor tiene la salida bloqueada en parada (lockStart = 1). Lo que elijas aquí no se usa en este servidor.'))
    ui.popStyleColor()
  elseif serverLinked then
    ui.pushStyleColor(ui.StyleColor.Text, COL_GREEN)
    ui.textWrapped(tr('Enlazado con el script del servidor: se usa el tipo de salida y la velocidad que elijas aquí.'))
    ui.popStyleColor()
  end

  W.section(tr('Tipo de salida'))
  W.radio(tr('Salida'), 'startMode', { tr('Parada'), tr('Lanzada') }, 1,
    tr('Parada: desde la grilla, con el semáforo del juego. Lanzada: los autos ruedan en fila hasta la bandera verde.'))
  if cfg.startMode == 2 or all then
    W.slider(tr('Velocidad máxima antes de la verde'), 'formSpeed', 60, 200, '%.0f km/h')
    W.check(tr('Salida corta'), 'formShort',
      tr('Los autos parten en fila cerca del final de la vuelta, sin dar la vuelta de formación completa. Online necesita el script del servidor.'))
    if cfg.formShort or all then
      W.slider(tr('El primero parte a'), 'formStartM', 200, 2000, tr('%.0f m de la meta'),
        tr('Offline, si ahí la pista es curva, la fila se arma en el primer tramo recto más atrás (hasta 400 m).'))
      W.check(tr('Radar de distancia'), 'formRadar',
        tr('En la formación, debajo del velocímetro: la distancia al auto que tienes que seguir y si estás muy cerca o muy lejos. En dos filas, también tu carril y si te pasaste al otro.'))
      W.check(tr('Dos filas'), 'formTwoWide',
        tr('Los autos parten de a dos, uno al lado del otro y en el orden de la grilla. Vale offline; online lo decide el script del servidor (twoWide). La IA tiende a ponerse en una sola fila al avanzar.'))
    end
    if all then
      W.slider(tr('Bandera verde'), 'formGreen', 0, 250, tr('%.0f m antes de la meta'),
        tr('La verde sale un poco antes de la meta para que el auto ya esté libre al cruzarla. Adelantar, solo después de la meta.'))
    end
    W.hint(tr('Sin salida corta, la primera vuelta es de formación y el juego la cuenta: conviene sumar una vuelta a la carrera.'))
  end

  W.section(tr('Faltas en la largada'))
  W.check(tr('Vigilar la salida en falso'), 'jumpEnabled', tr('Moverse antes de la luz verde. Solo en salida parada.'))
  W.check(tr('Sanción según la velocidad'), 'tiers',
    tr('Como en Real Penalty. Pits: hasta 100 km/h, drive-through; hasta 200, stop and go de 10 s; más, descalificación. Salida en falso: hasta 50 km/h, drive-through; hasta 200, stop and go de 10 s; más, descalificación. Formación: pasar el límite, drive-through; pasarlo por más de un 25% o adelantar, stop and go de 30 s.'))
  if all or not cfg.tiers then
    W.kind(tr('Sanción en la largada'), 'jumpPenalty',
      tr('Por salida en falso, o por correr o adelantar antes de la bandera verde. Se usa cuando la sanción no depende de la velocidad.'))
  end
end

function W.tabTrack(all)
  W.section(tr('Límites de pista'))
  W.check(tr('Vigilar los límites de pista'), 'tlEnabled')
  W.slider(tr('Avisos antes de sancionar'), 'tlWarnings', 0, 10, '%.0f')
  W.kind(tr('Sanción'), 'tlPenalty', tr('La que recibes al pasarte de avisos.'))
  if all then
    W.radio(tr('Qué salida cuenta'), 'tlMode', { tr('Toda salida'), tr('Solo el atajo con ventaja') }, 1,
      tr('Con "solo el atajo con ventaja", salirse y perder tiempo no cuenta: cuenta cortar camino o volver sin soltar el acelerador.'), true)
    W.check(tr('Después de la sanción, los avisos vuelven a cero'), 'tlReset')
    W.check(tr('Desde la segunda sanción de tiempo, el doble'), 'tlDouble')
    W.slider(tr('Ruedas fuera para contar'), 'tlWheels', 3, 4, '%.0f')
    W.slider(tr('Tiempo fuera para contar'), 'tlMinTime', 0.1, 2, '%.1f s', nil, true)
    W.slider(tr('Velocidad mínima para contar'), 'tlMinSpeed', 0, 150, '%.0f km/h')
    W.slider(tr('Pausa entre dos salidas'), 'tlCooldown', 0, 10, '%.0f s',
      tr('Segundos de vuelta en la pista antes de que pueda contarse otra salida.'))
    if cfg.tlMode == 2 then
      W.slider(tr('No cuenta si vuelves más lento que'), 'tlSlowRatio', 50, 100, tr('%.0f %% de la velocidad'),
        tr('Si vuelves a la pista a menos de este porcentaje de la velocidad con que saliste, perdiste tiempo y no cuenta.'))
      W.slider(tr('Tiempo para soltar el acelerador'), 'tlPostTime', 0, 3, '%.0f s',
        tr('Después de volver a la pista todavía puedes soltar el acelerador para que no cuente.'))
      W.slider(tr('Una salida más larga es accidente'), 'tlMaxTime', 1, 10, '%.0f s')
    end
  end

  W.section(tr('Pits'))
  W.check(tr('Vigilar la velocidad en pits'), 'pitEnabled')
  W.slider(tr('Límite de velocidad'), 'pitLimit', 40, 120, '%.0f km/h')
  if all then
    W.slider(tr('Margen'), 'pitTolerance', 0, 10, '%.0f km/h', tr('Cuánto puedes pasarte del límite sin sanción.'))
  end
  if all or not cfg.tiers then
    W.kind(tr('Sanción por exceso'), 'pitPenalty', tr('Se usa cuando la sanción no depende de la velocidad (pestaña Largada).'))
  end
end

function W.tabContact(all)
  W.section(tr('Contactos entre autos'))
  W.check(tr('Vigilar los contactos'), 'ctEnabled')
  W.slider(tr('Avisos antes de sancionar'), 'ctWarnings', 0, 5, '%.0f')
  W.kind(tr('Sanción por contacto evitable'), 'ctMedPenalty')
  W.kind(tr('Sanción por choque fuerte'), 'ctHeavyPenalty', tr('Con sanción de tiempo, vale el doble.'))

  W.section(tr('Devolver la posición'))
  W.check(tr('Pedir que devuelvas el puesto antes de sancionar'), 'gbEnabled',
    tr('Si ganas un puesto con un contacto o por fuera de la pista, primero se te pide dejar pasar al otro piloto.'))
  W.slider(tr('Plazo para devolverlo'), 'gbSec', 5, 60, '%.0f s')
  W.kind(tr('Sanción si no lo devuelves'), 'gbPenalty')
  W.check(tr('Vigilar adelantamientos por fuera de la pista'), 'passOffEnabled')

  if all then
    W.section(tr('Cómo se mide un contacto'))
    W.slider(tr('Roce sin sanción hasta'), 'ctLight', 2, 30, tr('%.0f km/h de diferencia'))
    W.slider(tr('Choque fuerte desde'), 'ctHeavy', 10, 80, tr('%.0f km/h de diferencia'))
    W.slider(tr('Golpe contra el muro desde'), 'wallMinKmh', 5, 50, tr('%.0f km/h perdidos'))
    W.radio(tr('Quién responde'), 'faultMode', { tr('El que alcanza por detrás'), tr('Los dos') }, 1,
      tr('"Los dos" es como iRacing: ambos pilotos suman puntos de incidente y no hay culpable.'), true)
    W.check(tr('Si el golpeado pierde el auto, cuenta como choque fuerte'), 'ctReview')
  end
end

function W.tabIncidents(all)
  W.section(tr('Puntos de incidente'))
  W.hint(tr('Cada falta suma puntos (1x, 2x, 4x). Sirven para sancionar al piloto que acumula muchas faltas pequeñas.'))
  W.check(tr('Contar puntos de incidente'), 'incEnabled')
  W.slider(tr('Descalificación al pasar de'), 'incDQ', 0, 80, tr('%.0f puntos'), tr('0 = nunca.'))
  W.slider(tr('Sanción cada'), 'incStep', 0, 40, tr('%.0f puntos'), tr('0 = nunca.'))
  if cfg.incStep > 0 or all then
    W.kind(tr('Sanción al llegar a ese número'), 'incPenalty')
  end
  if all then
    W.section(tr('Cuánto suma cada falta'))
    W.slider(tr('Salida de pista'), 'incOff', 0, 4, '%.0fx')
    W.slider(tr('Pérdida de control'), 'incSpin', 0, 4, '%.0fx')
    W.slider(tr('Golpe contra el muro'), 'incWall', 0, 4, '%.0fx')
    W.slider(tr('Contacto con otro auto'), 'incContact', 0, 4, '%.0fx')
    W.slider(tr('Choque fuerte'), 'incHeavy', 0, 8, '%.0fx')
    W.check(tr('Sumar todos los incidentes'), 'incSum',
      tr('Sin marcar, de varios incidentes seguidos solo cuenta el mayor, como en iRacing.'))
  end
end

function W.tabPenalties(all)
  W.section(tr('Cuánto dura cada sanción'))
  W.slider(tr('Sanción de tiempo'), 'timeSec', 1, 30, '%.0f s', tr('Segundos que se suman a tu tiempo final.'))
  W.slider(tr('Drive-through: vueltas de plazo'), 'dtLaps', 1, 5, '%.0f', tr('Vueltas que tienes para pasar por pits.'))
  W.slider(tr('Stop and go: detenido'), 'sgSec', 3, 30, '%.0f s')
  W.check(tr('No cumplir a tiempo es descalificación'), 'dtFailDQ',
    tr('Como en las carreras reales. Sin marcar, no cumplir un drive-through o un stop and go suma tiempo.'))
  if all or not cfg.dtFailDQ then
    W.slider(tr('Si no cumples'), 'dtFailSec', 5, 120, '+%.0f s')
  end
  if all then
    W.slider(tr('Cambio por tiempo al final'), 'endLaps', 0, 5, '%.0f',
      tr('Una sanción recibida cuando ya no quedan vueltas para cumplirla se puede cambiar por tiempo. El número son las vueltas de margen sobre el plazo; 0 = no se cambia.'))
    W.section(tr('Levantar el pie'))
    W.slider(tr('Tiempo sin acelerar'), 'liftSec', 1, 10, '%.0f s')
    W.slider(tr('Plazo para hacerlo'), 'liftWindow', 10, 60, '%.0f s')
    W.slider(tr('Si no lo haces'), 'liftFailSec', 1, 60, '+%.0f s')
    W.check(tr('Experimental: que el juego corte el acelerador'), 'forceCut')
  end
  W.tabIncidents(all)
end

function W.tabFlags(all)
  W.check(tr('Mostrar banderas de pista'), 'flEnabled',
    tr('Verde: pista libre. Amarilla: auto detenido o sin control adelante. Azul: viene alguien que te saca una vuelta. Blanca: última vuelta. A cuadros: meta. Negra: descalificado.'))

  W.section(tr('Bandera amarilla'))
  W.check(tr('Prohibido adelantar con amarilla'), 'yfPass', tr('Primero se pide devolver el puesto y, si no, viene la sanción.'))
  W.kind(tr('Sanción'), 'yfPenalty', tr('Por adelantar o correr con amarilla, amarilla total o roja.'))
  if all then
    W.slider(tr('Peligro hasta'), 'yfDist', 100, 600, tr('%.0f m adelante'))
  end

  W.section(tr('Bandera azul'))
  W.check(tr('Mostrar la bandera azul'), 'bfEnabled')
  if all then
    W.slider(tr('Tiempo para ceder el paso'), 'bfSec', 5, 60, '%.0f s')
    W.kind(tr('Sanción por no ceder el paso'), 'bfPenalty', tr('"Ninguna" deja solo el aviso.'))
  end

  W.section(tr('Amarilla total y bandera roja'))
  W.slider(tr('Velocidad máxima'), 'fcySpeed', 40, 150, '%.0f km/h')
  W.hint(tr('Los botones Amarilla total, Roja y Verde están en la ventana Comisario. Offline los usas tú; online, solo el director de carrera.'))
end

function W.tabScreen(all)
  W.check(tr('Mostrar un ejemplo para acomodarla'), 'hudPlace', tr('Deja a la vista todos los indicadores mientras eliges el lugar y el tamaño.'))
  W.slider(tr('Tamaño'), 'hudScale', 0.6, 2.5, '%.1f', nil, true)
  W.slider(tr('Altura'), 'hudY', 0, 85, '%.0f %%', tr('0 = arriba de la pantalla.'))
  W.slider(tr('Posición horizontal'), 'hudX', 5, 95, '%.0f %%', tr('50 = al centro.'))
  W.check(tr('Fondo oscuro detrás del texto'), 'hudBg')
  W.check(tr('Íconos de banderas y sanciones'), 'hudIcons')
  W.check(tr('Mostrar también el mensaje grande del juego'), 'showSystemMsg')
  if all then
    W.section(tr('Ventanas sueltas'))
    W.check(tr('Interfaz fija'), 'hudFixed',
      tr('Marcado: los indicadores van en un lugar fijo y no se mueven. Sin marcar: cada uno es una ventana que arrastras con el mouse.'))
    if ui.button(tr('Abrir todos los indicadores')) then
      for _, id in ipairs(HUD_IDS) do pcall(ac.setWindowOpen, id, true) end
    end
    ui.sameLine(0, 8)
    if ui.button(tr('Cerrar todos')) then
      for _, id in ipairs(HUD_IDS) do pcall(ac.setWindowOpen, id, false) end
    end
  end
end

function W.tabMore(all)
  W.section(tr('Inteligencia artificial (offline)'))
  W.radio(tr('Sanciones a la IA'), 'aiMode', { tr('No vigilarla'), tr('Solo tiempo'), tr('Que cumpla en pista') }, 0,
    tr('"Solo tiempo" suma la sanción en la clasificación. "Que cumpla en pista": la IA suelta el acelerador o entra a pits.'), true)
  if all then
    W.check(tr('Drive-through de la IA: mandarla a pits de verdad'), 'aiPitDt')
    W.slider(tr('Si la IA no puede cumplirlo'), 'aiDtSec', 5, 40, '+%.0f s')
  end
  W.check(tr('Mostrar los incidentes de los demás en el panel'), 'showAiEvents')
  drawTrackPhysics()

  W.section(tr('Registro'))
  W.check(tr('Guardar registro en archivo'), 'writeLog', tr('Sirve para revisar qué pasó en una carrera o para reportar un error.'))
  W.hint(logPath())

  W.section(tr('Pruebas'))
  W.hint(tr('Botones para ver cada sanción sin cometer la falta:'))
  local car = ac.getCar(0)
  if car then
    if ui.button(tr('Aviso')) then
      announce(1, tr('AVISO DE PRUEBA'), tr('Así se ve un aviso'), car.lapCount + 1)
    end
    ui.sameLine(0, 6)
    if ui.button(tr('Tiempo')) then issuePenalty(KIND_TIME, tr('Prueba'), car) end
    ui.sameLine(0, 6)
    if ui.button(tr('Levantar')) then issuePenalty(KIND_LIFT, tr('Prueba'), car) end
    ui.sameLine(0, 6)
    if ui.button('Drive-through') then issuePenalty(KIND_DT, tr('Prueba'), car) end
    local rival = ac.getCar(1)
    if rival and not online then
      if ui.button(tr('Rival 1: levantar')) then aiPenalty(1, rival, KIND_LIFT, 1, tr('Prueba'), true) end
      ui.sameLine(0, 6)
      if ui.button(tr('Rival 1: drive-through')) then aiPenalty(1, rival, KIND_DT, 1, tr('Prueba'), true) end
    end
  end
  if ui.button(tr('Borrar sanciones y contadores')) then
    releaseAllAi()
    resetSession()
    addLog('Contadores reiniciados a mano')
  end
end

function W.draw(dt)
  -- ancho fijo: nombre a la izquierda, control a la derecha
  ui.dummy(vec2(W.labelW + W.ctlW + 12, 1))
  ui.alignTextToFramePadding()
  ui.textColored('Comisario ' .. VERSION, COL_DIM)
  ui.sameLine(W.labelW)
  -- el idioma se ofrece siempre en los dos idiomas
  if ui.radioButton('Español##lang', stored.lang ~= 2) then stored.lang = 1 end
  ui.sameLine(0, 10)
  if ui.radioButton('English##lang', stored.lang == 2) then stored.lang = 2 end
  W.check(tr('Comisario activo'), 'enabled', tr('Apagado, la app no vigila ni sanciona.'))
  ui.sameLine(W.labelW)
  W.check(tr('Mostrar todas las opciones'), 'setAll', tr('Sin marcar se ven solo las opciones principales de cada pestaña.'))
  local all = cfg.setAll

  ui.tabBar('comisarioTabs', function ()
    ui.tabItem(tr('Inicio') .. '###comisarioTab1', function () W.tabStart(all) end)
    ui.tabItem(tr('Largada') .. '###comisarioTab2', function () W.tabRace(all) end)
    ui.tabItem(tr('Pista') .. '###comisarioTab3', function () W.tabTrack(all) end)
    ui.tabItem(tr('Contactos') .. '###comisarioTab4', function () W.tabContact(all) end)
    ui.tabItem(tr('Sanciones') .. '###comisarioTab6', function () W.tabPenalties(all) end)
    ui.tabItem(tr('Banderas') .. '###comisarioTab7', function () W.tabFlags(all) end)
    ui.tabItem(tr('Pantalla') .. '###comisarioTab8', function () W.tabScreen(all) end)
    ui.tabItem(tr('Más') .. '###comisarioTab9', function () W.tabMore(all) end)
  end)
end

function script.windowSettings(dt)
  -- si algo de la ventana falla en esta version del juego, se muestra el error en vez de dejarla en blanco
  local ok, err = pcall(W.draw, dt)
  if not ok then
    if lastError ~= tostring(err) then
      lastError = tostring(err)
      addLog('ERROR en ajustes: ' .. lastError)
    end
    ui.textWrapped('Comisario ' .. VERSION .. ': ' .. tostring(err))
  end
end

-- ---------------------------------------------------------------------------
-- 15. IDIOMAS
--     Cada linea es: EN['texto en espanol, tal como aparece dentro de tr()'] = 'texto en ingles'.
--     Los %s, %d y %.0f son huecos que se llenan con nombres o numeros: tienen que quedar los mismos
--     y en el mismo orden. Si falta una linea, ese texto sale en espanol.
-- ---------------------------------------------------------------------------

-- nombres y palabras sueltas
EN['Ninguna'] = 'None'
EN['Tiempo'] = 'Time'
EN['Levantar el pie'] = 'Lift off'
EN['Carrera'] = 'Race'
EN['Clasificación'] = 'Qualifying'
EN['Práctica'] = 'Practice'
EN['Sesión'] = 'Session'
EN['Tú'] = 'You'
EN['TÚ'] = 'YOU'
EN['Auto %s'] = 'Car %s'
EN['Prueba'] = 'Test'

-- titulos de los avisos
EN['SANCIÓN CUMPLIDA'] = 'PENALTY SERVED'
EN['POSICIÓN DEVUELTA'] = 'POSITION GIVEN BACK'
EN['SANCIÓN +'] = 'PENALTY +'
EN['SANCIÓN +%s s'] = 'PENALTY +%s s'
EN['LEVANTA EL PIE'] = 'LIFT OFF'
EN['LEVANTA EL PIE %s s'] = 'LIFT OFF %s s'
EN['STOP AND GO %s s'] = 'STOP AND GO %s s'
EN['DEVUELVE LA POSICIÓN'] = 'GIVE THE POSITION BACK'
EN['DESCALIFICADO'] = 'DISQUALIFIED'
EN['VUELTA INVALIDADA'] = 'LAP INVALIDATED'
EN['STOP AND GO NO VÁLIDO'] = 'STOP AND GO NOT VALID'
EN['DRIVE-THROUGH NO VÁLIDO'] = 'DRIVE-THROUGH NOT VALID'
EN['ORDEN ANULADA'] = 'ORDER CANCELLED'
EN['POSICIÓN NO DEVUELTA'] = 'POSITION NOT GIVEN BACK'
EN['SANCIÓN A %s'] = 'PENALTY FOR %s'
EN['ATENCIÓN'] = 'CAUTION'
EN['LÍMITES DE PISTA'] = 'TRACK LIMITS'
EN['SALIDA DE PISTA'] = 'OFF TRACK'
EN['AVISO %s/%s LÍMITES DE PISTA'] = 'WARNING %s/%s TRACK LIMITS'
EN['PÉRDIDA DE CONTROL'] = 'LOSS OF CONTROL'
EN['VELOCIDAD EN PITS'] = 'PIT LANE SPEED'
EN['SALIDA EN FALSO'] = 'JUMP START'
EN['CONTACTO'] = 'CONTACT'
EN['CHOQUE'] = 'CRASH'
EN['AVISO POR CONTACTO'] = 'CONTACT WARNING'
EN['AVISO A %s'] = 'WARNING FOR %s'
EN['INCIDENTE DE CARRERA'] = 'RACING INCIDENT'
EN['INCIDENTE BAJO INVESTIGACIÓN'] = 'INCIDENT UNDER INVESTIGATION'
EN['GOLPE CONTRA EL MURO'] = 'WALL HIT'
EN['SALIDA LANZADA NO DISPONIBLE'] = 'ROLLING START NOT AVAILABLE'
EN['SALIDA LANZADA'] = 'ROLLING START'
EN['VUELTA DE FORMACIÓN'] = 'FORMATION LAP'
EN['BANDERA VERDE'] = 'GREEN FLAG'
EN['AMARILLA TOTAL'] = 'FULL COURSE YELLOW'
EN['BANDERA ROJA'] = 'RED FLAG'
EN['BANDERA AMARILLA'] = 'YELLOW FLAG'
EN['BANDERA AZUL'] = 'BLUE FLAG'
EN['BANDERA NEGRA'] = 'BLACK FLAG'
EN['ÚLTIMA VUELTA'] = 'LAST LAP'
EN['CARRERA TERMINADA'] = 'RACE FINISHED'
EN['GANASTE LA CARRERA'] = 'YOU WON THE RACE'
EN['GANADOR: %s'] = 'WINNER: %s'
EN['AVISO DEL COMISARIO'] = 'STEWARD NOTICE'
EN['AVISO DE PRUEBA'] = 'TEST NOTICE'
EN['SANCIÓN PENDIENTE'] = 'PENDING PENALTY'
EN['ORDEN DEL COMISARIO'] = 'STEWARD ORDER'

-- online
EN['Se usa el reglamento de %s, director de carrera'] = 'Using the rules of %s, race director'
EN['El director de carrera ya no esta: bandera verde'] = 'The race director has left: green flag'
EN['El director de carrera ya no esta: vuelven tus reglas'] = 'The race director has left: back to your own rules'

-- sanciones
EN['Vuelta %s ya estaba invalidada: %s'] = 'Lap %s was already invalidated: %s'
EN['%s. El tiempo de esta vuelta no cuenta'] = '%s. This lap time does not count'
EN['vuelta invalidada: %s'] = 'lap invalidated: %s'
EN['%s. Se suma a tu tiempo final'] = '%s. Added to your final time'
EN['descalificado: %s'] = 'disqualified: %s'
EN['quedan pocas vueltas: cúmplelo o termina la carrera con +%s s'] = 'few laps left: serve it or finish the race with +%s s'
EN['tienes %s vueltas'] = 'you have %s laps'
EN['%s. Suelta el acelerador antes de %s s'] = '%s. Lift off the throttle within %s s'
EN['levantar el pie: %s'] = 'lift off: %s'
EN['%s. Entra a pits y detente %s segundos, %s'] = '%s. Enter the pits and stop for %s seconds, %s'
EN['%s. Pasa por pits sin detenerte, %s'] = '%s. Drive through the pits without stopping, %s'
EN['cumplio: levantar el pie'] = 'served: lift off'
EN['No levantaste el pie a tiempo'] = 'You did not lift off in time'
EN['%s no cumplido en %s vueltas'] = '%s not served within %s laps'
EN['%s no cumplido'] = '%s not served'
EN['cumplio: stop and go'] = 'served: stop and go'
EN['Debías detenerte %d s en pits y estuviste %.0f'] = 'You had to stop for %d s in the pits and stopped for %.0f'
EN['Te detuviste en boxes. Hay que pasar sin parar'] = 'You stopped in your pit box. You must drive through without stopping'
EN['cumplio: drive-through'] = 'served: drive-through'

-- devolver la posicion
EN['Deja pasar a %s antes de %s s. Motivo: %s'] = 'Let %s through within %s s. Reason: %s'
EN['debe devolver la posicion a %s'] = 'must give the position back to %s'
EN['%s ya no está en pista. Sin sanción'] = '%s is no longer on track. No penalty'
EN['Sin sanción. %s recuperó su puesto'] = 'No penalty. %s got the place back'
EN['devolvio la posicion a %s'] = 'gave the position back to %s'
EN['%s (quedó detenido)'] = '%s (the other car stopped)'
EN['%s quedó detenido. Sin sanción'] = '%s has stopped. No penalty'
EN['No dejaste pasar a %s'] = 'You did not let %s through'
EN['No devolviste la posición a %s'] = 'You did not give the position back to %s'
EN['Deja pasar a %s'] = 'Let %s through'

-- IA
EN['levantar el pie %s s'] = 'lift off for %s s'
EN['pasar por pits'] = 'drive through the pits'
EN['+%s s en la clasificación'] = '+%s s in the results'
EN['Sanción a %s: %s'] = 'Penalty for %s: %s'
EN['%s levanta el pie delante tuyo'] = '%s is lifting off right ahead of you'
EN['%s cumplió: levantó el pie %s s'] = '%s served it: lifted off for %s s'
EN['%s no entró a pits: +%s s en la clasificación'] = '%s did not pit: +%s s in the results'
EN['%s cumplió: pasó por pits'] = '%s served it: drove through the pits'

-- incidentes
EN['Pasaste el máximo de %s puntos de incidente (llevas %sx)'] = 'You went over the maximum of %s incident points (you have %sx)'
EN['descalificado con %s puntos de incidente'] = 'disqualified with %s incident points'
EN['%s descalificado por %s puntos de incidente'] = '%s disqualified for %s incident points'
EN['Límite de incidentes (%sx)'] = 'Incident limit (%sx)'
EN['+%sx de incidente (llevas %sx)'] = '+%sx incident (you have %sx)'
EN['Sin puntos extra: ya contaba un incidente mayor (llevas %sx)'] = 'No extra points: a bigger incident was already counted (you have %sx)'

-- limites de pista
EN['Atajo con ventaja'] = 'Cut with an advantage'
EN['Saliste de la pista'] = 'You went off track'
EN['Límites de pista'] = 'Track limits'
EN['Salida número %s. En práctica solo se cuenta'] = 'Off track number %s. In practice it is only counted'
EN['Te queda 1 aviso'] = 'You have 1 warning left'
EN['Te quedan %s avisos'] = 'You have %s warnings left'
EN['La próxima salida es sanción'] = 'The next one is a penalty'
EN['aviso %s/%s por limites de pista'] = 'warning %s/%s for track limits'
EN['Salida de pista sin ventaja: soltaste a tiempo'] = 'Off track with no advantage: you lifted in time'
EN['Salida de pista. %s'] = 'Off track. %s'
EN['Adelantamiento por fuera de la pista'] = 'Overtaking off track'
EN['%s: pérdida de control %s'] = '%s: loss of control %s'

-- pits y salida en falso
EN['Exceso en pits: %s km/h (límite %s)'] = 'Pit lane speeding: %s km/h (limit %s)'
EN['%s. Sin sanción en esta sesión'] = '%s. No penalty in this session'
EN['Salida en falso (%s km/h antes de la luz verde)'] = 'Jump start (%s km/h before the green light)'
EN['Te moviste antes de la luz verde. La sanción depende de la velocidad que alcances'] = 'You moved before the green light. The penalty depends on the speed you reach'
EN['Salida en falso'] = 'Jump start'

-- contactos
EN['Causar un choque contigo'] = 'Causing a crash with you'
EN['Contacto evitable contigo'] = 'Avoidable contact with you'
EN['Causar un choque con %s'] = 'Causing a crash with %s'
EN['Contacto evitable con %s'] = 'Avoidable contact with %s'
EN['%s (perdió el control)'] = '%s (lost control)'
EN['%s. En esta sesión solo se cuenta'] = '%s. In this session it is only counted'
EN['Choque con %s'] = 'Crash with %s'
EN['aviso: %s'] = 'warning: %s'
EN['Por el contacto contigo'] = 'For the contact with you'
EN['Aviso a %s: %s'] = 'Warning for %s: %s'
EN['Contacto con %s: la sanción la decide su Comisario'] = 'Contact with %s: the penalty is decided by their Comisario app'
EN['Roce con %s, sin sanción'] = 'Light touch with %s, no penalty'
EN['Con %s'] = 'With %s'
EN['Contacto lado a lado con %s, sin sanción'] = 'Side by side contact with %s, no penalty'
EN['Contacto con %s'] = 'Contact with %s'
EN['%s: golpe contra el muro %s'] = '%s: wall hit %s'

-- largada
EN['Esta pista no permite controlar a la IA. Se usa la salida parada'] = 'This track does not allow AI control. Using a standing start'
EN['Mantén tu puesto y no pases de %s km/h. Se larga cuando el líder llegue a la meta'] = 'Hold your position and stay under %s km/h. The race starts when the leader reaches the line'
EN['Mantén tu puesto y no pases de %s km/h. Se larga cuando el líder cruce la meta'] = 'Hold your position and stay under %s km/h. The race starts when the leader crosses the line'
EN['Salida corta no disponible aquí: vuelta de formación completa'] = 'Short start not available here: full formation lap'
EN['Carrera lanzada'] = 'Race is on'
EN['Carrera lanzada. Puedes adelantar después de cruzar la meta'] = 'Race is on. You may overtake after crossing the line'
EN['Exceso de velocidad en la vuelta de formación'] = 'Speeding on the formation lap'
EN['Adelantamiento antes de la largada'] = 'Overtaking before the start'

-- banderas
EN['bandera verde'] = 'green flag'
EN['amarilla total'] = 'full course yellow'
EN['bandera roja'] = 'red flag'
EN['. Orden de %s'] = '. Ordered by %s'
EN['Máximo %s km/h y prohibido adelantar'] = 'Maximum %s km/h and no overtaking'
EN['Sesión detenida: máximo %s km/h, sin adelantar, vuelve a pits'] = 'Session stopped: maximum %s km/h, no overtaking, return to the pits'
EN['Pista libre'] = 'Track clear'
EN['%s detenido o sin control a %s m. Prohibido adelantar'] = '%s stopped or out of control %s m ahead. No overtaking'
EN['Adelantamiento con bandera roja'] = 'Overtaking under red flag'
EN['Adelantamiento con bandera amarilla'] = 'Overtaking under yellow flag'
EN['Exceso de velocidad con %s'] = 'Speeding under %s'
EN['Deja pasar a %s, te saca una vuelta'] = 'Let %s through, they are lapping you'
EN['Deja pasar a %s, viene más rápido'] = 'Let %s through, they are faster'
EN['No cediste el paso a %s con bandera azul'] = 'You did not let %s through under blue flag'
EN['NEGRA'] = 'BLACK'
EN['META'] = 'FINISH'
EN['ROJA · MÁX %s'] = 'RED · MAX %s'
EN['AMARILLA TOTAL · MÁX %s'] = 'FCY · MAX %s'
EN['AMARILLA · NO ADELANTAR'] = 'YELLOW · NO OVERTAKING'
EN['AZUL · CEDE EL PASO'] = 'BLUE · LET THEM THROUGH'
EN['VERDE'] = 'GREEN'

-- final de carrera
EN['Sanción total: +%s s.  Incidentes: %sx'] = 'Total penalty: +%s s.  Incidents: %sx'
EN['Resultado con las sanciones aplicadas'] = 'Result with penalties applied'
EN['Cruzaste primero la meta, pero estás descalificado'] = 'You crossed the line first, but you are disqualified'
EN['Cruzaste primero la meta, pero tienes +%s s de sanción'] = 'You crossed the line first, but you have a +%s s penalty'
EN['%s cruzó primero la meta, pero está descalificado'] = '%s crossed the line first, but is disqualified'
EN['%s cruzó primero la meta, pero tiene +%s s de sanción'] = '%s crossed the line first, but has a +%s s penalty'
EN['Vuelta %s no cuenta: %s'] = 'Lap %s does not count: %s'
EN['Mejor vuelta válida: %s'] = 'Best valid lap: %s'

-- ventana principal
EN['detente en pits: %.0f / %d s'] = 'stop in the pits: %.0f / %d s'
EN['pasando por pits, no te detengas'] = 'driving through the pits, do not stop'
EN['entra a pits en esta vuelta'] = 'pit this lap'
EN['entra a pits, quedan %s vueltas'] = 'enter the pits, %s laps left'
EN['LEVANTA EL PIE: %.1f / %d s   (quedan %.0f s)'] = 'LIFT OFF: %.1f / %d s   (%.0f s left)'
EN['   Motivo: %s'] = '   Reason: %s'
EN['reglas: las tuyas'] = 'rules: your own'
EN['reglas: las de %s'] = 'rules: from %s'
EN['eres el administrador'] = 'you are the administrator'
EN['reglamento por defecto, a la espera del administrador'] = 'default rules, waiting for the administrator'
EN['eres el director de carrera'] = 'you are the race director'
EN[', salida impuesta por el servidor'] = ', start type set by the server'
EN[', enlazado con el script del servidor'] = ', linked to the server script'
EN['Online: %s pilotos más con Comisario, %s'] = 'Online: %s more drivers with Comisario, %s'
EN['IA: sin vigilar'] = 'AI: not watched'
EN['IA: sanción en la clasificación'] = 'AI: penalty in the results'
EN['IA: el juego ignora las órdenes, sanción en la clasificación'] = 'AI: the game ignores the orders, penalty in the results'
EN['IA: esta pista no permite controlarla, sanción en la clasificación (ver ajustes)'] = 'AI: this track does not allow control, penalty in the results (see settings)'
EN['IA: cumple en pista (levanta el pie o entra a pits)'] = 'AI: serves on track (lifts off or pits)'
EN['Esperando al auto...'] = 'Waiting for the car...'
EN['desactivado'] = 'disabled'
EN[' - sanciones activas'] = ' - penalties active'
EN[' - solo se invalida la vuelta'] = ' - laps are only invalidated'
EN[' - solo se cuenta, sin sanciones'] = ' - only counting, no penalties'
EN['Error interno (envíaselo a quien te ayuda):'] = 'Internal error (send it to whoever helps you):'
EN['Bandera:'] = 'Flag:'
EN['pista libre'] = 'track clear'
EN['Amarilla total'] = 'Full course yellow'
EN['Roja'] = 'Red'
EN['Verde'] = 'Green'
EN['DEVUELVE LA POSICIÓN a %s (quedan %.0f s)'] = 'GIVE THE POSITION BACK to %s (%.0f s left)'
EN['Incidentes:'] = 'Incidents:'
EN[' (sanción cada %sx)'] = ' (penalty every %sx)'
EN[' (máximo %sx)'] = ' (maximum %sx)'
EN['Límites de pista:'] = 'Track limits:'
EN['%s/%s avisos'] = '%s/%s warnings'
EN['Sanción de tiempo:'] = 'Time penalty:'
EN['salidas %s  contactos %s  cumplidas %s'] = 'offs %s  contacts %s  served %s'
EN['Sin incidentes.'] = 'No incidents.'
EN['V%s  '] = 'L%s  '

-- clasificacion
EN['Clasificación corregida con sanciones'] = 'Results corrected with penalties'
EN['Orden en pista (se corrige al terminar la carrera)'] = 'Order on track (corrected when the race ends)'
EN['Piloto'] = 'Driver'
EN['Sanción'] = 'Penalty'
EN['sin app'] = 'no app'
EN['debe levantar'] = 'must lift'
EN['debe pits'] = 'must pit'
EN['ganador'] = 'winner'
EN['+%s v'] = '+%s L'

-- indicadores
EN['Aquí aparece lo que pasó y por qué'] = 'What happened and why shows up here'
EN['MANTÉN P%s'] = 'HOLD P%s'
EN['NO ADELANTAR'] = 'NO OVERTAKING'
EN['MÁX %s'] = 'MAX %s'
EN['MÁX %s km/h'] = 'MAX %s km/h'
EN['Quedas en pits, con el auto bloqueado'] = 'You stay in the pits, with the car locked'
EN['Suelta el acelerador %d segundos. Plazo: %.0f s'] = 'Lift off the throttle for %d seconds. Time left: %.0f s'
EN['Detente por completo en pits'] = 'Come to a full stop in the pits'
EN['Entra a pits y detente %s s'] = 'Enter the pits and stop for %s s'
EN['Sigue sin parar hasta salir de pits'] = 'Keep going without stopping until you leave the pits'
EN['Pasa por pits sin parar'] = 'Drive through the pits without stopping'
EN['Aquí aparece lo que tienes que cumplir'] = 'What you have to serve shows up here'
EN['1 de %s'] = '1 of %s'
EN['ÚLTIMA OPORTUNIDAD: ENTRA EN ESTA VUELTA'] = 'LAST CHANCE: PIT THIS LAP'
EN['VUELTAS PARA CUMPLIR: %s'] = 'LAPS TO SERVE IT: %s'
EN['CARRERA'] = 'RACE'
EN['FORMACIÓN'] = 'FORMATION'
EN['ADELANTA DESPUÉS DE LA META'] = 'OVERTAKE AFTER THE LINE'
EN['CLASIFICACIÓN'] = 'QUALIFYING'
EN['VUELTA INVÁLIDA'] = 'INVALID LAP'
EN['VUELTA VÁLIDA'] = 'VALID LAP'
EN['MEJOR %s'] = 'BEST %s'
EN['PRÁCTICA'] = 'PRACTICE'
EN['SOLO CUENTA'] = 'COUNTING ONLY'
EN['LÍMITES'] = 'LIMITS'
EN['LÍMITES %s/%s'] = 'LIMITS %s/%s'
EN['SALIDAS %s'] = 'OFFS %s'

-- control de la IA en la pista
EN['No encontré el archivo surfaces.ini de esta pista: %s'] = 'Could not find the surfaces.ini file of this track: %s'
EN['El archivo surfaces.ini de esta pista tiene un formato que no reconozco. No lo toqué.'] = 'The surfaces.ini file of this track has a format I do not recognise. It was left untouched.'
EN['No pude guardar el cambio (puede ser un problema de permisos de la carpeta del juego).'] = 'Could not save the change (it may be a permissions problem in the game folder).'
EN['Listo. Sal de la sesión y vuelve a entrar para que el cambio funcione.'] = 'Done. Leave the session and join again for the change to work.'
EN['Error al cambiar el archivo: %s'] = 'Error while changing the file: %s'
EN['No hay respaldo de esta pista.'] = 'There is no backup for this track.'
EN['No pude restaurar el archivo. El respaldo sigue en: %s'] = 'Could not restore the file. The backup is still at: %s'
EN['Pista restaurada. El cambio se nota al volver a entrar a la sesión.'] = 'Track restored. The change applies when you join the session again.'
EN['Error al restaurar el archivo: %s'] = 'Error while restoring the file: %s'
EN['Control de la IA en esta pista:'] = 'AI control on this track:'
EN['Permitido. La IA puede cumplir sus sanciones en pista.'] = 'Allowed. The AI can serve its penalties on track.'
EN['Cambio aplicado. Sal de la sesión y vuelve a entrar para que funcione.'] = 'Change applied. Leave the session and join again for it to work.'
EN['No permitido: por ahora las sanciones de la IA van a la clasificación.'] = 'Not allowed: for now AI penalties go to the results.'
EN['Assetto Corsa solo deja que una app controle a la IA si la pista lo autoriza. El botón agrega esa autorización al archivo surfaces.ini de esta pista y guarda una copia del original. Mientras el cambio esté puesto, los servidores online pueden rechazar esta pista; con Deshacer queda como estaba.'] = 'Assetto Corsa only lets an app control the AI if the track allows it. The button adds that permission to the surfaces.ini file of this track and keeps a copy of the original. While the change is in place, online servers may reject this track; Undo puts it back as it was.'
EN['Permitir en esta pista'] = 'Allow on this track'
EN['Deshacer el cambio en esta pista'] = 'Undo the change on this track'

-- ajustes: cabecera y pestanas
EN['Comisario activo'] = 'Comisario on'
EN['Apagado, la app no vigila ni sanciona.'] = 'When off, the app does not watch or penalise.'
EN['Mostrar todas las opciones'] = 'Show all options'
EN['Sin marcar se ven solo las opciones principales de cada pestaña.'] = 'Unticked, only the main options of each tab are shown.'
EN['Inicio'] = 'Home'
EN['Largada'] = 'Start'
EN['Pista'] = 'Track'
EN['Contactos'] = 'Contacts'
EN['Sanciones'] = 'Penalties'
EN['Banderas'] = 'Flags'
EN['Pantalla'] = 'Display'
EN['Más'] = 'More'

-- ajustes: inicio
EN['Límites de pista: %s'] = 'Track limits: %s'
EN['1 aviso y después %s'] = '1 warning, then %s'
EN['%s, sin aviso previo'] = '%s, with no warning first'
EN['%s avisos y después %s'] = '%s warnings, then %s'
EN['Límites de pista: sin sanción'] = 'Track limits: no penalty'
EN['Contacto evitable: %s'] = 'Avoidable contact: %s'
EN['Causar un choque fuerte: %s'] = 'Causing a heavy crash: %s'
EN['Contactos: sin vigilar'] = 'Contacts: not watched'
EN['Pits: límite de %s km/h'] = 'Pits: %s km/h limit'
EN['Más de %s puntos de incidente: descalificación'] = 'More than %s incident points: disqualification'
EN['No cumplir un drive-through en %s vueltas: descalificación'] = 'Not serving a drive-through within %s laps: disqualification'
EN['No cumplir un drive-through en %s vueltas: +%s s'] = 'Not serving a drive-through within %s laps: +%s s'
EN['Eres el administrador de este servidor: tu reglamento y tus banderas valen para todos.'] = 'You are the administrator of this server: your rules and flags apply to everyone.'
EN['Este servidor tiene administrador. Se usa su reglamento: lo que cambies aquí se guarda, pero no se aplica en este servidor.'] = 'This server has an administrator. Their rules are used: what you change here is saved, but not applied on this server.'
EN['En este servidor mandan las reglas de %s, director de carrera.'] = 'On this server the rules of %s, race director, apply.'
EN['Lo que cambies aquí se guarda, pero no se usa hasta que salgas del servidor.'] = 'What you change here is saved, but not used until you leave the server.'
EN['Cuándo sanciona'] = 'When it penalises'
EN['Sancionar solo en carrera'] = 'Penalise only in races'
EN['Marcado: en práctica solo se cuentan las faltas y en clasificación solo se invalida la vuelta. Sin marcar: se sanciona en todas las sesiones.'] = 'Ticked: in practice offences are only counted and in qualifying the lap is only invalidated. Unticked: penalties in every session.'
EN['Reglamento en uso'] = 'Rules in use'
EN['Cada valor se cambia en las otras pestañas.'] = 'Each value can be changed in the other tabs.'
EN['Restablecer el reglamento por defecto'] = 'Restore the default rules'
EN['Vuelve a los valores con que viene la app. No cambia el tipo de salida ni la pantalla.'] = 'Goes back to the values the app ships with. It does not change the start type or the display.'
EN['Carreras online'] = 'Online races'
EN['Soy el director de carrera'] = 'I am the race director'
EN['Tu reglamento y tus banderas valen para todos en el servidor. Si nadie es director, cada piloto corre con sus propias reglas.'] = 'Your rules and flags apply to everyone on the server. If nobody is the director, each driver races with their own rules.'
EN['Clave de administrador'] = 'Administrator key'
EN['Solo si el servidor tiene una (adminPass en sus opciones). Quien la escriba fija el reglamento, el tipo de salida y las banderas; los demás no pueden cambiarlos ni apagar el comisario.'] = 'Only if the server has one (adminPass in its options). Whoever types it sets the rules, the start type and the flags; the others cannot change them or turn the steward off.'
EN['Online, cada piloto necesita esta app instalada.'] = 'Online, every driver needs this app installed.'

-- ajustes: largada
EN['El servidor tiene la salida bloqueada en lanzada (lockStart = 1). Lo que elijas aquí no se usa en este servidor.'] = 'The server has the start locked to rolling (lockStart = 1). What you choose here is not used on this server.'
EN['El servidor tiene la salida bloqueada en parada (lockStart = 1). Lo que elijas aquí no se usa en este servidor.'] = 'The server has the start locked to standing (lockStart = 1). What you choose here is not used on this server.'
EN['Enlazado con el script del servidor: se usa el tipo de salida y la velocidad que elijas aquí.'] = 'Linked to the server script: the start type and speed you choose here are the ones used.'
EN['Tipo de salida'] = 'Start type'
EN['Salida'] = 'Start'
EN['Parada'] = 'Standing'
EN['Lanzada'] = 'Rolling'
EN['Parada: desde la grilla, con el semáforo del juego. Lanzada: los autos ruedan en fila hasta la bandera verde.'] = "Standing: from the grid, with the game's lights. Rolling: the cars roll in line until the green flag."
EN['Velocidad máxima antes de la verde'] = 'Top speed before the green'
EN['Salida corta'] = 'Short start'
EN['Los autos parten en fila cerca del final de la vuelta, sin dar la vuelta de formación completa. Online necesita el script del servidor.'] = 'The cars start in line near the end of the lap, without a full formation lap. Online it needs the server script.'
EN['El primero parte a'] = 'The leader starts'
EN['Dos filas'] = 'Two rows'
EN['PÁSATE A LA IZQUIERDA'] = 'MOVE TO THE LEFT'
EN['PÁSATE A LA DERECHA'] = 'MOVE TO THE RIGHT'
EN['CARRIL IZQUIERDO'] = 'LEFT LANE'
EN['CARRIL DERECHO'] = 'RIGHT LANE'
EN['Radar de distancia'] = 'Gap radar'
EN['En la formación, debajo del velocímetro: la distancia al auto que tienes que seguir y si estás muy cerca o muy lejos. En dos filas, también tu carril y si te pasaste al otro.'] = 'During the formation, below the speedometer: the gap to the car you have to follow and whether you are too close or too far. With two rows, also your lane and whether you drifted into the other one.'
EN['LÍDER: MARCAS EL RITMO'] = 'LEADER: SET THE PACE'
EN['TE ADELANTASTE'] = 'TOO FAR FORWARD'
EN['ABRE ESPACIO'] = 'BACK OFF'
EN['ACÉRCATE'] = 'CLOSE UP'
EN['BIEN'] = 'GOOD'
EN['DISTANCIA AL DE ADELANTE'] = 'GAP TO CAR AHEAD'
EN['Offline, si ahí la pista es curva, la fila se arma en el primer tramo recto más atrás (hasta 400 m).'] = 'Offline, if the track curves there, the grid is set up on the first straight further back (up to 400 m).'
EN['La IA no arrancó en dos filas: se larga en una sola fila'] = 'The AI did not pull away two by two: starting in a single line'
EN['Los autos parten de a dos, uno al lado del otro y en el orden de la grilla. Vale offline; online lo decide el script del servidor (twoWide). La IA tiende a ponerse en una sola fila al avanzar.'] = 'Cars start two by two, side by side and in grid order. Applies offline; online the server script decides (twoWide). The AI tends to fall into a single line once moving.'
EN['%.0f m de la meta'] = '%.0f m from the line'
EN['Bandera verde'] = 'Green flag'
EN['%.0f m antes de la meta'] = '%.0f m before the line'
EN['La verde sale un poco antes de la meta para que el auto ya esté libre al cruzarla. Adelantar, solo después de la meta.'] = 'The green comes out a little before the line so the car is already free when crossing it. Overtaking only after the line.'
EN['Sin salida corta, la primera vuelta es de formación y el juego la cuenta: conviene sumar una vuelta a la carrera.'] = 'Without the short start, the first lap is a formation lap and the game counts it: add one lap to the race.'
EN['Faltas en la largada'] = 'Start offences'
EN['Vigilar la salida en falso'] = 'Watch for jump starts'
EN['Moverse antes de la luz verde. Solo en salida parada.'] = 'Moving before the green light. Standing starts only.'
EN['Sanción según la velocidad'] = 'Penalty depends on speed'
EN['Como en Real Penalty. Pits: hasta 100 km/h, drive-through; hasta 200, stop and go de 10 s; más, descalificación. Salida en falso: hasta 50 km/h, drive-through; hasta 200, stop and go de 10 s; más, descalificación. Formación: pasar el límite, drive-through; pasarlo por más de un 25% o adelantar, stop and go de 30 s.'] = 'As in Real Penalty. Pits: up to 100 km/h, drive-through; up to 200, 10 s stop and go; above, disqualification. Jump start: up to 50 km/h, drive-through; up to 200, 10 s stop and go; above, disqualification. Formation: over the limit, drive-through; over it by more than 25% or overtaking, 30 s stop and go.'
EN['Sanción en la largada'] = 'Start penalty'
EN['Por salida en falso, o por correr o adelantar antes de la bandera verde. Se usa cuando la sanción no depende de la velocidad.'] = 'For a jump start, or for speeding or overtaking before the green flag. Used when the penalty does not depend on speed.'

-- ajustes: pista y pits
EN['Vigilar los límites de pista'] = 'Watch track limits'
EN['Avisos antes de sancionar'] = 'Warnings before a penalty'
EN['La que recibes al pasarte de avisos.'] = 'The one you get when you run out of warnings.'
EN['Qué salida cuenta'] = 'Which offs count'
EN['Toda salida'] = 'Every off'
EN['Solo el atajo con ventaja'] = 'Only cuts with an advantage'
EN['Con "solo el atajo con ventaja", salirse y perder tiempo no cuenta: cuenta cortar camino o volver sin soltar el acelerador.'] = 'With "only cuts with an advantage", going off and losing time does not count: cutting the track or rejoining without lifting does.'
EN['Después de la sanción, los avisos vuelven a cero'] = 'After the penalty, warnings go back to zero'
EN['Desde la segunda sanción de tiempo, el doble'] = 'From the second time penalty on, double'
EN['Ruedas fuera para contar'] = 'Wheels off to count'
EN['Tiempo fuera para contar'] = 'Time off to count'
EN['Velocidad mínima para contar'] = 'Minimum speed to count'
EN['Pausa entre dos salidas'] = 'Pause between two offs'
EN['Segundos de vuelta en la pista antes de que pueda contarse otra salida.'] = 'Seconds back on track before another off can be counted.'
EN['No cuenta si vuelves más lento que'] = 'Does not count if you rejoin below'
EN['%.0f %% de la velocidad'] = '%.0f %% of the speed'
EN['Si vuelves a la pista a menos de este porcentaje de la velocidad con que saliste, perdiste tiempo y no cuenta.'] = 'If you rejoin below this share of the speed you left with, you lost time and it does not count.'
EN['Tiempo para soltar el acelerador'] = 'Time to lift off'
EN['Después de volver a la pista todavía puedes soltar el acelerador para que no cuente.'] = 'After rejoining you can still lift off so that it does not count.'
EN['Una salida más larga es accidente'] = 'A longer off is an accident'
EN['Pits'] = 'Pits'
EN['Vigilar la velocidad en pits'] = 'Watch pit lane speed'
EN['Límite de velocidad'] = 'Speed limit'
EN['Margen'] = 'Tolerance'
EN['Cuánto puedes pasarte del límite sin sanción.'] = 'How far over the limit you can go without a penalty.'
EN['Sanción por exceso'] = 'Speeding penalty'
EN['Se usa cuando la sanción no depende de la velocidad (pestaña Largada).'] = 'Used when the penalty does not depend on speed (Start tab).'

-- ajustes: contactos
EN['Contactos entre autos'] = 'Car to car contact'
EN['Vigilar los contactos'] = 'Watch contacts'
EN['Sanción por contacto evitable'] = 'Avoidable contact penalty'
EN['Sanción por choque fuerte'] = 'Heavy crash penalty'
EN['Con sanción de tiempo, vale el doble.'] = 'With a time penalty, it counts double.'
EN['Devolver la posición'] = 'Giving the position back'
EN['Pedir que devuelvas el puesto antes de sancionar'] = 'Ask you to give the place back before penalising'
EN['Si ganas un puesto con un contacto o por fuera de la pista, primero se te pide dejar pasar al otro piloto.'] = 'If you gain a place through contact or off track, you are first asked to let the other driver through.'
EN['Plazo para devolverlo'] = 'Time to give it back'
EN['Sanción si no lo devuelves'] = 'Penalty if you do not'
EN['Vigilar adelantamientos por fuera de la pista'] = 'Watch overtakes off track'
EN['Cómo se mide un contacto'] = 'How contact is measured'
EN['Roce sin sanción hasta'] = 'Light touch, no penalty, up to'
EN['%.0f km/h de diferencia'] = '%.0f km/h difference'
EN['Choque fuerte desde'] = 'Heavy crash from'
EN['Golpe contra el muro desde'] = 'Wall hit from'
EN['%.0f km/h perdidos'] = '%.0f km/h lost'
EN['Quién responde'] = 'Who is at fault'
EN['El que alcanza por detrás'] = 'The car hitting from behind'
EN['Los dos'] = 'Both'
EN['"Los dos" es como iRacing: ambos pilotos suman puntos de incidente y no hay culpable.'] = '"Both" works like iRacing: both drivers get incident points and nobody is blamed.'
EN['Si el golpeado pierde el auto, cuenta como choque fuerte'] = 'If the car that was hit loses control, it counts as a heavy crash'

-- ajustes: incidentes
EN['Cada falta suma puntos (1x, 2x, 4x). Sirven para sancionar al piloto que acumula muchas faltas pequeñas.'] = 'Each offence adds points (1x, 2x, 4x). They are used to penalise a driver who piles up many small offences.'
EN['Puntos de incidente'] = 'Incident points'
EN['Contar puntos de incidente'] = 'Count incident points'
EN['Descalificación al pasar de'] = 'Disqualification above'
EN['%.0f puntos'] = '%.0f points'
EN['0 = nunca.'] = '0 = never.'
EN['Sanción cada'] = 'Penalty every'
EN['Sanción al llegar a ese número'] = 'Penalty when reaching that number'
EN['Cuánto suma cada falta'] = 'Points for each offence'
EN['Salida de pista'] = 'Off track'
EN['Pérdida de control'] = 'Loss of control'
EN['Golpe contra el muro'] = 'Wall hit'
EN['Contacto con otro auto'] = 'Contact with another car'
EN['Choque fuerte'] = 'Heavy crash'
EN['Sumar todos los incidentes'] = 'Add up every incident'
EN['Sin marcar, de varios incidentes seguidos solo cuenta el mayor, como en iRacing.'] = 'Unticked, out of several incidents in a row only the biggest counts, as in iRacing.'

-- ajustes: sanciones
EN['Cuánto dura cada sanción'] = 'How long each penalty lasts'
EN['Sanción de tiempo'] = 'Time penalty'
EN['Segundos que se suman a tu tiempo final.'] = 'Seconds added to your final time.'
EN['Drive-through: vueltas de plazo'] = 'Drive-through: laps to serve it'
EN['Vueltas que tienes para pasar por pits.'] = 'Laps you have to drive through the pits.'
EN['Stop and go: detenido'] = 'Stop and go: stopped for'
EN['No cumplir a tiempo es descalificación'] = 'Not serving in time means disqualification'
EN['Como en las carreras reales. Sin marcar, no cumplir un drive-through o un stop and go suma tiempo.'] = 'As in real racing. Unticked, not serving a drive-through or a stop and go adds time.'
EN['Si no cumples'] = 'If you do not serve it'
EN['Cambio por tiempo al final'] = 'Swap for time near the end'
EN['Una sanción recibida cuando ya no quedan vueltas para cumplirla se puede cambiar por tiempo. El número son las vueltas de margen sobre el plazo; 0 = no se cambia.'] = 'A penalty received when there are no laps left to serve it can be swapped for time. The number is the margin in laps over the deadline; 0 = never swapped.'
EN['Tiempo sin acelerar'] = 'Time off the throttle'
EN['Plazo para hacerlo'] = 'Time to do it'
EN['Si no lo haces'] = 'If you do not'
EN['Experimental: que el juego corte el acelerador'] = 'Experimental: let the game cut the throttle'

-- ajustes: banderas
EN['Mostrar banderas de pista'] = 'Show track flags'
EN['Verde: pista libre. Amarilla: auto detenido o sin control adelante. Azul: viene alguien que te saca una vuelta. Blanca: última vuelta. A cuadros: meta. Negra: descalificado.'] = 'Green: track clear. Yellow: a car stopped or out of control ahead. Blue: someone is about to lap you. White: last lap. Chequered: finish. Black: disqualified.'
EN['Bandera amarilla'] = 'Yellow flag'
EN['Prohibido adelantar con amarilla'] = 'No overtaking under yellow'
EN['Primero se pide devolver el puesto y, si no, viene la sanción.'] = 'First you are asked to give the place back; if you do not, the penalty follows.'
EN['Por adelantar o correr con amarilla, amarilla total o roja.'] = 'For overtaking or speeding under yellow, full course yellow or red.'
EN['Peligro hasta'] = 'Danger up to'
EN['%.0f m adelante'] = '%.0f m ahead'
EN['Bandera azul'] = 'Blue flag'
EN['Mostrar la bandera azul'] = 'Show the blue flag'
EN['Tiempo para ceder el paso'] = 'Time to let them through'
EN['Sanción por no ceder el paso'] = 'Penalty for not letting them through'
EN['"Ninguna" deja solo el aviso.'] = '"None" leaves only the warning.'
EN['Amarilla total y bandera roja'] = 'Full course yellow and red flag'
EN['Velocidad máxima'] = 'Top speed'
EN['Los botones Amarilla total, Roja y Verde están en la ventana Comisario. Offline los usas tú; online, solo el director de carrera.'] = 'The Full course yellow, Red and Green buttons are in the Comisario window. Offline you use them; online, only the race director.'

-- ajustes: pantalla
EN['Mostrar un ejemplo para acomodarla'] = 'Show a sample to position it'
EN['Deja a la vista todos los indicadores mientras eliges el lugar y el tamaño.'] = 'Keeps every indicator visible while you choose the place and size.'
EN['Tamaño'] = 'Size'
EN['Altura'] = 'Height'
EN['0 = arriba de la pantalla.'] = '0 = top of the screen.'
EN['Posición horizontal'] = 'Horizontal position'
EN['50 = al centro.'] = '50 = centre.'
EN['Fondo oscuro detrás del texto'] = 'Dark background behind the text'
EN['Íconos de banderas y sanciones'] = 'Flag and penalty icons'
EN['Mostrar también el mensaje grande del juego'] = "Also show the game's big message"
EN['Ventanas sueltas'] = 'Loose windows'
EN['Interfaz fija'] = 'Fixed interface'
EN['Marcado: los indicadores van en un lugar fijo y no se mueven. Sin marcar: cada uno es una ventana que arrastras con el mouse.'] = 'Ticked: the indicators sit in a fixed place and do not move. Unticked: each one is a window you drag with the mouse.'
EN['Abrir todos los indicadores'] = 'Open every indicator'
EN['Cerrar todos'] = 'Close all'

-- ajustes: mas
EN['Inteligencia artificial (offline)'] = 'AI drivers (offline)'
EN['Sanciones a la IA'] = 'AI penalties'
EN['No vigilarla'] = 'Do not watch'
EN['Solo tiempo'] = 'Time only'
EN['Que cumpla en pista'] = 'Serve on track'
EN['"Solo tiempo" suma la sanción en la clasificación. "Que cumpla en pista": la IA suelta el acelerador o entra a pits.'] = '"Time only" adds the penalty to the results. "Serve on track": the AI lifts off or pits.'
EN['Drive-through de la IA: mandarla a pits de verdad'] = 'AI drive-through: really send it to the pits'
EN['Si la IA no puede cumplirlo'] = 'If the AI cannot serve it'
EN['Mostrar los incidentes de los demás en el panel'] = "Show other drivers' incidents in the panel"
EN['Registro'] = 'Log'
EN['Guardar registro en archivo'] = 'Save the log to a file'
EN['Sirve para revisar qué pasó en una carrera o para reportar un error.'] = 'Useful to review what happened in a race or to report a bug.'
EN['Pruebas'] = 'Tests'
EN['Botones para ver cada sanción sin cometer la falta:'] = 'Buttons to see each penalty without committing the offence:'
EN['Aviso'] = 'Warning'
EN['Así se ve un aviso'] = 'This is what a notice looks like'
EN['Levantar'] = 'Lift off'
EN['Rival 1: levantar'] = 'Rival 1: lift off'
EN['Rival 1: drive-through'] = 'Rival 1: drive-through'
EN['Borrar sanciones y contadores'] = 'Clear penalties and counters'
