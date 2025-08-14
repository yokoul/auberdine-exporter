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
    
    -- Create main frame - Plus large pour accueillir la vue des personnages
    local frame = CreateFrame("Frame", "AuberdineExporterMainFrame", UIParent)
    frame:SetSize(1000, 700)  -- Agrandi pour la nouvelle layout
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
    frame.title:SetText("Famille d'Auberdine v1.3.3 - Interface Unifiée")
    frame.title:SetTextColor(1, 1, 1)
    
    -- Close button
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetPoint("TOPRIGHT", -5, -5)
    frame.closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- SIDEBAR GAUCHE POUR LES BOUTONS (remplace les boutons horizontaux)
    frame.sidebar = CreateFrame("Frame", nil, frame)
    frame.sidebar:SetPoint("TOPLEFT", 10, -35)
    frame.sidebar:SetSize(180, 650)  -- Barre verticale
    
    -- Background de la sidebar
    frame.sidebar.bg = frame.sidebar:CreateTexture(nil, "BACKGROUND")
    frame.sidebar.bg:SetAllPoints()
    frame.sidebar.bg:SetColorTexture(0.1, 0.1, 0.1, 0.6)
    
    -- Titre de la sidebar
    frame.sidebar.title = frame.sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.sidebar.title:SetPoint("TOP", 0, -10)
    frame.sidebar.title:SetText("Actions")
    frame.sidebar.title:SetTextColor(1, 1, 0)
    
    -- Export Auberdine button (vertical)
    local exportBtn = CreateFrame("Button", nil, frame.sidebar, "UIPanelButtonTemplate")
    exportBtn:SetPoint("TOP", 0, -35)
    exportBtn:SetSize(160, 30)
    exportBtn:SetText("Export Auberdine")
    exportBtn:SetScript("OnClick", function()
        local jsonData = ExportToJSON()
        CreateExportFrame(jsonData, "Auberdine")
    end)
    
    -- Export CSV button
    local csvBtn = CreateFrame("Button", nil, frame.sidebar, "UIPanelButtonTemplate")
    csvBtn:SetPoint("TOP", 0, -75)
    csvBtn:SetSize(160, 30)
    csvBtn:SetText("Export CSV")
    csvBtn:SetScript("OnClick", function()
        local csvData = ExportToCSV()
        CreateExportFrame(csvData, "CSV")
    end)
    
    -- Clear Cache button
    local clearBtn = CreateFrame("Button", nil, frame.sidebar, "UIPanelButtonTemplate")
    clearBtn:SetPoint("TOP", 0, -115)
    clearBtn:SetSize(160, 30)
    clearBtn:SetText("Supprimer Cache")
    clearBtn:SetScript("OnClick", function()
        StaticPopup_Show("AUBERDINE_EXPORTER_RESET_CONFIRM")
    end)
    
    -- Bouton Actualiser personnages
    local refreshBtn = CreateFrame("Button", nil, frame.sidebar, "UIPanelButtonTemplate")
    refreshBtn:SetPoint("TOP", 0, -155)
    refreshBtn:SetSize(160, 30)
    refreshBtn:SetText("Actualiser Vue")
    refreshBtn:SetScript("OnClick", function()
        AuberdineExporterUI:RefreshCharacterView(frame)
    end)
    
    -- Bouton Aide
    local helpBtn = CreateFrame("Button", nil, frame.sidebar, "UIPanelButtonTemplate")
    helpBtn:SetPoint("TOP", 0, -195)
    helpBtn:SetSize(160, 30)
    helpBtn:SetText("Aide")
    helpBtn:SetScript("OnClick", function()
        AuberdineExporterUI:ShowHelpPopup()
    end)
    
    -- ZONE PRINCIPALE POUR LA VUE DES PERSONNAGES
    frame.mainContent = CreateFrame("Frame", nil, frame)
    frame.mainContent:SetPoint("TOPLEFT", frame.sidebar, "TOPRIGHT", 10, 0)
    frame.mainContent:SetPoint("BOTTOMRIGHT", -10, 10)
    
    -- Background de la zone principale
    frame.mainContent.bg = frame.mainContent:CreateTexture(nil, "BACKGROUND")
    frame.mainContent.bg:SetAllPoints()
    frame.mainContent.bg:SetColorTexture(0.05, 0.05, 0.05, 0.4)
    
    -- Initialiser la vue des personnages
    self:CreateUnifiedCharacterView(frame.mainContent)
    
    -- Update content function (pour compatibilité)
    frame.UpdateContent = function()
        -- Actualiser la vue des personnages
        self:RefreshCharacterView(frame)
    end
    
    self.mainFrame = frame
    return frame
