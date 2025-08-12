-- Main UI for AuberdineExporter
AuberdineExporterUI = {}

function AuberdineExporterUI:Initialize()
    self.mainFrame = nil
    self.isInitialized = true
end

function AuberdineExporterUI:CreateMainFrame()
    if self.mainFrame then
        return self.mainFrame
    end
    
    -- Create main frame
    local frame = CreateFrame("Frame", "AuberdineExporterMainFrame", UIParent)
    frame:SetSize(650, 500)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    
    -- Gestion de la touche ESC
    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
        end
    end)
    frame:SetPropagateKeyboardInput(true)
    frame:EnableKeyboard(true)
    
    -- Background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0, 0, 0, 0.8)
    
    -- Border
    frame.border = CreateFrame("Frame", nil, frame, "DialogBorderTemplate")
    
    -- Title bar
    frame.titleBg = frame:CreateTexture(nil, "ARTWORK")
    frame.titleBg:SetPoint("TOPLEFT", 5, -5)
    frame.titleBg:SetPoint("TOPRIGHT", -5, -5)
    frame.titleBg:SetHeight(25)
    frame.titleBg:SetColorTexture(0.2, 0.2, 0.2, 1)
    
    -- Addon icon in title bar
    frame.icon = frame:CreateTexture(nil, "OVERLAY")
    frame.icon:SetSize(16, 16)
    frame.icon:SetPoint("TOPLEFT", 10, -7)
    frame.icon:SetTexture("Interface\\AddOns\\AuberdineExporter\\UI\\Icons\\ab32.png")
    
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 30, -12)  -- Adjusted for icon
    frame.title:SetText("Auberdine Exporter")
    frame.title:SetTextColor(1, 1, 1)
    
    -- Close button
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetPoint("TOPRIGHT", -5, -5)
    frame.closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Export Auberdine button
    local exportBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    exportBtn:SetPoint("TOPLEFT", 30, -50)
    exportBtn:SetSize(140, 25)
    exportBtn:SetText("Export Auberdine")
    exportBtn:SetScript("OnClick", function()
        local jsonData = ExportToJSON()
        CreateExportFrame(jsonData, "Auberdine")
    end)
    
    -- Clear Cache button
    local clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearBtn:SetPoint("TOPLEFT", 180, -50)
    clearBtn:SetSize(140, 25)
    clearBtn:SetText("Supprimer Cache")
    clearBtn:SetScript("OnClick", function()
        StaticPopup_Show("AUBERDINE_EXPORTER_RESET_CONFIRM")
    end)

    -- Export CSV button
    local csvBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    csvBtn:SetPoint("TOPLEFT", 330, -50)
    csvBtn:SetSize(140, 25)
    csvBtn:SetText("Export CSV")
    csvBtn:SetScript("OnClick", function()
        local csvData = ExportToCSV()
        CreateExportFrame(csvData, "CSV")
    end)
    
    -- NOUVEAU v1.3.2b: Bouton Gestion Personnages
    local charConfigBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    charConfigBtn:SetPoint("TOPLEFT", 480, -50)
    charConfigBtn:SetSize(140, 25)
    charConfigBtn:SetText("Gestion Personnages")
    charConfigBtn:SetScript("OnClick", function()
        AuberdineExporterUI:ShowCharacterConfigFrame()
    end)
    
    -- Content area
    frame.content = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.content:SetPoint("TOPLEFT", 10, -85)
    frame.content:SetPoint("BOTTOMRIGHT", -30, 10)
    
    -- Background icon for content area
    frame.contentBg = frame.content:CreateTexture(nil, "BACKGROUND")
    frame.contentBg:SetSize(256, 256)
    frame.contentBg:SetPoint("CENTER", frame.content, "CENTER", 0, 0)
    frame.contentBg:SetTexture("Interface\\AddOns\\AuberdineExporter\\UI\\Icons\\ab256.png")
    frame.contentBg:SetAlpha(0.1) -- Semi-transparent pour ne pas gêner la lecture
    frame.contentBg:SetDesaturated(true) -- Désaturé pour être plus discret
    
    -- Text content
    frame.textContent = CreateFrame("EditBox", nil, frame.content)
    frame.textContent:SetMultiLine(true)
    frame.textContent:SetFontObject("GameFontNormal")
    frame.textContent:SetWidth(550)
    frame.textContent:SetAutoFocus(false)
    frame.textContent:EnableMouse(false)
    frame.content:SetScrollChild(frame.textContent)
    
    -- Update content function
    frame.UpdateContent = function()
        if GetStatistics and AuberdineExporterDB then
            local stats = GetStatistics()
            local currentCharKey = GetCurrentCharacterKey and GetCurrentCharacterKey() or "Unknown"
            local currentCharData = AuberdineExporterDB.characters and AuberdineExporterDB.characters[currentCharKey]
            local currentSettings = InitializeCharacterSettings and InitializeCharacterSettings(currentCharKey) or {}
            
            local text = string.format([[
Auberdine Exporter v1.3.2b - Gestion avancée des personnages

Personnages: %d
Métiers: %d  
Total Recettes: %d

Personnage Actuel: %s (%s)
Type: %s | Groupe: %s | Export: %s

NOUVEAU v1.3.2b:
• Gestion des types de personnages (Main/Alt/Bank/Mule)
• Organisation par groupes de comptes
• Export sélectif des personnages
• Relations main/alt dans les exports

Instructions:
1. Ouvrez les fenêtres de métiers pour scanner automatiquement les recettes
2. Utilisez "Export Auberdine" pour générer un export complet pour auberdine.eu
3. Utilisez "Gestion Personnages" pour configurer vos personnages
4. Utilisez "Export CSV" pour générer un export au format tableur
5. Utilisez "Supprimer Cache" pour effacer toutes les données stockées

Commandes principales:
• /auberdine - Ouvrir cette interface
• /auberdine config - Lister la configuration des personnages
• /auberdine settype <main|alt|bank|mule> - Définir le type du personnage
• /auberdine account <groupe> - Définir le groupe de compte
• /auberdine export <enable|disable> - Activer/désactiver l'export
• /auberdine help - Aide complète
]], 
                stats.totalCharacters, 
                stats.totalProfessions, 
                stats.totalRecipes,
                currentCharData and currentCharData.name or "Inconnu",
                currentCharData and currentCharData.realm or "Inconnu",
                currentSettings.characterType or "main",
                currentSettings.accountGroup or (AuberdineExporterDB.accountGroup or "Groupe-Auto"),
                (currentSettings.exportEnabled ~= false) and "Activé" or "Désactivé"
            )
            
            if stats.totalCharacters > 0 then
                text = text .. "\n\nDétails par personnage:\n"
                for charKey, charData in pairs(AuberdineExporterDB.characters or {}) do
                    local charProfs = 0
                    local charRecipes = 0
                    if charData.professions then
                        for _, profData in pairs(charData.professions) do
                            charProfs = charProfs + 1
                            if profData.recipes then
                                for _ in pairs(profData.recipes) do charRecipes = charRecipes + 1 end
                            end
                        end
                    end
                    text = text .. string.format("• %s: %d métiers, %d recettes\n", 
                        charData.name or charKey, charProfs, charRecipes)
                end
            end
            
            frame.textContent:SetText(text)
        else
            frame.textContent:SetText("AuberdineExporter - Chargement...")
        end
    end
    
    self.mainFrame = frame
    return frame
end

function AuberdineExporterUI:ToggleMainFrame()
    local frame = self:CreateMainFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        frame.UpdateContent()
        frame:Show()
    end
end

