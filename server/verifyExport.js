// Vérification de l'export AuberdineExporter côté serveur (Node.js)
// Compatible avec les signatures multi-passes sécurisées
// Placez votre clé privée dans secret.json (non versionné)
const fs = require('fs');
const crypto = require('crypto');

// Charger la clé privée
const secret = JSON.parse(fs.readFileSync(__dirname + '/secret.json', 'utf8'));
const PRIVATE_KEY = secret.privateKey;
const CLIENT_KEY = "auberdine-v1"; // Doit correspondre à AuberdineExporterClientKey
const ADDON_CHALLENGE = "auberdine-2025-recipe-export"; // Challenge hardcodé de l'addon

// Fonction hash simplifiée compatible avec l'addon
function simpleHash(str) {
    let hash = 5381;
    for (let i = 0; i < str.length; i++) {
        const c = str.charCodeAt(i);
        hash = ((hash * 33) + c) % 2147483647;
    }
    return hash.toString(16);
}

// Fonction MD5 compatible avec l'addon (multi-passes)
function md5_sumhexa(s) {
    // Reproduire exactement la logique de l'addon
    const pass1 = simpleHash(s);
    const pass2 = simpleHash(s + pass1);
    const pass3 = simpleHash(pass2 + s);
    
    // Retourner un hash de 32 caractères comme MD5
    return (pass2 + pass3).substring(0, 32);
}

// Fonction pour vérifier la signature multi-passes (format complet)
function verifyCompleteSignature(exportData) {
    try {
        const data = JSON.parse(JSON.stringify(exportData)); // Deep copy
        
        // Extraire les métadonnées de signature
        const signature = data.signature;
        const signatureInfo = data.signatureInfo;
        
        if (!signature || !signatureInfo) {
            return { valid: false, error: "Signature ou signatureInfo manquant" };
        }
        
        // Vérifier l'algorithme
        if (signatureInfo.algorithm !== "multi-pass-md5") {
            return { valid: false, error: "Algorithme de signature non supporté: " + signatureInfo.algorithm };
        }
        
        // Retirer les champs de signature pour recalculer
        delete data.signature;
        delete data.signatureInfo;
        
        // Reconstruire le JSON dans l'ordre canonique (comme l'addon)
        const jsonWithoutSignature = createCanonicalJSON(data);
        
        // Recalculer la signature avec la même méthode que l'addon
        const metadata = data.metadata;
        const nonce = signatureInfo.nonce;
        const timestamp = signatureInfo.timestamp;
        const hasChallenge = signatureInfo.hasChallenge;
        
        // Base de signature (EXACTE logique addon)
        // Addon: signatureBase = jsonWithoutSignature .. exportMetadata.clientKey .. exportMetadata.nonce .. AuberdineExporterChallenge
        const signatureBase = jsonWithoutSignature + CLIENT_KEY + nonce + ADDON_CHALLENGE;
        
        // Debug: afficher les composants de la signature
        console.log('DEBUG - Components:');
        console.log('  JSON length:', jsonWithoutSignature.length);
        console.log('  CLIENT_KEY:', CLIENT_KEY);
        console.log('  nonce:', nonce);
        console.log('  ADDON_CHALLENGE:', ADDON_CHALLENGE);
        console.log('  timestamp:', timestamp);
        
        // Signature à plusieurs passes (reproduire EXACTEMENT la logique addon)
        // Addon: signature1 = md5_sumhexa(signatureBase)
        const signature1 = md5_sumhexa(signatureBase);
        console.log('  signature1:', signature1);
        // Addon: signature2 = md5_sumhexa(signature1 .. exportMetadata.timestamp .. exportMetadata.clientKey)
        const signature2 = md5_sumhexa(signature1 + timestamp + CLIENT_KEY);
        console.log('  signature2:', signature2);
        // Addon: finalSignature = md5_sumhexa(signature2 .. nonce)
        const expectedSignature = md5_sumhexa(signature2 + nonce);
        console.log('  expectedSignature:', expectedSignature);
        
        return {
            valid: expectedSignature === signature,
            expected: expectedSignature,
            received: signature,
            metadata: {
                timestamp: timestamp,
                nonce: nonce,
                hasChallenge: hasChallenge,
                algorithm: signatureInfo.algorithm,
                challengeValid: metadata.challenge === ADDON_CHALLENGE
            }
        };
        
    } catch (error) {
        return { valid: false, error: "Erreur lors de la vérification: " + error.message };
    }
}

