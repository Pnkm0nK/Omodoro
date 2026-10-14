import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property string currentMode: "work" // "work" | "shortBreak" | "longBreak"
    property int completedSessions: 0

    property int workTime: 1500
    property int shortBreakTime: 300
    property int longBreakTime: 900

    property int longBreakInterval: 4
    property bool autoStartWork: false
    property bool autoStartBreak: true
    property bool notificationsEnabled: true
    property bool soundEnabled: true
    property bool tickSoundEnabled: true
    property string selectedPreset: "classic"

    readonly property string pluginDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/pnkm0nk.omodoro"

    readonly property var soundOptions: [
        { id: "bell",      label: "Bell",       path: "/usr/share/sounds/freedesktop/stereo/bell.oga" },
        { id: "complete",  label: "Complete",   path: "/usr/share/sounds/freedesktop/stereo/complete.oga" },
        { id: "message",   label: "Message",    path: "/usr/share/sounds/freedesktop/stereo/message.oga" },
        { id: "alarm",     label: "Alarm",      path: "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga" }
    ]

    readonly property var tickOptions: [
        { id: "click",      label: "Click",      path: pluginDir + "/sounds/tick.wav" },
        { id: "wristwatch", label: "Wristwatch", path: pluginDir + "/sounds/tick-wristwatch.wav" }
    ]

    property string breakSoundId: "complete"
    property string workSoundId: "bell"
    property string tickSoundId: "wristwatch"

    function soundPathForId(id) {
    for (var i = 0; i < soundOptions.length; i++) {
        if (soundOptions[i].id === id) return soundOptions[i].path
    }
    return soundOptions[0].path
    }

    function tickSoundPathForId(id) {
    for (var i = 0; i < tickOptions.length; i++) {
        if (tickOptions[i].id === id) return tickOptions[i].path
    }
    return tickOptions[0].path
    }

    property int timeLeft: workTime
    property alias timerRunning: timer.running
    property string label: format_bar_icon(timeLeft, timer.running)

    // panel views
    property bool showSettings: false
    property bool showStats: false
    property bool showTasks: false
    property bool isDraggingTask: false

    // tasks
    property alias taskModel: taskModel
    property var currentTask: null

    ListModel {
    id: taskModel
    }

    function updateCurrentTask() {
    for (var i = 0; i < taskModel.count; i++) {
        var item = taskModel.get(i)
        if (item && item.completed < item.estimated) {
        root.currentTask = {
            index: i,
            name: item.name,
            completed: item.completed,
            estimated: item.estimated
        }
        return
        }
    }
    if (taskModel.count > 0) {
        var first = taskModel.get(0)
        root.currentTask = {
        index: 0,
        name: first.name,
        completed: first.completed,
        estimated: first.estimated
        }
    } else {
        root.currentTask = null
    }
    }

    Component.onCompleted: root.updateCurrentTask()

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
            if (data.settings.soundEnabled !== undefined) root.soundEnabled = data.settings.soundEnabled
            if (data.settings.tickSoundEnabled !== undefined) root.tickSoundEnabled = data.settings.tickSoundEnabled
            if (data.settings.tickSoundId !== undefined) root.tickSoundId = data.settings.tickSoundId
            if (data.settings.breakSoundId !== undefined) root.breakSoundId = data.settings.breakSoundId
            if (data.settings.workSoundId !== undefined) root.workSoundId = data.settings.workSoundId
            if (!timer.running) root.timeLeft = root.getTimeForMode(root.currentMode)
        }
        // clearing to prevent leftover data duplicating
        taskModel.clear()
        if (Array.isArray(data.tasks)) {
            for (var i = 0; i < data.tasks.length; i++) {
            taskModel.append(data.tasks[i])
            }
        }
        root.updateCurrentTask()
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

    function modelToArrayTransform(model) {
    var arr = []
    if (!model) return arr
    for (var i = 0; i < model.count; i++) {
        var item = model.get(i)
        arr.push({
        name: item.name,
        estimated: item.estimated,
        completed: item.completed
        })
    }
    return arr
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
        notificationsEnabled: root.notificationsEnabled,
        soundEnabled: root.soundEnabled,
        tickSoundEnabled: root.tickSoundEnabled,
        tickSoundId: root.tickSoundId,
        breakSoundId: root.breakSoundId,
        workSoundId: root.workSoundId
        },
        tasks: modelToArrayTransform(taskModel),
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
    for (var i = 0; i < taskModel.count; i++) {
        if (taskModel.get(i).completed < taskModel.get(i).estimated) {
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
        default:           return root.currentTask ? root.currentTask.name : "Focus!"
    }
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

    function playSound(path) {
    if (!soundEnabled) return
    Quickshell.execDetached(["paplay", path])
    }

    function previewSound(id) {
    Quickshell.execDetached(["paplay", soundPathForId(id)])
    }

    function previewTick() {
    Quickshell.execDetached(["paplay", tickSoundPathForId(tickSoundId)])
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
        playSound(soundPathForId(breakSoundId))
    } else {
        notificationTitle = "Time to work"
        message = "Another pomodoro!"
        switchMode("work")
        timer.running = autoStartWork
        playSound(soundPathForId(workSoundId))
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

    function addTask(name, estimated) {
    var trimmed = (name || "").trim()
    if (trimmed === "") return
    taskModel.append({
        name: trimmed,
        estimated: estimated || 1,
        completed: 0
    })
    root.updateCurrentTask()
    saveState()
    }

    function removeTask(index) {
    if (index >= 0 && index < taskModel.count) {
        taskModel.remove(index)
        root.updateCurrentTask()
        saveState()
    }
    }

    function incrementTask(index) {
    if (index >= 0 && index < taskModel.count) {
        var item = taskModel.get(index)
        if (item.completed < item.estimated) {
        taskModel.setProperty(index, "completed", item.completed + 1)
        root.updateCurrentTask()
        saveState()
        }
    }
    }
    Timer {
        id: timer
        interval: 1000
        running: false
        repeat: true
        onTriggered: {
            if (root.timeLeft > 0) {
            root.timeLeft -= 1
            if (root.tickSoundEnabled) root.playSound(root.tickSoundPathForId(root.tickSoundId))
            } else {
            running = false
            root.nextMode()
            }
        }
    }
}