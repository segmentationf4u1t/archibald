import QtQuick
import Quickshell
import Quickshell.Services.Greetd

// greetd conversation: createSession(user) -> authMessage(responseRequired) -> respond(password)
// -> state ReadyToLaunch -> launch(command, environment), after which quickshell exits and greetd
// starts the session. A bad password ends the greetd session (authFailure); the next attempt
// creates a new one. Extra PAM prompts (e.g. a second factor) are shown as the field's placeholder.
Scope {
    id: auth

    property var command: []
    property var environment: []

    property bool busy: false          // waiting for greetd
    property bool launching: false     // authenticated, fading out before launch()
    property bool failed: false        // last attempt failed: red field, shake
    property string message: ""        // text under the field (error or PAM info)
    property string prompt: ""         // extra PAM prompt; empty = normal password field
    property bool promptEcho: false    // the extra prompt's answer may be shown in clear text

    signal failure()

    property string _pending: ""
    property bool _havePending: false  // password typed before greetd asked for it
    property bool _awaiting: false     // greetd asked for a response that the user has to type

    function submit(user, text) {
        if (launching)
            return;
        failed = false;
        message = "";
        if (_awaiting) {
            _awaiting = false;
            prompt = "";
            busy = true;
            Greetd.respond(text);
            return;
        }
        // an empty Enter would be a failed PAM attempt, and pam_faillock locks the account after 3
        if (busy || user === "" || text === "")
            return;
        busy = true;
        _pending = text;
        _havePending = true;
        Greetd.createSession(user);
    }

    function _fail(text) {
        busy = false;
        _awaiting = false;
        _havePending = false;
        _pending = "";
        prompt = "";
        failed = true;
        message = text;
        failure();
    }

    Connections {
        target: Greetd

        function onAuthMessage(text, error, responseRequired, echoResponse) {
            if (responseRequired) {
                if (auth._havePending) {
                    const response = auth._pending;
                    auth._havePending = false;
                    auth._pending = "";
                    Greetd.respond(response);
                } else {
                    auth.prompt = text;
                    auth.promptEcho = echoResponse;
                    auth._awaiting = true;
                    auth.busy = false;
                }
            } else {
                auth.message = text;   // PAM info or a recoverable error (e.g. fingerprint misread)
            }
        }

        function onAuthFailure(text) {
            auth._fail("Nieprawidłowe hasło");
        }

        function onError(text) {
            auth._fail(text);
        }

        function onStateChanged() {
            if (Greetd.state === GreetdState.ReadyToLaunch) {
                auth.busy = false;
                auth.launching = true;
                launchTimer.start();
            }
        }
    }

    // Fade out first: greetd expects the greeter to exit right after launch().
    Timer {
        id: launchTimer
        interval: 350
        onTriggered: Greetd.launch(auth.command, auth.environment)
    }
}
