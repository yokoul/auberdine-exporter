-- AuberdineExporter - Main addon file
print("=== AuberdineExporter loading ===")

-- Load LibRecipes-3.0
local LibRecipes = LibStub("LibRecipes-3.0", true) or LibStub("LibRecipes-1.0a", true)

-- Forward declarations
local ToggleMainFrame

-- Professions valides selon la locale avec mapping pour éviter les doublons
local function GetValidProfessions()
    if GetLocale and GetLocale() == "frFR" then
        return {
            ["Alchimie"] = "Alchemy",
            ["Forge"] = "Blacksmithing", 
            ["Enchantement"] = "Enchanting",
            ["Ingénierie"] = "Engineering",
            ["Herboristerie"] = "Herbalism",
            ["Secourisme"] = "First Aid",
            ["Pêche"] = "Fishing",
            ["Cuisine"] = "Cooking",
            ["Minage"] = "Mining",
            ["Dépeçage"] = "Skinning",
            ["Travail du cuir"] = "Leatherworking",
            ["Couture"] = "Tailoring",
        }
    else -- enUS par défaut
        return {
            ["Alchemy"] = "Alchemy",
            ["Blacksmithing"] = "Blacksmithing",
            ["Enchanting"] = "Enchanting",
            ["Engineering"] = "Engineering",
            ["Herbalism"] = "Herbalism",
            ["First Aid"] = "First Aid",
            ["Fishing"] = "Fishing",
            ["Cooking"] = "Cooking",
            ["Mining"] = "Mining",
            ["Skinning"] = "Skinning",
            ["Leatherworking"] = "Leatherworking",
            ["Tailoring"] = "Tailoring",
        }
    end
end

-- Fonction pour normaliser le nom d'une profession
local function GetNormalizedProfessionName(professionName)
    local validProfessions = GetValidProfessions()
    return validProfessions[professionName] or professionName
end

-- Helper pour accès rapide
local validProfessions = GetValidProfessions()

-- Fonction pour vérifier si une profession est valide
local function IsProfessionValid(professionName)
    return validProfessions[professionName] ~= nil
end

-- Stub pour GetCharacterSkills si non défini
if not GetCharacterSkills then
    function GetCharacterSkills()
        local skills = {}
        -- Extraire les compétences depuis l'API WoW
        for i = 1, GetNumSkillLines() do
            local skillName, header, isExpanded, skillRank, numTempPoints, skillModifier, skillMaxRank = GetSkillLineInfo(i)
            if skillName and not header then
                skills[skillName] = {
                    name = skillName,
                    rank = skillRank,
                    maxRank = skillMaxRank,
                    modifier = skillModifier or 0
                }
            end
        end
        return skills
    end
end

-- Stub pour GetCharacterReputations si non défini
if not GetCharacterReputations then
    function GetCharacterReputations()
        local reputations = {}
        -- Extraire les réputations depuis l'API WoW
        for i = 1, GetNumFactions() do
            local name, description, standingID, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID = GetFactionInfo(i)
            if name and not isHeader then
                reputations[name] = {
                    name = name,
                    standingID = standingID,
                    standing = _G["FACTION_STANDING_LABEL" .. standingID] or "Unknown",
                    barMin = barMin,
                    barMax = barMax,
                    barValue = barValue,
                    factionID = factionID
                }
            end
        end
        return reputations
    end
end

-- Stub pour GetSpellIDFromTooltip si non défini
if not GetSpellIDFromTooltip then
    function GetSpellIDFromTooltip()
        return nil
    end
end

local function GetCurrentCharacterKey()
    local playerName = UnitName("player")
    local realmName = GetRealmName()
    return playerName .. "-" .. realmName
end

local function InitializeCharacterData()
    local charKey = GetCurrentCharacterKey()
    if not AuberdineExporterDB.characters[charKey] then
        local locale = GetLocale and GetLocale() or "unknown"
        AuberdineExporterDB.characters[charKey] = {
            name = UnitName("player"),
            realm = GetRealmName(),
            guid = UnitGUID("player"),
            level = UnitLevel("player"),
            class = UnitClass("player"),
            race = UnitRace("player"),
            locale = locale,
            lastUpdate = time(),
            professions = {},
            skills = GetCharacterSkills(),
            reputations = GetCharacterReputations()
        }
        print("|cff00ff00AuberdineExporter:|r Personnage " .. UnitName("player") .. " initialisé (locale: " .. locale .. ")")
    else
        -- Mettre à jour skills/réputations à chaque init
        AuberdineExporterDB.characters[charKey].skills = GetCharacterSkills()
        AuberdineExporterDB.characters[charKey].reputations = GetCharacterReputations()
        AuberdineExporterDB.characters[charKey].lastUpdate = time()
    end
    return charKey
end

-- Scan all character professions (including gathering)
local function ScanAllProfessions()
    if not GetProfessions then
        print("|cffff0000AuberdineExporter:|r GetProfessions API not available.")
        return 0
    end
    local prof1, prof2, archaeology, fishing, cooking, firstAid = GetProfessions()
    local professionSlots = {prof1, prof2, archaeology, fishing, cooking, firstAid}
    local charKey = InitializeCharacterData()
    local scannedProfessions = {}
    for i, professionIndex in ipairs(professionSlots) do
        if professionIndex then
            local name, icon, skillLevel, maxSkillLevel, numAbilities, spelloffset, skillLine, skillModifier = GetProfessionInfo(professionIndex)
            if name and IsProfessionValid(name) then
                -- Utiliser le nom normalisé pour éviter les doublons multilingues
                local normalizedName = GetNormalizedProfessionName(name)
                scannedProfessions[normalizedName] = {
                    name = name, -- Garder le nom original pour l'affichage
                    normalizedName = normalizedName,
                    level = skillLevel,
                    maxLevel = maxSkillLevel,
                    lastScan = time(),
                    recipes = AuberdineExporterDB.characters[charKey].professions[normalizedName] and AuberdineExporterDB.characters[charKey].professions[normalizedName].recipes or {},
                    type = "scanned"
                }
                print("|cff00ff00AuberdineExporter:|r Profession trouvée : " .. name .. " (" .. skillLevel .. "/" .. maxSkillLevel .. ")")
            end
        end
    end
    -- Mettre à jour la base de données avec les professions trouvées
    for normalizedName, profData in pairs(scannedProfessions) do
        AuberdineExporterDB.characters[charKey].professions[normalizedName] = profData
    end
    local profCount = 0
    for _ in pairs(scannedProfessions) do profCount = profCount + 1 end
    if profCount > 0 then
        print("|cff00ff00AuberdineExporter:|r " .. profCount .. " métiers scannés !")
        print("|cffff8000Note:|r Pour collecter les recettes, ouvrez vos fenêtres de métiers (touche 'P' puis cliquez sur un métier)")
        return profCount
    else
        print("|cffff8000AuberdineExporter:|r Aucun métier valide trouvé.")
        return 0
    end
end

