/*
    SPDX-FileCopyrightText: 2013-2016 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <KConfigWatcher>

#include <QHash>
#include <QObject>
#include <QRect>
#include <QSet>

#include <netwm.h>
#include <qqmlregistration.h>
#include <qwindowdefs.h>

#include "kactivitymanagerd_plugins_settings.h"

class QAction;
class QActionGroup;
class QFileSystemWatcher;
class QQuickItem;
class QQuickWindow;
class QJsonArray;
class QSocketNotifier;
class QTimer;
class QWindow;

namespace KActivities
{
class Consumer;
}

class Backend : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_CLASSINFO("D-Bus Interface", "org.kde.plasmashell.WavetaskMeta")

public:
    enum MiddleClickAction {
        None = 0,
        Close,
        NewInstance,
        ToggleMinimized,
        ToggleGrouping,
        BringToCurrentDesktop,
    };

    Q_ENUM(MiddleClickAction)

    Q_PROPERTY(bool metaKeyHeld READ isMetaKeyHeld NOTIFY metaKeyHeldChanged)

    // Whether the compositor is currently in "show desktop" mode (Win+D).
    // Toggling it drops the blur behind panels, so QML watches this to re-apply it.
    Q_PROPERTY(bool showingDesktop READ isShowingDesktop NOTIFY showingDesktopChanged)

    explicit Backend(QObject *parent = nullptr);
    ~Backend() override;

    Q_INVOKABLE QVariantList jumpListActions(const QUrl &launcherUrl, QObject *parent);
    Q_INVOKABLE QVariantList placesActions(const QUrl &launcherUrl, bool showAllPlaces, QObject *parent);
    Q_INVOKABLE QVariantList recentDocumentActions(const QUrl &launcherUrl, QObject *parent);
    Q_INVOKABLE void setActionGroup(QAction *action) const;
    Q_INVOKABLE void setBlurBehind(QWindow *window, bool enable, int x, int y, int w, int h, int radius);

    Q_INVOKABLE QRect globalRect(QQuickItem *item) const;

    Q_INVOKABLE bool isApplication(const QUrl &url) const;

    Q_INVOKABLE qint64 parentPid(qint64 pid) const;

    Q_INVOKABLE static QUrl tryDecodeApplicationsUrl(const QUrl &launcherUrl);
    Q_INVOKABLE static QStringList applicationCategories(const QUrl &launcherUrl);

    bool isMetaKeyHeld() const;

    bool isShowingDesktop() const;

Q_SIGNALS:
    void addLauncher(const QUrl &url) const;

    void showAllPlaces();
    void metaKeyHeldChanged();
    void showingDesktopChanged();

public Q_SLOTS:
    Q_SCRIPTABLE void metaKeyPressed();
    Q_SCRIPTABLE void metaKeyReleased();

private Q_SLOTS:
    void handleRecentDocumentAction() const;

private:
    QVariantList systemSettingsActions(QObject *parent) const;

    QActionGroup *m_actionGroup = nullptr;
    KActivities::Consumer *m_activitiesConsumer = nullptr;

    KActivityManagerdPluginsSettings m_activityManagerPluginsSettings;
    KConfigWatcher::Ptr m_activityManagerPluginsSettingsWatcher;

    // Meta key detection via /dev/input monitoring
    void setMetaKeyHeld(bool held);
    void initInputMonitor();
    void scanInputDevices();
    void pruneProbedPaths();
    void onInputEvent(int fd);
    void removeInputDevice(int fd);

    struct InputDeviceMonitor {
        QString path;
        QSocketNotifier *notifier = nullptr;
    };

    bool m_metaKeyHeld = false;
    QFileSystemWatcher *m_inputDirWatcher = nullptr;
    QTimer *m_inputSettleTimer = nullptr;
    QHash<int, InputDeviceMonitor> m_inputMonitors;
    QSet<QString> m_probedPaths;
};
