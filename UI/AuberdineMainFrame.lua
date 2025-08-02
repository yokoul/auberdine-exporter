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
    
    -- NOUVEAU v1.3.2: Bouton Gestion Personnages
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
Auberdine Exporter v1.3.2 - Gestion avancée des personnages

Personnages: %d
Métiers: %d  
Total Recettes: %d

Personnage Actuel: %s (%s)
Type: %s | Groupe: %s | Export: %s

NOUVEAU v1.3.2:
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
    title:SetText("Gestion des Personnages (v1.3.2)")
    title:SetTextColor(1, 1, 0)
    
    -- Instructions
    local instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instructions:SetPoint("TOPLEFT", 10, -35)
    instructions:SetPoint("TOPRIGHT", -10, -35)
    instructions:SetJustifyH("LEFT")
    instructions:SetText(
        "Configurez vos personnages :\n" ..
        "• Main : Personnage principal\n" ..
        "• Alt : Personnage alternatif\n" ..
        "• Bank : Personnage banque/stockage\n" ..
        "• Mule : Personnage de transport"
    )
    instructions:SetTextColor(0.8, 0.8, 0.8)
    
    -- Section personnage actuel
    local currentCharTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    currentCharTitle:SetPoint("TOPLEFT", 10, -120)
    currentCharTitle:SetText("Personnage Actuel")
    currentCharTitle:SetTextColor(0.5, 1, 0.5)
    
    local currentCharKey = GetCurrentCharacterKey and GetCurrentCharacterKey() or "Unknown"
    local currentCharData = AuberdineExporterDB and AuberdineExporterDB.characters and AuberdineExporterDB.characters[currentCharKey]
    
    if currentCharData then
        local charInfo = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        charInfo:SetPoint("TOPLEFT", 10, -145)
        charInfo:SetText(string.format("%s (%s) - Niveau %d %s", 
            currentCharData.name, currentCharData.realm,
            currentCharData.level, currentCharData.class))
        charInfo:SetTextColor(1, 1, 1)
        
        -- Configuration actuelle
        local currentSettings = InitializeCharacterSettings and InitializeCharacterSettings(currentCharKey) or {}
        local configInfo = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        configInfo:SetPoint("TOPLEFT", 10, -170)
        configInfo:SetText(string.format("Type: %s | Groupe: %s | Export: %s", 
            currentSettings.characterType or "main",
            currentSettings.accountGroup or (AuberdineExporterDB.accountGroup or "Groupe-Auto"),
            (currentSettings.exportEnabled ~= false) and "Activé" or "Désactivé"))
        configInfo:SetTextColor(0.8, 0.8, 0.8)
        
        -- Boutons de configuration rapide
        local yOffset = -200
        
        -- Type de personnage
        local typeTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        typeTitle:SetPoint("TOPLEFT", 10, yOffset)
        typeTitle:SetText("Type de personnage:")
        typeTitle:SetTextColor(1, 0.8, 0)
        
        local typeButtons = {"Main", "Alt", "Bank", "Mule"}
        for i, buttonType in ipairs(typeButtons) do
            local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
            btn:SetPoint("TOPLEFT", 10 + (i-1) * 85, yOffset - 25)
            btn:SetSize(80, 25)
            btn:SetText(buttonType)
            btn:SetScript("OnClick", function()
                if SetCharacterType then
                    SetCharacterType(currentCharKey, string.lower(buttonType))
                    -- Refresh the display
                    frame:GetParent():GetParent():UpdateContent()
                end
            end)
        end
        
        yOffset = yOffset - 70
        
        -- Groupe de compte
        local accountTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        accountTitle:SetPoint("TOPLEFT", 10, yOffset)
        accountTitle:SetText("Groupe de compte:")
        accountTitle:SetTextColor(1, 0.8, 0)
        
        local accountInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        accountInput:SetPoint("TOPLEFT", 130, yOffset + 5)
        accountInput:SetSize(150, 20)
        accountInput:SetText(currentSettings.accountGroup or (AuberdineExporterDB.accountGroup or "Groupe-Auto"))
        accountInput:SetAutoFocus(false)
        
        local setAccountBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        setAccountBtn:SetPoint("TOPLEFT", 290, yOffset)
        setAccountBtn:SetSize(80, 25)
        setAccountBtn:SetText("Définir")
        setAccountBtn:SetScript("OnClick", function()
            local groupName = accountInput:GetText()
            if groupName and groupName ~= "" and SetAccountGroup then
                SetAccountGroup(currentCharKey, groupName)
                frame:GetParent():GetParent():UpdateContent()
            end
        end)
        
        yOffset = yOffset - 50
        
        -- Toggle export
        local exportBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        exportBtn:SetPoint("TOPLEFT", 10, yOffset)
        exportBtn:SetSize(150, 25)
        local exportStatus = (currentSettings.exportEnabled ~= false) and "Désactiver" or "Activer"
        exportBtn:SetText(exportStatus .. " Export")
        exportBtn:SetScript("OnClick", function()
            if ToggleCharacterExport then
                ToggleCharacterExport(currentCharKey)
                frame:GetParent():GetParent():UpdateContent()
            end
        end)
        
        -- Bouton de configuration avancée
        local configBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        configBtn:SetPoint("TOPLEFT", 170, yOffset)
        configBtn:SetSize(150, 25)
        configBtn:SetText("Liste Complète")
        configBtn:SetScript("OnClick", function()
            if ListCharacterConfiguration then
                ListCharacterConfiguration()
            end
        end)
    end
    
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