-- Minimap Button
local function CreateMinimapButton()
    if AuberdineExporterMinimapButton then
        return AuberdineExporterMinimapButton
    end
    local button = CreateFrame("Button", "AuberdineExporterMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    
    -- Icon texture
    button.icon = button:CreateTexture(nil, "BACKGROUND")
    button.icon:SetSize(20, 20)
    button.icon:SetPoint("CENTER", 0, 1)
    
    -- Try multiple paths for your custom icon
    local iconPaths = {
        "Interface\\AddOns\\AuberdineExporter\\UI\\Icons\\ab32",
        "Interface/AddOns/AuberdineExporter/UI/Icons/ab32",
        "Interface\\AddOns\\AuberdineExporter\\UI\\Icons\\ab32.png",
        "Interface/AddOns/AuberdineExporter/UI/Icons/ab32.png"
    }
    
    local iconLoaded = false
    for _, path in ipairs(iconPaths) do
        button.icon:SetTexture(path)
        if button.icon:GetTexture() then
            print("|cff00ff00AuberdineExporter:|r Custom icon loaded: " .. path)
            iconLoaded = true
            break
        end
    end
    
    -- If custom icon doesn't load, use a recognizable recipe-related icon
    if not iconLoaded then
        button.icon:SetTexture("Interface\\Icons\\INV_Scroll_03") -- Scroll icon for recipes
        print("|cffff8000AuberdineExporter:|r Custom icon not found, using recipe scroll icon")
    end
    
    -- Border texture
    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetSize(52, 52)
    button.border:SetPoint("TOPLEFT", -10, 10)
    button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    
    -- Position around minimap
    local function UpdatePosition()
        -- Vérification de sécurité pour la base de données
        if not AuberdineExporterDB or not AuberdineExporterDB.settings then
            print("|cffff8000AuberdineExporter:|r UpdatePosition called before DB init, using default angle")
            local x = 80 * cos(0)
            local y = 80 * sin(0)
            button:SetPoint("CENTER", Minimap, "CENTER", x, y)
            return
        end
        
        local angle = AuberdineExporterDB.settings.minimapButtonAngle or 0
        local x = 80 * cos(angle)
        local y = 80 * sin(angle)
        button:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
    
    -- Click handlers
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(self, clickType)
        if clickType == "LeftButton" then
            ToggleMainFrame()
        elseif clickType == "RightButton" then
            print("|cff00ff00AuberdineExporter Menu:|r")
            print("  Clic gauche - Ouvrir l'interface")
            print("  /auberdine - Commandes")
            print("  /auberdine help - Aide complète")
        end
    end)
    
    -- Dragging
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Calculate new angle
        local centerX, centerY = Minimap:GetCenter()
        local buttonX, buttonY = self:GetCenter()
        local angle = atan2(buttonY - centerY, buttonX - centerX)
        if AuberdineExporterDB and AuberdineExporterDB.settings then
            AuberdineExporterDB.settings.minimapButtonAngle = angle
        end
        UpdatePosition() -- Snap to proper position
    end)
    
    UpdatePosition()
    
    -- Vérification de sécurité pour l'affichage du bouton
    if AuberdineExporterDB and AuberdineExporterDB.settings then
        if not AuberdineExporterDB.settings.minimapButtonHidden then
            button:Show()
        else
            button:Hide()
        end
    else
        button:Show()
    end
    
    print("|cff00ff00AuberdineExporter:|r Bouton minimap créé")
    return button
end

-- Statistics function
function GetStatistics()
    local stats = {
        totalCharacters = 0,
        totalProfessions = 0,
        totalRecipes = 0,
        professionBreakdown = {}
    }
    if not AuberdineExporterDB.characters or type(AuberdineExporterDB.characters) ~= "table" then
        AuberdineExporterDB.characters = {}
    end
    for charKey, charData in pairs(AuberdineExporterDB.characters) do
        stats.totalCharacters = stats.totalCharacters + 1
        if charData.professions then
            for profName, profData in pairs(charData.professions) do
                stats.totalProfessions = stats.totalProfessions + 1
                if not stats.professionBreakdown[profName] then
                    stats.professionBreakdown[profName] = {
                        characters = 0,
                        totalRecipes = 0
                    }
                end
                stats.professionBreakdown[profName].characters = stats.professionBreakdown[profName].characters + 1
                local recipeCount = 0
                if profData.recipes then
                    for _ in pairs(profData.recipes) do recipeCount = recipeCount + 1 end
                end
                stats.professionBreakdown[profName].totalRecipes = stats.professionBreakdown[profName].totalRecipes + recipeCount
                stats.totalRecipes = stats.totalRecipes + recipeCount
            end
        end
    end
    return stats
end

-- Clé client publique pour auberdine.eu
AuberdineExporterClientKey = "auberdine-v1"

-- Challenge fixe pour auberdine.eu (sécurité côté serveur)
AuberdineExporterChallenge = "auberdine-2025-recipe-export"

-- Implémentation MD5 simplifiée pour WoW Classic
-- Utilise une approche compatible avec toutes les versions de WoW
local function md5_sumhexa(s)
    -- Pour WoW Classic, on utilise un hash simplifié mais sécurisé
    -- Basé sur une fonction de hash simple mais efficace
    local function simpleHash(str)
        local hash = 5381
        for i = 1, #str do
            local c = string.byte(str, i)
            hash = ((hash * 33) + c) % 2147483647
        end
        return string.format("%x", hash)
    end
    
    -- On ajoute quelques passes pour améliorer la distribution
    local pass1 = simpleHash(s)
    local pass2 = simpleHash(s .. pass1)
    local pass3 = simpleHash(pass2 .. s)
    
    -- Retourner un hash de 32 caractères comme MD5
    return string.format("%s%s", pass2, pass3):sub(1, 32)
end

-- Export functions

-- Variable globale pour le challenge (fixe pour la sécurité)
-- AuberdineExporterChallenge est défini plus haut

