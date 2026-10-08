"""Pruebas online: dos jugadores (Matias y Benja), cada uno con su propia app, mas un tercero sin app."""
import sys
from lupa import luajit21 as lj

APP = sys.argv[1]
results = []


class Player:
    def __init__(self, me, other_name):
        self.lua = lj.LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute("local f = assert(loadfile('test/harness.lua')); f('%s')" % APP)
        self.lua.execute('''
          T.sim.isOnlineRace = true
          T.cars[0].sessionID = %d; T.cars[1].sessionID = %d; T.cars[2].sessionID = 2
          T.names = { [1] = '%s', [2] = 'Invitado' }
          place(0, 0, 150); place(1, 300, 150); place(2, 600, 150)
        ''' % (me, 1 - me, other_name))
        self.gone = False

    def do(self, code):
        return self.lua.execute(code)

    def take(self):
        out = []
        sent = self.lua.eval('T.sent')
        for i in range(1, len(sent) + 1):
            out.append((sent[i]['key'], dict(sent[i]['data'])))
        self.lua.execute('T.sent = {}')
        return out

    def give(self, key, data, sender_index):
        g = self.lua.globals()
        cb = g.T.events[key]
        cb(g.T.cars[sender_index], self.lua.table_from(data))


def both(a, b, seconds, log=None):
    for _ in range(int(round(seconds / 0.1))):
        for src, dst in ((a, b), (b, a)):
            if src.gone:
                continue
            src.do('run(0.1)')
            for key, data in src.take():
                if log is not None:
                    log.append((src, key, data))
                src.give(key, data, 0)          # el propio mensaje vuelve al que lo envio
                if not dst.gone:
                    dst.give(key, data, 1)


def scenario(name, fn):
    a, b = Player(0, 'Benja'), Player(1, 'Matias')
    try:
        ok = fn(a, b)
        err = ''
        for who, p in (('Matias', a), ('Benja', b)):
            v = p.lua.eval('T.netViolation')
            if v:
                ok, err = False, err + ' [red %s: %s]' % (who, v)
            log = p.lua.eval('logText()')
            if 'ERROR' in log:
                ok, err = False, err + ' [%s: %s]' % (who, log[log.find('ERROR'):][:200])
        if not ok and not err:
            err = 'Matias ve: ' + a.do('return screen()')[:400] + ' ### Benja ve: ' + b.do('return screen()')[:400]
        results.append((name, bool(ok), err))
    except Exception as e:  # noqa
        results.append((name, False, str(e)[:300]))


def s1(a, b):
    both(a, b, 8)
    a.do('local c = T.cars[0]; c.wheelsOutside = 4; run(1); c.wheelsOutside = 0')
    both(a, b, 4)
    sb, sa = b.do('return screen()'), a.do('return screen()')
    return ('Matias: aviso 1/3 por limites de pista' in sb and 'Matias | 1x' in sb and 'Invitado | sin app' in sb
            and 'Benja | 0x' in sa and 'Online: 1 pilotos mas con Comisario, reglas: las tuyas' in sa
            and b.do('return #T.messages') == 0)
scenario('lo que le pasa a un piloto aparece en el panel y la clasificacion del otro; el que no tiene app sale "sin app"', s1)


def s2(a, b):
    both(a, b, 2)
    # Matias alcanza fuerte a Benja. Cada juego ve el golpe desde su propio auto.
    a.do('place(0, 0, 200); place(1, 4.5, 150); run(0.5); hit(0)')
    b.do('place(0, 4.5, 150); place(1, 0, 200); run(0.5); hit(0)')
    both(a, b, 4)
    ma = a.do('return table.concat(T.messages, " // ")')
    mb = b.do('return table.concat(T.messages, " // ")')
    sb = b.do('return screen()')
    return ('DRIVE-THROUGH | Causar un choque con Benja' in ma and 'DRIVE' not in mb.replace('MATIAS | drive-through', '')
            and 'MATIAS | drive-through: Causar un choque con Benja' in mb
            and 'Incidentes: | 0x' in sb and 'debe pits' in sb and 'la sancion la decide su Comisario' in sb)
scenario('choque por alcance online: se sanciona el culpable en su app y el golpeado recibe el aviso', s2)