end

-- NOUVELLE FONCTION: Vue unifiée des personnages 
function AuberdineExporterUI:CreateUnifiedCharacterView(parent)
    -- Créer une zone conteneur pour le contenu des personnages
    local characterArea = CreateFrame("Frame", nil, parent)
    characterArea:SetAllPoints(parent)
    parent.characterContentArea = characterArea
    
    -- Titre principal
    local title = characterArea:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -10)
    title:SetText("Structure Familiale des Personnages")
    title:SetTextColor(1, 1, 0)
    
    -- Instructions compactes
    local instructions = characterArea:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instructions:SetPoint("TOPLEFT", 20, -35)
    instructions:SetPoint("TOPRIGHT", -20, -35)
    instructions:SetJustifyH("LEFT")
    instructions:SetText("Visualisez et gérez vos personnages. Utilisez les boutons à gauche pour les exports.")
    instructions:SetTextColor(0.8, 0.8, 0.8)
    
    -- Zone de scroll pour l'affichage des cartes personnages
    local scrollFrame = CreateFrame("ScrollFrame", nil, characterArea)
    scrollFrame:SetPoint("TOPLEFT", 20, -60)
    scrollFrame:SetPoint("BOTTOMRIGHT", -40, 120)  -- Espace pour la légende en bas
    
    -- Support molette de souris
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
    
    -- Créer les barres de scroll personnalisées
    self:CreateScrollBars(scrollFrame, characterArea)
    
    -- Créer l'affichage des cartes personnages
    self:CreateCharacterCardLayout(content, characterArea)
    
    -- Section infos/légende en bas
    self:CreateBottomLegend(characterArea)
    
    -- Stocker les références pour l'actualisation
    characterArea.scrollFrame = scrollFrame
    characterArea.content = content
end