function AuberdineExporterUI:CreateMainFrameContent(parent)
    -- Tab buttons
    local tabHeight = 25
    local tabButtons = {}
    local tabs = {
        { name = "Overview", func = "CreateOverviewTab" },
        { name = "Characters", func = "CreateCharactersTab" },
        { name = "Character Config", func = "CreateCharacterConfigTab" },
        { name = "Export", func = "CreateExportTab" },
        { name = "Settings", func = "CreateSettingsTab" }
    }
    
    for i, tab in ipairs(tabs) do
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(90, tabHeight)
        btn:SetPoint("TOPLEFT", (i-1) * 90, 0)
        btn:SetNormalTexture("Interface\\ChatFrame\\ChatFrameTab-BGLeft")
        btn:SetHighlightTexture("Interface\\ChatFrame\\ChatFrameTab-BGLeft")
        
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.text:SetAllPoints()
        btn.text:SetText(tab.name)
        
        btn:SetScript("OnClick", function()
            self:ShowTab(tab.func, tabButtons, i)
        end)
        
        tabButtons[i] = btn
    end
    
    -- Content frame for tabs
    parent.tabContent = CreateFrame("Frame", nil, parent)
    parent.tabContent:SetPoint("TOPLEFT", 0, -tabHeight - 5)
    parent.tabContent:SetPoint("BOTTOMRIGHT", 0, 0)
    
    -- Show overview tab by default
    self:ShowTab("CreateOverviewTab", tabButtons, 1)
end

function AuberdineExporterUI:ShowTab(tabFunction, tabButtons, activeTab)
    local content = self.mainFrame.content.tabContent
    
    -- Clear current content
    if content.currentTab then
        content.currentTab:Hide()
    end
    
    -- Update tab appearance
    for i, btn in ipairs(tabButtons) do
        if i == activeTab then
            btn.text:SetTextColor(1, 1, 1)
        else
            btn.text:SetTextColor(0.7, 0.7, 0.7)
        end
    end
    
    -- Create new tab content
    if self[tabFunction] then
        content.currentTab = self[tabFunction](self, content)
        content.currentTab:Show()
    end
end

function AuberdineExporterUI:CreateOverviewTab(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    
    local stats = GetStatistics and GetStatistics() or {totalCharacters = 0, totalProfessions = 0, totalRecipes = 0}
    
    -- Statistics display
    local yOffset = -10
    
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, yOffset)
    title:SetText("Recipe Collection Overview")
    title:SetTextColor(1, 1, 0)
    yOffset = yOffset - 30
    
    -- Data size information
    if AuberdineExporter and AuberdineExporter.GetDataSizeInfo then
        local totalChars, totalSize, charSizes = AuberdineExporter:GetDataSizeInfo()
        
        local sizeTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        sizeTitle:SetPoint("TOPLEFT", 10, yOffset)
        sizeTitle:SetText("Data Size Information")
        sizeTitle:SetTextColor(1, 0.5, 0)
        yOffset = yOffset - 25
        
        local sizeText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sizeText:SetPoint("TOPLEFT", 10, yOffset)
        sizeText:SetJustifyH("LEFT")
        sizeText:SetText(string.format(
            "Total Characters: %d\nEstimated Data Size: ~%d bytes (~%.1f KB)\n\n" ..
            "Note: Large datasets may cause export issues.\nUse 'Clear Memory Data' to reduce size.",
            totalChars,
            totalSize,
            totalSize / 1024
        ))
        
        -- Color warning if size is large
        if totalSize > 50000 then -- >50KB
            sizeText:SetTextColor(1, 0.3, 0.3) -- Red warning
        elseif totalSize > 25000 then -- >25KB
            sizeText:SetTextColor(1, 0.8, 0.3) -- Orange warning
        else
            sizeText:SetTextColor(0.8, 0.8, 0.8) -- Normal color
        end
        
        yOffset = yOffset - 80
    end
    
    -- Overall stats
    local statsText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsText:SetPoint("TOPLEFT", 10, yOffset)
    statsText:SetJustifyH("LEFT")
    statsText:SetText(string.format(
        "Total Characters: %d\nTotal Professions: %d\nTotal Recipes: %d",
        stats.totalCharacters,
        stats.totalProfessions,
        stats.totalRecipes
    ))
    yOffset = yOffset - 70
    
    -- Profession breakdown
    if stats.totalProfessions > 0 then
        local profTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        profTitle:SetPoint("TOPLEFT", 10, yOffset)
        profTitle:SetText("Profession Breakdown")
        profTitle:SetTextColor(0.5, 1, 0.5)
        yOffset = yOffset - 25
        
        for profName, profStats in pairs(stats.professionBreakdown) do
            local profText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            profText:SetPoint("TOPLEFT", 20, yOffset)
            profText:SetText(string.format(
                "%s: %d characters, %d recipes (avg level: %d)",
                profName,
                profStats.characters,
                profStats.totalRecipes,
                profStats.averageLevel
            ))
            yOffset = yOffset - 15
        end
    end
    
    -- Instructions
    yOffset = yOffset - 20
    local instructTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    instructTitle:SetPoint("TOPLEFT", 10, yOffset)
    instructTitle:SetText("How to Use")
    instructTitle:SetTextColor(1, 0.8, 0)
    yOffset = yOffset - 25
    
    local instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    instructions:SetPoint("TOPLEFT", 20, yOffset)
    instructions:SetPoint("TOPRIGHT", -20, yOffset)
    instructions:SetJustifyH("LEFT")
    instructions:SetText(
        "1. Open your profession windows (Blacksmithing, Tailoring, etc.)\n" ..
        "2. The addon will automatically scan and save your recipes\n" ..
        "3. Use the Export tab to generate data for web integration\n" ..
        "4. Use /auberdine scan to manually scan all professions\n" ..
        "5. Use /auberdine clear to reduce data size (keeps current character)\n" ..
        "6. Use /auberdine reset to clear all data\n" ..
        "7. Click the minimap button for quick access"
    )
    
    return frame
end