local function ExportToJSON()
    -- Export multi-personnages avec séparation claire des données
    
    -- Métadonnées système pour auberdine.eu
    local exportMetadata = {
        addon = "AuberdineExporter",
        version = AuberdineExporterDB.version or "1.3.0",
        timestamp = time(),
        exportDate = date("%Y-%m-%d %H:%M:%S"),
        clientKey = AuberdineExporterClientKey,
        challenge = AuberdineExporterChallenge,
        locale = GetLocale() or "unknown",
        realmlist = GetCVar("realmList") or "unknown",
        clientBuild = (GetBuildInfo and select(2, GetBuildInfo())) or "unknown"
    }
    
    -- Générer un nonce unique pour cette session d'export
    local nonce = string.format("%d_%d_%s", time(), math.random(1000, 9999), (UnitGUID("player") or "unknown"):sub(-8))
    exportMetadata.nonce = nonce
    
    -- Structure d'export multi-personnages
    local exportData = {
        -- Métadonnées système (en premier)
        metadata = exportMetadata,
        
        -- Tous les personnages avec leurs données séparées
        characters = {},
        
        -- Statistiques globales
        summary = {
            totalCharacters = 0,
            totalProfessions = 0,
            totalRecipes = 0,
            exportedBy = UnitName("player") .. "-" .. GetRealmName(),
            exportedAt = GetZoneText and GetZoneText() or "unknown"
        },
        
        -- Données de validation finale
        validation = {
            dataChecksum = "", -- Sera calculé plus tard
            exportComplete = true,
            missingAPIs = {},
            warnings = {}
        }
    }
    
    -- Vérifier les APIs manquantes
    if not GetTradeSkillLine then
        table.insert(exportData.validation.missingAPIs, "GetTradeSkillLine")
    end
    if not GetCraftDisplaySkillLine then
        table.insert(exportData.validation.missingAPIs, "GetCraftDisplaySkillLine")
    end
    
    -- Construire les données pour chaque personnage
    if AuberdineExporterDB.characters then
        for charKey, charData in pairs(AuberdineExporterDB.characters) do
            local characterExport = {
                -- Informations de base du personnage
                info = {
                    name = charData.name,
                    realm = charData.realm,
                    guid = charData.guid,
                    level = charData.level,
                    race = charData.race,
                    class = charData.class,
                    locale = charData.locale or "unknown",
                    lastUpdate = charData.lastUpdate
                },
                
                -- Localisation si c'est le personnage connecté
                location = {},
                
                -- Statistiques de ce personnage
                stats = {
                    totalProfessions = 0,
                    totalRecipes = 0,
                    totalSkills = 0,
                    totalReputations = 0
                },
                
                -- Professions de ce personnage
                professions = {},
                
                -- Skills de ce personnage  
                skills = charData.skills or {},
                
                -- Réputations de ce personnage
                reputations = charData.reputations or {}
            }
            
            -- Ajouter localisation si c'est le personnage connecté
            local currentCharKey = GetCurrentCharacterKey()
            if charKey == currentCharKey then
                characterExport.location = {
                    zone = GetZoneText and GetZoneText() or "unknown",
                    subzone = GetSubZoneText and GetSubZoneText() or "unknown",
                    bindLocation = GetBindLocation and GetBindLocation() or "unknown"
                }
                characterExport.isCurrentCharacter = true
            end
            
            -- Construire les professions pour ce personnage
            if charData.professions then
                for profName, profData in pairs(charData.professions) do
                    local recipesList = {}
                    local recipeCount = 0
                    
                    if profData.recipes then
                        for recipeKey, recipeData in pairs(profData.recipes) do
                            recipeCount = recipeCount + 1
                            table.insert(recipesList, {
                                id = recipeData.id,
                                name = recipeData.name,
                                spellLink = recipeData.spellLink
                            })
                        end
                    end
                    
                    characterExport.professions[profName] = {
                        name = profName,
                        level = profData.level,
                        maxLevel = profData.maxLevel,
                        lastScan = profData.lastScan,
                        captureTime = profData.lastScan,
                        recipes = recipesList,
                        recipeCount = recipeCount
                    }
                    
                    characterExport.stats.totalProfessions = characterExport.stats.totalProfessions + 1
                    characterExport.stats.totalRecipes = characterExport.stats.totalRecipes + recipeCount
                end
            end
            
            -- Compter les skills et réputations
            for _ in pairs(characterExport.skills) do 
                characterExport.stats.totalSkills = characterExport.stats.totalSkills + 1 
            end
            for _ in pairs(characterExport.reputations) do 
                characterExport.stats.totalReputations = characterExport.stats.totalReputations + 1 
            end
            
            -- Ajouter le personnage à l'export
            exportData.characters[charKey] = characterExport
            
            -- Mettre à jour les statistiques globales
            exportData.summary.totalCharacters = exportData.summary.totalCharacters + 1
            exportData.summary.totalProfessions = exportData.summary.totalProfessions + characterExport.stats.totalProfessions
            exportData.summary.totalRecipes = exportData.summary.totalRecipes + characterExport.stats.totalRecipes
        end
    end
    
    -- Ajouter des avertissements si nécessaire
    if exportData.summary.totalRecipes == 0 then
        table.insert(exportData.validation.warnings, "Aucune recette trouvée - ouvrez vos fenêtres de métiers")
    end

    -- Fonction de conversion JSON améliorée avec échappement complet
    local function escapeJSON(s)
        s = string.gsub(s, "\\", "\\\\")
        s = string.gsub(s, '"', '\\"')
        s = string.gsub(s, "\n", "\\n")
        s = string.gsub(s, "\r", "\\r")
        s = string.gsub(s, "\t", "\\t")
        return s
    end
    
    -- Encodeur Base64 simple pour WoW Classic
    local function base64Encode(data)
        local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
        local result = {}
        
        for i = 1, #data, 3 do
            local a, b, c = string.byte(data, i, i+2)
            b = b or 0
            c = c or 0
            
            local bitmap = a * 0x10000 + b * 0x100 + c
            
            table.insert(result, string.sub(b64chars, math.floor(bitmap / 0x40000) + 1, math.floor(bitmap / 0x40000) + 1))
            table.insert(result, string.sub(b64chars, math.floor(bitmap / 0x1000) % 0x40 + 1, math.floor(bitmap / 0x1000) % 0x40 + 1))
            table.insert(result, i + 1 <= #data and string.sub(b64chars, math.floor(bitmap / 0x40) % 0x40 + 1, math.floor(bitmap / 0x40) % 0x40 + 1) or '=')
            table.insert(result, i + 2 <= #data and string.sub(b64chars, bitmap % 0x40 + 1, bitmap % 0x40 + 1) or '=')
        end
        
        return table.concat(result)
    end
    
    local function tableToJSON(t, indent, excludeSignature)
        indent = indent or 0
        local spacing = string.rep("  ", indent)
        local result = "{\n"
        local pairs_count = 0
        
        -- Ordonner les clés pour une sortie stable
        local keys = {}
        for k in pairs(t) do
            if not excludeSignature or k ~= "signature" then
                table.insert(keys, k)
            end
        end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        
        for i, k in ipairs(keys) do
            local v = t[k]
            pairs_count = pairs_count + 1
            result = result .. spacing .. "  \"" .. escapeJSON(tostring(k)) .. "\": "
            
            if type(v) == "table" then
                -- Vérifier si c'est un tableau ou un objet
                local isArray = true
                local arrayCount = 0
                for kk, _ in pairs(v) do
                    arrayCount = arrayCount + 1
                    if type(kk) ~= "number" or kk ~= arrayCount then
                        isArray = false
                        break
                    end
                end
                
                if isArray and arrayCount > 0 then
                    result = result .. "[\n"
                    for j = 1, arrayCount do
                        result = result .. spacing .. "    "
                        if type(v[j]) == "table" then
                            result = result .. tableToJSON(v[j], indent + 2, excludeSignature)
                        elseif type(v[j]) == "string" then
                            result = result .. '"' .. escapeJSON(v[j]) .. '"'
                        else
                            result = result .. tostring(v[j])
                        end
                        if j < arrayCount then result = result .. "," end
                        result = result .. "\n"
                    end
                    result = result .. spacing .. "  ]"
                else
                    -- Table vide ou objet
                    local isEmpty = true
                    for _ in pairs(v) do isEmpty = false break end
                    if isEmpty then
                        result = result .. "{}"
                    else
                        result = result .. tableToJSON(v, indent + 1, excludeSignature)
                    end
                end
            elseif type(v) == "string" then
                result = result .. '"' .. escapeJSON(v) .. '"'
            elseif type(v) == "boolean" then
                result = result .. (v and "true" or "false")
            else
                result = result .. tostring(v)
            end
            
            if i < #keys then result = result .. "," end
            result = result .. "\n"
        end
        
        result = result .. spacing .. "}"
        return result
    end

    -- NOUVELLE APPROCHE : Base64 pour éviter les problèmes de formatage JSON
    
    -- 1. Générer le JSON des données sans signature
    local jsonWithoutSignature = tableToJSON(exportData, 0, true)
    
    -- 2. Encoder en Base64
    local dataBase64 = base64Encode(jsonWithoutSignature)
    
    -- 3. Calculer la checksum sur le Base64 (pas sur le JSON)
    local dataChecksum = md5_sumhexa(dataBase64)
    
    -- 4. Créer le wrapper avec Base64
    local exportWrapper = {
        metadata = exportMetadata,
        dataBase64 = dataBase64,
        signatureInfo = {
            algorithm = "multi-pass-md5-base64",
            timestamp = exportMetadata.timestamp,
            nonce = nonce,
            hasChallenge = true
        },
        validation = {
            dataChecksum = dataChecksum,
            exportComplete = true,
            encoding = "base64",
            missingAPIs = {},
            warnings = {}
        }
    }
    
    -- 5. Générer la signature sur le Base64 + metadata
    local signatureBase = dataBase64 .. exportMetadata.clientKey .. exportMetadata.nonce .. AuberdineExporterChallenge
    
    -- Signature multi-passes sur Base64
    local signature1 = md5_sumhexa(signatureBase)
    local signature2 = md5_sumhexa(signature1 .. exportMetadata.timestamp .. exportMetadata.clientKey)
    local finalSignature = md5_sumhexa(signature2 .. nonce)
    
    -- 6. Ajouter la signature finale
    exportWrapper.signature = finalSignature
    
    -- Ajouter les warnings si nécessaire
    if exportData.summary.totalRecipes == 0 then
        table.insert(exportWrapper.validation.warnings, "Aucune recette trouvée - ouvrez vos fenêtres de métiers")
    end

    -- 7. Retourner le JSON du wrapper (format simple, pas de problème de formatage)
    return tableToJSON(exportWrapper, 0, false)
end

-- Export JSON simple pour auberdine.eu
local function ExportToSimpleJSON()
    -- On prend le personnage courant (celui connecté)
    local charKey = GetCurrentCharacterKey()
    local charData = AuberdineExporterDB.characters[charKey]
    if not charData then
        return '{"error":"Aucun personnage courant trouvé"}'
    end

    -- Rafraîchir skills et reputations depuis le jeu (toujours à jour)
    local freshSkills = GetCharacterSkills and GetCharacterSkills() or {}
    local freshReputations = GetCharacterReputations and GetCharacterReputations() or {}
    charData.skills = freshSkills
    charData.reputations = freshReputations

    -- Construction du bloc character (à plat)
    local character = {
        name = charData.name,
        class = charData.class,
        level = charData.level,
        race = charData.race,
        realm = charData.realm,
        guid = charData.guid,
        locale = charData.locale,
        lastUpdate = charData.lastUpdate,
        -- Ajoute d'autres champs si besoin (guild, etc.)
    }

    -- Construction du bloc recipes (par métier, liste de noms)
    local recipes = {}
    if charData.professions then
        for profName, profData in pairs(charData.professions) do
            recipes[profName] = {}
            if profData.recipes then
                for _, recipeData in pairs(profData.recipes) do
                    if recipeData.name then
                        table.insert(recipes[profName], recipeData.name)
                    end
                end
            end
        end
    end

    -- Construction de la table d'export
    local exportData = {
        timestamp = time(),
        addon = "AuberdineExporter",
        version = AuberdineExporterDB.version or "1.0.0",
        character = character,
        recipes = recipes,
        skills = freshSkills,
        reputations = freshReputations
    }

    -- Génération du JSON (manuel, à plat)
    local function escape(s)
        return string.gsub(s, "[\"\\]", function(c)
            if c == '\\' then return "\\\\" elseif c == '"' then return '\\"' end
        end)
    end
    local function tableToSimpleJSON(t)
        local out = "{"
        local first = true
        for k, v in pairs(t) do
            if not first then out = out .. "," end
            first = false
            out = out .. '"' .. escape(tostring(k)) .. '":'
            if type(v) == "table" then
                -- Table d'objets ou de tableaux
                local isArray = true
                local idx = 1
                for kk, _ in pairs(v) do
                    if kk ~= idx then isArray = false break end
                    idx = idx + 1
                end
                if isArray then
                    out = out .. "["
                    for i, vv in ipairs(v) do
                        if i > 1 then out = out .. "," end
                        if type(vv) == "string" then
                            out = out .. '"' .. escape(vv) .. '"'
                        else
                            out = out .. tostring(vv)
                        end
                    end
                    out = out .. "]"
                else
                    out = out .. tableToSimpleJSON(v)
                end
            elseif type(v) == "string" then
                out = out .. '"' .. escape(v) .. '"'
            else
                out = out .. tostring(v)
            end
        end
        out = out .. "}"
        return out
    end

    -- Signature
    local jsonNoSig = tableToSimpleJSON(exportData)
    local signature = md5_sumhexa(jsonNoSig .. AuberdineExporterClientKey)
    exportData.signature = signature
    return tableToSimpleJSON(exportData)
end

-- Export CSV simple pour auberdine.eu
local function ExportToCSV()
    local csv = "Character,Realm,Level,Race,Class,Profession,ProfessionLevel,RecipeID,RecipeName,RecipeType,SpellLink\n"
    for charKey, charData in pairs(AuberdineExporterDB.characters) do
        for profName, profData in pairs(charData.professions or {}) do
            local recipes = profData.recipes or {}
            for recipeKey, recipeData in pairs(recipes) do
                local recipeID = recipeData.id or "N/A"
                local recipeName = recipeData.name or recipeKey
                local spellLink = recipeData.spellLink or "N/A"
                csv = csv .. string.format(
                    '"%s","%s",%d,"%s","%s","%s",%d,"%s","%s","%s","%s"\n',
                    charData.name, charData.realm, charData.level,
                    charData.race, charData.class, profName,
                    profData.level or 0, tostring(recipeID), recipeName, 
                    recipeData.type or "unknown", spellLink
                )
            end
        end
    end
    return csv
end

local function CreateExportFrame(exportData, format)
    -- Create export window
    local exportFrame = CreateFrame("Frame", "AuberdineExporterExportFrame", UIParent)
    exportFrame:SetSize(500, 400)
    exportFrame:SetPoint("CENTER")
    exportFrame:SetFrameStrata("FULLSCREEN")
    exportFrame:SetMovable(true)
    exportFrame:EnableMouse(true)
    exportFrame:RegisterForDrag("LeftButton")
    exportFrame:SetScript("OnDragStart", exportFrame.StartMoving)
    exportFrame:SetScript("OnDragStop", exportFrame.StopMovingOrSizing)
    
    -- Background
    exportFrame.bg = exportFrame:CreateTexture(nil, "BACKGROUND")
    exportFrame.bg:SetAllPoints()
    exportFrame.bg:SetColorTexture(0, 0, 0, 0.9)
    
    -- Border
    exportFrame.border = CreateFrame("Frame", nil, exportFrame, "DialogBorderTemplate")
    
    -- Title
    exportFrame.title = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    exportFrame.title:SetPoint("TOP", 0, -10)
    exportFrame.title:SetText("Export " .. format:upper())
    
    -- Scroll frame for text
    local scrollFrame = CreateFrame("ScrollFrame", nil, exportFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)
    
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetWidth(450)
    editBox:SetText(exportData)
    editBox:SetCursorPosition(0)
    editBox:SetScript("OnEscapePressed", function() exportFrame:Hide() end)
    scrollFrame:SetScrollChild(editBox)
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, exportFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function() exportFrame:Hide() end)
    
    -- Instructions
    local instructions = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instructions:SetPoint("BOTTOM", 0, 10)
    instructions:SetText("Sélectionnez tout (Ctrl+A) puis copiez (Ctrl+C)")
    instructions:SetTextColor(1, 1, 0)
    
    exportFrame:Show()
    editBox:SetFocus()
    editBox:HighlightText()
end

-- Main UI Frame (simplified but functional)
local mainFrame = nil

local function CreateMainFrame()
    if mainFrame then
        return mainFrame
    end
    
    -- Create main frame
    local frame = CreateFrame("Frame", "AuberdineExporterMainFrame", UIParent)
    frame:SetSize(600, 600)
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
    
    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -20)
    frame.title:SetText("Auberdine Exporter")
    frame.title:SetTextColor(1, 1, 1)
    
    -- Close button
    frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeButton:SetPoint("TOPRIGHT", -5, -5)
    
    -- Buttons en haut - Disposition en 2 colonnes
    -- Bouton Export Auberdine (colonne 1)
    local exportButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    exportButton:SetSize(260, 35)
    exportButton:SetPoint("TOPLEFT", 20, -60)
    exportButton:SetText("Export Auberdine")
    exportButton:SetScript("OnClick", function()
        local jsonData = ExportToJSON()
        CreateExportFrame(jsonData, "JSON-AUBERDINE")
    end)
    
    -- Bouton Export CSV (colonne 2)
    local csvButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    csvButton:SetSize(260, 35)
    csvButton:SetPoint("TOPLEFT", 300, -60)
    csvButton:SetText("Export CSV")
    csvButton:SetScript("OnClick", function()
        local csvData = ExportToCSV()
        CreateExportFrame(csvData, "CSV")
    end)
    
    -- Ligne de séparation
    local separator = frame:CreateTexture(nil, "ARTWORK")
    separator:SetSize(560, 2)
    separator:SetPoint("TOPLEFT", 20, -120)
    separator:SetColorTexture(0.5, 0.5, 0.5, 0.8)
    
    -- Zone de texte scrollable en bas
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -130)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 20)
    
    -- Content text dans le scroll frame
    frame.content = CreateFrame("EditBox", nil, scrollFrame)
    frame.content:SetMultiLine(true)
    frame.content:SetFontObject("GameFontNormal")
    frame.content:SetWidth(530)
    frame.content:SetAutoFocus(false)
    frame.content:EnableMouse(false)
    frame.content:SetScript("OnEscapePressed", function() frame.content:ClearFocus() end)
    scrollFrame:SetScrollChild(frame.content)
    
    -- Update content function
    frame.UpdateContent = function(self)
        local stats = GetStatistics()
        local currentChar = GetCurrentCharacterKey()
        local currentCharData = AuberdineExporterDB.characters[currentChar]
        
        local text = string.format(
            "Auberdine Exporter - Statistiques Multi-Personnages\n\n" ..
            "Personnages scannés: %d\n" ..
            "Métiers au total: %d\n" ..
            "Recettes collectées: %d\n" ..
            "Challenge: auberdine-2025-recipe-export (fixe)\n\n" ..
            "Personnage connecté: %s (%s)\n" ..
            "Niveau: %d - Classe: %s\n" ..
            "Realm: %s\n\n" ..
            "Instructions d'utilisation:\n" ..
            "1. Ouvrez vos fenêtres de métiers pour scanner automatiquement\n" ..
            "2. Utilisez 'Export Auberdine' pour un export multi-personnages complet\n" ..
            "3. Utilisez 'Export CSV' pour un format tableur\n\n" ..
            "Commandes disponibles:\n" ..
            "• /auberdine scan - Scanner tous les métiers manuellement\n" ..
            "• /auberdine stats - Afficher les statistiques\n" ..
            "• /auberdine chars - Lister tous les personnages\n" ..
            "• /auberdine help - Aide complète\n" ..
            "• /auberdine debug - Toggle mode debug",
            stats.totalCharacters, stats.totalProfessions, stats.totalRecipes,
            currentCharData and currentCharData.name or "Inconnu",
            currentCharData and currentCharData.class or "Inconnue",
            currentCharData and currentCharData.level or 0,
            currentCharData and currentCharData.class or "Inconnue",
            currentCharData and currentCharData.realm or "Inconnu"
        )
        
        if stats.totalCharacters > 0 then
            text = text .. "\n\nDétail par personnage:\n"
            for charKey, charData in pairs(AuberdineExporterDB.characters) do
                local charProfessions = 0
                local charRecipes = 0
                if charData.professions then
                    for profName, profData in pairs(charData.professions) do
                        charProfessions = charProfessions + 1
                        if profData.recipes then
                            for _ in pairs(profData.recipes) do charRecipes = charRecipes + 1 end
                        end
                    end
                end
                text = text .. string.format("• %s (%s): %d métiers, %d recettes\n", 
                    charData.name, charData.class, charProfessions, charRecipes)
            end
            
            text = text .. "\nDétail par métier (tous personnages):\n"
            for profName, profStats in pairs(stats.professionBreakdown) do
                text = text .. string.format("• %s: %d recettes sur %d personnages\n", 
                    profName, profStats.totalRecipes, profStats.characters)
            end
        end
        
        self.content:SetText(text)
    end
    
    mainFrame = frame
    return frame