-- Fonction pour créer les barres de scroll
function AuberdineExporterUI:CreateScrollBars(scrollFrame, parent)
    -- BARRE DE SCROLL VERTICALE
    local vScrollBar = CreateFrame("Frame", nil, parent)
    vScrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 16, 0)
    vScrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 16, 20)
    vScrollBar:SetWidth(12)
    
    vScrollBar.bg = vScrollBar:CreateTexture(nil, "BACKGROUND")
    vScrollBar.bg:SetAllPoints()
    vScrollBar.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    
    vScrollBar.thumb = CreateFrame("Button", nil, vScrollBar)
    vScrollBar.thumb:SetWidth(10)
    vScrollBar.thumb:SetHeight(30)
    vScrollBar.thumb:SetPoint("TOP", 0, -1)
    vScrollBar.thumb:EnableMouse(true)
    vScrollBar.thumb:RegisterForDrag("LeftButton")
    
    vScrollBar.thumb.bg = vScrollBar.thumb:CreateTexture(nil, "ARTWORK")
    vScrollBar.thumb.bg:SetAllPoints()
    vScrollBar.thumb.bg:SetColorTexture(0.6, 0.6, 0.6, 1)
    
    vScrollBar.thumb.bgHighlight = vScrollBar.thumb:CreateTexture(nil, "HIGHLIGHT")
    vScrollBar.thumb.bgHighlight:SetAllPoints()
    vScrollBar.thumb.bgHighlight:SetColorTexture(0.8, 0.8, 0.8, 1)
    
    -- BARRE DE SCROLL HORIZONTALE
    local hScrollBar = CreateFrame("Frame", nil, parent)
    hScrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMLEFT", 0, -16)
    hScrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", -16, -16)
    hScrollBar:SetHeight(12)
    
    hScrollBar.bg = hScrollBar:CreateTexture(nil, "BACKGROUND")
    hScrollBar.bg:SetAllPoints()
    hScrollBar.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    
    hScrollBar.thumb = CreateFrame("Button", nil, hScrollBar)
    hScrollBar.thumb:SetHeight(10)
    hScrollBar.thumb:SetWidth(30)
    hScrollBar.thumb:SetPoint("LEFT", 1, 0)
    hScrollBar.thumb:EnableMouse(true)
    hScrollBar.thumb:RegisterForDrag("LeftButton")
    
    hScrollBar.thumb.bg = hScrollBar.thumb:CreateTexture(nil, "ARTWORK")
    hScrollBar.thumb.bg:SetAllPoints()
    hScrollBar.thumb.bg:SetColorTexture(0.6, 0.6, 0.6, 1)
    
    -- Fonctions de mise à jour et d'interaction des barres de scroll
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
    
    -- Drag vertical avec correction
    vScrollBar.thumb:SetScript("OnDragStart", function(self)
        self.isDragging = true
        self.startY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        self.startScroll = scrollFrame:GetVerticalScroll()
    end)
    
    vScrollBar.thumb:SetScript("OnDragStop", function(self)
        self.isDragging = false
    end)
    
    vScrollBar.thumb:SetScript("OnUpdate", function(self)
        if self.isDragging then
            local currentY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
            local deltaY = self.startY - currentY
            local barHeight = vScrollBar:GetHeight() - 2
            local maxScroll = scrollFrame:GetVerticalScrollRange()
            
            if maxScroll > 0 then
                local thumbHeight = vScrollBar.thumb:GetHeight()
                local scrollRange = barHeight - thumbHeight
                if scrollRange > 0 then
                    local scrollDelta = (deltaY / scrollRange) * maxScroll
                    local newScroll = math.max(0, math.min(maxScroll, self.startScroll + scrollDelta))
                    scrollFrame:SetVerticalScroll(newScroll)
                end
            end
        end
    end)
    
    -- Drag horizontal avec correction
    hScrollBar.thumb:SetScript("OnDragStart", function(self)
        self.isDragging = true
        self.startX = GetCursorPosition() / self:GetEffectiveScale()
        self.startScroll = scrollFrame:GetHorizontalScroll()
    end)
    
    hScrollBar.thumb:SetScript("OnDragStop", function(self)
        self.isDragging = false
    end)
    
    hScrollBar.thumb:SetScript("OnUpdate", function(self)
        if self.isDragging then
            local currentX = GetCursorPosition() / self:GetEffectiveScale()
            local deltaX = currentX - self.startX
            local barWidth = hScrollBar:GetWidth() - 2
            local maxScroll = scrollFrame:GetHorizontalScrollRange()
            
            if maxScroll > 0 then
                local thumbWidth = hScrollBar.thumb:GetWidth()
                local scrollRange = barWidth - thumbWidth
                if scrollRange > 0 then
                    local scrollDelta = (deltaX / scrollRange) * maxScroll
                    local newScroll = math.max(0, math.min(maxScroll, self.startScroll + scrollDelta))
                    scrollFrame:SetHorizontalScroll(newScroll)
                end
            end
        end
    end)
    
    -- Clic sur les barres pour sauter à une position
    vScrollBar:EnableMouse(true)
    vScrollBar:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            local cursorY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
            local barTop = self:GetTop()
            local barBottom = self:GetBottom()
            local clickPos = (barTop - cursorY) / (barTop - barBottom)
            
            local maxScroll = scrollFrame:GetVerticalScrollRange()
            local newScroll = math.max(0, math.min(maxScroll, clickPos * maxScroll))
            scrollFrame:SetVerticalScroll(newScroll)
        end
    end)
    
    hScrollBar:EnableMouse(true)
    hScrollBar:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            local cursorX = GetCursorPosition() / self:GetEffectiveScale()
            local barLeft = self:GetLeft()
            local barRight = self:GetRight()
            local clickPos = (cursorX - barLeft) / (barRight - barLeft)
            
            local maxScroll = scrollFrame:GetHorizontalScrollRange()
            local newScroll = math.max(0, math.min(maxScroll, clickPos * maxScroll))
            scrollFrame:SetHorizontalScroll(newScroll)
        end
    end)
    
    -- Événements pour les barres de scroll
    scrollFrame:SetScript("OnScrollRangeChanged", function()
        UpdateVerticalScrollBar()
        UpdateHorizontalScrollBar()
    end)
    scrollFrame:SetScript("OnVerticalScroll", UpdateVerticalScrollBar)
    scrollFrame:SetScript("OnHorizontalScroll", UpdateHorizontalScrollBar)
    
    -- Initialiser l'affichage des barres
    C_Timer.After(0.1, function()
        UpdateVerticalScrollBar()
        UpdateHorizontalScrollBar()
    end)
