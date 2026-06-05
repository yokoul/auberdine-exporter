-- Main UI for AuberdineExporter
AuberdineExporterUI = {}

function AuberdineExporterUI:Initialize()
    self.mainFrame = nil
    self.isInitialized = true
end

function AuberdineExporterUI:CreateAccountKeyEditFrame()
    -- Créer une fenêtre pour éditer l'accountKey
    local editFrame = CreateFrame("Frame", "AuberdineAccountKeyEditFrame", UIParent)
    editFrame:SetSize(450, 220)
    editFrame:SetPoint("CENTER")
    editFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    editFrame:SetMovable(true)
    editFrame:EnableMouse(true)
    editFrame:RegisterForDrag("LeftButton")
    editFrame:SetScript("OnDragStart", editFrame.StartMoving)
    editFrame:SetScript("OnDragStop", editFrame.StopMovingOrSizing)
    
    -- Gestion de la touche ESC
    editFrame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
        end
    end)
    editFrame:SetPropagateKeyboardInput(true)
    editFrame:EnableKeyboard(true)
    
    -- Background (même style que la fenêtre principale)
    editFrame.bg = editFrame:CreateTexture(nil, "BACKGROUND")
    editFrame.bg:SetAllPoints()
    editFrame.bg:SetColorTexture(0, 0, 0, 0.8)
    
    -- Border
    editFrame.border = CreateFrame("Frame", nil, editFrame, "DialogBorderTemplate")
    
    -- Title bar (même style que la fenêtre principale)
    editFrame.titleBg = editFrame:CreateTexture(nil, "ARTWORK")
    editFrame.titleBg:SetPoint("TOPLEFT", 5, -5)
    editFrame.titleBg:SetPoint("TOPRIGHT", -5, -5)
    editFrame.titleBg:SetHeight(25)
    editFrame.titleBg:SetColorTexture(0.2, 0.2, 0.2, 1)
    
    -- Addon icon dans la title bar
    editFrame.icon = editFrame:CreateTexture(nil, "OVERLAY")
    editFrame.icon:SetSize(16, 16)
    editFrame.icon:SetPoint("TOPLEFT", 10, -7)
    editFrame.icon:SetTexture("Interface\\AddOns\\AuberdineExporter\\UI\\Icons\\ab32.png")
    
    -- Title
    editFrame.title = editFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    editFrame.title:SetPoint("TOPLEFT", 30, -12)
    editFrame.title:SetText("Modifier l'ID Compte")
    editFrame.title:SetTextColor(1, 1, 1)
    
    -- Instructions
    local instructions = editFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instructions:SetPoint("TOP", 0, -50)
    instructions:SetText("Format: AB-XXXX-YYYY (ex: AB-1054-YFNJ)")
    instructions:SetTextColor(0.8, 0.8, 0.8)
    
    -- Label pour l'EditBox
    local label = editFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 75, -80)
    label:SetText("ID Compte actuel:")
    label:SetTextColor(0.9, 0.9, 0.9)
    
    -- EditBox pour saisir le nouvel accountKey
    local editBox = CreateFrame("EditBox", nil, editFrame, "InputBoxTemplate")
    editBox:SetSize(300, 32)
    editBox:SetPoint("TOP", 0, -100)
    editBox:SetAutoFocus(true)
    editBox:SetMaxLetters(12)  -- Corrigé : AB-XXXX-YYYY = 12 caractères
    editFrame.editBox = editBox
    
    -- Function pour pré-remplir avec l'accountKey actuel (appelée à chaque affichage)
    editFrame.RefreshAccountKey = function(self)
        if AuberdineExporter and AuberdineExporter.GetOrCreateAccountKey then
            local fullAccountKey = AuberdineExporter:GetOrCreateAccountKey()
            self.editBox:SetText(fullAccountKey)
        end
    end
    
    -- Scripts pour l'EditBox
    editBox:SetScript("OnEscapePressed", function() editFrame:Hide() end)
    
    -- Bouton Valider
    local confirmBtn = CreateFrame("Button", nil, editFrame, "UIPanelButtonTemplate")
    confirmBtn:SetPoint("BOTTOM", -60, 25)
    confirmBtn:SetSize(120, 30)
    confirmBtn:SetText("Valider")
    confirmBtn:SetScript("OnClick", function()
        local newKey = editBox:GetText():upper():gsub("%s+", "")
        if AuberdineExporter and AuberdineExporter.SetAccountKey then
            local success, message = AuberdineExporter:SetAccountKey(newKey)
            if success then
                print("|cff00ff00AuberdineExporter:|r " .. message)
                -- Rafraîchir l'affichage de l'accountKey dans l'interface principale
                if self.mainFrame then
                    self:RefreshAccountKeyDisplay(self.mainFrame)
                end
                editFrame:Hide()
            else
                print("|cffff0000AuberdineExporter:|r " .. message)
                -- Garder la fenêtre ouverte en cas d'erreur pour permettre la correction
            end
        end
    end)
    
    -- Bouton Annuler
    local cancelBtn = CreateFrame("Button", nil, editFrame, "UIPanelButtonTemplate")
    cancelBtn:SetPoint("BOTTOM", 60, 25)
    cancelBtn:SetSize(120, 30)
    cancelBtn:SetText("Annuler")
    cancelBtn:SetScript("OnClick", function() editFrame:Hide() end)
    
    -- Close button (même style que la fenêtre principale)
    editFrame.closeBtn = CreateFrame("Button", nil, editFrame, "UIPanelCloseButton")
    editFrame.closeBtn:SetPoint("TOPRIGHT", -5, -5)
    editFrame.closeBtn:SetScript("OnClick", function() editFrame:Hide() end)
    
    -- Validation sur Entrée
    editBox:SetScript("OnEnterPressed", function()
        confirmBtn:Click()
    end)
    
    return editFrame
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
    frame.title:SetText("Auberdine Exporter v" .. (GetAddOnMetadata("AuberdineExporter", "Version") or "1.5.1"))
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

    -- Bouton Réglages (ancré en bas de la sidebar pour ne pas chevaucher l'arbre des personnages)
    local settingsBtn = CreateFrame("Button", nil, frame.sidebar, "UIPanelButtonTemplate")
    settingsBtn:SetPoint("BOTTOM", 0, 15)
    settingsBtn:SetSize(160, 30)
    settingsBtn:SetText("Réglages")
    settingsBtn:SetScript("OnClick", function()
        AuberdineExporterUI:ToggleSettingsPanel(frame)
    end)

    -- Ajouter la hiérarchie dans la sidebar
    self:CreateSidebarHierarchy(frame.sidebar)
    
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
    
    -- Support molette de souris (vertical uniquement avec 5 cartes par ligne)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        -- Scroll vertical uniquement (plus besoin d'horizontal avec 5 cartes max par ligne)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local newScroll = math.max(0, math.min(maxScroll, current - (delta * 50)))
        self:SetVerticalScroll(newScroll)
    end)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(content)
    
    -- Créer la barre de scroll verticale uniquement (plus besoin d'horizontale)
    self:CreateVerticalScrollBar(scrollFrame, characterArea)
    
    -- Créer l'affichage des cartes personnages
    self:CreateCharacterCardLayout(content, characterArea)
    
    -- Section infos/légende en bas
    self:CreateBottomLegend(characterArea)
    
    -- Stocker les références pour l'actualisation
    characterArea.scrollFrame = scrollFrame
    characterArea.content = content
end

-- Affiche/masque le panneau de réglages (général + suivi de guilde) par-dessus la vue des personnages
function AuberdineExporterUI:ToggleSettingsPanel(frame)
    frame = frame or self.mainFrame
    if not frame or not frame.mainContent then return end
    local mc = frame.mainContent

    -- Déjà ouvert : on referme et on rend la vue des personnages
    if mc.settingsPanel and mc.settingsPanel:IsShown() then
        mc.settingsPanel:Hide()
        if mc.characterContentArea then mc.characterContentArea:Show() end
        return
    end

    -- Construction paresseuse du panneau (une seule fois)
    if not mc.settingsPanel then
        local panel = CreateFrame("Frame", nil, mc)
        panel:SetAllPoints(mc)
        panel:SetFrameLevel(mc:GetFrameLevel() + 10)
        panel.bg = panel:CreateTexture(nil, "BACKGROUND")
        panel.bg:SetAllPoints()
        panel.bg:SetColorTexture(0.05, 0.05, 0.05, 0.97)
        -- Réutilise le constructeur de réglages complet (auto-scan, partage, minimap, guilde)
        self:CreateSettingsTab(panel)
        mc.settingsPanel = panel
    end

    if mc.characterContentArea then mc.characterContentArea:Hide() end
    mc.settingsPanel:Show()
end

-- Fonction pour créer seulement la barre de scroll verticale
function AuberdineExporterUI:CreateVerticalScrollBar(scrollFrame, parent)
    -- BARRE DE SCROLL VERTICALE
    local vScrollBar = CreateFrame("Frame", nil, parent)
    vScrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 16, 0)
    vScrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 16, 0)
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
    
    -- Fonctions de mise à jour et d'interaction de la barre de scroll
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
    
    -- Clic sur la barre pour sauter à une position
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
    
    -- Événements pour la barre de scroll
    scrollFrame:SetScript("OnScrollRangeChanged", UpdateVerticalScrollBar)
    scrollFrame:SetScript("OnVerticalScroll", UpdateVerticalScrollBar)
    
    -- Initialiser l'affichage de la barre
    C_Timer.After(0.1, UpdateVerticalScrollBar)
