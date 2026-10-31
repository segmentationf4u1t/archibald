#include <QObject>
#include <QQmlEngine>
#include <QQmlExtensionPlugin>
#include <qqml.h>

#include "native.h"

class NativePlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char* uri) override {
        qmlRegisterSingletonType<Native>(uri, 1, 0, "Native", [](QQmlEngine*, QJSEngine*) -> QObject* {
            return new Native();
        });
    }
};

#include "plugin.moc"