end

-- Fonction pour créer la légende en bas
function AuberdineExporterUI:CreateBottomLegend(parent)
    local bottomFrame = CreateFrame("Frame", nil, parent)
    bottomFrame:SetPoint("BOTTOMLEFT", 20, 20)
    bottomFrame:SetPoint("BOTTOMRIGHT", -20, 20)
    bottomFrame:SetHeight(80)
    
    bottomFrame.bg = bottomFrame:CreateTexture(nil, "BACKGROUND")
    bottomFrame.bg:SetAllPoints()
    bottomFrame.bg:SetColorTexture(0.1, 0.1, 0.1, 0.4)
    
    -- Ligne de séparation
    local separator = bottomFrame:CreateTexture(nil, "ARTWORK")
    separator:SetPoint("TOPLEFT", 5, -5)
    separator:SetPoint("TOPRIGHT", -5, -5)
    separator:SetHeight(2)
    separator:SetColorTexture(0.5, 0.5, 0.5, 1)
    
    -- Légende des couleurs
    local legendText = bottomFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    legendText:SetPoint("TOPLEFT", 10, -15)
    legendText:SetText("Types de personnages:")
    legendText:SetTextColor(1, 1, 1)
    
    local typeLabels = {
        {type = "Main", color = {0.1, 0.4, 0.7}, x = 140},
        {type = "Alt", color = {0.6, 0.3, 0.8}, x = 200},
        {type = "Banque", color = {0.8, 0.6, 0.1}, x = 260},
        {type = "Mule", color = {0.7, 0.4, 0.2}, x = 330}
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
    
    -- Informations et aide
    local helpText = bottomFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    helpText:SetPoint("TOPLEFT", 10, -35)
    helpText:SetText("Clic sur groupes = éditer | Coin supérieur droit des cartes = export ON/OFF | Shift+molette = scroll horizontal")
    helpText:SetTextColor(0.7, 0.7, 0.7)
    
    -- ID de compte
    local accountKey = "AB-????-????"
    if AuberdineExporter and AuberdineExporter.GetOrCreateAccountKey then
        accountKey = AuberdineExporter:GetOrCreateAccountKey()
    end
    local accountKeyText = bottomFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    accountKeyText:SetPoint("TOPLEFT", 10, -55)
    accountKeyText:SetText("ID Compte: " .. accountKey)
    accountKeyText:SetTextColor(0.7, 0.7, 0.7)
end

-- Fonction pour actualiser la vue des personnages
function AuberdineExporterUI:RefreshCharacterView(frame)
    if not frame or not frame.mainContent then
        return
    end
    
    -- Nettoyer seulement la zone de contenu des personnages, pas la sidebar
    if frame.mainContent.characterContentArea then
        local children = {frame.mainContent.characterContentArea:GetChildren()}
        for _, child in pairs(children) do
            child:Hide()
            child:SetParent(nil)
        end
        frame.mainContent.characterContentArea:Hide()
        frame.mainContent.characterContentArea:SetParent(nil)
        frame.mainContent.characterContentArea = nil
    end
    
    -- Recréer seulement la vue des personnages
    self:CreateUnifiedCharacterView(frame.mainContent)
    print("|cff00ff00AuberdineExporter:|r Vue des personnages actualisée !")
end

function AuberdineExporterUI:ToggleMainFrame()
    local frame = self:CreateMainFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        -- Actualiser la vue avant de l'afficher
        self:RefreshCharacterView(frame)
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
    -- Créer une fenêtre d'aide dédiée au lieu d'un StaticPopup
    if self.helpFrame then
        if self.helpFrame:IsShown() then
            self.helpFrame:Hide()
            return
        else
            self.helpFrame:Show()
            return
        end
    end
    
    -- Créer la fenêtre d'aide
    local frame = CreateFrame("Frame", "AuberdineHelpFrame", UIParent)
    frame:SetSize(600, 500)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(150)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    -- Background plus opaque pour une meilleure lisibilité
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0.05, 0.05, 0.15, 0.95)  -- Bleu foncé, presque opaque
    
    -- Border
    frame.border = CreateFrame("Frame", nil, frame, "DialogBorderTemplate")
    
    -- Title bar
    frame.titleBg = frame:CreateTexture(nil, "ARTWORK")
    frame.titleBg:SetPoint("TOPLEFT", 5, -5)
    frame.titleBg:SetPoint("TOPRIGHT", -5, -5)
    frame.titleBg:SetHeight(25)
    frame.titleBg:SetColorTexture(0.1, 0.3, 0.6, 1)  -- Bleu titre
    
    -- Icône d'aide
    frame.icon = frame:CreateTexture(nil, "OVERLAY")
    frame.icon:SetSize(16, 16)
    frame.icon:SetPoint("TOPLEFT", 10, -7)
    frame.icon:SetTexture("Interface\\AddOns\\AuberdineExporter\\UI\\Icons\\ab32.png")
    
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 30, -12)
    frame.title:SetText("Aide - Famille d'Auberdine v1.3.3")
    frame.title:SetTextColor(1, 1, 1)
    
    -- Close button
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetPoint("TOPRIGHT", -5, -5)
    frame.closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Gestion ESC
    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
        end
    end)
    frame:SetPropagateKeyboardInput(true)
    frame:EnableKeyboard(true)
    
    -- Zone de contenu avec scroll
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 15, -35)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(content)
    content:SetWidth(scrollFrame:GetWidth())
    
    -- Contenu d'aide étoffé
    local helpText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    helpText:SetPoint("TOPLEFT", 10, -10)
    helpText:SetPoint("TOPRIGHT", -10, -10)
    helpText:SetJustifyH("LEFT")
    helpText:SetSpacing(3)
    helpText:SetText(
        "|cffffcc00=== INTERFACE UNIFIÉE v1.3.3 ===|r\n\n" ..
        
        "|cff77ff77[*] OBJECTIF PRINCIPAL|r\n" ..
        "Gérer vos personnages et exporter vos données de métiers pour auberdine.eu\n\n" ..
        
        "|cff77ff77[~] ORGANISATION DE L'INTERFACE|r\n" ..
        "• |cffaaaaff Sidebar gauche|r : Boutons d'action (Export, Actualiser, Aide)\n" ..
        "• |cffaaaaff Zone principale|r : Vue graphique de vos personnages\n" ..
        "• |cffaaaaff Légende en bas|r : Codes couleurs et informations compte\n\n" ..
        
        "|cff77ff77[@] TYPES DE PERSONNAGES|r\n" ..
        "• |cff4488ffMain (Bleu)|r : Personnage principal de votre compte\n" ..
        "• |cffaa44ffAlt (Violet)|r : Personnage alternatif, relié au main\n" ..
        "• |cffffaa44Banque (Or)|r : Personnage de stockage des objets\n" ..
        "• |cffff8844Mule (Cuivre)|r : Personnage de transport/transfer\n\n" ..
        
        "|cff77ff77[+] FONCTIONNALITÉS DES CARTES|r\n" ..
        "• |cffccccccNom et niveau|r : Informations du personnage\n" ..
        "• |cffccccccGroupe|r : Cliquez pour éditer le groupe de compte\n" ..
        "• |cffccccccDropdown central|r : Changez le type de personnage\n" ..
        "• |cffccccccCoin supérieur droit|r : Toggle export ON/OFF (vert/rouge)\n" ..
        "• |cffccccccLignes de connexion|r : Montrent la hiérarchie Main→Alt→Banque\n\n" ..
        
        "|cff77ff77[>] NAVIGATION|r\n" ..
        "• |cffccccccMolette souris|r : Scroll vertical\n" ..
        "• |cffccccccShift + Molette|r : Scroll horizontal\n" ..
        "• |cffccccccGlisser barres|r : Positionnement précis\n" ..
        "• |cffccccccClic sur barres|r : Saut rapide à une position\n\n" ..
        
        "|cff77ff77[^] EXPORTS DISPONIBLES|r\n" ..
        "• |cff88ff88Export Auberdine|r : Format JSON optimisé pour auberdine.eu\n" ..
        "• |cff88ff88Export CSV|r : Format tableur pour analyse locale\n" ..
        "• |cffff8888Supprimer Cache|r : Réinitialise toutes les données\n\n" ..
        
        "|cff77ff77[/] COMMANDES UTILES|r\n" ..
        "• |cffcccccc/auberdine|r : Ouvrir/fermer l'interface\n" ..
        "• |cffcccccc/auberdine scan|r : Scanner manuellement tous les métiers\n" ..
        "• |cffcccccc/auberdine stats|r : Afficher les statistiques\n" ..
        "• |cffcccccc/auberdine settype <type>|r : Changer le type du personnage actuel\n" ..
        "• |cffcccccc/auberdine account <groupe>|r : Définir le groupe de compte\n" ..
        "• |cffcccccc/auberdine help|r : Aide complète en console\n\n" ..
        
        "|cff77ff77[!] CONSEILS D'UTILISATION|r\n" ..
        "• Scannez vos métiers en ouvrant les fenêtres de profession\n" ..
        "• Organisez vos personnages par type pour une meilleure visibilité\n" ..
        "• Utilisez les groupes pour séparer vos comptes multiples\n" ..
        "• Désactivez l'export pour les personnages temporaires\n" ..
        "• Actualisez la vue après avoir modifié des paramètres\n\n" ..
        
        "|cff77ff77[=] INTEGRATION WEB|r\n" ..
        "Vos exports sont compatibles avec auberdine.eu pour :\n" ..
        "• Partage de vos collections de recettes\n" ..
        "• Comparaison avec d'autres joueurs\n" ..
        "• Suivi de progression des métiers\n\n" ..
        
        "|cff77ff77[#] COMMUNAUTÉ|r\n" ..
        "Rejoignez le Discord d'auberdine.eu pour :\n" ..
        "• |cffaaaaff https://discord.gg/qVgtRqSkJz|r\n" ..
        "• Support et aide de la communauté\n" ..
        "• Nouvelles fonctionnalités et mises à jour\n" ..
        "• Discussions entre joueurs\n\n" ..
        
        "|cffff7777[X] IMPORTANT|r\n" ..
        "Les données sont sauvegardées automatiquement.\n" ..
        "L'export inclut seulement les personnages avec export activé."
    )
    
    -- Ajuster la hauteur du contenu
    content:SetHeight(helpText:GetStringHeight() + 20)
    
    -- Bouton de fermeture en bas
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetPoint("BOTTOM", 0, 10)
    closeBtn:SetSize(100, 25)
    closeBtn:SetText("Fermer")
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    self.helpFrame = frame
    frame:Show()
