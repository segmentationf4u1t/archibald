pragma Singleton

import Quickshell

// Starts programs from the bar. This process renders with the software scene graph (shell.qml sets
// QT_QUICK_BACKEND=software); launched programs must not inherit that, so it is removed from their
// environment (a null value unsets the variable).
Singleton {
    function exec(command) {
        Quickshell.execDetached({ command: command, environment: { QT_QUICK_BACKEND: null } });
    }
}
