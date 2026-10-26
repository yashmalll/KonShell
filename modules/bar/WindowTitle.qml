import QtQuick
import qs.config
import qs.services
import qs.widgets

StyledText {
    text: Niri.focusedWindow?.title ?? ""
    color: Theme.color.textMuted
}
