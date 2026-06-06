// Package luasv parse les fichiers SavedVariables de World of Warcraft.
//
// Un fichier SavedVariables est une suite d'affectations de premier niveau
// (`Nom = valeur`) où les valeurs sont des littéraux Lua : tables, chaînes,
// nombres, booléens et nil. Il ne contient pas d'expressions ni d'appels de
// fonction. Le parseur reste donc volontairement minimal et générique : il ne
// connaît rien au schéma d'AuberdineExporter, ce qui le rend robuste aux
// évolutions de l'addon — on transmet la structure telle qu'elle est écrite.
package luasv

import (
	"fmt"
	"strconv"
	"strings"
	"unicode"
)

// Parse lit le contenu complet d'un fichier SavedVariables et renvoie une map
// des variables globales de premier niveau (ex. "AuberdineExporterDB").
//
// Les tables Lua sont converties ainsi :
//   - une table dont les clés sont les entiers 1..n contigus devient un []any ;
//   - sinon elle devient une map[string]any (les clés entières sont
//     converties en chaînes, comme le ferait un encodage JSON).
func Parse(src string) (map[string]any, error) {
	p := &parser{lex: newLexer(src)}
	return p.parseChunk()
}

// ---------------------------------------------------------------------------
// Lexer
// ---------------------------------------------------------------------------

type tokenKind int

const (
	tEOF tokenKind = iota
	tIdent
	tString
	tNumber
	tTrue
	tFalse
	tNil
	tLBrace // {
	tRBrace // }
	tLBrack // [
	tRBrack // ]
	tEquals // =
	tComma  // ,
	tSemi   // ;
)

type token struct {
	kind tokenKind
	str  string  // valeur pour tIdent / tString
	num  float64 // valeur pour tNumber
	pos  int
}

type lexer struct {
	src string
	pos int
}

func newLexer(src string) *lexer { return &lexer{src: src} }

func (l *lexer) errf(format string, args ...any) error {
	return fmt.Errorf("luasv: position %d: %s", l.pos, fmt.Sprintf(format, args...))
}

func (l *lexer) next() (token, error) {
	l.skipTrivia()
	if l.pos >= len(l.src) {
		return token{kind: tEOF, pos: l.pos}, nil
	}
	start := l.pos
	c := l.src[l.pos]

	switch c {
	case '{':
		l.pos++
		return token{kind: tLBrace, pos: start}, nil
	case '}':
		l.pos++
		return token{kind: tRBrace, pos: start}, nil
	case '[':
		// Peut être un délimiteur de clé `[` ou une chaîne longue `[[ ... ]]`.
		if s, ok, err := l.tryLongString(); err != nil {
			return token{}, err
		} else if ok {
			return token{kind: tString, str: s, pos: start}, nil
		}
		l.pos++
		return token{kind: tLBrack, pos: start}, nil
	case ']':
		l.pos++
		return token{kind: tRBrack, pos: start}, nil
	case '=':
		l.pos++
		return token{kind: tEquals, pos: start}, nil
	case ',':
		l.pos++
		return token{kind: tComma, pos: start}, nil
	case ';':
		l.pos++
		return token{kind: tSemi, pos: start}, nil
	case '"', '\'':
		s, err := l.scanQuotedString(c)
		if err != nil {
			return token{}, err
		}
		return token{kind: tString, str: s, pos: start}, nil
	}

	if c == '-' || c == '+' || c == '.' || (c >= '0' && c <= '9') {
		return l.scanNumber()
	}
	if isIdentStart(rune(c)) {
		return l.scanIdent()
	}
	return token{}, l.errf("caractère inattendu %q", c)
}

func (l *lexer) skipTrivia() {
	for l.pos < len(l.src) {
		c := l.src[l.pos]
		switch {
		case c == ' ' || c == '\t' || c == '\r' || c == '\n':
			l.pos++
		case c == '-' && l.pos+1 < len(l.src) && l.src[l.pos+1] == '-':
			// Commentaire : long `--[[ ... ]]` ou ligne `-- ...`.
			l.pos += 2
			if l.pos+1 < len(l.src) && l.src[l.pos] == '[' && l.src[l.pos+1] == '[' {
				if idx := strings.Index(l.src[l.pos:], "]]"); idx >= 0 {
					l.pos += idx + 2
				} else {
					l.pos = len(l.src)
				}
			} else {
				if idx := strings.IndexByte(l.src[l.pos:], '\n'); idx >= 0 {
					l.pos += idx + 1
				} else {
					l.pos = len(l.src)
				}
			}
		default:
			return
		}
	}
}