def s3(a, b):
    a.do("preset('iRacing'); T.cfg.director = true")
    both(a, b, 16)
    adopted = 'reglas: las de Matias' in b.do('return screen()') and 'eres el director de carrera' in a.do('return screen()')
    b.do('local c = T.cars[0]; c.gas = 1; for n = 1, 4 do c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(3.5) end')
    mb = b.do('return table.concat(T.messages, " // ")')
    own_kept = b.do('return T.cfg.tlPenalty') == 2 and b.do('return T.cfg.incStep') == 12
    b.do("T.texts = {}; script.windowSettings(0.016)")
    warned = 'mandan las reglas de Matias' in b.do("return table.concat(T.texts, ' ')")
    return adopted and 'LEVANTA' not in mb and mb.count('SALIDA DE PISTA') == 4 and own_kept and warned
scenario('director de carrera: su reglamento se aplica al otro piloto sin borrarle sus ajustes', s3)


def s4(a, b):
    a.do("preset('iRacing'); T.cfg.director = true")
    both(a, b, 16)
    a.gone = True                                   # el director se desconecta
    both(a, b, 45)
    back = 'reglas: las tuyas' in b.do('return screen()')
    b.do('local c = T.cars[0]; c.gas = 1; for n = 1, 4 do c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(3.5) end')
    return back and 'LEVANTA EL PIE' in b.do('return table.concat(T.messages, " // ")')
scenario('si el director se va, cada uno vuelve a sus reglas', s4)


def s5(a, b):
    a.do("preset('iRacing'); T.cfg.director = true")
    b.do("press('Comisarios (F1)'); T.cfg.director = true")
    both(a, b, 30)
    return ('eres el director de carrera' in a.do('return screen()') and 'reglas: las de Matias' in b.do('return screen()'))
scenario('dos directores: mandan las reglas del puesto mas bajo del servidor', s5)


def s6(a, b):
    both(a, b, 2)
    # en el juego de Matias, el auto de Benja se sale de pista y se trompea: no es asunto de la app de Matias
    a.do('local o = T.cars[1]; o.wheelsOutside = 4; o.look = vec3(1, 0, 0); run(3)')
    both(a, b, 3)
    sa = a.do('return screen()')
    return 'Benja | 0x' in sa and a.do('return #T.messages') == 0
scenario('online, la app no juzga las salidas ni los trompos de los otros autos', s6)


def s7(a, b):
    log = []
    both(a, b, 1)
    a.do("press('Drive-through'); press('Levantar'); press('Tiempo'); press('Tiempo')")
    a.do('local c = T.cars[0]; c.gas = 1; for n = 1, 3 do c.wheelsOutside = 4; run(1); c.wheelsOutside = 0; run(3.5) end')
    both(a, b, 20, log)
    notes = [d['comText'] for (src, key, d) in log if key == 'comisario:nota:1' and src is a]
    sb = b.do('return screen()')
    # 7 avisos mas el de la sancion por no levantar el pie a tiempo
    return (len(notes) == 8 and notes[0].startswith('drive-through') and notes[6].startswith('aviso 3/3')
            and notes[7].startswith('+10 s: No levantaste') and 'Matias | 3x' in sb and '+20 s' in sb)
scenario('muchos avisos seguidos salen de a uno, en orden y sin romper los limites del chat del servidor', s7)


def s8(a, b):
    a.do('T.sim.raceSessionType = 2'); b.do('T.sim.raceSessionType = 2')
    both(a, b, 2)
    a.do('local c = T.cars[0]; c.wheelsOutside = 4; run(1); c.wheelsOutside = 0')
    both(a, b, 3)
    return 'Matias: vuelta invalidada: Limites de pista' in b.do('return screen()')
scenario('clasificacion online: la vuelta invalidada de un piloto se le avisa al resto', s8)


def s9(a, b):
    both(a, b, 2)
    # Matias toca a Benja por detras y queda delante de el
    a.do('place(0, 0, 170); place(1, 4.5, 150); run(0.5); hit(0); run(0.3); place(0, 20, 170)')
    b.do('place(0, 4.5, 150); place(1, 0, 170); run(0.5); hit(0); run(0.3); place(1, 20, 170)')
    both(a, b, 5)
    asked = 'DEVUELVE LA POSICION | Deja pasar a Benja' in a.do('return lastMsg()')
    told = 'MATIAS | debe devolver la posicion a Benja' in b.do('return table.concat(T.messages, " // ")')
    a.do('place(0, 0, 120); place(1, 30, 150)')
    b.do('place(0, 30, 150); place(1, 0, 120)')
    both(a, b, 3)
    return (asked and told and 'POSICION DEVUELTA' in a.do('return lastMsg()')
            and 'Matias: devolvio la posicion a Benja' in b.do('return screen()')
            and 'DRIVE' not in a.do('return table.concat(T.messages, " // ")'))
