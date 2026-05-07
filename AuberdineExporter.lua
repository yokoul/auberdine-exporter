-- AuberdineExporter - Main addon file
-- print("=== AuberdineExporter loading ===")

-- Global addon table
AuberdineExporter = AuberdineExporter or {}

-- Public function to check if we're on the correct realm
function AuberdineExporter:IsOnAuberdine()
    local realmName = GetRealmName()
    return realmName == "Auberdine" or realmName == "auberdine" or realmName == "AUBERDINE"
end

-- Function to reset all data
function AuberdineExporter:ResetAllData()
    if not AuberdineExporterDB or type(AuberdineExporterDB) ~= "table" then
        AuberdineExporterDB = {}
    end
    AuberdineExporterDB.characters = {}
    print("|cff00ff00AuberdineExporter:|r All data has been reset!")
end

-- Function to clear memory data (selective cleanup)
function AuberdineExporter:ClearMemoryData()
    if not AuberdineExporterDB or not AuberdineExporterDB.characters then
        print("|cffff0000AuberdineExporter:|r No data to clear!")
        return
    end
    
    local currentPlayerKey = UnitName("player") .. "-" .. GetRealmName()
    local clearedCount = 0
    local keptCount = 0
    
    -- Keep only current character's data
    local currentCharData = AuberdineExporterDB.characters[currentPlayerKey]
    
    for charKey, _ in pairs(AuberdineExporterDB.characters) do
        if charKey ~= currentPlayerKey then
            AuberdineExporterDB.characters[charKey] = nil
            clearedCount = clearedCount + 1
        else
            keptCount = keptCount + 1
        end
    end
    
    if clearedCount > 0 then
        print(string.format("|cff00ff00AuberdineExporter:|r Cleared data for %d characters. Kept current character data (%d).", 
            clearedCount, keptCount))
    else
        print("|cff00ff00AuberdineExporter:|r No additional character data found to clear.")
    end
end

-- Function to get data size information
function AuberdineExporter:GetDataSizeInfo()
    if not AuberdineExporterDB or not AuberdineExporterDB.characters then
        return 0, 0, {}
    end
    
    local totalChars = 0
    local totalSize = 0
    local charSizes = {}
    
    for charKey, charData in pairs(AuberdineExporterDB.characters) do
        totalChars = totalChars + 1
        
        -- Estimate data size (rough calculation)
        local charDataStr = ""
        if charData.professions then
            for profName, profData in pairs(charData.professions) do
                if profData.recipes then
                    for recipeId, _ in pairs(profData.recipes) do
                        charDataStr = charDataStr .. tostring(recipeId)
                    end
                end
            end
        end
        
        local estimatedSize = string.len(charDataStr) + 100 -- Base character info
        charSizes[charKey] = estimatedSize
        totalSize = totalSize + estimatedSize
    end
    
    return totalChars, totalSize, charSizes
end

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

-- Function to validate if we're on the correct realm (Auberdine)
local function IsValidRealm()
    return AuberdineExporter:IsOnAuberdine()
end

local function GetCurrentCharacterKey()
    local playerName = UnitName("player")
    local realmName = GetRealmName()
    return playerName .. "-" .. realmName
end

local function InitializeCharacterData()
    -- Verify we're on the correct realm before initializing any data
    if not IsValidRealm() then
        print("|cffff0000AuberdineExporter:|r Cet addon ne fonctionne que sur le serveur Auberdine. Serveur actuel: " .. GetRealmName())
        return nil
    end
    
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
        -- Character initialization message disabled for cleaner experience
        -- print("|cff00ff00AuberdineExporter:|r Personnage " .. UnitName("player") .. " initialisé (locale: " .. locale .. ")")
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

-- Minimap Button (now handled by AuberdineMinimapButton.lua)
-- Old CreateMinimapButton function removed

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

-- Fonction pour récupérer la version depuis le fichier .toc
local function GetAddonVersion()
    local addonName = "AuberdineExporter"
    local version = GetAddOnMetadata(addonName, "Version")
    return version or "1.4.1" -- Fallback au cas où la lecture échoue
end

-- Clé client publique pour auberdine.eu
AuberdineExporterClientKey = "auberdine-v1"

-- Challenge fixe pour auberdine.eu (sécurité côté serveur)
AuberdineExporterChallenge = "auberdine-2025-recipe-export"

-- ===== FONCTIONS DE GESTION DES PERSONNAGES ET COMPTES =====

-- Types de personnages
local CHARACTER_TYPES = {
    MAIN = "main",          -- Personnage principal
    ALT = "alt",           -- Personnage alternatif
    BANK = "bank",         -- Personnage banque
    MULE = "mule"          -- Personnage de stockage
}

-- Générateur de clés d'identification uniques (format: AB-7K9M-X2P4)
local function GenerateUniqueAccountKey()
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local key = "AB-"
    
    -- Premier bloc de 4 caractères
    for i = 1, 4 do
        local index = math.random(1, string.len(chars))
        key = key .. string.sub(chars, index, index)
    end
    
    key = key .. "-"
    
    -- Deuxième bloc de 4 caractères
    for i = 1, 4 do
        local index = math.random(1, string.len(chars))
        key = key .. string.sub(chars, index, index)
    end
    
    return key
end

