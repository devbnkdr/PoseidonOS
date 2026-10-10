import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    property string cfg_note
    QQC2.Label {
        Kirigami.FormData.label: i18n("Settings:")
        text: i18n("Use the [ CFG ] button on the taskbar to change the flow, dots and emblem.")
        wrapMode: Text.WordWrap
    }
}