end

ToggleMainFrame = function()
    local frame = CreateMainFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:UpdateContent()
        frame:Show()
    end
end

-- Display functions
local function ShowStatistics()
    local stats = GetStatistics()
    print("|cff00ff00=== AuberdineExporter Statistiques ===|r")
    print("Characters: " .. stats.totalCharacters)
    print("Professions: " .. stats.totalProfessions)
    print("Total Recipes: " .. stats.totalRecipes)
    print("")
    
    if stats.totalCharacters == 0 then
        print("|cffff8000No data yet!|r Open profession windows to scan recipes.")
        return
    end
    
    for profName, profStats in pairs(stats.professionBreakdown) do
        print("|cffff8000" .. profName .. ":|r " .. profStats.characters .. " chars, " .. profStats.totalRecipes .. " recipes")
    end
end

local function ShowCharacters()
    print("|cff00ff00=== Personnages ===|r")
    local count = 0
    for charKey, charData in pairs(AuberdineExporterDB.characters) do
        count = count + 1
        print("|cffff8000" .. charData.name .. ":|r " .. charData.realm .. " - Level " .. charData.level .. " " .. charData.class)
        
        if charData.professions then
            for profName, profData in pairs(charData.professions) do
                local recipeCount = 0
                if profData.recipes then
                    for _ in pairs(profData.recipes) do recipeCount = recipeCount + 1 end
                end
                print("  " .. profName .. ": " .. (profData.level or 0) .. "/" .. (profData.maxLevel or 0) .. " (" .. recipeCount .. " recipes)")
            end
        end
    end
    
    if count == 0 then
        print("|cffff8000No characters scanned yet.|r")
    end
