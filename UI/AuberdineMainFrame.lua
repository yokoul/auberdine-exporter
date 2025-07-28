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
    frame:SetSize(600, 500)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    
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
    exportBtn:SetSize(160, 25)
    exportBtn:SetText("Export Auberdine")
    exportBtn:SetScript("OnClick", function()
        local jsonData = ExportToJSON()
        CreateExportFrame(jsonData, "Auberdine")
    end)
    
    -- Clear Cache button
    local clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearBtn:SetPoint("TOPLEFT", 210, -50)
    clearBtn:SetSize(160, 25)
    clearBtn:SetText("Supprimer Cache")
    clearBtn:SetScript("OnClick", function()
        StaticPopup_Show("AUBERDINE_EXPORTER_RESET_CONFIRM")
    end)

    -- Export CSV button
    local csvBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    csvBtn:SetPoint("TOPLEFT", 390, -50)
    csvBtn:SetSize(160, 25)
    csvBtn:SetText("Export CSV")
    csvBtn:SetScript("OnClick", function()
        local csvData = ExportToCSV()
        CreateExportFrame(csvData, "CSV")
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
            local text = string.format([[
Auberdine Exporter - Statistiques

Personnages: %d
Métiers: %d  
Total Recettes: %d

Personnage Actuel: %s (%s)

Instructions:
1. Ouvrez les fenêtres de métiers pour scanner automatiquement les recettes
2. Utilisez "Export Auberdine" pour générer un export complet pour auberdine.eu
3. Utilisez "Export CSV" pour générer un export au format tableur
4. Utilisez "Supprimer Cache" pour effacer toutes les données stockées

Commandes:
• /auberdine - Ouvrir cette interface
• /auberdine scan - Scan manuel de tous les métiers
• /auberdine clear - Vider les données mémoire
• /auberdine size - Afficher la taille des données
• /auberdine help - Afficher toutes les commandes
]], 
                stats.totalCharacters, 
                stats.totalProfessions, 
                stats.totalRecipes,
                UnitName("player") or "Unknown",
                GetRealmName() or "Unknown"
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
        { name = "Export", func = "CreateExportTab" },
        { name = "Settings", func = "CreateSettingsTab" }
    }
    
    for i, tab in ipairs(tabs) do
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(100, tabHeight)
        btn:SetPoint("TOPLEFT", (i-1) * 100, 0)
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
