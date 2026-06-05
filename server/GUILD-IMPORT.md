# Handoff importer — ingestion des données de guilde (clé `guilds`)

> **Pour l'agent qui modifie l'importer auberdine.eu.**
> L'addon (v1.5.0) émet désormais une clé `guilds` dans le payload d'export.
> Aucun code serveur ne la lit encore. Ce document décrit précisément le
> contrat, l'algorithme d'import attendu et les pièges. Le contrat « source de
> vérité » côté addon est dans `docs/GUILD-TRACKING.md` ; ce fichier-ci se
> concentre sur **l'implémentation côté importer**.

---

## 1. Où se trouve la donnée

La clé `guilds` est **à l'intérieur du payload signé**, au même niveau que
`characters` / `summary` / `relationships`. Elle n'a **pas** de signature
propre : elle est couverte par la signature de l'enveloppe (`dataBase64`).

➡️ **Vérifier la signature de l'enveloppe AVANT de toucher à `guilds`.** Si la
signature est invalide, ignorer tout l'export.

```js
const {
  verifySignature,
  extractDataFromBase64Export,
} = require('./verifyBase64Export');

function ingest(envelope) {
  // 1) Authentifier l'enveloppe (couvre aussi `guilds`)
  const check = verifySignature(envelope);
  if (!check.valid) throw new Error('Export invalide: ' + check.error);

  // 2) Décoder le payload de jeu
  const data = extractDataFromBase64Export(envelope);

  // 3) `guilds` est OPTIONNEL (voir §4). Tableau ou undefined.
  if (Array.isArray(data.guilds)) {
    for (const g of data.guilds) importGuild(g, { envelope });
  }
}
```

`data.guilds` est **absent** si : le suivi est désactivé, aucune guilde n'est
partagée, ou (rare) l'addon n'a rien produit. Ne pas supposer sa présence.

---

## 2. Forme d'une entrée `guilds[i]`

Deux modes, distingués par le champ `mode`.

### Mode `full` (snapshot complet)
```json
{
  "name": "Ma Guilde",
  "realm": "Auberdine",
  "faction": "Alliance",
  "mode": "full",
  "since": 1730800000,
  "exportedAt": 1733400000,
  "ranks": { "0": "Guild Master", "1": "Officier", "4": "Membre" },
  "memberCount": 42,
  "members": [
    { "name": "Carnalis", "class": "MAGE", "level": 60,
      "rankIndex": 0, "publicNote": "chef", "joinDate": 1733000000 }
  ],
  "log": [
    { "ts": 1733400500, "type": "PROMOTE", "target": "Bob",
      "actor": "Yan", "detail": "Officier" }
  ]
}
```

### Mode `delta` (incrémental — défaut)
```json
{
  "name": "Autre Guilde",
  "realm": "Auberdine",
  "mode": "delta",
  "since": 1733300000,
  "exportedAt": 1733400000,
  "log": [
    { "ts": 1733401000, "type": "KICK", "target": "BadGuy", "actor": "Yan" }
  ]
}
```

### Référence des champs

| Champ         | Modes        | Type        | Notes |
|---------------|--------------|-------------|-------|
| `name`        | full + delta | string      | Nom de guilde. Élément clé d'identité. |
| `realm`       | full + delta | string?     | Royaume. **Peut être absent**, surtout en delta. |
| `faction`     | full + delta | string?     | `"Alliance"`/`"Horde"`. Souvent **absent en delta**. |
| `mode`        | full + delta | `"full"`/`"delta"` | Pilote l'algorithme (voir §3). |
| `since`       | full + delta | int (epoch s) | Borne basse : le journal contient les events **strictement > `since`**. |
| `exportedAt`  | full + delta | int (epoch s) | Horodatage de génération. |
| `ranks`       | **full**     | objet `{ "<rankIndex>": "<nom>" }` | **Clés = chaînes** ("0","1","4"), pas contigües. Convertir en int si besoin. |
| `memberCount` | **full**     | int         | `== members.length`. |
| `members`     | **full**     | array       | Roster courant complet (voir ci-dessous). |
| `log`         | full + delta | array       | Événements (voir §2.1). Peut être **vide** `[]`. |

`members[i]` :

| Champ        | Type    | Notes |
|--------------|---------|-------|
| `name`       | string  | |
| `class`      | string  | Token classe WoW (`"MAGE"`, `"WARRIOR"`, …). |
| `level`      | int     | |
| `rankIndex`  | int     | Index dans `ranks` (0 = GM). |
| `publicNote` | string? | **Absent** si note vide ou si « Exporter les notes publiques » est décoché. |
| `joinDate`   | int?    | Epoch s. Best-effort, peut manquer. |

### 2.1 Événements `log[i]`

Champs exportés (et **uniquement** ceux-là — `fromRank`/`fromNote` existent en
interne mais **ne sont pas** émis) : `ts`, `type`, `target`, `actor?`, `detail?`.

| `type`    | Sens                              | `actor`            | `detail`            |
|-----------|-----------------------------------|--------------------|---------------------|
| `JOIN`    | `target` a rejoint la guilde      | —                  | —                   |
| `LEAVE`   | `target` est parti (volontaire)   | —                  | —                   |
| `KICK`    | `target` a été expulsé            | best-effort (peut manquer) | —          |
| `PROMOTE` | `target` promu                    | best-effort        | **nouveau** rang (nom) |
| `DEMOTE`  | `target` rétrogradé               | best-effort        | **nouveau** rang (nom) |
| `NOTE`    | note publique de `target` modifiée| —                  | **nouvelle** note (peut être `""`) |

