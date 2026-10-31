#pragma once

#include <QFuture>
#include <QHash>
#include <QMutex>
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

#include <atomic>

#include "procs.h"

// QML singleton "Native" of the QsNative module; see native/bridge.qml.
class Native : public QObject {
    Q_OBJECT
public:
    explicit Native(QObject* parent = nullptr);
    ~Native() override;

    // Take a process sample on a worker thread; false when one is already in flight. The result is
    // delivered as `sampled` on the calling thread, so a sample never stalls the UI.
    Q_INVOKABLE bool sample();
    Q_INVOKABLE void reset();
    Q_INVOKABLE QVariantList gpuUtil();
    Q_INVOKABLE QVariantList gpuDetail();

signals:
    void sampled(const QVariantMap& result);

private:
    struct ProcState {
        QHash<int, ProcTick> prev;
        double prevUptime = 0;
        bool hasPrev = false;
    };

    ProcState m_proc;   // only under m_procMutex: the worker reads and replaces it
    QMutex m_procMutex;
    std::atomic<bool> m_busy {false};
    QFuture<void> m_worker;
};
