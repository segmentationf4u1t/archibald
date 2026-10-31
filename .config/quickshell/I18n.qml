pragma Singleton

import QtQuick
import Quickshell

// UI language. English is the source language (the strings in the code); every other language is a
// table keyed by the English text, missing entries fall back to English.
// Follows the system locale (LANG); override with QS_LANG, e.g. hl.env("QS_LANG", "pl") in hyprland.lua.
Singleton {
    readonly property var locale: Quickshell.env("QS_LANG") ? Qt.locale(Quickshell.env("QS_LANG")) : Qt.locale()
    readonly property string language: locale.name.split("_")[0]
    readonly property var table: translations[language] ?? ({})

    // tr("Uptime: %1", value): %1..%n are replaced by the extra arguments
    function tr(text, ...args) {
        let s = table[text] ?? text;
        args.forEach((arg, i) => s = s.replace("%" + (i + 1), arg));
        return s;
    }

    readonly property var translations: ({
        pl: {
            // shared
            "Advanced… (%1)": "Zaawansowane… (%1)",
            "Connected": "Połączono",
            "Disconnected": "Rozłączono",
            "usage": "użycie",
            "Processes": "Procesy",
            "System monitor…": "Monitor systemu…",
            // audio
            "Output": "Wyjście",
            "No output device": "Brak urządzenia wyjściowego",
            "Input": "Wejście",
            "No input device": "Brak urządzenia wejściowego",
            "Applications": "Aplikacje",
            "Nothing is playing": "Brak odtwarzania",
            // bluetooth
            "Connecting…": "Łączenie…",
            "Disconnecting…": "Rozłączanie…",
            "No Bluetooth adapter": "Brak adaptera Bluetooth",
            "Bluetooth is blocked (rfkill). Unblock it to use devices.": "Bluetooth jest zablokowany (rfkill). Odblokuj go, aby korzystać z urządzeń.",
            "Turning on…": "Włączanie…",
            "Turning off…": "Wyłączanie…",
            "Bluetooth is off. Turn it on to connect devices.": "Bluetooth jest wyłączony. Włącz go, aby połączyć urządzenia.",
            "Devices": "Urządzenia",
            "No paired devices": "Brak sparowanych urządzeń",
            "Available": "Dostępne",
            "Searching for devices…": "Szukanie urządzeń…",
            "Search to find new devices": "Wyszukaj, aby znaleźć nowe urządzenia",
            "Pairing…": "Parowanie…",
            "Click to pair · %1": "Kliknij, aby sparować · %1",
            // network
            "Network portal login required": "Wymagane logowanie w portalu sieciowym",
            "Limited connectivity – no internet access": "Ograniczona łączność – brak dostępu do internetu",
            "No internet connection": "Brak łączności z internetem",
            "Password missing or incorrect": "Brak hasła lub hasło jest nieprawidłowe",
            "Wi‑Fi connection error": "Błąd połączenia Wi‑Fi",
            "Authentication timed out": "Przekroczono czas uwierzytelniania",
            "Network is out of range": "Sieć jest poza zasięgiem",
            "Could not connect": "Nie udało się połączyć",
            "Wired": "Przewodowa",
            "Wi‑Fi is disabled by a hardware switch": "Wi‑Fi wyłączone sprzętowo",
            "Wi‑Fi is off": "Wi‑Fi jest wyłączone",
            "Not connected": "Brak połączenia",
            "Networks": "Sieci",
            "Scanning for networks…": "Szukam sieci…",
            "No Wi‑Fi adapter": "Brak karty Wi‑Fi",
            "Enterprise network – set it up in nmtui": "Sieć korporacyjna – skonfiguruj ją w nmtui",
            "Saved": "Zapisana",
            "Password": "Hasło",
            "Connect": "Połącz",
            // cpu
            "Processor": "Procesor",
            "Avg clock": "Zegar śr.",
            "Max clock": "Zegar maks.",
            "Load 1/5/15": "Obciążenie 1/5/15",
            "temperature": "temperatura",
            "Threads (%1)": "Wątki (%1)",
            "Cores": "Rdzenie",
            "Uptime: %1": "Czas pracy: %1",
            // memory
            "Memory": "Pamięć",
            "Used": "Używana",
            "Buffers": "Bufory",
            "Free": "Wolna",
            "No swap": "Brak swapu",
            "Total: %1": "Razem: %1",
            // gpu
            "Power draw": "Pobór mocy",
            "Fan": "Wentylator",
            "No GPU data": "Brak danych GPU",
            // disks
            "Disks": "Dyski",
            "Read %1 · write %2": "Odczyt %1 · zapis %2",
            "R": "O",
            "W": "Z",
            "Total read": "Odczytano",
            "Total written": "Zapisano",
            "No disks found": "Nie znaleziono dysków",
            "Filesystems": "Systemy plików"
        }
    })
}
