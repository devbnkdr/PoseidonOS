import QtQuick
import QtQuick.Window
import org.kde.taskmanager as TaskManager

// covered == a maximized or fullscreen window (not minimized, on the current virtual
// desktop and activity) sits on this item's screen, i.e. nobody can see the desktop.
// Used to pause animations and polling while the desktop is hidden.
Item {
    id: cw
    visible: false
    property bool active: true
    property bool _covered: false
    readonly property bool covered: active && _covered
    readonly property rect screenRect: Qt.rect(Screen.virtualX, Screen.virtualY, Screen.width, Screen.height)

    TaskManager.VirtualDesktopInfo { id: vd }
    TaskManager.ActivityInfo { id: act }
    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByScreen: true
        screenGeometry: cw.screenRect
        filterByVirtualDesktop: true
        virtualDesktop: vd.currentDesktop
        filterByActivity: true
        activity: act.currentActivity
        onDataChanged: recheck.restart()
        onCountChanged: recheck.restart()
        onModelReset: recheck.restart()
    }
    Timer { id: recheck; interval: 250; onTriggered: cw.evaluate() }
    function evaluate() {
        var c = false;
        for (var i = 0; i < tasks.count; i++) {
            var ix = tasks.index(i, 0);
            if (tasks.data(ix, TaskManager.AbstractTasksModel.IsMinimized)) continue;
            if (tasks.data(ix, TaskManager.AbstractTasksModel.IsMaximized)
                || tasks.data(ix, TaskManager.AbstractTasksModel.IsFullScreen)) { c = true; break; }
        }
        cw._covered = c;
    }
    onScreenRectChanged: recheck.restart()
    Component.onCompleted: recheck.restart()
}
