import QtQuick
import Quickshell
import Quickshell.Io
import "file:/usr/share/omarchy/shell/services" as StockServices

// Keep the Alt-held session logic separate from the themed window list.
Item {
  id: root
  property var shell: null
  property var manifest: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  readonly property string picker: Quickshell.env("HOME") + "/.local/bin/omarchy-window-picker"
  property real session: -1
  property int serial: -1
  property int steps: 0
  property var addresses: []
  property var windows: []
  property bool closed: true
  property bool accepted: false
  property bool showReady: false
  property bool loaded: false

  StockServices.AppLibrary { id: appLibrary }

  function decorate(window, index) {
    var entry = null
    var ids = [window.desktopId, window.appId, window.initialAppId]
    for (var i = 0; i < ids.length && !entry; i++) {
      if (typeof ids[i] === "string" && ids[i].length <= 512 && ids[i])
        entry = DesktopEntries.heuristicLookup(ids[i])
    }
    // Desktop icons resolve through the local application library. Unmatched
    // windows receive a themed generic icon, never a URL from a window title.
    return Object.assign({}, window, {
      label: entry ? String(index + 1) + ". " + appLibrary.entryName(entry) : window.label,
      iconSource: appLibrary.iconSource(entry && entry.icon ? entry.icon : "application-x-executable")
    })
  }

  function open(payloadJson) {
    var p
    try { p = JSON.parse(payloadJson) } catch (e) { return }
    if (!Number.isSafeInteger(p.session) || !Number.isInteger(p.serial)
        || !Number.isInteger(p.steps) || !Array.isArray(p.addresses)
        || p.addresses.length > 500 || !p.addresses.every(function(a) {
          return typeof a === "string" && /^0x[0-9a-fA-F]+$/.test(a)
        }) || (p.action !== "step" && p.action !== "accept" && p.action !== "cancel")) return
    if (p.session < session || (p.session === session && (closed || p.serial <= serial))) return
    var fresh = p.session !== session
    if (p.action === "cancel") {
      session = p.session
      serial = p.serial
      close()
      return
    }
    if (fresh) {
      closed = true
      menu.cancel()
      session = p.session
      serial = -1
      addresses = p.addresses
      windows = []
      accepted = false
      showReady = false
      loaded = false
      closed = false
      delay.restart()
      if (!reader.running) reader.running = true
    }
    var delta = p.steps - steps
    steps = p.steps
    serial = p.serial
    accepted = p.action === "accept"
    if (!fresh && menu.opened && delta !== 0) menu.select(Number(delta))
    settle()
  }

  function settle() {
    if (closed || !loaded) return
    if (windows.length === 0) { close(); return }
    if (accepted) {
      if (menu.opened) menu.activateIndex(menu.selectedIndex)
      else {
        var index = ((steps % windows.length) + windows.length) % windows.length
        finish(windows[index].value)
      }
    } else if (showReady && !menu.opened) {
      menu.openWindows(windows)
      menu.select(Number(steps))
    }
  }

  function finish(value) {
    if (closed) return
    var chosen = windows.find(function(w) { return w.value === value })
    closed = true
    delay.stop()
    menu.opened = false
    if (chosen) Quickshell.execDetached([picker, "--focus", chosen.address])
  }

  function close() {
    closed = true
    delay.stop()
    menu.opened = false
    menu.filterText = ""
  }

  function status() {
    return JSON.stringify({session: session, serial: serial, steps: steps, closed: closed,
      opened: menu.opened, selected: menu.selectedIndex, filter: menu.filterText,
      addresses: windows.map(function(w) { return w.address }),
      icons: windows.map(function(w) { return { address: w.address, source: w.iconSource } })})
  }

  Timer { id: delay; interval: 150; onTriggered: { root.showReady = true; root.settle() } }

  Process {
    id: reader
    command: [root.picker, "--json"]
    property string output: ""
    onStarted: output = ""
    stdout: StdioCollector { onStreamFinished: reader.output = text }
    onExited: function(code) {
      if (root.closed) return
      var rows = []
      try { rows = JSON.parse(output) } catch (e) { root.close(); return }
      if (code !== 0 || !Array.isArray(rows)) { root.close(); return }
      root.windows = root.addresses.map(function(a) {
        return rows.find(function(w) { return w.address === a })
      }).filter(function(w) { return !!w }).map(root.decorate)
      root.loaded = true
      root.settle()
    }
  }

  WindowList {
    id: menu
    onChosen: function(value) { root.finish(value) }
    onCancelled: root.close()
  }
}