function AuberdineExporterUI:CreateCharactersTab(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    
    -- Create scroll frame for character list
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(content)
    content:SetWidth(scrollFrame:GetWidth())
    
    local allRecipes = AuberdineExporterDB and AuberdineExporterDB.characters or {}
    local yOffset = 0
    local rowHeight = 80
    
    for charKey, characterData in pairs(allRecipes) do
        local char = characterData
        
        -- Character frame
        local charFrame = CreateFrame("Frame", nil, content)
        charFrame:SetPoint("TOPLEFT", 0, yOffset)
        charFrame:SetPoint("TOPRIGHT", 0, yOffset)
        charFrame:SetHeight(rowHeight)
        
        -- Background
        charFrame.bg = charFrame:CreateTexture(nil, "BACKGROUND")
        charFrame.bg:SetAllPoints()
        charFrame.bg:SetColorTexture(0.1, 0.1, 0.1, 0.5)
        
        -- Character info
        local charName = charFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        charName:SetPoint("TOPLEFT", 10, -5)
        charName:SetText(char.name .. " (" .. char.realm .. ")")
        charName:SetTextColor(1, 1, 1)
        
        local charDetails = charFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        charDetails:SetPoint("TOPLEFT", 10, -25)
        charDetails:SetText(string.format("Level %d %s %s", char.level, char.race, char.class))
        charDetails:SetTextColor(0.8, 0.8, 0.8)
        
        local lastUpdate = charFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lastUpdate:SetPoint("TOPLEFT", 10, -45)
        lastUpdate:SetText("Last update: " .. date("%Y-%m-%d %H:%M", char.lastUpdate))
        lastUpdate:SetTextColor(0.6, 0.6, 0.6)
        
        -- Professions info
        local profText = ""
        local profCount = 0
        for profName, profData in pairs(characterData.professions or {}) do
            profCount = profCount + 1
            local recipeCount = 0
            for _ in pairs(profData.recipes or {}) do
                recipeCount = recipeCount + 1
            end
            
            if profText ~= "" then
                profText = profText .. ", "
            end
            profText = profText .. string.format("%s (%d/%d, %d recipes)", 
                profName, profData.level or 0, profData.maxLevel or 0, recipeCount)
        end
        
        if profCount > 0 then
            local professions = charFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            professions:SetPoint("TOPLEFT", 200, -5)
            professions:SetPoint("TOPRIGHT", -10, -5)
            professions:SetJustifyH("LEFT")
            professions:SetText("Professions: " .. profText)
            professions:SetTextColor(0.5, 1, 0.5)
        end
        
        yOffset = yOffset - rowHeight - 5
    end
    
    content:SetHeight(math.abs(yOffset))
    
    return frame
end

function AuberdineExporterUI:CreateCharacterConfigTab(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    
    -- Titre
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText("Gestion des Personnages (v1.3.2b)")
    title:SetTextColor(1, 1, 0)
    
    -- Instructions
    local instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instructions:SetPoint("TOPLEFT", 10, -35)
    instructions:SetPoint("TOPRIGHT", -10, -35)
    instructions:SetJustifyH("LEFT")
    instructions:SetText("Cliquez sur les cartes pour configurer vos personnages. Utilisez les boutons en bas pour les actions.")
    instructions:SetTextColor(0.8, 0.8, 0.8)
    
    -- Schéma de tous les personnages
    if not AuberdineExporterDB or not AuberdineExporterDB.characters then
        local noDataText = scrollFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noDataText:SetPoint("CENTER", scrollFrame, "CENTER", 0, 0)
        noDataText:SetText("Aucune donnée de personnage disponible")
        noDataText:SetTextColor(1, 0.5, 0.5)
        return
    end
    
    -- Générer le schéma des cartes personnages dans scrollFrame
    AuberdineExporterUI:GenerateCharacterCards(scrollFrame)
    
    return frame
end

function AuberdineExporterUI:CreateExportTab(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    
    -- Export buttons
    local yOffset = -10
    
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, yOffset)
    title:SetText("Export Data")
    title:SetTextColor(1, 1, 0)
    yOffset = yOffset - 40
    
    -- JSON Export button
    local jsonBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    jsonBtn:SetPoint("TOPLEFT", 10, yOffset)
    jsonBtn:SetSize(150, 25)
    jsonBtn:SetText("Export as JSON")
    jsonBtn:SetScript("OnClick", function()
        self:ShowExportFrame("json")
    end)
    
    -- CSV Export button
    local csvBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    csvBtn:SetPoint("TOPLEFT", 170, yOffset)
    csvBtn:SetSize(150, 25)
    csvBtn:SetText("Export as CSV")
    csvBtn:SetScript("OnClick", function()
        self:ShowExportFrame("csv")
    end)
    
    -- Web Export button
    local webBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    webBtn:SetPoint("TOPLEFT", 330, yOffset)
    webBtn:SetSize(150, 25)
    webBtn:SetText("Export for Web")
    webBtn:SetScript("OnClick", function()
        self:ShowExportFrame("web")
    end)
    
    yOffset = yOffset - 40
    
    -- Instructions
    local instructText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instructText:SetPoint("TOPLEFT", 10, yOffset)
    instructText:SetPoint("TOPRIGHT", -10, yOffset)
    instructText:SetJustifyH("LEFT")
    instructText:SetText(
        "Export formats:\n\n" ..
        "• JSON: Complete data export with all details\n" ..
        "• CSV: Spreadsheet-compatible format\n" ..
        "• Web: Optimized format for web integration\n\n" ..
        "Click any export button to generate and display the data for copying."
    )
    
    return frame
end

function AuberdineExporterUI:CreateSettingsTab(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    
    local settings = AuberdineExporterDB and AuberdineExporterDB.settings or {
        autoScan = true,
        shareData = true,
        minimapButtonHidden = false
    }
    local yOffset = -10
    
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, yOffset)
    title:SetText("Settings")
    title:SetTextColor(1, 1, 0)
    yOffset = yOffset - 40
    
    -- Auto-scan setting
    local autoScanCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    autoScanCheck:SetPoint("TOPLEFT", 10, yOffset)
    autoScanCheck:SetChecked(settings.autoScan)
    autoScanCheck.text:SetText("Auto-scan professions when opened")
    autoScanCheck:SetScript("OnClick", function(self)
        if AuberdineExporterDB and AuberdineExporterDB.settings then
            AuberdineExporterDB.settings.autoScan = self:GetChecked()
        end
    end)
    
    yOffset = yOffset - 30
    
    -- Share data setting
    local shareDataCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    shareDataCheck:SetPoint("TOPLEFT", 10, yOffset)
    shareDataCheck:SetChecked(settings.shareData)
    shareDataCheck.text:SetText("Share data between characters")
    shareDataCheck:SetScript("OnClick", function(self)
        if AuberdineExporterDB and AuberdineExporterDB.settings then
            AuberdineExporterDB.settings.shareData = self:GetChecked()
        end
    end)
    
    yOffset = yOffset - 30
    
    -- Minimap button setting
    local minimapCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", 10, yOffset)
    minimapCheck:SetChecked(not settings.minimapButtonHidden)
    minimapCheck.text:SetText("Show minimap button")
    minimapCheck:SetScript("OnClick", function(self)
        local show = self:GetChecked()
        if AuberdineExporterDB and AuberdineExporterDB.settings then
            AuberdineExporterDB.settings.minimapButtonHidden = not show
        end
        if AuberdineMinimapButton and AuberdineMinimapButton.SetVisibility then
            AuberdineMinimapButton:SetVisibility(show)
        end
    end)
    
    yOffset = yOffset - 50
    
    -- Reset button
    local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", 10, yOffset)
    resetBtn:SetSize(150, 25)
    resetBtn:SetText("Reset All Data")
    resetBtn:SetScript("OnClick", function()
        StaticPopup_Show("AUBERDINE_EXPORTER_RESET_CONFIRM")
    end)
    
    -- Clear Memory Data button
    local clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearBtn:SetPoint("TOPLEFT", 170, yOffset)
    clearBtn:SetSize(180, 25)
    clearBtn:SetText("Clear Memory Data")
    clearBtn:SetScript("OnClick", function()
        StaticPopup_Show("AUBERDINE_EXPORTER_CLEAR_CONFIRM")
    end)
    
    yOffset = yOffset - 40
    
    yOffset = yOffset - 40
    
    -- Data size info
    local sizeInfoBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    sizeInfoBtn:SetPoint("TOPLEFT", 10, yOffset)
    sizeInfoBtn:SetSize(180, 25)
    sizeInfoBtn:SetText("Show Data Size Info")
    sizeInfoBtn:SetScript("OnClick", function()
        if AuberdineExporter and AuberdineExporter.GetDataSizeInfo then
            local totalChars, totalSize, charSizes = AuberdineExporter:GetDataSizeInfo()
            print(string.format("|cff00ff00AuberdineExporter:|r Data size info: %d characters, ~%d bytes total (~%.1f KB)", 
                totalChars, totalSize, totalSize / 1024))
            
            for charKey, size in pairs(charSizes) do
                print(string.format("  %s: ~%d bytes (~%.1f KB)", charKey, size, size / 1024))
            end
        else
            print("|cffff0000AuberdineExporter:|r Size function not available!")
        end
    end)
    
    -- Minimap button reset
    local resetMinimapBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetMinimapBtn:SetPoint("TOPLEFT", 200, yOffset)
    resetMinimapBtn:SetSize(180, 25)
    resetMinimapBtn:SetText("Reset Minimap Position")
    resetMinimapBtn:SetScript("OnClick", function()
        if AuberdineMinimapButton and AuberdineMinimapButton.SetPosition then
            AuberdineMinimapButton:SetPosition(0)
            AuberdineMinimapButton:SavePosition()
            print("|cff00ff00AuberdineExporter:|r Position du bouton minimap réinitialisée.")
        end
    end)
    
    return frame
end

function AuberdineExporterUI:ToggleMainFrame()
    local frame = self:CreateMainFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        frame.UpdateContent()
        frame:Show()
    end
end

function AuberdineExporterUI:ShowExportFrame(exportType)
    AuberdineExportUI:ShowExportFrame(exportType)
end

-- Static popup pour éditer le groupe d'un personnage
StaticPopupDialogs["AUBERDINE_EDIT_GROUP"] = {
    text = "Changer le groupe de %s\nGroupe actuel: %s",
    button1 = "Valider",
    button2 = "Annuler",
    hasEditBox = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    -- Forcer un niveau plus élevé pour passer devant la fenêtre de config
    OnShow = function(self, data)
        -- Ajuster les niveaux d'affichage
        self:SetFrameStrata("TOOLTIP")
        self:SetFrameLevel(200)
        
        -- data est maintenant une table {charKey = "...", currentGroup = "..."}
        if data and data.currentGroup then
            self.editBox:SetText(data.currentGroup)
            self.editBox:HighlightText()
        else
            self.editBox:SetText("")
        end
    end,
    OnAccept = function(self, data)
        local newGroup = self.editBox:GetText()
        if newGroup and newGroup ~= "" and data and data.charKey then
            if SetAccountGroup then
                SetAccountGroup(data.charKey, newGroup)
                print(string.format("|cff00ff00AuberdineExporter:|r Groupe de %s changé vers '%s'", 
                    AuberdineExporterDB.characters[data.charKey] and AuberdineExporterDB.characters[data.charKey].name or data.charKey, newGroup))
                -- Recharger l'interface
                if AuberdineExporterUI.charConfigFrame then
                    AuberdineExporterUI.charConfigFrame:Hide()
                    AuberdineExporterUI:ShowCharacterConfigFrame()
                end
            end
        end
    end,
    EditBoxOnEnterPressed = function(self, data)
        StaticPopup_OnClick(self:GetParent(), 1)
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    preferredIndex = 3,
}

-- Static popup pour l'aide
StaticPopupDialogs["AUBERDINE_HELP_POPUP"] = {
    text = "AIDE - Configuration des Personnages\n\n" ..
           "Types de personnages :\n" ..
           "• Main (Bleu) : Personnage principal\n" ..
           "• Alt (Violet) : Personnage alternatif\n" ..
           "• Banque (Or) : Personnage de stockage\n" ..
           "• Mule (Cuivre) : Personnage de transport\n\n" ..
           "Fonctionnalités :\n" ..
           "• Cliquez sur les dropdowns pour changer le type\n" ..
           "• Les connexions montrent la hiérarchie\n" ..
           "• L'icône en haut à droite active/désactive l'export\n" ..
           "• Utilisez 'Actualiser' après modifications",
    button1 = "Compris",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    -- Forcer un niveau plus élevé pour passer devant la fenêtre de config
    OnShow = function(self)
        self:SetFrameStrata("TOOLTIP")
        self:SetFrameLevel(200)
    end,
}

-- Static popup for reset confirmation
StaticPopupDialogs["AUBERDINE_EXPORTER_RESET_CONFIRM"] = {
    text = "Êtes-vous sûr de vouloir réinitialiser toutes les données AuberdineExporter ? Cette action ne peut pas être annulée !",
    button1 = "Oui",
    button2 = "Non",
    OnAccept = function()
        if AuberdineExporter and AuberdineExporter.ResetAllData then
            AuberdineExporter:ResetAllData()
        else
            -- Fallback reset method
            if not AuberdineExporterDB or type(AuberdineExporterDB) ~= "table" then
                AuberdineExporterDB = {}
            end
            AuberdineExporterDB.characters = {}
            print("|cff00ff00AuberdineExporter:|r Toutes les données ont été réinitialisées !")
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Static popup for clear memory confirmation
StaticPopupDialogs["AUBERDINE_EXPORTER_CLEAR_CONFIRM"] = {
    text = "Vider les données mémoire pour réduire la taille de l'export ?\n\nCeci supprimera les données des anciennes sessions mais gardera les données du personnage actuel.",
    button1 = "Vider",
    button2 = "Annuler",
    OnAccept = function()
        if AuberdineExporter and AuberdineExporter.ClearMemoryData then
            AuberdineExporter:ClearMemoryData()
        else
            print("|cffff0000AuberdineExporter:|r Fonction de vidage non disponible !")
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- NOUVEAU v1.3.2b: Fenêtre de gestion des personnages
function AuberdineExporterUI:ShowGroupEditPopup(charKey, currentGroup)
    -- Créer une table avec les données nécessaires
    local popupData = {
        charKey = charKey,
        currentGroup = currentGroup or "Groupe-Auto"
    }
    
    -- Obtenir le nom du personnage pour l'affichage
    local charName = "Inconnu"
    if AuberdineExporterDB and AuberdineExporterDB.characters and AuberdineExporterDB.characters[charKey] then
        charName = AuberdineExporterDB.characters[charKey].name
    end
    
    -- Afficher la popup avec le nom du personnage et le groupe actuel dans le texte
    StaticPopup_Show("AUBERDINE_EDIT_GROUP", charName, popupData.currentGroup, popupData)
end

function AuberdineExporterUI:ShowHelpPopup()
    StaticPopup_Show("AUBERDINE_HELP_POPUP")
end

function AuberdineExporterUI:ShowCharacterConfigFrame()
    -- Fermer la fenêtre principale pour éviter les superpositions
    if self.mainFrame and self.mainFrame:IsShown() then
        self.mainFrame:Hide()
    end
    
    if self.charConfigFrame then
        if self.charConfigFrame:IsShown() then
            self.charConfigFrame:Hide()
            -- Rouvrir la fenêtre principale
            if self.mainFrame then
                self.mainFrame:Show()
            end
            return
        else
            self.charConfigFrame:Show()
            return
        end
    end
    
    -- Créer la fenêtre de gestion des personnages
    local frame = CreateFrame("Frame", "AuberdineCharacterConfigFrame", UIParent)
    frame:SetSize(900, 650)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")  -- Plus haut niveau
    frame:SetFrameLevel(100)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    -- Gestion de la touche ESC
    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
            if AuberdineExporterUI.mainFrame then
                AuberdineExporterUI.mainFrame:Show()
            end
        end
    end)
    frame:SetPropagateKeyboardInput(true)
    frame:EnableKeyboard(true)
    
    -- Background opaque
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0, 0, 0, 0.95)  -- Plus opaque
    
    -- Border
    frame.border = CreateFrame("Frame", nil, frame, "DialogBorderTemplate")
    
    -- Title bar
    frame.titleBg = frame:CreateTexture(nil, "ARTWORK")
    frame.titleBg:SetPoint("TOPLEFT", 5, -5)
    frame.titleBg:SetPoint("TOPRIGHT", -5, -5)
    frame.titleBg:SetHeight(25)
    frame.titleBg:SetColorTexture(0.2, 0.2, 0.2, 1)
    
    -- Addon icon in title bar
    frame.icon = frame:CreateTexture(nil, "OVERLAY")
    frame.icon:SetSize(16, 16)
    frame.icon:SetPoint("TOPLEFT", 10, -7)
    frame.icon:SetTexture("Interface\\AddOns\\AuberdineExporter\\UI\\Icons\\ab32.png")
    
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 30, -12)
    frame.title:SetText("Famille d'Auberdine v1.3.2b")
    frame.title:SetTextColor(1, 1, 1)
    
    -- Close button
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetPoint("TOPRIGHT", -5, -5)
    frame.closeBtn:SetScript("OnClick", function() 
        frame:Hide()
        -- Rouvrir la fenêtre principale
        if AuberdineExporterUI.mainFrame then
            AuberdineExporterUI.mainFrame:Show()
        end
    end)
    
    -- Content area
    self:CreateCharacterConfigContent(frame)
    
    self.charConfigFrame = frame
    frame:Show()
end

function AuberdineExporterUI:CreateCharacterConfigContent(frame)
    local yOffset = -40
    
    -- Titre principal seulement (libérer l'espace)
    local instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    instructions:SetPoint("TOPLEFT", 20, yOffset)
    instructions:SetText("Structure familliale")
    instructions:SetTextColor(1, 1, 0)
    
    yOffset = yOffset - 35
    
    -- Zone de scroll MAXIMISÉE pour l'affichage graphique des cartes
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)  -- Supprimé le template pour faire nos propres barres
    scrollFrame:SetPoint("TOPLEFT", 20, yOffset)
    scrollFrame:SetPoint("BOTTOMRIGHT", -40, 140)  -- Ajusté pour les barres plus fines
    
    -- Ajouter le support de la molette avec Shift pour horizontal
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        if IsShiftKeyDown() then
            -- Scroll horizontal avec Shift
            local currentH = self:GetHorizontalScroll()
            local maxScrollH = self:GetHorizontalScrollRange()
            local newScrollH = math.max(0, math.min(maxScrollH, currentH - (delta * 50)))
            self:SetHorizontalScroll(newScrollH)
        else
            -- Scroll vertical normal
            local current = self:GetVerticalScroll()
            local maxScroll = self:GetVerticalScrollRange()
            local newScroll = math.max(0, math.min(maxScroll, current - (delta * 50)))
            self:SetVerticalScroll(newScroll)
        end
    end)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(content)
    -- content:SetWidth(scrollFrame:GetWidth()) -- Supprimé pour permettre scroll horizontal
    
    -- BARRES DE SCROLL MANUELLES IDENTIQUES
    
    -- BARRE DE SCROLL VERTICALE MANUELLE
    local vScrollBar = CreateFrame("Frame", nil, frame)
    vScrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 16, 0)
    vScrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 16, 20)
    vScrollBar:SetWidth(12)  -- Plus fine
    
    -- Background de la barre verticale
    vScrollBar.bg = vScrollBar:CreateTexture(nil, "BACKGROUND")
    vScrollBar.bg:SetAllPoints()
    vScrollBar.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    
    -- Curseur de la barre verticale
    vScrollBar.thumb = CreateFrame("Button", nil, vScrollBar)
    vScrollBar.thumb:SetWidth(10)  -- Plus fin
    vScrollBar.thumb:SetHeight(30)  -- Légèrement plus petit
    vScrollBar.thumb:SetPoint("TOP", 0, -1)
    
    vScrollBar.thumb.bg = vScrollBar.thumb:CreateTexture(nil, "ARTWORK")
    vScrollBar.thumb.bg:SetAllPoints()
    vScrollBar.thumb.bg:SetColorTexture(0.6, 0.6, 0.6, 1)
    
    vScrollBar.thumb.bgHighlight = vScrollBar.thumb:CreateTexture(nil, "HIGHLIGHT")
    vScrollBar.thumb.bgHighlight:SetAllPoints()
    vScrollBar.thumb.bgHighlight:SetColorTexture(0.8, 0.8, 0.8, 1)
    
    -- Fonction de mise à jour du scroll vertical
    local function UpdateVerticalScrollBar()
        local maxScroll = scrollFrame:GetVerticalScrollRange()
        local currentScroll = scrollFrame:GetVerticalScroll()
        
        if maxScroll > 0 then
            vScrollBar:Show()
            local barHeight = vScrollBar:GetHeight() - 2
            local thumbHeight = math.max(20, barHeight * (scrollFrame:GetHeight() / (scrollFrame:GetHeight() + maxScroll)))
            local thumbPos = (currentScroll / maxScroll) * (barHeight - thumbHeight)
            
            vScrollBar.thumb:SetHeight(thumbHeight)
            vScrollBar.thumb:SetPoint("TOP", 0, -1 - thumbPos)
        else
            vScrollBar:Hide()
        end
    end
    
    -- Drag du curseur vertical
    vScrollBar.thumb:EnableMouse(true)
    vScrollBar.thumb:RegisterForDrag("LeftButton")
    vScrollBar.thumb:SetScript("OnDragStart", function(self)
        self.isDragging = true
        self.startY = select(2, GetCursorPosition())
        self.startScroll = scrollFrame:GetVerticalScroll()
    end)
    
    vScrollBar.thumb:SetScript("OnDragStop", function(self)
        self.isDragging = false
    end)
    
    vScrollBar.thumb:SetScript("OnUpdate", function(self)
        if self.isDragging then
            local currentY = select(2, GetCursorPosition())
            local deltaY = self.startY - currentY  -- Inversé pour WoW
            local barHeight = vScrollBar:GetHeight() - 2
            local maxScroll = scrollFrame:GetVerticalScrollRange()
            
            if maxScroll > 0 then
                local thumbHeight = vScrollBar.thumb:GetHeight()
                local scrollDelta = (deltaY / (barHeight - thumbHeight)) * maxScroll
                local newScroll = math.max(0, math.min(maxScroll, self.startScroll + scrollDelta))
                scrollFrame:SetVerticalScroll(newScroll)
                UpdateVerticalScrollBar()
            end
        end
    end)
    
    -- Clic sur la barre verticale pour sauter à une position
    vScrollBar:EnableMouse(true)
    vScrollBar:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            local cursorY = select(2, GetCursorPosition())
            local barTop = self:GetTop() * self:GetEffectiveScale()
            local barHeight = self:GetHeight() * self:GetEffectiveScale()
            local clickPos = (barTop - cursorY) / barHeight
            
            local maxScroll = scrollFrame:GetVerticalScrollRange()
            local newScroll = math.max(0, math.min(maxScroll, clickPos * maxScroll))
            scrollFrame:SetVerticalScroll(newScroll)
            UpdateVerticalScrollBar()
        end
    end)
    
    -- BARRE DE SCROLL HORIZONTALE MANUELLE
    -- Créer la barre de scroll horizontale
    local hScrollBar = CreateFrame("Frame", nil, frame)
    hScrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMLEFT", 0, -16)
    hScrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", -16, -16)
    hScrollBar:SetHeight(12)  -- Plus fine
    
    -- Background de la barre
    hScrollBar.bg = hScrollBar:CreateTexture(nil, "BACKGROUND")
    hScrollBar.bg:SetAllPoints()
    hScrollBar.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    
    -- Curseur de la barre
    hScrollBar.thumb = CreateFrame("Button", nil, hScrollBar)
    hScrollBar.thumb:SetHeight(10)  -- Plus fin
    hScrollBar.thumb:SetWidth(30)   -- Légèrement plus petit
    hScrollBar.thumb:SetPoint("LEFT", 1, 0)
    
    hScrollBar.thumb.bg = hScrollBar.thumb:CreateTexture(nil, "ARTWORK")
    hScrollBar.thumb.bg:SetAllPoints()
    hScrollBar.thumb.bg:SetColorTexture(0.6, 0.6, 0.6, 1)
    
    hScrollBar.thumb.bgHighlight = hScrollBar.thumb:CreateTexture(nil, "HIGHLIGHT")
    hScrollBar.thumb.bgHighlight:SetAllPoints()
    hScrollBar.thumb.bgHighlight:SetColorTexture(0.8, 0.8, 0.8, 1)
    
    -- Fonction de mise à jour du scroll horizontal
    local function UpdateHorizontalScrollBar()
        local maxScroll = scrollFrame:GetHorizontalScrollRange()
        local currentScroll = scrollFrame:GetHorizontalScroll()
        
        if maxScroll > 0 then
            hScrollBar:Show()
            local barWidth = hScrollBar:GetWidth() - 2
            local thumbWidth = math.max(20, barWidth * (scrollFrame:GetWidth() / (scrollFrame:GetWidth() + maxScroll)))
            local thumbPos = (currentScroll / maxScroll) * (barWidth - thumbWidth)
            
            hScrollBar.thumb:SetWidth(thumbWidth)
            hScrollBar.thumb:SetPoint("LEFT", 1 + thumbPos, 0)
        else
            hScrollBar:Hide()
        end
    end
    
    -- Drag du curseur horizontal
    hScrollBar.thumb:EnableMouse(true)
    hScrollBar.thumb:RegisterForDrag("LeftButton")
    hScrollBar.thumb:SetScript("OnDragStart", function(self)
        self.isDragging = true
        self.startX = GetCursorPosition()
        self.startScroll = scrollFrame:GetHorizontalScroll()
    end)
    
    hScrollBar.thumb:SetScript("OnDragStop", function(self)
        self.isDragging = false
    end)
    
    hScrollBar.thumb:SetScript("OnUpdate", function(self)
        if self.isDragging then
            local currentX = GetCursorPosition()
            local deltaX = currentX - self.startX
            local barWidth = hScrollBar:GetWidth() - 2
            local maxScroll = scrollFrame:GetHorizontalScrollRange()
            
            if maxScroll > 0 then
                local thumbWidth = hScrollBar.thumb:GetWidth()
                local scrollDelta = (deltaX / (barWidth - thumbWidth)) * maxScroll
                local newScroll = math.max(0, math.min(maxScroll, self.startScroll + scrollDelta))
                scrollFrame:SetHorizontalScroll(newScroll)
                UpdateHorizontalScrollBar()
            end
        end
    end)
    
    -- Clic sur la barre pour sauter à une position
    hScrollBar:EnableMouse(true)
    hScrollBar:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            local cursorX = GetCursorPosition()
            local barLeft = self:GetLeft() * self:GetEffectiveScale()
            local barWidth = self:GetWidth() * self:GetEffectiveScale()
            local clickPos = (cursorX - barLeft) / barWidth
            
            local maxScroll = scrollFrame:GetHorizontalScrollRange()
            local newScroll = math.max(0, math.min(maxScroll, clickPos * maxScroll))
            scrollFrame:SetHorizontalScroll(newScroll)
            UpdateHorizontalScrollBar()
        end
    end)
    
    -- Mettre à jour les barres quand le contenu change
    scrollFrame:SetScript("OnScrollRangeChanged", function()
        UpdateVerticalScrollBar()
        UpdateHorizontalScrollBar()
    end)
    scrollFrame:SetScript("OnVerticalScroll", UpdateVerticalScrollBar)
    scrollFrame:SetScript("OnHorizontalScroll", UpdateHorizontalScrollBar)
    
    -- Créer l'affichage graphique des personnages
    self:CreateCharacterCardLayout(content, frame)
    
    -- SECTION INFOS/CONTRÔLES EN BAS (tout regroupé)
    local bottomFrame = CreateFrame("Frame", nil, frame)
    bottomFrame:SetPoint("BOTTOMLEFT", 20, 20)
    bottomFrame:SetPoint("BOTTOMRIGHT", -20, 20)
    bottomFrame:SetHeight(100)
    
    -- Background pour la section infos
    bottomFrame.bg = bottomFrame:CreateTexture(nil, "BACKGROUND")
    bottomFrame.bg:SetAllPoints()
    bottomFrame.bg:SetColorTexture(0.1, 0.1, 0.1, 0.4)
    
    -- Ligne de séparation
    local separator = bottomFrame:CreateTexture(nil, "ARTWORK")
    separator:SetPoint("TOPLEFT", 5, -5)
    separator:SetPoint("TOPRIGHT", -5, -5)
    separator:SetHeight(2)
    separator:SetColorTexture(0.5, 0.5, 0.5, 1)
    
    -- PREMIÈRE LIGNE: Légende des couleurs
    local legendText = bottomFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    legendText:SetPoint("TOPLEFT", 10, -15)
    legendText:SetText("Couleurs:")
    legendText:SetTextColor(1, 1, 1)
    
    -- Échantillons de couleur compacts
    local typeLabels = {
        {type = "Main", color = {0.1, 0.4, 0.7}, x = 60},
        {type = "Alt", color = {0.6, 0.3, 0.8}, x = 120},
        {type = "Banque", color = {0.8, 0.6, 0.1}, x = 180},
        {type = "Mule", color = {0.7, 0.4, 0.2}, x = 250}
    }
    
    for _, typeInfo in ipairs(typeLabels) do
        local colorSample = bottomFrame:CreateTexture(nil, "ARTWORK")
        colorSample:SetSize(10, 10)
        colorSample:SetPoint("TOPLEFT", typeInfo.x, -18)
        colorSample:SetColorTexture(typeInfo.color[1], typeInfo.color[2], typeInfo.color[3], 1)
        
        local typeText = bottomFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        typeText:SetPoint("TOPLEFT", typeInfo.x + 12, -15)
        typeText:SetText(typeInfo.type)
        typeText:SetTextColor(0.9, 0.9, 0.9)
    end
    
    -- DEUXIÈME LIGNE: Clé de compte et infos
    local accountKey = "AB-????-????"
    if AuberdineExporter and AuberdineExporter.GetOrCreateAccountKey then
        accountKey = AuberdineExporter:GetOrCreateAccountKey()
    end
    local accountKeyText = bottomFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    accountKeyText:SetPoint("TOPLEFT", 10, -35)
    accountKeyText:SetText("ID Compte: " .. accountKey)
    accountKeyText:SetTextColor(0.7, 0.7, 0.7)
    
    -- Aide sur les connexions
    local connectionText = bottomFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    connectionText:SetPoint("TOPLEFT", 200, -35)
    connectionText:SetText("Lignes = hiérarchie | Coin = export ON/OFF | Clic groupe = éditer")
    connectionText:SetTextColor(0.7, 0.7, 0.7)
    
    -- TROISIÈME LIGNE: Boutons
    local helpBtn = CreateFrame("Button", nil, bottomFrame, "UIPanelButtonTemplate")
    helpBtn:SetPoint("TOPLEFT", 10, -55)
    helpBtn:SetSize(60, 25)
    helpBtn:SetText("Aide")
    helpBtn:SetScript("OnClick", function()
        AuberdineExporterUI:ShowHelpPopup()
    end)
    
    local refreshBtn = CreateFrame("Button", nil, bottomFrame, "UIPanelButtonTemplate")
    refreshBtn:SetPoint("TOPLEFT", 80, -55)
    refreshBtn:SetSize(80, 25)
    refreshBtn:SetText("Actualiser")
    refreshBtn:SetScript("OnClick", function()
        -- Forcer la fermeture complète et recréation
        if AuberdineExporterUI.charConfigFrame then
            AuberdineExporterUI.charConfigFrame:Hide()
            AuberdineExporterUI.charConfigFrame = nil
        end
        -- Force le rechargement immédiat
        AuberdineExporterUI:ShowCharacterConfigFrame()
        print("Interface des personnages actualisée!")
    end)
    
    local closeBtn = CreateFrame("Button", nil, bottomFrame, "UIPanelButtonTemplate")
    closeBtn:SetPoint("TOPRIGHT", -10, -55)
    closeBtn:SetSize(80, 25)
    closeBtn:SetText("Fermer")
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
        if AuberdineExporterUI.mainFrame then
            AuberdineExporterUI.mainFrame:Show()
        end
    end)
    
    return frame
