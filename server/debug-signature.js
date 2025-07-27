// Script de debug pour reproduire exactement la signature de l'addon
const fs = require('fs');

// Reproduire exactement la logique addon
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

// Fonction d'échappement JSON exactement comme l'addon
function escapeJSON(s) {
    return s.replace(/\\/g, "\\\\")
            .replace(/"/g, '\\"')
            .replace(/\n/g, "\\n")
            .replace(/\r/g, "\\r")
            .replace(/\t/g, "\\t");
}

// Reproduire EXACTEMENT la fonction tableToJSON de l'addon
function tableToJSON(t, indent = 0, excludeSignature = false) {
    const spacing = "  ".repeat(indent);
    let result = "{\n";
    let pairs_count = 0;
    
    // Ordonner les clés EXACTEMENT comme l'addon
    const keys = [];
    for (const k in t) {
        if (!excludeSignature || (k !== "signature" && k !== "signatureInfo")) {
            keys.push(k);
        }
    }
    keys.sort((a, b) => String(a) < String(b) ? -1 : String(a) > String(b) ? 1 : 0);
    
    for (let i = 0; i < keys.length; i++) {
        const k = keys[i];
        const v = t[k];
        pairs_count++;
        result += spacing + "  \"" + escapeJSON(String(k)) + "\": ";
        
        if (typeof v === "object" && v !== null) {
            // Vérifier si c'est un tableau ou un objet
            let isArray = Array.isArray(v);
            
            if (isArray) {
                result += "[\n";
                for (let j = 0; j < v.length; j++) {
                    result += spacing + "    ";
                    if (typeof v[j] === "object" && v[j] !== null) {
                        result += tableToJSON(v[j], indent + 2, excludeSignature);
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
                // Table vide ou objet
                const isEmpty = Object.keys(v).length === 0;
                if (isEmpty) {
                    result += "{}";
                } else {
                    result += tableToJSON(v, indent + 1, excludeSignature);
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

// Test avec les vraies données
const data = JSON.parse(fs.readFileSync('test-export.json', 'utf8'));

// Extraire signature originale
const originalSignature = data.signature;

// Paramètres
const CLIENT_KEY = 'auberdine-v1';
const ADDON_CHALLENGE = 'auberdine-2025-recipe-export';
const nonce = data.signatureInfo.nonce;
const timestamp = data.metadata.timestamp;

console.log('=== DEBUG SIGNATURE ===');
console.log('Signature originale:', originalSignature);
console.log('CLIENT_KEY:', CLIENT_KEY);
console.log('ADDON_CHALLENGE:', ADDON_CHALLENGE);
console.log('nonce:', nonce);
console.log('timestamp:', timestamp);
console.log();

// Générer JSON exactement comme l'addon (excludeSignature = true)
const jsonWithoutSignature = tableToJSON(data, 0, true);

console.log('=== JSON SANS SIGNATURE (premiers 200 chars) ===');
console.log(jsonWithoutSignature.substring(0, 200) + '...');
console.log('Longueur totale:', jsonWithoutSignature.length);
console.log();

// Calculer signature exactement comme l'addon
const signatureBase = jsonWithoutSignature + CLIENT_KEY + nonce + ADDON_CHALLENGE;
const signature1 = md5_sumhexa(signatureBase);
const signature2 = md5_sumhexa(signature1 + timestamp + CLIENT_KEY);
const finalSignature = md5_sumhexa(signature2 + nonce);

console.log('=== CALCUL SIGNATURE ===');
console.log('signatureBase length:', signatureBase.length);
console.log('signature1:', signature1);
console.log('signature2:', signature2);
console.log('finalSignature:', finalSignature);
console.log();

console.log('=== RESULTAT ===');
console.log('Signature calculée:', finalSignature);
console.log('Signature originale:', originalSignature);
console.log('MATCH:', finalSignature === originalSignature ? '✅ OUI' : '❌ NON');

if (finalSignature !== originalSignature) {
    console.log();
    console.log('=== ANALYSE DIFFERENCE ===');
    
    // Essayer avec JSON.stringify simple
    const dataNoSig = {...data};
    delete dataNoSig.signature;
    delete dataNoSig.signatureInfo;
    const simpleJSON = JSON.stringify(dataNoSig);
    const simpleSigBase = simpleJSON + CLIENT_KEY + nonce + ADDON_CHALLENGE;
    const simpleSig1 = md5_sumhexa(simpleSigBase);
    const simpleSig2 = md5_sumhexa(simpleSig1 + timestamp + CLIENT_KEY);
    const simpleFinSig = md5_sumhexa(simpleSig2 + nonce);
    
    console.log('Avec JSON.stringify simple:', simpleFinSig);
    console.log('Match simple:', simpleFinSig === originalSignature ? '✅ OUI' : '❌ NON');
}
