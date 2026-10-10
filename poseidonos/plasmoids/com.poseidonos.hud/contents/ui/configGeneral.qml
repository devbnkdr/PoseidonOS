import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_gridSections: sectionsField.text
    property alias cfg_fontSize: fontSpin.value
    property alias cfg_gridCompact: compactField.text
    property alias cfg_bottomSections: bottomField.text
    property alias cfg_solidBlock: solidBox.checked
    property alias cfg_columns: colSpin.value
    property alias cfg_terminal: termBox.checked
    property string cfg_terminalMode
    Kirigami.FormLayout {
        QQC2.TextField {
            id: sectionsField
            Kirigami.FormData.label: i18n("Sections (in order):")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 28
        }
        QQC2.Label { text: i18n("profile, weather, clock, vitals, net, procs, disks, files, media, notes  (| starts a new column)"); opacity: 0.7 }
        QQC2.TextField {
            id: bottomField
            Kirigami.FormData.label: i18n("Full-width above terminal:")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 28
        }
        QQC2.CheckBox { id: solidBox; Kirigami.FormData.label: i18n("Style:"); text: i18n("One solid block (no gaps)") }
        QQC2.TextField {
            id: compactField
            Kirigami.FormData.label: i18n("Sections when only 1 column fits:")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 28
        }
        QQC2.SpinBox { id: colSpin; from: 0; to: 6; Kirigami.FormData.label: i18n("Columns (0 = auto):") }
        QQC2.SpinBox { id: fontSpin; from: 10; to: 40; Kirigami.FormData.label: i18n("Font size:") }
        QQC2.CheckBox { id: termBox; Kirigami.FormData.label: i18n("Terminal:"); text: i18n("Show TERMLINK terminal") }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Terminal engine:")
            model: [i18n("Real shell if QMLTermWidget is installed"), i18n("Built-in command console")]
            currentIndex: cfg_terminalMode === "builtin" ? 1 : 0
            onActivated: cfg_terminalMode = currentIndex === 1 ? "builtin" : "auto"
        }
    }
}