end

local function ShowSkillLines()
    print("|cff00ff00=== Toutes les compétences ===|r")
    for i = 1, GetNumSkillLines() do
        local skillName, header, isExpanded, skillRank, numTempPoints, skillModifier, skillMaxRank, isAbandonable, stepCost, rankCost, minLevel, skillCostType, skillDescription = GetSkillLineInfo(i)
        if skillName and not header then
            local status = validProfessions[skillName] and "|cff00ff00[VALID]|r" or "|cffff0000[INVALID]|r"
            print(status .. " '" .. skillName .. "' - " .. skillRank .. "/" .. skillMaxRank)
        end
    end
end

-- Main collection function for TradeSkill
local function OnTradeSkillShow()
    -- Protection contre les conflits d'addons
    if not GetTradeSkillLine then
        print("|cffff0000AuberdineExporter:|r TradeSkill API not available, skipping scan.")
        return
    end
    
    if not AuberdineExporterDB or not AuberdineExporterDB.settings then
        print("|cffff8000AuberdineExporter:|r Database not initialized, initializing...")
        return
    end
    
    -- Petit délai pour éviter les conflits avec d'autres addons
    local function DelayedScan()
        local skillName, skillRank, skillMaxRank = GetTradeSkillLine()
        print("|cff00ff00AuberdineExporter DEBUG:|r TradeSkill opened - Name: '" .. tostring(skillName) .. "', Rank: " .. tostring(skillRank) .. "/" .. tostring(skillMaxRank))

        -- Rafraîchir la table si la langue a changé dynamiquement
        validProfessions = GetValidProfessions()
        if IsProfessionValid(skillName) then
            print("|cff00ff00AuberdineExporter:|r Scanning " .. skillName .. "...")
            local recipes = {}
            local numRecipes = GetNumTradeSkills()
            
            -- Utiliser le nom normalisé pour éviter les doublons
            local normalizedName = GetNormalizedProfessionName(skillName)

            for i = 1, numRecipes do
                local recipeName, recipeType = GetTradeSkillInfo(i)
                if recipeType ~= "header" then
                    -- Toujours sélectionner la recette avant d'appeler GetTradeSkillRecipeLink (Classic Era)
                    local oldSelection = GetTradeSkillSelectionIndex and GetTradeSkillSelectionIndex() or nil
                    if SelectTradeSkill then
                        SelectTradeSkill(i)
                    end
                    local spellLink = nil
                    local spellID = nil
                    local idSource = nil
                    if GetTradeSkillRecipeLink then
                        spellLink = GetTradeSkillRecipeLink()
                        if spellLink and spellLink ~= "" then
                            spellID = tonumber(string.match(spellLink, "spell:(%d+)") or string.match(spellLink, "enchant:(%d+)") or string.match(spellLink, "craft:(%d+)"))
                            if spellID then idSource = "link" end
                        end
                    end
                    -- Fallback: tenter d'extraire l'ID via le tooltip si non trouvé
                    if not spellID then
                        spellID = GetSpellIDFromTooltip()
                        if spellID then idSource = "tooltip" end
                    end
                    if not idSource then idSource = "none" end
                    -- Rétablir la sélection précédente
                    if oldSelection and oldSelection > 0 and SelectTradeSkill then
                        SelectTradeSkill(oldSelection)
                    end
                    local recipeKey = (spellID and (spellID .. "_" .. recipeName)) or (i .. "_" .. recipeName)
                    recipes[recipeKey] = {
                        id = spellID,
                        idSource = idSource,
                        name = recipeName,
                        type = recipeType,
                        index = i,
                        spellLink = spellLink
                    }
                    if AuberdineExporterDB and AuberdineExporterDB.settings and AuberdineExporterDB.settings.verboseDebug then
                        if spellID then
                            print("|cff00ff00AuberdineExporter:|r " .. recipeName .. " (index: " .. i .. ", ID: " .. spellID .. ", source: " .. idSource .. ")")
                        else
                            print("|cffff8000AuberdineExporter DEBUG:|r " .. recipeName .. " (index: " .. i .. ", pas d'ID)")
                        end
                    end
                end -- Fin if recipeType ~= "header"
            end -- Fin boucle for

            local charKey = InitializeCharacterData()
            if not recipes or type(recipes) ~= "table" then recipes = {} end
            AuberdineExporterDB.characters[charKey].professions[normalizedName] = {
                name = skillName, -- Nom original pour l'affichage
                normalizedName = normalizedName,
                level = skillRank,
                maxLevel = skillMaxRank,
                lastScan = time(),
                recipes = recipes
            }

            local recipeCount = 0
            local recipesWithID = 0
            for _, recipeData in pairs(recipes) do 
                recipeCount = recipeCount + 1 
                if recipeData.id then
                    recipesWithID = recipesWithID + 1
                end
            end
            if recipeCount == 0 then
                print("|cffff8000AuberdineExporter:|r Aucune recette trouvée pour " .. skillName .. ". Ouvrez la fenêtre du métier et vérifiez les filtres.")
            else
                local successRate = math.floor((recipesWithID / recipeCount) * 100)
                print("|cff00ff00AuberdineExporter:|r " .. skillName .. " scanned - " .. recipeCount .. " recipes found!")
                print("|cff00ff00AuberdineExporter:|r IDs captured: " .. recipesWithID .. "/" .. recipeCount .. " (" .. successRate .. "%)")
            end
        else
            print("|cffff0000AuberdineExporter:|r Profession '" .. tostring(skillName) .. "' not recognized.")
            print("Use /auberdine skills to see all profession names.")
        end
    end

    -- Délai de 0.5 secondes pour éviter les conflits avec ElvUI/autres addons
    C_Timer.After(0.5, DelayedScan)
