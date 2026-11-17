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
    property bool tickSoundEnabled: false
    property bool showSecondsInBar: false
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
    property string label: format_bar_icon(timeLeft, timer.running, showSecondsInBar)

    // panel views
    property bool showSettings: false
    property bool showStats: false
    property bool showTasks: false
    property bool showSoundSettings: false
    property bool showShortcuts: false
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
        if (item && !item.done && item.completed < item.estimated) {
        root.currentTask = {
            index: i,
            name: item.name,
            completed: item.completed,
            estimated: item.estimated,
            done: Boolean(item.done)
        }
        return
        }
    }
    for (var j = 0; j < taskModel.count; j++) {
        var openItem = taskModel.get(j)
        if (openItem && !openItem.done) {
        root.currentTask = {
            index: j,
            name: openItem.name,
            completed: openItem.completed,
            estimated: openItem.estimated,
            done: false
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
        estimated: first.estimated,
        done: Boolean(first.done)
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
    property var dailyHistory: ({})
    property var taskHistory: ({})
    property int historyRevision: 0
    property string breakdownMode: "tasks" // "tasks" | "tags"

    // path for persistent state storage
    property string statePath: Quickshell.env("HOME") + "/.local/state/omarchy/omodoro.json"
    property string lastSavedJson: ""

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

    function extractTaskTag(rawName) {
    var s = String(rawName || "").trim()
    if (s === "") return { tag: "", cleanName: "Untitled" }
    var hashMatch = s.match(/(?:^|\s)#([A-Za-z0-9_-]+)/)
    if (hashMatch) {
        var cleaned = s.replace(/(?:^|\s)#[A-Za-z0-9_-]+/g, " ").replace(/\s+/g, " ").trim()
        return {
            tag: hashMatch[1].toLowerCase(),
            cleanName: cleaned.length > 0 ? cleaned : s
        }
    }
    var bracketMatch = s.match(/^\[([^\]]+)\]\s*(.+)$/)
    if (bracketMatch) {
        return {
            tag: bracketMatch[1].trim().replace(/^#+/, "").toLowerCase(),
            cleanName: bracketMatch[2].trim()
        }
    }
    var colonMatch = s.match(/^([A-Za-z0-9_-]{2,14}):\s+(.+)$/)
    if (colonMatch) {
        return {
            tag: colonMatch[1].trim().replace(/^#+/, "").toLowerCase(),
            cleanName: colonMatch[2].trim()
        }
    }
    return { tag: "", cleanName: s }
    }

    function normalizeTaskObject(t, idx) {
    var est = Math.max(1, Number(t && t.estimated) || 1)
    var comp = Math.max(0, Number(t && t.completed) || 0)
    var isDone = (t && t.done !== undefined) ? Boolean(t.done) : (comp >= est && est > 0)
    var defaultMins = comp * Math.max(1, Math.round(root.workTime / 60))
    var mins = (t && t.focusMinutes !== undefined && Number(t.focusMinutes) > 0)
        ? Number(t.focusMinutes)
        : defaultMins
    var cAt = (t && t.completedAt) ? String(t.completedAt) : (isDone ? (root.lastActiveDate || todayString()) : "")
    return {
        id: (t && t.id) ? String(t.id) : ("task_" + Date.now() + "_" + (idx || 0) + "_" + Math.floor(Math.random() * 10000)),
        name: String((t && t.name) || "Untitled").trim(),
        estimated: est,
        completed: comp,
        done: isDone,
        completedAt: isDone ? (cAt || todayString()) : "",
        focusMinutes: mins
    }
    }

    function syncTaskToHistory(item) {
    if (!item || !item.id) return
    var copy = Object.assign({}, root.taskHistory || {})
    if (item.done || item.completed > 0) {
        var parsed = extractTaskTag(item.name)
        copy[item.id] = {
            id: item.id,
            name: item.name,
            tag: parsed.tag,
            estimated: item.estimated,
            completed: item.completed,
            done: Boolean(item.done),
            completedAt: item.done ? (item.completedAt || todayString()) : "",
            focusMinutes: item.focusMinutes || (item.completed * Math.max(1, Math.round(root.workTime / 60))),
            updatedAt: todayString()
        }
    } else {
        delete copy[item.id]
    }
    root.taskHistory = copy
    }

    function syncAllTasksToHistory() {
    var copy = Object.assign({}, root.taskHistory || {})
    for (var i = 0; i < taskModel.count; i++) {
        var item = taskModel.get(i)
        if (item && item.id && (item.done || item.completed > 0)) {
            var parsed = extractTaskTag(item.name)
            var existing = copy[item.id] || {}
            copy[item.id] = {
                id: item.id,
                name: item.name,
                tag: parsed.tag,
                estimated: item.estimated,
                completed: item.completed,
                done: Boolean(item.done),
                completedAt: item.done ? (item.completedAt || existing.completedAt || root.lastActiveDate || todayString()) : "",
                focusMinutes: item.focusMinutes || existing.focusMinutes || (item.completed * Math.max(1, Math.round(root.workTime / 60))),
                updatedAt: existing.updatedAt || todayString()
            }
        }
    }
    root.taskHistory = copy
    }

    function loadState(raw) {
    if (!raw || raw.trim() === "") return
    if (raw === root.lastSavedJson) return
    root.lastSavedJson = raw
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
            if (data.settings.showSecondsInBar !== undefined) root.showSecondsInBar = data.settings.showSecondsInBar
            else if (data.settings.doubleDigitTimer !== undefined) root.showSecondsInBar = data.settings.doubleDigitTimer
            if (data.settings.showSoundSettings !== undefined) root.showSoundSettings = data.settings.showSoundSettings
            if (data.settings.showShortcuts !== undefined) root.showShortcuts = data.settings.showShortcuts
            if (!timer.running) root.timeLeft = root.getTimeForMode(root.currentMode)
        }
        if (data.stats) {
        root.totalPomodoros = data.stats.totalPomodoros || 0
        root.totalFocusMinutes = data.stats.totalFocusMinutes || 0
        root.streakDays = data.stats.streakDays || 0
        root.lastActiveDate = data.stats.lastActiveDate || ""
        root.dailyHistory = (data.stats.dailyHistory && typeof data.stats.dailyHistory === "object")
            ? data.stats.dailyHistory
            : {}
        root.taskHistory = (data.stats.taskHistory && typeof data.stats.taskHistory === "object")
            ? data.stats.taskHistory
            : {}

        var today = todayString()
        if (root.lastActiveDate === today) {
            root.todayPomodoros = data.stats.todayPomodoros || 0
            root.todayFocusMinutes = data.stats.todayFocusMinutes || 0
        } else {
            root.todayPomodoros = 0
            root.todayFocusMinutes = 0
        }

        // Backfill lastActiveDate entry if dailyHistory didn't have it yet
        if (root.lastActiveDate !== "" && !root.dailyHistory[root.lastActiveDate]) {
            var lastCount = (root.lastActiveDate === today) ? root.todayPomodoros : (data.stats.todayPomodoros || 0)
            var lastMins = (root.lastActiveDate === today) ? root.todayFocusMinutes : (data.stats.todayFocusMinutes || 0)
            if (lastCount > 0) {
                var copy = Object.assign({}, root.dailyHistory)
                copy[root.lastActiveDate] = { count: lastCount, minutes: lastMins }
                root.dailyHistory = copy
            }
        }
        }
        // clearing to prevent leftover data duplicating
        taskModel.clear()
        if (Array.isArray(data.tasks)) {
            for (var i = 0; i < data.tasks.length; i++) {
            taskModel.append(normalizeTaskObject(data.tasks[i], i))
            }
        }
        root.syncAllTasksToHistory()
        root.updateCurrentTask()
        root.historyRevision += 1
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
        id: item.id,
        name: item.name,
        estimated: item.estimated,
        completed: item.completed,
        done: Boolean(item.done),
        completedAt: item.completedAt || "",
        focusMinutes: item.focusMinutes || 0
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
        workSoundId: root.workSoundId,
        showSecondsInBar: root.showSecondsInBar,
        showSoundSettings: root.showSoundSettings,
        showShortcuts: root.showShortcuts
        },
        tasks: modelToArrayTransform(taskModel),
        stats: {
        totalPomodoros: root.totalPomodoros,
        totalFocusMinutes: root.totalFocusMinutes,
        todayPomodoros: root.todayPomodoros,
        todayFocusMinutes: root.todayFocusMinutes,
        streakDays: root.streakDays,
        lastActiveDate: root.lastActiveDate,
        dailyHistory: root.dailyHistory,
        taskHistory: root.taskHistory
        }
    }
    var jsonText = JSON.stringify(data, null, 2) + "\n"
    root.lastSavedJson = jsonText
    stateFile.setText(jsonText)
    }

    function recordWorkSessionCompleted() {
    var today = todayString()
    var mins = Math.max(1, Math.round((workTime - timeLeft) / 60))

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

    var historyCopy = Object.assign({}, root.dailyHistory || {})
    var existing = historyCopy[today] || { count: 0, minutes: 0 }
    historyCopy[today] = {
        count: (existing.count || 0) + 1,
        minutes: (existing.minutes || 0) + mins
    }
    root.dailyHistory = historyCopy
    root.historyRevision += 1

    // Increment the first uncompleted task (preferring < estimated, then any !done task)
    var targetIndex = -1
    for (var i = 0; i < taskModel.count; i++) {
        var tItem = taskModel.get(i)
        if (!tItem.done && tItem.completed < tItem.estimated) {
            targetIndex = i
            break
        }
    }
    if (targetIndex === -1) {
        for (var j = 0; j < taskModel.count; j++) {
            if (!taskModel.get(j).done) {
                targetIndex = j
                break
            }
        }
    }
    if (targetIndex >= 0) {
        incrementTask(targetIndex, mins)
    } else {
        saveState()
    }
    }

    function resetStats() {
    totalPomodoros = 0
    totalFocusMinutes = 0
    todayPomodoros = 0
    todayFocusMinutes = 0
    streakDays = 0
    lastActiveDate = ""
    dailyHistory = ({})
    taskHistory = ({})
    for (var i = 0; i < taskModel.count; i++) {
        taskModel.setProperty(i, "completed", 0)
        taskModel.setProperty(i, "done", false)
        taskModel.setProperty(i, "completedAt", "")
        taskModel.setProperty(i, "focusMinutes", 0)
    }
    updateCurrentTask()
    historyRevision += 1
    saveState()
    }

    function getHeatmapWeeks(numWeeks) {
    var weeksCount = numWeeks || 16
    var now = new Date()
    now.setHours(12, 0, 0, 0)
    // Monday-indexed day of week: Mon=0 .. Sun=6
    var dow = (now.getDay() + 6) % 7
    var startOfThisWeek = new Date(now)
    startOfThisWeek.setDate(now.getDate() - dow)

    var firstDay = new Date(startOfThisWeek)
    firstDay.setDate(startOfThisWeek.getDate() - (weeksCount - 1) * 7)

    var todayStr = todayString()
    var monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    var dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    var weeks = []
    var lastMonth = -1

    for (var w = 0; w < weeksCount; w++) {
        var days = []
        var monthLabel = ""
        for (var d = 0; d < 7; d++) {
            var cur = new Date(firstDay)
            cur.setDate(firstDay.getDate() + w * 7 + d)
            var dateStr = Qt.formatDate(cur, "yyyy-MM-dd")
            var isFuture = dateStr > todayStr
            var entry = (!isFuture && root.dailyHistory && root.dailyHistory[dateStr])
                ? root.dailyHistory[dateStr]
                : { count: 0, minutes: 0 }

            if (cur.getDate() <= 7 && cur.getMonth() !== lastMonth && w > 0) {
                monthLabel = monthNames[cur.getMonth()]
                lastMonth = cur.getMonth()
            } else if (w === 0 && d === 0) {
                lastMonth = cur.getMonth()
                // Only show label on week 0 if the next month isn't starting within the next 2 columns
                var twoWeeksLater = new Date(firstDay)
                twoWeeksLater.setDate(firstDay.getDate() + 14)
                if (twoWeeksLater.getMonth() === cur.getMonth()) {
                    monthLabel = monthNames[cur.getMonth()]
                }
            }

            var countVal = entry.count || 0
            var level = 0
            if (countVal >= 7) level = 4
            else if (countVal >= 5) level = 3
            else if (countVal >= 3) level = 2
            else if (countVal >= 1) level = 1

            days.push({
                date: dateStr,
                label: dayNames[d] + ", " + monthNames[cur.getMonth()] + " " + cur.getDate(),
                count: countVal,
                minutes: entry.minutes || 0,
                level: level,
                isToday: dateStr === todayStr,
                isFuture: isFuture
            })
        }
        weeks.push({
            monthLabel: monthLabel,
            days: days
        })
    }
    return weeks
    }

    // helpers
    function format_time(seconds) {
    var m = Math.floor(seconds / 60)
    var s = seconds % 60
    return String(m).padStart(2, '0') + ":" + String(s).padStart(2, '0')
    }

    function format_bar_icon(seconds, isTimerRunning, showSeconds) {
    if (!isTimerRunning) {
        return "\ue001"
    }
    var useSeconds = (showSeconds !== undefined) ? showSeconds : root.showSecondsInBar
    var m = Math.floor(seconds / 60)
    var s = seconds % 60
    if (!useSeconds) {
        if (m === 0) return String(s).padStart(2, '0')
        return String(m)
    }
    return "[" + String(m).padStart(2, '0') + ":" + String(s).padStart(2, '0') + "]"
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
        default:           return root.currentTask ? extractTaskTag(root.currentTask.name).cleanName : "Focus!"
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
    var taskObj = normalizeTaskObject({
        name: trimmed,
        estimated: estimated || 1,
        completed: 0,
        done: false,
        completedAt: "",
        focusMinutes: 0
    }, taskModel.count)
    taskModel.append(taskObj)
    root.updateCurrentTask()
    root.historyRevision += 1
    saveState()
    }

    function removeTask(index) {
    if (index >= 0 && index < taskModel.count) {
        var item = taskModel.get(index)
        if (item && item.id) {
            syncTaskToHistory(item)
        }
        taskModel.remove(index)
        root.updateCurrentTask()
        root.historyRevision += 1
        saveState()
    }
    }

    function toggleTaskDone(index) {
    if (index >= 0 && index < taskModel.count) {
        var item = taskModel.get(index)
        var nextDone = !Boolean(item.done)
        var nextCompletedAt = nextDone ? todayString() : ""
        taskModel.setProperty(index, "done", nextDone)
        taskModel.setProperty(index, "completedAt", nextCompletedAt)
        syncTaskToHistory(taskModel.get(index))
        root.updateCurrentTask()
        root.historyRevision += 1
        saveState()
    }
    }

    function adjustTaskEstimate(index, delta) {
    if (index >= 0 && index < taskModel.count) {
        var item = taskModel.get(index)
        var prevEstimated = item.estimated || 1
        var nextEstimated = Math.max(1, prevEstimated + (delta || 0))
        if (nextEstimated === prevEstimated) return

        var comp = item.completed || 0
        taskModel.setProperty(index, "estimated", nextEstimated)

        if (!item.done && comp > 0 && comp >= nextEstimated) {
            taskModel.setProperty(index, "done", true)
            taskModel.setProperty(index, "completedAt", todayString())
        } else if (item.done && comp >= prevEstimated && comp < nextEstimated) {
            taskModel.setProperty(index, "done", false)
            taskModel.setProperty(index, "completedAt", "")
        }

        syncTaskToHistory(taskModel.get(index))
        root.updateCurrentTask()
        root.historyRevision += 1
        saveState()
    }
    }

    function incrementTask(index, minsOverride) {
    if (index >= 0 && index < taskModel.count) {
        var item = taskModel.get(index)
        var prevCompleted = item.completed || 0
        var nextCompleted = prevCompleted + 1
        var addMins = (minsOverride !== undefined && minsOverride > 0)
            ? minsOverride
            : Math.max(1, Math.round(root.workTime / 60))
        var nextMins = (item.focusMinutes || (prevCompleted * addMins)) + addMins

        taskModel.setProperty(index, "completed", nextCompleted)
        taskModel.setProperty(index, "focusMinutes", nextMins)

        if (!item.done && prevCompleted < item.estimated && nextCompleted >= item.estimated) {
            taskModel.setProperty(index, "done", true)
            taskModel.setProperty(index, "completedAt", todayString())
        } else if (item.done && (!item.completedAt || item.completedAt === "")) {
            taskModel.setProperty(index, "completedAt", todayString())
        }

        syncTaskToHistory(taskModel.get(index))
        root.updateCurrentTask()
        root.historyRevision += 1
        saveState()
    }
    }

    function getTaskStats() {
    var todayStr = todayString()
    var now = new Date()
    now.setHours(12, 0, 0, 0)
    var dow = (now.getDay() + 6) % 7 // Mon=0 .. Sun=6
    var startOfThisWeek = new Date(now)
    startOfThisWeek.setDate(now.getDate() - dow)
    var thisWeekStartStr = Qt.formatDate(startOfThisWeek, "yyyy-MM-dd")

    var startOfLastWeek = new Date(startOfThisWeek)
    startOfLastWeek.setDate(startOfThisWeek.getDate() - 7)
    var endOfLastWeek = new Date(startOfThisWeek)
    endOfLastWeek.setDate(startOfThisWeek.getDate() - 1)
    var lastWeekStartStr = Qt.formatDate(startOfLastWeek, "yyyy-MM-dd")
    var lastWeekEndStr = Qt.formatDate(endOfLastWeek, "yyyy-MM-dd")

    var thisMonthPrefix = todayStr.substr(0, 7)
    var defaultPomoMins = Math.max(1, Math.round(root.workTime / 60))

    var unifiedMap = {}
    var hist = root.taskHistory || {}
    for (var hid in hist) {
        if (!hist[hid]) continue
        unifiedMap[hid] = Object.assign({}, hist[hid], { inQueue: false })
    }

    var activeDoneCount = 0
    var activeTotalCount = taskModel.count
    var remainingPomodoros = 0

    for (var i = 0; i < taskModel.count; i++) {
        var t = taskModel.get(i)
        if (!t) continue
        var tid = t.id || ("live_" + i)
        var parsed = extractTaskTag(t.name)
        var isDone = Boolean(t.done)
        var comp = Math.max(0, t.completed || 0)
        var est = Math.max(1, t.estimated || 1)
        var mins = (t.focusMinutes && t.focusMinutes > 0) ? t.focusMinutes : (comp * defaultPomoMins)
        var prevHist = unifiedMap[tid] || {}
        var compAt = isDone ? (t.completedAt || prevHist.completedAt || root.lastActiveDate || todayStr) : ""

        if (isDone) activeDoneCount += 1
        else remainingPomodoros += Math.max(0, est - comp)

        unifiedMap[tid] = {
            id: tid,
            name: t.name,
            cleanName: parsed.cleanName,
            tag: parsed.tag,
            estimated: est,
            completed: comp,
            focusMinutes: mins,
            done: isDone,
            completedAt: compAt,
            inQueue: true
        }
    }

    var allTasks = []
    for (var uid in unifiedMap) {
        var entry = unifiedMap[uid]
        if (!entry) continue
        var p = extractTaskTag(entry.name)
        entry.cleanName = p.cleanName
        entry.tag = (p.tag || String(entry.tag || "")).replace(/^#+/, "")
        allTasks.push(entry)
    }

    var completedThisWeek = 0
    var completedLastWeek = 0
    var completedThisMonth = 0
    var completedAllTime = 0
    var donePomodorosTotal = 0
    var doneTasksByDate = {}

    for (var k = 0; k < allTasks.length; k++) {
        var tk = allTasks[k]
        if (tk.done) {
            completedAllTime += 1
            donePomodorosTotal += tk.completed
            var cDate = tk.completedAt || todayStr
            doneTasksByDate[cDate] = (doneTasksByDate[cDate] || 0) + 1
            if (cDate >= thisWeekStartStr && cDate <= todayStr) {
                completedThisWeek += 1
            } else if (cDate >= lastWeekStartStr && cDate <= lastWeekEndStr) {
                completedLastWeek += 1
            }
            if (cDate.indexOf(thisMonthPrefix) === 0) {
                completedThisMonth += 1
            }
        }
    }

    var shortDayNames = ["M", "T", "W", "T", "F", "S", "S"]
    var fullDayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    var weekDays = []
    var maxDailyTasks = 1
    var pomodorosThisWeek = 0

    for (var d = 0; d < 7; d++) {
        var curDay = new Date(startOfThisWeek)
        curDay.setDate(startOfThisWeek.getDate() + d)
        var dStr = Qt.formatDate(curDay, "yyyy-MM-dd")
        var isFut = dStr > todayStr
        var tDone = isFut ? 0 : (doneTasksByDate[dStr] || 0)
        var dHist = (!isFut && root.dailyHistory && root.dailyHistory[dStr]) ? root.dailyHistory[dStr] : { count: 0, minutes: 0 }
        var pCount = dHist.count || 0
        pomodorosThisWeek += pCount
        if (tDone > maxDailyTasks) maxDailyTasks = tDone
        weekDays.push({
            dayLabel: shortDayNames[d],
            fullLabel: fullDayNames[d],
            date: dStr,
            tasksDone: tDone,
            pomodoros: pCount,
            isToday: dStr === todayStr,
            isFuture: isFut
        })
    }
    for (var wd = 0; wd < weekDays.length; wd++) {
        weekDays[wd].ratio = weekDays[wd].tasksDone > 0 ? (weekDays[wd].tasksDone / maxDailyTasks) : 0
    }

    var activeClearPct = activeTotalCount > 0 ? Math.round((activeDoneCount / activeTotalCount) * 100) : 0
    var avgPomosPerTask = completedAllTime > 0 ? (donePomodorosTotal / completedAllTime).toFixed(1) : "0.0"
    var weekDelta = completedThisWeek - completedLastWeek

    var velocityHeadline = ""
    var velocitySubline = ""
    if (activeTotalCount > 0 && activeDoneCount === activeTotalCount) {
        velocityHeadline = "All " + activeTotalCount + " queued tasks completed!"
        velocitySubline = completedThisWeek + " finished this week · Queue 100% clear"
    } else if (completedThisWeek > 0) {
        velocityHeadline = completedThisWeek + (completedThisWeek === 1 ? " task crushed this week" : " tasks crushed this week")
        velocitySubline = remainingPomodoros > 0
            ? (remainingPomodoros + " \ue001 est. remaining in active queue")
            : (completedThisMonth + " completed this month · " + completedAllTime + " all-time")
    } else if (activeTotalCount > 0) {
        velocityHeadline = (activeTotalCount - activeDoneCount) + " active " + ((activeTotalCount - activeDoneCount) === 1 ? "task" : "tasks") + " in queue"
        velocitySubline = remainingPomodoros + " \ue001 estimated to clear current queue"
    } else {
        velocityHeadline = "Ready for your next sprint"
        velocitySubline = "Add tasks with pomodoro estimates to track velocity"
    }

    var workedTasks = []
    var hasTags = false
    for (var b = 0; b < allTasks.length; b++) {
        if (allTasks[b].tag && allTasks[b].tag !== "") hasTags = true
        if (allTasks[b].completed > 0 || allTasks[b].inQueue) {
            workedTasks.push(allTasks[b])
        }
    }

    workedTasks.sort(function(a, bItem) {
        if (bItem.completed !== a.completed) return bItem.completed - a.completed
        if (bItem.focusMinutes !== a.focusMinutes) return bItem.focusMinutes - a.focusMinutes
        return bItem.estimated - a.estimated
    })

    var totalTaskPomos = 0
    var totalTaskMins = 0
    var maxTaskPomos = 0
    for (var wIdx = 0; wIdx < workedTasks.length; wIdx++) {
        totalTaskPomos += workedTasks[wIdx].completed
        totalTaskMins += workedTasks[wIdx].focusMinutes
        if (workedTasks[wIdx].completed > maxTaskPomos) maxTaskPomos = workedTasks[wIdx].completed
    }
    if (maxTaskPomos <= 0) maxTaskPomos = 1

    var topTaskRows = []
    var maxVisibleTasks = 6
    var otherCompleted = 0
    var otherEstimated = 0
    var otherMins = 0
    var otherCount = 0

    for (var r = 0; r < workedTasks.length; r++) {
        var wt = workedTasks[r]
        if (r < maxVisibleTasks) {
            var share = totalTaskPomos > 0
                ? Math.round((wt.completed / totalTaskPomos) * 100)
                : 0
            topTaskRows.push({
                id: wt.id,
                name: wt.name,
                cleanName: wt.cleanName,
                tag: wt.tag,
                completed: wt.completed,
                estimated: wt.estimated,
                focusMinutes: wt.focusMinutes,
                done: wt.done,
                sharePct: share,
                barRatio: Math.min(1.0, wt.completed / maxTaskPomos)
            })
        } else {
            otherCompleted += wt.completed
            otherEstimated += wt.estimated
            otherMins += wt.focusMinutes
            otherCount += 1
        }
    }

    if (otherCount > 0 && otherCompleted > 0) {
        topTaskRows.push({
            id: "other_rollup",
            name: "+" + otherCount + " more " + (otherCount === 1 ? "task" : "tasks"),
            cleanName: "+" + otherCount + " more " + (otherCount === 1 ? "task" : "tasks"),
            tag: "",
            completed: otherCompleted,
            estimated: otherEstimated,
            focusMinutes: otherMins,
            done: false,
            sharePct: totalTaskPomos > 0 ? Math.max(1, Math.round((otherCompleted / totalTaskPomos) * 100)) : 0,
            barRatio: Math.min(1.0, otherCompleted / maxTaskPomos)
        })
    }

    var tagGroups = {}
    for (var g = 0; g < workedTasks.length; g++) {
        var gt = workedTasks[g]
        var tKey = (gt.tag && gt.tag !== "") ? gt.tag : "Untagged"
        if (!tagGroups[tKey]) {
            tagGroups[tKey] = {
                name: tKey,
                cleanName: tKey,
                tag: tKey === "Untagged" ? "" : tKey,
                completed: 0,
                estimated: 0,
                focusMinutes: 0,
                taskCount: 0,
                doneCount: 0
            }
        }
        tagGroups[tKey].completed += gt.completed
        tagGroups[tKey].estimated += gt.estimated
        tagGroups[tKey].focusMinutes += gt.focusMinutes
        tagGroups[tKey].taskCount += 1
        if (gt.done) tagGroups[tKey].doneCount += 1
    }

    var tagRows = []
    var maxTagPomos = 1
    for (var tkName in tagGroups) {
        var tg = tagGroups[tkName]
        if (tg.completed > maxTagPomos) maxTagPomos = tg.completed
        tagRows.push(tg)
    }
    tagRows.sort(function(a, bItem) {
        if (bItem.completed !== a.completed) return bItem.completed - a.completed
        return bItem.estimated - a.estimated
    })
    for (var tr = 0; tr < tagRows.length; tr++) {
        var row = tagRows[tr]
        row.sharePct = totalTaskPomos > 0 ? Math.round((row.completed / totalTaskPomos) * 100) : 0
        row.barRatio = Math.min(1.0, row.completed / maxTagPomos)
        row.done = (row.doneCount === row.taskCount && row.taskCount > 0)
    }

    return {
        velocity: {
            completedThisWeek: completedThisWeek,
            completedLastWeek: completedLastWeek,
            weekDelta: weekDelta,
            completedThisMonth: completedThisMonth,
            completedAllTime: completedAllTime,
            pomodorosThisWeek: pomodorosThisWeek,
            activeDoneCount: activeDoneCount,
            activeTotalCount: activeTotalCount,
            activeClearPct: activeClearPct,
            remainingPomodoros: remainingPomodoros,
            weekDays: weekDays,
            headline: velocityHeadline,
            subline: velocitySubline
        },
        breakdown: {
            hasTags: hasTags,
            totalPomodoros: totalTaskPomos,
            totalMinutes: totalTaskMins,
            tasks: topTaskRows,
            tags: tagRows
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