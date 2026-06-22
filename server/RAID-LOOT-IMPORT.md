# Contrat d'import — Butin de raid (`raidLoots`)

Capture des objets **épiques** tombés en raid et de leur destinataire, « façon
Gargul », pour le journal du joueur et le tableau de butin de la guilde sur
auberdine.eu.

Produit par `LootTracker.lua` (addon, v1.7.3+), transmis dans l'export perso
signé (clé top-level `raidLoots`), traité côté serveur en **side-channel** par
`addonImporter.processRaidLoots` — exactement comme `census`. Aucun changement
du client Go uploader.

## Forme du payload

```jsonc
"raidLoots": {
  "schema": 1,
  "items": [
    {
      "lootUid":     "Qist:0:18832:1718987050",  // identité STABLE du drop (cf. infra)
      "recipient":   "Qist",                       // nom (sans royaume) du destinataire
      "itemId":      18832,
      "itemName":    "Lame de la brutalité",       // libellé du lien (localisé)
      "itemLink":    "|cffa335ee|Hitem:18832:...|h[...]|h|r",
      "itemQuality": 4,                            // 4=épique, 5=légendaire (lu sur la COULEUR du lien)
      "bossName":    "Ragnaros",                   // dernier ENCOUNTER_END (libellé, peut être null)
      "instanceName":"Molten Core",
      "instanceId":  409,
      "lootedAt":    1718987050000,                // epoch MS (aligné raid_analyses / guild_boss_pulls)
      "source":      "chat",                       // 'chat' (passif) | 'gargul' (master looter)
      // enrichissement Gargul (null en capture passive) :
      "disposition": "awarded",                    // awarded | disenchanted | banked
      "reason":      "BiS",                         // BiS | OS | DE … (note Gargul)
      "awardedBy":   "Nomduml"
    }
  ]
}
```

## Règles

- **Épiques seulement** (`itemQuality >= 4`). La qualité est lue sur la couleur
  du lien (`|cffa335ee` = épique), donc *locale-proof* et indépendante du cache
  client. Le serveur re-filtre par sécurité.
- **Raids seulement** : capture gated sur `IsInInstance() == "raid"`. Les
  épiques de donjon ne matcheraient aucune entrée de raid WCL.
- **`lootUid`** : identité déterministe d'un drop physique, calculée par
  l'addon et stockée (clé de `AuberdineExporterDB.raidLoots.items`). Garantit :
  1. **idempotence** — l'historique complet est ré-émis à chaque export ; le
     serveur upsert par `loot_uid` (table `raid_loots`).
  2. **fusion chat/gargul** — un même drop vu en chat PUIS attribué via Gargul
     retombe sur la même ligne, enrichie (gargul autoritaire).
  Forme : `recipient:bossId:itemId:timestampSec`.
- **`lootedAt` en epoch MS** : c'est l'unité de `raid_analyses` et
  `guild_boss_pulls` côté serveur, indispensable au rattachement temporel.
- **Pas d'ID de boss** : l'addon ne connaît que l'encounterID *Blizzard* (≠ WCL)
  et le nom. Le serveur résout le boss canonique (encounterID WCL) par
  recoupement temporel sur la timeline du raid. `bossName` n'est qu'un libellé
  de repli.

## Rattachement côté serveur (rappel)

Le loot arrive en temps réel ; le log WCL du raid souvent après. Le
`lootMatcher` relie chaque loot à une entrée de raid de façon **asynchrone** :
`report_code` par containment temporel dans `raid_analyses` (départagé par
roster si raids concomitants), `encounter_id` WCL par le kill `guild_boss_pulls`
le plus proche. Re-tenté au calcul de chaque nouveau `raid_analyses`.