// Fonction pour créer un JSON canonique EXACTEMENT comme l'addon
function createCanonicalJSON(obj, indent = 0) {
    const spacing = "  ".repeat(indent);
    let result = "{\n";
    
    // Trier les clés EXACTEMENT comme l'addon : tostring(a) < tostring(b)
    const keys = Object.keys(obj).sort((a, b) => String(a) < String(b) ? -1 : String(a) > String(b) ? 1 : 0);
    
    for (let i = 0; i < keys.length; i++) {
        const k = keys[i];
        const v = obj[k];
        result += spacing + "  \"" + escapeJSON(k) + "\": ";
        
        if (typeof v === "object" && v !== null) {
            // Vérifier si c'est un tableau ou un objet
            if (Array.isArray(v)) {
                result += "[\n";
                for (let j = 0; j < v.length; j++) {
                    result += spacing + "    ";
                    if (typeof v[j] === "object" && v[j] !== null) {
                        result += createCanonicalJSON(v[j], indent + 2);
                    } else if (typeof v[j] === "string") {
                        result += '"' + escapeJSON(v[j]) + '"';
                    } else {
                        result += String(v[j]);
                    }
                    if (j < v.length - 1) result += ",";
                    result += "\n";
                }
                result += spacing + "  ]";
            } else {
                // Objet vide ou objet avec propriétés
                const isEmpty = Object.keys(v).length === 0;
                if (isEmpty) {
                    result += "{}";
                } else {
                    result += createCanonicalJSON(v, indent + 1);
                }
            }
        } else if (typeof v === "string") {
            result += '"' + escapeJSON(v) + '"';
        } else if (typeof v === "boolean") {
            result += v ? "true" : "false";
        } else {
            result += String(v);
        }
        
        if (i < keys.length - 1) result += ",";
        result += "\n";
    }
    
    result += spacing + "}";
    return result;
}

// Fonction d'échappement JSON compatible
function escapeJSON(s) {
    return s.replace(/\\/g, "\\\\")
            .replace(/"/g, '\\"')
            .replace(/\n/g, "\\n")
            .replace(/\r/g, "\\r")
            .replace(/\t/g, "\\t");
}

// Fonction pour vérifier la signature simple (rétrocompatibilité)
function verifySimpleSignature(exportJson, privateKey) {
    try {
        const data = JSON.parse(exportJson);
        const signature = data.signature;
        delete data.signature;
        
        // Re-stringifie avec les mêmes règles que l'addon simple
        const jsonNoSig = JSON.stringify(data);
        const expectedSig = md5_sumhexa(jsonNoSig + CLIENT_KEY);
        
        return {
            valid: expectedSig === signature,
            expected: expectedSig,
            received: signature,
            type: "simple"
        };
    } catch (error) {
        return { valid: false, error: "Erreur signature simple: " + error.message };
    }
}

// Fonction principale de vérification (auto-détecte le format)
function verifySignature(exportData) {
    // Auto-détection du format
    if (typeof exportData === 'string') {
        exportData = JSON.parse(exportData);
    }
    
    // Vérifier si c'est le nouveau format avec signatureInfo
    if (exportData.signatureInfo && exportData.signatureInfo.algorithm === "multi-pass-md5") {
        console.log("Détection: Format signature multi-passes");
        return verifyCompleteSignature(exportData);
    } else {
        console.log("Détection: Format signature simple (legacy)");
        return verifySimpleSignature(JSON.stringify(exportData), PRIVATE_KEY);
    }
}

// Exemple d'utilisation
if (require.main === module) {
    const inputFile = process.argv[2];
    if (!inputFile) {
        console.error('Usage: node verifyExport.js <export.json>');
        console.error('');
        console.error('Vérifie la signature d\'un export AuberdineExporter');
        console.error('Supporte les formats simple et multi-passes');
        process.exit(1);
    }
    
    console.log('AuberdineExporter - Vérificateur de signature serveur');
    console.log('=====================================================');
    
    try {
        const exportJson = fs.readFileSync(inputFile, 'utf8');
        const data = JSON.parse(exportJson);
        
        console.log('Fichier chargé:', inputFile);
        console.log('Taille:', Math.round(exportJson.length / 1024 * 100) / 100, 'KB');
        
        if (data.metadata) {
            console.log('Addon:', data.metadata.addon);
            console.log('Version:', data.metadata.version);
            console.log('Timestamp:', new Date(data.metadata.timestamp * 1000).toISOString());
            if (data.character) {
                console.log('Personnage:', data.character.name + '-' + data.character.realm);
                console.log('Niveau:', data.character.level, data.character.class);
            }
        }
        
        console.log('');
        console.log('Vérification de la signature...');
        
        const result = verifySignature(data);
        
        if (result.valid) {
            console.log('\x1b[32m✓ SIGNATURE VALIDE\x1b[0m');
            if (result.metadata) {
                console.log('Algorithme:', result.metadata.algorithm);
                console.log('Timestamp:', new Date(result.metadata.timestamp * 1000).toISOString());
                console.log('Challenge:', result.metadata.hasChallenge ? 'présent' : 'absent');
            }
        } else {
            console.log('\x1b[31m✗ SIGNATURE INVALIDE\x1b[0m');
            if (result.error) {
                console.log('Erreur:', result.error);
            } else {
                console.log('Signature attendue:', result.expected);
                console.log('Signature reçue   :', result.received);
            }
        }
        
    } catch (error) {
        console.error('\x1b[31mErreur lors du traitement du fichier:\x1b[0m', error.message);
        process.exit(1);
    }
}

module.exports = { 
    verifySignature, 
    verifyCompleteSignature, 
    verifySimpleSignature, 
    md5_sumhexa,
    CLIENT_KEY 
};