scenario('online: tras un contacto se pide devolver el puesto y el golpeado se entera de todo', s9)


def s10(a, b):
    a.do("T.cfg.startMode = 2; T.cfg.formSpeed = 80; T.cfg.director = true")
    both(a, b, 16)
    for p_ in (a, b):
        p_.do('newSession(); T.sim.isOnlineRace = true; T.sim.timeToSessionStart = -100; place(0, 0, 60); place(1, 300, 60)')
    both(a, b, 2)
    mb = b.do('return table.concat(T.messages, " // ")')
    return ('VUELTA DE FORMACION | Manten tu puesto y no pases de 80 km/h' in mb and b.do('return T.cfg.startMode') == 1
            and 'VUELTA DE FORMACION' in a.do('return table.concat(T.messages, " // ")'))
scenario('online: el director elige salida lanzada y a todos les aparece la vuelta de formacion', s10)


def s11(a, b):
    # el script del servidor corre en el juego de cada piloto y deja escrito lo que impone.
    # Solo uno de los tres "espacios" de memoria compartida esta conectado de verdad.
    for space in ('def', 'server_script', 'shared'):
        x, y = Player(0, 'Benja'), Player(1, 'Matias')
        for p_ in (x, y):
            p_.do("T.cfg.formSpeed = 70; SRV = T.shared['comisario:enlace:7|%s']; SRV.srvMode = 2; SRV.srvSpeed = 100" % space)
            p_.do('newSession(); T.sim.isOnlineRace = true; T.sim.timeToSessionStart = -100; place(0, 0, 60); place(1, 300, 60)')
        for _ in range(20):
            for p_ in (x, y):
                p_.do('SRV.srvTick = SRV.srvTick + 1')
            both(x, y, 0.1)
        mx = x.do('return table.concat(T.messages, " // ")')
        imposed = ('VUELTA DE FORMACION | Manten tu puesto y no pases de 70 km/h' in mx and x.do('return T.cfg.startMode') == 1
                   and 'salida impuesta por el servidor' in x.do('return screen()'))
        asked = x.do('return SRV.appSpeed') == 70 and x.do('return SRV.appTick') > 100 and x.do('return SRV.appGreen') == 100
        both(x, y, 4)                               # el script deja de responder: se vuelve a lo propio
        if not (imposed and asked and 'salida impuesta por el servidor' not in x.do('return screen()')):
            return False
    return True
scenario('script del servidor: impone la salida lanzada y recibe de la app la velocidad de formacion (por cualquiera de los 3 enlaces)', s11)


def s12(a, b):
    a.do("T.cfg.formSpeed = 70; T.cfg.director = true")
    b.do("SRV = T.shared['comisario:enlace:7|shared']")
    b.do('run(0.2)')                                # antes de recibir nada, vale la propia
    own = b.do('return SRV.appSpeed')
    both(a, b, 15)
    return own == 100 and b.do('return SRV.appSpeed') == 70 and b.do('return T.cfg.formSpeed') == 100
scenario('el limite de formacion que pone el director llega al limitador del servidor de los demas pilotos', s12)


def s13(a, b):
    a.do("preset('Real Penalty'); T.cfg.director = true")
    both(a, b, 16)
    b.do('place(0, 0, 150)')
    for _ in range(4):
        b.do('T.cars[0].wheelsOutside = 4'); both(a, b, 1)
        b.do('T.cars[0].wheelsOutside = 0'); both(a, b, 5)
    mb = b.do('return table.concat(T.messages, " // ")')
    return ('Atajo con ventaja' in mb and 'DRIVE-THROUGH | Limites de pista. Pasa por pits sin detenerte, tienes 2 vueltas' in mb
            and b.do('return T.cfg.tlMode') == 1)
scenario('online: el reglamento Real Penalty del director se aplica completo a los demas', s13)