-- Générateur de noms de groupes auto (format: DragonRouge-42)
local function GenerateDefaultGroupName()
    local words1 = {"Dragon", "Lune", "Soleil", "Ombre", "Flamme", "Glace", "Vent", "Terre", "Mer", "Ciel", "Fer", "Or", "Argent", "Bronze", "Cristal"}
    local words2 = {"Rouge", "Bleu", "Vert", "Noir", "Blanc", "Argent", "Doré", "Sombre", "Brillant", "Gelé", "Ardent", "Mystique", "Ancien", "Noble", "Sauvage"}
    
    local word1 = words1[math.random(1, #words1)]
    local word2 = words2[math.random(1, #words2)]
    local number = math.random(10, 99)
    
    return word1 .. word2 .. "-" .. number
end

-- Obtenir ou créer une clé de compte unique globale
local function GetOrCreateAccountKey()
    if not AuberdineExporterDB.accountKey then
        AuberdineExporterDB.accountKey = GenerateUniqueAccountKey()
    end
    return AuberdineExporterDB.accountKey
end

-- Valider le format d'une accountKey
local function IsValidAccountKey(key)
    if not key or type(key) ~= "string" then
        return false
    end
    -- Format: AB-XXXX-YYYY où X et Y sont A-Z ou 0-9
    local pattern = "^AB%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]$"
    local match = string.match(key, pattern)
    
    return match ~= nil
end

-- Définir manuellement une accountKey (pour lier des comptes)
local function SetAccountKey(newKey)
    if not IsValidAccountKey(newKey) then
        return false, "Format invalide. Utilisez le format AB-XXXX-YYYY (ex: AB-1054-YFNJ)"
    end
    
    local oldKey = AuberdineExporterDB.accountKey
    AuberdineExporterDB.accountKey = newKey
    
    print("|cff00ff00AuberdineExporter:|r AccountKey mise à jour !")
    if oldKey then
        print("  Ancienne clé: |cffffffff" .. oldKey .. "|r")
    end
    print("  Nouvelle clé: |cffffffff" .. newKey .. "|r")
    print("|cffff8000Important:|r Cette modification prendra effet au prochain export.")
    
    return true, "AccountKey définie avec succès"
end

-- Exposer les fonctions dans l'objet global pour l'interface
function AuberdineExporter:GetOrCreateAccountKey()
    return GetOrCreateAccountKey()
end

function AuberdineExporter:SetAccountKey(newKey)
    return SetAccountKey(newKey)
end

function AuberdineExporter:IsValidAccountKey(key)
    return IsValidAccountKey(key)
end

function AuberdineExporter:GenerateDefaultGroupName()
    return GenerateDefaultGroupName()
end

-- Initialiser les paramètres d'un personnage
function InitializeCharacterSettings(charKey)
    if not AuberdineExporterDB.characterSettings then
        AuberdineExporterDB.characterSettings = {}
    end
    
    if not AuberdineExporterDB.characterSettings[charKey] then
        -- S'assurer qu'il y a toujours un groupe unique généré
        local defaultGroup
        if not AuberdineExporterDB.accountGroup then
            defaultGroup = GenerateDefaultGroupName()
            AuberdineExporterDB.accountGroup = defaultGroup
        else
            defaultGroup = AuberdineExporterDB.accountGroup
        end
        
        AuberdineExporterDB.characterSettings[charKey] = {
            exportEnabled = true,           -- Exporter ce personnage
            characterType = CHARACTER_TYPES.MAIN, -- Type par défaut
            mainCharacter = charKey,        -- Son main (lui-même par défaut)
            accountGroup = defaultGroup,    -- Groupe de compte généré
            notes = "",                     -- Notes utilisateur
            lastModified = time()
        }
    end
    return AuberdineExporterDB.characterSettings[charKey]
end

-- Fonctions de gestion des types de personnages
function SetCharacterType(charKey, characterType)
    if not CHARACTER_TYPES[string.upper(characterType)] then
        print("|cffff0000AuberdineExporter:|r Type de personnage invalide: " .. characterType)
        print("Types valides: main, alt, bank, mule")
        return false
    end
    
    InitializeCharacterSettings(charKey)
    AuberdineExporterDB.characterSettings[charKey].characterType = CHARACTER_TYPES[string.upper(characterType)]
    AuberdineExporterDB.characterSettings[charKey].lastModified = time()
    
    local charData = AuberdineExporterDB.characters[charKey]
    local charName = charData and charData.name or charKey
    print("|cff00ff00AuberdineExporter:|r " .. charName .. " défini comme " .. characterType)
    return true
end

function GetCharacterType(charKey)
    local settings = AuberdineExporterDB.characterSettings and AuberdineExporterDB.characterSettings[charKey]
    return settings and settings.characterType or CHARACTER_TYPES.MAIN
end

-- Fonctions de gestion des liens entre personnages
function LinkCharacterToMain(charKey, mainCharKey)
    if not AuberdineExporterDB.characters[mainCharKey] then
        print("|cffff0000AuberdineExporter:|r Personnage principal introuvable: " .. mainCharKey)
        return false
    end
    
    InitializeCharacterSettings(charKey)
    InitializeCharacterSettings(mainCharKey)
    
    AuberdineExporterDB.characterSettings[charKey].mainCharacter = mainCharKey
    AuberdineExporterDB.characterSettings[charKey].lastModified = time()
    
    local charData = AuberdineExporterDB.characters[charKey]
    local mainData = AuberdineExporterDB.characters[mainCharKey]
    local charName = charData and charData.name or charKey
    local mainName = mainData and mainData.name or mainCharKey
    
    print("|cff00ff00AuberdineExporter:|r " .. charName .. " lié au main " .. mainName)
    return true
end

-- Fonctions de gestion des groupes de comptes
function SetAccountGroup(charKey, groupName)
    InitializeCharacterSettings(charKey)
    
    -- Si aucun nom de groupe fourni, utiliser le groupe par défaut généré ou en générer un nouveau
    if not groupName then
        if AuberdineExporterDB.accountGroup then
            groupName = AuberdineExporterDB.accountGroup
        else
            groupName = GenerateDefaultGroupName()
            AuberdineExporterDB.accountGroup = groupName
        end
    end
    
    AuberdineExporterDB.characterSettings[charKey].accountGroup = groupName
    AuberdineExporterDB.characterSettings[charKey].lastModified = time()
    
    local charData = AuberdineExporterDB.characters[charKey]
    local charName = charData and charData.name or charKey
    print("|cff00ff00AuberdineExporter:|r " .. charName .. " ajouté au groupe de compte: " .. groupName)
end

function GetAccountGroup(charKey)
    local settings = AuberdineExporterDB.characterSettings and AuberdineExporterDB.characterSettings[charKey]
    -- Si pas de groupe défini, en générer un automatiquement
    if not settings or not settings.accountGroup then
        if not AuberdineExporterDB.accountGroup then
            AuberdineExporterDB.accountGroup = GenerateDefaultGroupName()
        end
        return AuberdineExporterDB.accountGroup
    end
    return settings.accountGroup
end

-- Fonction pour lister tous les personnages avec leurs informations
function ListCharacterConfiguration()
    print("|cff00ff00=== Configuration des Personnages ===|r")
    
    if not AuberdineExporterDB.characters or not next(AuberdineExporterDB.characters) then
        print("|cffff8000Aucun personnage trouvé.|r")
        return
    end
    
    -- Organiser par groupe de compte
    local accountGroups = {}
    
    for charKey, charData in pairs(AuberdineExporterDB.characters) do
        local settings = InitializeCharacterSettings(charKey)
        local group = settings.accountGroup
        
        if not accountGroups[group] then
            accountGroups[group] = {}
        end
        
        table.insert(accountGroups[group], {
            key = charKey,
            data = charData,
            settings = settings
        })
    end
    
    for groupName, characters in pairs(accountGroups) do
        print("|cff00ff8f=== Groupe de compte: " .. groupName .. " ===|r")
        
        for _, char in ipairs(characters) do
            local exportStatus = char.settings.exportEnabled and "|cff00ff00[ACTIF]|r" or "|cffff0000[DÉSACTIVÉ]|r"
            local typeColor = ""
            
            if char.settings.characterType == CHARACTER_TYPES.MAIN then
                typeColor = "|cff00ff00"
            elseif char.settings.characterType == CHARACTER_TYPES.ALT then
                typeColor = "|cff8080ff"
            elseif char.settings.characterType == CHARACTER_TYPES.BANK then
                typeColor = "|cffffff00"
            else
                typeColor = "|cffff8000"
            end
            
            local mainInfo = ""
            if char.settings.mainCharacter ~= char.key then
                local mainData = AuberdineExporterDB.characters[char.settings.mainCharacter]
                if mainData then
                    mainInfo = " → Main: " .. mainData.name
                end
            end
            
            print("  " .. exportStatus .. " " .. typeColor .. char.data.name .. "|r (" .. 
                  char.settings.characterType .. ")" .. mainInfo)
        end
        print("")
    end
end

-- Fonction pour activer/désactiver l'export d'un personnage
function ToggleCharacterExport(charKey, enabled)
    InitializeCharacterSettings(charKey)
    
    if enabled == nil then
        -- Toggle
        AuberdineExporterDB.characterSettings[charKey].exportEnabled = 
            not AuberdineExporterDB.characterSettings[charKey].exportEnabled
    else
        AuberdineExporterDB.characterSettings[charKey].exportEnabled = enabled
    end
    
    local charData = AuberdineExporterDB.characters[charKey]
    local charName = charData and charData.name or charKey
    local status = AuberdineExporterDB.characterSettings[charKey].exportEnabled and "activé" or "désactivé"
    
    print("|cff00ff00AuberdineExporter:|r Export " .. status .. " pour " .. charName)
end

-- Fonction pour obtenir la liste des personnages à exporter
function GetExportableCharacters()
    local exportableChars = {}
    
    if not AuberdineExporterDB.characters then
        return exportableChars
    end
    
    for charKey, charData in pairs(AuberdineExporterDB.characters) do
        local settings = AuberdineExporterDB.characterSettings and AuberdineExporterDB.characterSettings[charKey]
        local exportEnabled = not settings or settings.exportEnabled -- Défaut: activé
        
        if exportEnabled then
            exportableChars[charKey] = charData
        end
    end
    
    return exportableChars
end

-- =====================================================================
-- ===== COLLECTE INVENTAIRE (équipement, sacs, banque) ET CONSOMMABLES
-- =====================================================================

-- Slots d'équipement scannés (1..19, hors slots cosmétiques inutiles)
local EQUIPMENT_SLOTS = {
    [1]  = "Head",     [2]  = "Neck",     [3]  = "Shoulder", [4]  = "Shirt",
    [5]  = "Chest",    [6]  = "Waist",    [7]  = "Legs",     [8]  = "Feet",
    [9]  = "Wrist",    [10] = "Hands",    [11] = "Finger1",  [12] = "Finger2",
    [13] = "Trinket1", [14] = "Trinket2", [15] = "Back",     [16] = "MainHand",
    [17] = "OffHand",  [18] = "Ranged",   [19] = "Tabard",
}

-- Constantes de bagId
local BAG_BACKPACK = 0
local BAG_FIRST    = 1
local BAG_LAST     = 4
local BANK_MAIN    = -1
local BANK_FIRST   = 5
local BANK_LAST    = 11
local KEYRING_BAG  = -2

-- Compatibilité API : utiliser C_Container si dispo, sinon fallback global
local function GetBagNumSlots(bagId)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bagId) or 0
    elseif GetContainerNumSlots then
        return GetContainerNumSlots(bagId) or 0
    end
    return 0
end

local function GetBagItemLink(bagId, slot)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bagId, slot)
    elseif GetContainerItemLink then
        return GetContainerItemLink(bagId, slot)
    end
    return nil
end

local function GetBagItemInfo(bagId, slot)
    -- Renvoie : count, itemId, hyperlink
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bagId, slot)
        if info then
            return info.stackCount or 1, info.itemID, info.hyperlink
        end
        return nil, nil, nil
    elseif GetContainerItemInfo then
        -- API Classic legacy : icon, count, locked, quality, readable, lootable, link, isFiltered, noValue, itemID
        local _, count, _, _, _, _, link, _, _, itemID = GetContainerItemInfo(bagId, slot)
        return count or 1, itemID, link
    end
    return nil, nil, nil
end

-- Extraire l'itemId depuis un itemLink en fallback
local function ExtractItemIdFromLink(itemLink)
    if not itemLink then return nil end
    local id = string.match(itemLink, "item:(%d+):")
    return id and tonumber(id) or nil
end

-- Construire un enregistrement d'objet normalisé à partir d'un lien
local function BuildItemRecord(itemLink, count, itemId)
    if not itemLink and not itemId then return nil end

    local name, link, quality, iLevel, _, itemType, itemSubType, _, equipLoc, _, _, classID, subClassID
    if GetItemInfo then
        name, link, quality, iLevel, _, itemType, itemSubType, _, equipLoc, _, _, classID, subClassID = GetItemInfo(itemLink or itemId)
    end

    local resolvedId = itemId or ExtractItemIdFromLink(itemLink or link)
    if not resolvedId then return nil end

    return {
        id        = resolvedId,
        name      = name,
        link      = link or itemLink,
        count     = count or 1,
        quality   = quality,
        iLevel    = iLevel,
        type      = itemType,
        subType   = itemSubType,
        equipLoc  = equipLoc and equipLoc ~= "" and equipLoc or nil,
        classID   = classID,
        subClassID = subClassID,
    }
end

-- Collecter le contenu d'un bag (renvoie la table { numSlots, slots = {[slot]=item} })
local function ScanContainer(bagId)
    local numSlots = GetBagNumSlots(bagId)
    local container = { numSlots = numSlots, slots = {} }
    if not numSlots or numSlots <= 0 then
        return container
    end
    for slot = 1, numSlots do
        local link = GetBagItemLink(bagId, slot)
        if link then
            local count, itemId = GetBagItemInfo(bagId, slot)
            local record = BuildItemRecord(link, count, itemId)
            if record then
                container.slots[slot] = record
            end
        end
    end
    return container
end

local function EnsureInventoryContainer(charKey)
    local charData = AuberdineExporterDB.characters[charKey]
    if not charData then return nil end
    if not charData.inventory then
        charData.inventory = {
            equipment = {},
            bags = {},
            bank = { main = nil, bags = {}, lastUpdate = 0 },
            keyring = nil,
            lastUpdate = 0,
        }
    end
    if not charData.inventory.bank then
        charData.inventory.bank = { main = nil, bags = {}, lastUpdate = 0 }
    end
    return charData.inventory
end

-- Scan de l'équipement porté
local function ScanEquipment(charKey)
    if not charKey or not AuberdineExporterDB.characters[charKey] then return 0 end
    local inventory = EnsureInventoryContainer(charKey)
    inventory.equipment = {}
    local count = 0
    for slotId, slotName in pairs(EQUIPMENT_SLOTS) do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", slotId)
        if link then
            local record = BuildItemRecord(link, 1, nil)
            if record then
                record.slot = slotId
                record.slotName = slotName
                inventory.equipment[slotId] = record
                count = count + 1
            end
        end
    end
    inventory.lastUpdate = time()
    return count
end

-- Scan de tous les sacs (backpack + 4 sacs)
local function ScanBags(charKey)
    if not charKey or not AuberdineExporterDB.characters[charKey] then return 0 end
    local inventory = EnsureInventoryContainer(charKey)
    inventory.bags = {}
    local total = 0
    for bagId = BAG_BACKPACK, BAG_LAST do
        local container = ScanContainer(bagId)
        inventory.bags[bagId] = container
        for _ in pairs(container.slots) do total = total + 1 end
    end
    -- Keyring (Classic Era)
    if KEYRING_BAG and GetBagNumSlots(KEYRING_BAG) > 0 then
        inventory.keyring = ScanContainer(KEYRING_BAG)
    end
    inventory.lastUpdate = time()
    return total
end

-- Scan de la banque (uniquement quand BANKFRAME est ouvert)
local function ScanBank(charKey)
    if not charKey or not AuberdineExporterDB.characters[charKey] then return 0 end
    local inventory = EnsureInventoryContainer(charKey)
    local bank = { main = nil, bags = {}, lastUpdate = time() }
    bank.main = ScanContainer(BANK_MAIN)
    local total = 0
    for _ in pairs(bank.main.slots) do total = total + 1 end
    for bagId = BANK_FIRST, BANK_LAST do
        local container = ScanContainer(bagId)
        if container.numSlots and container.numSlots > 0 then
            bank.bags[bagId] = container
            for _ in pairs(container.slots) do total = total + 1 end
        end
    end
    inventory.bank = bank
    inventory.lastUpdate = time()
    return total
end

-- Détection des consommables : classID 0 (Consumable) ou catégorisation héritée
local CONSUMABLE_CLASS_ID = 0

-- Buckets utilisés par auberdine.eu pour la "chambre froide"
-- Mapping basé sur subClassID Consumable (Classic Era):
-- 0=Consumable générique, 1=Potion, 2=Élixir, 3=Flacon, 4=Parchemin,
-- 5=Nourriture/Boisson, 6=Amélioration d'objet, 7=Bandage, 8=Autre
local CONSUMABLE_SUBCLASS_BUCKETS = {
    [0] = "other",
    [1] = "potion",
    [2] = "elixir",
    [3] = "flask",
    [4] = "scroll",
    [5] = "food",
    [6] = "enhancement",  -- pierres à aiguiser, huiles, etc.
    [7] = "bandage",
    [8] = "other",
}

-- Détection complémentaire par mots-clés (juju, huile, pierre, etc.)
-- pour les serveurs Classic où classID/subClassID ne sont pas toujours fiables.
local CONSUMABLE_NAME_HINTS = {
    { pattern = "[Jj]uju",                          bucket = "juju" },
    { pattern = "[Hh]uile",                         bucket = "enhancement" },
    { pattern = "[Oo]il of",                        bucket = "enhancement" },
    { pattern = "[Ss]harpening [Ss]tone",           bucket = "enhancement" },
    { pattern = "[Pp]ierre %a* [aà]iguiser",        bucket = "enhancement" },
    { pattern = "[Ww]eightstone",                   bucket = "enhancement" },
    { pattern = "[Pp]ierre de poids",               bucket = "enhancement" },
}

local function IsConsumableRecord(record)
    if not record then return false end
    if record.classID == CONSUMABLE_CLASS_ID then return true end
    -- Fallback texte si classID indisponible (cache GetItemInfo non chargé par exemple)
    if record.type and (record.type == "Consumable" or record.type == "Consommable") then
        return true
    end
    return false
end

local function GetConsumableBucket(record)
    if not record then return "other" end
    if record.name then
        for _, hint in ipairs(CONSUMABLE_NAME_HINTS) do
            if string.find(record.name, hint.pattern) then
                return hint.bucket
            end
        end
    end
    if record.subClassID and CONSUMABLE_SUBCLASS_BUCKETS[record.subClassID] then
        return CONSUMABLE_SUBCLASS_BUCKETS[record.subClassID]
    end
    return "other"
end

-- Recalcule l'agrégat des consommables d'un personnage à partir de
-- l'équipement (ignoré), des sacs et de la banque.
local function RecomputeConsumables(charKey)
    local charData = AuberdineExporterDB.characters[charKey]
    if not charData or not charData.inventory then return 0 end

    local consumables = {}

    local function addRecord(record, location)
        if not IsConsumableRecord(record) then return end
        local id = record.id
        if not id then return end
        local entry = consumables[id]
        if not entry then
            entry = {
                id = id,
                name = record.name,
                link = record.link,
                quality = record.quality,
                classID = record.classID,
                subClassID = record.subClassID,
                bucket = GetConsumableBucket(record),
                count = 0,
                locations = { bags = 0, bank = 0 },
            }
            consumables[id] = entry
        end
        entry.count = entry.count + (record.count or 1)
        entry.locations[location] = (entry.locations[location] or 0) + (record.count or 1)
        -- Compléter le nom si on l'a obtenu plus tard
        if not entry.name and record.name then entry.name = record.name end
        if not entry.link and record.link then entry.link = record.link end
    end

    -- Sacs
    if charData.inventory.bags then
        for _, container in pairs(charData.inventory.bags) do
            if container.slots then
                for _, record in pairs(container.slots) do
                    addRecord(record, "bags")
                end
            end
        end
    end
    if charData.inventory.keyring and charData.inventory.keyring.slots then
        for _, record in pairs(charData.inventory.keyring.slots) do
            addRecord(record, "bags")
        end
    end

    -- Banque
    if charData.inventory.bank then
        if charData.inventory.bank.main and charData.inventory.bank.main.slots then
            for _, record in pairs(charData.inventory.bank.main.slots) do
                addRecord(record, "bank")
            end
        end
        if charData.inventory.bank.bags then
            for _, container in pairs(charData.inventory.bank.bags) do
                if container.slots then
                    for _, record in pairs(container.slots) do
                        addRecord(record, "bank")
                    end
                end
            end
        end
    end

    charData.consumables = {
        items = consumables,
        lastUpdate = time(),
    }

    local count = 0
    for _ in pairs(consumables) do count = count + 1 end
    return count
end

-- =====================================================================
-- ===== SNAPSHOT LOCAL BRUT (sacs + banque)
-- =====================================================================
-- Ces données sont stockées UNIQUEMENT dans la SavedVariable locale,
-- destinées à être consommées par un client Electron local.
-- Elles ne sont PAS incluses dans les exports JSON envoyés à auberdine.eu.
-- =====================================================================

local function ExtractItemString(itemLink)
    if not itemLink then return nil end
    return string.match(itemLink, "item[%-?%d:]+")
end

-- Capture l'intégralité des champs disponibles pour un slot donné
local function CaptureRawSlot(bagId, slot)
    local link = GetBagItemLink(bagId, slot)
    if not link then return nil end

    local raw = {
        bag = bagId,
        slot = slot,
        link = link,
        itemString = ExtractItemString(link),
    }

    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bagId, slot)
        if info then
            raw.iconFileID = info.iconFileID
            raw.stackCount = info.stackCount
            raw.isLocked = info.isLocked
            raw.quality = info.quality
            raw.isReadable = info.isReadable
            raw.hasLoot = info.hasLoot
            raw.hyperlink = info.hyperlink
            raw.isFiltered = info.isFiltered
            raw.hasNoValue = info.hasNoValue
            raw.itemId = info.itemID
            raw.isBound = info.isBound
        end
    elseif GetContainerItemInfo then
        local icon, count, locked, quality, readable, lootable, link2, isFiltered, noValue, itemID = GetContainerItemInfo(bagId, slot)
        raw.iconFileID = icon
        raw.stackCount = count
        raw.isLocked = locked
        raw.quality = quality
        raw.isReadable = readable
        raw.hasLoot = lootable
        raw.hyperlink = link2 or link
        raw.isFiltered = isFiltered
        raw.hasNoValue = noValue
        raw.itemId = itemID
    end

    if not raw.itemId then
        raw.itemId = ExtractItemIdFromLink(link)
    end

    if GetItemInfo then
        local name, _, quality, iLevel, reqLevel, itemType, itemSubType,
              maxStack, equipLoc, _, sellPrice, classID, subClassID, bindType
              = GetItemInfo(link)
        raw.name = name
        if quality and not raw.quality then raw.quality = quality end
        raw.itemLevel = iLevel
        raw.requiredLevel = reqLevel
        raw.type = itemType
        raw.subType = itemSubType
        raw.maxStackCount = maxStack
        raw.equipLoc = (equipLoc and equipLoc ~= "") and equipLoc or nil
        raw.sellPrice = sellPrice
        raw.classID = classID
        raw.subClassID = subClassID
        raw.bindType = bindType
    end

    return raw
