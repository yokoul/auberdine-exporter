#!/usr/bin/env node

/**
 * Script de test pour AuberdineExporter Base64
 * Usage: node test-base64-system.js [export.json]
 */

const fs = require('fs');
const { verifySignature, extractDataFromBase64Export, md5_sumhexa } = require('./verifyBase64Export');

function runTests() {
    console.log('🧪 Tests du système Base64 AuberdineExporter');
    console.log('='.repeat(50));

    // Test 1: Validation d'un export valide
    console.log('\n📝 Test 1: Validation export valide');
    if (fs.existsSync('./test-export-b64.json')) {
        try {
            const validExport = JSON.parse(fs.readFileSync('./test-export-b64.json', 'utf8'));
            const result = verifySignature(validExport);
            
            if (result.valid) {
                console.log('✅ Export valide détecté correctement');
                console.log(`   Algorithm: ${result.metadata.algorithm}`);
                console.log(`   Données: ${result.metadata.dataSize} bytes (Base64)`);
                console.log(`   Décodé: ${result.metadata.decodedSize} bytes (JSON)`);
                
                // Extraire et afficher les données
                const gameData = extractDataFromBase64Export(validExport);
                console.log(`   Personnages: ${gameData.summary?.totalCharacters || 'N/A'}`);
                console.log(`   Recettes: ${gameData.summary?.totalRecipes || 'N/A'}`);
            } else {
                console.log('❌ Échec validation export valide:', result.error);
            }
        } catch (error) {
            console.log('❌ Erreur lecture export valide:', error.message);
        }
    } else {
        console.log('⚠️  Fichier test-export-b64.json non trouvé - test ignoré');
    }

    // Test 2: Détection de falsification
    console.log('\n🔒 Test 2: Détection falsification');
    if (fs.existsSync('./test-export-b64.json')) {
        try {
            const tamperedExport = JSON.parse(fs.readFileSync('./test-export-b64.json', 'utf8'));
            
            // Modifier légèrement le Base64
            tamperedExport.dataBase64 = tamperedExport.dataBase64.slice(0, -10) + 'XXXXXXXXXX';
            
            const result = verifySignature(tamperedExport);
            
            if (!result.valid && result.error.includes('DataChecksum')) {
                console.log('✅ Falsification détectée correctement');
                console.log(`   Erreur: ${result.error}`);
            } else {
                console.log('❌ Falsification non détectée - PROBLÈME DE SÉCURITÉ!');
                console.log(`   Result: ${JSON.stringify(result)}`);
            }
        } catch (error) {
            console.log('❌ Erreur test falsification:', error.message);
        }
    } else {
        console.log('⚠️  Fichier test-export-b64.json non trouvé - test ignoré');
    }

    // Test 3: Format legacy rejeté
    console.log('\n📛 Test 3: Rejet format legacy');
    const legacyExport = {
        signature: "fake-signature",
        signatureInfo: {
            algorithm: "multi-pass-md5", // Ancien format
            timestamp: Date.now(),
            nonce: "fake-nonce"
        },
        characters: { "test": {} }
    };
    
    const legacyResult = verifySignature(legacyExport);
    if (!legacyResult.valid && legacyResult.error.includes('legacy')) {
        console.log('✅ Format legacy rejeté correctement');
    } else {
        console.log('❌ Format legacy accepté - problème de compatibilité');
    }

    // Test 4: Performance checksum
    console.log('\n⚡ Test 4: Performance checksum');
    const testData = 'A'.repeat(100000); // 100KB de données
    const start = process.hrtime.bigint();
    const hash = md5_sumhexa(testData);
    const end = process.hrtime.bigint();
    const duration = Number(end - start) / 1000000; // Convert to milliseconds
    
    console.log(`✅ Checksum 100KB: ${duration.toFixed(2)}ms`);
    console.log(`   Hash: ${hash}`);

    // Test 5: Décodage Base64
    console.log('\n🔄 Test 5: Décodage Base64');
    const testObject = { test: "données de test", number: 42, array: [1, 2, 3] };
    const testJson = JSON.stringify(testObject);
    const testBase64 = Buffer.from(testJson).toString('base64');
    
    try {
        const decoded = Buffer.from(testBase64, 'base64').toString('utf8');
        const parsed = JSON.parse(decoded);
        
        if (JSON.stringify(parsed) === JSON.stringify(testObject)) {
            console.log('✅ Encodage/décodage Base64 fonctionnel');
            console.log(`   Original: ${testJson.length} bytes`);
            console.log(`   Base64: ${testBase64.length} bytes (+${Math.round((testBase64.length/testJson.length - 1) * 100)}%)`);
        } else {
            console.log('❌ Problème encodage/décodage Base64');
        }
    } catch (error) {
        console.log('❌ Erreur décodage Base64:', error.message);
    }

    console.log('\n' + '='.repeat(50));
    console.log('🏁 Tests terminés');
}