def s14(a, b):
    for p_ in (a, b):
        p_.do("T.cfg.flEnabled = true; T.sim.timeToSessionStart = -20000; SRV = T.shared['comisario:enlace:7|shared']")
    a.do("T.cfg.director = true; T.cfg.fcySpeed = 70")
    both(a, b, 8)
    b.do("T.clickButton = 'Roja'; script.windowMain(0.016); T.clickButton = nil")       # no es director: no hay boton
    both(a, b, 2)
    ignored = b.do('return #T.messages') == 0 and a.do('return #T.messages') == 0
    a.do("T.clickButton = 'Roja'; script.windowMain(0.016); T.clickButton = nil")
    both(a, b, 2)
    red = ('BANDERA ROJA | Sesion detenida: maximo 70 km/h, sin adelantar, vuelve a pits. Orden de Matias' in b.do('return lastMsg()')
           and 'ROJA' in b.do('return hudScreen()') and b.do('return SRV.appLimit') == 70 and a.do('return SRV.appLimit') == 70)
    a.do("T.clickButton = 'Verde'; script.windowMain(0.016); T.clickButton = nil")
    both(a, b, 2)
    green = 'BANDERA VERDE | Pista libre. Orden de Matias' in b.do('return lastMsg()') and b.do('return SRV.appLimit') == 0
    a.do("T.clickButton = 'Amarilla total'; script.windowMain(0.016); T.clickButton = nil")
    both(a, b, 2)
    fcy = 'AMARILLA TOTAL' in b.do('return lastMsg()')
    a.gone = True                                   # el director se desconecta con la amarilla puesta
    both(a, b, 25)
    return ignored and red and green and fcy and 'BANDERA VERDE' in b.do('return lastMsg()') and b.do('return SRV.appLimit') == 0
scenario('direccion de carrera online: roja, verde y amarilla total del director llegan a todos y al limitador', s14)


def s15(a, b):
    for p_ in (a, b):
        p_.do("T.cfg.flEnabled = true; T.sim.timeToSessionStart = -20000")
    both(a, b, 8)
    # Benja queda detenido 200 m delante de Matias: Matias ve amarilla; Benja no ve nada raro
    a.do('place(0, 0, 150); place(1, 200, 0)')
    b.do('place(0, 200, 0); place(1, 0, 150)')
    both(a, b, 1)
    return ('BANDERA AMARILLA | Benja detenido o sin control a 200 m' in a.do('return lastMsg()')
            and b.do('return msgCount("BANDERA")') == 0)
scenario('online: amarilla local por un rival detenido adelante', s15)

def s16(a, b):
    # servidor sin bloqueo (srvMode = 0): la app elige y se lo dice al script; el director decide por todos
    for p_ in (a, b):
        p_.do("SRV = T.shared['comisario:enlace:7|shared']; SRV.srvMode = 0")
    a.do("T.cfg.startMode = 1; T.cfg.director = true")
    b.do("T.cfg.startMode = 2")
    for _ in range(160):
        for p_ in (a, b):
            p_.do('SRV.srvTick = SRV.srvTick + 1')
        both(a, b, 0.1)
    free = (a.do('return SRV.appMode') == 1 and b.do('return SRV.appMode') == 1 and b.do('return T.cfg.startMode') == 2
            and 'enlazado con el script del servidor' in a.do('return screen()')
            and 'salida impuesta' not in a.do('return screen()'))
    a.do("T.clickRadio = 'Lanzada'; script.windowSettings(0.016); T.clickRadio = nil")
    for _ in range(160):
        for p_ in (a, b):
            p_.do('SRV.srvTick = SRV.srvTick + 1')
        both(a, b, 0.1)
    return free and a.do('return T.cfg.startMode') == 2 and a.do('return SRV.appMode') == 2 and b.do('return SRV.appMode') == 2
scenario('servidor sin bloqueo: el tipo de salida se elige en la app y el del director vale para todos', s16)

def hash_key(text):
    h = 5381
    for ch in text.encode():
        h = (h * 33 + ch) % 4294967296
    return h or 1


def tick_both(a, b, seconds):
    for _ in range(int(round(seconds / 0.1))):
        for p_ in (a, b):
            if not p_.gone:
                p_.do('SRV.srvTick = (SRV.srvTick + 1) % 60000')
        both(a, b, 0.1)


