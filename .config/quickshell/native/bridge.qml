// Loaded by services/SysStats.qml with an absolute file:// URL: a directory import of a C++ module is
// resolved through the real file system, while the config's own QML files live under qs: URLs, from
// which a plugin library can not be loaded.
import QtQuick
import "QsNative"

QtObject {
    readonly property var api: Native
}
