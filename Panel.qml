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

  property string currentMode: "work" // "work" | "shortBreak" | "longBreak"
  property int completedSessions: 0

  property int workTime: 1500
  property int shortBreakTime: 300
  property int longBreakTime: 900

  property int longBreakInterval: 4
  property bool autoStartWork: false
  property bool autoStartBreak: true
  property bool notificationsEnabled: true
  property string selectedPreset: "classic"

  property int timeLeft: workTime
  readonly property bool timerRunning: timer.running
  property string label: format_bar_icon(timeLeft, timer.running)

  // panel views
  property bool showSettings: false
  property bool showStats: false
  property bool showTasks: false

  // tasks
  property var tasks: []
  property string newTaskName: ""
  property int newTaskEstimate: 4

  // stats
  property int totalPomodoros: 0
  property int totalFocusMinutes: 0
  property int todayPomodoros: 0
  property int todayFocusMinutes: 0
  property int streakDays: 0
  property string lastActiveDate: ""

  // path for persistent state storage
  property string statePath: Quickshell.env("HOME") + "/.local/state/omarchy/omodoro.json"

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadState(text())
    onLoadFailed: root.saveState()
    onFileChanged: reload()
  }

  function todayString() {
    return Qt.formatDate(new Date(), "yyyy-MM-dd")
  }

  function loadState(raw) {
    if (!raw || raw.trim() === "") return
    try {
      var data = JSON.parse(raw)
      if (data.settings) {
        if (data.settings.selectedPreset !== undefined) root.selectedPreset = data.settings.selectedPreset
        if (data.settings.workTime !== undefined) root.workTime = data.settings.workTime
        if (data.settings.shortBreakTime !== undefined) root.shortBreakTime = data.settings.shortBreakTime
        if (data.settings.longBreakTime !== undefined) root.longBreakTime = data.settings.longBreakTime
        if (data.settings.longBreakInterval !== undefined) root.longBreakInterval = data.settings.longBreakInterval
        if (data.settings.autoStartWork !== undefined) root.autoStartWork = data.settings.autoStartWork
        if (data.settings.autoStartBreak !== undefined) root.autoStartBreak = data.settings.autoStartBreak
        if (data.settings.notificationsEnabled !== undefined) root.notificationsEnabled = data.settings.notificationsEnabled
        if (!timer.running) root.timeLeft = root.getTimeForMode(root.currentMode)
      }
      if (Array.isArray(data.tasks)) {
        root.tasks = data.tasks
      }
      if (data.stats) {
        root.totalPomodoros = data.stats.totalPomodoros || 0
        root.totalFocusMinutes = data.stats.totalFocusMinutes || 0
        root.streakDays = data.stats.streakDays || 0
        root.lastActiveDate = data.stats.lastActiveDate || ""

        var today = todayString()
        if (root.lastActiveDate === today) {
          root.todayPomodoros = data.stats.todayPomodoros || 0
          root.todayFocusMinutes = data.stats.todayFocusMinutes || 0
        } else {
          root.todayPomodoros = 0
          root.todayFocusMinutes = 0
        }
      }
    } catch (e) {
      console.warn("Omodoro: failed to parse state JSON", e)
    }
  }

  function saveState() {
    var data = {
      settings: {
        selectedPreset: root.selectedPreset,
        workTime: root.workTime,
        shortBreakTime: root.shortBreakTime,
        longBreakTime: root.longBreakTime,
        longBreakInterval: root.longBreakInterval,
        autoStartWork: root.autoStartWork,
        autoStartBreak: root.autoStartBreak,
        notificationsEnabled: root.notificationsEnabled
      },
      tasks: root.tasks,
      stats: {
        totalPomodoros: root.totalPomodoros,
        totalFocusMinutes: root.totalFocusMinutes,
        todayPomodoros: root.todayPomodoros,
        todayFocusMinutes: root.todayFocusMinutes,
        streakDays: root.streakDays,
        lastActiveDate: root.lastActiveDate
      }
    }
    stateFile.setText(JSON.stringify(data, null, 2) + "\n")
  }

  function recordWorkSessionCompleted() {
    var today = todayString()
    var mins = Math.round((workTime - timeLeft) / 60)

    totalPomodoros += 1
    totalFocusMinutes += mins

    if (lastActiveDate === today) {
      todayPomodoros += 1
      todayFocusMinutes += mins
    } else {
      var yesterday = new Date()
      yesterday.setDate(yesterday.getDate() - 1)
      var yStr = Qt.formatDate(yesterday, "yyyy-MM-dd")
      if (lastActiveDate === yStr) {
        streakDays += 1
      } else {
        streakDays = 1
      }
      todayPomodoros = 1
      todayFocusMinutes = mins
      lastActiveDate = today
    }

    // increment the first uncompleted task
    for (var i = 0; i < tasks.length; i++) {
      if (tasks[i].completed < tasks[i].estimated) {
        incrementTask(i)
        break
      }
    }

    saveState()
  }

  function resetStats() {
    totalPomodoros = 0
    totalFocusMinutes = 0
    todayPomodoros = 0
    todayFocusMinutes = 0
    streakDays = 0
    lastActiveDate = ""
    saveState()
  }

  // helpers
  function format_time(seconds) {
    var m = Math.floor(seconds / 60)
    var s = seconds % 60
    return String(m).padStart(2, '0') + ":" + String(s).padStart(2, '0')
  }

  function format_bar_icon(seconds, isTimerRunning) {
    if (!isTimerRunning) {
      return "\ue001"
    }
    var m = Math.floor(seconds / 60)
    var s = seconds % 60
    if (m === 0) return String(s).padStart(2, '0')
    return String(m)
  }

  function getLogoForMode(mode) {
    switch (mode) {
      case "shortBreak": return "\ue26f"
      case "longBreak":  return "\udb84\udc4f"
      default:           return "\uf017"
    }
  }

  function getMessageForMode(mode) {
    switch (mode) {
      case "shortBreak": return "Short Break"
      case "longBreak":  return "Long Break"
    }
    return tasks.length > 0 ? tasks[0].name : "Focus!"
  }

  function getTimeForMode(mode) {
    switch (mode) {
      case "shortBreak": return shortBreakTime
      case "longBreak":  return longBreakTime
      default:           return workTime
    }
  }

  function sendNotification(title, message) {
    if (!notificationsEnabled) return
    Quickshell.execDetached([
      "notify-send",
      "-a", "Omodoro",
      "-i", "alarm-symbolic",
      "-u", "normal",
      title,
      message
    ])
  }

  function switchMode(newMode) {
    currentMode = newMode
    timeLeft = getTimeForMode(newMode)
  }

  function nextMode() {
    var notificationTitle = ""
    var message = ""
    if (currentMode === "work") {
      completedSessions += 1
      recordWorkSessionCompleted()
      notificationTitle = "Break time"
      if (completedSessions % longBreakInterval === 0) {
        switchMode("longBreak")
        message = "Enjoy your long break!"
        timer.running = autoStartBreak
      } else {
        switchMode("shortBreak")
        message = "Take a short break"
        timer.running = autoStartBreak
      }
    } else {
      notificationTitle = "Time to work"
      message = "Another pomodoro!"  
      switchMode("work")
      timer.running = autoStartWork
    }
    sendNotification(notificationTitle, message)
  }

  function applyPreset(preset) {
    selectedPreset = preset
    switch (preset) {
      case "classic":
        workTime = 1500; shortBreakTime = 300; longBreakTime = 900; break
      case "long":
        workTime = 3000; shortBreakTime = 600; longBreakTime = 1800; break
      case "short":
        workTime = 900; shortBreakTime = 180; longBreakTime = 600; break
      default: break
    }
    if (!timer.running) timeLeft = getTimeForMode(currentMode)
    saveState()
  }

  function addTask() {
    if (newTaskName.trim() === "") return
    var t = tasks.slice()
    t.push({ name: newTaskName.trim(), estimated: newTaskEstimate, completed: 0 })
    tasks = t
    newTaskName = ""
    saveState()
  }

  function removeTask(index) {
    var t = tasks.slice()
    t.splice(index, 1)
    tasks = t
    saveState()
  }

  function incrementTask(index) {
    var t = tasks.slice()
    if (t[index].completed < t[index].estimated) {
      t[index] = { name: t[index].name, estimated: t[index].estimated, completed: t[index].completed + 1 }
      tasks = t
      saveState()
    }
  }

  function open() { root.controller.show() }
  function openFromHotkey() { root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  Timer {
    id: timer
    interval: 1000
    running: false
    repeat: true
    onTriggered: {
      if (root.timeLeft > 0) {
        root.timeLeft -= 1
      } else {
        running = false
        root.nextMode()
      }
    }
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
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: taskNameField && taskNameField.activeFocus ? true : false
      onCloseRequested: root.close()
      onActivateRequested: timer.running = !timer.running
      onTextKey: function(t) {
        if (t === "r" || t === "R") {
          root.timeLeft = root.getTimeForMode(root.currentMode)
        } else if (t === "n" || t === "N") {
          root.nextMode()
        } else if (t === "+" || t === "=") {
          root.timeLeft += 60
        } else if (t === "-" || t === "_") {
          root.timeLeft = Math.max(0, root.timeLeft - 60)
        }
      }

      Flickable {
        id: mainScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainColumn.implicitHeight
        clip: interactive
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: mainColumn
          width: mainScroll.width
          spacing: Style.space(4)

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
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.heading
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: "Omodoro"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
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
                iconText: root.showStats ? "\uf00d" : "\uebe2"
                tooltipText: root.showStats ? "Back to timer" : "Statistics"
                foreground: root.bar.foreground
                onClicked: {
                  if (root.showStats) {
                    root.showStats = false
                  } else {
                    root.showStats = true
                    root.showSettings = false
                  }
                }
              }

              Button {
                iconText: root.showSettings ? "\uf00d" : "\ueb52"
                tooltipText: root.showSettings ? "Back to timer" : "Settings"
                foreground: root.bar.foreground
                onClicked: {
                  if (root.showSettings) {
                    root.showSettings = false
                  } else {
                    root.showSettings = true
                    root.showStats = false
                  }
                }
              }
            }
          }

          PanelSeparator { foreground: root.bar.foreground }

          Column {
            id: timerView
            visible: !root.showSettings && !root.showStats
            width: parent.width
            spacing: Style.space(8)

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
                    text: root.getLogoForMode(root.currentMode)
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.display
                  }

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.format_time(root.timeLeft)
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
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
                  color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.15)

                  Rectangle {
                    id: progressFill
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    radius: parent.radius
                    color: root.bar.foreground
                    width: {
                      var total = root.getTimeForMode(root.currentMode)
                      if (total <= 0) return 0
                      return parent.width * (1.0 - root.timeLeft / total)
                    }

                    Behavior on width {
                      NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }
                  }
                }
              }
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.getMessageForMode(root.currentMode)
              color: Qt.darker(root.bar.foreground, 1.3)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }

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
                  foreground: root.bar.foreground
                  onClicked: root.timeLeft = root.getTimeForMode(root.currentMode)
                }
                Button {
                  iconText: timer.running ? "\uead1" : "\ueb2c"
                  tooltipText: timer.running ? "Pause" : "Start"
                  foreground: root.bar.foreground
                  onClicked: timer.running = !timer.running
                }
                Button {
                  iconText: "\udb83\udf27"
                  tooltipText: "Skip"
                  foreground: root.bar.foreground
                  onClicked: root.nextMode()
                }
                Button {
                  text: "+1m"
                  tooltipText: "Add 1 minute"
                  foreground: root.bar.foreground
                  onClicked: root.timeLeft += 60
                }
              }
            }

            Item {
              width: parent.width
              height: dotsRow.implicitHeight

              Row {
                id: dotsRow
                anchors.centerIn: parent
                spacing: Style.space(6)

                Repeater {
                  model: root.longBreakInterval

                  Rectangle {
                    required property int index
                    width: Style.space(8)
                    height: Style.space(8)
                    radius: width / 2
                    color: index < (root.completedSessions % root.longBreakInterval)
                      ? root.bar.foreground
                      : "transparent"
                    border.color: root.bar.foreground
                    border.width: 1
                  }
                }
              }
            }

            PanelSeparator { foreground: root.bar.foreground }

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
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              Button {
                anchors.right: parent.right
                anchors.rightMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                iconText: root.showTasks ? "\ueaa1" : "\uea9a"
                foreground: root.bar.foreground
                onClicked: root.showTasks = !root.showTasks
              }
            }

            Column {
              id: taskDrawer
              width: parent.width
              visible: root.showTasks
              spacing: Style.space(4)

              Repeater {
                model: root.tasks

                Item {
                  required property int index
                  required property var modelData
                  width: taskDrawer.width
                  height: Math.max(taskRow.implicitHeight, Style.space(36))

                  readonly property int taskCompleted: modelData ? (modelData.completed || 0) : 0
                  readonly property int taskEstimated: modelData ? (modelData.estimated || 1) : 1

                  Row {
                    id: taskRow
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(16)
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(12)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(8)

                    Text {
                      text: modelData ? modelData.name : ""
                      color: root.bar.foreground
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.body
                      elide: Text.ElideRight
                      width: parent.width - taskProgress.width - taskIncBtn.width - taskDelBtn.width - parent.spacing * 3
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                      id: taskProgress
                      text: modelData ? (taskCompleted + "/" + taskEstimated) : ""
                      color: Qt.darker(root.bar.foreground, 1.4)
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    PanelActionButton {
                      id: taskIncBtn
                      iconText: "\uf067"
                      foreground: root.bar.foreground
                      anchors.verticalCenter: parent.verticalCenter
                      enabled: taskCompleted < taskEstimated
                      onClicked: root.incrementTask(index)
                    }

                    PanelActionButton {
                      id: taskDelBtn
                      iconText: "✕"
                      foreground: root.bar.foreground
                      hoverColor: Color.urgent
                      anchors.verticalCenter: parent.verticalCenter
                      onClicked: root.removeTask(index)
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
                    foreground: root.bar.foreground
                    text: root.newTaskName
                    onTextChanged: root.newTaskName = text
                    Keys.onReturnPressed: root.addTask()
                    Keys.onEnterPressed: root.addTask()
                    Keys.onEscapePressed: function(event) {
                      taskNameField.focus = false
                      keyCatcher.forceActiveFocus()
                      if (event) event.accepted = true
                    }
                  }

                  NumberField {
                    id: taskEstField
                    label: ""
                    value: root.newTaskEstimate
                    from: 1
                    to: 20
                    foreground: root.bar.foreground
                    fieldWidth: Style.space(56)
                    onModified: function(v) { root.newTaskEstimate = v }
                  }

                  Button {
                    id: addTaskBtn
                    iconText: "\uf067"
                    tooltipText: "Add task"
                    foreground: root.bar.foreground
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: {
                      root.addTask()
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
            visible: root.showStats
            width: parent.width
            spacing: Style.space(12)

            PanelSectionHeader {
              text: "STATISTICS"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
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
                    color: Qt.darker(root.bar.foreground, 1.5)
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                  Text {
                    text: root.todayPomodoros + " \ue001 (" + root.todayFocusMinutes + "m)"
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }
                }

                Column {
                  spacing: Style.space(2)
                  Text {
                    text: "ALL TIME"
                    color: Qt.darker(root.bar.foreground, 1.5)
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                  Text {
                    text: root.totalPomodoros + " (" + Math.round(root.totalFocusMinutes / 60) + "h)"
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }
                }

                Column {
                  spacing: Style.space(2)
                  Text {
                    text: "STREAK"
                    color: Qt.darker(root.bar.foreground, 1.5)
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                  Text {
                    text: root.streakDays + " \udb80\ude38"
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
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
                foreground: root.bar.foreground
                onClicked: root.resetStats()
              }
            }
          }

          // ----------- SETTINGS VIEW -----------
          Column {
            id: settingsView
            visible: root.showSettings
            width: parent.width
            spacing: Style.space(12)

            PanelSectionHeader {
              text: "PRESET"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              leftPadding: Style.space(16)
            }

            Item {
              width: parent.width
              height: presetGroup.implicitHeight

              ButtonGroup {
                id: presetGroup
                anchors.horizontalCenter: parent.horizontalCenter
                foreground: root.bar.foreground
                value: root.selectedPreset
                options: [
                  { value: "classic", label: "25/5/15" },
                  { value: "long",    label: "50/10/30" },
                  { value: "short",   label: "15/3/10" },
                  { value: "custom",  label: "Custom" }
                ]
                onChanged: function(v) { root.applyPreset(v) }
              }
            }

            Column {
              visible: root.selectedPreset === "custom"
              width: parent.width
              spacing: Style.space(10)
              leftPadding: Style.space(16)

              PanelSectionHeader {
                text: "CUSTOM DURATIONS"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
              }

              Row {
                spacing: Style.space(16)

                NumberField {
                  label: "Work (min)"
                  value: Math.round(root.workTime / 60)
                  from: 1
                  to: 120
                  foreground: root.bar.foreground
                  fieldWidth: Style.space(70)
                  onModified: function(v) {
                    root.workTime = v * 60
                    if (!timer.running && root.currentMode === "work") root.timeLeft = root.workTime
                    root.saveState()
                  }
                }

                NumberField {
                  label: "Short (min)"
                  value: Math.round(root.shortBreakTime / 60)
                  from: 1
                  to: 30
                  foreground: root.bar.foreground
                  fieldWidth: Style.space(70)
                  onModified: function(v) {
                    root.shortBreakTime = v * 60
                    if (!timer.running && root.currentMode === "shortBreak") root.timeLeft = root.shortBreakTime
                    root.saveState()
                  }
                }

                NumberField {
                  label: "Long (min)"
                  value: Math.round(root.longBreakTime / 60)
                  from: 1
                  to: 60
                  foreground: root.bar.foreground
                  fieldWidth: Style.space(70)
                  onModified: function(v) {
                    root.longBreakTime = v * 60
                    if (!timer.running && root.currentMode === "longBreak") root.timeLeft = root.longBreakTime
                    root.saveState()
                  }
                }
              }
            }

            PanelSeparator { foreground: root.bar.foreground }

            Item {
              width: parent.width
              height: intervalField.implicitHeight

              NumberField {
                id: intervalField
                anchors.left: parent.left
                anchors.leftMargin: Style.space(16)
                label: "Sessions before long break"
                value: root.longBreakInterval
                from: 1
                to: 10
                foreground: root.bar.foreground
                fieldWidth: Style.space(70)
                onModified: function(v) {
                  root.longBreakInterval = v
                  root.saveState()
                }
              }
            }

            PanelSeparator { foreground: root.bar.foreground }

            PanelSectionHeader {
              text: "AUTO-START"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
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
                checked: root.autoStartWork
                foreground: root.bar.foreground
                onClicked: {
                  root.autoStartWork = !root.autoStartWork
                  root.saveState()
                }
              }

              Toggle {
                width: parent.width
                label: "Auto-start breaks"
                description: "Automatically begin breaks after work sessions"
                checked: root.autoStartBreak
                foreground: root.bar.foreground
                onClicked: {
                  root.autoStartBreak = !root.autoStartBreak
                  root.saveState()
                }
              }

              Toggle {
                width: parent.width
                label: "Notifications"
                description: "Notify when work sessions and breaks finish"
                checked: root.notificationsEnabled
                foreground: root.bar.foreground
                onClicked: {
                  root.notificationsEnabled = !root.notificationsEnabled
                  root.saveState()
                }
              }
            }

            PanelSeparator { foreground: root.bar.foreground }

            PanelSectionHeader {
              text: "KEYBOARD SHORTCUTS"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              leftPadding: Style.space(8)
            }

            Column {
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
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                  }

                  Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.desc
                    color: Qt.darker(root.bar.foreground, 1.4)
                    font.family: root.bar.fontFamily
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
}