function analyzeExport(filename) {
    console.log(`🔍 Analyse de l'export: ${filename}`);
    console.log('='.repeat(50));
    
    try {
        const exportData = JSON.parse(fs.readFileSync(filename, 'utf8'));
        
        // Informations générales
        console.log('\n📊 Informations générales:');
        console.log(`   Fichier: ${filename} (${Math.round(fs.statSync(filename).size / 1024 * 100) / 100} KB)`);
        
        if (exportData.metadata) {
            console.log(`   Addon: ${exportData.metadata.addon} v${exportData.metadata.version}`);
            console.log(`   Date: ${new Date(exportData.metadata.timestamp * 1000).toISOString()}`);
            console.log(`   Locale: ${exportData.metadata.locale}`);
        }
        
        // Format détecté
        if (exportData.dataBase64 && exportData.signatureInfo?.algorithm === "multi-pass-md5-base64") {
            console.log(`   Format: Base64 sécurisé ✅`);
            console.log(`   Base64: ${Math.round(exportData.dataBase64.length / 1024 * 100) / 100} KB`);
        } else if (exportData.signatureInfo?.algorithm === "multi-pass-md5") {
            console.log(`   Format: Legacy multi-passes ⚠️`);
        } else {
            console.log(`   Format: Inconnu ou simple ❌`);
        }
        
        // Validation
        console.log('\n🔐 Validation:');
        const result = verifySignature(exportData);
        
        if (result.valid) {
            console.log('   Signature: ✅ VALIDE');
            console.log(`   Algorithme: ${result.metadata.algorithm}`);
            console.log(`   Challenge: ${result.metadata.hasChallenge ? '✅' : '❌'}`);
            console.log(`   Timestamp: ${new Date(result.metadata.timestamp * 1000).toISOString()}`);
        } else {
            console.log('   Signature: ❌ INVALIDE');
            console.log(`   Erreur: ${result.error}`);
            if (result.expected && result.received) {
                console.log(`   Attendue: ${result.expected}`);
                console.log(`   Reçue: ${result.received}`);
            }
        }
        
        // Contenu (si Base64 et valide)
        if (exportData.dataBase64 && result.valid) {
            try {
                const gameData = extractDataFromBase64Export(exportData);
                console.log('\n🎮 Contenu du jeu:');
                if (gameData.summary) {
                    console.log(`   Personnages: ${gameData.summary.totalCharacters}`);
                    console.log(`   Professions: ${gameData.summary.totalProfessions}`);
                    console.log(`   Recettes: ${gameData.summary.totalRecipes}`);
                }
                
                if (gameData.characters) {
                    console.log('\n👥 Personnages:');
                    for (const [charKey, charData] of Object.entries(gameData.characters)) {
                        console.log(`   • ${charData.info?.name}-${charData.info?.realm} (${charData.info?.class}, lvl ${charData.info?.level})`);
                        if (charData.isCurrentCharacter) console.log('     [Personnage actuel]');
                    }
                }
            } catch (error) {
                console.log('\n❌ Erreur extraction contenu:', error.message);
            }
        }
        
    } catch (error) {
        console.log(`❌ Erreur analyse: ${error.message}`);
    }
}

// Main
if (require.main === module) {
    const filename = process.argv[2];
    
    if (filename) {
        if (fs.existsSync(filename)) {
            analyzeExport(filename);
        } else {
            console.error(`❌ Fichier non trouvé: ${filename}`);
            process.exit(1);
        }
    } else {
        runTests();
    }
}

module.exports = { runTests, analyzeExport };
