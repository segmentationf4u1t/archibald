pragma Singleton

import Quickshell

// Starts programs from the bar without the bar's own process settings: QT_QUICK_BACKEND=software
// (shell.qml) and MALLOC_CONF (set where the bar is started) are removed by `env -u`. The argv
// form of execDetached is used because Quickshell can not convert a JS object to its context form.
Singleton {
    function exec(command) {
        Quickshell.execDetached(["env", "-u", "QT_QUICK_BACKEND", "-u", "MALLOC_CONF"].concat(command));
    }
}
