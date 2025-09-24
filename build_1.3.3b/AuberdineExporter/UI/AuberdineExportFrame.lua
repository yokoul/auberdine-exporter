-- Export UI for AuberdineExporter
AuberdineExportUI = {}

function AuberdineExportUI:ShowExportFrame(exportType)
    if self.exportFrame then
        self.exportFrame:Hide()
        self.exportFrame = nil
    end
    
    -- Create export frame
    local frame = CreateFrame("Frame", "AuberdineExportFrame", UIParent)
    frame:SetSize(700, 600)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    -- Background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0, 0, 0, 0.9)
    
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
    frame.title:SetText("Export Données - " .. string.upper(exportType))
    frame.title:SetTextColor(1, 1, 1)
    
    -- Close button
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetPoint("TOPRIGHT", -5, -5)
    frame.closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Generate export data
    local exportData = self:GenerateExportData(exportType)
    
    -- Info text
    local infoText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    infoText:SetPoint("TOPLEFT", 15, -40)
    infoText:SetText("Sélectionnez tout le texte ci-dessous et copiez-le (Ctrl+C) :")
    infoText:SetTextColor(1, 1, 0)
    
    -- Copy All button
    local copyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    copyBtn:SetPoint("TOPRIGHT", -15, -35)
    copyBtn:SetSize(100, 25)
    copyBtn:SetText("Tout Sélectionner")
    copyBtn:SetScript("OnClick", function()
        frame.scrollFrame.editBox:SetFocus()
        frame.scrollFrame.editBox:HighlightText()
    end)
    
    -- Scroll frame for export data
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 15, -70)
    scrollFrame:SetPoint("BOTTOMRIGHT", -35, 15)
    
    -- Edit box for export data
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(scrollFrame:GetWidth() - 20)
    editBox:SetAutoFocus(false)
    editBox:SetText(exportData)
    editBox:SetCursorPosition(0)
    
    -- Calculate height based on content
    local fontHeight = select(2, editBox:GetFont()) or 12
    local numLines = 1
    for _ in string.gmatch(exportData, "\n") do
        numLines = numLines + 1
    end
    local contentHeight = numLines * (fontHeight + 2)
    editBox:SetHeight(math.max(contentHeight, scrollFrame:GetHeight()))
    
    scrollFrame:SetScrollChild(editBox)
    scrollFrame.editBox = editBox
    frame.scrollFrame = scrollFrame
    
    -- Instructions at bottom
    local instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    instructions:SetPoint("BOTTOMLEFT", 15, 5)
    instructions:SetPoint("BOTTOMRIGHT", -15, 5)
    instructions:SetJustifyH("LEFT")
    instructions:SetTextColor(0.8, 0.8, 0.8)
    
    if exportType == "web" then
        instructions:SetText("Ce format est optimisé pour l'intégration web. Copiez le texte et collez-le sur votre site web.")
    elseif exportType == "csv" then
        instructions:SetText("Ce format CSV peut être importé dans Excel, Google Sheets, ou d'autres applications de tableur.")
    else
        instructions:SetText("Ce format JSON contient toutes les données de recettes et peut être traité par des outils externes.")
    end
    
    self.exportFrame = frame
    frame:Show()
    
    -- Auto-select text after a brief delay
    C_Timer.After(0.1, function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)
end

function AuberdineExportUI:GenerateExportData(exportType)
    if exportType == "json" then
        return ExportToJSON and ExportToJSON() or "Fonction d'export non disponible"
    elseif exportType == "csv" then
        return ExportToCSV and ExportToCSV() or "Fonction d'export CSV non disponible"
    elseif exportType == "web" then
        return ExportToSimpleJSON and ExportToSimpleJSON() or "Fonction d'export web non disponible"
    else
        return "Type d'export inconnu: " .. tostring(exportType)
    end
end
