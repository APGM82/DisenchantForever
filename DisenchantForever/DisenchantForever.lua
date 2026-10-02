-- Disenchant Forever
-- Boton que apunta al siguiente objeto desencantable de las bolsas.
-- El juego no deja desencantar en automatico, asi que toca un clic por objeto.

local ADDON, ns = ...

local PREFIX = "|cffa335eeDisenchant Forever|r: "
local DISENCHANT_SPELL = 13262

local QUALITY_UNCOMMON, QUALITY_RARE, QUALITY_EPIC = 2, 3, 4
local CLASS_WEAPON, CLASS_ARMOR = 2, 4

local DEFAULTS = {
    epicos   = false,       -- epicos fuera por defecto
    raros    = true,
    locked   = false,
    point    = "CENTER",
    relPoint = "CENTER",
    x        = 200,
    y        = 0,
}

local db
local button, banButton, optionsButton, icon, countText, nameText
local options
local spellName
local pending           -- refresco pendiente hasta salir de combate

-- se llaman entre ellas
local Refresh, RefreshOptions, PrintState

-- La clave es el ingles. Idioma sin traducir -> se ve la clave.
local L = setmetatable({}, { __index = function(_, key) return key end })

for key, value in pairs(ns.L[(GetLocale and GetLocale()) or "enUS"] or {}) do
    L[key] = value
end

-- traducir antes de formatear, que el orden cambia segun el idioma
local function Say(text, ...)
    local message = L[text]
    if select("#", ...) > 0 then
        message = string.format(message, ...)
    end
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. message)
end

-- en este cliente unas estan en C_Item/C_Container y otras sueltas
local NumSlots       = (C_Container and C_Container.GetContainerNumSlots) or _G.GetContainerNumSlots
local ContainerInfo  = (C_Container and C_Container.GetContainerItemInfo) or _G.GetContainerItemInfo
local GetInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
local GetInfo        = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo

local function SpellName(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if type(info) == "table" then return info.name end
        return info
    end
    if _G.GetSpellInfo then
        return (_G.GetSpellInfo(spellID))
    end
    return nil
end

-- dos firmas posibles segun la version
local function SlotContents(bag, slot)
    if not ContainerInfo then return nil end

    local info = ContainerInfo(bag, slot)
    if type(info) == "table" then
        return info.hyperlink, info.quality, info.iconFileID
    end

    -- firma antigua
    local texture, _, _, quality, _, _, link = ContainerInfo(bag, slot)
    return link, quality, texture
end

local function ClassOf(link)
    if GetInfoInstant then
        local _, _, _, _, _, classID = GetInfoInstant(link)
        return classID
    end
    if GetInfo then
        local _, _, _, _, _, _, _, _, _, _, _, classID = GetInfo(link)
        return classID
    end
    return nil
end

local function MaxQuality()
    if db.epicos then return QUALITY_EPIC end
    if db.raros then return QUALITY_RARE end
    return QUALITY_UNCOMMON
end

-- el veto va por itemID, asi vale para todos los iguales
local function ItemIDOf(link)
    if not link then return nil end

    if GetInfoInstant then
        local itemID = GetInfoInstant(link)
        if itemID then return itemID end
    end

    -- del enlace, por si acaso
    return tonumber(string.match(tostring(link), "item:(%d+)"))
end

local function IsBanned(link)
    local itemID = ItemIDOf(link)
    return itemID ~= nil and db.baneados[itemID] ~= nil
end

-- lo blanco y lo gris no se puede desencantar
local function IsCandidate(link, quality)
    if not link or not quality then return false end
    if quality < QUALITY_UNCOMMON or quality > MaxQuality() then return false end
    if IsBanned(link) then return false end
    local classID = ClassOf(link)
    return classID == CLASS_WEAPON or classID == CLASS_ARMOR
end

local function FindNext()
    if not NumSlots then return nil, 0 end

    local first, total = nil, 0
    for bag = 0, 4 do
        for slot = 1, (NumSlots(bag) or 0) do
            local link, quality, texture = SlotContents(bag, slot)
            if IsCandidate(link, quality) then
                total = total + 1
                if not first then
                    first = { bag = bag, slot = slot, link = link, texture = texture }
                end
            end
        end
    end
    return first, total
end

-- ------------------------------------------------------------------ boton

function Refresh()
    if not button then return end
    if RefreshOptions then RefreshOptions() end

    -- en combate no se puede tocar; se hace al salir
    if InCombatLockdown and InCombatLockdown() then
        pending = true
        return
    end
    pending = nil

    local target, total = FindNext()

    if not target or not spellName then
        button:SetAttribute("macrotext", "")
        icon:SetTexture("Interface\\Icons\\INV_Enchant_Disenchant")
        icon:SetDesaturated(true)
        countText:SetText("")
        nameText:SetText(spellName and L["nothing to disenchant"]
            or ("|cffff5555" .. L["no spell"] .. "|r"))
        return
    end

    button:SetAttribute("macrotext",
        string.format("/cast %s\n/use %d %d", spellName, target.bag, target.slot))

    icon:SetTexture(target.texture or "Interface\\Icons\\INV_Enchant_Disenchant")
    icon:SetDesaturated(false)
    countText:SetText(total > 1 and total or "")
    nameText:SetText(target.link)
end

-- --------------------------------------------------------------- vetados

local function BanCurrent()
    local target = FindNext()
    if not target then
        Say("nothing targeted to ban.")
        return
    end

    local itemID = ItemIDOf(target.link)
    if not itemID then
        Say("I cannot identify that item, so I cannot ban it.")
        return
    end

    db.baneados[itemID] = target.link
    Refresh()
    Say("banned: %s. It will not come up again.", target.link)
end

local function ListBanned()
    local count = 0
    for _ in pairs(db.baneados) do count = count + 1 end

    if count == 0 then
        Say("nothing is banned.")
        return
    end

    Say("banned items (%d):", count)
    for itemID, link in pairs(db.baneados) do
        Say(string.format("  %s |cff999999(%d)|r", link, itemID))
    end
    Say("|cffffd100/dis clear|r empties the list.")
end

local function ClearBanned()
    local count = 0
    for _ in pairs(db.baneados) do count = count + 1 end

    if count == 0 then
        Say("the list was already empty.")
        return
    end

    db.baneados = {}
    Refresh()
    Say("list emptied: %d item(s) come back in.", count)
end

local function Unban(itemID)
    if not db.baneados[itemID] then return end
    db.baneados[itemID] = nil
    Refresh()
end

-- ------------------------------------------------------ ventana de opciones
-- Marcos y texturas a pelo. Una plantilla de Blizzard que no exista tumba
-- el addon entero al cargar, asi que mejor no depender de ninguna.

local ROW_HEIGHT, MAX_ROWS = 20, 5
local listOffset = 0

-- recuadro con borde
local function Panel(parent, r, g, b, a)
    local edge = parent:CreateTexture(nil, "BACKGROUND")
    edge:SetColorTexture(0.42, 0.32, 0.58, 0.9)
    local face = parent:CreateTexture(nil, "BORDER")
    face:SetColorTexture(r, g, b, a)
    face:SetPoint("TOPLEFT", edge, "TOPLEFT", 1, -1)
    face:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", -1, 1)
    return edge, face
end

local function MakeCheck(parent, labelKey, getter, setter)
    local check = CreateFrame("Button", nil, parent)
    check:SetSize(18, 18)

    local edge, face = Panel(check, 0.10, 0.08, 0.14, 1)
    edge:SetAllPoints(check)

    local mark = check:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mark:SetPoint("CENTER", 0, 0)

    local label = check:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", check, "RIGHT", 6, 0)
    label:SetText(L[labelKey])
    label:SetTextColor(0.9, 0.88, 0.95)

    check:SetScript("OnClick", function()
        setter(not getter())
        Refresh()
        RefreshOptions()
    end)
    check:SetScript("OnEnter", function() face:SetColorTexture(0.20, 0.16, 0.28, 1) end)
    check:SetScript("OnLeave", function() face:SetColorTexture(0.10, 0.08, 0.14, 1) end)

    check.Update = function()
        mark:SetText(getter() and "|cff66dd66x|r" or "")
    end
    return check
end

local function MakeButton(parent, width, labelKey, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, 22)

    local edge, face = Panel(btn, 0.24, 0.18, 0.34, 1)
    edge:SetAllPoints(btn)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER")
    label:SetText(L[labelKey])

    btn:SetScript("OnEnter", function() face:SetColorTexture(0.34, 0.26, 0.48, 1) end)
    btn:SetScript("OnLeave", function() face:SetColorTexture(0.24, 0.18, 0.34, 1) end)
    btn:SetScript("OnClick", onClick)
    return btn
end

local function BuildOptions()
    options = CreateFrame("Frame", "DisenchantForeverOpciones", UIParent)
    options:SetSize(330, 400)
    options:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    options:SetFrameStrata("DIALOG")
    options:SetClampedToScreen(true)
    options:SetMovable(true)
    options:EnableMouse(true)
    options:RegisterForDrag("LeftButton")
    options:SetScript("OnDragStart", options.StartMoving)
    options:SetScript("OnDragStop", options.StopMovingOrSizing)

    local edge = options:CreateTexture(nil, "BACKGROUND")
    edge:SetAllPoints()
    edge:SetColorTexture(0.42, 0.32, 0.58, 1)
    local face = options:CreateTexture(nil, "BORDER")
    face:SetPoint("TOPLEFT", 2, -2)
    face:SetPoint("BOTTOMRIGHT", -2, 2)
    face:SetColorTexture(0.06, 0.05, 0.09, 0.96)

    local title = options:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -12)
    title:SetText("|cffa335eeDisenchant Forever|r")

    local close = MakeButton(options, 22, "x", function() options:Hide() end)
    close:SetPoint("TOPRIGHT", -8, -8)

    -- casillas
    local showCheck = MakeCheck(options, "Show the button",
        function() return button:IsShown() end,
        function(value)
            if value then button:Show() else button:Hide() end
        end)
    showCheck:SetPoint("TOPLEFT", 16, -44)

    local lockCheck = MakeCheck(options, "Lock in place",
        function() return db.locked end,
        function(value) db.locked = value end)
    lockCheck:SetPoint("TOPLEFT", 16, -70)

    local blueCheck = MakeCheck(options, "Include blue items",
        function() return db.raros end,
        function(value) db.raros = value end)
    blueCheck:SetPoint("TOPLEFT", 16, -100)

    local epicCheck = MakeCheck(options, "Include epics (careful)",
        function() return db.epicos end,
        function(value) db.epicos = value end)
    epicCheck:SetPoint("TOPLEFT", 16, -126)

    local resetButton = MakeButton(options, 120, "Reset position", function()
        db.point, db.relPoint = DEFAULTS.point, DEFAULTS.relPoint
        db.x, db.y = DEFAULTS.x, DEFAULTS.y
        button:ClearAllPoints()
        button:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
    end)
    resetButton:SetPoint("TOPLEFT", 16, -154)

    local diagButton = MakeButton(options, 150, "Diagnosis to chat", function()
        PrintState()
    end)
    diagButton:SetPoint("TOPLEFT", 146, -154)

    -- estado
    local status = options:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("TOPLEFT", 16, -186)
    status:SetTextColor(0.75, 0.72, 0.82)

    -- lista de vetados
    local listTitle = options:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listTitle:SetPoint("TOPLEFT", 16, -208)
    listTitle:SetText(L["Banned items"])

    local listEdge = options:CreateTexture(nil, "BACKGROUND")
    listEdge:SetPoint("TOPLEFT", 14, -228)
    listEdge:SetPoint("BOTTOMRIGHT", -14, 44)
    listEdge:SetColorTexture(0.42, 0.32, 0.58, 0.6)
    local listFace = options:CreateTexture(nil, "BORDER")
    listFace:SetPoint("TOPLEFT", listEdge, "TOPLEFT", 1, -1)
    listFace:SetPoint("BOTTOMRIGHT", listEdge, "BOTTOMRIGHT", -1, 1)
    listFace:SetColorTexture(0.03, 0.02, 0.05, 0.9)

    local empty = options:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    empty:SetPoint("TOPLEFT", 24, -238)
    empty:SetTextColor(0.6, 0.58, 0.65)

    local more = options:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    more:SetPoint("BOTTOMLEFT", 24, 50)
    more:SetTextColor(0.6, 0.58, 0.65)

    -- rueda para recorrer la lista
    local wheel = CreateFrame("Frame", nil, options)
    wheel:SetPoint("TOPLEFT", listEdge, "TOPLEFT")
    wheel:SetPoint("BOTTOMRIGHT", listEdge, "BOTTOMRIGHT")
    wheel:EnableMouseWheel(true)
    wheel:SetScript("OnMouseWheel", function(_, delta)
        listOffset = listOffset - delta
        RefreshOptions()
    end)

    -- filas reutilizadas
    options.rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Frame", nil, options)
        row:SetSize(268, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 22, -234 - (i - 1) * ROW_HEIGHT)

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.text:SetPoint("LEFT", 0, 0)
        row.text:SetWidth(240)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(false)

        row.remove = MakeButton(row, 18, "x", nil)
        row.remove:SetPoint("RIGHT", 0, 0)
        row.remove:SetHeight(16)

        row:Hide()
        options.rows[i] = row
    end

    local clearButton = MakeButton(options, 120, "Clear all", function()
        ClearBanned()
    end)
    clearButton:SetPoint("BOTTOMLEFT", 16, 14)

    options.checks = { showCheck, lockCheck, blueCheck, epicCheck }
    options.status = status
    options.empty = empty
    options.more = more
    options:Hide()