-- NOUVEAU v1.3.2: Fenêtre de gestion des personnages
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
    frame.title:SetText("Configuration des Personnages v1.3.2")
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
    
    -- Instructions principales
    local instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    instructions:SetPoint("TOPLEFT", 20, yOffset)
    instructions:SetText("Configuration des Types de Personnages")
    instructions:SetTextColor(1, 1, 0)
    
    -- Bouton Aide
    local helpBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    helpBtn:SetPoint("TOPRIGHT", -90, yOffset - 5)
    helpBtn:SetSize(60, 25)
    helpBtn:SetText("Aide")
    helpBtn:SetScript("OnClick", function()
        AuberdineExporterUI:ShowHelpPopup()
    end)
    
    -- Bouton Actualiser
    local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refreshBtn:SetPoint("TOPRIGHT", -20, yOffset - 5)
    refreshBtn:SetSize(70, 25)
    refreshBtn:SetText("Actualiser")
    refreshBtn:SetScript("OnClick", function()
        frame:Hide()
        AuberdineExporterUI:ShowCharacterConfigFrame()
    end)
    
    yOffset = yOffset - 35
    
    -- Section de gestion du groupe global avec nom généré automatiquement
    local groupSectionBg = frame:CreateTexture(nil, "BACKGROUND")
    groupSectionBg:SetPoint("TOPLEFT", 10, yOffset + 5)
    groupSectionBg:SetPoint("TOPRIGHT", -10, yOffset + 5)
    groupSectionBg:SetHeight(80)
    groupSectionBg:SetColorTexture(0.2, 0.2, 0.4, 0.3)
    
    -- S'assurer qu'il y a toujours un groupe généré automatiquement
    if not AuberdineExporterDB.accountGroup then
        if AuberdineExporter and AuberdineExporter.GenerateDefaultGroupName then
            AuberdineExporterDB.accountGroup = AuberdineExporter:GenerateDefaultGroupName()
        else
            AuberdineExporterDB.accountGroup = "Groupe-" .. math.random(10, 99)
        end
    end
    local currentGroupName = AuberdineExporterDB.accountGroup
    -- Assurer que les fonctions sont disponibles avant appel
    local accountKey = "AB-????-????"
    if AuberdineExporter and AuberdineExporter.GetOrCreateAccountKey then
        accountKey = AuberdineExporter:GetOrCreateAccountKey()
    elseif GetOrCreateAccountKey then
        accountKey = GetOrCreateAccountKey()
    end
    
    local groupTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    groupTitle:SetPoint("TOPLEFT", 20, yOffset)
    groupTitle:SetText("Configuration Groupe de Compte (Auto-généré)")
    groupTitle:SetTextColor(0.5, 1, 0.5)
    
    local groupInfo = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    groupInfo:SetPoint("TOPLEFT", 20, yOffset - 20)
    groupInfo:SetText(string.format("Nom de groupe: %s | Clé unique: %s", currentGroupName, accountKey))
    groupInfo:SetTextColor(1, 1, 1)
    
    local groupHelp = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    groupHelp:SetPoint("TOPLEFT", 20, yOffset - 35)
    groupHelp:SetText("Nom de groupe unique généré automatiquement")
    groupHelp:SetTextColor(0.7, 0.7, 0.7)
    
    -- Champ pour nouveau nom de groupe
    local newGroupInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    newGroupInput:SetPoint("TOPLEFT", 20, yOffset - 55)
    newGroupInput:SetSize(150, 20)
    newGroupInput:SetText(currentGroupName)
    newGroupInput:SetAutoFocus(false)
    
    -- Bouton pour appliquer à tous
    local setAllGroupBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    setAllGroupBtn:SetPoint("TOPLEFT", 180, yOffset - 60)
    setAllGroupBtn:SetSize(150, 25)
    setAllGroupBtn:SetText("Appliquer à tous")
    setAllGroupBtn:SetScript("OnClick", function()
        local newGroupName = newGroupInput:GetText()
        if newGroupName and newGroupName ~= "" then
            -- Mettre à jour le groupe global
            if not AuberdineExporterDB then AuberdineExporterDB = {} end
            AuberdineExporterDB.accountGroup = newGroupName
            
            -- Appliquer à tous les personnages
            if AuberdineExporterDB.characters then
                for charKey, _ in pairs(AuberdineExporterDB.characters) do
                    if SetAccountGroup then
                        SetAccountGroup(charKey, newGroupName)
                    end
                end
            end
            
            print(string.format("|cff00ff00AuberdineExporter:|r Groupe '%s' appliqué à tous les personnages", newGroupName))
            frame:Hide()
            AuberdineExporterUI:ShowCharacterConfigFrame()
        end
    end)
    
    -- Bouton pour générer un nouveau nom
    local generateGroupBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    generateGroupBtn:SetPoint("TOPLEFT", 340, yOffset - 60)
    generateGroupBtn:SetSize(120, 25)
    generateGroupBtn:SetText("Nouveau nom")
    generateGroupBtn:SetScript("OnClick", function()
        local newName = "DefaultGroup-00" -- Fallback sécurisé
        if AuberdineExporter and AuberdineExporter.GenerateDefaultGroupName then
            newName = AuberdineExporter:GenerateDefaultGroupName()
        elseif GenerateDefaultGroupName then
            newName = GenerateDefaultGroupName()
        end
        if newName and newName ~= "" then
            newGroupInput:SetText(newName)
            print(string.format("|cff00ff00AuberdineExporter:|r Nouveau nom généré: %s", newName))
        end
    end)
    
    -- Bouton pour afficher la clé unique
    local showKeyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    showKeyBtn:SetPoint("TOPLEFT", 470, yOffset - 60)
    showKeyBtn:SetSize(120, 25)
    showKeyBtn:SetText("Voir clé unique")
    showKeyBtn:SetScript("OnClick", function()
        local key = "AB-????-????" -- Fallback
        if AuberdineExporter and AuberdineExporter.GetOrCreateAccountKey then
            key = AuberdineExporter:GetOrCreateAccountKey()
        elseif GetOrCreateAccountKey then
            key = GetOrCreateAccountKey()
        end
        print(string.format("|cff00ff00AuberdineExporter:|r Votre clé d'identification unique: %s", key))
        print("Utilisez '/auberdine accountkey' pour plus d'informations.")
    end)
    
    yOffset = yOffset - 100
    
    -- Titre pour l'affichage graphique
    local graphicTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    graphicTitle:SetPoint("TOPLEFT", 20, yOffset)
    graphicTitle:SetText("Relations entre Personnages")
    graphicTitle:SetTextColor(1, 1, 0)
    
    yOffset = yOffset - 25
    
    -- Légende des couleurs et connexions
    local legendFrame = CreateFrame("Frame", nil, frame)
    legendFrame:SetPoint("TOPLEFT", 20, yOffset)
    legendFrame:SetSize(860, 35)
    
    -- Background de la légende
    legendFrame.bg = legendFrame:CreateTexture(nil, "BACKGROUND")
    legendFrame.bg:SetAllPoints()
    legendFrame.bg:SetColorTexture(0.1, 0.1, 0.1, 0.3)
    
    local legendText = legendFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    legendText:SetPoint("TOPLEFT", 10, -5)
    legendText:SetText("Couleurs: ")
    legendText:SetTextColor(1, 1, 1)
    
    -- Échantillons de couleur pour chaque type (nouvelles couleurs)
    local typeLabels = {
        {type = "Main", color = {0.1, 0.4, 0.7}, x = 60},
        {type = "Alt", color = {0.6, 0.3, 0.8}, x = 120},
        {type = "Banque", color = {0.8, 0.6, 0.1}, x = 180},
        {type = "Mule", color = {0.7, 0.4, 0.2}, x = 250}
    }
    
    for _, typeInfo in ipairs(typeLabels) do
        local colorSample = legendFrame:CreateTexture(nil, "ARTWORK")
        colorSample:SetSize(12, 12)
        colorSample:SetPoint("TOPLEFT", typeInfo.x, -8)
        colorSample:SetColorTexture(typeInfo.color[1], typeInfo.color[2], typeInfo.color[3], 1)
        
        local typeText = legendFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        typeText:SetPoint("TOPLEFT", typeInfo.x + 15, -5)
        typeText:SetText(typeInfo.type)
        typeText:SetTextColor(0.9, 0.9, 0.9)
    end
    
    -- Explication des connexions
    local connectionText = legendFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    connectionText:SetPoint("TOPLEFT", 350, -5)
    connectionText:SetText("Connexions: ")
    connectionText:SetTextColor(1, 1, 1)
    
    -- Ligne d'exemple
    local sampleLine = legendFrame:CreateTexture(nil, "ARTWORK")
    sampleLine:SetSize(20, 2)
    sampleLine:SetPoint("TOPLEFT", 420, -10)
    sampleLine:SetColorTexture(0.7, 0.7, 0.7, 0.8)
    
    local connectionExplain = legendFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    connectionExplain:SetPoint("TOPLEFT", 445, -5)
    connectionExplain:SetText("Hiérarchie des personnages")
    connectionExplain:SetTextColor(0.9, 0.9, 0.9)
    
    -- Indicateur export
    local exportSample = legendFrame:CreateTexture(nil, "ARTWORK")
    exportSample:SetSize(12, 12)
    exportSample:SetPoint("TOPLEFT", 620, -8)
    exportSample:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    
    local exportText = legendFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    exportText:SetPoint("TOPLEFT", 635, -5)
    exportText:SetText("Export activé/désactivé")
    exportText:SetTextColor(0.9, 0.9, 0.9)
    
    yOffset = yOffset - 45
    
    -- Zone de scroll pour l'affichage graphique des cartes
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, yOffset)
    scrollFrame:SetPoint("BOTTOMRIGHT", -40, 80)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(content)
    content:SetWidth(scrollFrame:GetWidth())
    
    -- Créer l'affichage graphique des personnages
    self:CreateCharacterCardLayout(content, frame)
    
    -- Boutons d'actions globales en bas
    local globalActionsFrame = CreateFrame("Frame", nil, frame)
    globalActionsFrame:SetPoint("BOTTOMLEFT", 20, 20)
    globalActionsFrame:SetPoint("BOTTOMRIGHT", -20, 20)
    globalActionsFrame:SetHeight(40)
    
    -- Séparateur
    local bottomSeparator = globalActionsFrame:CreateTexture(nil, "ARTWORK")
    bottomSeparator:SetPoint("TOPLEFT", 0, 35)
    bottomSeparator:SetPoint("TOPRIGHT", 0, 35)
    bottomSeparator:SetHeight(2)
    bottomSeparator:SetColorTexture(0.5, 0.5, 0.5, 1)
    
    -- Bouton pour configurer tous en main
    local allMainBtn = CreateFrame("Button", nil, globalActionsFrame, "UIPanelButtonTemplate")
    allMainBtn:SetPoint("TOPLEFT", 0, 25)
    allMainBtn:SetSize(120, 25)
    allMainBtn:SetText("Tous en Main")
    allMainBtn:SetScript("OnClick", function()
        if AuberdineExporterDB and AuberdineExporterDB.characters then
            for charKey, _ in pairs(AuberdineExporterDB.characters) do
                if SetCharacterType then
                    SetCharacterType(charKey, "main")
                end
            end
            frame:Hide()
            AuberdineExporterUI:ShowCharacterConfigFrame()
            print("|cff00ff00AuberdineExporter:|r Tous les personnages définis comme 'main'")
        end
    end)
    
    -- Bouton pour activer l'export pour tous
    local enableAllBtn = CreateFrame("Button", nil, globalActionsFrame, "UIPanelButtonTemplate")
    enableAllBtn:SetPoint("TOPLEFT", 130, 25)
    enableAllBtn:SetSize(140, 25)
    enableAllBtn:SetText("Activer tous exports")
    enableAllBtn:SetScript("OnClick", function()
        if AuberdineExporterDB and AuberdineExporterDB.characters then
            for charKey, _ in pairs(AuberdineExporterDB.characters) do
                if SetCharacterExportEnabled then
                    SetCharacterExportEnabled(charKey, true)
                elseif ToggleCharacterExport then
                    local settings = InitializeCharacterSettings and InitializeCharacterSettings(charKey) or {}
                    if settings.exportEnabled == false then
                        ToggleCharacterExport(charKey)
                    end
                end
            end
            frame:Hide()
            AuberdineExporterUI:ShowCharacterConfigFrame()
            print("|cff00ff00AuberdineExporter:|r Export activé pour tous les personnages")
        end
    end)
    
    -- Bouton pour lister la config dans le chat
    local listConfigBtn = CreateFrame("Button", nil, globalActionsFrame, "UIPanelButtonTemplate")
    listConfigBtn:SetPoint("TOPLEFT", 280, 25)
    listConfigBtn:SetSize(120, 25)
    listConfigBtn:SetText("Liste dans Chat")
    listConfigBtn:SetScript("OnClick", function()
        if ListCharacterConfiguration then
            ListCharacterConfiguration()
        end
    end)
    
    -- Bouton de fermeture
    local closeBtn = CreateFrame("Button", nil, globalActionsFrame, "UIPanelButtonTemplate")
    closeBtn:SetPoint("TOPRIGHT", 0, 25)
    closeBtn:SetSize(80, 25)
    closeBtn:SetText("Fermer")
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
        if AuberdineExporterUI.mainFrame then
            AuberdineExporterUI.mainFrame:Show()
        end
    end)
