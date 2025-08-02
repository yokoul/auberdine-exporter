// Test simple du dataChecksum uniquement
const fs = require('fs');
const { md5_sumhexa } = require('./verifyExport.js');

// Charger le JSON d'export
const exportData = JSON.parse(fs.readFileSync('./test-export.json', 'utf8'));

console.log('=== Test du dataChecksum ===');
console.log('dataChecksum dans le JSON:', exportData.validation.dataChecksum);

// Copier les données et retirer signature + signatureInfo
const dataCopy = JSON.parse(JSON.stringify(exportData));
delete dataCopy.signature;
delete dataCopy.signatureInfo;

// Convertir en JSON (essayer différentes méthodes)
const jsonCompact = JSON.stringify(dataCopy);
const jsonPretty = JSON.stringify(dataCopy, null, 2);

console.log('\nTest JSON compact:');
console.log('  Length:', jsonCompact.length);
console.log('  MD5:', md5_sumhexa(jsonCompact));

console.log('\nTest JSON pretty:');
console.log('  Length:', jsonPretty.length);
console.log('  MD5:', md5_sumhexa(jsonPretty));

// Essayer avec la méthode canonique du serveur
const { createCanonicalJSON } = require('./verifyExport.js');
