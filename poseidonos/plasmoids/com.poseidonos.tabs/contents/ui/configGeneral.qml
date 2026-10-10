import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property string cfg_tabs
    property alias cfg_fontFamily: fontField.text
    property alias cfg_glow: glowBox.checked
    property alias cfg_showHints: hintBox.checked

    Kirigami.FormLayout {
        QQC2.TextArea {
            id: tabsArea
            Kirigami.FormData.label: i18n("Tabs (one per line, LABEL:hint|command):")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 30
            Layout.minimumHeight: Kirigami.Units.gridUnit * 8
            font.family: "monospace"
            wrapMode: TextEdit.NoWrap
            text: cfg_tabs.split(";;").join("\n")
            onTextChanged: cfg_tabs = text.split("\n").filter(l => l.trim().length > 0).join(";;")
        }
        QQC2.TextField {
            id: fontField
            Kirigami.FormData.label: i18n("Font family:")
        }
        QQC2.CheckBox {
            id: hintBox
            Kirigami.FormData.label: i18n("Show what each tab does:")
        }
        QQC2.CheckBox {
            id: glowBox
            Kirigami.FormData.label: i18n("Phosphor glow:")
        }
    }
}