func (l *lexer) tryLongString() (string, bool, error) {
	// Appelé quand src[pos] == '['. Gère `[[ ... ]]` et `[=[ ... ]=]`.
	p := l.pos + 1
	eq := 0
	for p < len(l.src) && l.src[p] == '=' {
		eq++
		p++
	}
	if p >= len(l.src) || l.src[p] != '[' {
		return "", false, nil
	}
	p++ // saute le second '['
	closing := "]" + strings.Repeat("=", eq) + "]"
	idx := strings.Index(l.src[p:], closing)
	if idx < 0 {
		return "", false, l.errf("chaîne longue non terminée")
	}
	content := l.src[p : p+idx]
	content = strings.TrimPrefix(content, "\n")
	l.pos = p + idx + len(closing)
	return content, true, nil
}

func (l *lexer) scanQuotedString(quote byte) (string, error) {
	l.pos++ // saute le guillemet ouvrant
	var b strings.Builder
	for l.pos < len(l.src) {
		c := l.src[l.pos]
		if c == quote {
			l.pos++
			return b.String(), nil
		}
		if c == '\\' {
			l.pos++
			if l.pos >= len(l.src) {
				break
			}
			e := l.src[l.pos]
			switch e {
			case 'n':
				b.WriteByte('\n')
			case 't':
				b.WriteByte('\t')
			case 'r':
				b.WriteByte('\r')
			case 'a':
				b.WriteByte(7)
			case 'b':
				b.WriteByte(8)
			case 'f':
				b.WriteByte(12)
			case 'v':
				b.WriteByte(11)
			case '\\', '"', '\'':
				b.WriteByte(e)
			case '\n':
				b.WriteByte('\n')
			default:
				if e >= '0' && e <= '9' {
					// Échappement décimal \ddd (1 à 3 chiffres).
					n := 0
					for k := 0; k < 3 && l.pos < len(l.src) && l.src[l.pos] >= '0' && l.src[l.pos] <= '9'; k++ {
						n = n*10 + int(l.src[l.pos]-'0')
						l.pos++
					}
					b.WriteByte(byte(n))
					continue
				}
				b.WriteByte(e)
			}
			l.pos++
			continue
		}
		b.WriteByte(c)
		l.pos++
	}
	return "", l.errf("chaîne non terminée")
}

func (l *lexer) scanNumber() (token, error) {
	start := l.pos
	if l.src[l.pos] == '+' || l.src[l.pos] == '-' {
		l.pos++
	}
	// Hexadécimal ?
	if l.pos+1 < len(l.src) && l.src[l.pos] == '0' && (l.src[l.pos+1] == 'x' || l.src[l.pos+1] == 'X') {
		l.pos += 2
		for l.pos < len(l.src) && isHex(l.src[l.pos]) {
			l.pos++
		}
		v, err := strconv.ParseInt(l.src[start:l.pos], 0, 64)
		if err != nil {
			return token{}, l.errf("nombre hexadécimal invalide %q", l.src[start:l.pos])
		}
		return token{kind: tNumber, num: float64(v), pos: start}, nil
	}
	for l.pos < len(l.src) {
		c := l.src[l.pos]
		if (c >= '0' && c <= '9') || c == '.' || c == 'e' || c == 'E' || c == '+' || c == '-' {
			l.pos++
			continue
		}
		break
	}
	v, err := strconv.ParseFloat(l.src[start:l.pos], 64)
	if err != nil {
		return token{}, l.errf("nombre invalide %q", l.src[start:l.pos])
	}
	return token{kind: tNumber, num: v, pos: start}, nil
}

func (l *lexer) scanIdent() (token, error) {
	start := l.pos
	for l.pos < len(l.src) && isIdentPart(rune(l.src[l.pos])) {
		l.pos++
	}
	word := l.src[start:l.pos]
	switch word {
	case "true":
		return token{kind: tTrue, pos: start}, nil
	case "false":
		return token{kind: tFalse, pos: start}, nil
	case "nil":
		return token{kind: tNil, pos: start}, nil
	}
	return token{kind: tIdent, str: word, pos: start}, nil
}

