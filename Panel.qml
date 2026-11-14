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
    contentHeight: panel.fittedContentHeight(contentLoader.item ? contentLoader.item.implicitHeight : Style.space(300), Style.space(580))

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
          Item {
            id: timerMessageContainer
            width: parent.width - Style.space(24)
            anchors.horizontalCenter: parent.horizontalCenter
            height: timerMessageRow.implicitHeight

            readonly property var activeParsedTask: (root.service.currentMode === "work" && root.service.currentTask)
              ? root.service.extractTaskTag(root.service.currentTask.name)
              : { tag: "", cleanName: root.service.getMessageForMode(root.service.currentMode) }

            Row {
              id: timerMessageRow
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(6)

              Rectangle {
                id: activeTimerTagPill
                visible: timerMessageContainer.activeParsedTask.tag !== ""
                height: activeTimerTagText.implicitHeight + Style.space(4)
                width: visible ? (activeTimerTagText.implicitWidth + Style.space(10)) : 0
                radius: Style.space(4)
                color: Util.alpha(Color.accent, 0.18)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  id: activeTimerTagText
                  anchors.centerIn: parent
                  text: timerMessageContainer.activeParsedTask.tag
                  color: Color.accent
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }

              Text {
                id: timerMessageText
                width: Math.min(
                  implicitWidth,
                  timerMessageContainer.width - (activeTimerTagPill.visible ? activeTimerTagPill.width + timerMessageRow.spacing : 0)
                )
                horizontalAlignment: Text.AlignHCenter
                text: timerMessageContainer.activeParsedTask.cleanName
                color: root.bar ? Qt.darker(root.bar.foreground, 1.3) : Color.muted
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                elide: Text.ElideRight
                font.pixelSize: Style.font.subtitle
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            MouseArea {
              id: timerMessageMouse
              anchors.fill: timerMessageRow
              hoverEnabled: true
              acceptedButtons: Qt.NoButton
            }

            PanelToolTip {
              visible: timerMessageMouse.containsMouse && timerMessageText.truncated
              text: timerMessageContainer.activeParsedTask.cleanName
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            }
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
                required property bool done
                required property int index
                width: taskDrawer.width
                height: Math.max(taskRow.implicitHeight, Style.space(36))
                z: dragArea.drag.active ? 100 : 1

                readonly property var parsedTask: root.service.extractTaskTag(name)

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
                    anchors.leftMargin: Style.space(36)
                    anchors.rightMargin: Style.space(76)
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
                    spacing: Style.space(6)

                    Text {
                      text: "⠿"
                      color: root.bar ? Qt.darker(root.bar.foreground, 1.5) : Color.muted
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.body
                      anchors.verticalCenter: parent.verticalCenter
                      anchors.verticalCenterOffset: Style.space(2)
                    }

                    PanelActionButton {
                      id: taskDoneBtn
                      iconText: done ? "\uf00c" : "\uf10c"
                      tooltipText: done ? "Mark incomplete" : "Mark completed"
                      foreground: done
                        ? Color.accent
                        : (root.bar ? Qt.darker(root.bar.foreground, 1.4) : Color.muted)
                      hoverColor: Color.accent
                      anchors.verticalCenter: parent.verticalCenter
                      onClicked: root.service.toggleTaskDone(index)
                    }

                    Rectangle {
                      id: taskTagPill
                      visible: delegateRoot.parsedTask.tag !== ""
                      height: taskTagLabel.implicitHeight + Style.space(4)
                      width: visible ? (taskTagLabel.implicitWidth + Style.space(10)) : 0
                      radius: Style.space(3)
                      color: Util.alpha(Color.accent, 0.16)
                      anchors.verticalCenter: parent.verticalCenter

                      Text {
                        id: taskTagLabel
                        anchors.centerIn: parent
                        text: delegateRoot.parsedTask.tag
                        color: Color.accent
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }
                    }

                    Text {
                      id: taskNameText
                      text: delegateRoot.parsedTask.cleanName
                      color: done
                        ? (root.bar ? Qt.darker(root.bar.foreground, 1.4) : Color.muted)
                        : (root.bar ? root.bar.foreground : Color.foreground)
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.body
                      font.strikeout: done
                      elide: Text.ElideRight
                      width: Math.max(
                        Style.space(40),
                        parent.width - taskDoneBtn.width - (taskTagPill.visible ? taskTagPill.width + parent.spacing : 0) - taskProgress.width - taskIncBtn.width - taskDelBtn.width - Style.space(18) - parent.spacing * 5
                      )
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                      id: taskProgress
                      text: completed + "/" + estimated
                      color: completed > estimated
                        ? Color.urgent
                        : (done ? Color.accent : (root.bar ? Qt.darker(root.bar.foreground, 1.4) : Color.muted))
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.bodySmall
                      font.bold: completed > estimated || done
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    PanelActionButton {
                      id: taskIncBtn
                      iconText: "\uf067"
                      tooltipText: "Log +1 pomodoro"
                      foreground: root.bar ? root.bar.foreground : Color.foreground
                      anchors.verticalCenter: parent.verticalCenter
                      onClicked: root.service.incrementTask(index)
                    }

                    PanelActionButton {
                      id: taskDelBtn
                      iconText: "✕"
                      tooltipText: "Remove from list"
                      foreground: root.bar ? root.bar.foreground : Color.foreground
                      hoverColor: Color.urgent
                      anchors.verticalCenter: parent.verticalCenter
                      onClicked: root.service.removeTask(index)
                    }
                  }

                  PanelToolTip {
                    visible: dragArea.containsMouse && !dragArea.drag.active && taskNameText.truncated
                    text: delegateRoot.parsedTask.cleanName
                    fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
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
                  placeholderText: "New task... (e.g. #dev Fix bug)"
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

          readonly property color fgColor: root.bar ? root.bar.foreground : Color.foreground
          readonly property color mutedColor: root.bar ? Qt.darker(root.bar.foreground, 1.5) : Color.muted
          readonly property string fontFam: root.bar ? root.bar.fontFamily : Style.font.family
          property var hoveredDay: null
          property int hoveredBreakdownIdx: -1
          readonly property var heatmapWeeks: {
            var _ = root.service.historyRevision
            return root.service.getHeatmapWeeks(18)
          }
          readonly property var taskStats: {
            var _ = root.service.historyRevision
            return root.service.getTaskStats()
          }
          readonly property var activeBreakdownRows: {
            var b = statsView.taskStats.breakdown
            if (root.service.breakdownMode === "tags") return b.tags
            return b.tasks
          }

          function segmentColorForIndex(idx) {
            var alphas = [1.0, 0.78, 0.58, 0.42, 0.30, 0.22, 0.16]
            var a = alphas[Math.min(idx, alphas.length - 1)]
            return Util.alpha(Color.accent, a)
          }

          function formatDurationCompact(mins) {
            var m = Math.max(0, Math.round(mins || 0))
            if (m < 60) return m + "m"
            var h = Math.floor(m / 60)
            var rem = m % 60
            return rem > 0 ? (h + "h " + rem + "m") : (h + "h")
          }

          function cellColorForLevel(level, isFuture) {
            if (isFuture) return "transparent"
            switch (level) {
              case 1: return Util.alpha(Color.accent, 0.28)
              case 2: return Util.alpha(Color.accent, 0.50)
              case 3: return Util.alpha(Color.accent, 0.75)
              case 4: return Color.accent
              default: return Util.alpha(statsView.fgColor, 0.08)
            }
          }

          PanelSectionHeader {
            text: "STATISTICS"
            foreground: statsView.fgColor
            fontFamily: statsView.fontFam
            leftPadding: Style.space(16)
          }

          // ----------- MAIN 3 STATS CARDS (TODAY / ALL TIME / STREAK) -----------
          Row {
            id: statsRow
            width: parent.width - Style.space(32)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(8)

            // Card 1: TODAY
            Rectangle {
              width: (parent.width - Style.space(16)) / 3
              height: todayStatCol.implicitHeight + Style.space(16)
              radius: Style.space(6)
              color: root.service.todayPomodoros > 0
                ? Util.alpha(Color.accent, 0.08)
                : Util.alpha(statsView.fgColor, 0.04)
              border.width: 1
              border.color: root.service.todayPomodoros > 0
                ? Util.alpha(Color.accent, 0.28)
                : Util.alpha(statsView.fgColor, 0.10)

              Column {
                id: todayStatCol
                anchors.left: parent.left
                anchors.leftMargin: Style.space(10)
                anchors.right: parent.right
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(3)

                Text {
                  text: "TODAY"
                  color: statsView.mutedColor
                  font.family: statsView.fontFam
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                Row {
                  spacing: Style.space(4)

                  Text {
                    text: String(root.service.todayPomodoros)
                    color: root.service.todayPomodoros > 0 ? Color.accent : statsView.fgColor
                    font.family: statsView.fontFam
                    font.pixelSize: Style.font.heading
                    font.bold: true
                    anchors.baseline: todayGlyph.baseline
                  }

                  Text {
                    id: todayGlyph
                    text: "\ue001"
                    color: root.service.todayPomodoros > 0 ? Color.accent : statsView.mutedColor
                    font.family: statsView.fontFam
                    font.pixelSize: Style.font.body
                  }
                }

                Text {
                  width: parent.width
                  elide: Text.ElideRight
                  text: statsView.formatDurationCompact(root.service.todayFocusMinutes) + " focused"
                  color: statsView.mutedColor
                  font.family: statsView.fontFam
                  font.pixelSize: Style.font.caption
                }
              }
            }

            // Card 2: ALL TIME
            Rectangle {
              width: (parent.width - Style.space(16)) / 3
              height: todayStatCol.implicitHeight + Style.space(16)
              radius: Style.space(6)
              color: Util.alpha(statsView.fgColor, 0.04)
              border.width: 1
              border.color: Util.alpha(statsView.fgColor, 0.10)

              Column {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(10)
                anchors.right: parent.right
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(3)

                Text {
                  text: "ALL TIME"
                  color: statsView.mutedColor
                  font.family: statsView.fontFam
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                Row {
                  spacing: Style.space(4)

                  Text {
                    text: String(root.service.totalPomodoros)
                    color: statsView.fgColor
                    font.family: statsView.fontFam
                    font.pixelSize: Style.font.heading
                    font.bold: true
                    anchors.baseline: allTimeGlyph.baseline
                  }

                  Text {
                    id: allTimeGlyph
                    text: "\ue001"
                    color: statsView.mutedColor
                    font.family: statsView.fontFam
                    font.pixelSize: Style.font.body
                  }
                }

                Text {
                  width: parent.width
                  elide: Text.ElideRight
                  text: statsView.formatDurationCompact(root.service.totalFocusMinutes) + " total"
                  color: statsView.mutedColor
                  font.family: statsView.fontFam
                  font.pixelSize: Style.font.caption
                }
              }
            }

            // Card 3: STREAK
            Rectangle {
              width: (parent.width - Style.space(16)) / 3
              height: todayStatCol.implicitHeight + Style.space(16)
              radius: Style.space(6)
              color: root.service.streakDays > 0
                ? Util.alpha(Color.accent, 0.08)
                : Util.alpha(statsView.fgColor, 0.04)
              border.width: 1
              border.color: root.service.streakDays > 0
                ? Util.alpha(Color.accent, 0.28)
                : Util.alpha(statsView.fgColor, 0.10)

              Column {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(10)
                anchors.right: parent.right
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(3)

                Text {
                  text: "STREAK"
                  color: statsView.mutedColor
                  font.family: statsView.fontFam
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                Row {
                  spacing: Style.space(4)

                  Text {
                    text: String(root.service.streakDays)
                    color: root.service.streakDays > 0 ? Color.accent : statsView.fgColor
                    font.family: statsView.fontFam
                    font.pixelSize: Style.font.heading
                    font.bold: true
                    anchors.baseline: streakGlyph.baseline
                  }

                  Text {
                    id: streakGlyph
                    text: "\udb80\ude38"
                    color: root.service.streakDays > 0 ? Color.accent : statsView.mutedColor
                    font.family: statsView.fontFam
                    font.pixelSize: Style.font.body
                  }
                }

                Text {
                  width: parent.width
                  elide: Text.ElideRight
                  text: root.service.streakDays === 1 ? "day active" : "days active"
                  color: statsView.mutedColor
                  font.family: statsView.fontFam
                  font.pixelSize: Style.font.caption
                }
              }
            }
          }

          PanelSeparator { foreground: statsView.fgColor }

          // ----------- ACTIVITY HEATMAP -----------
          Column {
            id: heatmapSection
            width: parent.width - Style.space(32)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(6)

            readonly property int cellSize: Style.space(13)
            readonly property int cellGap: Style.space(3)
            readonly property int dayLabelWidth: Style.space(26)

            Item {
              width: parent.width
              height: Math.max(heatmapHeaderTitle.implicitHeight, heatmapHoverText.implicitHeight)

              PanelSectionHeader {
                id: heatmapHeaderTitle
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "ACTIVITY"
                foreground: statsView.fgColor
                fontFamily: statsView.fontFam
              }

              Text {
                id: heatmapHoverText
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: {
                  if (!statsView.hoveredDay) return "Last 18 weeks"
                  var d = statsView.hoveredDay
                  return d.label + " · " + d.count + " \ue001 (" + d.minutes + "m)"
                }
                color: statsView.hoveredDay ? statsView.fgColor : statsView.mutedColor
                font.family: statsView.fontFam
                font.pixelSize: Style.font.caption
                font.bold: Boolean(statsView.hoveredDay)
              }
            }

            // Month labels row
            Item {
              width: parent.width
              height: Style.space(14)

              Repeater {
                model: statsView.heatmapWeeks

                Item {
                  required property var modelData
                  required property int index
                  x: heatmapSection.dayLabelWidth + index * (heatmapSection.cellSize + heatmapSection.cellGap)
                  height: parent.height
                  visible: modelData.monthLabel !== ""

                  Text {
                    text: modelData.monthLabel
                    color: statsView.mutedColor
                    font.family: statsView.fontFam
                    font.pixelSize: Style.font.caption
                  }
                }
              }
            }

            // Day labels + Grid
            Row {
              spacing: Style.space(0)

              // Left day-of-week labels (Mon, Wed, Fri)
              Column {
                width: heatmapSection.dayLabelWidth
                spacing: heatmapSection.cellGap

                Repeater {
                  model: ["Mon", "", "Wed", "", "Fri", "", ""]

                  Item {
                    required property string modelData
                    width: heatmapSection.dayLabelWidth
                    height: heatmapSection.cellSize

                    Text {
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData
                      color: statsView.mutedColor
                      font.family: statsView.fontFam
                      font.pixelSize: Style.font.caption
                    }
                  }
                }
              }

              // Week columns
              Row {
                spacing: heatmapSection.cellGap

                Repeater {
                  model: statsView.heatmapWeeks

                  Column {
                    id: weekCol
                    required property var modelData
                    spacing: heatmapSection.cellGap

                    Repeater {
                      model: weekCol.modelData.days

                      Rectangle {
                        id: dayCell
                        required property var modelData
                        width: heatmapSection.cellSize
                        height: heatmapSection.cellSize
                        radius: Style.space(2)
                        color: statsView.cellColorForLevel(modelData.level, modelData.isFuture)
                        border.width: (!modelData.isFuture && (cellMouse.containsMouse || modelData.isToday)) ? 1 : 0
                        border.color: cellMouse.containsMouse
                          ? statsView.fgColor
                          : Util.alpha(statsView.fgColor, 0.55)

                        MouseArea {
                          id: cellMouse
                          anchors.fill: parent
                          hoverEnabled: !dayCell.modelData.isFuture
                          enabled: !dayCell.modelData.isFuture
                          onEntered: statsView.hoveredDay = dayCell.modelData
                          onExited: {
                            if (statsView.hoveredDay && statsView.hoveredDay.date === dayCell.modelData.date) {
                              statsView.hoveredDay = null
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }

            // Legend row (Less [ ][ ][ ][ ][ ] More)
            Item {
              width: parent.width
              height: Style.space(18)

              Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)

                Text {
                  text: "Less"
                  color: statsView.mutedColor
                  font.family: statsView.fontFam
                  font.pixelSize: Style.font.caption
                  anchors.verticalCenter: parent.verticalCenter
                }

                Repeater {
                  model: [0, 1, 2, 3, 4]

                  Rectangle {
                    required property int modelData
                    width: Style.space(10)
                    height: Style.space(10)
                    radius: Style.space(2)
                    color: statsView.cellColorForLevel(modelData, false)
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                Text {
                  text: "More"
                  color: statsView.mutedColor
                  font.family: statsView.fontFam
                  font.pixelSize: Style.font.caption
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }
          }

          PanelSeparator { foreground: statsView.fgColor }

          // ----------- TASK COMPLETION -----------
          Column {
            id: completionSection
            width: parent.width - Style.space(32)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(8)

            Item {
              width: parent.width
              height: Math.max(velocityHeader.implicitHeight, queueBadge.implicitHeight)

              PanelSectionHeader {
                id: velocityHeader
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "TASK VELOCITY"
                foreground: statsView.fgColor
                fontFamily: statsView.fontFam
              }

              Rectangle {
                id: queueBadge
                visible: statsView.taskStats.velocity.activeTotalCount > 0
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: queueBadgeText.implicitHeight + Style.space(4)
                width: queueBadgeText.implicitWidth + Style.space(12)
                radius: height / 2
                color: statsView.taskStats.velocity.activeDoneCount === statsView.taskStats.velocity.activeTotalCount
                  ? Util.alpha(Color.accent, 0.22)
                  : Util.alpha(statsView.fgColor, 0.08)
                border.width: 1
                border.color: statsView.taskStats.velocity.activeDoneCount === statsView.taskStats.velocity.activeTotalCount
                  ? Util.alpha(Color.accent, 0.55)
                  : Util.alpha(statsView.fgColor, 0.16)

                Text {
                  id: queueBadgeText
                  anchors.centerIn: parent
                  text: statsView.taskStats.velocity.activeDoneCount + "/" + statsView.taskStats.velocity.activeTotalCount + " queue (" + statsView.taskStats.velocity.activeClearPct + "%)"
                  color: statsView.taskStats.velocity.activeDoneCount === statsView.taskStats.velocity.activeTotalCount
                    ? Color.accent
                    : statsView.fgColor
                  font.family: statsView.fontFam
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }
            }

            // Reward / Momentum Banner Card
            Rectangle {
              width: parent.width
              height: rewardRow.implicitHeight + Style.space(16)
              radius: Style.space(6)
              color: statsView.taskStats.velocity.completedThisWeek > 0
                ? Util.alpha(Color.accent, 0.10)
                : Util.alpha(statsView.fgColor, 0.05)
              border.width: 1
              border.color: statsView.taskStats.velocity.completedThisWeek > 0
                ? Util.alpha(Color.accent, 0.30)
                : Util.alpha(statsView.fgColor, 0.12)

              Row {
                id: rewardRow
                anchors.left: parent.left
                anchors.leftMargin: Style.space(12)
                anchors.right: parent.right
                anchors.rightMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(10)

                Rectangle {
                  width: Style.space(32)
                  height: Style.space(32)
                  radius: Style.space(6)
                  color: statsView.taskStats.velocity.completedThisWeek > 0
                    ? Util.alpha(Color.accent, 0.22)
                    : Util.alpha(statsView.fgColor, 0.10)
                  anchors.verticalCenter: parent.verticalCenter

                  Text {
                    anchors.centerIn: parent
                    text: (statsView.taskStats.velocity.activeTotalCount > 0 && statsView.taskStats.velocity.activeDoneCount === statsView.taskStats.velocity.activeTotalCount)
                      ? "\uf091"
                      : (statsView.taskStats.velocity.completedThisWeek > 0 ? "\uf00c" : "\uf0ae")
                    color: statsView.taskStats.velocity.completedThisWeek > 0 ? Color.accent : statsView.fgColor
                    font.family: statsView.fontFam
                    font.pixelSize: Style.font.title
                  }
                }

                Column {
                  width: parent.width - Style.space(42)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(2)

                  Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: statsView.taskStats.velocity.headline
                    color: statsView.fgColor
                    font.family: statsView.fontFam
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }

                  Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: statsView.taskStats.velocity.subline
                    color: statsView.mutedColor
                    font.family: statsView.fontFam
                    font.pixelSize: Style.font.caption
                  }
                }
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              // weekly completions tile
              Rectangle {
                width: (parent.width - Style.space(8)) / 2
                height: wkCol.implicitHeight + Style.space(14)
                radius: Style.space(6)
                color: Util.alpha(statsView.fgColor, 0.04)
                border.width: 1
                border.color: Util.alpha(statsView.fgColor, 0.10)

                Column {
                  id: wkCol
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(12)
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(2)

                  Text {
                    text: "THIS WEEK"
                    color: statsView.mutedColor
                    font.family: statsView.fontFam
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }

                  Text {
                    text: statsView.taskStats.velocity.completedThisWeek + " \uf00c"
                    color: statsView.taskStats.velocity.completedThisWeek > 0 ? Color.accent : statsView.fgColor
                    font.family: statsView.fontFam
                    font.pixelSize: Style.font.heading
                    font.bold: true
                  }

                  Text {
                    text: {
                      var d = statsView.taskStats.velocity.weekDelta
                      if (d > 0) return "+" + d + " vs last week"
                      if (d < 0) return d + " vs last week"
                      return statsView.taskStats.velocity.pomodorosThisWeek + " \ue001 this week"
                    }
                    color: statsView.taskStats.velocity.weekDelta > 0 ? Color.accent : statsView.mutedColor
                    font.family: statsView.fontFam
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    width: parent.width
                  }
                }
              }

              // monthly completions tile
              Rectangle {
                width: (parent.width - Style.space(8)) / 2
                height: wkCol.implicitHeight + Style.space(14)
                radius: Style.space(6)
                color: Util.alpha(statsView.fgColor, 0.04)
                border.width: 1
                border.color: Util.alpha(statsView.fgColor, 0.10)

                Column {
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(12)
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(2)

                  Text {
                    text: "THIS MONTH"
                    color: statsView.mutedColor
                    font.family: statsView.fontFam
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }

                  Text {
                    text: statsView.taskStats.velocity.completedThisMonth + " \uf00c"
                    color: statsView.fgColor
                    font.family: statsView.fontFam
                    font.pixelSize: Style.font.heading
                    font.bold: true
                  }

                  Text {
                    text: statsView.taskStats.velocity.completedAllTime + " completed all-time"
                    color: statsView.mutedColor
                    font.family: statsView.fontFam
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    width: parent.width
                  }
                }
              }
            }

            // Completions by days of the week
            Rectangle {
              width: parent.width
              height: Style.space(42)
              radius: Style.space(6)
              color: Util.alpha(statsView.fgColor, 0.03)
              border.width: 1
              border.color: Util.alpha(statsView.fgColor, 0.08)

              Row {
                anchors.fill: parent
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(4)

                Repeater {
                  model: statsView.taskStats.velocity.weekDays

                  Item {
                    required property var modelData
                    width: (parent.width - Style.space(24)) / 7
                    height: parent.height

                    Column {
                      anchors.centerIn: parent
                      spacing: Style.space(3)

                      Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Style.space(28)
                        height: Style.space(16)
                        radius: Style.space(4)
                        color: modelData.tasksDone > 0
                          ? Util.alpha(Color.accent, Math.min(1.0, 0.35 + modelData.tasksDone * 0.22))
                          : (modelData.pomodoros > 0 ? Util.alpha(statsView.fgColor, 0.14) : Util.alpha(statsView.fgColor, 0.05))
                        border.width: modelData.isToday ? 1 : 0
                        border.color: modelData.tasksDone > 0 ? Color.accent : Util.alpha(statsView.fgColor, 0.5)

                        Text {
                          anchors.centerIn: parent
                          text: modelData.tasksDone > 0
                            ? (modelData.tasksDone + "✓")
                            : (modelData.pomodoros > 0 ? (modelData.pomodoros + "\ue001") : "·")
                          color: modelData.tasksDone > 0
                            ? statsView.fgColor
                            : statsView.mutedColor
                          font.family: statsView.fontFam
                          font.pixelSize: Style.font.caption
                          font.bold: modelData.tasksDone > 0
                        }
                      }

                      Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.fullLabel
                        color: modelData.isToday ? statsView.fgColor : statsView.mutedColor
                        font.family: statsView.fontFam
                        font.pixelSize: Style.font.caption
                        font.bold: modelData.isToday
                      }
                    }
                  }
                }
              }
            }
          }

          PanelSeparator { foreground: statsView.fgColor }

          // ----------- POMODOROS BY TASK / TAG BREAKDOWN -----------
          Column {
            id: breakdownSection
            width: parent.width - Style.space(32)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(8)

            Item {
              width: parent.width
              height: Math.max(breakdownHeader.implicitHeight, modeSwitchRow.implicitHeight)

              PanelSectionHeader {
                id: breakdownHeader
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "FOCUS BREAKDOWN"
                foreground: statsView.fgColor
                fontFamily: statsView.fontFam
              }

              // Tasks / Tags switcher pills
              Row {
                id: modeSwitchRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)

                Rectangle {
                  height: Style.space(20)
                  width: tasksTabLabel.implicitWidth + Style.space(14)
                  radius: height / 2
                  color: root.service.breakdownMode === "tasks"
                    ? Util.alpha(Color.accent, 0.22)
                    : Util.alpha(statsView.fgColor, 0.06)
                  border.width: 1
                  border.color: root.service.breakdownMode === "tasks"
                    ? Util.alpha(Color.accent, 0.55)
                    : "transparent"

                  Text {
                    id: tasksTabLabel
                    anchors.centerIn: parent
                    text: "By Task"
                    color: root.service.breakdownMode === "tasks" ? Color.accent : statsView.mutedColor
                    font.family: statsView.fontFam
                    font.pixelSize: Style.font.caption
                    font.bold: root.service.breakdownMode === "tasks"
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.service.breakdownMode = "tasks"
                  }
                }

                Rectangle {
                  height: Style.space(20)
                  width: tagsTabLabel.implicitWidth + Style.space(14)
                  radius: height / 2
                  color: root.service.breakdownMode === "tags"
                    ? Util.alpha(Color.accent, 0.22)
                    : Util.alpha(statsView.fgColor, 0.06)
                  border.width: 1
                  border.color: root.service.breakdownMode === "tags"
                    ? Util.alpha(Color.accent, 0.55)
                    : "transparent"

                  Text {
                    id: tagsTabLabel
                    anchors.centerIn: parent
                    text: "By Tag"
                    color: root.service.breakdownMode === "tags" ? Color.accent : statsView.mutedColor
                    font.family: statsView.fontFam
                    font.pixelSize: Style.font.caption
                    font.bold: root.service.breakdownMode === "tags"
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.service.breakdownMode = "tags"
                  }
                }
              }
            }

            // Empty state when no tasks exist yet
            Rectangle {
              visible: statsView.activeBreakdownRows.length === 0
              width: parent.width
              height: Style.space(48)
              radius: Style.space(6)
              color: Util.alpha(statsView.fgColor, 0.04)
              border.width: 1
              border.color: Util.alpha(statsView.fgColor, 0.08)

              Text {
                anchors.centerIn: parent
                text: "No tasks logged yet — add tasks (use #tags to group) to see focus breakdown"
                color: statsView.mutedColor
                font.family: statsView.fontFam
                font.pixelSize: Style.font.caption
                width: parent.width - Style.space(24)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
              }
            }

            // Stacked Proportional Share Bar (Whole-Pie Distribution Strip)
            Column {
              visible: statsView.activeBreakdownRows.length > 0 && statsView.taskStats.breakdown.totalPomodoros > 0
              width: parent.width
              spacing: Style.space(4)

              Row {
                id: stackedShareBar
                width: parent.width
                height: Style.space(8)
                spacing: Style.space(2)

                Repeater {
                  model: statsView.activeBreakdownRows

                  Rectangle {
                    required property var modelData
                    required property int index
                    visible: modelData.completed > 0
                    height: parent.height
                    radius: Style.space(3)
                    width: {
                      var totalP = Math.max(1, statsView.taskStats.breakdown.totalPomodoros)
                      var nonZeroCount = 0
                      for (var i = 0; i < statsView.activeBreakdownRows.length; i++) {
                        if (statsView.activeBreakdownRows[i].completed > 0) nonZeroCount += 1
                      }
                      var availW = stackedShareBar.width - Math.max(0, nonZeroCount - 1) * stackedShareBar.spacing
                      return Math.max(Style.space(6), availW * (modelData.completed / totalP))
                    }
                    color: statsView.segmentColorForIndex(index)
                    border.width: statsView.hoveredBreakdownIdx === index ? 1 : 0
                    border.color: statsView.fgColor

                    MouseArea {
                      anchors.fill: parent
                      hoverEnabled: true
                      onEntered: statsView.hoveredBreakdownIdx = index
                      onExited: if (statsView.hoveredBreakdownIdx === index) statsView.hoveredBreakdownIdx = -1
                    }
                  }
                }
              }

              // Summary caption below stacked share bar
              Item {
                width: parent.width
                height: Style.space(14)

                Text {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: {
                    if (statsView.hoveredBreakdownIdx >= 0 && statsView.hoveredBreakdownIdx < statsView.activeBreakdownRows.length) {
                      var h = statsView.activeBreakdownRows[statsView.hoveredBreakdownIdx]
                      return h.cleanName + " · " + h.sharePct + "% of focus time (" + statsView.formatDurationCompact(h.focusMinutes) + ")"
                    }
                    return "Focus distribution (" + statsView.taskStats.breakdown.totalPomodoros + " \ue001 · " + statsView.formatDurationCompact(statsView.taskStats.breakdown.totalMinutes) + ")"
                  }
                  color: statsView.hoveredBreakdownIdx >= 0 ? statsView.fgColor : statsView.mutedColor
                  font.family: statsView.fontFam
                  font.pixelSize: Style.font.caption
                  font.bold: statsView.hoveredBreakdownIdx >= 0
                }
              }
            }

            // Ranked Horizontal Bar Chart per Task / Tag
            Column {
              visible: statsView.activeBreakdownRows.length > 0
              width: parent.width
              spacing: Style.space(8)

              Repeater {
                model: statsView.activeBreakdownRows

                Column {
                  id: barRowItem
                  required property var modelData
                  required property int index
                  width: parent.width
                  spacing: Style.space(3)

                  // Top line: Swatch + Task/Tag Title + Tag Pill + Stats on Right
                  Item {
                    width: parent.width
                    height: Math.max(leftTitleRow.implicitHeight, rightMetricRow.implicitHeight)

                    Row {
                      id: leftTitleRow
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                      width: parent.width - rightMetricRow.implicitWidth - Style.space(8)
                      spacing: Style.space(6)

                      Rectangle {
                        width: Style.space(8)
                        height: Style.space(8)
                        radius: Style.space(2)
                        color: statsView.segmentColorForIndex(barRowItem.index)
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      Rectangle {
                        id: rowTagChip
                        visible: root.service.breakdownMode === "tasks" && barRowItem.modelData.tag !== ""
                        height: rowTagChipText.implicitHeight + Style.space(2)
                        width: visible ? (rowTagChipText.implicitWidth + Style.space(8)) : 0
                        radius: Style.space(3)
                        color: Util.alpha(Color.accent, 0.15)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                          id: rowTagChipText
                          anchors.centerIn: parent
                          text: barRowItem.modelData.tag
                          color: Color.accent
                          font.family: statsView.fontFam
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }
                      }

                      Text {
                        id: breakdownTaskText
                        text: barRowItem.modelData.cleanName + (barRowItem.modelData.done ? " \uf00c" : "")
                        color: statsView.fgColor
                        font.family: statsView.fontFam
                        font.pixelSize: Style.font.bodySmall
                        font.bold: barRowItem.index === 0 && barRowItem.modelData.completed > 0
                        elide: Text.ElideRight
                        width: Math.max(
                          Style.space(40),
                          parent.width - Style.space(14) - (rowTagChip.visible ? rowTagChip.width + parent.spacing : 0)
                        )
                        anchors.verticalCenter: parent.verticalCenter
                      }
                    }

                    MouseArea {
                      id: breakdownTitleMouse
                      anchors.fill: leftTitleRow
                      hoverEnabled: true
                      acceptedButtons: Qt.NoButton
                      onEntered: statsView.hoveredBreakdownIdx = barRowItem.index
                      onExited: if (statsView.hoveredBreakdownIdx === barRowItem.index) statsView.hoveredBreakdownIdx = -1
                    }

                    PanelToolTip {
                      visible: breakdownTitleMouse.containsMouse && breakdownTaskText.truncated
                      text: barRowItem.modelData.cleanName
                      fontFamily: statsView.fontFam
                    }

                    Row {
                      id: rightMetricRow
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(6)

                      Text {
                        text: barRowItem.modelData.completed + " \ue001 · " + statsView.formatDurationCompact(barRowItem.modelData.focusMinutes) + " (" + barRowItem.modelData.sharePct + "%)"
                        color: statsView.mutedColor
                        font.family: statsView.fontFam
                        font.pixelSize: Style.font.caption
                        anchors.verticalCenter: parent.verticalCenter
                      }
                    }
                  }

                  // Horizontal Bar Track
                  Item {
                    width: parent.width
                    height: Style.space(6)

                    Rectangle {
                      id: barTrack
                      anchors.fill: parent
                      radius: height / 2
                      color: Util.alpha(statsView.fgColor, 0.08)

                      Rectangle {
                        id: baseBarFill
                        anchors.left: parent.left
                        height: parent.height
                        radius: parent.radius
                        color: statsView.segmentColorForIndex(barRowItem.index)
                        width: parent.width * barRowItem.modelData.barRatio
                        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                      }
                    }

                    MouseArea {
                      anchors.fill: parent
                      hoverEnabled: true
                      onEntered: statsView.hoveredBreakdownIdx = barRowItem.index
                      onExited: if (statsView.hoveredBreakdownIdx === barRowItem.index) statsView.hoveredBreakdownIdx = -1
                    }
                  }
                }
              }
            }
          }

          PanelSeparator { foreground: statsView.fgColor }

          Item {
            width: parent.width
            height: resetStatsBtn.implicitHeight + Style.space(4)

            Button {
              id: resetStatsBtn
              anchors.left: parent.left
              anchors.leftMargin: Style.space(16)
              text: "Reset statistics"
              iconText: "\uf1da"
              foreground: statsView.fgColor
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
              label: "Show seconds in bar"
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