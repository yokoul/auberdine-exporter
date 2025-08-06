-- Minimap button for AuberdineExporter (SIMPLE VERSION)
AuberdineMinimapButton = {}

function AuberdineMinimapButton:Initialize()
    self:CreateButton()
end

function AuberdineMinimapButton:CreateButton()
    if self.button then
        return self.button
    end
    
    -- Détruire l'ancien bouton s'il existe
    local oldButton = _G["AuberdineMinimapButton"]
    if oldButton and oldButton.Hide then
        oldButton:Hide()
        oldButton:SetParent(nil)
    end
    local oldExporter = _G["AuberdineExporterMinimapButton"]
    if oldExporter and oldExporter.Hide then
        oldExporter:Hide()
        oldExporter:SetParent(nil)
    end
    
    -- Create simple minimap button
    local button = CreateFrame("Button", "AuberdineMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -15, 15)
    
    -- Icon
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\AddOns\\AuberdineExporter\\UI\\Icons\\ab64.png")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexCoord(0.1, 0.9, 0.1, 0.9) -- Meilleur cadrage de l'icône

    -- Highlight
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints(button)
    
    -- Events
    button:EnableMouse(true)
    button:SetScript("OnClick", function()
        -- Utiliser la fonction globale directement
        if type(ToggleMainFrame) == "function" then
            ToggleMainFrame()
        elseif _G.ToggleMainFrame and type(_G.ToggleMainFrame) == "function" then
            _G.ToggleMainFrame()
        else
            -- Fallback: essayer la commande slash
            SlashCmdList["AUBERDINE"]("show")
        end
    end)
    
    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Auberdine Exporter")
        GameTooltip:AddLine("Cliquez pour ouvrir l'interface")
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    self.button = button
    return button
end

function AuberdineMinimapButton:SetVisibility(show)
    if not self.button then return end
    if show then
        self.button:Show()
    else
        self.button:Hide()
    end
end

function AuberdineMinimapButton:SetPosition(angle)
    -- Position sur le bord du minimap
    if not self.button then return end
    self.button:ClearAllPoints()
    self.button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -15, 15)
end

function AuberdineMinimapButton:SavePosition()
    -- Placeholder pour compatibilité
end
