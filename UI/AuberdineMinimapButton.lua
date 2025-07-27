-- Minimap button for RecipesExtractor
RecipesExtractorMinimapButton = {}

function RecipesExtractorMinimapButton:Initialize()
    self:CreateButton()
    self:LoadPosition()
end

function RecipesExtractorMinimapButton:CreateButton()
    if self.button then
        return self.button
    end
    
    -- Create the minimap button
    local button = CreateFrame("Button", "RecipesExtractorMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    
    -- Icon texture
    button.icon = button:CreateTexture(nil, "BACKGROUND")
    button.icon:SetSize(20, 20)
    button.icon:SetPoint("CENTER", 0, 1)
    button.icon:SetTexture("Interface\\AddOns\\RecipesExtractor\\UI\\Icons\\rc32.png")
    
    -- Border texture
    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetSize(52, 52)
    button.border:SetPoint("TOPLEFT", -10, 10)
    button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    
    -- Make it draggable
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForDrag("LeftButton")
    
    -- Click handlers
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    button:SetScript("OnClick", function(self, clickType)
        if clickType == "LeftButton" then
            RecipesExtractorUI:ToggleMainFrame()
        elseif clickType == "RightButton" then
            RecipesExtractorMinimapButton:ShowContextMenu()
        end
    end)
    
    -- Drag functionality
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", RecipesExtractorMinimapButton.OnUpdate)
    end)
    
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        RecipesExtractorMinimapButton:SavePosition()
    end)
    
    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Recipes Extractor", 1, 1, 1)
        GameTooltip:AddLine("Clic gauche : Ouvrir l'interface", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Clic droit : Menu contextuel", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Glisser : Déplacer l'icône", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Position the button
    button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0)
    
    self.button = button
    return button
end

function RecipesExtractorMinimapButton.OnUpdate(self)
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    
    px, py = px / scale, py / scale
    
    local angle = math.atan2(py - my, px - mx)
    local x, y = math.cos(angle), math.sin(angle)
    local minimapRadius = (Minimap:GetWidth() / 2) + 10
    
    x = x * minimapRadius
    y = y * minimapRadius
    
    self:SetPoint("CENTER", Minimap, "CENTER", x, y)
    
    -- Store angle for saving
    RecipesExtractorMinimapButton.angle = angle
end

function RecipesExtractorMinimapButton:SetPosition(angle)
    if not self.button then return end
    
    self.angle = angle or self.angle or 0
    
    local x = math.cos(self.angle) * ((Minimap:GetWidth() / 2) + 10)
    local y = math.sin(self.angle) * ((Minimap:GetHeight() / 2) + 10)
    
    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function RecipesExtractorMinimapButton:SavePosition()
    if not RecipesExtractorDB then return end
    
    if not RecipesExtractorDB.settings then
        RecipesExtractorDB.settings = {}
    end
    
    RecipesExtractorDB.settings.minimapButtonAngle = self.angle or 0
end

function RecipesExtractorMinimapButton:LoadPosition()
    if not RecipesExtractorDB or not RecipesExtractorDB.settings then return end
    
    local angle = RecipesExtractorDB.settings.minimapButtonAngle or 0
    self:SetPosition(angle)
end

function RecipesExtractorMinimapButton:ShowContextMenu()
    if not self.contextMenu then
        self:CreateContextMenu()
    end
    
    ToggleDropDownMenu(1, nil, self.contextMenu, self.button, 0, 0)
end