end

function AuberdineExporterUI:ShowCharacterConfigFrame()
    -- Redirection vers la nouvelle interface unifiée
    self:ToggleMainFrame()
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
    
    -- Créer la table charactersGrouped pour l'arborescence
    local charactersGrouped = {
        main = mainCharacters,
        alt = altCharacters,
        bank = bankCharacters,
        mule = {}  -- Séparé si nécessaire plus tard
    }
    
    -- Séparer les mules des banques si nécessaire
    for i = #bankCharacters, 1, -1 do
        if bankCharacters[i].type == "mule" then
            table.insert(charactersGrouped.mule, table.remove(bankCharacters, i))
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
                        
                        -- Actualiser seulement la vue des personnages au lieu de fermer/ouvrir
                        C_Timer.After(0.1, function()
                            if parentFrame and parentFrame.UpdateContent then
                                parentFrame.UpdateContent()
                            elseif AuberdineExporterUI and AuberdineExporterUI.mainFrame then
                                AuberdineExporterUI:RefreshCharacterView(AuberdineExporterUI.mainFrame)
                            end
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
    
    -- Affichage des cartes par type
    local currentY = -50  -- Commencer en négatif pour WoW
    
    -- Pour chaque type, afficher les cartes
    local typeOrder = {"main", "alt", "bank", "mule"}
    for _, charType in ipairs(typeOrder) do
        local chars = charactersGrouped[charType]
        if chars and #chars > 0 then
            -- Afficher le titre du type
            local typeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            typeLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 160, currentY)
            
            if charType == "main" then
                typeLabel:SetText("|cff4488ff[MAINS]|r")
            elseif charType == "alt" then
                typeLabel:SetText("|cffaa44ff[ALTS]|r")
            elseif charType == "bank" then
                typeLabel:SetText("|cffffaa44[BANQUES]|r")
            else -- mule
                typeLabel:SetText("|cffff8844[MULES]|r")
            end
            
            currentY = currentY - 25  -- Descendre pour les cartes
            
            -- Afficher les cartes pour ce type
            local startX = 160 -- Position X de départ pour les cartes
            for i, charInfo in ipairs(chars) do
                local cardX = startX + (i - 1) * (cardWidth + 10)
                local card = CreateCharacterCard(content, charInfo, cardX, currentY)
                maxWidth = math.max(maxWidth, cardX + cardWidth)
            end
            
            currentY = currentY - cardHeight - 20 -- Espace après les cartes
        end
    end
    
    -- Créer une table vide pour placedCards (optionnel pour la nouvelle arborescence)
    local placedCards = {}
    
    -- Créer l'arborescence latérale simplifiée
    self:CreateTreeStructure(content, charactersGrouped, placedCards)
    
    -- Définir la taille du content pour le scroll
    content:SetHeight(math.abs(currentY) + 100)  -- Utiliser la valeur absolue de currentY qui est négatif
    content:SetWidth(maxWidth + 50)