end

-- NOUVEAU: Fonction pour créer l'affichage graphique en cartes
function AuberdineExporterUI:GenerateCharacterCards(scrollFrame)
    -- Créer le content frame pour le scrollFrame
    local content = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(content)
    content:SetWidth(scrollFrame:GetWidth())
    
    -- Nettoyer le contenu existant
    local children = {content:GetChildren()}
    for _, child in pairs(children) do
        child:Hide()
        child:SetParent(nil)
    end
    
    -- Appeler la fonction de génération des cartes existante
    self:CreateCharacterCardLayout(content, scrollFrame:GetParent())
end

function AuberdineExporterUI:CreateCharacterCardLayout(content, parentFrame)
    if not AuberdineExporterDB or not AuberdineExporterDB.characters then
        local noCharsText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        noCharsText:SetPoint("CENTER", content, "CENTER", 0, 0)
        noCharsText:SetText("Aucun personnage scanné")
        noCharsText:SetTextColor(0.7, 0.7, 0.7)
        content:SetHeight(100)
        return
    end
    
    -- Organiser les personnages par type
    local mainCharacters = {}
    local altCharacters = {}
    local bankCharacters = {}
    local unknownCharacters = {}
    
    for charKey, charData in pairs(AuberdineExporterDB.characters) do
        local charSettings = InitializeCharacterSettings and InitializeCharacterSettings(charKey) or {}
        local charType = charSettings.characterType or "main"
        
        local charInfo = {
            key = charKey,
            data = charData,
            settings = charSettings,
            type = charType
        }
        
        if charType == "main" then
            table.insert(mainCharacters, charInfo)
        elseif charType == "alt" then
            table.insert(altCharacters, charInfo)
        elseif charType == "bank" or charType == "mule" then
            table.insert(bankCharacters, charInfo)
        else
            table.insert(unknownCharacters, charInfo)
        end
    end
    
    -- Dimensions des cartes (réduites)
    local cardWidth = 140
    local cardHeight = 80
    local cardSpacing = 15
    local levelSpacing = 100
    
    local currentY = -20
    local maxWidth = 0
    
    -- Fonction pour créer une carte de personnage
    local function CreateCharacterCard(parent, charInfo, x, y)
        local card = CreateFrame("Frame", nil, parent)
        card:SetSize(cardWidth, cardHeight)
        card:SetPoint("TOPLEFT", x, y)
        
        -- Couleurs selon le type (améliorées)
        local typeColors = {
            main = {0.1, 0.4, 0.7, 0.8},     -- Bleu professionnel
            alt = {0.6, 0.3, 0.8, 0.8},      -- Violet pour alt
            bank = {0.8, 0.6, 0.1, 0.8},     -- Or pour banque
            mule = {0.7, 0.4, 0.2, 0.8}      -- Cuivre pour mule
        }
        
        local color = typeColors[charInfo.type] or {0.5, 0.5, 0.5, 0.8}
        
        -- Background de la carte avec gradient
        card.bg = card:CreateTexture(nil, "BACKGROUND")
        card.bg:SetAllPoints()
        card.bg:SetColorTexture(color[1], color[2], color[3], color[4])
        
        -- Bordure simple compatible WoW Classic Era
        card.border = CreateFrame("Frame", nil, card)
        card.border:SetAllPoints()
        
        -- Créer une bordure simple avec des textures
        card.borderTop = card.border:CreateTexture(nil, "OVERLAY")
        card.borderTop:SetPoint("TOPLEFT", 0, 0)
        card.borderTop:SetPoint("TOPRIGHT", 0, 0)
        card.borderTop:SetHeight(2)
        card.borderTop:SetColorTexture(1, 1, 1, 0.8)
        
        card.borderBottom = card.border:CreateTexture(nil, "OVERLAY")
        card.borderBottom:SetPoint("BOTTOMLEFT", 0, 0)
        card.borderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
        card.borderBottom:SetHeight(2)
        card.borderBottom:SetColorTexture(1, 1, 1, 0.8)
        
        card.borderLeft = card.border:CreateTexture(nil, "OVERLAY")
        card.borderLeft:SetPoint("TOPLEFT", 0, 0)
        card.borderLeft:SetPoint("BOTTOMLEFT", 0, 0)
        card.borderLeft:SetWidth(2)
        card.borderLeft:SetColorTexture(1, 1, 1, 0.8)
        
        card.borderRight = card.border:CreateTexture(nil, "OVERLAY")
        card.borderRight:SetPoint("TOPRIGHT", 0, 0)
        card.borderRight:SetPoint("BOTTOMRIGHT", 0, 0)
        card.borderRight:SetWidth(2)
        card.borderRight:SetColorTexture(1, 1, 1, 0.8)
        
        -- Nom du personnage
        card.nameText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        card.nameText:SetPoint("TOP", 0, -8)
        card.nameText:SetText(charInfo.data.name)
        card.nameText:SetTextColor(1, 1, 1)
        
        -- Détails du personnage avec clé de groupe
        card.detailsText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        card.detailsText:SetPoint("TOP", 0, -22)
        card.detailsText:SetText(string.format("Niv %d %s", charInfo.data.level, charInfo.data.class))
        card.detailsText:SetTextColor(0.9, 0.9, 0.9)
        
        -- Affichage du groupe (cliquable pour éditer)
        card.groupText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        card.groupText:SetPoint("TOP", 0, -35)
        local groupName = charInfo.settings.accountGroup or (AuberdineExporterDB.accountGroup or "Groupe-Auto")
        card.groupText:SetText("Groupe: " .. groupName)
        card.groupText:SetTextColor(0.7, 0.7, 0.7)
        
        -- Bouton invisible pour éditer le groupe
        card.groupBtn = CreateFrame("Button", nil, card)
        card.groupBtn:SetAllPoints(card.groupText)
        card.groupBtn:SetScript("OnClick", function()
            AuberdineExporterUI:ShowGroupEditPopup(charInfo.key, groupName)
        end)
        card.groupBtn:SetScript("OnEnter", function()
            card.groupText:SetTextColor(1, 1, 0.5) -- Jaune au survol
        end)
        card.groupBtn:SetScript("OnLeave", function()
            card.groupText:SetTextColor(0.7, 0.7, 0.7) -- Retour normal
        end)
        
        -- Dropdown pour le rôle (position ajustée)
        card.roleDropdown = CreateFrame("Frame", nil, card, "UIDropDownMenuTemplate")
        card.roleDropdown:SetPoint("TOP", 0, -55)
        card.roleDropdown:SetSize(120, 20)
        
        UIDropDownMenu_SetWidth(card.roleDropdown, 120)
        local roleText = charInfo.type == "main" and "Main" or 
                        charInfo.type == "alt" and "Alt" or
                        charInfo.type == "bank" and "Banque" or
                        charInfo.type == "mule" and "Mule" or "Inconnu"
        UIDropDownMenu_SetText(card.roleDropdown, roleText)
        
        UIDropDownMenu_Initialize(card.roleDropdown, function(self, level)
            local types = {
                {text = "Main", value = "main", color = {0.5, 1, 0.5}},
                {text = "Alt", value = "alt", color = {0.5, 0.5, 1}},
                {text = "Banque", value = "bank", color = {1, 1, 0.5}},
                {text = "Mule", value = "mule", color = {1, 0.5, 0.5}},
                {text = "Inconnu", value = "unknown", color = {0.7, 0.7, 0.7}}
            }
            
            for _, typeInfo in ipairs(types) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = typeInfo.text
                info.value = typeInfo.value
                info.colorCode = string.format("|cff%02x%02x%02x", 
                    typeInfo.color[1] * 255, 
                    typeInfo.color[2] * 255, 
                    typeInfo.color[3] * 255)
                info.func = function(self)
                    if SetCharacterType then
                        SetCharacterType(charInfo.key, self.value)
                        UIDropDownMenu_SetText(card.roleDropdown, self.text)
                        CloseDropDownMenus()
                        
                        -- Recharger automatiquement l'affichage
                        C_Timer.After(0.1, function()
                            parentFrame:Hide()
                            AuberdineExporterUI:ShowCharacterConfigFrame()
                        end)
                    end
                end
                info.checked = charInfo.type == typeInfo.value
                UIDropDownMenu_AddButton(info)
            end
        end)
        
        -- Indicateur d'export
        card.exportIcon = card:CreateTexture(nil, "OVERLAY")
        card.exportIcon:SetSize(12, 12)
        card.exportIcon:SetPoint("TOPRIGHT", -5, -5)
        if charInfo.settings.exportEnabled ~= false then
            card.exportIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        else
            card.exportIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
        end
        
        -- Bouton toggle export
        card.exportBtn = CreateFrame("Button", nil, card)
        card.exportBtn:SetSize(16, 16)
        card.exportBtn:SetPoint("TOPRIGHT", -5, -5)
        card.exportBtn:SetScript("OnClick", function()
            if ToggleCharacterExport then
                ToggleCharacterExport(charInfo.key)
                -- Mettre à jour l'icône
                local newSettings = InitializeCharacterSettings and InitializeCharacterSettings(charInfo.key) or {}
                if newSettings.exportEnabled ~= false then
                    card.exportIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
                else
                    card.exportIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
                end
            end
        end)
        
        return card
    end
    
    -- Fonction pour dessiner des lignes de connexion entre personnages
    local function DrawConnection(parent, fromCard, toCard, connectionType, fromX, fromY, toX, toY)
        -- Vérifier que les cartes sont valides
        if not fromCard or not toCard or not parent then
            return nil
        end
        
        -- Utiliser les positions passées en paramètre plutôt que GetLeft/GetTop
        -- car ces méthodes ne fonctionnent que si les frames sont déjà rendus
        
        -- Points de connexion (centre-bas de la carte source, centre-haut de la carte cible)
        local fromConnectX = fromX + cardWidth/2
        local fromConnectY = fromY - cardHeight
        local toConnectX = toX + cardWidth/2
        local toConnectY = toY
        
        -- Ligne verticale principale (du bas de la source vers le niveau de la cible)
        local verticalHeight = math.abs(toConnectY - fromConnectY) - 20
        if verticalHeight > 5 then
            local line = parent:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(0.7, 0.7, 0.7, 0.8)
            line:SetSize(2, verticalHeight)
            line:SetPoint("TOPLEFT", parent, "TOPLEFT", fromConnectX - 1, fromConnectY - 10)
        end
        
        -- Ligne horizontale si les cartes ne sont pas alignées verticalement
        if math.abs(toConnectX - fromConnectX) > 5 then
            local horizontalLine = parent:CreateTexture(nil, "ARTWORK")
            horizontalLine:SetColorTexture(0.7, 0.7, 0.7, 0.8)
            horizontalLine:SetSize(math.abs(toConnectX - fromConnectX), 2)
            
            local startX = math.min(fromConnectX, toConnectX)
            horizontalLine:SetPoint("TOPLEFT", parent, "TOPLEFT", startX, toConnectY - 10)
            
            -- Ligne verticale finale vers la carte destinataire
            local finalVertical = parent:CreateTexture(nil, "ARTWORK")
            finalVertical:SetColorTexture(0.7, 0.7, 0.7, 0.8)
            finalVertical:SetSize(2, 10)
            finalVertical:SetPoint("TOPLEFT", parent, "TOPLEFT", toConnectX - 1, toConnectY - 10)
        end
        
        -- Ajouter une flèche de direction
        local arrow = parent:CreateTexture(nil, "OVERLAY")
        arrow:SetSize(8, 8)
        arrow:SetPoint("TOPLEFT", parent, "TOPLEFT", toConnectX - 4, toConnectY - 5)
        
        -- Couleur selon le type de connexion
        if connectionType == "main-alt" then
            arrow:SetColorTexture(0.2, 0.8, 0.2, 1) -- Vert pour main->alt
        elseif connectionType == "alt-bank" then
            arrow:SetColorTexture(0.8, 0.8, 0.2, 1) -- Jaune pour alt->bank
        else
            arrow:SetColorTexture(0.8, 0.8, 0.8, 1) -- Blanc par défaut
        end
        
        return {line = line, arrow = arrow}
    end
    
    -- Placer les cartes par niveaux et créer les connexions
    local placedCards = {}
    
    -- Niveau 1: Personnages Main
    if #mainCharacters > 0 then
        local startX = 50
        for i, charInfo in ipairs(mainCharacters) do
            local x = startX + (i - 1) * (cardWidth + cardSpacing)
            local card = CreateCharacterCard(content, charInfo, x, currentY)
            placedCards[charInfo.key] = {card = card, info = charInfo, level = 1, x = x, y = currentY}
            maxWidth = math.max(maxWidth, x + cardWidth)
        end
        currentY = currentY - cardHeight - levelSpacing
    end
    
    -- Niveau 2: Personnages Alt
    if #altCharacters > 0 then
        local startX = 100
        for i, charInfo in ipairs(altCharacters) do
            local x = startX + (i - 1) * (cardWidth + cardSpacing)
            local card = CreateCharacterCard(content, charInfo, x, currentY)
            placedCards[charInfo.key] = {card = card, info = charInfo, level = 2, x = x, y = currentY}
            maxWidth = math.max(maxWidth, x + cardWidth)
        end
        currentY = currentY - cardHeight - levelSpacing
    end
    
    -- Niveau 3: Personnages Banque/Mule
    if #bankCharacters > 0 then
        local startX = 150
        for i, charInfo in ipairs(bankCharacters) do
            local x = startX + (i - 1) * (cardWidth + cardSpacing)
            local card = CreateCharacterCard(content, charInfo, x, currentY)
            placedCards[charInfo.key] = {card = card, info = charInfo, level = 3, x = x, y = currentY}
            maxWidth = math.max(maxWidth, x + cardWidth)
        end
        currentY = currentY - cardHeight - levelSpacing
    end
    
    -- Niveau 4: Personnages Inconnus
    if #unknownCharacters > 0 then
        local startX = 50
        for i, charInfo in ipairs(unknownCharacters) do
            local x = startX + (i - 1) * (cardWidth + cardSpacing)
            local card = CreateCharacterCard(content, charInfo, x, currentY)
            placedCards[charInfo.key] = {card = card, info = charInfo, level = 4, x = x, y = currentY}
            maxWidth = math.max(maxWidth, x + cardWidth)
        end
        currentY = currentY - cardHeight - 20
    end
    
    -- Créer les connexions visuelles entre niveaux immédiatement
    -- en utilisant les positions absolues stockées
    local function CreateConnections()
        -- Connexions Main -> Alt
        for _, mainChar in ipairs(mainCharacters) do
            for _, altChar in ipairs(altCharacters) do
                local fromCard = placedCards[mainChar.key]
                local toCard = placedCards[altChar.key]
                if fromCard and toCard then
                    DrawConnection(content, fromCard.card, toCard.card, "main-alt", fromCard.x, fromCard.y, toCard.x, toCard.y)
                end
            end
        end
        
        -- Connexions Alt -> Bank/Mule
        for _, altChar in ipairs(altCharacters) do
            for _, bankChar in ipairs(bankCharacters) do
                local fromCard = placedCards[altChar.key]
                local toCard = placedCards[bankChar.key]
                if fromCard and toCard then
                    DrawConnection(content, fromCard.card, toCard.card, "alt-bank", fromCard.x, fromCard.y, toCard.x, toCard.y)
                end
            end
        end
        
        -- Connexions Main -> Bank/Mule (si pas d'alt intermédiaire)
        if #altCharacters == 0 then
            for _, mainChar in ipairs(mainCharacters) do
                for _, bankChar in ipairs(bankCharacters) do
                    local fromCard = placedCards[mainChar.key]
                    local toCard = placedCards[bankChar.key]
                    if fromCard and toCard then
                        DrawConnection(content, fromCard.card, toCard.card, "main-bank", fromCard.x, fromCard.y, toCard.x, toCard.y)
                    end
                end
            end
        end
    end
    
    -- Appeler immédiatement la création des connexions
    CreateConnections()
    
    -- Définir la taille du content pour le scroll
    content:SetHeight(math.abs(currentY) + 50)
    content:SetWidth(maxWidth + 50)
end
