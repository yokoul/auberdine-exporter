//go:build tray && !windows

// macOS / Linux : systray accepte le PNG directement.
package tray

import _ "embed"

//go:embed icon.png
var iconData []byte