end

-- Fonction pour créer les barres de scroll (ancienne fonction conservée pour compatibilité)
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
    helpText:SetText("Clic sur groupes = éditer | Coin supérieur droit des cartes = export ON/OFF | 5 cartes par ligne max")
    helpText:SetTextColor(0.7, 0.7, 0.7)
    
    -- ID de compte (cliquable pour édition)
    local accountKey = "AB-????-????"
    if AuberdineExporter and AuberdineExporter.GetOrCreateAccountKey then
        accountKey = AuberdineExporter:GetOrCreateAccountKey()
    end
    
    -- Créer un bouton invisible pour rendre l'accountKey cliquable
    local accountKeyBtn = CreateFrame("Button", nil, bottomFrame)
    accountKeyBtn:SetPoint("TOPLEFT", 10, -55)
    accountKeyBtn:SetSize(250, 16)
    accountKeyBtn:SetScript("OnClick", function()
        local editFrame = AuberdineExporterUI:CreateAccountKeyEditFrame()
        -- Actualiser l'accountKey avant d'afficher la fenêtre
        editFrame:RefreshAccountKey()
        editFrame:Show()
    end)
    accountKeyBtn:SetScript("OnEnter", function(self)
        -- Changer la couleur au survol pour indiquer que c'est cliquable
        if self.text then
            self.text:SetTextColor(1, 1, 0) -- Jaune au survol
        end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Cliquez pour modifier l'ID Compte", 1, 1, 1)
        GameTooltip:AddLine("Utilisé pour lier plusieurs comptes sur le même identifiant", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    accountKeyBtn:SetScript("OnLeave", function(self)
        -- Remettre la couleur normale
        if self.text then
            self.text:SetTextColor(0.7, 0.7, 0.7)
        end
        GameTooltip:Hide()
    end)
    
    -- Texte de l'accountKey
    local accountKeyText = accountKeyBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    accountKeyText:SetPoint("TOPLEFT", 0, 0)
    accountKeyText:SetText("ID Compte: " .. accountKey .. " ".. "(ajustable pour compte multiple)")
    accountKeyText:SetTextColor(0.7, 0.7, 0.7)
    accountKeyBtn.text = accountKeyText
end

-- Fonction pour actualiser l'affichage de l'accountKey
function AuberdineExporterUI:RefreshAccountKeyDisplay(frame)
    if not frame or not frame.mainContent or not frame.mainContent.characterContentArea then
        return
    end
    
    -- Trouver et mettre à jour le texte de l'accountKey
    local function findAccountKeyButton(parent)
        local children = {parent:GetChildren()}
        for _, child in pairs(children) do
            if child.text and child.text:GetText() and child.text:GetText():find("ID Compte:") then
                return child
            end
            -- Recherche récursive
            local found = findAccountKeyButton(child)
            if found then return found end
        end
        return nil
    end
    
    local accountKeyBtn = findAccountKeyButton(frame.mainContent.characterContentArea)
    if accountKeyBtn and accountKeyBtn.text then
        local accountKey = "AB-????-????"
        if AuberdineExporter and AuberdineExporter.GetOrCreateAccountKey then
            accountKey = AuberdineExporter:GetOrCreateAccountKey()
        end
        accountKeyBtn.text:SetText("ID Compte: " .. accountKey .. " (ajustable pour compte multiple)")
    end
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
    
    -- Nettoyer et recréer la hiérarchie dans la sidebar
    if frame.sidebar then
        -- Supprimer les anciens éléments de hiérarchie
        local children = {frame.sidebar:GetChildren()}
        for _, child in pairs(children) do
            if child:GetObjectType() == "FontString" and child:GetText() and child:GetText():find("HIÉRARCHIE") then
                child:Hide()
                child:SetParent(nil)
            end
        end
        
        -- Supprimer les anciennes textures de hiérarchie
        local regions = {frame.sidebar:GetRegions()}
        for _, region in pairs(regions) do
            if region:GetObjectType() == "Texture" and region:GetTexture() then
                region:Hide()
                region:SetParent(nil)
            end
        end
        
        -- Recréer la hiérarchie
        self:CreateSidebarHierarchy(frame.sidebar)
    end
    
    -- Recréer seulement la vue des personnages
    self:CreateUnifiedCharacterView(frame.mainContent)
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

function AuberdineExporterUI:CreateSettingsTab(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    
    local settings = AuberdineExporterDB and AuberdineExporterDB.settings or {
        autoScan = true,
        minimapButtonHidden = false
    }
    local yOffset = -10
    
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, yOffset)
    title:SetText("Réglages")
    title:SetTextColor(1, 1, 0)
    yOffset = yOffset - 40
    
    -- Auto-scan setting
    local autoScanCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    autoScanCheck:SetPoint("TOPLEFT", 10, yOffset)
    autoScanCheck:SetChecked(settings.autoScan)
    autoScanCheck.text:SetText("Scanner les métiers à l'ouverture")
    autoScanCheck:SetScript("OnClick", function(self)
        if AuberdineExporterDB and AuberdineExporterDB.settings then
            AuberdineExporterDB.settings.autoScan = self:GetChecked()
        end
    end)
    
    yOffset = yOffset - 30

    -- Minimap button setting
    local minimapCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", 10, yOffset)
    minimapCheck:SetChecked(not settings.minimapButtonHidden)
    minimapCheck.text:SetText("Afficher le bouton minimap")
    minimapCheck:SetScript("OnClick", function(self)
        local show = self:GetChecked()
        if AuberdineExporterDB and AuberdineExporterDB.settings then
            AuberdineExporterDB.settings.minimapButtonHidden = not show
        end
        if AuberdineMinimapButton and AuberdineMinimapButton.SetVisibility then
            AuberdineMinimapButton:SetVisibility(show)
        end
    end)
    
    yOffset = yOffset - 40

    -- ===== Section Suivi de guilde =====
    local GT = AuberdineExporter and AuberdineExporter.GuildTracker
    local gsettings = GT and GT:GetSettings() or { enabled = true, exportPublicNotes = true, trackNoteChanges = true }

    local guildTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    guildTitle:SetPoint("TOPLEFT", 10, yOffset)
    guildTitle:SetText("Suivi de guilde")
    guildTitle:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 30

    -- Activer le suivi
    local guildEnableCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    guildEnableCheck:SetPoint("TOPLEFT", 10, yOffset)
    guildEnableCheck:SetChecked(gsettings.enabled)
    guildEnableCheck.text:SetText("Activer le suivi de guilde")
    guildEnableCheck:SetScript("OnClick", function(self)
        if GT then GT:GetSettings().enabled = self:GetChecked() and true or false end
    end)
    yOffset = yOffset - 28

    -- Exporter les notes publiques
    local guildNotesCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    guildNotesCheck:SetPoint("TOPLEFT", 10, yOffset)
    guildNotesCheck:SetChecked(gsettings.exportPublicNotes)
    guildNotesCheck.text:SetText("Exporter les notes publiques (décoché = export plus léger)")
    guildNotesCheck:SetScript("OnClick", function(self)
        if GT then GT:GetSettings().exportPublicNotes = self:GetChecked() and true or false end
    end)
    yOffset = yOffset - 28

    -- Taille max du journal (rétention configurable)
    local maxLogLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    maxLogLabel:SetPoint("TOPLEFT", 14, yOffset - 4)
    maxLogLabel:SetText("Taille max du journal par guilde :")
    maxLogLabel:SetTextColor(0.9, 0.9, 0.9)

    local maxLogBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    maxLogBox:SetSize(70, 20)
    maxLogBox:SetPoint("TOPLEFT", 240, yOffset)
    maxLogBox:SetAutoFocus(false)
    maxLogBox:SetNumeric(true)
    maxLogBox:SetMaxLetters(6)
    local curMax = (gsettings.maxLog and gsettings.maxLog > 0) and gsettings.maxLog or 1000
    maxLogBox:SetText(tostring(curMax))
    local function commitMaxLog(self)
        local v = tonumber(self:GetText()) or 1000
        if v < 50 then v = 50 end
        if v > 50000 then v = 50000 end
        self:SetText(tostring(v))
        if GT then GT:GetSettings().maxLog = v end
        self:ClearFocus()
    end
    maxLogBox:SetScript("OnEnterPressed", commitMaxLog)
    maxLogBox:SetScript("OnEditFocusLost", commitMaxLog)
    maxLogBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local maxLogHint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    maxLogHint:SetPoint("TOPLEFT", 318, yOffset - 4)
    maxLogHint:SetText("(50 à 50000, Entrée pour valider)")
    yOffset = yOffset - 32

    -- Liste des guildes connues + case "Partager"
    local guildsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    guildsLabel:SetPoint("TOPLEFT", 14, yOffset)
    guildsLabel:SetText("Guildes partagées :")
    guildsLabel:SetTextColor(0.8, 0.8, 0.8)
    yOffset = yOffset - 22

    local tracked = GT and GT:GetTrackedGuilds() or {}
    if #tracked == 0 then
        local none = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        none:SetPoint("TOPLEFT", 26, yOffset)
        none:SetText("Aucune guilde détectée pour l'instant (connectez-vous en guilde).")
        yOffset = yOffset - 22
    else
        local maxRows = 6
        for i = 1, math.min(#tracked, maxRows) do
            local gi = tracked[i]
            local row = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
            row:SetPoint("TOPLEFT", 20, yOffset)
            row:SetChecked(gi.share)
            row.text:SetText(string.format("%s  |cff888888(%d membres · ~%.1f KB)|r",
                gi.name, gi.memberCount, gi.estBytes / 1024))
            local key = gi.key
            row:SetScript("OnClick", function(self)
                if GT then GT:SetShare(key, self:GetChecked() and true or false) end
            end)

            -- Bouton "Vider le journal" de cette guilde
            local clearLogBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
            clearLogBtn:SetPoint("TOPLEFT", 360, yOffset + 1)
            clearLogBtn:SetSize(70, 20)
            clearLogBtn:SetText("Vider")
            clearLogBtn:SetScript("OnClick", function()
                StaticPopup_Show("AUBERDINE_GUILD_CLEAR_LOG", gi.name, nil, { key = key, name = gi.name })
            end)
            yOffset = yOffset - 24
        end
        if #tracked > maxRows then
            local more = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            more:SetPoint("TOPLEFT", 26, yOffset)
            more:SetText(string.format("... +%d autres (voir /auberdine guild list)", #tracked - maxRows))
            yOffset = yOffset - 22
        end
    end

    -- Bouton resync complet
    local resyncBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resyncBtn:SetPoint("TOPLEFT", 20, yOffset)
    resyncBtn:SetSize(240, 22)
    resyncBtn:SetText("Forcer un export complet (resync)")
    resyncBtn:SetScript("OnClick", function()
        if GT then
            GT:RequestFullResync()
            print("|cff00ff00AuberdineExporter|r |cffffd200[Guilde]|r Prochain export forcé en mode complet.")
        end
    end)
    yOffset = yOffset - 40

    -- Reset button
    local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", 10, yOffset)
    resetBtn:SetSize(150, 25)
    resetBtn:SetText("Tout réinitialiser")
    resetBtn:SetScript("OnClick", function()
        StaticPopup_Show("AUBERDINE_EXPORTER_RESET_CONFIRM")
    end)
    
    -- Clear Memory Data button
    local clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearBtn:SetPoint("TOPLEFT", 170, yOffset)
    clearBtn:SetSize(180, 25)
    clearBtn:SetText("Vider la mémoire")
    clearBtn:SetScript("OnClick", function()
        StaticPopup_Show("AUBERDINE_EXPORTER_CLEAR_CONFIRM")
    end)
    
    yOffset = yOffset - 40
    
    yOffset = yOffset - 40
    
    -- Data size info
    local sizeInfoBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    sizeInfoBtn:SetPoint("TOPLEFT", 10, yOffset)
    sizeInfoBtn:SetSize(180, 25)
    sizeInfoBtn:SetText("Taille des données")
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
    resetMinimapBtn:SetText("Réinit. position minimap")
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

-- Récupère l'EditBox d'un StaticPopup de façon robuste.
-- Dans les clients récents (Classic ERA 11508+), Blizzard wrap StaticPopup
-- avec GameDialog et `self.editBox` n'est plus toujours directement exposé.
local function GetPopupEditBox(popup)
    if not popup then return nil end
    if popup.editBox then return popup.editBox end
    if popup.GetEditBox then
        local ok, eb = pcall(popup.GetEditBox, popup)
        if ok and eb then return eb end
    end
    -- Fallback : chercher un EditBox parmi les enfants directs
    if popup.GetNumChildren then
        for i = 1, popup:GetNumChildren() do
            local child = select(i, popup:GetChildren())
            if child and child.GetObjectType and child:GetObjectType() == "EditBox" then
                return child
            end
        end
    end
    return nil
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
        local editBox = GetPopupEditBox(self)
        if editBox then
            if data and data.currentGroup then
                editBox:SetText(data.currentGroup)
                editBox:HighlightText()
            else
                editBox:SetText("")
            end
        end
    end,
    OnAccept = function(self, data)
        local editBox = GetPopupEditBox(self)
        local newGroup = editBox and editBox:GetText() or nil
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
        local parent = self:GetParent()
        if parent then StaticPopup_OnClick(parent, 1) end
    end,
    EditBoxOnEscapePressed = function(self)
        local parent = self:GetParent()
        if parent then parent:Hide() end
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

-- Static popup pour effacer le journal d'une guilde
StaticPopupDialogs["AUBERDINE_GUILD_CLEAR_LOG"] = {
    text = "Effacer le journal d'activité de la guilde « %s » ?\n\nLe roster est conservé ; seul l'historique des événements est supprimé.",
    button1 = "Effacer",
    button2 = "Annuler",
    OnAccept = function(self, data)
        local GT = AuberdineExporter and AuberdineExporter.GuildTracker
        if GT and data and data.key then
            GT:ClearLogByKey(data.key)
            print("|cff00ff00AuberdineExporter|r |cffffd200[Guilde]|r Journal de « " .. (data.name or data.key) .. " » effacé.")
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

-- Static popup for character deletion confirmation
StaticPopupDialogs["AUBERDINE_EXPORTER_DELETE_CHAR_CONFIRM"] = {
    text = "ATTENTION : Supprimer définitivement le personnage '%s' ?\n\n|cffff0000Cette action est IRRÉVERSIBLE !|r\n\nToutes les données (recettes, skills, réputations) seront perdues.\n\nPour simplement désactiver l'export, utilisez le bouton vert/rouge.",
    button1 = "SUPPRIMER",
    button2 = "Annuler",
    OnAccept = function(self)
        local data = self.data
        if data and data.callback then
            data.callback()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Fonction pour afficher la confirmation de suppression de personnage
function AuberdineExporterUI:ShowDeleteConfirmation(charKey, charName, callback)
    if not charKey or not charName or not callback then
        print("|cffff0000AuberdineExporter:|r Erreur - Données manquantes pour la suppression")
        return
    end
    
    local popupData = {
        charKey = charKey,
        charName = charName,
        callback = callback
    }
    
    StaticPopup_Show("AUBERDINE_EXPORTER_DELETE_CHAR_CONFIRM", charName, nil, popupData)
end

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
    frame.title:SetText("Aide - Auberdine Exporter v" .. (GetAddOnMetadata("AuberdineExporter", "Version") or "1.5.1"))
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
        "|cffffcc00=== INTERFACE UNIFIÉE v1.5.1 ===|r\n\n" ..
        
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
        "• |cffccccccLignes de connexion|r : Montrent la hiérarchie Main→Alt→Banque\n" ..
        "• |cffccccccAffichage multi-lignes|r : 5 cartes maximum par ligne\n\n" ..
        
        "|cff77ff77[>] NAVIGATION|r\n" ..
        "• |cffccccccMolette souris|r : Scroll vertical\n" ..
        "• |cffccccccGlisser barre|r : Positionnement précis\n" ..
        "• |cffccccccClic sur barre|r : Saut rapide à une position\n\n" ..
        
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
    
    -- Dimensions des cartes (réduites) - Option 2
    local cardWidth = 120
    local cardHeight = 100           -- v1.5.0 : bumpé pour accueillir le compteur quêtes sous le dropdown
    local cardSpacing = 10
    local levelSpacing = 110         -- = cardHeight + cardSpacing (conserve le gap visuel)
    local cardsPerRow = 5  -- Nombre maximum de cartes par ligne
    
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
        
        -- Créer une bordure simple avec des textures (bordures fines)
        card.borderTop = card.border:CreateTexture(nil, "OVERLAY")
        card.borderTop:SetPoint("TOPLEFT", 0, 0)
        card.borderTop:SetPoint("TOPRIGHT", 0, 0)
        card.borderTop:SetHeight(1)
        card.borderTop:SetColorTexture(1, 1, 1, 0.8)
        
        card.borderBottom = card.border:CreateTexture(nil, "OVERLAY")
        card.borderBottom:SetPoint("BOTTOMLEFT", 0, 0)
        card.borderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
        card.borderBottom:SetHeight(1)
        card.borderBottom:SetColorTexture(1, 1, 1, 0.8)
        
        card.borderLeft = card.border:CreateTexture(nil, "OVERLAY")
        card.borderLeft:SetPoint("TOPLEFT", 0, 0)
        card.borderLeft:SetPoint("BOTTOMLEFT", 0, 0)
        card.borderLeft:SetWidth(1)
        card.borderLeft:SetColorTexture(1, 1, 1, 0.8)
        
        card.borderRight = card.border:CreateTexture(nil, "OVERLAY")
        card.borderRight:SetPoint("TOPRIGHT", 0, 0)
        card.borderRight:SetPoint("BOTTOMRIGHT", 0, 0)
        card.borderRight:SetWidth(1)
        card.borderRight:SetColorTexture(1, 1, 1, 0.8)
        
        -- Nom du personnage
        card.nameText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        card.nameText:SetPoint("TOP", 0, -6)
        card.nameText:SetText(charInfo.data.name)
        card.nameText:SetTextColor(1, 1, 1)
        
        -- Détails du personnage avec clé de groupe (texte optimisé)
        card.detailsText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        card.detailsText:SetPoint("TOP", 0, -18)
        card.detailsText:SetText(string.format("Niv %d %s", charInfo.data.level, charInfo.data.class))
        card.detailsText:SetTextColor(0.9, 0.9, 0.9)
        
        -- Affichage du groupe (cliquable pour éditer)
        card.groupText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        card.groupText:SetPoint("TOP", 0, -30)
        local groupName = charInfo.settings.accountGroup or (AuberdineExporterDB.accountGroup or "Groupe-Auto")
        card.groupText:SetText("G: " .. groupName)
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
        
        -- Dropdown pour le rôle (centré dans la carte)
        -- Note : UIDropDownMenuTemplate ajoute ~25px de marges internes autour
        -- de la largeur "utile". On vise une largeur totale < cardWidth (120)
        -- pour que le menu reste contenu et centré dans la carte.
        card.roleDropdown = CreateFrame("Frame", nil, card, "UIDropDownMenuTemplate")
        card.roleDropdown:SetPoint("TOP", 0, -44)

        -- Largeur utile 78 -> largeur totale ~103px, centrée dans une carte de 120px
        UIDropDownMenu_SetWidth(card.roleDropdown, 78)
        card.roleDropdown:SetHeight(24)
        if card.roleDropdown.Text then
            card.roleDropdown.Text:SetJustifyH("CENTER")
        end
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
        
        -- Compteur quêtes terminées (v1.5.0) — positionné sous le dropdown rôle.
        local questCountInit = 0
        for _ in pairs(charInfo.data.completedQuests or {}) do
            questCountInit = questCountInit + 1
        end
        card.questText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        -- Ancré BOTTOM pour être robuste à la vraie hauteur du dropdown (le template
        -- UIDropDownMenuTemplate a des textures décoratives qui débordent de sa
        -- height déclarée de 18px — visuellement ~30px).
        card.questText:SetPoint("BOTTOM", 0, 6)
        card.questText:SetText(string.format("Quêtes : %d", questCountInit))
        card.questText:SetTextColor(0.7, 0.85, 1)

        -- Indicateur d'export (taille ajustée)
        card.exportIcon = card:CreateTexture(nil, "OVERLAY")
        card.exportIcon:SetSize(10, 10)
        card.exportIcon:SetPoint("TOPRIGHT", -4, -4)
        if charInfo.settings.exportEnabled ~= false then
            card.exportIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        else
            card.exportIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
        end
        
        -- Bouton toggle export (taille ajustée)
        card.exportBtn = CreateFrame("Button", nil, card)
        card.exportBtn:SetSize(14, 14)
        card.exportBtn:SetPoint("TOPRIGHT", -4, -4)
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
        
        -- Bouton de suppression (croix rouge)
        card.deleteIcon = card:CreateTexture(nil, "OVERLAY")
        card.deleteIcon:SetSize(12, 12)
        card.deleteIcon:SetPoint("TOPRIGHT", -20, -4)
        card.deleteIcon:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
        card.deleteIcon:SetVertexColor(1, 0.3, 0.3) -- Rouge
        
        card.deleteBtn = CreateFrame("Button", nil, card)
        card.deleteBtn:SetSize(16, 16)
        card.deleteBtn:SetPoint("TOPRIGHT", -20, -4)
        card.deleteBtn:SetScript("OnClick", function()
            -- Demander confirmation avant suppression
            AuberdineExporterUI:ShowDeleteConfirmation(charInfo.key, charInfo.data.name, function()
                if DeleteCharacter then
                    DeleteCharacter(charInfo.key)
                    -- Actualiser l'affichage
                    C_Timer.After(0.1, function()
                        if parentFrame and parentFrame.UpdateContent then
                            parentFrame.UpdateContent()
                        elseif AuberdineExporterUI and AuberdineExporterUI.mainFrame then
                            AuberdineExporterUI:RefreshCharacterView(AuberdineExporterUI.mainFrame)
                        end
                    end)
                end
            end)
        end)
        card.deleteBtn:SetScript("OnEnter", function()
            card.deleteIcon:SetVertexColor(1, 0.1, 0.1) -- Rouge plus intense au survol
        end)
        card.deleteBtn:SetScript("OnLeave", function()
            card.deleteIcon:SetVertexColor(1, 0.3, 0.3) -- Rouge normal
        end)

        -- Tooltip détaillé au hover de la carte (v1.5.0 : expose le détail
        -- quêtes/métiers/recettes sans rajouter de lignes sur le layout compact).
        card:EnableMouse(true)
        card:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(charInfo.data.name, 1, 1, 1)
            GameTooltip:AddLine(string.format("Niv %d %s %s",
                charInfo.data.level or 0,
                charInfo.data.race or "?",
                charInfo.data.class or "?"), 0.9, 0.9, 0.9)

            -- Quêtes terminées
            local questCount = 0
            for _ in pairs(charInfo.data.completedQuests or {}) do
                questCount = questCount + 1
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(string.format("Quêtes terminées : %d", questCount), 0.7, 0.85, 1)

            -- Métiers et recettes
            local profCount, recipeTotal = 0, 0
            for profName, profData in pairs(charInfo.data.professions or {}) do
                profCount = profCount + 1
                local rc = 0
                for _ in pairs(profData.recipes or {}) do rc = rc + 1 end
                recipeTotal = recipeTotal + rc
                GameTooltip:AddLine(string.format("  %s : %d/%d (%d recettes)",
                    profData.name or profName,
                    profData.level or 0, profData.maxLevel or 0, rc), 0.5, 1, 0.5)
            end
            if profCount == 0 then
                GameTooltip:AddLine("Aucun métier scanné", 0.6, 0.6, 0.6)
            end

            -- Dernière màj
            if charInfo.data.lastUpdate then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Dernière mise à jour : " ..
                    date("%Y-%m-%d %H:%M", charInfo.data.lastUpdate), 0.6, 0.6, 0.6)
            end

            GameTooltip:Show()
        end)
        card:SetScript("OnLeave", function()
            GameTooltip:Hide()
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
            typeLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 20, currentY)
            
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
            
            -- Afficher les cartes pour ce type avec gestion multi-lignes
            local startX = 20 -- Position X de départ pour les cartes (plus d'arborescence dans la zone principale)
            local currentRow = 0
            local cardsInCurrentRow = 0
            
            for i, charInfo in ipairs(chars) do
                -- Calculer position X et Y pour cette carte
                local cardX = startX + cardsInCurrentRow * (cardWidth + 10)
                local cardY = currentY - (currentRow * (cardHeight + 10))
                
                local card = CreateCharacterCard(content, charInfo, cardX, cardY)
                maxWidth = math.max(maxWidth, cardX + cardWidth)
                
                cardsInCurrentRow = cardsInCurrentRow + 1
                
                -- Passer à la ligne suivante si on atteint le maximum par ligne
                if cardsInCurrentRow >= cardsPerRow then
                    cardsInCurrentRow = 0
                    currentRow = currentRow + 1
                end
            end
            
            -- Calculer l'espace nécessaire pour ce type (nombre de lignes)
            local totalRows = currentRow + (cardsInCurrentRow > 0 and 1 or 0)
            currentY = currentY - (totalRows * (cardHeight + 10)) - 20 -- Espace après les cartes
        end
    end
    
    -- Créer une table vide pour placedCards (optionnel pour la nouvelle arborescence)
    local placedCards = {}
    
    -- Calculer la largeur optimale selon le nombre maximum de cartes par ligne (sans arborescence)
    local minWidthNeeded = 20 + (cardsPerRow * cardWidth) + ((cardsPerRow - 1) * 10) + 20 -- Marges simplifiées
    maxWidth = math.max(maxWidth, minWidthNeeded)
    
    -- Définir la taille du content pour le scroll (largeur fixe, plus besoin de scroll horizontal)
    content:SetHeight(math.abs(currentY) + 100)  -- Utiliser la valeur absolue de currentY qui est négatif
    content:SetWidth(minWidthNeeded)  -- Largeur fixe calculée pour 5 cartes par ligne
end

-- Fonction pour créer la hiérarchie dans la sidebar
function AuberdineExporterUI:CreateSidebarHierarchy(sidebar)
    -- Récupérer les données des personnages pour l'affichage
    if not AuberdineExporterDB or not AuberdineExporterDB.characters then
        return
    end
    
    -- Organiser les personnages par type (même logique que dans CreateCharacterCardLayout)
    local charactersGrouped = {main = {}, alt = {}, bank = {}, mule = {}}
    
    for charKey, charData in pairs(AuberdineExporterDB.characters) do
        local charSettings = InitializeCharacterSettings and InitializeCharacterSettings(charKey) or {}
        local charType = charSettings.characterType or "main"
        
        if charType == "main" then
            table.insert(charactersGrouped.main, {key = charKey, data = charData})
        elseif charType == "alt" then
            table.insert(charactersGrouped.alt, {key = charKey, data = charData})
        elseif charType == "bank" then
            table.insert(charactersGrouped.bank, {key = charKey, data = charData})
        elseif charType == "mule" then
            table.insert(charactersGrouped.mule, {key = charKey, data = charData})
        end
    end
    
    -- Titre de la hiérarchie
    local treeTitle = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    treeTitle:SetPoint("TOP", 0, -240)
    treeTitle:SetText("|cffaaaaff[HIÉRARCHIE]|r")
    treeTitle:SetTextColor(0.7, 0.7, 0.7)
    
    -- Ligne principale verticale (positionnée juste sous le titre)
    local mainTreeLine = sidebar:CreateTexture(nil, "ARTWORK")
    mainTreeLine:SetColorTexture(0.6, 0.6, 0.6, 0.8)
    mainTreeLine:SetWidth(2)
    mainTreeLine:SetPoint("TOPLEFT", treeTitle, "BOTTOMLEFT", -20, -5)
    
    -- Créer des indicateurs pour chaque niveau avec des personnages
    local yOffset = -15  -- Commencer plus près du titre
    local levels = {"main", "alt", "bank", "mule"}
    local levelNames = {
        main = "|cff4488ff MAINS|r",
        alt = "|cffaa44ff ALTS|r", 
        bank = "|cffffaa44 BANQUES|r",
        mule = "|cffff8844 MULES|r"
    }
    
    local itemCount = 0
    local firstItemY = 0
    local lastItemY = 0
    
    for i, level in ipairs(levels) do
        if charactersGrouped[level] and #charactersGrouped[level] > 0 then
            -- Enregistrer la position du premier et dernier élément
            if itemCount == 0 then
                firstItemY = yOffset
            end
            lastItemY = yOffset
            
            -- Branche horizontale courte (positionnée relativement au titre, pas à la ligne)
            local branch = sidebar:CreateTexture(nil, "ARTWORK")
            branch:SetColorTexture(0.6, 0.6, 0.6, 0.8)
            branch:SetHeight(1)
            branch:SetWidth(12)
            branch:SetPoint("TOPLEFT", treeTitle, "BOTTOMLEFT", -20, yOffset + 2)
            
            -- Étiquette du niveau avec compteur (positionnée relativement au titre)
            local label = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            label:SetPoint("TOPLEFT", treeTitle, "BOTTOMLEFT", -5, yOffset)
            label:SetText(levelNames[level] .. " (" .. #charactersGrouped[level] .. ")")
            label:SetTextColor(0.8, 0.8, 0.8)
            
            yOffset = yOffset - 18
            itemCount = itemCount + 1
        end
    end
    
    -- Ajuster la hauteur de la ligne principale selon les positions réelles
    -- Maintenant que les textes sont fixes, calculer la hauteur exacte nécessaire
    local totalHeight = math.max(math.abs(firstItemY - lastItemY) + 10, 25)
    mainTreeLine:SetHeight(totalHeight)
end

-- Fonction pour créer l'arborescence latérale (ancienne version, conservée pour compatibilité)
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
        main = "|cff4488ff MAINS|r",
        alt = "|cffaa44ff ALTS|r", 
        bank = "|cffffaa44 BANQUES|r",
        mule = "|cffff8844 MULES|r"
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
