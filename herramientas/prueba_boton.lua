-- Prueba fuera del juego de cuando se ve el boton: carga el addon con una API de WoW
-- simulada y repite /reload conservando DisenchantForeverDB, con y sin Encantamiento,
-- en combate y fuera. Como el juego, bloquea en combate lo que no se puede hacer con
-- un boton seguro (mostrar, ocultar, mover, cambiar atributos).
-- Uso: lua5.1 herramientas/prueba_boton.lua [carpeta del addon]

local here = arg[0]:match("^(.*)/") or "."
local dir = arg[1] or (here .. "/../DisenchantForever")

local GREEN = "|cff1eff00|Hitem:2042::::::::22:::::::|h[Staff]|h|r"
local SECRET = {}

local state, frames, timers, printed, blocked
local bagScans = 0

-- ------------------------------------------------------------------ marcos

local Frame = {}
Frame.__index = function(_, key)
    local method = rawget(Frame, key)
    if method then return method end
    -- metodos que no importan aqui: no hacen nada. Los campos (en minuscula)
    -- quedan en nil, como en el juego.
    if type(key) == "string" and key:match("^%u") then return function() end end
end

local function NewFrame(name, template)
    local f = setmetatable({ shown = true, scripts = {}, attrs = {}, points = {}, strings = {}, lines = {},
        protected = template ~= nil and template:find("Secure") ~= nil }, Frame)
    if name then _G[name] = f end
    return f
end

