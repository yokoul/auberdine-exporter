// Test de l'approche Base64 pour résoudre le problème de formatage JSON
const fs = require('fs');
const { md5_sumhexa } = require('./verifyExport.js');

// Charger le JSON d'export actuel
const exportData = JSON.parse(fs.readFileSync('./test-export.json', 'utf8'));

console.log('=== Test de l\'approche Base64 ===');

// 1. Extraire les données (sans signature)
const dataCopy = JSON.parse(JSON.stringify(exportData));
delete dataCopy.signature;
delete dataCopy.signatureInfo;

// 2. Convertir en JSON (peu importe le format, on va encoder en Base64)
const jsonString = JSON.stringify(dataCopy);
console.log('JSON size:', jsonString.length, 'bytes');

// 3. Encoder en Base64
const base64Data = Buffer.from(jsonString).toString('base64');
console.log('Base64 size:', base64Data.length, 'bytes');
console.log('Base64 (first 100 chars):', base64Data.substring(0, 100) + '...');

// 4. Calculer le checksum sur le Base64
const checksumOnBase64 = md5_sumhexa(base64Data);
console.log('Checksum sur Base64:', checksumOnBase64);

// 5. Test de décodage côté serveur
const decodedJSON = Buffer.from(base64Data, 'base64').toString('utf8');
const decodedData = JSON.parse(decodedJSON);
console.log('Décodage réussi:', decodedData.metadata.addon === 'AuberdineExporter');

// 6. Re-calculer le checksum côté serveur
const serverChecksum = md5_sumhexa(base64Data);
console.log('Server checksum:', serverChecksum);
console.log('Checksums match:', checksumOnBase64 === serverChecksum);

console.log('\n=== Format d\'export proposé ===');
const newExportFormat = {
    metadata: exportData.metadata,
    dataBase64: base64Data,
    signature: "XXXX", // Signature calculée sur dataBase64 + metadata
    signatureInfo: {
        algorithm: "multi-pass-md5-base64",
        timestamp: exportData.metadata.timestamp,
        nonce: exportData.metadata.nonce,
        hasChallenge: true
    },
    validation: {
        dataChecksum: checksumOnBase64, // Checksum sur Base64
        exportComplete: true,
        encoding: "base64"
    }
};

console.log('New format size:', JSON.stringify(newExportFormat).length, 'bytes');
console.log('Compression ratio:', Math.round((base64Data.length / jsonString.length) * 100) + '%');