func isIdentStart(r rune) bool { return r == '_' || unicode.IsLetter(r) }
func isIdentPart(r rune) bool  { return r == '_' || unicode.IsLetter(r) || unicode.IsDigit(r) }
func isHex(c byte) bool {
	return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

// ---------------------------------------------------------------------------
// Parser
// ---------------------------------------------------------------------------

type parser struct {
	lex    *lexer
	peeked *token
}

func (p *parser) next() (token, error) {
	if p.peeked != nil {
		t := *p.peeked
		p.peeked = nil
		return t, nil
	}
	return p.lex.next()
}

func (p *parser) peek() (token, error) {
	if p.peeked == nil {
		t, err := p.lex.next()
		if err != nil {
			return token{}, err
		}
		p.peeked = &t
	}
	return *p.peeked, nil
}

// parseChunk lit les affectations globales `Nom = valeur` jusqu'à EOF.
func (p *parser) parseChunk() (map[string]any, error) {
	out := map[string]any{}
	for {
		t, err := p.next()
		if err != nil {
			return nil, err
		}
		if t.kind == tEOF {
			return out, nil
		}
		if t.kind == tSemi {
			continue
		}
		if t.kind != tIdent {
			return nil, fmt.Errorf("luasv: attendu un identifiant global, obtenu %v", t.kind)
		}
		if eq, err := p.next(); err != nil {
			return nil, err
		} else if eq.kind != tEquals {
			return nil, fmt.Errorf("luasv: attendu '=' après %q", t.str)
		}
		val, err := p.parseValue()
		if err != nil {
			return nil, err
		}
		out[t.str] = val
	}
}

func (p *parser) parseValue() (any, error) {
	t, err := p.next()
	if err != nil {
		return nil, err
	}
	switch t.kind {
	case tString:
		return t.str, nil
	case tNumber:
		return t.num, nil
	case tTrue:
		return true, nil
	case tFalse:
		return false, nil
	case tNil:
		return nil, nil
	case tLBrace:
		return p.parseTable()
	default:
		return nil, fmt.Errorf("luasv: valeur inattendue (token %v)", t.kind)
	}
}

// tableEntry conserve l'ordre et distingue les clés explicites des positions.
type tableEntry struct {
	key      any // string, int, ou nil pour une entrée positionnelle
	value    any
	implicit bool
}

func (p *parser) parseTable() (any, error) {
	var entries []tableEntry
	for {
		t, err := p.peek()
		if err != nil {
			return nil, err
		}
		if t.kind == tRBrace {
			p.next()
			break
		}
		if t.kind == tComma || t.kind == tSemi {
			p.next()
			continue
		}

		switch t.kind {
		case tLBrack:
			// [clé] = valeur
			p.next()
			keyTok, err := p.next()
			if err != nil {
				return nil, err
			}
			var key any
			switch keyTok.kind {
			case tString:
				key = keyTok.str
			case tNumber:
				key = keyTok.num
			default:
				return nil, fmt.Errorf("luasv: clé de table invalide (token %v)", keyTok.kind)
			}
			if rb, err := p.next(); err != nil {
				return nil, err
			} else if rb.kind != tRBrack {
				return nil, fmt.Errorf("luasv: ']' attendu après une clé de table")
			}
			if eq, err := p.next(); err != nil {
				return nil, err
			} else if eq.kind != tEquals {
				return nil, fmt.Errorf("luasv: '=' attendu après une clé de table")
			}
			val, err := p.parseValue()
			if err != nil {
				return nil, err
			}
			entries = append(entries, tableEntry{key: key, value: val})

		case tIdent:
			// nom = valeur (clé identifiant non quotée)
			p.next()
			if eq, err := p.peek(); err != nil {
				return nil, err
			} else if eq.kind == tEquals {
				p.next()
				val, err := p.parseValue()
				if err != nil {
					return nil, err
				}
				entries = append(entries, tableEntry{key: t.str, value: val})
			} else {
				return nil, fmt.Errorf("luasv: '=' attendu après la clé %q", t.str)
			}

		default:
			// Valeur positionnelle (tableau).
			val, err := p.parseValue()
			if err != nil {
				return nil, err
			}
			entries = append(entries, tableEntry{value: val, implicit: true})
		}
	}
	return materialize(entries), nil
}

// materialize convertit les entrées en []any si la table est un tableau
// contigu 1..n, sinon en map[string]any.
func materialize(entries []tableEntry) any {
	if len(entries) == 0 {
		// Table vide : on ne peut pas deviner. Une map vide est le choix le
		// plus sûr pour l'encodage JSON.
		return map[string]any{}
	}

	// Index positionnel courant (les entrées implicites occupent 1, 2, 3, …).
	nextIdx := 1
	isArray := true
	maxIdx := 0
	seen := map[int]bool{}

	for _, e := range entries {
		switch {
		case e.implicit:
			if seen[nextIdx] {
				isArray = false
			}
			seen[nextIdx] = true
			if nextIdx > maxIdx {
				maxIdx = nextIdx
			}
			nextIdx++
		case isIntKey(e.key):
			n := int(e.key.(float64))
			if n < 1 || seen[n] {
				isArray = false
			}
			seen[n] = true
			if n > maxIdx {
				maxIdx = n
			}
		default:
			isArray = false
		}
	}
	if isArray && maxIdx == len(entries) {
		arr := make([]any, maxIdx)
		idx := 1
		for _, e := range entries {
			if e.implicit {
				arr[idx-1] = e.value
				idx++
			} else {
				arr[int(e.key.(float64))-1] = e.value
			}
		}
		return arr
	}

	m := map[string]any{}
	idx := 1
	for _, e := range entries {
		switch {
		case e.implicit:
			m[strconv.Itoa(idx)] = e.value
			idx++
		case isIntKey(e.key):
			m[strconv.Itoa(int(e.key.(float64)))] = e.value
		default:
			m[fmt.Sprintf("%v", e.key)] = e.value
		}
	}
	return m
}

func isIntKey(k any) bool {
	f, ok := k.(float64)
	return ok && f == float64(int(f))
}
