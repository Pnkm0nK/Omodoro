import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Controls.Basic
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "pnkm0nk.omodoro"
  ipcTarget: "pnkm0nk.omodoro"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  property string currentMode:"work"
  property string currentModeLogo:getLogoForMode(currentMode)
  property string currentModeMessage:getMessageForMode(currentMode)
  
  property int longBreakInterval: 4
  property int completedSessions: 0
  property bool autoStartWork: false
  property bool autoStartBreak: true


  property var workTime: 1800
  property var shortBreakTime: 300
  property var longBreakTime: 900
  

  property var timeLeft: getTimeForMode(currentMode)
  readonly property var barIdentity: hostWidget || root
  property string label: "\ue001"

  function format_time(seconds){
    // get correct timer formating from seconds
    let minutes = Math.floor(seconds / 60)
    seconds = seconds%60
    return String(minutes).padStart(2,'0') + ":" + String(seconds).padStart(2, '0')
  }

  function getLogoForMode(mode){
    switch(mode){
      case "shortBreak": return "\ue26f"
      case "longBreak": return "\udb84\udc4f"
      case "work": return "\uf017"
    }
  }
  function getMessageForMode(mode){
    switch(mode){
      case "shortBreak": return "Short Break"
      case "longBreak": return "Long Break"
      case "work": return "Focus!"
    }
  }
  function getTimeForMode(mode) {
    switch (mode) {
      case "shortBreak": return shortBreakTime
      case "longBreak": return longBreakTime
      case "work": return workTime
      default: return workTime
    }
  }

  function switchMode(newMode) {
    currentMode = newMode
    currentModeLogo = getLogoForMode(newMode)
    timeLeft = getTimeForMode(newMode)
  }

  function nextMode(){
    if (currentMode === "work") {
      completedSessions += 1
      if (completedSessions % longBreakInterval === 0) {
        switchMode("longBreak")
        timer.running = autoStartBreak ? true : false 
      } else {
        switchMode("shortBreak")
        timer.running = autoStartBreak ? true : false
      }
    } else {
      switchMode("work")
      timer.running = autoStartWork ? true : false
    }
  }



  function open() {
    root.controller.show()
  }
  function openFromHotkey() {
    root.controller.show()
  }
  function close() {
    root.controller.hide()
  }
  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  // Process{
  //    id: timeProc

  //     command: ["date","+%s"]
  //     running: true

  //     stdout: StdioCollector {
  //       onStreamFinished:timerText.text = format_time(text)
  //     }C
  // }
   Timer {
      id: timer
      interval: 1000

      running: false

      repeat: true

      onTriggered: {
        if (root.timeLeft > 0) {
          root.timeLeft -= 1
        } else {
          running = false // stop when reaching 0
          nextMode()
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
    contentWidth: panel.fittedContentWidth(Style.space(350))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.editingLocation
      onReturnRequested: root.startEditingLocation()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: mainScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: mainColumn
          width: mainScroll.width
          spacing: Style.space(8)

          Item {
            width: parent.width
            height: logoRow.implicitHeight

            Row {
              id: logoRow
              anchors.centerIn: parent
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(8)

              Text {
                id: omodoroIcon
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: 16
              }

              Text {
                id: labelMain
                text: "Omodoro"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: 16
                font.bold: true
              }
            }
          }
          Item{
            width: parent.width
            height: Math.max(timerRow.implicitHeight,timerText.implicitHeight)
            Row{
                id: timerRow
                spacing: Style.space(12)
                anchors.horizontalCenterOffset: 18
                anchors.centerIn: parent
                Text{
                    text: root.getLogoForMode(root.currentMode)
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
                    font.pixelSize: 48
                    font.bold: true
                }
                Text{
                    id: timerText
                    text: root.format_time(root.timeLeft)
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
                    font.pixelSize: 48
                    font.bold: true
                }
                Button{
                  id: plusMinuteButton
                  anchors.verticalCenter: parent.verticalCenter
                  text: "+1 Min"
                  onClicked: root.timeLeft = root.timeLeft +60

              }
            }
          }
        Item{
          id: message
          width: parent.width
          height: 18
          Row{
            id: messageRow
            anchors.centerIn: parent
            Text{
              id: messageText
              text: root.mode
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: 18
            }
          }
        }
        Item{
          id: timerControls
          width: parent.width
          height: 20
          Row{
            id: timerControlsRow
            anchors.centerIn: parent
            Button {
              text: "\uf1da"
              onClicked: root.timeLeft = root.timeToWork
            }
            Button{
              text: timer.running ? "\uead1" :  "\ueb2c"
              onClicked: timer.running = !timer.running
            }
            Button{
              text: "\udb83\udf27"
              onClicked: root.nextMode()
            }
          }
        }
        PanelSeparator {
          foreground: root.bar.foreground
        }

        }
      }
    }
  }
}