function RecipesExtractorMinimapButton:CreateContextMenu()
    local menu = CreateFrame("Frame", "RecipesExtractorMinimapContextMenu", UIParent, "UIDropDownMenuTemplate")
    
    UIDropDownMenu_Initialize(menu, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        
        -- Interface principale
        info.text = "Ouvrir l'interface"
        info.func = function()
            RecipesExtractorUI:ToggleMainFrame()
        end
        info.icon = "Interface\\Icons\\INV_Misc_Book_09"
        UIDropDownMenu_AddButton(info)
        
        -- Scan rapide
        info.text = "Scanner les métiers"
        info.func = function()
            RecipesExtractorDataCollector:ScanAllProfessions()
        end
        info.icon = "Interface\\Icons\\INV_Misc_Eye_02"
        UIDropDownMenu_AddButton(info)
        
        -- Export rapide
        info.text = "Export web"
        info.func = function()
            RecipesExtractorUI:ShowExportFrame("web")
        end
        info.icon = "Interface\\Icons\\INV_Misc_Note_01"
        UIDropDownMenu_AddButton(info)
        
        -- Séparateur
        info.text = ""
        info.disabled = true
        info.notCheckable = true
        info.iconOnly = true
        info.icon = nil
        UIDropDownMenu_AddButton(info)
        
        -- Options d'affichage
        info.text = "Masquer le bouton minimap"
        info.disabled = false
        info.func = function()
            RecipesExtractorMinimapButton:ToggleVisibility()
        end
        info.icon = "Interface\\Icons\\INV_Misc_Eye_01"
        UIDropDownMenu_AddButton(info)
        
        -- Réinitialiser position
        info.text = "Réinitialiser la position"
        info.func = function()
            RecipesExtractorMinimapButton:SetPosition(0)
            RecipesExtractorMinimapButton:SavePosition()
        end
        info.icon = "Interface\\Icons\\Ability_Spy"
        UIDropDownMenu_AddButton(info)
        
        -- Aide
        info.text = "Aide"
        info.func = function()
            print("|cff00ff00RecipesExtractor Aide:|r")
            print("  Clic gauche : Ouvrir l'interface")
            print("  Clic droit : Menu contextuel")
            print("  Glisser : Déplacer l'icône")
            print("  /recipes help : Aide complète")
        end
        info.icon = "Interface\\Icons\\INV_Misc_QuestionMark"
        UIDropDownMenu_AddButton(info)
        
    end, "MENU")
    
    self.contextMenu = menu
end

function RecipesExtractorMinimapButton:ToggleVisibility()
    if not self.button then return end
    
    if self.button:IsShown() then
        self.button:Hide()
        if not RecipesExtractorDB.settings then
            RecipesExtractorDB.settings = {}
        end
        RecipesExtractorDB.settings.minimapButtonHidden = true
        print("|cff00ff00RecipesExtractor:|r Bouton minimap masqué. Utilisez '/recipes minimap show' pour le réafficher.")
    else
        self.button:Show()
        RecipesExtractorDB.settings.minimapButtonHidden = false
        print("|cff00ff00RecipesExtractor:|r Bouton minimap affiché.")
    end
end

function RecipesExtractorMinimapButton:SetVisibility(visible)
    if not self.button then return end
    
    if visible then
        self.button:Show()
        if RecipesExtractorDB and RecipesExtractorDB.settings then
            RecipesExtractorDB.settings.minimapButtonHidden = false
        end
    else
        self.button:Hide()
        if RecipesExtractorDB and RecipesExtractorDB.settings then
            RecipesExtractorDB.settings.minimapButtonHidden = true
        end
    end
end

function RecipesExtractorMinimapButton:IsVisible()
    return self.button and self.button:IsShown()
end

function RecipesExtractorMinimapButton:UpdateIcon()
    if not self.button or not self.button.icon then return end
    
    -- Peut être utilisé pour changer l'icône selon l'état
    local stats = RecipesExtractorDataManager:GetStatistics()
    if stats.totalRecipes > 0 then
        -- Icône normale
        self.button.icon:SetTexture("Interface\\AddOns\\RecipesExtractor\\UI\\Icons\\rc32.png")
        self.button.icon:SetDesaturated(false)
    else
        -- Icône grisée si aucune donnée
        self.button.icon:SetTexture("Interface\\AddOns\\RecipesExtractor\\UI\\Icons\\rc32.png")
        self.button.icon:SetDesaturated(true)
    end
end

-- Animation de notification
function RecipesExtractorMinimapButton:ShowNotification()
    if not self.button then return end
    
    -- Animation de pulsation
    local animGroup = self.button:CreateAnimationGroup()
    local scale1 = animGroup:CreateAnimation("Scale")
    scale1:SetScale(1.2, 1.2)
    scale1:SetDuration(0.2)
    scale1:SetOrder(1)
    
    local scale2 = animGroup:CreateAnimation("Scale")
    scale2:SetScale(0.83, 0.83) -- Retour à la taille normale (1/1.2)
    scale2:SetDuration(0.2)
    scale2:SetOrder(2)
    
    animGroup:Play()
    
    -- Effet de brillance temporaire
    if not self.button.flash then
        self.button.flash = self.button:CreateTexture(nil, "OVERLAY")
        self.button.flash:SetSize(32, 32)
        self.button.flash:SetPoint("CENTER")
        self.button.flash:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Flash")
        self.button.flash:SetBlendMode("ADD")
    end
    
    self.button.flash:SetAlpha(0.8)
    UIFrameFadeOut(self.button.flash, 1.0, 0.8, 0)
end

-- Fonction appelée lors du scan de recettes
function RecipesExtractorMinimapButton:OnRecipesScanned()
    self:UpdateIcon()
    self:ShowNotification()
end
