import QtQuick
import QtCore
import Qt.labs.folderlistmodel

// Emits changed() when ~/.config/poseidonos/<file> is written (the settings
// panel writes a temp file and renames it over the old one). Uses the inotify
// directory watch inside FolderListModel, so nothing is polled.
Item {
    id: w
    visible: false
    property string file: "desktop.json"
    signal changed()
    FolderListModel {
        id: fm
        folder: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/poseidonos"
        nameFilters: [w.file]
        showDirs: false
        showHidden: true
        onDataChanged: deb.restart()
        onRowsInserted: deb.restart()
        onRowsRemoved: deb.restart()
        onModelReset: deb.restart()
    }
    Timer { id: deb; interval: 150; onTriggered: w.changed() }
}