end

function RefreshOptions()
    if not options or not options:IsShown() then return end

    for _, check in ipairs(options.checks) do
        check.Update()
    end

    local _, total = FindNext()
    options.status:SetText(string.format(L["%d candidates in your bags"], total))

    -- ordenado, si no la lista baila
    local banned = {}
    for itemID, link in pairs(db.baneados) do
        banned[#banned + 1] = { id = itemID, link = link }
    end
    table.sort(banned, function(a, b) return a.id < b.id end)

    local maxOffset = math.max(0, #banned - MAX_ROWS)
    listOffset = math.min(math.max(listOffset, 0), maxOffset)

    for i, row in ipairs(options.rows) do
        local entry = banned[i + listOffset]
        if entry then
            row.text:SetText(entry.link)
            row.remove:SetScript("OnClick", function()
                Unban(entry.id)
                RefreshOptions()
            end)
            row:Show()
        else
            row:Hide()
        end
    end

    options.empty:SetText(#banned == 0 and L["Nothing banned yet."] or "")
    local below = #banned - MAX_ROWS - listOffset
    options.more:SetText(below > 0
        and string.format(L["and %d more"], below) or "")
end

local function ToggleOptions()
    if not options then return end
    if options:IsShown() then
        options:Hide()
    else
        options:Show()
        RefreshOptions()
    end
end

local function Build()
    button = CreateFrame("Button", "DisenchantForeverBoton", UIParent, "SecureActionButtonTemplate")
    button:SetSize(44, 44)
    button:SetAttribute("type", "macro")
    -- solo el izquierdo: con Any, el derecho desencantaba al ir a mover.
    -- Las dos direcciones si hacen falta o este cliente no responde.
    button:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
    button:SetClampedToScreen(true)
    button:SetMovable(true)

    -- con el derecho: el izquierdo es para desencantar
    button:RegisterForDrag("RightButton")
    button:SetScript("OnDragStart", function(self)
        if not db.locked then self:StartMoving() end
    end)
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
    end)

    local border = button:CreateTexture(nil, "BACKGROUND")
    border:SetColorTexture(0, 0, 0, 0.8)
    border:SetPoint("TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", 2, -2)

    icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()

    countText = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    countText:SetPoint("BOTTOMRIGHT", -2, 2)

    nameText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("TOP", button, "BOTTOM", 0, -4)
    nameText:SetWidth(180)
    nameText:SetWordWrap(false)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Disenchant Forever")
        GameTooltip:AddLine(L["Left click: disenchant the item shown."], 1, 1, 1)
        GameTooltip:AddLine(L["Right click and drag: move the button."], 1, 1, 1)
        GameTooltip:AddLine(L["The red X bans the item and moves to the next one."], 1, 1, 1)
        GameTooltip:AddLine(L["/dis for the options."], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- boton normal, no seguro, para que el clic no se mezcle
    banButton = CreateFrame("Button", nil, button)
    banButton:SetSize(16, 16)
    banButton:SetPoint("TOPRIGHT", button, "TOPRIGHT", 6, 6)
    banButton:SetFrameLevel(button:GetFrameLevel() + 2)

    local banBack = banButton:CreateTexture(nil, "BACKGROUND")
    banBack:SetAllPoints()
    banBack:SetColorTexture(0, 0, 0, 0.8)

    local banMark = banButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    banMark:SetPoint("CENTER", 0, 0)
    banMark:SetText("|cffff5555X|r")

    banButton:SetScript("OnClick", BanCurrent)
    banButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["Ban this item"])
        GameTooltip:AddLine(L["It will not come up again, nor any others like it."], 1, 1, 1)
        GameTooltip:AddLine(L["Remembered between sessions."], 1, 1, 1)
        GameTooltip:AddLine(L["/dis list to see them, /dis clear to empty."], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    banButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- engranaje, arriba a la izquierda; abajo se pisaba con el nombre
    optionsButton = CreateFrame("Button", nil, button)
    optionsButton:SetSize(18, 18)
    optionsButton:SetPoint("TOPLEFT", button, "TOPLEFT", -6, 6)
    optionsButton:SetFrameLevel(button:GetFrameLevel() + 2)

    local gearBack = optionsButton:CreateTexture(nil, "BACKGROUND")
    gearBack:SetAllPoints()
    gearBack:SetColorTexture(0, 0, 0, 0.85)

    -- si la textura faltara queda el cuadro, que se sigue pulsando
    local gear = optionsButton:CreateTexture(nil, "ARTWORK")
    gear:SetPoint("TOPLEFT", 2, -2)
    gear:SetPoint("BOTTOMRIGHT", -2, 2)
    gear:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    gear:SetVertexColor(1, 0.85, 0.4)

    optionsButton:SetScript("OnClick", function() ToggleOptions() end)
    optionsButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["Options"])
        GameTooltip:Show()
    end)
    optionsButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function ApplyPosition()
    button:ClearAllPoints()
    button:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
end

-- --------------------------------------------------------------- comandos

function PrintState()
    local yes, no = L["yes"], L["no"]
    local noLoud = "|cffff5555" .. L["no"] .. "|r"

    Say("status:")
    Say("  spell: %s", spellName or ("|cffff5555" .. L["not found"] .. "|r"))
    local target, total = FindNext()
    Say("  candidates in bags: %d", total)
    Say("  next: %s", target and target.link or L["none"])
    Say("  blues: %s | epics: %s", db.raros and yes or no, db.epicos and yes or no)
    Say("  functions: bags=%s item=%s",
        (NumSlots and ContainerInfo) and yes or noLoud,
        (GetInfoInstant or GetInfo) and yes or noLoud)

    -- lo util cuando el clic no hace nada
    if not button then
        Say("  |cffff5555the button does not exist|r")
        return
    end

    local macro = button:GetAttribute("macrotext")
    if macro and macro ~= "" then
        Say("  button order:")
        for line in string.gmatch(macro, "[^\n]+") do
            Say("    |cffffd100" .. line .. "|r")
        end
    else
        Say("  button order: |cffff5555empty|r")
    end

    Say("  type=%s shown=%s enabled=%s",
        tostring(button:GetAttribute("type")),
        button:IsShown() and yes or no,
        (button.IsEnabled and button:IsEnabled()) and yes or no)
    Say("  strata=%s level=%s",
        tostring(button:GetFrameStrata()), tostring(button:GetFrameLevel()))
end

local function HandleSlash(msg)
    local cmd = strlower(strtrim(msg or ""))

    -- ordenes solo en ingles; se traduce la explicacion, no la palabra
    if cmd == "" then
        if button:IsShown() then
            button:Hide()
            Say("button hidden. |cffffd100/dis|r brings it back.")
        else
            button:Show()
            Refresh()
            Say("button shown.")
        end

    elseif cmd == "options" or cmd == "config" then
        ToggleOptions()

    elseif cmd == "status" then
        PrintState()

    elseif cmd == "ban" then
        BanCurrent()

    elseif cmd == "list" then
        ListBanned()

    -- ojo: reset es para la posicion
    elseif cmd == "clear" then
        ClearBanned()

    elseif cmd == "lock" then
        db.locked = not db.locked
        Say(db.locked and "button locked." or "button loose: move it with the right button.")

    elseif cmd == "reset" then
        db.point, db.relPoint = DEFAULTS.point, DEFAULTS.relPoint
        db.x, db.y = DEFAULTS.x, DEFAULTS.y
        ApplyPosition()
        Say("button put back.")

    elseif cmd == "blues" then
        db.raros = not db.raros
        Refresh()
        Say(db.raros and "blues are in." or "blues are out.")

    elseif cmd == "epics" then
        db.epicos = not db.epicos
        Refresh()
        Say(db.epicos and "|cffff5555epics are in. Careful.|r" or "epics are out.")

    else
        Say("commands:")
        Say("  |cffffd100/dis options|r - open the options window")
        Say("  |cffffd100/dis|r - show or hide the button")
        Say("  |cffffd100/dis ban|r - ban the item shown (same as the red X)")
        Say("  |cffffd100/dis list|r - see the banned items")
        Say("  |cffffd100/dis clear|r - empty the banned list")
        Say("  |cffffd100/dis blues|r / |cffffd100epics|r - which qualities count")
        Say("  |cffffd100/dis lock|r / |cffffd100reset|r - fix and reposition the button")
        Say("  |cffffd100/dis status|r - diagnosis")
    end
end

-- ---------------------------------------------------------------- arranque

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("BAG_UPDATE_DELAYED")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")
loader:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ADDON then return end
        DisenchantForeverDB = DisenchantForeverDB or {}
        db = DisenchantForeverDB
        for key, value in pairs(DEFAULTS) do
            if db[key] == nil then db[key] = value end
        end
        -- aparte, que una tabla en DEFAULTS se compartiria por referencia
        db.baneados = db.baneados or {}

    elseif event == "PLAYER_LOGIN" then
        spellName = SpellName(DISENCHANT_SPELL)
        Build()
        BuildOptions()
        ApplyPosition()
        Refresh()

        SLASH_DISENCHANTFOREVER1 = "/dis"
        SLASH_DISENCHANTFOREVER2 = "/disenchant"
        SLASH_DISENCHANTFOREVER3 = "/di"
        SlashCmdList.DISENCHANTFOREVER = HandleSlash

        if not spellName then
            Say("|cffff5555I cannot find the Disenchant spell|r. Type |cffffd100/dis status|r and send me what it says.")
        end

    elseif event == "BAG_UPDATE_DELAYED" then
        if db then Refresh() end

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- al salir de combate, lo que quedo pendiente
        if pending and db then Refresh() end
    end
end)