end

-- NOUVEAU: Fonction pour créer l'affichage graphique en cartes
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
        
        -- Affichage du groupe
        card.groupText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        card.groupText:SetPoint("TOP", 0, -35)
        local groupName = charInfo.settings.accountGroup or (AuberdineExporterDB.accountGroup or "Groupe-Auto")
        card.groupText:SetText("Groupe: " .. groupName)
        card.groupText:SetTextColor(0.7, 0.7, 0.7)
        
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
    local function DrawConnection(parent, fromCard, toCard, connectionType)
        -- Vérifier que les cartes sont valides et positionnées
        if not fromCard or not toCard or not parent then
            return nil
        end
        
        -- Attendre que les frames soient positionnés (vérification des positions)
        local fromLeft = fromCard:GetLeft()
        local fromTop = fromCard:GetTop()
        local toLeft = toCard:GetLeft()
        local toTop = toCard:GetTop()
        local parentLeft = parent:GetLeft()
        local parentTop = parent:GetTop()
        
        -- Si une des positions est nil, ne pas dessiner de connexion
        if not fromLeft or not fromTop or not toLeft or not toTop or not parentLeft or not parentTop then
            return nil
        end
        
        -- Créer une ligne verticale étirée en utilisant une texture de pixel
        local line = parent:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(0.7, 0.7, 0.7, 0.6)
        
        -- Calculer positions des cartes
        local fromX = fromLeft - parentLeft + cardWidth/2
        local fromY = -(fromTop - parentTop) - cardHeight
        local toX = toLeft - parentLeft + cardWidth/2
        local toY = -(toTop - parentTop)
        
        -- Ligne verticale de base (du bas de la carte source vers le niveau du destinataire)
        local verticalHeight = math.abs(toY - fromY) - 20
        if verticalHeight > 0 then
            line:SetSize(2, verticalHeight)
            line:SetPoint("TOPLEFT", parent, "TOPLEFT", fromX - 1, fromY - 10)
        end
        
        -- Ligne horizontale si nécessaire
        if math.abs(toX - fromX) > 5 then
            local horizontalLine = parent:CreateTexture(nil, "ARTWORK")
            horizontalLine:SetColorTexture(0.7, 0.7, 0.7, 0.6)
            horizontalLine:SetSize(math.abs(toX - fromX), 2)
            
            local startX = math.min(fromX, toX)
            horizontalLine:SetPoint("TOPLEFT", parent, "TOPLEFT", startX, toY - 10)
            
            -- Ligne verticale finale vers la carte destinataire
            local finalVertical = parent:CreateTexture(nil, "ARTWORK")
            finalVertical:SetColorTexture(0.7, 0.7, 0.7, 0.6)
            finalVertical:SetSize(2, 10)
            finalVertical:SetPoint("TOPLEFT", parent, "TOPLEFT", toX - 1, toY - 10)
        end
        
        -- Ajouter une flèche de direction
        local arrow = parent:CreateTexture(nil, "OVERLAY")
        arrow:SetSize(8, 8)
        arrow:SetPoint("TOPLEFT", parent, "TOPLEFT", toX - 4, toY - 5)
        
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
            placedCards[charInfo.key] = {card = card, info = charInfo, level = 1}
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
            placedCards[charInfo.key] = {card = card, info = charInfo, level = 2}
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
            placedCards[charInfo.key] = {card = card, info = charInfo, level = 3}
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
            placedCards[charInfo.key] = {card = card, info = charInfo, level = 4}
            maxWidth = math.max(maxWidth, x + cardWidth)
        end
        currentY = currentY - cardHeight - 20
    end
    
    -- Créer les connexions visuelles entre niveaux avec un délai
    -- pour permettre aux frames d'être complètement positionnés
    local function CreateConnections()
        -- Connexions Main -> Alt
        for _, mainChar in ipairs(mainCharacters) do
            for _, altChar in ipairs(altCharacters) do
                if placedCards[mainChar.key] and placedCards[altChar.key] then
                    DrawConnection(content, placedCards[mainChar.key].card, placedCards[altChar.key].card, "main-alt")
                end
            end
        end
        
        -- Connexions Alt -> Bank/Mule
        for _, altChar in ipairs(altCharacters) do
            for _, bankChar in ipairs(bankCharacters) do
                if placedCards[altChar.key] and placedCards[bankChar.key] then
                    DrawConnection(content, placedCards[altChar.key].card, placedCards[bankChar.key].card, "alt-bank")
                end
            end
        end
        
        -- Connexions Main -> Bank/Mule (si pas d'alt intermédiaire)
        if #altCharacters == 0 then
            for _, mainChar in ipairs(mainCharacters) do
                for _, bankChar in ipairs(bankCharacters) do
                    if placedCards[mainChar.key] and placedCards[bankChar.key] then
                        DrawConnection(content, placedCards[mainChar.key].card, placedCards[bankChar.key].card, "main-bank")
                    end
                end
            end
        end
    end
    
    -- Retarder le dessin des connexions pour permettre le positionnement des frames
    C_Timer.After(0.1, CreateConnections)
    
    -- Définir la taille du content pour le scroll
    content:SetHeight(math.abs(currentY) + 50)
    content:SetWidth(maxWidth + 50)
end