def s17(a, b):
    # servidor con clave de administrador. Matias (a) la conoce; Benja (b) no.
    for p_ in (a, b):
        p_.do("SRV = T.shared['comisario:enlace:7|shared']; SRV.srvAuth = %d" % hash_key('secreto'))
    a.do("T.cfg.adminKey = 'secreto'; T.cfg.tlWarnings = 1; T.cfg.tlPenalty = 1; T.cfg.tlMode = 1; T.cfg.flEnabled = true")
    b.do("T.cfg.director = true; T.cfg.tlPenalty = 0; T.cfg.tlWarnings = 9; T.cfg.enabled = false; T.cfg.adminKey = 'adivino'")
    tick_both(a, b, 16)
    sa, sb = a.do('return screen()'), b.do('return screen()')
    roles = ('eres el administrador' in sa and 'reglas: las de Matias' in sb and 'reglas: las de Benja' not in sa
             and a.do('return SRV.appOn') == 1 and b.do('return SRV.appOn') == 1)
    # Benja se sale dos veces: vale el reglamento de Matias (1 aviso y +5 s), no el suyo (sin sancion) ni apagar el comisario
    b.do('place(0, 0, 150)')
    for _ in range(2):
        b.do('T.cars[0].wheelsOutside = 4'); tick_both(a, b, 1)
        b.do('T.cars[0].wheelsOutside = 0'); tick_both(a, b, 5)
    mb = b.do('return table.concat(T.messages, " // ")')
    obeys = 'AVISO 1/1 LIMITES DE PISTA' in mb and 'SANCION +5 s | Limites de pista' in mb
    # Benja intenta decretar bandera roja: no tiene boton, y un mensaje sin la huella correcta se descarta
    b.do("T.clickButton = 'Roja'; script.windowMain(0.016); T.clickButton = nil")
    tick_both(a, b, 2)
    # un tercero (sin clave) manda una bandera roja y un reglamento blando: Benja los descarta
    b.give('comisario:control:2', {'ctlState': 2, 'ctlSpeed': 80, 'ctlAuth': 12345}, 2)
    log = []
    for _ in range(140):
        for p_ in (a, b):
            p_.do('SRV.srvTick = (SRV.srvTick + 1) % 60000')
        both(a, b, 0.1, log)
    rules = [d for (src, key, d) in log if key.startswith('comisario:reglas') and src is a]
    forged = dict(rules[-1]); forged['comAuth'] = 999; forged['tlWarnings'] = 7
    b.give('comisario:reglas:8', forged, 2)
    tick_both(a, b, 1)
    no_red = ('BANDERA ROJA' not in b.do('return table.concat(T.messages, " // ")') and len(rules) > 0
              and b.do('return hudScreen()').count('LIMITES 1/7') == 0 and 'reglas: las de Matias' in b.do('return screen()'))
    # el administrador se desconecta: Benja sigue con su reglamento, no vuelve al propio
    a.gone = True
    tick_both(a, b, 60)
    return roles and obeys and no_red and 'reglas: las de Matias' in b.do('return screen()') and b.do('return T.cfg.tlPenalty') == 0
scenario('servidor con clave: solo el administrador fija reglas y banderas; el otro piloto no puede cambiarlas ni apagar la app', s17)


def s18(a, b):
    # servidor con clave y el administrador todavia no entra: Benja corre con el reglamento por defecto
    b.do("SRV = T.shared['comisario:enlace:7|shared']; SRV.srvAuth = %d" % hash_key('secreto'))
    a.do("SRV = T.shared['comisario:enlace:7|shared']")
    b.do("T.cfg.tlPenalty = 0; T.cfg.tlMode = 1; T.cfg.startMode = 2")
    a.gone = True
    tick_both(a, b, 4)
    b.do('place(0, 0, 150)')
    for _ in range(4):
        b.do('T.cars[0].wheelsOutside = 4'); tick_both(a, b, 1)
        b.do('T.cars[0].wheelsOutside = 0'); tick_both(a, b, 5)
    mb = b.do('return table.concat(T.messages, " // ")')
    return ('Atajo con ventaja' in mb and 'SANCION +5 s | Limites de pista' in mb and b.do('return SRV.appMode') == 0
            and 'a la espera del administrador' in b.do('return screen()'))
scenario('servidor con clave sin el administrador conectado: vale el reglamento por defecto, no el del piloto', s18)