local function Blocked(f, what)
    if f.protected and state.combat then
        blocked[#blocked + 1] = what
        return true
    end
end

function Frame:Show() if not Blocked(self, "Show") then self.shown = true end end
function Frame:Hide() if not Blocked(self, "Hide") then self.shown = false end end
function Frame:SetShown(v) if v then self:Show() else self:Hide() end end
function Frame:IsShown() return self.shown end
function Frame:SetScript(event, fn) self.scripts[event] = fn end
function Frame:HookScript(event, fn)
    local old = self.scripts[event]
    self.scripts[event] = old and function(...) old(...); fn(...) end or fn
end
function Frame:GetScript(event) return self.scripts[event] end
function Frame:SetAttribute(k, v) if not Blocked(self, "SetAttribute") then self.attrs[k] = v end end
function Frame:GetAttribute(k) return self.attrs[k] end
function Frame:ClearAllPoints() if not Blocked(self, "ClearAllPoints") then self.points = {} end end
function Frame:SetPoint(...) if not Blocked(self, "SetPoint") then self.points[#self.points + 1] = { ... } end end
function Frame:GetPoint() local p = self.points[1]; if p then return unpack(p) end end
function Frame:StartMoving() if not Blocked(self, "StartMoving") then self.dragging = true end end
function Frame:StopMovingOrSizing() if not Blocked(self, "StopMovingOrSizing") then self.dragging = nil end end
function Frame:GetFrameLevel() return 1 end
function Frame:GetFrameStrata() return "MEDIUM" end
function Frame:GetWidth() return 100 end
function Frame:GetHeight() return 20 end
function Frame:GetStringWidth() return 50 end
function Frame:IsEnabled() return true end
function Frame:CreateTexture() return NewFrame() end
function Frame:CreateFontString()
    local fs = NewFrame()
    self.strings[#self.strings + 1] = fs
    return fs
end
function Frame:SetText(text) self.text = text end
function Frame:GetText() return self.text end
function Frame:SetOwner(owner) self.owner = owner; self.lines = {} end
function Frame:IsOwned(owner) return self.owner == owner end
function Frame:AddLine(text) self.lines[#self.lines + 1] = text end
function Frame:AddDoubleLine(text) self.lines[#self.lines + 1] = text end

-- ------------------------------------------------------------- API del juego

local function Setup(opts)
    state = { combat = false, knows = opts.knows ~= false }
    frames, timers, printed, blocked = {}, {}, {}, {}
    DisenchantForeverBoton, DisenchantForeverOpciones = nil, nil

    GetLocale = function() return opts.locale or "enUS" end
    DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) printed[#printed + 1] = m end }
    UIParent = NewFrame()
    GameTooltip, ItemRefTooltip = NewFrame(), NewFrame()
    GameTooltip.shown = false
    CreateFrame = function(_, name, _, template)
        local f = NewFrame(name, template)
        frames[#frames + 1] = f
        return f
    end
    CreateColor = function() return {} end
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
    C_Spell = { GetSpellInfo = function() return { name = "Disenchant" } end }
    C_Container = {
        GetContainerNumSlots = function(bag)
            bagScans = bagScans + 1
            return bag == 0 and 1 or 0
        end,
        GetContainerItemInfo = function(bag, slot)
            if bag == 0 and slot == 1 then return { hyperlink = opts.item or GREEN, quality = 2, iconFileID = 123 } end
        end,
    }
    C_Item = {
        -- la efigie de cera y el lino son materiales (7); el resto, armadura (4)
        GetItemInfoInstant = function(link)
            local itemID = tonumber(tostring(link):match("item:(%d+)"))
            return itemID, nil, nil, nil, nil, (itemID == 247883 or itemID == 2589) and 7 or 4
        end,
        RequestLoadItemDataByID = function() end,
    }
    InCombatLockdown = function() return state.combat end
    C_SpellBook, IsSpellKnown = nil, nil
    issecretvalue = function(v) return v == SECRET end

    if opts.noApi then
        IsPlayerSpell, GetProfessions, GetProfessionInfo = nil, nil, nil
    else
        IsPlayerSpell = function(id)
            if opts.secret then return SECRET end
            return id == 13262 and state.knows
        end
        -- sin profesiones, GetProfessions no devuelve nada
        GetProfessions = function() return opts.profIndex end
        GetProfessionInfo = function() return "Profesion", 1, 1, 300, 0, 0, opts.profSkill end
        if opts.noProfessions then GetProfessions, GetProfessionInfo = nil, nil end
    end

    SlashCmdList = {}
    strlower = string.lower
    strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
end

-- los archivos en el orden del .toc
local FILES = {}
for line in io.lines(dir .. "/DisenchantForever.toc") do
    local file = line:match("^([%w_]+%.lua)%s*$")
    if file then FILES[#FILES + 1] = file end
end

local function Login(saved, opts)
    opts = opts or {}
    Setup(opts)
    DisenchantForeverDB = saved
    local ns = {}
    for _, file in ipairs(FILES) do
        assert(loadfile(dir .. "/" .. file))("DisenchantForever", ns)
    end
    local loader = frames[#frames]
    local function Fire(event, ...) loader.scripts.OnEvent(loader, event, ...) end
    Fire("ADDON_LOADED", "DisenchantForever")
    Fire("SPELLS_CHANGED")      -- antes de PLAYER_LOGIN: el boton aun no existe
    Fire("PLAYER_LOGIN")
    Fire("SPELLS_CHANGED")
    for _, fn in ipairs(timers) do fn() end
    timers = {}
    return {
        ns = ns,
        button = DisenchantForeverBoton,
        options = DisenchantForeverOpciones,
        Fire = Fire,
        Slash = function(msg) SlashCmdList.DISENCHANTFOREVER(msg) end,
    }
end

-- lo que el juego guarda al salir y vuelve a leer al entrar
local function Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = Copy(v) end
    return out
end
local function Saved() return Copy(DisenchantForeverDB) end

-- ------------------------------------------------------------ comprobaciones

local failures = 0
local function expect(what, got, want)
    if got ~= want then
        failures = failures + 1
        print(("FALLO %s: se esperaba [%s] y salio [%s]"):format(what, tostring(want), tostring(got)))
    else
        print("ok  " .. what .. " -> " .. tostring(got))
    end
end

local function Count(text)
    local n = 0
    for _, m in ipairs(printed) do
        if m:find(text, 1, true) then n = n + 1 end
    end
    return n
end
local function Said(text) return Count(text) > 0 end

local function ShowCheck(ui) return ui.options.checks[1] end
local function Mark(ui) return ShowCheck(ui).strings[1].text end
local function Click(ui) local check = ShowCheck(ui); check.scripts.OnClick(check) end
local function Ticked(ui) return Mark(ui) == ui.ns.style.TICK end

local MACRO = "/cast Disenchant\n/use 0 1"

print("-- encantador sin eleccion guardada")
local ui = Login(nil, { knows = true })
expect("se ve", ui.button:IsShown(), true)
expect("sin eleccion guardada", DisenchantForeverDB.hidden, nil)
expect("apunta al objeto", ui.button:GetAttribute("macrotext"), MACRO)
expect("sin aviso", Said("does not know"), false)

print("-- el fallo del comentario: ocultar, /reload y sigue oculto")
ui.Slash("")
expect("/dis lo oculta", ui.button:IsShown(), false)
expect("se guarda", DisenchantForeverDB.hidden, true)
expect("mensaje", Said("button hidden"), true)
ui = Login(Saved(), { knows = true })
expect("oculto tras /reload", ui.button:IsShown(), false)
ui.Slash("options")
expect("casilla sin marcar", Ticked(ui), false)
Click(ui)
expect("la casilla lo muestra", ui.button:IsShown(), true)
expect("se guarda visible", DisenchantForeverDB.hidden, false)
expect("casilla marcada", Ticked(ui), true)
expect("apunta al mostrarse", ui.button:GetAttribute("macrotext"), MACRO)
Click(ui)
expect("la casilla lo oculta", ui.button:IsShown(), false)
ui = Login(Saved(), { knows = true })
expect("oculto por la casilla tras /reload", ui.button:IsShown(), false)
expect("nada bloqueado", #blocked, 0)

print("-- personaje sin Encantamiento")
ui = Login(nil, { knows = false })
expect("oculto por defecto", ui.button:IsShown(), false)
expect("lo avisa una vez", Count("does not know"), 1)
local scans = bagScans
ui.Fire("BAG_UPDATE_DELAYED")
expect("oculto no recorre las bolsas", bagScans, scans)
ui = Login(Saved(), { knows = false })
expect("el aviso no se repite", Count("does not know"), 0)
ui.Slash("options")
expect("casilla sin marcar", Ticked(ui), false)
ui.Slash("")
expect("/dis lo muestra", ui.button:IsShown(), true)
expect("y apunta", ui.button:GetAttribute("macrotext"), MACRO)
expect("casilla al dia", Ticked(ui), true)
ui = Login(Saved(), { knows = false })
expect("mostrado a mano sigue tras /reload", ui.button:IsShown(), true)

print("-- aprende u olvida Encantamiento con la partida abierta")
ui = Login(nil, { knows = false })
state.knows = true
ui.Fire("SPELLS_CHANGED")
expect("al aprenderlo aparece", ui.button:IsShown(), true)
state.knows = false
ui.Fire("SPELLS_CHANGED")
expect("al olvidarlo se va", ui.button:IsShown(), false)
ui = Login({ hidden = true }, { knows = false })
state.knows = true
ui.Fire("SPELLS_CHANGED")
expect("si lo oculto a mano, sigue oculto", ui.button:IsShown(), false)

print("-- lo guardado con el parche del comentario")
ui = Login({ hidden = true }, { knows = true })
expect("hidden = true", ui.button:IsShown(), false)
ui = Login({ hidden = false }, { knows = false })
expect("hidden = false", ui.button:IsShown(), true)
expect("sin aviso si eligio", Said("does not know"), false)

print("-- lo guardado por la 1.43 en un encantador")
ui = Login({ raros = true, epicos = false, materiales = true, locked = false, point = "BOTTOM",
    relPoint = "BOTTOM", x = 656.6, y = 244.6, baneados = { [4566] = "x" } }, { knows = true })
expect("se ve", ui.button:IsShown(), true)
expect("conserva la posicion", (ui.button:GetPoint()), "BOTTOM")
expect("conserva los vetados", DisenchantForeverDB.baneados[4566], "x")

print("-- como sabe si desencanta")
ui = Login(nil, { knows = false, profIndex = 5, profSkill = 333 })
expect("por la profesion (333)", ui.button:IsShown(), true)
ui = Login(nil, { knows = false, profIndex = 5, profSkill = 186 })
expect("otra profesion no cuenta", ui.button:IsShown(), false)
ui = Login(nil, { noApi = true })
expect("sin ninguna API se muestra", ui.button:IsShown(), true)
expect("y sin aviso", Said("does not know"), false)
ui = Login(nil, { secret = true, profIndex = 5, profSkill = 333 })
expect("hechizo secreto y Encantamiento: se ve", ui.button:IsShown(), true)
ui = Login(nil, { secret = true })
expect("hechizo secreto y sin profesiones: oculto", ui.button:IsShown(), false)
ui = Login(nil, { secret = true, noProfessions = true })
expect("hechizo secreto y nada mas: se ve", ui.button:IsShown(), true)

print("-- combate")
ui = Login(nil, { knows = true })
ui.Slash("options")
state.combat = true
ui.Slash("")
expect("nada bloqueado", #blocked, 0)
expect("sigue visible en combate", ui.button:IsShown(), true)
expect("eleccion guardada", DisenchantForeverDB.hidden, true)
expect("avisa", Said("hide when combat ends"), true)
expect("no dice que ya esta oculto", Said("button hidden"), false)
expect("la casilla ya muestra lo elegido", Ticked(ui), false)
state.combat = false
ui.Fire("PLAYER_REGEN_ENABLED")
expect("al salir se oculta", ui.button:IsShown(), false)

state.combat = true
Click(ui)
expect("casilla en combate: avisa", Said("show when combat ends"), true)
Click(ui)
Click(ui)
expect("nada bloqueado", #blocked, 0)
state.combat = false
ui.Fire("PLAYER_REGEN_ENABLED")
expect("tres clics en combate: visible", ui.button:IsShown(), true)
expect("y apunta", ui.button:GetAttribute("macrotext"), MACRO)

ui = Login({ point = "TOP", relPoint = "TOP", x = 1, y = 2 }, { knows = true })
state.combat = true
ui.Slash("reset")
ui.button.scripts.OnDragStart(ui.button)
ui.button.scripts.OnDragStop(ui.button)
expect("recolocar y arrastrar en combate: nada bloqueado", #blocked, 0)
expect("no se mueve en combate", (ui.button:GetPoint()), "TOP")
state.combat = false
ui.Fire("PLAYER_REGEN_ENABLED")
expect("al salir se recoloca", (ui.button:GetPoint()), "CENTER")
expect("el arrastre en combate no guardo nada", DisenchantForeverDB.point, "CENTER")
ui.button.scripts.OnDragStart(ui.button)
ui.button.scripts.OnDragStop(ui.button)
expect("fuera de combate se arrastra", #blocked, 0)

print("-- objetos con botin propio (efigie de cera)")
ui = Login(nil, { knows = true, item = "|cff1eff00|Hitem:247883::::::::22:::::::|h[Effigy]|h|r" })
expect("apunta a la efigie", ui.button:GetAttribute("macrotext"), MACRO)
ui = Login(nil, { knows = true, item = "|cff1eff00|Hitem:2589::::::::22:::::::|h[Linen]|h|r" })
expect("otro material verde no", ui.button:GetAttribute("macrotext"), "")
expect("nada bloqueado", #blocked, 0)

print("-- textos")
ui = Login(nil, { knows = true })
ui.button.scripts.OnEnter(ui.button)
local hint = GameTooltip.lines[#GameTooltip.lines]
expect("pista de la ventanita", hint, "/dis options opens the options window.")
ui = Login(nil, { knows = true, locale = "esES" })
ui.button.scripts.OnEnter(ui.button)
expect("pista en espanol", GameTooltip.lines[#GameTooltip.lines], "/dis options abre la ventana de opciones.")
ui.Slash("status")
expect("diagnostico", Said("visibility: auto"), true)

local NEW = { "/dis options opens the options window.", "the button will show when combat ends.",
    "the button will hide when combat ends.",
    "this character does not know Disenchant, so the button stays hidden. |cffffd100/dis|r shows it." }
local languages = 0
for lang, texts in pairs(ui.ns.L) do
    languages = languages + 1
    for _, key in ipairs(NEW) do
        if not texts[key] then expect(lang .. " traduce [" .. key .. "]", nil, "algo") end
    end
    if texts["/dis for the options."] then expect(lang .. " sin la pista vieja", true, false) end
end
expect("idiomas con todo traducido", languages, 10)

print()
if failures > 0 then
    print(failures .. " FALLO(S)")
    os.exit(1)
end
print("todo bien")