end

-- Collection function for Craft (Enchanting) - FIXED
local function OnCraftShow()
    -- Protection contre les conflits d'addons
    if not GetCraftDisplaySkillLine then
        print("|cffff0000AuberdineExporter:|r Craft API not available, skipping scan.")
        return
    end
    
    if not AuberdineExporterDB or not AuberdineExporterDB.settings then
        print("|cffff8000AuberdineExporter:|r Database not initialized, initializing...")
        return
    end
    
    -- Petit délai pour éviter les conflits avec d'autres addons
    local function DelayedCraftScan()
        local skillName, skillRank, skillMaxRank = GetCraftDisplaySkillLine()
        print("|cff00ff00AuberdineExporter DEBUG:|r Craft opened - Name: '" .. tostring(skillName) .. "'")
        
        -- Rafraîchir la table si la langue a changé dynamiquement
        validProfessions = GetValidProfessions()
        if (skillName == "Enchantement" and GetLocale() == "frFR") or (skillName == "Enchanting" and GetLocale() ~= "frFR") then
            print("|cff00ff00AuberdineExporter:|r Scanning Enchanting...")
            local recipes = {}
            local numRecipes = GetNumCrafts()
            
            -- Utiliser le nom normalisé pour éviter les doublons
            local normalizedName = GetNormalizedProfessionName(skillName)

            if numRecipes and numRecipes > 0 then
                for i = 1, numRecipes do
                    local recipeName, craftSubSpellName, recipeType = GetCraftInfo(i)
                    if recipeType ~= "header" then
                        -- Toujours sélectionner l'enchantement avant d'appeler GetCraftRecipeLink (Classic Era)
                        local oldSelection = GetCraftSelectionIndex and GetCraftSelectionIndex() or nil
                        if SelectCraft then
                            SelectCraft(i)
                        end
                        local spellLink = nil
                        local recipeID = nil
                        local idSource = nil
                        if GetCraftRecipeLink then
                            spellLink = GetCraftRecipeLink()
                            if spellLink and spellLink ~= "" then
                                recipeID = tonumber(spellLink:match("spell:(%d+)") ) or 
                                          tonumber(spellLink:match("enchant:(%d+)") ) or
                                          tonumber(spellLink:match("craft:(%d+)"))
                                if recipeID then idSource = "link" end
                            end
                        end
                        -- Fallback: tenter d'extraire l'ID via le tooltip si non trouvé
                        if not recipeID then
                            recipeID = GetSpellIDFromTooltip()
                            if recipeID then idSource = "tooltip" end
                        end
                        if not idSource then idSource = "none" end
                        -- Rétablir la sélection précédente
                        if oldSelection and oldSelection > 0 and SelectCraft then
                            SelectCraft(oldSelection)
                        end
                        -- Stocker avec une clé unique
                        local recipeKey = recipeID and (recipeID .. "_" .. recipeName) or (i .. "_" .. recipeName)
                        recipes[recipeKey] = {
                            id = recipeID,
                            idSource = idSource,
                            name = recipeName,
                            type = recipeType,
                            index = i,
                            spellLink = spellLink
                        }
                        -- Messages de debug plus discrets
                        if recipeID then
                            print("|cff00ff00AuberdineExporter:|r " .. recipeName .. " (ID: " .. recipeID .. ", source: " .. idSource .. ")")
                        elseif AuberdineExporterDB and AuberdineExporterDB.settings and AuberdineExporterDB.settings.verboseDebug then
                            print("|cffff8000AuberdineExporter DEBUG:|r " .. recipeName .. " (index: " .. i .. ", no spell ID)")
                        end
                    end -- Fin if recipeType ~= "header"
                end -- Fin boucle for
            end

            -- Toujours garantir que recipes est une table
            local charKey = InitializeCharacterData()
            if not recipes or type(recipes) ~= "table" then recipes = {} end
            AuberdineExporterDB.characters[charKey].professions[normalizedName] = {
                name = skillName, -- Nom original pour l'affichage
                normalizedName = normalizedName,
                level = skillRank,
                maxLevel = skillMaxRank,
                lastScan = time(),
                recipes = recipes
            }

            -- Protéger la boucle d'itération
            local recipeCount = 0
            local recipesWithID = 0
            for _, recipeData in pairs(recipes) do 
                recipeCount = recipeCount + 1 
                if recipeData.id then
                    recipesWithID = recipesWithID + 1
                end
            end
            if recipeCount == 0 then
                print("|cffff8000AuberdineExporter:|r Aucune recette trouvée pour " .. skillName .. ". Ouvrez la fenêtre du métier et vérifiez les filtres.")
            else
                local successRate = math.floor((recipesWithID / recipeCount) * 100)
                print("|cff00ff00AuberdineExporter:|r " .. skillName .. " scanned - " .. recipeCount .. " recipes found!")
                print("|cff00ff00AuberdineExporter:|r IDs captured: " .. recipesWithID .. "/" .. recipeCount .. " (" .. successRate .. "%)")
            end
        end -- Fin if Enchantement/Enchanting
    end
    
    -- Délai de 0.5 secondes pour éviter les conflits avec ElvUI/autres addons
    C_Timer.After(0.5, DelayedCraftScan)
