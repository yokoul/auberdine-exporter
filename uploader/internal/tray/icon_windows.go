//go:build tray && windows

// Sous Windows, systray attend une icône au format ICO (PNG ailleurs).
package tray

import _ "embed"

//go:embed icon.ico
var iconData []byte
