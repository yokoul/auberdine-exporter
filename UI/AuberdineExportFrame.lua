-- Export UI for RecipesExtractor
RecipesExtractorExportUI = {}

function RecipesExtractorExportUI:ShowExportFrame(exportType)
    if self.exportFrame then
        self.exportFrame:Hide()
        self.exportFrame = nil
    end
    
    -- Create export frame
    local frame = CreateFrame("Frame", "RecipesExtractorExportFrame", UIParent)
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
    frame.icon:SetTexture("Interface\\AddOns\\RecipesExtractor\\UI\\Icons\\rc32.png")
    
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 30, -12)  -- Adjusted for icon
    frame.title:SetText("Export Data - " .. string.upper(exportType))
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
    infoText:SetText("Select all text below and copy it (Ctrl+C):")
    infoText:SetTextColor(1, 1, 0)
    
    -- Copy All button
    local copyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    copyBtn:SetPoint("TOPRIGHT", -15, -35)
    copyBtn:SetSize(100, 25)
    copyBtn:SetText("Select All")
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
        instructions:SetText("This format is optimized for web integration. Copy the text and paste it on your website.")
    elseif exportType == "csv" then
        instructions:SetText("This CSV format can be imported into Excel, Google Sheets, or other spreadsheet applications.")
    else
        instructions:SetText("This JSON format contains all recipe data and can be processed by external tools.")
    end
    
    self.exportFrame = frame
    frame:Show()
    
    -- Auto-select text after a brief delay
    C_Timer.After(0.1, function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)
end

function RecipesExtractorExportUI:GenerateExportData(exportType)
    if exportType == "json" then
        return RecipesExtractorDataManager:GenerateJSONExport()
    elseif exportType == "csv" then
        return RecipesExtractorDataManager:GenerateCSVExport()
    elseif exportType == "web" then
        return RecipesExtractorDataManager:GenerateWebExport()
    else
        return "Unknown export type: " .. tostring(exportType)
    end
end
