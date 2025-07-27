// Vérificateur Base64 pour AuberdineExporter - Version sécurisée
// Compatible avec le nouveau format Base64 qui évite les problèmes de formatage JSON
const fs = require('fs');
const crypto = require('crypto');

// Charger la clé privée
const secret = JSON.parse(fs.readFileSync(__dirname + '/secret.json', 'utf8'));
const PRIVATE_KEY = secret.privateKey;
const CLIENT_KEY = "auberdine-v1";
const ADDON_CHALLENGE = "auberdine-2025-recipe-export";

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
    const pass1 = simpleHash(s);
    const pass2 = simpleHash(s + pass1);
    const pass3 = simpleHash(pass2 + s);
    
    return (pass2 + pass3).substring(0, 32);
}

// Fonction pour vérifier la signature Base64 (nouveau format)
function verifyBase64Signature(exportData) {
    try {
        // Vérifier que c'est le bon format
        if (!exportData.dataBase64 || !exportData.signatureInfo || !exportData.signature) {
            return { valid: false, error: "Format Base64 invalide - champs manquants" };
        }
        
        if (exportData.signatureInfo.algorithm !== "multi-pass-md5-base64") {
            return { valid: false, error: "Algorithme non supporté: " + exportData.signatureInfo.algorithm };
        }
        
        // 1. Vérifier le dataChecksum
        const expectedDataChecksum = md5_sumhexa(exportData.dataBase64);
        const receivedDataChecksum = exportData.validation.dataChecksum;
        
        if (expectedDataChecksum !== receivedDataChecksum) {
            return { 
                valid: false, 
                error: "DataChecksum invalide",
                expected: expectedDataChecksum,
                received: receivedDataChecksum
            };
        }
        
        // 2. Décoder le Base64 pour récupérer les données
        let decodedData;
        try {
            const decodedJSON = Buffer.from(exportData.dataBase64, 'base64').toString('utf8');
            decodedData = JSON.parse(decodedJSON);
        } catch (decodeError) {
            return { valid: false, error: "Erreur de décodage Base64: " + decodeError.message };
        }
        
        // 3. Vérifier la signature (même logique que l'addon)
        const metadata = exportData.metadata;
        const nonce = exportData.signatureInfo.nonce;
        const timestamp = exportData.signatureInfo.timestamp;
        
        // Signature base sur Base64 + metadata (EXACTE logique addon)
        const signatureBase = exportData.dataBase64 + CLIENT_KEY + nonce + ADDON_CHALLENGE;
        
        // Signature multi-passes
        const signature1 = md5_sumhexa(signatureBase);
        const signature2 = md5_sumhexa(signature1 + timestamp + CLIENT_KEY);
        const expectedSignature = md5_sumhexa(signature2 + nonce);
        
        const isValid = expectedSignature === exportData.signature;
        
        return {
            valid: isValid,
            expected: expectedSignature,
            received: exportData.signature,
            metadata: {
                timestamp: timestamp,
                nonce: nonce,
                hasChallenge: exportData.signatureInfo.hasChallenge,
                algorithm: exportData.signatureInfo.algorithm,
                challengeValid: metadata.challenge === ADDON_CHALLENGE,
                dataSize: exportData.dataBase64.length,
                decodedSize: decodedData ? JSON.stringify(decodedData).length : 0
            }
        };
        
    } catch (error) {
        return { valid: false, error: "Erreur lors de la vérification: " + error.message };
    }
}

// Fonction principale de vérification avec auto-détection de format
function verifySignature(exportData) {
    if (typeof exportData === 'string') {
        exportData = JSON.parse(exportData);
    }
    
    // Détecter le nouveau format Base64
    if (exportData.dataBase64 && exportData.signatureInfo && exportData.signatureInfo.algorithm === "multi-pass-md5-base64") {
        console.log("Détection: Format Base64 sécurisé");
        return verifyBase64Signature(exportData);
    } 
    // Format legacy (original)
    else if (exportData.signatureInfo && exportData.signatureInfo.algorithm === "multi-pass-md5") {
        console.log("Détection: Format legacy multi-passes");
        return { valid: false, error: "Format legacy non supporté - utilisez le nouveau format Base64" };
    } 
    else {
        console.log("Détection: Format inconnu");
        return { valid: false, error: "Format de signature non reconnu" };
    }
}

// Fonction pour extraire les données depuis le format Base64
function extractDataFromBase64Export(exportData) {
    try {
        if (!exportData.dataBase64) {
            throw new Error("Pas de données Base64 dans l'export");
        }
        
        const decodedJSON = Buffer.from(exportData.dataBase64, 'base64').toString('utf8');
        return JSON.parse(decodedJSON);
    } catch (error) {
        throw new Error("Erreur d'extraction des données: " + error.message);
    }
}

// CLI
if (require.main === module) {
    const inputFile = process.argv[2];
    if (!inputFile) {
        console.error('Usage: node verifyBase64Export.js <export.json>');
        console.error('');
        console.error('Vérifie la signature d\'un export AuberdineExporter (format Base64)');
        process.exit(1);
    }
    
    console.log('AuberdineExporter - Vérificateur Base64');
    console.log('======================================');
    
    try {
        const exportJson = fs.readFileSync(inputFile, 'utf8');
        const data = JSON.parse(exportJson);
        
        console.log('Fichier chargé:', inputFile);
        console.log('Taille:', Math.round(exportJson.length / 1024 * 100) / 100, 'KB');
        
        if (data.metadata) {
            console.log('Addon:', data.metadata.addon);
            console.log('Version:', data.metadata.version);
            console.log('Timestamp:', new Date(data.metadata.timestamp * 1000).toISOString());
        }
        
        if (data.dataBase64) {
            console.log('Format: Base64');
            console.log('Données encodées:', Math.round(data.dataBase64.length / 1024 * 100) / 100, 'KB');
            
            // Extraire et afficher un aperçu des données
            try {
                const extractedData = extractDataFromBase64Export(data);
                if (extractedData.summary) {
                    console.log('Personnages:', extractedData.summary.totalCharacters || 'N/A');
                    console.log('Recettes:', extractedData.summary.totalRecipes || 'N/A');
                }
            } catch (e) {
                console.log('Impossible d\'extraire les données:', e.message);
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
                console.log('Taille données:', result.metadata.dataSize, 'bytes (Base64)');
                console.log('Taille décodée:', result.metadata.decodedSize, 'bytes (JSON)');
            }
        } else {
            console.log('\x1b[31m✗ SIGNATURE INVALIDE\x1b[0m');
            if (result.error) {
                console.log('Erreur:', result.error);
            }
            if (result.expected && result.received) {
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
    verifyBase64Signature,
    extractDataFromBase64Export,
    md5_sumhexa,
    CLIENT_KEY 
};
