-- Test de validation de serveur pour AuberdineExporter
-- Ce script peut être utilisé pour tester la validation du serveur

print("=== Test de validation du serveur AuberdineExporter ===")

-- Simuler différents noms de serveur
local function TestRealm(realmName)
    -- Mock GetRealmName() pour le test
    _G.GetRealmName = function() return realmName end
    
    -- Test de notre fonction de validation
    local isValid = AuberdineExporter and AuberdineExporter.IsOnAuberdine and AuberdineExporter:IsOnAuberdine()
    
    print("Serveur: " .. realmName .. " -> Valide: " .. (isValid and "OUI" or "NON"))
    return isValid
end

-- Tests avec différents formats de nom
print("Tests de validation:")
TestRealm("Auberdine")     -- Devrait être valide
TestRealm("auberdine")     -- Devrait être valide  
TestRealm("AUBERDINE")     -- Devrait être valide
TestRealm("Sulfuron")      -- Devrait être invalide
TestRealm("Mirage Raceway") -- Devrait être invalide
TestRealm("auberdine ")    -- Devrait être invalide (espace)

print("=== Fin des tests ===")