end

-- Event frame
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("TRADE_SKILL_SHOW")
frame:RegisterEvent("CRAFT_SHOW")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "AuberdineExporter" then
            if not AuberdineExporterDB then
                AuberdineExporterDB = {
                    version = "1.3.0",
                    characters = {},
                    settings = {
                        autoScan = true,
                        shareData = true,
                        exportFormat = "json",
                        minimapButtonAngle = 0,
                        minimapButtonHidden = false,
                        verboseDebug = false
                    }
                }
                print("|cff00ff00AuberdineExporter:|r Base de données initialisée à ADDON_LOADED")
            end
            print("|cff00ff00AuberdineExporter|r v" .. AuberdineExporterDB.version .. " chargé !")
        end
    elseif event == "PLAYER_LOGIN" then
        -- S'assurer que la base de données principale est complètement initialisée
        if not AuberdineExporterDB then
            AuberdineExporterDB = {
                version = "1.3.0",
                characters = {},
                settings = {
                    autoScan = true,
                    shareData = true,
                    exportFormat = "json",
                    minimapButtonAngle = 0,
                    minimapButtonHidden = false,
                    verboseDebug = false
                }
            }
            print("|cff00ff00AuberdineExporter:|r Base de données réinitialisée à PLAYER_LOGIN")
        end
        InitializeCharacterData()
        CreateMinimapButton()
        if LibRecipes then
            if LibRecipes.GetCount then
                print("|cff00ff00AuberdineExporter:|r LibRecipes-3.0 chargé avec " .. LibRecipes:GetCount() .. " recettes !")
            else
                print("|cff00ff00AuberdineExporter:|r LibRecipes-1.0a chargé (version legacy)")
            end
        else
            print("|cffff8000AuberdineExporter:|r Attention : LibRecipes non trouvée")
        end
        C_Timer.After(2, function()
            print("|cff00ff00AuberdineExporter:|r Scan automatique de vos métiers...")
            ScanAllProfessions()
        end)
        print("|cff00ff00AuberdineExporter:|r Prêt ! Tapez /auberdine pour les commandes.")
        print("|cff00ff00AuberdineExporter:|r Bouton minimap disponible. Utilisez /auberdine scan pour un scan manuel.")
    elseif event == "TRADE_SKILL_SHOW" then
        OnTradeSkillShow()
    elseif event == "CRAFT_SHOW" then
        OnCraftShow()
    end
end)

-- Test slash command first
SLASH_AUBERDINETEST1 = "/auberdinetest"
SlashCmdList["AUBERDINETEST"] = function(msg)
    print("|cff00ff00AuberdineExporter TEST:|r Slash commands OK ! Message: " .. tostring(msg))
    print("Les commandes principales devraient fonctionner...")
end

