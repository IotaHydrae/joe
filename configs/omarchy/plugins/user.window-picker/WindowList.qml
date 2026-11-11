pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import qs.Commons as Commons
import qs.Ui

// A window-only picker: app icons and desktop names come from the caller's
// local application library; choosing a row never launches or removes an app.
Item {
  id: root

  property bool opened: false
  property int selectedIndex: 0
  property string filterText: ""
  property var rows: []
  readonly property string genericIcon: Quickshell.iconPath("application-x-executable", true)
  readonly property int rowHeight: Commons.Style.space(64)
  readonly property int rowSpacing: Commons.Style.spacing.xs
  readonly property int headerHeight: Commons.Style.space(32)
  readonly property var filteredRows: {
    var query = filterText.trim().toLowerCase()
    if (!query) return rows
    return rows.filter(function(row) {
      return [row.label, row.detail, row.appId, row.initialAppId, row.desktopId]
        .join(" ").toLowerCase().indexOf(query) >= 0
    })
  }

  signal chosen(string value)
  signal cancelled()
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  function keepSelectionVisible() {
    Qt.callLater(function() {
      if (root.opened && root.filteredRows.length > 0)
        resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    })
  }

  function openWindows(windows) {
    rows = Array.isArray(windows) ? windows.slice(0, 500) : []
    filterText = ""
    selectedIndex = 0
    pointerGate.reset()
    opened = true
    resultList.positionViewAtBeginning()
  }

  function select(delta) {
    var count = filteredRows.length
    if (!count) return
    selectedIndex = ((selectedIndex + delta) % count + count) % count
    pointerGate.reset()
    keepSelectionVisible()
  }

  function activateIndex(index) {
    if (!opened || index < 0 || index >= filteredRows.length) return
    var value = filteredRows[index].value
    opened = false
    chosen(value)
  }

  function cancel() {
    if (!opened) return
    opened = false
    cancelled()
  }

  onOpenedChanged: {
    pointerGate.reset()
    if (opened) Qt.callLater(function() {
      if (root.opened) filterInput.forceActiveFocus()
    })
  }
  onFilterTextChanged: {
    if (filterInput.text !== filterText) filterInput.text = filterText
    selectedIndex = 0
    pointerGate.reset()
    keepSelectionVisible()
  }

  PointerMoveGate { id: pointerGate; referenceItem: card }

  OverlayWindow {
    id: panel
    shown: root.opened
    WlrLayershell.namespace: "omarchy-window-picker"
    onContentRevealedChanged: if (contentRevealed && root.opened) filterInput.forceActiveFocus()

    Rectangle { anchors.fill: parent; color: Commons.Color.menu.scrim }
    MouseArea { anchors.fill: parent; onClicked: root.cancel() }

    BorderSurface {
      id: card
      readonly property real bodyHeight: Math.max(root.rowHeight,
        root.filteredRows.length * (root.rowHeight + root.rowSpacing) - root.rowSpacing)
      width: Math.max(1, Math.min(Commons.Style.space(640), panel.width - 2 * Commons.Style.gapsOut))
      height: Math.max(1, Math.min(Commons.Style.space(620), panel.height - 2 * Commons.Style.gapsOut,
        contentTopInset + contentBottomInset + root.headerHeight + Commons.Style.spacing.md + bodyHeight))
      anchors.centerIn: parent
      color: Commons.Color.menu.background
      borderSpec: Commons.Border.surfaceSpec("menu", "border", Commons.Color.menu.border,
        Math.max(1, Commons.Style.space(2)))
      padding: Commons.Style.spacing.panelPadding
      radius: Commons.Style.cornerRadius

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (root.filterText) root.filterText = ""
            else root.cancel()
          }
          else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) root.select(-1)
          else if (event.key === Qt.Key_Down) root.select(1)
          else if (event.key === Qt.Key_Tab) root.select(event.modifiers & Qt.ShiftModifier ? -1 : 1)
          else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.activateIndex(root.selectedIndex)
          else return
          event.accepted = true
        }
      }

      Item {
        id: content
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset

        Item {
          id: filterHeader
          width: parent.width
          height: root.headerHeight

          FilterInput {
            id: filterInput
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            keyHandler: keyCatcher
            color: Commons.Color.menu.text
            font.family: Commons.Style.font.menuFamily
            font.pixelSize: Commons.Style.font.heading
            onTextChanged: if (text !== root.filterText) root.filterText = text
          }

          Text {
            textFormat: Text.PlainText
            anchors.fill: filterInput
            visible: !root.filterText && !filterInput.preeditText
            text: strings.t("searchWindows")
            color: Commons.Color.menu.text
            opacity: 0.58
            font.family: Commons.Style.font.menuFamily
            font.pixelSize: Commons.Style.font.heading
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
          }
        }

        ListView {
          id: resultList
          anchors.top: filterHeader.bottom
          anchors.topMargin: Commons.Style.spacing.md
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          model: root.filteredRows
          spacing: root.rowSpacing
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          delegate: BorderSurface {
            id: row
            required property int index
            required property var modelData
            readonly property bool selected: index === root.selectedIndex
            width: ListView.view.width
            height: root.rowHeight
            color: selected ? Commons.Color.menu.selectedBackground : "transparent"
            borderSpec: selected ? Commons.Border.surfaceSpec("menu", "selected-border",
              Commons.Color.menu.selectedBorder, 0) : Commons.Border.none()
            radius: Commons.Style.cornerRadius

            Image {
              id: appIcon
              property bool failed: false
              width: Commons.Style.space(32)
              height: width
              anchors.left: parent.left
              anchors.leftMargin: Commons.Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              source: failed ? root.genericIcon : (row.modelData.iconSource || root.genericIcon)
              sourceSize.width: width * Screen.devicePixelRatio
              sourceSize.height: height * Screen.devicePixelRatio
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              onStatusChanged: if (status === Image.Error) failed = true
            }

            Text {
              textFormat: Text.PlainText
              anchors.fill: appIcon
              visible: appIcon.status === Image.Error || appIcon.status === Image.Null
              text: "▣"
              color: row.selected ? Commons.Color.menu.selectedText : Commons.Color.menu.text
              font.pixelSize: Commons.Style.space(28)
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }

            Column {
              anchors.left: appIcon.right
              anchors.leftMargin: Commons.Style.space(12)
              anchors.right: parent.right
              anchors.rightMargin: Commons.Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Commons.Style.spacing.xs

              Text {
                textFormat: Text.PlainText
                width: parent.width
                text: row.modelData.label || ""
                color: row.selected ? Commons.Color.menu.selectedText : Commons.Color.menu.text
                font.family: Commons.Style.font.menuFamily
                font.pixelSize: Commons.Style.font.heading
                font.weight: Font.Medium
                elide: Text.ElideRight
              }
              Text {
                textFormat: Text.PlainText
                width: parent.width
                text: row.modelData.detail || ""
                visible: text.length > 0
                color: row.selected ? Commons.Color.menu.selectedText : Commons.Color.menu.text
                opacity: 0.58
                font.family: Commons.Style.font.menuFamily
                font.pixelSize: Commons.Style.font.bodySmall
                elide: Text.ElideRight
              }
            }

            MouseArea {
              id: rowMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: {
                if (pointerGate.moved(row, {x: mouseX, y: mouseY})) root.selectedIndex = row.index
              }
              onPositionChanged: function(mouse) {
                if (pointerGate.moved(row, mouse)) root.selectedIndex = row.index
              }
              onClicked: root.activateIndex(row.index)
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          anchors.centerIn: resultList
          width: resultList.width
          visible: root.filteredRows.length === 0
          text: strings.t("noWindows")
          color: Commons.Color.menu.text
          opacity: 0.58
          font.family: Commons.Style.font.menuFamily
          font.pixelSize: Commons.Style.font.heading
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
        }
      }
    }
  }
}