def s19(a, b):
    # descalificado online: la app le pide al limitador del servidor 50 km/h, y el otro piloto ve quien gano
    for p_ in (a, b):
        p_.do("SRV = T.shared['comisario:enlace:7|shared']; T.sessionLaps = 5; T.sim.carsCount = 2")
    a.do("T.cfg.incDQ = 1; T.cfg.tlMode = 1")
    tick_both(a, b, 8)
    a.do('place(0, 0, 150); T.cars[0].lapCount = 2')
    for wait in (5, 2):
        a.do('T.cars[0].wheelsOutside = 4'); tick_both(a, b, 1)
        a.do('T.cars[0].wheelsOutside = 0'); tick_both(a, b, wait)
    dq = 'DESCALIFICADO' in a.do('return table.concat(T.messages, " // ")') and a.do('return SRV.appLimit') == 50
    a.do('T.cars[0].lapCount = 5; T.cars[0].isRaceFinished = true')
    b.do('T.cars[1].lapCount = 5; T.cars[1].isRaceFinished = true')
    tick_both(a, b, 3)
    a.do('T.cars[1].lapCount = 5; T.cars[1].isRaceFinished = true')
    b.do('T.cars[0].lapCount = 5; T.cars[0].isRaceFinished = true')
    tick_both(a, b, 8)
    return (dq and 'GANADOR: Benja | Cruzaste primero la meta, pero estas descalificado' in a.do('return lastMsg()')
            and 'GANASTE LA CARRERA | Matias cruzo primero la meta, pero esta descalificado' in b.do('return lastMsg()'))
scenario('descalificado online: queda limitado a 50 km/h y los dos ven al mismo ganador', s19)

def s20(a, b):
    # salida corta online: el director la elige, cada app le pasa los metros al script y, cuando el script mueve
    # los autos a la fila, la verde sale sin dar la vuelta
    for p_ in (a, b):
        p_.do("SRV = T.shared['comisario:enlace:7|shared']")
    a.do("T.cfg.director = true; T.cfg.startMode = 2; T.cfg.formShort = true; T.cfg.formStartM = 600")
    tick_both(a, b, 16)
    asked = a.do('return SRV.appStart') == 600 and b.do('return SRV.appStart') == 600 and b.do('return SRV.appMode') == 2
    for p_ in (a, b):
        p_.do('newSession(); T.sim.isOnlineRace = true; T.sim.carsCount = 2; T.sim.timeToSessionStart = -100')
    a.do('T.cars[0].racePosition = 1; T.cars[1].racePosition = 2; T.cars[0].splinePosition = 0.99; T.cars[1].splinePosition = 0.985')
    b.do('T.cars[0].racePosition = 2; T.cars[1].racePosition = 1; T.cars[0].splinePosition = 0.985; T.cars[1].splinePosition = 0.99')
    tick_both(a, b, 0.5)
    # el script del servidor (aqui, la prueba) deja a cada uno en la fila: Matias primero a 600 m, Benja 10 m atras
    a.do('place(0, 2900, 0); place(1, 2890, 0)')
    b.do('place(0, 2890, 0); place(1, 2900, 0)')
    tick_both(a, b, 4)
    forming = ('Salida corta no disponible' not in a.do('return screen()') and 'BANDERA VERDE' not in a.do('return table.concat(T.messages, " // ")')
               and 'SALIDA LANZADA | Manten tu puesto' in b.do('return table.concat(T.messages, " // ")'))
    a.do('place(0, 3420, 95); place(1, 3410, 95)')
    b.do('place(0, 3410, 95); place(1, 3420, 95)')
    tick_both(a, b, 0.3)
    return asked and forming and 'BANDERA VERDE' in a.do('return lastMsg()') and 'BANDERA VERDE' in b.do('return lastMsg()')
scenario('salida corta online: el director la elige, el script recibe los metros y la verde sale sin dar la vuelta', s20)


def s21(a, b):
    for p_ in (a, b):
        p_.do("SRV = T.shared['comisario:enlace:7|shared']")
    a.do("T.cfg.incDQ = 1; T.cfg.tlMode = 1")
    tick_both(a, b, 8)
    clean = a.do('return SRV.appDq') == 0
    a.do('place(0, 0, 150)')
    for wait in (5, 2):
        a.do('T.cars[0].wheelsOutside = 4'); tick_both(a, b, 1)
        a.do('T.cars[0].wheelsOutside = 0'); tick_both(a, b, wait)
    return clean and a.do('return SRV.appDq') == 1 and a.do('return SRV.appLimit') == 50 and b.do('return SRV.appDq') == 0
scenario('descalificado online: la app le avisa al script para que lo mande a pits', s21)

fails = 0
for name, ok, err in results:
    print(('OK    ' if ok else 'FALLA ') + name + (('\n        -> ' + err) if err else ''))
    fails += 0 if ok else 1
print('\n%d de %d pruebas online correctas' % (len(results) - fails, len(results)))
sys.exit(1 if fails else 0)
