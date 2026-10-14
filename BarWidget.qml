import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "pnkm0nk.omodoro"

  readonly property var service: root.bar && root.bar.shell
    ? root.bar.shell.serviceFor("pnkm0nk.omodoro") : null

  readonly property bool showingSeconds: root.service && root.service.timerRunning && root.service.showSecondsInBar
  readonly property Item activeWidget: showingSeconds ? secondsButton : iconButton

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = activeWidget
    if ("hostWidget" in target) target.hostWidget = root
  }

  onShowingSecondsChanged: injectPanel()

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  // Shape contract for shell.summon/hide/toggle routing (Bar.findPanelWidget
  // requires open/close/opened on the bar-widget root). Open maps to the
  // panel's hotkey path so summoning suppresses the center hover reveal,
  // matching what the old per-plugin IpcHandler did.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  function getIconForegroundColor() {
    if (!root.service || !root.service.timerRunning) return root.bar ? root.bar.barForeground : Color.foreground
    switch (root.service.currentMode) {
      case "work": return root.bar ? root.bar.urgent : Color.urgent
      case "shortBreak":
      case "longBreak": return Color.accent
      default: return root.bar ? root.bar.barForeground : Color.foreground
    }
  }

  // Forwarded so this widget can stand in for the panel as the bar's popout
  // identity: Bar.requestPopout prefers closeForPopoutSwitch over close, and
  // KeyboardPanel reads popoutSwitchClosing back off its owner.
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  visible: panelLoader.item && root.service && root.service.label !== ""
  implicitWidth: activeWidget ? activeWidget.implicitWidth : 0
  implicitHeight: activeWidget ? activeWidget.implicitHeight : 0

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: iconButton
    anchors.fill: parent
    visible: !root.showingSeconds
    bar: root.bar
    text: root.service ? root.service.label : ""
    foreground: root.getIconForegroundColor()
    slotSize: Style.bar.statusSlot
    tooltipText: "Omodoro"

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }
  }

  WidgetButton {
    id: secondsButton
    anchors.fill: parent
    visible: root.showingSeconds
    bar: root.bar
    // Hidden label exists only to drive implicitWidth, so the bar reflows
    // neighboring widgets as the countdown text changes width.
    text: root.service ? root.service.label : ""
    labelVisible: false
    hasVisualContent: text !== ""
    horizontalMargin: 4
    tooltipText: "Omodoro"

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }

    Row {
      anchors.centerIn: parent

      Text {
        text: "["
        font.family: secondsButton.fontFamily
        font.pixelSize: Style.bar.iconFont
        color: secondsButton.foreground
        renderType: Text.NativeRendering
      }
      Text {
        text: root.service ? root.service.label.slice(1, -1) : ""
        font.family: secondsButton.fontFamily
        font.pixelSize: Style.bar.iconFont
        color: root.getIconForegroundColor()
        renderType: Text.NativeRendering
      }
      Text {
        text: "]"
        font.family: secondsButton.fontFamily
        font.pixelSize: Style.bar.iconFont
        color: secondsButton.foreground
        renderType: Text.NativeRendering
      }
    }
  }
}