end

local function EnsureLocalSnapshotContainer(charKey)
    local charData = AuberdineExporterDB.characters[charKey]
    if not charData then return nil end
    if not charData.localSnapshot then
        charData.localSnapshot = {
            bags = {},
            bank = { main = nil, bags = {} },
            keyring = nil,
            lastBagsUpdate = 0,
            lastBankUpdate = 0,
            lastUpdate = 0,
        }
    end
    if not charData.localSnapshot.bank then
        charData.localSnapshot.bank = { main = nil, bags = {} }
    end
    return charData.localSnapshot
end

local function ScanLocalSnapshotContainer(bagId)
    local numSlots = GetBagNumSlots(bagId) or 0
    local container = { numSlots = numSlots, slots = {} }
    if numSlots <= 0 then return container end
    for slot = 1, numSlots do
        local raw = CaptureRawSlot(bagId, slot)
        if raw then
            container.slots[slot] = raw
        end
    end
    return container
end

local function ScanLocalSnapshotBags(charKey)
    if not charKey or not AuberdineExporterDB.characters[charKey] then return 0 end
    local snap = EnsureLocalSnapshotContainer(charKey)
    snap.bags = {}
    local total = 0
    for bagId = BAG_BACKPACK, BAG_LAST do
        local container = ScanLocalSnapshotContainer(bagId)
        snap.bags[bagId] = container
        for _ in pairs(container.slots) do total = total + 1 end
    end
    if KEYRING_BAG and (GetBagNumSlots(KEYRING_BAG) or 0) > 0 then
        snap.keyring = ScanLocalSnapshotContainer(KEYRING_BAG)
        for _ in pairs(snap.keyring.slots) do total = total + 1 end
    end
    snap.lastBagsUpdate = time()
    snap.lastUpdate = snap.lastBagsUpdate
    return total
