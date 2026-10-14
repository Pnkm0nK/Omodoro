import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "pnkm0nk.omodoro"
  ipcTarget: "pnkm0nk.omodoro"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property var service: root.bar && root.bar.shell
    ? root.bar.shell.serviceFor("pnkm0nk.omodoro") : null

  function open() { root.controller.show() }
  function openFromHotkey() { root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(contentLoader.item ? contentLoader.item.implicitHeight : Style.space(300), Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: contentLoader.item ? contentLoader.item.taskInputActive : false
      onCloseRequested: root.close()
      onActivateRequested: if (root.service) root.service.timerRunning = !root.service.timerRunning
      onTextKey: function(t) {
        if (!root.service) return
        if (t === "r" || t === "R") {
          root.service.timeLeft = root.service.getTimeForMode(root.service.currentMode)
        } else if (t === "n" || t === "N") {
          root.service.nextMode()
        } else if (t === "+" || t === "=") {
          root.service.timeLeft += 60
        } else if (t === "-" || t === "_") {
          root.service.timeLeft = Math.max(0, root.service.timeLeft - 60)
        }
      }


      Loader {
        // this loader ensures service is instantiated
        // to prevent checking it's presence
        // at every call
        id: contentLoader
        anchors.fill: parent
        active: Boolean(root.service)
        sourceComponent: panelContent
      }
    }
  }

  Component {
    id: panelContent

    Flickable {
      id: mainScroll
      implicitHeight: mainColumn.implicitHeight
      contentWidth: width
      contentHeight: mainColumn.implicitHeight
      clip: interactive
      boundsBehavior: Flickable.StopAtBounds
      interactive: (contentHeight > height) && !root.service.isDraggingTask

      readonly property bool taskInputActive: taskNameField && taskNameField.activeFocus

      Column {
        id: mainColumn
        width: mainScroll.width
        spacing: Style.space(4)

        // header + stats and settings buttons
        Item {
          width: parent.width
          height: headerRow.implicitHeight + Style.space(8)

          Row {
            id: headerRow
            anchors.left: parent.left
            anchors.leftMargin: Style.space(16)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)

            Text {
              text: "\ue001"
              color: root.bar ? root.bar.foreground : Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.heading
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: "Omodoro"
              color: root.bar ? root.bar.foreground : Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.heading
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Row {
            anchors.right: parent.right
            anchors.rightMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            Button {
              iconText: root.service.showStats ? "\uf00d" : "\uebe2"
              tooltipText: root.service.showStats ? "Back to timer" : "Statistics"
              foreground: root.bar ? root.bar.foreground : Color.foreground
              onClicked: {
                if (root.service.showStats) {
                  root.service.showStats = false
                } else {
                  root.service.showStats = true
                  root.service.showSettings = false
                }
              }
            }

            Button {
              iconText: root.service.showSettings ? "\uf00d" : "\ueb52"
              tooltipText: root.service.showSettings ? "Back to timer" : "Settings"
              foreground: root.bar ? root.bar.foreground : Color.foreground
              onClicked: {
                if (root.service.showSettings) {
                  root.service.showSettings = false
                } else {
                  root.service.showSettings = true
                  root.service.showStats = false
                }
              }
            }
          }
        }

        PanelSeparator { foreground: root.bar ? root.bar.foreground : Color.foreground }

        Column {
          id: timerView
          visible: !root.service.showSettings && !root.service.showStats
          width: parent.width
          spacing: Style.space(8)

          // the clock itself
          Column {
            width: parent.width

            Item {
              width: parent.width
              height: timerColumn.implicitHeight + Style.space(16)

              Column {
                id: timerColumn
                anchors.centerIn: parent

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: root.service.getLogoForMode(root.service.currentMode)
                  color: root.bar ? root.bar.foreground : Color.foreground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.display
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: root.service.format_time(root.service.timeLeft)
                  color: root.bar ? root.bar.foreground : Color.foreground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: 48
                  font.bold: true
                }
              }
            }

            Item {
              width: parent.width
              height: Style.space(8)

              Rectangle {
                id: progressTrack
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Style.space(24)
                anchors.rightMargin: Style.space(24)
                anchors.verticalCenter: parent.verticalCenter
                height: Style.space(4)
                radius: height / 2
                color: root.bar ? Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.15) : Qt.rgba(1, 1, 1, 0.15)

                Rectangle {
                  id: progressFill
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  height: parent.height
                  radius: parent.radius
                  color: root.bar ? root.bar.foreground : Color.foreground
                  width: {
                    var total = root.service.getTimeForMode(root.service.currentMode)
                    if (total <= 0) return 0
                    return parent.width * (1.0 - root.service.timeLeft / total)
                  }

                  Behavior on width {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                  }
                }
              }
            }
          }
          // message about pomodoro(either task, or just a slogan)
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            width: parent.width - Style.space(16)
            text: root.service.getMessageForMode(root.service.currentMode)
            color: root.bar ? Qt.darker(root.bar.foreground, 1.3) : Color.muted
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }
          // controls
          Item {
            width: parent.width
            height: controlsRow.implicitHeight

            Row {
              id: controlsRow
              anchors.centerIn: parent
              spacing: Style.space(6)

              Button {
                iconText: "\uf1da"
                tooltipText: "Reset"
                foreground: root.bar ? root.bar.foreground : Color.foreground
                onClicked: root.service.timeLeft = root.service.getTimeForMode(root.service.currentMode)
              }
              Button {
                iconText: root.service.timerRunning ? "\uead1" : "\ueb2c"
                tooltipText: root.service.timerRunning ? "Pause" : "Start"
                foreground: root.bar ? root.bar.foreground : Color.foreground
                onClicked: root.service.timerRunning = !root.service.timerRunning
              }
              Button {
                iconText: "\udb83\udf27"
                tooltipText: "Skip"
                foreground: root.bar ? root.bar.foreground : Color.foreground
                onClicked: root.service.nextMode()
              }
              Button {
                text: "+1m"
                tooltipText: "Add 1 minute"
                foreground: root.bar ? root.bar.foreground : Color.foreground
                onClicked: root.service.timeLeft += 60
              }
            }
          }
          // dots: num of pomos until long break
          Item {
            width: parent.width
            height: dotsRow.implicitHeight

            Row {
              id: dotsRow
              anchors.centerIn: parent
              spacing: Style.space(6)

              Repeater {
                model: root.service.longBreakInterval

                Rectangle {
                  required property int index
                  width: Style.space(8)
                  height: Style.space(8)
                  radius: width / 2
                  color: index < (root.service.completedSessions % root.service.longBreakInterval)
                    ? (root.bar ? root.bar.foreground : Color.foreground)
                    : "transparent"
                  border.color: root.bar ? root.bar.foreground : Color.foreground
                  border.width: 1
                }
              }
            }
          }

          PanelSeparator { foreground: root.bar ? root.bar.foreground : Color.foreground }

          Item {
            width: parent.width
            height: taskHeaderRow.implicitHeight

            Row {
              id: taskHeaderRow
              anchors.left: parent.left
              anchors.leftMargin: Style.space(16)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(8)

              PanelSectionHeader {
                text: "TASKS"
                foreground: root.bar ? root.bar.foreground : Color.foreground
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Button {
              anchors.right: parent.right
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              iconText: root.service.showTasks ? "\ueaa1" : "\uea9a"
              foreground: root.bar ? root.bar.foreground : Color.foreground
              onClicked: root.service.showTasks = !root.service.showTasks
            }
          }
          Column {
            id: taskDrawerColumn
            width: parent.width
            visible: root.service.showTasks
            spacing: Style.space(8)

            ListView {
              id: taskDrawer
              width: parent.width
              height: Math.min(contentHeight, Style.space(150))
              clip: true
              interactive: !root.service.isDraggingTask
              model: root.service.taskModel

              delegate: Item {
                id: delegateRoot
                required property string name
                required property int completed
                required property int estimated
                required property int index
                width: taskDrawer.width
                height: Math.max(taskRow.implicitHeight, Style.space(36))
                z: dragArea.drag.active ? 100 : 1

                Item {
                  id: taskRowWrapper
                  width: parent.width
                  height: parent.height

                  Rectangle {
                    anchors.fill: parent
                    color: dragArea.drag.active
                      ? (root.bar ? Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.15) : Qt.rgba(1, 1, 1, 0.15))
                      : (dragArea.containsMouse ? (root.bar ? Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.05) : Qt.rgba(1, 1, 1, 0.05)) : "transparent")
                    radius: Style.space(4)
                    border.color: dragArea.drag.active ? (root.bar ? root.bar.foreground : Color.foreground) : "transparent"
                    border.width: dragArea.drag.active ? 1 : 0
                  }

                  MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    anchors.rightMargin: Style.space(70)
                    hoverEnabled: true
                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: taskRowWrapper
                    drag.axis: Drag.YAxis

                    onPressed: root.service.isDraggingTask = true

                    onPositionChanged: {
                      if (drag.active) {
                        var currentY = delegateRoot.y + taskRowWrapper.y + delegateRoot.height / 2
                        var targetIdx = Math.floor(currentY / delegateRoot.height)
                        targetIdx = Math.max(0, Math.min(root.service.taskModel.count - 1, targetIdx))
                        if (targetIdx !== index) {
                          root.service.taskModel.move(index, targetIdx, 1)
                          root.service.updateCurrentTask()
                          root.service.saveState()
                        }
                      }
                    }

                    onReleased: {
                      root.service.isDraggingTask = false
                      taskRowWrapper.y = 0
                    }

                    onCanceled: {
                      root.service.isDraggingTask = false
                      taskRowWrapper.y = 0
                    }
                  }

                  Row {
                    id: taskRow
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(12)
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(12)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(8)

                    Text {
                      text: "⠿"
                      color: root.bar ? Qt.darker(root.bar.foreground, 1.5) : Color.muted
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.body
                      anchors.verticalCenter: parent.verticalCenter
                      anchors.verticalCenterOffset: Style.space(2)
                    }

                    Text {
                      text: name
                      color: root.bar ? root.bar.foreground : Color.foreground
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.body
                      elide: Text.ElideRight
                      width: parent.width - taskProgress.width - taskIncBtn.width - taskDelBtn.width - Style.space(34) - parent.spacing * 4
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Item{
                      width: completedCheckmark.implicitWidth
                      height: completedCheckmark.implicitHeight

                      Text{
                        id: completedCheckmark
                        text: ("\uf00c")
                        visible: completed === estimated
                        color: Color.accent
                      }
                    }

                    Text {
                      id: taskProgress
                      text: completed + "/" + estimated
                      color: root.bar ? Qt.darker(root.bar.foreground, 1.4) : Color.muted
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.bodySmall
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    PanelActionButton {
                      id: taskIncBtn
                      iconText: "\uf067"
                      foreground: root.bar ? root.bar.foreground : Color.foreground
                      anchors.verticalCenter: parent.verticalCenter
                      enabled: completed < estimated
                      onClicked: root.service.incrementTask(index)
                    }

                    PanelActionButton {
                      id: taskDelBtn
                      iconText: "✕"
                      foreground: root.bar ? root.bar.foreground : Color.foreground
                      hoverColor: Color.urgent
                      anchors.verticalCenter: parent.verticalCenter
                      onClicked: root.service.removeTask(index)
                    }
                  }
                }
              }
            }

            Item {
              width: parent.width
              height: addTaskRow.implicitHeight + Style.space(8)

              Row {
                id: addTaskRow
                anchors.left: parent.left
                anchors.leftMargin: Style.space(16)
                anchors.right: parent.right
                anchors.rightMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(8)

                TextField {
                  id: taskNameField
                  width: parent.width - taskEstField.width - addTaskBtn.width - parent.spacing * 3
                  placeholderText: "New task..."
                  foreground: root.bar ? root.bar.foreground : Color.foreground
                  Keys.onReturnPressed: {
                    root.service.addTask(taskNameField.text, taskEstField.value)
                    taskNameField.text = ""
                  }
                  Keys.onEnterPressed: {
                    root.service.addTask(taskNameField.text, taskEstField.value)
                    taskNameField.text = ""
                  }
                  Keys.onEscapePressed: function(event) {
                    taskNameField.focus = false
                    keyCatcher.forceActiveFocus()
                    if (event) event.accepted = true
                  }
                }

                NumberField {
                  id: taskEstField
                  label: ""
                  value: 4
                  from: 1
                  to: 20
                  foreground: root.bar ? root.bar.foreground : Color.foreground
                  fieldWidth: Style.space(56)
                  onModified: function(v) { value = v }
                }

                Button {
                  id: addTaskBtn
                  iconText: "\uf067"
                  tooltipText: "Add task"
                  foreground: root.bar ? root.bar.foreground : Color.foreground
                  anchors.verticalCenter: parent.verticalCenter
                  onClicked: {
                    root.service.addTask(taskNameField.text, taskEstField.value)
                    taskNameField.text = ""
                  }
                }
              }
            }
          }
        }

        // ----------- STATISTICS VIEW -----------
        Column {
          id: statsView
          visible: root.service.showStats
          width: parent.width
          spacing: Style.space(12)

          PanelSectionHeader {
            text: "STATISTICS"
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            leftPadding: Style.space(16)
          }

          Item {
            width: parent.width
            height: statsRow.implicitHeight

            Row {
              id: statsRow
              anchors.left: parent.left
              anchors.leftMargin: Style.space(16)
              anchors.right: parent.right
              anchors.rightMargin: Style.space(16)
              spacing: Style.space(20)

              Column {
                spacing: Style.space(2)
                Text {
                  text: "TODAY"
                  color: root.bar ? Qt.darker(root.bar.foreground, 1.5) : Color.muted
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
                Text {
                  text: root.service.todayPomodoros + " \ue001 (" + root.service.todayFocusMinutes + "m)"
                  color: root.bar ? root.bar.foreground : Color.foreground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
              }

              Column {
                spacing: Style.space(2)
                Text {
                  text: "ALL TIME"
                  color: root.bar ? Qt.darker(root.bar.foreground, 1.5) : Color.muted
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
                Text {
                  text: root.service.totalPomodoros + " (" + Math.round(root.service.totalFocusMinutes / 60) + "h)"
                  color: root.bar ? root.bar.foreground : Color.foreground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
              }

              Column {
                spacing: Style.space(2)
                Text {
                  text: "STREAK"
                  color: root.bar ? Qt.darker(root.bar.foreground, 1.5) : Color.muted
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
                Text {
                  text: root.service.streakDays + " \udb80\ude38"
                  color: root.bar ? root.bar.foreground : Color.foreground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
              }
            }
          }

          Item {
            width: parent.width
            height: resetStatsBtn.implicitHeight + Style.space(4)

            Button {
              id: resetStatsBtn
              anchors.left: parent.left
              anchors.leftMargin: Style.space(16)
              text: "Reset statistics"
              iconText: "\uf1da"
              foreground: root.bar ? root.bar.foreground : Color.foreground
              onClicked: root.service.resetStats()
            }
          }
        }

        // ----------- SETTINGS VIEW -----------
        Column {
          id: settingsView
          visible: root.service.showSettings
          width: parent.width
          spacing: Style.space(12)

          PanelSectionHeader {
            text: "PRESET"
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            leftPadding: Style.space(16)
          }

          Item {
            width: parent.width
            height: presetGroup.implicitHeight

            ButtonGroup {
              id: presetGroup
              anchors.horizontalCenter: parent.horizontalCenter
              foreground: root.bar ? root.bar.foreground : Color.foreground
              value: root.service.selectedPreset
              options: [
                { value: "classic", label: "25/5/15" },
                { value: "long",    label: "50/10/30" },
                { value: "short",   label: "15/3/10" },
                { value: "custom",  label: "Custom" }
              ]
              onChanged: function(v) {
                root.service.applyPreset(v)
              }
            }
          }

          Column {
            visible: root.service.selectedPreset === "custom"
            width: parent.width
            spacing: Style.space(10)
            leftPadding: Style.space(16)

            PanelSectionHeader {
              text: "CUSTOM DURATIONS"
              foreground: root.bar ? root.bar.foreground : Color.foreground
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            }

            Row {
              spacing: Style.space(16)

              NumberField {
                label: "Work (min)"
                value: Math.round(root.service.workTime / 60)
                from: 1
                to: 120
                foreground: root.bar ? root.bar.foreground : Color.foreground
                fieldWidth: Style.space(70)
                onModified: function(v) {
                  root.service.workTime = v * 60
                  if (!root.service.timerRunning && root.service.currentMode === "work") {
                    root.service.timeLeft = root.service.workTime
                  }
                  root.service.saveState()
                }
              }

              NumberField {
                label: "Short (min)"
                value: Math.round(root.service.shortBreakTime / 60)
                from: 1
                to: 30
                foreground: root.bar ? root.bar.foreground : Color.foreground
                fieldWidth: Style.space(70)
                onModified: function(v) {
                  root.service.shortBreakTime = v * 60
                  if (!root.service.timerRunning && root.service.currentMode === "shortBreak") {
                    root.service.timeLeft = root.service.shortBreakTime
                  }
                  root.service.saveState()
                }
              }

              NumberField {
                label: "Long (min)"
                value: Math.round(root.service.longBreakTime / 60)
                from: 1
                to: 60
                foreground: root.bar ? root.bar.foreground : Color.foreground
                fieldWidth: Style.space(70)
                onModified: function(v) {
                  root.service.longBreakTime = v * 60
                  if (!root.service.timerRunning && root.service.currentMode === "longBreak") {
                    root.service.timeLeft = root.service.longBreakTime
                  }
                  root.service.saveState()
                }
              }
            }
          }

          PanelSeparator { foreground: root.bar ? root.bar.foreground : Color.foreground }

          Item {
            width: parent.width
            height: intervalField.implicitHeight

            NumberField {
              id: intervalField
              anchors.left: parent.left
              anchors.leftMargin: Style.space(16)
              label: "Sessions before long break"
              value: root.service.longBreakInterval
              from: 1
              to: 10
              foreground: root.bar ? root.bar.foreground : Color.foreground
              fieldWidth: Style.space(70)
              onModified: function(v) {
                root.service.longBreakInterval = v
                root.service.saveState()
              }
            }
          }

          PanelSeparator { foreground: root.bar ? root.bar.foreground : Color.foreground }

          PanelSectionHeader {
            text: "TOGGLES"
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            leftPadding: Style.space(16)
          }

          Column {
            width: parent.width - Style.space(32)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(6)

            Toggle {
              width: parent.width
              label: "Auto-start work"
              description: "Automatically begin work sessions after breaks"
              checked: root.service.autoStartWork
              foreground: root.bar ? root.bar.foreground : Color.foreground
              onClicked: {
                root.service.autoStartWork = !root.service.autoStartWork
                root.service.saveState()
              }
            }

            Toggle {
              width: parent.width
              label: "Auto-start breaks"
              description: "Automatically begin breaks after work sessions"
              checked: root.service.autoStartBreak
              foreground: root.bar ? root.bar.foreground : Color.foreground
              onClicked: {
                root.service.autoStartBreak = !root.service.autoStartBreak
                root.service.saveState()
              }
            }

            Toggle {
              width: parent.width
              label: "Notifications"
              description: "Notify when work sessions and breaks finish"
              checked: root.service.notificationsEnabled
              foreground: root.bar ? root.bar.foreground : Color.foreground
              onClicked: {
                root.service.notificationsEnabled = !root.service.notificationsEnabled
                root.service.saveState()
              }
            }

            Toggle {
              width: parent.width
              label: "Double digit timer in bar"
              description: "Display [mm:ss] countdown on the bar instead of just minutes"
              checked: root.service.showSecondsInBar
              foreground: root.bar ? root.bar.foreground : Color.foreground
              onClicked: {
                root.service.showSecondsInBar = !root.service.showSecondsInBar
                root.service.saveState()
              }
            }
          }

          PanelSeparator { foreground: root.bar ? root.bar.foreground : Color.foreground }

          Item {
            id: soundHeader
            width: parent.width - Style.space(32)
            anchors.horizontalCenter: parent.horizontalCenter
            height: Math.max(soundSectionTitle.implicitHeight, Style.space(24))

            PanelSectionHeader {
              id: soundSectionTitle
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "SOUND"
              foreground: soundHeaderMouse.containsMouse
                ? (root.bar ? root.bar.foreground : Color.foreground)
                : (root.bar ? Qt.darker(root.bar.foreground, 1.2) : Color.muted)
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            }

            Text {
              id: soundChevron
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: root.service.showSoundSettings ? "󰅀" : "󰅂"
              color: soundHeaderMouse.containsMouse
                ? (root.bar ? root.bar.foreground : Color.foreground)
                : (root.bar ? Qt.darker(root.bar.foreground, 1.4) : Color.muted)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }

            MouseArea {
              id: soundHeaderMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.service.showSoundSettings = !root.service.showSoundSettings
                root.service.saveState()
              }
            }
          }

          Column {
            id: soundSectionContent
            visible: root.service.showSoundSettings
            width: parent.width - Style.space(32)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(10)

            Toggle {
              width: parent.width
              label: "Sound"
              description: "Play a sound when work sessions and breaks finish"
              checked: root.service.soundEnabled
              foreground: root.bar ? root.bar.foreground : Color.foreground
              onClicked: {
                root.service.soundEnabled = !root.service.soundEnabled
                root.service.saveState()
              }
            }

            Toggle {
              width: parent.width
              label: "Ticking"
              description: "Play a clock tick every second while the timer runs"
              checked: root.service.tickSoundEnabled
              foreground: root.bar ? root.bar.foreground : Color.foreground
              onClicked: {
                root.service.tickSoundEnabled = !root.service.tickSoundEnabled
                root.service.saveState()
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(6)

              Text {
                text: "Tick sound"
                color: root.bar ? root.bar.foreground : Color.foreground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.bodySmall
              }

              Row {
                spacing: Style.space(8)

                ButtonGroup {
                  id: tickSoundGroup
                  foreground: root.bar ? root.bar.foreground : Color.foreground
                  value: root.service.tickSoundId
                  options: root.service.tickOptions.map(function(o) { return { value: o.id, label: o.label } })
                  onChanged: function(v) {
                    root.service.tickSoundId = v
                    root.service.saveState()
                  }
                }

                Button {
                  iconText: ""
                  foreground: root.bar ? root.bar.foreground : Color.foreground
                  tooltipText: "Preview"
                  onClicked: root.service.previewTick()
                }
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(6)

              Text {
                text: "Break sound"
                color: root.bar ? root.bar.foreground : Color.foreground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.bodySmall
              }

              Row {
                spacing: Style.space(8)

                ButtonGroup {
                  id: breakSoundGroup
                  foreground: root.bar ? root.bar.foreground : Color.foreground
                  value: root.service.breakSoundId
                  options: root.service.soundOptions.map(function(o) { return { value: o.id, label: o.label } })
                  onChanged: function(v) {
                    root.service.breakSoundId = v
                    root.service.saveState()
                  }
                }

                Button {
                  iconText: ""
                  foreground: root.bar ? root.bar.foreground : Color.foreground
                  tooltipText: "Preview"
                  onClicked: root.service.previewSound(root.service.breakSoundId)
                }
              }

              Text {
                text: "Back-to-work sound"
                color: root.bar ? root.bar.foreground : Color.foreground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.bodySmall
                topPadding: Style.space(6)
              }

              Row {
                spacing: Style.space(8)

                ButtonGroup {
                  id: workSoundGroup
                  foreground: root.bar ? root.bar.foreground : Color.foreground
                  value: root.service.workSoundId
                  options: root.service.soundOptions.map(function(o) { return { value: o.id, label: o.label } })
                  onChanged: function(v) {
                    root.service.workSoundId = v
                    root.service.saveState()
                  }
                }

                Button {
                  iconText: ""
                  foreground: root.bar ? root.bar.foreground : Color.foreground
                  tooltipText: "Preview"
                  onClicked: root.service.previewSound(root.service.workSoundId)
                }
              }
            }
          }

          PanelSeparator { foreground: root.bar ? root.bar.foreground : Color.foreground }

          Item {
            id: shortcutsHeader
            width: parent.width - Style.space(32)
            anchors.horizontalCenter: parent.horizontalCenter
            height: Math.max(shortcutsSectionTitle.implicitHeight, Style.space(24))

            PanelSectionHeader {
              id: shortcutsSectionTitle
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "KEYBOARD SHORTCUTS"
              foreground: shortcutsHeaderMouse.containsMouse
                ? (root.bar ? root.bar.foreground : Color.foreground)
                : (root.bar ? Qt.darker(root.bar.foreground, 1.2) : Color.muted)
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            }

            Text {
              id: shortcutsChevron
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: root.service.showShortcuts ? "󰅀" : "󰅂"
              color: shortcutsHeaderMouse.containsMouse
                ? (root.bar ? root.bar.foreground : Color.foreground)
                : (root.bar ? Qt.darker(root.bar.foreground, 1.4) : Color.muted)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }

            MouseArea {
              id: shortcutsHeaderMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.service.showShortcuts = !root.service.showShortcuts
                root.service.saveState()
              }
            }
          }

          Column {
            visible: root.service.showShortcuts
            width: parent.width - Style.space(32)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(6)

            Repeater {
              model: [
                { key: "Space / Enter", desc: "Start / Pause timer" },
                { key: "R", desc: "Reset current session" },
                { key: "N", desc: "Skip to next session" },
                { key: "+ / -", desc: "Add / subtract 1 minute" },
                { key: "Esc", desc: "Close panel" }
              ]

              Item {
                required property var modelData
                width: parent.width
                height: Style.space(12)

                Text {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.key
                  color: root.bar ? root.bar.foreground : Color.foreground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }

                Text {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.desc
                  color: root.bar ? Qt.darker(root.bar.foreground, 1.4) : Color.muted
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }
          }

          Item {
            width: parent.width
            height: Style.space(8)
          }
        }
      }
    }
  }
}