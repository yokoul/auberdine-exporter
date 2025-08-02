// Script pour diagnostiquer précisément la différence avec l'addon
const fs = require('fs');

// Hash functions exactes
function simpleHash(str) {
    let hash = 5381;
    for (let i = 0; i < str.length; i++) {
        const c = str.charCodeAt(i);
        hash = ((hash * 33) + c) % 2147483647;
    }
    return hash.toString(16);
}

function md5_sumhexa(s) {
    const pass1 = simpleHash(s);
    const pass2 = simpleHash(s + pass1);
    const pass3 = simpleHash(pass2 + s);
    return (pass2 + pass3).substring(0, 32);
}

// Lire les données d'origine intactes (pas modifiées)
// IMPORTANT: Utiliser un fichier d'export qui n'a PAS été modifié
const originalData = {
    "characters": {
        "Doomia-Auberdine": {
            "info": {
                "class": "Démoniste",
                "guid": "Player-5241-011E2333",
                "lastUpdate": 1753631172,
                "level": 35,
                "locale": "frFR",
                "name": "Doomia",
                "race": "Gnome",
                "realm": "Auberdine"
            }
        }
    },
    "metadata": {
        "addon": "AuberdineExporter",
        "challenge": "auberdine-2025-recipe-export",
        "clientKey": "auberdine-v1",
        "nonce": "1753631174_8483_011E2333",
        "timestamp": 1753631174
    },
    "summary": {
        "totalCharacters": 2,
        "totalProfessions": 6,
        "totalRecipes": 116
    },
    "validation": {
        "exportComplete": true
    }
};

// Signature originale du vrai fichier
const ORIGINAL_SIGNATURE = "79f77d887e40be95";
const CLIENT_KEY = 'auberdine-v1';
const ADDON_CHALLENGE = 'auberdine-2025-recipe-export';
const nonce = "1753631174_8483_011E2333";
const timestamp = 1753631174;

console.log('=== TEST AVEC DONNÉES SIMPLIFIÉES ===');

// Essayer différentes méthodes de génération JSON
const methods = [
    { name: 'JSON.stringify (compact)', fn: () => JSON.stringify(originalData) },
    { name: 'JSON.stringify (pretty)', fn: () => JSON.stringify(originalData, null, 2) },
    { name: 'JSON.stringify (sorted)', fn: () => JSON.stringify(originalData, Object.keys(originalData).sort()) }
];

for (const method of methods) {
    const json = method.fn();
    const signatureBase = json + CLIENT_KEY + nonce + ADDON_CHALLENGE;
    const signature1 = md5_sumhexa(signatureBase);
    const signature2 = md5_sumhexa(signature1 + timestamp + CLIENT_KEY);
    const finalSignature = md5_sumhexa(signature2 + nonce);
    
    console.log(`\\n${method.name}:`);
    console.log(`  JSON length: ${json.length}`);
    console.log(`  Final signature: ${finalSignature}`);
    console.log(`  Match: ${finalSignature === ORIGINAL_SIGNATURE ? '✅' : '❌'}`);
}

// Tester avec l'ordre exact des clés tel qu'il apparaît dans le fichier original
console.log('\\n=== TESTING EXACT KEY ORDER ===');
const exactOrder = {
    "characters": originalData.characters,
    "metadata": originalData.metadata, 
    "summary": originalData.summary,
    "validation": originalData.validation
};

const exactJSON = JSON.stringify(exactOrder, null, 2);
const exactSigBase = exactJSON + CLIENT_KEY + nonce + ADDON_CHALLENGE;
const exactSig1 = md5_sumhexa(exactSigBase);
const exactSig2 = md5_sumhexa(exactSig1 + timestamp + CLIENT_KEY);
const exactFinalSig = md5_sumhexa(exactSig2 + nonce);

console.log('Exact order signature:', exactFinalSig);
console.log('Match:', exactFinalSig === ORIGINAL_SIGNATURE ? '✅' : '❌');