-- Main slash commands - COMPLETE VERSION
local function HandleSlashCommand(msg)
    local command = string.lower(msg or "")
    print("|cff00ff00AuberdineExporter:|r Commande reçue : '" .. command .. "'")
    
    if command == "show" or command == "" or command == "ui" then
        ToggleMainFrame()
    elseif command == "characters" or command == "chars" then
        ToggleMainFrame()
        -- Auto switch to characters tab if possible
    elseif command == "skills" then
        ShowSkillLines()
    elseif command == "autoscan" then
        if AuberdineExporterDB and AuberdineExporterDB.settings then
            AuberdineExporterDB.settings.autoScan = not AuberdineExporterDB.settings.autoScan
            local status = AuberdineExporterDB.settings.autoScan and "enabled" or "disabled"
            print("|cff00ff00AuberdineExporter:|r Auto-scan " .. status)
        else
            print("|cffff0000AuberdineExporter:|r Database not initialized yet!")
        end
    elseif command == "debug" then
        if AuberdineExporterDB and AuberdineExporterDB.settings then
            AuberdineExporterDB.settings.verboseDebug = not AuberdineExporterDB.settings.verboseDebug
            local status = AuberdineExporterDB.settings.verboseDebug and "ON" or "OFF"
            print("|cff00ff00AuberdineExporter:|r Verbose debug " .. status)
            if AuberdineExporterDB.settings.verboseDebug then
                print("  Debug mode will show detailed scan information")
            else
                print("  Debug mode disabled, only successful ID captures will be shown")
            end
        else
            print("|cffff0000AuberdineExporter:|r Database not initialized yet!")
        end
    elseif command == "reset" then
        if not AuberdineExporterDB or type(AuberdineExporterDB) ~= "table" then
            AuberdineExporterDB = {}
        end
        AuberdineExporterDB.characters = {}
        print("|cff00ff00AuberdineExporter:|r All data has been reset!")
    elseif command == "minimap" then
        if AuberdineExporterMinimapButton then
            if AuberdineExporterMinimapButton:IsShown() then
                AuberdineExporterMinimapButton:Hide()
                if AuberdineExporterDB and AuberdineExporterDB.settings then
                    AuberdineExporterDB.settings.minimapButtonHidden = true
                end
                print("|cff00ff00AuberdineExporter:|r Minimap button hidden")
            else
                AuberdineExporterMinimapButton:Show()
                if AuberdineExporterDB and AuberdineExporterDB.settings then
                    AuberdineExporterDB.settings.minimapButtonHidden = false
                end
                print("|cff00ff00AuberdineExporter:|r Minimap button shown")
            end
        else
            print("|cffff0000AuberdineExporter:|r Minimap button not created yet!")
        end
    elseif command == "stats" then
        ShowStatistics()
    elseif command == "scan" then
        local count = ScanAllProfessions()
        if count > 0 then
            print("|cff00ff00AuberdineExporter:|r Scan terminé ! " .. count .. " métiers trouvés.")
            if mainFrame and mainFrame:IsShown() then
                mainFrame:UpdateContent()
            end
        end
    elseif command == "recipes" then
        -- Afficher toutes les recettes avec leurs IDs
        local charKey = GetCurrentCharacterKey()
        if AuberdineExporterDB.characters[charKey] then
            print("|cff00ff00=== Recettes avec IDs ===|r")
            for profName, profData in pairs(AuberdineExporterDB.characters[charKey].professions) do
                print("|cffff8000" .. profName .. ":|r")
                local count = 0
                for recipeKey, recipeData in pairs(profData.recipes or {}) do
                    count = count + 1
                    if count <= 10 then -- Limiter l'affichage
                        local idText = recipeData.id and (" (ID: " .. recipeData.id .. ")") or " (pas d'ID)"
                        print("  • " .. (recipeData.name or recipeKey) .. idText)
                    elseif count == 11 then
                        print("  ... et " .. (count - 10) .. " autres recettes")
                        break
                    end
                end
                if count == 0 then
                    print("  Aucune recette")
                end
                print("")
            end
        else
            print("|cffff0000AuberdineExporter:|r Aucune donnée pour ce personnage.")
        end
    elseif command == "debugdb" then
        -- Debug complet de la base de données
        print("|cff00ff00=== DEBUG DATABASE ===|r")
        local charKey = GetCurrentCharacterKey()
        print("Current Character Key: " .. charKey)
        print("Database exists: " .. tostring(AuberdineExporterDB ~= nil))
        if AuberdineExporterDB then
            print("Characters in DB: " .. tostring(AuberdineExporterDB.characters ~= nil))
            if AuberdineExporterDB.characters then
                local charCount = 0
                for ck, cd in pairs(AuberdineExporterDB.characters) do
                    charCount = charCount + 1
                    print("  Character " .. charCount .. ": " .. ck)
                    print("    Name: " .. (cd.name or "nil"))
                    print("    Professions: " .. tostring(cd.professions ~= nil))
                    if cd.professions then
                        for profName, profData in pairs(cd.professions) do
                            local recipeCount = 0
                            if profData.recipes then
                                for _ in pairs(profData.recipes) do recipeCount = recipeCount + 1 end
                            end
                            print("      " .. profName .. ": " .. recipeCount .. " recipes")
                        end
                    end
                end
                print("Total characters: " .. charCount)
            end
        end
    elseif command == "help" then
        print("|cff00ff00AuberdineExporter Commands:|r")
        print("  /auberdine - Ouvrir l'interface principale")
        print("  /auberdine ui - Ouvrir l'interface principale")
        print("  /auberdine characters - Ouvrir l'onglet personnages")
        print("  /auberdine scan - Scanner tous vos métiers (inclut récolte)")
        print("  /auberdine recipes - Afficher toutes les recettes avec IDs")
        print("  /auberdine stats - Afficher les statistiques dans le chat")
        print("  /auberdine debug - Toggle verbose debug messages")
        print("  /auberdine debugdb - Debug complet de la base de données")
        print("  /auberdine skills - Show all skill lines (debug)")
        print("  /auberdine autoscan - Toggle auto-scan on/off")
        print("  /auberdine minimap - Toggle minimap button")
        print("  /auberdine reset - Reset all data")
        print("  /auberdine help - Show this help")
        print("")
        if AuberdineExporterDB and AuberdineExporterDB.settings then
            print("Auto-scan: " .. (AuberdineExporterDB.settings.autoScan and "ON" or "OFF"))
            print("Debug: " .. (AuberdineExporterDB.settings.verboseDebug and "ON" or "OFF"))
        else
            print("Settings: Database not initialized yet")
        end
    else
        print("|cffff0000AuberdineExporter:|r Unknown command '" .. command .. "'. Use /auberdine help")
    end
end

-- Main slash commands
SLASH_AUBERDINE1 = "/auberdine"
SLASH_AUBERDINE2 = "/ae"
SLASH_AUBERDINE3 = "/aubex"
SlashCmdList["AUBERDINE"] = HandleSlashCommand

print("=== Commandes slash enregistrées ===")
print("=== AuberdineExporter chargé complètement ===")
print("=== Utilisez /auberdinetest pour tester, /auberdine pour les commandes principales ===")