end

-- Fonction pour créer l'arborescence latérale
function AuberdineExporterUI:CreateTreeStructure(content, charactersGrouped, placedCards)
    -- Ligne principale verticale à gauche
    local mainTreeLine = content:CreateTexture(nil, "ARTWORK")
    mainTreeLine:SetColorTexture(0.6, 0.6, 0.6, 0.8)
    mainTreeLine:SetWidth(3)
    mainTreeLine:SetPoint("TOPLEFT", content, "TOPLEFT", 15, -10)
    mainTreeLine:SetHeight(400) -- Hauteur fixe pour commencer
    
    -- Titre de l'arborescence
    local treeTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    treeTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 25, -15)
    treeTitle:SetText("|cffaaaaff[HIÉRARCHIE]|r")
    treeTitle:SetTextColor(0.7, 0.7, 0.7)
    
    -- Créer des indicateurs pour chaque niveau avec des personnages
    local yOffset = -40
    local levels = {"main", "alt", "bank", "mule"}
    local levelNames = {
        main = "|cff4488ff● MAINS|r",
        alt = "|cffaa44ff● ALTS|r", 
        bank = "|cffffaa44● BANQUES|r",
        mule = "|cffff8844● MULES|r"
    }
    
    for i, level in ipairs(levels) do
        if charactersGrouped[level] and #charactersGrouped[level] > 0 then
            -- Branche horizontale courte
            local branch = content:CreateTexture(nil, "ARTWORK")
            branch:SetColorTexture(0.6, 0.6, 0.6, 0.8)
            branch:SetHeight(2)
            branch:SetWidth(15)
            branch:SetPoint("LEFT", mainTreeLine, "RIGHT", 0, yOffset + 5)
            
            -- Étiquette du niveau avec compteur
            local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            label:SetPoint("LEFT", branch, "RIGHT", 5, 0)
            label:SetText(levelNames[level] .. " (" .. #charactersGrouped[level] .. ")")
            label:SetTextColor(0.8, 0.8, 0.8)
            
            yOffset = yOffset - 25
        end
    end
    
    -- Ajuster la hauteur de la ligne principale selon le contenu
    mainTreeLine:SetHeight(math.abs(yOffset) + 40)
end
