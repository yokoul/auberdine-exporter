-- Minimap button for AuberdineExporter
-- Bouton posé sur le POURTOUR circulaire de la minimap (angle en degrés),
-- déplaçable à la souris le long du bord, position persistée dans
-- AuberdineExporterDB.settings.minimapButtonAngle.
AuberdineMinimapButton = {}

-- Angle courant (degrés). 0 = 3 h (bord droit), sens trigonométrique.
AuberdineMinimapButton.angle = 0

-- Accès défensif aux réglages : la SavedVariable peut ne pas être prête.
local function settings()
    if AuberdineExporterDB and AuberdineExporterDB.settings then
        return AuberdineExporterDB.settings
    end
    return nil
end

-- Place le bouton sur le pourtour à l'angle donné (rayon dérivé de la
-- taille réelle de la minimap → suit un éventuel redimensionnement/échelle).
local function place(button, angle)
    local rad = math.rad(angle)
    local radius = (Minimap:GetWidth() / 2) + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(rad) * radius, math.sin(rad) * radius)
end

function AuberdineMinimapButton:Initialize()
    self:CreateButton()
    local s = settings()
    if s and type(s.minimapButtonAngle) == "number" then
        self.angle = s.minimapButtonAngle
    end
    self:SetPosition(self.angle)
    if s and s.minimapButtonHidden then
        self:SetVisibility(false)
    end
end

-- Suit le curseur : recalcule l'angle depuis le centre de la minimap.
-- Formule éprouvée (cf. LibDBIcon) : curseur ramené à l'échelle de la
-- minimap, atan2 sur l'écart au centre.
local function dragUpdate(self)
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local px, py = GetCursorPosition()
    px, py = px / scale, py / scale
    local angle = math.deg(math.atan2(py - my, px - mx))
    AuberdineMinimapButton:SetPosition(angle)
end

function AuberdineMinimapButton:CreateButton()
    if self.button then
        return self.button
    end

    -- Détruire d'anciens boutons éventuels
    for _, name in ipairs({ "AuberdineMinimapButton", "AuberdineExporterMinimapButton" }) do
        local old = _G[name]
        if old and old ~= self.button and old.Hide then
            old:Hide()
            old:SetParent(nil)
        end
    end

    -- Géométrie calquée sur LibDBIcon (combinaison éprouvée) : bouton 31,
    -- disque de fond + icône ancrés en TOPLEFT 7,-6, anneau sur-dimensionné
    -- ancré TOPLEFT — c'est ce décalage qui recentre l'anneau sur l'icône.
    local button = CreateFrame("Button", "AuberdineMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    -- Disque de fond : assise sombre sous l'icône (sans lui, l'icône flotte).
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)

    -- Icône, posée sur le disque
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\AddOns\\AuberdineExporter\\UI\\Icons\\ab64.png")
    icon:SetSize(18, 18)
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)
    icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

    -- Anneau doré natif : sur-dimensionné, ancré TOPLEFT (recentre l'anneau).
    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetSize(53, 53)
    overlay:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

    -- Surbrillance
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints(button)

    button:SetScript("OnClick", function()
        if type(ToggleMainFrame) == "function" then
            ToggleMainFrame()
        elseif _G.ToggleMainFrame and type(_G.ToggleMainFrame) == "function" then
            _G.ToggleMainFrame()
        else
            SlashCmdList["AUBERDINE"]("show")
        end
    end)

    -- Déplacement le long du pourtour
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", dragUpdate)
        GameTooltip:Hide()
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        AuberdineMinimapButton:SavePosition()
    end)

    -- Tooltip (+ agenda des world buffs planifiés, cf. Worldbuffs.lua)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Auberdine Exporter")
        GameTooltip:AddLine("Clic : ouvrir l'interface", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("Glisser : déplacer le bouton", 0.6, 0.6, 0.6)
        if AuberdineWorldbuffs and AuberdineWorldbuffs.AddToTooltip then
            AuberdineWorldbuffs.AddToTooltip(GameTooltip)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.button = button
    place(button, self.angle)
    return button
end

function AuberdineMinimapButton:SetVisibility(show)
    if not self.button then return end
    if show then self.button:Show() else self.button:Hide() end
end

function AuberdineMinimapButton:SetPosition(angle)
    if not self.button then return end
    if type(angle) ~= "number" then angle = self.angle or 0 end
    -- Normalise dans [0, 360) pour une persistance propre.
    angle = angle % 360
    self.angle = angle
    place(self.button, angle)
end

function AuberdineMinimapButton:SavePosition()
    local s = settings()
    if s then
        s.minimapButtonAngle = self.angle or 0
    end
end