end

local function ScanLocalSnapshotBank(charKey)
    if not charKey or not AuberdineExporterDB.characters[charKey] then return 0 end
    local snap = EnsureLocalSnapshotContainer(charKey)
    local bank = { main = nil, bags = {} }
    bank.main = ScanLocalSnapshotContainer(BANK_MAIN)
    local total = 0
    for _ in pairs(bank.main.slots) do total = total + 1 end
    for bagId = BANK_FIRST, BANK_LAST do
        local container = ScanLocalSnapshotContainer(bagId)
        if container.numSlots and container.numSlots > 0 then
            bank.bags[bagId] = container
            for _ in pairs(container.slots) do total = total + 1 end
        end
    end
    snap.bank = bank
    snap.lastBankUpdate = time()
    snap.lastUpdate = snap.lastBankUpdate
    return total
end

-- Throttle pour éviter les scans intempestifs (BAG_UPDATE etc.)
local inventoryScanState = {
    pendingBags = false,
    pendingEquipment = false,
    pendingBank = false,
    bankOpen = false,
    lastBagsScan = 0,
    lastEquipmentScan = 0,
    lastBankScan = 0,
}

local INVENTORY_SCAN_THROTTLE = 2 -- secondes mini entre deux scans automatiques

local function RunBagsScan()
    inventoryScanState.pendingBags = false
    if not IsValidRealm() then return end
    local charKey = InitializeCharacterData()
    if not charKey then return end
    ScanBags(charKey)
    ScanLocalSnapshotBags(charKey)
    RecomputeConsumables(charKey)
    inventoryScanState.lastBagsScan = time()
end

local function RunEquipmentScan()
    inventoryScanState.pendingEquipment = false
    if not IsValidRealm() then return end
    local charKey = InitializeCharacterData()
    if not charKey then return end
    ScanEquipment(charKey)
    inventoryScanState.lastEquipmentScan = time()
end

local function RunBankScan()
    inventoryScanState.pendingBank = false
    if not IsValidRealm() then return end
    if not inventoryScanState.bankOpen then return end
    local charKey = InitializeCharacterData()
    if not charKey then return end
    ScanBank(charKey)
    ScanLocalSnapshotBank(charKey)
    RecomputeConsumables(charKey)
    inventoryScanState.lastBankScan = time()
end

local function ScheduleBagsScan()
    if inventoryScanState.pendingBags then return end
    inventoryScanState.pendingBags = true
    C_Timer.After(INVENTORY_SCAN_THROTTLE, RunBagsScan)
end

local function ScheduleEquipmentScan()
    if inventoryScanState.pendingEquipment then return end
    inventoryScanState.pendingEquipment = true
    C_Timer.After(1, RunEquipmentScan)
end

local function ScheduleBankScan()
    if inventoryScanState.pendingBank then return end
    inventoryScanState.pendingBank = true
    C_Timer.After(1, RunBankScan)
end

-- Scan complet inventaire (utilisé par /auberdine scan et au login)
local function ScanFullInventory()
    if not IsValidRealm() then return 0, 0, 0 end
    local charKey = InitializeCharacterData()
    if not charKey then return 0, 0, 0 end
    local equipCount = ScanEquipment(charKey)
    local bagCount = ScanBags(charKey)
    ScanLocalSnapshotBags(charKey)
    local bankCount = 0
    if inventoryScanState.bankOpen then
        bankCount = ScanBank(charKey)
        ScanLocalSnapshotBank(charKey)
    end
    local consumableCount = RecomputeConsumables(charKey)
    return equipCount, bagCount, bankCount, consumableCount