- `ts` = epoch s. `target`/`actor` sont des **noms** de personnage (pas des GUID).
- `actor` est « best-effort » : déduit des messages système, **souvent absent**.
  Ne jamais le rendre obligatoire.

---

## 3. Algorithme d'import

Traiter chaque entrée indépendamment, **idempotemment** (les exports se
recouvrent ; voir §4).

```
importGuild(entry, ctx):
    guild = upsertGuildIdentity(entry.name, entry.realm, entry.faction)

    if entry.mode == "full":
        # Le roster fourni fait autorité à l'instant exportedAt
        replaceRoster(guild, entry.members)      # upsert membres présents …
        markAbsentMembersLeft(guild, entry.members, entry.exportedAt)  # … et marquer les absents
        upsertRanks(guild, entry.ranks)
        guild.lastFullAt = max(guild.lastFullAt, entry.exportedAt)

    # full ET delta charrient un journal :
    for ev in (entry.log || []):
        appendEventDedup(guild, ev)              # voir §4 (clé de dédup)
```

- **`full`** → le roster fourni **remplace/upsert** l'état connu. Les membres
  connus du serveur **absents** du snapshot peuvent être marqués « partis »
  (à `exportedAt`) — c'est le seul moyen fiable de rattraper les départs ratés.
- **`delta`** → **pas** de `members`/`ranks`. On applique seulement le journal
  au roster déjà connu (append + dédup). Si la guilde est inconnue côté serveur
  (on n'a jamais reçu de `full`), créer une coquille d'identité et **accumuler
  quand même le journal** ; le roster sera rempli au prochain `full`.

---

## 4. Idempotence & dédoublonnage (CRITIQUE)

Les exports **se recouvrent volontairement** — il faut donc dédupliquer :

1. **Recouvrement temporel.** En delta, `since` est ré-ancré sur
   `max(lastExportTs, now - 30j)`. Un même événement peut être renvoyé si un
   export précédent n'a pas été importé (l'addon ne sait pas s'il a abouti).
2. **Re-soumission de l'enveloppe.** Le même fichier peut être posté deux fois.
3. **Fenêtre glissante de 30 j.** Un `full` ré-émet le roster et le journal
   récent à chaque fois.

**Défenses recommandées (les deux) :**

- **Au niveau enveloppe** : mémoriser `signatureInfo.nonce` (+ `timestamp`)
  déjà traités et court-circuiter les rejeux complets.
- **Au niveau événement** : clé de dédup stable
  ```
  (guildId, ts, type, target, actor || '', detail || '')
  ```
  `appendEventDedup` insère seulement si cette clé n'existe pas (ex.
  contrainte UNIQUE + `INSERT … ON CONFLICT DO NOTHING`).

> ⚠️ Ne **pas** déduire l'unicité de `ts` seul : plusieurs événements peuvent
> partager la même seconde (ex. promotion + changement de note).

**Important — côté client ≠ côté serveur :**
- Le bouton **« Vider le journal »** et la **rétention `maxLog`** (50–50000)
  sont **purement locaux** à l'addon. Ils n'émettent rien. Le serveur **garde**
  son historique : un journal vidé chez le joueur ne doit jamais effacer
  l'historique serveur.
- Une entrée `delta` avec `log: []` est **normale** (guilde partagée mais aucun
  nouvel événement) → **no-op**, ne pas la traiter comme une erreur.

---

## 5. Identité de guilde (clé de regroupement)

- Clé conseillée : **`name` normalisé** (+ `realm` quand présent). Garder
  `faction` comme attribut, **pas** comme clé (souvent absent en delta).
- Normaliser pour la comparaison (trim, casse), mais **conserver l'affichage**
  d'origine.
- Un `delta` peut arriver **sans `realm`** : faire correspondre sur `name`
  (+ realm de l'enveloppe / du personnage exportant si disponible), sinon
  rattacher à la guilde `name` existante la plus probable, ou créer une coquille
  en attendant le prochain `full` qui portera `realm`+`faction`.

---

## 6. Checklist d'implémentation

- [ ] Brancher l'ingestion guildes **après** `verifySignature` (réutiliser
      `extractDataFromBase64Export`), dans le même handler que l'import perso.
- [ ] Schéma : `guilds`, `guild_members`, `guild_ranks`, `guild_events`
      (UNIQUE sur la clé de dédup §4).
- [ ] `mode=full` → upsert roster + ranks, marquer les absents partis.
- [ ] `mode=delta` → append-dedup du journal uniquement.
- [ ] Dédup enveloppe (nonce) **et** dédup événement.
- [ ] Tolérer `realm`/`faction`/`actor`/`publicNote`/`joinDate` absents.
- [ ] `ranks` : clés en **chaînes** → convertir si la colonne est int.
- [ ] `log: []` et `guilds` absent → no-op silencieux.
- [ ] Tests : rejouer deux fois le **même** export → 0 doublon ; un `delta`
      après un `full` → events ajoutés une seule fois ; `full` avec un membre en
      moins → ancien membre marqué parti.

---

## 7. Pour tester sans serveur

`server/verifyBase64Export.js` décode déjà un export ; en CLI :
```bash
node server/verifyBase64Export.js mon-export.json
```
Pour inspecter la clé guildes d'un export local :
```js
const { extractDataFromBase64Export } = require('./server/verifyBase64Export');
const data = extractDataFromBase64Export(require('./mon-export.json'));
console.dir(data.guilds, { depth: null });
```
Côté addon, un harness Lua (API WoW mockée) valide déjà la production de
`guilds` (full/delta, dédup d'événements, rétention) — voir l'historique de la
PR de suivi de guilde si besoin de reproduire des cas.