end

-- Exposer les fonctions au reste du fichier / interface
AuberdineExporter.ScanFullInventory = ScanFullInventory
AuberdineExporter.ScanEquipment = function(self) return ScanEquipment(GetCurrentCharacterKey()) end
AuberdineExporter.ScanBags = function(self) return ScanBags(GetCurrentCharacterKey()) end
AuberdineExporter.ScanBank = function(self) return ScanBank(GetCurrentCharacterKey()) end
AuberdineExporter.RecomputeConsumables = function(self) return RecomputeConsumables(GetCurrentCharacterKey()) end
AuberdineExporter.ScanLocalSnapshotBags = function(self) return ScanLocalSnapshotBags(GetCurrentCharacterKey()) end
AuberdineExporter.ScanLocalSnapshotBank = function(self) return ScanLocalSnapshotBank(GetCurrentCharacterKey()) end
function AuberdineExporter:GetLocalSnapshot(charKey)
    charKey = charKey or GetCurrentCharacterKey()
    local charData = AuberdineExporterDB and AuberdineExporterDB.characters and AuberdineExporterDB.characters[charKey]
    return charData and charData.localSnapshot or nil
end

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

-- Export functions (GLOBAL pour l'UI)

-- Variable globale pour le challenge (fixe pour la sécurité)
-- AuberdineExporterChallenge est défini plus haut

function ExportToJSON()
    -- Export multi-personnages avec séparation claire des données
    
    -- Métadonnées système pour auberdine.eu
    local exportMetadata = {
        addon = "AuberdineExporter",
        version = AuberdineExporterDB.version or GetAddonVersion(),
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
    
    -- Ajouter la clé d'identification unique du compte
    exportMetadata.accountKey = GetOrCreateAccountKey()
    -- S'assurer qu'il y a toujours un groupe unique (jamais "default")
    if not AuberdineExporterDB.accountGroup then
        AuberdineExporterDB.accountGroup = GenerateDefaultGroupName()
    end
    -- NOTE: accountGroup retiré des métadonnées car chaque personnage peut avoir son propre groupe en v1.3.2
    
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
            totalEquipment = 0,
            totalBagItems = 0,
            totalBankItems = 0,
            totalConsumables = 0,
            exportedBy = UnitName("player") .. "-" .. GetRealmName(),
            exportedAt = GetZoneText and GetZoneText() or "unknown",
            -- NOUVEAU v1.3.2: Statistiques de configuration
            charactersByType = {},
            accountGroups = {},
            exportSettings = {
                onlyExportEnabled = true,
                includeCharacterConfig = true
            }
        },
        
        -- NOUVEAU v1.3.2: Relations entre personnages et comptes
        relationships = {
            accountGroups = {},     -- Groupes de comptes
            mainCharacters = {},    -- Liens main/alt
            characterTypes = {}     -- Types de personnages
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
    
    -- Construire les données pour chaque personnage (uniquement ceux sélectionnés pour l'export)
    local exportableCharacters = GetExportableCharacters()
    if exportableCharacters then
        for charKey, charData in pairs(exportableCharacters) do
            -- Récupérer les paramètres de configuration du personnage
            local charSettings = InitializeCharacterSettings(charKey)
            
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
                
                -- Configuration du personnage (NOUVEAU dans v1.3.2)
                configuration = {
                    characterType = charSettings.characterType,
                    mainCharacter = charSettings.mainCharacter,
                    accountGroup = charSettings.accountGroup,
                    exportEnabled = charSettings.exportEnabled,
                    lastModified = charSettings.lastModified,
                    notes = charSettings.notes or ""
                },
                
                -- Localisation si c'est le personnage connecté
                location = {},
                
                -- Statistiques de ce personnage
                stats = {
                    totalProfessions = 0,
                    totalRecipes = 0,
                    totalSkills = 0,
                    totalReputations = 0,
                    totalEquipment = 0,
                    totalBagItems = 0,
                    totalBankItems = 0,
                    totalConsumables = 0,
                },

                -- Professions de ce personnage
                professions = {},

                -- Skills de ce personnage
                skills = charData.skills or {},

                -- Réputations de ce personnage
                reputations = charData.reputations or {},

                -- Inventaire (dressroom) : équipement, sacs et banque
                inventory = charData.inventory or { equipment = {}, bags = {}, bank = { main = nil, bags = {} } },

                -- Consommables agrégés (chambre froide)
                consumables = charData.consumables or { items = {}, lastUpdate = 0 }
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

            -- Compter les éléments d'inventaire
            if characterExport.inventory then
                if characterExport.inventory.equipment then
                    for _ in pairs(characterExport.inventory.equipment) do
                        characterExport.stats.totalEquipment = characterExport.stats.totalEquipment + 1
                    end
                end
                if characterExport.inventory.bags then
                    for _, container in pairs(characterExport.inventory.bags) do
                        if container.slots then
                            for _ in pairs(container.slots) do
                                characterExport.stats.totalBagItems = characterExport.stats.totalBagItems + 1
                            end
                        end
                    end
                end
                if characterExport.inventory.bank then
                    if characterExport.inventory.bank.main and characterExport.inventory.bank.main.slots then
                        for _ in pairs(characterExport.inventory.bank.main.slots) do
                            characterExport.stats.totalBankItems = characterExport.stats.totalBankItems + 1
                        end
                    end
                    if characterExport.inventory.bank.bags then
                        for _, container in pairs(characterExport.inventory.bank.bags) do
                            if container.slots then
                                for _ in pairs(container.slots) do
                                    characterExport.stats.totalBankItems = characterExport.stats.totalBankItems + 1
                                end
                            end
                        end
                    end
                end
            end
            if characterExport.consumables and characterExport.consumables.items then
                for _ in pairs(characterExport.consumables.items) do
                    characterExport.stats.totalConsumables = characterExport.stats.totalConsumables + 1
                end
            end
            
            -- Ajouter le personnage à l'export
            exportData.characters[charKey] = characterExport
            
            -- Mettre à jour les statistiques globales
            exportData.summary.totalCharacters = exportData.summary.totalCharacters + 1
            exportData.summary.totalProfessions = exportData.summary.totalProfessions + characterExport.stats.totalProfessions
            exportData.summary.totalRecipes = exportData.summary.totalRecipes + characterExport.stats.totalRecipes
            exportData.summary.totalEquipment = exportData.summary.totalEquipment + characterExport.stats.totalEquipment
            exportData.summary.totalBagItems = exportData.summary.totalBagItems + characterExport.stats.totalBagItems
            exportData.summary.totalBankItems = exportData.summary.totalBankItems + characterExport.stats.totalBankItems
            exportData.summary.totalConsumables = exportData.summary.totalConsumables + characterExport.stats.totalConsumables
            
            -- NOUVEAU v1.3.2: Collecter les statistiques de configuration
            local charType = charSettings.characterType
            if not exportData.summary.charactersByType[charType] then
                exportData.summary.charactersByType[charType] = 0
            end
            exportData.summary.charactersByType[charType] = exportData.summary.charactersByType[charType] + 1
            
            local accountGroup = charSettings.accountGroup
            if not exportData.summary.accountGroups[accountGroup] then
                exportData.summary.accountGroups[accountGroup] = 0
            end
            exportData.summary.accountGroups[accountGroup] = exportData.summary.accountGroups[accountGroup] + 1
            
            -- Ajouter aux relations
            exportData.relationships.characterTypes[charKey] = charSettings.characterType
            exportData.relationships.mainCharacters[charKey] = charSettings.mainCharacter
            
            if not exportData.relationships.accountGroups[accountGroup] then
                exportData.relationships.accountGroups[accountGroup] = {}
            end
            table.insert(exportData.relationships.accountGroups[accountGroup], charKey)
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
function ExportToSimpleJSON()
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
        version = AuberdineExporterDB.version or GetAddonVersion(),
        character = character,
        recipes = recipes,
        skills = freshSkills,
        reputations = freshReputations,
        inventory = charData.inventory or { equipment = {}, bags = {}, bank = { main = nil, bags = {} } },
        consumables = charData.consumables or { items = {}, lastUpdate = 0 }
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
function ExportToCSV()
    local csv = "Character,Realm,Level,Race,Class,Profession,ProfessionLevel,RecipeName\n"
    for charKey, charData in pairs(AuberdineExporterDB.characters) do
        for profName, profData in pairs(charData.professions or {}) do
            local recipes = profData.recipes or {}
            for recipeKey, recipeData in pairs(recipes) do
                local recipeName = recipeData.name or recipeKey
                csv = csv .. string.format(
                    '"%s","%s",%d,"%s","%s","%s",%d,"%s"\n',
                    charData.name, charData.realm, charData.level,
                    charData.race, charData.class, profName,
                    profData.level or 0, recipeName
                )
            end
        end
    end
    return csv
end

function CreateExportFrame(exportData, format)
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
    frame.UpdateContent = function()
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
                local equipped, bagItems, bankItems, consumables = 0, 0, 0, 0
                if charData.inventory then
                    if charData.inventory.equipment then
                        for _ in pairs(charData.inventory.equipment) do equipped = equipped + 1 end
                    end
                    if charData.inventory.bags then
                        for _, c in pairs(charData.inventory.bags) do
                            if c.slots then for _ in pairs(c.slots) do bagItems = bagItems + 1 end end
                        end
                    end
                    if charData.inventory.bank then
                        if charData.inventory.bank.main and charData.inventory.bank.main.slots then
                            for _ in pairs(charData.inventory.bank.main.slots) do bankItems = bankItems + 1 end
                        end
                        if charData.inventory.bank.bags then
                            for _, c in pairs(charData.inventory.bank.bags) do
                                if c.slots then for _ in pairs(c.slots) do bankItems = bankItems + 1 end end
                            end
                        end
                    end
                end
                if charData.consumables and charData.consumables.items then
                    for _ in pairs(charData.consumables.items) do consumables = consumables + 1 end
                end
                text = text .. string.format(
                    "• %s (%s): %d métiers, %d recettes | %d équipés, %d sac, %d banque, %d consommables\n",
                    charData.name, charData.class, charProfessions, charRecipes,
                    equipped, bagItems, bankItems, consumables
                )
            end
            
            text = text .. "\nDétail par métier (tous personnages):\n"
            for profName, profStats in pairs(stats.professionBreakdown) do
                text = text .. string.format("• %s: %d recettes sur %d personnages\n", 
                    profName, profStats.totalRecipes, profStats.characters)
            end
        end
        
        frame.content:SetText(text)
    end
    
    mainFrame = frame
    return frame
end

ToggleMainFrame = function()
    if AuberdineExporterUI and AuberdineExporterUI.ToggleMainFrame then
        AuberdineExporterUI:ToggleMainFrame()
    else
        -- Fallback: use the built-in simple frame
        local frame = CreateMainFrame()
        if frame:IsShown() then
            frame:Hide()
        else
            frame.UpdateContent()
            frame:Show()
        end
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
        -- Database initialization message disabled for cleaner experience
        -- print("|cffff8000AuberdineExporter:|r Database not initialized, initializing...")
        return
    end
    
    -- Petit délai pour éviter les conflits avec d'autres addons
    local function DelayedScan()
        local skillName, skillRank, skillMaxRank = GetTradeSkillLine()
        -- Debug message removed for cleaner chat experience
        -- print("|cff00ff00AuberdineExporter DEBUG:|r TradeSkill opened - Name: '" .. tostring(skillName) .. "', Rank: " .. tostring(skillRank) .. "/" .. tostring(skillMaxRank))

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
            for _, recipeData in pairs(recipes) do 
                recipeCount = recipeCount + 1 
            end
            if recipeCount == 0 then
                print("|cffff8000AuberdineExporter:|r Aucune recette trouvée pour " .. skillName .. ". Ouvrez la fenêtre du métier et vérifiez les filtres.")
            else
                print("|cff00ff00AuberdineExporter:|r " .. skillName .. " scanné - " .. recipeCount .. " recettes trouvées !")
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
        -- Database initialization message disabled for cleaner experience
        -- print("|cffff8000AuberdineExporter:|r Database not initialized, initializing...")
        return
    end
    
    -- Petit délai pour éviter les conflits avec d'autres addons
    local function DelayedCraftScan()
        local skillName, skillRank, skillMaxRank = GetCraftDisplaySkillLine()
        -- Debug message removed for cleaner chat experience
        -- print("|cff00ff00AuberdineExporter DEBUG:|r Craft opened - Name: '" .. tostring(skillName) .. "'")
        
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
            for _, recipeData in pairs(recipes) do 
                recipeCount = recipeCount + 1 
            end
            if recipeCount == 0 then
                print("|cffff8000AuberdineExporter:|r Aucune recette trouvée pour " .. skillName .. ". Ouvrez la fenêtre du métier et vérifiez les filtres.")
            else
                print("|cff00ff00AuberdineExporter:|r " .. skillName .. " scanné - " .. recipeCount .. " recettes trouvées !")
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
-- Inventaire & consommables
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("BANKFRAME_OPENED")
frame:RegisterEvent("BANKFRAME_CLOSED")
frame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
frame:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "AuberdineExporter" then
            if not AuberdineExporterDB then
                AuberdineExporterDB = {
                    version = GetAddonVersion(),
                    characters = {},
                    settings = {
                        autoScan = true,
                        shareData = true,
                        exportFormat = "json",
                        minimapButtonAngle = 0,
                        minimapButtonHidden = false,
                        verboseDebug = false
                    },
                    characterSettings = {},
                    accountLinks = {},
                    -- S'assurer qu'un groupe unique est créé dès l'initialisation
                    accountGroup = GenerateDefaultGroupName()
                }
                -- Database initialization message disabled for cleaner experience
                -- print("|cff00ff00AuberdineExporter:|r Base de données initialisée à ADDON_LOADED")
            else
                -- MIGRATION: Forcer la mise à jour de la version si elle est ancienne
                local currentVersion = GetAddonVersion()
                if not AuberdineExporterDB.version or AuberdineExporterDB.version ~= currentVersion then
                    AuberdineExporterDB.version = currentVersion
                end
            end
            -- Startup message reduced to essential information only
            -- print("|cff00ff00AuberdineExporter|r v" .. AuberdineExporterDB.version .. " chargé !")
        end
    elseif event == "PLAYER_LOGIN" then
        -- S'assurer que la base de données principale est complètement initialisée
        if not AuberdineExporterDB then
            AuberdineExporterDB = {
                version = GetAddonVersion(),
                characters = {},
                settings = {
                    autoScan = true,
                    shareData = true,
                    exportFormat = "json",
                    minimapButtonAngle = 0,
                    minimapButtonHidden = false,
                    verboseDebug = false
                },
                characterSettings = {},
                accountLinks = {},
                -- S'assurer qu'un groupe unique est créé dès l'initialisation
                accountGroup = GenerateDefaultGroupName()
            }
            -- Database re-initialization message disabled for cleaner experience
            -- print("|cff00ff00AuberdineExporter:|r Base de données réinitialisée à PLAYER_LOGIN")
        else
            -- MIGRATION: Forcer la mise à jour de la version si elle est ancienne
            local currentVersion = GetAddonVersion()
            if not AuberdineExporterDB.version or AuberdineExporterDB.version ~= currentVersion then
                AuberdineExporterDB.version = currentVersion
            end
        end
        
        -- Only proceed with character initialization and other features if we're on Auberdine
        if not IsValidRealm() then
            print("|cffff0000AuberdineExporter:|r Addon désactivé - Serveur non supporté: " .. GetRealmName())
            print("|cffff0000AuberdineExporter:|r Cet addon ne fonctionne que sur le serveur Auberdine.")
            return
        end
        
        local charKey = InitializeCharacterData()
        if charKey and AuberdineMinimapButton then
            AuberdineMinimapButton:Initialize()
        end
        
        -- MIGRATION v1.3.2: Remplacer "default" par un nom unique généré
        if AuberdineExporterDB.accountGroup == "default" or not AuberdineExporterDB.accountGroup then
            local newGroupName = GenerateDefaultGroupName()
            AuberdineExporterDB.accountGroup = newGroupName
            
            -- Mettre à jour tous les personnages qui utilisent "default"
            if AuberdineExporterDB.characterSettings then
                for charKey, settings in pairs(AuberdineExporterDB.characterSettings) do
                    if not settings.accountGroup or settings.accountGroup == "default" then
                        settings.accountGroup = newGroupName
                        settings.lastModified = time()
                    end
                end
            end
            
            print(string.format("|cff00ff00AuberdineExporter:|r Migration v1.3.2 - Nouveau nom de groupe généré: %s", newGroupName))
        end
        
        -- Vérifier LibRecipes avec retry
        local function CheckLibRecipes()
            if not LibRecipes then
                LibRecipes = LibStub("LibRecipes-3.0", true) or LibStub("LibRecipes-1.0a", true)
            end
            
            if LibRecipes then
                -- Library loading messages disabled for cleaner experience
                -- if LibRecipes.GetCount then
                --     print("|cff00ff00AuberdineExporter:|r LibRecipes-3.0 chargé avec " .. LibRecipes:GetCount() .. " recettes !")
                -- else
                --     print("|cff00ff00AuberdineExporter:|r LibRecipes-1.0a chargé (version legacy)")
                -- end
            else
                print("|cffff8000AuberdineExporter:|r Attention : LibRecipes non trouvée - Retry dans 3s...")
                C_Timer.After(3, CheckLibRecipes)
                return
            end
        end
        
        CheckLibRecipes()
        
        C_Timer.After(2, function()
            -- Auto-scan message disabled for cleaner experience
            -- print("|cff00ff00AuberdineExporter:|r Scan automatique de vos métiers...")
            ScanAllProfessions()
        end)
        print("|cff00ff00AuberdineExporter:|r Prêt ! Tapez /auberdine pour les commandes.")
        -- print("|cff00ff00AuberdineExporter:|r Bouton minimap disponible. Utilisez /auberdine scan pour un scan manuel.")
    elseif event == "TRADE_SKILL_SHOW" then
        if IsValidRealm() then
            OnTradeSkillShow()
        end
    elseif event == "CRAFT_SHOW" then
        if IsValidRealm() then
            OnCraftShow()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if IsValidRealm() then
            -- Léger délai pour laisser le cache GetItemInfo se peupler
            C_Timer.After(3, function()
                ScanFullInventory()
            end)
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        if IsValidRealm() then
            ScheduleBagsScan()
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        if IsValidRealm() then
            ScheduleEquipmentScan()
        end
    elseif event == "BANKFRAME_OPENED" then
        if IsValidRealm() then
            inventoryScanState.bankOpen = true
            ScheduleBankScan()
        end
    elseif event == "BANKFRAME_CLOSED" then
        inventoryScanState.bankOpen = false
    elseif event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYERBANKBAGSLOTS_CHANGED" then
        if IsValidRealm() and inventoryScanState.bankOpen then
            ScheduleBankScan()
        end
    end
end)

-- Test slash command first
SLASH_AUBERDINETEST1 = "/auberdinetest"
SlashCmdList["AUBERDINETEST"] = function(msg)
    print("|cff00ff00AuberdineExporter TEST:|r Slash commands OK ! Message: " .. tostring(msg))
    print("Les commandes principales devraient fonctionner...")
end

-- Main slash commands - COMPLETE VERSION with v1.3.2 features
local function HandleSlashCommand(msg)
    -- Verify we're on the correct realm before processing any commands
    if not IsValidRealm() then
        print("|cffff0000AuberdineExporter:|r Cette commande ne fonctionne que sur le serveur Auberdine.")
        print("|cffff0000AuberdineExporter:|r Serveur actuel: " .. GetRealmName())
        return
    end
    
    local args = {}
    for word in string.gmatch(msg or "", "%S+") do
        table.insert(args, word)
    end
    
    local command = string.lower(args[1] or "")
    -- Debug message removed for cleaner chat experience
    -- print("|cff00ff00AuberdineExporter:|r Commande reçue : '" .. command .. "'")
    
    if command == "show" or command == "" or command == "ui" then
        ToggleMainFrame()
    elseif command == "characters" or command == "chars" then
        ListCharacterConfiguration()
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
    elseif command == "clear" then
        if AuberdineExporter and AuberdineExporter.ClearMemoryData then
            AuberdineExporter:ClearMemoryData()
        else
            print("|cffff0000AuberdineExporter:|r Clear function not available!")
        end
    elseif command == "size" then
        if AuberdineExporter and AuberdineExporter.GetDataSizeInfo then
            local totalChars, totalSize, charSizes = AuberdineExporter:GetDataSizeInfo()
            print(string.format("|cff00ff00AuberdineExporter:|r Data size info: %d characters, ~%d bytes total", 
                totalChars, totalSize))
            
            for charKey, size in pairs(charSizes) do
                print(string.format("  %s: ~%d bytes", charKey, size))
            end
        else
            print("|cffff0000AuberdineExporter:|r Size function not available!")
        end
    elseif command == "minimap" then
        if AuberdineMinimapButton and AuberdineMinimapButton.button then
            if AuberdineMinimapButton.button:IsShown() then
                AuberdineMinimapButton:SetVisibility(false)
                print("|cff00ff00AuberdineExporter:|r Minimap button hidden")
            else
                AuberdineMinimapButton:SetVisibility(true)
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
        -- Scan complet de l'inventaire en parallèle
        local equipCount, bagCount, bankCount, consumableCount = ScanFullInventory()
        print(string.format(
            "|cff00ff00AuberdineExporter:|r Inventaire scanné : %d équipement, %d objets en sacs, %d en banque, %d consommables uniques.",
            equipCount or 0, bagCount or 0, bankCount or 0, consumableCount or 0
        ))
        if (bankCount or 0) == 0 and not inventoryScanState.bankOpen then
            print("|cffff8000AuberdineExporter:|r Ouvrez la banque pour collecter son contenu.")
        end
    elseif command == "inventory" or command == "inv" then
        local equipCount, bagCount, bankCount, consumableCount = ScanFullInventory()
        print(string.format(
            "|cff00ff00AuberdineExporter:|r Inventaire scanné : %d équipement, %d objets en sacs, %d en banque, %d consommables uniques.",
            equipCount or 0, bagCount or 0, bankCount or 0, consumableCount or 0
        ))
        if (bankCount or 0) == 0 and not inventoryScanState.bankOpen then
            print("|cffff8000AuberdineExporter:|r Ouvrez la banque pour collecter son contenu.")
        end
    elseif command == "localsnapshot" or command == "snapshot" or command == "snap" then
        -- Snapshot brut local des sacs et de la banque (NON exporté).
        -- Destiné à un futur client Electron qui lira la SavedVariable.
        local charKey = InitializeCharacterData()
        if not charKey then return end
        local bagCount = ScanLocalSnapshotBags(charKey)
        local bankCount = 0
        if inventoryScanState.bankOpen then
            bankCount = ScanLocalSnapshotBank(charKey)
        end
        local snap = AuberdineExporterDB.characters[charKey].localSnapshot
        local lastBags = snap and snap.lastBagsUpdate or 0
        local lastBank = snap and snap.lastBankUpdate or 0
        print(string.format(
            "|cff00ff00AuberdineExporter:|r Snapshot local mis à jour : %d objet(s) en sacs, %d en banque.",
            bagCount, bankCount
        ))
        print(string.format(
            "  • Dernier scan sacs   : %s",
            lastBags > 0 and date("%Y-%m-%d %H:%M:%S", lastBags) or "jamais"
        ))
        print(string.format(
            "  • Dernier scan banque : %s",
            lastBank > 0 and date("%Y-%m-%d %H:%M:%S", lastBank) or "jamais"
        ))
        if not inventoryScanState.bankOpen then
            print("|cffff8000Note:|r Ouvrez la banque pour rafraîchir son snapshot.")
        end
        print("|cffff8000Stockage local uniquement|r — non inclus dans les exports auberdine.eu.")
    elseif command == "consumables" or command == "consu" then
        local charKey = GetCurrentCharacterKey()
        RecomputeConsumables(charKey)
        local charData = AuberdineExporterDB.characters[charKey]
        local items = charData and charData.consumables and charData.consumables.items or {}
        local buckets = {}
        local total = 0
        for _, entry in pairs(items) do
            local b = entry.bucket or "other"
            buckets[b] = (buckets[b] or 0) + (entry.count or 0)
            total = total + (entry.count or 0)
        end
        print("|cff00ff00=== Consommables (" .. total .. " unités) ===|r")
        if next(buckets) == nil then
            print("|cffff8000Aucun consommable détecté.|r Ouvrez vos sacs / la banque puis relancez la commande.")
        else
            for bucket, count in pairs(buckets) do
                print(string.format("  %s: %d", bucket, count))
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
    -- NOUVELLES COMMANDES v1.3.2 - Gestion des personnages et comptes
    elseif command == "settype" then
        -- /auberdine settype main|alt|bank|mule [character]
        local characterType = args[2]
        local charName = args[3]
        
        if not characterType then
            print("|cffff0000AuberdineExporter:|r Usage: /auberdine settype <main|alt|bank|mule> [character]")
            print("Si aucun personnage n'est spécifié, s'applique au personnage actuel.")
            return
        end
        
        local charKey = charName and (charName .. "-" .. GetRealmName()) or GetCurrentCharacterKey()
        SetCharacterType(charKey, characterType)
        
    elseif command == "linkto" then
        -- /auberdine linkto <mainCharacter>
        local mainCharName = args[2]
        
        if not mainCharName then
            print("|cffff0000AuberdineExporter:|r Usage: /auberdine linkto <mainCharacter>")
            print("Lie le personnage actuel au personnage principal spécifié.")
            return
        end
        
        local charKey = GetCurrentCharacterKey()
        local mainCharKey = mainCharName .. "-" .. GetRealmName()
        LinkCharacterToMain(charKey, mainCharKey)
        
    elseif command == "account" then
        -- /auberdine account <groupName>
        local groupName = args[2]
        
        if not groupName then
            print("|cffff0000AuberdineExporter:|r Usage: /auberdine account <groupName>")
            print("Définit le groupe de compte pour le personnage actuel.")
            return
        end
        
        local charKey = GetCurrentCharacterKey()
        SetAccountGroup(charKey, groupName)
        
    elseif command == "export" then
        -- /auberdine export enable|disable [character]
        local action = args[2]
        local charName = args[3]
        
        if not action then
            print("|cffff0000AuberdineExporter:|r Usage: /auberdine export <enable|disable> [character]")
            print("Active ou désactive l'export pour un personnage.")
            return
        end
        
        local enabled = string.lower(action) == "enable"
        local charKey = charName and (charName .. "-" .. GetRealmName()) or GetCurrentCharacterKey()
        ToggleCharacterExport(charKey, enabled)
        
    elseif command == "config" then
        -- /auberdine config - Affiche la configuration complète
        ListCharacterConfiguration()
        
    elseif command == "accountkey" then
        -- /auberdine accountkey [nouvelle_clé] - Affiche ou définit la clé d'identification unique du compte
        local newKey = args[2]
        
        if newKey then
            -- Définir une nouvelle accountKey
            local success, message = SetAccountKey(string.upper(newKey))
            if not success then
                print("|cffff0000AuberdineExporter:|r " .. message)
                print("Exemple de format valide: AB-1234-ABCD")
            end
        else
            -- Afficher l'accountKey actuelle
            local accountKey = GetOrCreateAccountKey()
            print("|cff00ff00AuberdineExporter:|r Clé d'identification unique: |cffffffff" .. accountKey .. "|r")
            print("Cette clé permet de lier vos comptes WoW dans le système de groupes.")
            print("Partagez cette clé avec vos autres comptes pour les regrouper.")
            print("|cffff8000Usage:|r /auberdine accountkey <nouvelle_clé> pour changer la clé")
        end
        
    elseif command == "generatekey" then
        -- /auberdine generatekey - Génère une nouvelle accountKey aléatoire
        local newKey = GenerateUniqueAccountKey()
        print("|cff00ff00AuberdineExporter:|r Nouvelle clé générée: |cffffffff" .. newKey .. "|r")
        print("Utilisez '/auberdine accountkey " .. newKey .. "' pour l'appliquer.")
        print("Ou copiez cette clé pour la partager avec vos autres comptes.")
        print("|cffff8000Exemple d'usage multi-comptes:|r")
        print("  1. Sur le compte principal: /auberdine generatekey")
        print("  2. Copiez la clé générée")  
        print("  3. Sur les autres comptes: /auberdine accountkey " .. newKey)
        
    elseif command == "testkey" then
        -- /auberdine testkey <clé> - Teste la validation d'une clé
        local testKey = args[2]
        if not testKey then
            print("|cffff0000AuberdineExporter:|r Usage: /auberdine testkey <clé_à_tester>")
            print("Exemple: /auberdine testkey AB-9KR8-2HYC")
            return
        end
        
        print("|cff00ff00AuberdineExporter:|r Test de validation pour: " .. testKey)
        local isValid = IsValidAccountKey(testKey)
        if isValid then
            print("|cff00ff00Résultat:|r Clé VALIDE ✓")
        else
            print("|cffff0000Résultat:|r Clé INVALIDE ✗")
        end
        
    elseif command == "groupname" then
        -- /auberdine groupname [newName] - Affiche ou change le nom du groupe
        local newName = args[2]
        
        if newName then
            -- Changer le nom du groupe pour tous les personnages du compte
            if not AuberdineExporterDB.characterSettings then
                AuberdineExporterDB.characterSettings = {}
            end
            
            -- S'assurer qu'il y a toujours un groupe unique généré
            if not AuberdineExporterDB.accountGroup then
                AuberdineExporterDB.accountGroup = GenerateDefaultGroupName()
            end
            local oldGroup = AuberdineExporterDB.accountGroup
            AuberdineExporterDB.accountGroup = newName
            
            -- Mettre à jour tous les personnages qui utilisent l'ancien groupe
            for charKey, settings in pairs(AuberdineExporterDB.characterSettings) do
                if settings.accountGroup == oldGroup then
                    settings.accountGroup = newName
                    settings.lastModified = time()
                end
            end
            
            print("|cff00ff00AuberdineExporter:|r Nom de groupe changé: |cffffffff" .. newName .. "|r")
        else
            -- Afficher le nom du groupe actuel - s'assurer qu'il y en a un
            if not AuberdineExporterDB.accountGroup then
                AuberdineExporterDB.accountGroup = GenerateDefaultGroupName()
            end
            local currentGroup = AuberdineExporterDB.accountGroup
            print("|cff00ff00AuberdineExporter:|r Nom de groupe actuel: |cffffffff" .. currentGroup .. "|r")
            print("Utilisez '/auberdine groupname <nouveau_nom>' pour le changer.")
        end
        
    elseif command == "help" then
        print("|cff00ff00AuberdineExporter Commands:|r")
        print("|cffff8000=== COMMANDES PRINCIPALES ===|r")
        print("  /auberdine - Ouvrir l'interface principale")
        print("  /auberdine ui - Ouvrir l'interface principale")
        print("  /auberdine scan - Scanner métiers + inventaire (équipement, sacs, banque)")
        print("  /auberdine inventory - Scanner uniquement l'inventaire (alias: /auberdine inv)")
        print("  /auberdine consumables - Afficher les consommables agrégés (alias: consu)")
        print("  /auberdine localsnapshot - Forcer un snapshot local complet (sacs+banque, non exporté)")
        print("  /auberdine recipes - Afficher toutes les recettes avec IDs")
        print("  /auberdine stats - Afficher les statistiques dans le chat")
        print("")
        print("|cffff8000=== GESTION DES PERSONNAGES (v1.3.2) ===|r")
        print("  /auberdine characters - Lister tous les personnages et leur config")
        print("  /auberdine config - Afficher la configuration des personnages")
        print("  /auberdine settype <main|alt|bank|mule> - Définir le type du personnage")
        print("  /auberdine linkto <mainCharacter> - Lier au personnage principal")
        print("  /auberdine account <groupName> - Définir le groupe de compte")
        print("  /auberdine export <enable|disable> - Activer/désactiver l'export")
        print("")
        print("|cffff8000=== GESTION DES GROUPES MULTI-COMPTES ===|r")
        print("  /auberdine accountkey [nouvelle_clé] - Afficher ou définir votre clé d'identification unique")
        print("  /auberdine generatekey - Générer une nouvelle clé aléatoire")
        print("  /auberdine groupname [nom] - Afficher/changer le nom de votre groupe")
        print("    Exemples: DragonRouge-42, CarnAlliance, MesPersonnages")
        print("")
        print("|cffff8000=== COMMANDES SYSTÈME ===|r")
        print("  /auberdine debug - Toggle verbose debug messages")
        print("  /auberdine debugdb - Debug complet de la base de données")
        print("  /auberdine skills - Show all skill lines (debug)")
        print("  /auberdine autoscan - Toggle auto-scan on/off")
        print("  /auberdine minimap - Toggle minimap button")
        print("  /auberdine reset - Reset all data")
        print("  /auberdine clear - Clear memory data (keep current character)")
        print("  /auberdine size - Show data size information")
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

SLASH_AUBERDINE1 = "/auberdine"
SLASH_AUBERDINE2 = "/ae"
SLASH_AUBERDINE3 = "/aubex"
SlashCmdList["AUBERDINE"] = HandleSlashCommand

-- print("=== Commandes slash enregistrées ===")
-- print("=== AuberdineExporter chargé complètement ===")
-- print("=== Utilisez /auberdinetest pour tester, /auberdine pour les commandes principales ===")
