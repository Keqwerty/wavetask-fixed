/*
    SPDX-FileCopyrightText: 2012-2016 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg as KSvg
import org.kde.plasma.private.mpris as Mpris
import org.kde.kirigami as Kirigami

import org.kde.plasma.workspace.trianglemousefilter

import org.kde.taskmanager as TaskManager
import org.vicko.wavetask as TaskManagerApplet
import org.kde.plasma.workspace.dbus as DBus

import "code/LayoutMetrics.js" as LayoutMetrics
import "code/TaskTools.js" as TaskTools

PlasmoidItem {
    id: tasks

    // For making a bottom to top layout since qml flow can't do that.
    // We just hang the task manager upside down to achieve that.
    // This mirrors the tasks and group dialog as well, so we un-rotate them
    // to fix that (see Task.qml and GroupDialog.qml).
    rotation: Plasmoid.configuration.reverseMode && Plasmoid.formFactor === PlasmaCore.Types.Vertical ? 180 : 0

    readonly property bool shouldShrinkToZero: tasksModel.count === 0
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool iconsOnly: Plasmoid.pluginName === "org.vicko.wavetask"

    property Task toolTipOpenedByClick
    property Task toolTipAreaItem

    readonly property Component contextMenuComponent: Qt.createComponent("ContextMenu.qml")
    readonly property Component pulseAudioComponent: Qt.createComponent("PulseAudio.qml")

    property alias taskList: taskList
    property alias taskRepeater: taskRepeater

    readonly property bool metaKeyHeld: backend.metaKeyHeld
    readonly property bool metaFeaturesEnabled: Plasmoid.configuration.showOnMetaKey
                                                || Plasmoid.configuration.showTaskNumbersOnMeta

    // --- META KEY DOCK VISIBILITY ---
    property bool metaShowActive: false

    // Reset timer: hides dock and numbers after Meta is no longer detected
    Timer {
        id: metaResetTimer
        interval: 500
        repeat: false
        onTriggered: {
            console.log("QML: metaResetTimer fired, hiding dock/numbers");
            tasks.metaShowActive = false;
        }
    }

    // Refresh timer: while Meta is still held, keep restarting the reset timer
    Timer {
        id: metaRefreshTimer
        interval: 200
        repeat: true
        running: tasks.metaShowActive
        onTriggered: {
            if (backend.metaKeyHeld) {
                metaResetTimer.restart();
            }
        }
    }

    Connections {
        target: backend
        function onMetaKeyHeldChanged() {
            console.log("QML: onMetaKeyHeldChanged, held=" + backend.metaKeyHeld);
            if (backend.metaKeyHeld && Plasmoid.configuration.showOnMetaKey) {
                tasks.metaShowActive = true;
                metaResetTimer.restart();
            }
        }
    }

    readonly property bool isTopPanel: Plasmoid.location === PlasmaCore.Types.TopEdge
    readonly property bool isLeftPanel: Plasmoid.location === PlasmaCore.Types.LeftEdge

    preferredRepresentation: fullRepresentation

  //  Plasmoid.constraintHints: Plasmoid.CanFillArea

  // --- LÓGICA DE TRANSPARENCIA ---
  property Item containmentItem: null
  readonly property int depth: 14
  property bool isBackgroundDisabled: true

  function lookForContainer(object, tries) {
      if (tries === 0 || object === null) return;
      // busca el panel
      if (object.toString().indexOf("ContainmentItem_QML") > -1) {
          tasks.containmentItem = object;
          console.log("Contenedor encontrado en el intento: " + (depth - tries));
          console.log("containment width:", tasks.containmentItem.width)
          console.log("containment height:", tasks.containmentItem.height)

      } else {
          lookForContainer(object.parent, tries - 1);
      }
  }

  function applyBackgroundHint() {
      if (tasks.containmentItem === null) lookForContainer(tasks.parent, depth);
      if (tasks.containmentItem === null) return;

      // Aplicamos el NoBackground (0) o Default (1)
      tasks.containmentItem.Plasmoid.backgroundHints = (isBackgroundDisabled) ? 0 : 1;

      // También lo aplicamos al objeto raíz por si acaso
      tasks.Plasmoid.backgroundHints = (isBackgroundDisabled) ? 0 : 1;
  }

  // --- LÓGICA DE SKINS ---
  property int topoutimage: 0
  property var skinParams: ({
      imageTop: "", imageBottom: "", imageLeft: "", imageRight: "", imagetask: "", blur: false, blurRadius: 18, positionTaskIndicator: 9,
      left: 0, top: 0, right: 0, bottom: 0,
      outLeft: 0, outTop: 0, outRight: 0, outBottom: 0
  })

  function loadSkinConfig() {
      let skinName = Plasmoid.configuration.skinName || "Default Plasma";

      // LIMPIAR BLUR ANTES DE CAMBIAR
      if (tasks.backend && tasks.parent && tasks.Window && tasks.Window.window) {
          backend.setBlurBehind(tasks.Window.window, false, 0, 0, 0, 0, 0);
          tasks.Window.window.requestUpdate();
          console.log("Blur limpiado antes de aplicar nuevo skin");
      }

      // Construimos la ruta al nuevo archivo Config.qml
      let configUrl = Qt.resolvedUrl("../skins/" + skinName + "/Config.qml");

      console.log("Cargando configuración de skin desde: " + configUrl);

      let component = Qt.createComponent(configUrl);

      if (Plasmoid.configuration.iconSize <= 44) {
          tasks.topoutimage = Math.abs(Plasmoid.configuration.iconSize - 44);
      } else {
          tasks.topoutimage = 44 - Plasmoid.configuration.iconSize;
      }

      if (component.status === Component.Ready) {
          let config = component.createObject(tasks); // 'tasks' es el id de tu PlasmoidItem

          if (config) {
              let skinFolderUrl = Qt.resolvedUrl("../skins/" + skinName + "/").toString();

              // Valores base tomados del Config.qml del skin.
              let blurRadiusVal = config.blurRadius;
              let frameRadiusVal = config.frameRadius;
              let frameFillVal = config.frameFill;
              let blurInsetVal = config.blurInset;
              let frameOffsetVal = config.frameOffset;

              // Para el skin "macOS Dock" estos valores se controlan desde los
              // ajustes del plasmoide (radio de esquinas, tono/brillo del panel y
              // cuánto se mete el blur), así el usuario los cambia en vivo sin
              // tocar el Config.qml.
              if (skinName === "macOS Dock") {
                  const r = Plasmoid.configuration.tahoeFrameRadius;
                  blurRadiusVal = r;
                  frameRadiusVal = r;
                  const a = Math.max(0, Math.min(100, Plasmoid.configuration.tahoeTintStrength)) / 100;
                  const v = Plasmoid.configuration.tahoeTintDark ? 0 : 1;
                  frameFillVal = Qt.rgba(v, v, v, a);
                  blurInsetVal = Plasmoid.configuration.tahoeBlurInset;
                  frameOffsetVal = Plasmoid.configuration.tahoeFrameOffset;
              }

              // Actualizamos skinParams de forma reactiva
              tasks.skinParams = {
                  imageTop: skinFolderUrl + config.imageTop,
                  imageBottom: skinFolderUrl + config.imageBottom,
                  imageLeft: skinFolderUrl + config.imageLeft,
                  imageRight: skinFolderUrl + config.imageRight,
                  image: skinFolderUrl + config.image,
                  imagetask: skinFolderUrl + config.imagetask,
                  blur: config.blur,
                  blurRadius: blurRadiusVal,
                  positionTaskIndicator: config.positionTaskIndicator,
                  left: config.leftMargin,
                  top: config.topMargin,
                  right: config.rightMargin,
                  bottom: config.bottomMargin,
                  outLeft: config.outsideLeftMargin,
                  outTop: config.outsideTopMargin + tasks.topoutimage,
                  outRight: config.outsideRightMargin,
                  outBottom: config.outsideBottomMargin,
                  // Marco vectorial opcional estilo macOS (sin imagen). Los campos
                  // son opcionales; si el skin no los define quedan como undefined
                  // y el Rectangle usa sus valores por defecto.
                  frame: config.frame === true,
                  frameColor: config.frameColor,
                  frameFill: frameFillVal,
                  frameBorder: config.frameBorder,
                  frameRadius: frameRadiusVal,
                  blurInset: blurInsetVal,
                  frameOffset: frameOffsetVal
              };

              console.log("EXITO: Skin '" + skinName + "' cargada. Imagen: " + tasks.skinParams.image);

              // Limpiamos el objeto temporal de memoria
              config.destroy();
          }
      } else {
          console.log("ERROR al cargar Config.qml: " + component.errorString());
          // Fallback: Si no existe el .qml, podrías intentar cargar valores por defecto aquí
      }
  }

  // Detecta si entra zoom y si sale
  readonly property bool isZoomActive: {
      for (let i = 0; i < taskRepeater.count; ++i) {
          let item = taskRepeater.itemAt(i);
          // Si el zoomFactor es mayor a 1.0 (o un umbral mínimo como 1.01)
          if (item && item.zoomFactor > 1.01) return true;
      }
      return false;
  }

    Plasmoid.onUserConfiguringChanged: {
        if (Plasmoid.userConfiguring && groupDialog !== null) {
            groupDialog.visible = false;
        }
    }

    Layout.fillWidth: vertical ? true : Plasmoid.configuration.fill
    Layout.fillHeight: !vertical ? true : Plasmoid.configuration.fill
    Layout.minimumWidth: {
        if (shouldShrinkToZero) {
            return Kirigami.Units.gridUnit; // For edit mode
        }
        return vertical ? 0 : LayoutMetrics.preferredMinWidth();
    }
    Layout.minimumHeight: {
        if (shouldShrinkToZero) {
            return Kirigami.Units.gridUnit; // For edit mode
        }
        return !vertical ? 0 : LayoutMetrics.preferredMinHeight();
    }

//BEGIN TODO: this is not precise enough: launchers are smaller than full tasks
    Layout.preferredWidth: {
        if (shouldShrinkToZero) {
            return 0.01;
        }
        if (vertical) {
            return Kirigami.Units.gridUnit * 10;
        }
        return taskList.Layout.maximumWidth
    }
    Layout.preferredHeight: {
        if (shouldShrinkToZero) {
            return 0.01;
        }
        if (vertical) {
            return taskList.Layout.maximumHeight
        }
        return Kirigami.Units.gridUnit * 2;
    }
//END TODO

    property Item dragSource

    signal requestLayout

    onDragSourceChanged: {
        if (dragSource === null) {
            tasksModel.syncLaunchers();
        }
    }

    function windowsHovered(winIds: var, hovered: bool): DBus.DBusPendingReply {
        if (!Plasmoid.configuration.highlightWindows) {
            return;
        }
        return DBus.SessionBus.asyncCall({service: "org.kde.KWin.HighlightWindow", path: "/org/kde/KWin/HighlightWindow", iface: "org.kde.KWin.HighlightWindow", member: "highlightWindows", arguments: [hovered ? winIds : []], signature: "(as)"});
    }

    function cancelHighlightWindows(): DBus.DBusPendingReply {
        return DBus.SessionBus.asyncCall({service: "org.kde.KWin.HighlightWindow", path: "/org/kde/KWin/HighlightWindow", iface: "org.kde.KWin.HighlightWindow", member: "highlightWindows", arguments: [[]], signature: "(as)"});
    }

    function activateWindowView(winIds: var): DBus.DBusPendingReply {
        if (!effectWatcher.registered) {
            return;
        }
        cancelHighlightWindows();
        return DBus.SessionBus.asyncCall({service: "org.kde.KWin.Effect.WindowView1", path: "/org/kde/KWin/Effect/WindowView1", iface: "org.kde.KWin.Effect.WindowView1", member: "activate", arguments: [winIds.map(s => String(s))], signature: "(as)"});
    }

    function publishIconGeometries(taskItems: /*list<Item>*/var): void {
        if (TaskTools.taskManagerInstanceCount >= 2) {
            return;
        }
        for (let i = 0; i < taskItems.length - 1; ++i) {
            const task = taskItems[i];

            if (!task.model.IsLauncher && !task.model.IsStartup) {
                tasksModel.requestPublishDelegateGeometry(tasksModel.makeModelIndex(task.index),
                    backend.globalRect(task), task);
            }
        }
    }

    readonly property TaskManager.TasksModel tasksModel: TaskManager.TasksModel {
        id: tasksModel

        readonly property int logicalLauncherCount: {
            if (Plasmoid.configuration.separateLaunchers) {
                return launcherCount;
            }

            let startupsWithLaunchers = 0;

            for (let i = 0; i < taskRepeater.count; ++i) {
                const item = taskRepeater.itemAt(i) as Task;

                // During destruction required properties such as item.model can go null for a while,
                // so in paths that can trigger on those moments, they need to be guarded
                if (item?.model?.IsStartup && item.model.HasLauncher) {
                    ++startupsWithLaunchers;
                }
            }

            return launcherCount + startupsWithLaunchers;
        }

        virtualDesktop: virtualDesktopInfo.currentDesktop
        screenGeometry: Plasmoid.containment.screenGeometry
        activity: activityInfo.currentActivity

        filterByVirtualDesktop: Plasmoid.configuration.showOnlyCurrentDesktop
        filterByScreen: Plasmoid.configuration.showOnlyCurrentScreen
        filterByActivity: Plasmoid.configuration.showOnlyCurrentActivity
        filterNotMinimized: Plasmoid.configuration.showOnlyMinimized

        hideActivatedLaunchers: tasks.iconsOnly || Plasmoid.configuration.hideLauncherOnStart
        sortMode: sortModeEnumValue(Plasmoid.configuration.sortingStrategy)
        launchInPlace: tasks.iconsOnly && Plasmoid.configuration.sortingStrategy === 1
        separateLaunchers: {
            if (!tasks.iconsOnly && !Plasmoid.configuration.separateLaunchers
                && Plasmoid.configuration.sortingStrategy === 1) {
                return false;
            }

            return true;
        }

        groupMode: groupModeEnumValue(Plasmoid.configuration.groupingStrategy)
        groupInline: !Plasmoid.configuration.groupPopups && !tasks.iconsOnly
        groupingWindowTasksThreshold: (Plasmoid.configuration.onlyGroupWhenFull && !tasks.iconsOnly
            ? LayoutMetrics.optimumCapacity(tasks.width, tasks.height) + 1 : -1)

        onLauncherListChanged: {
            Plasmoid.configuration.launchers = launcherList;
        }

        onGroupingAppIdBlacklistChanged: {
            Plasmoid.configuration.groupingAppIdBlacklist = groupingAppIdBlacklist;
        }

        onGroupingLauncherUrlBlacklistChanged: {
            Plasmoid.configuration.groupingLauncherUrlBlacklist = groupingLauncherUrlBlacklist;
        }

        function sortModeEnumValue(index: int): /*TaskManager.TasksModel.SortMode*/ int {
            switch (index) {
            case 0:
                return TaskManager.TasksModel.SortDisabled;
            case 1:
                return TaskManager.TasksModel.SortManual;
            case 2:
                return TaskManager.TasksModel.SortAlpha;
            case 3:
                return TaskManager.TasksModel.SortVirtualDesktop;
            case 4:
                return TaskManager.TasksModel.SortActivity;
            // 5 is SortLastActivated, skipped
            case 6:
                return TaskManager.TasksModel.SortWindowPositionHorizontal;
            default:
                return TaskManager.TasksModel.SortDisabled;
            }
        }

        function groupModeEnumValue(index: int): /*TaskManager.TasksModel.GroupMode*/ int {
            switch (index) {
            case 0:
                return TaskManager.TasksModel.GroupDisabled;
            case 1:
                return TaskManager.TasksModel.GroupApplications;
            }
        }

        Component.onCompleted: {
            launcherList = Plasmoid.configuration.launchers;
            groupingAppIdBlacklist = Plasmoid.configuration.groupingAppIdBlacklist;
            groupingLauncherUrlBlacklist = Plasmoid.configuration.groupingLauncherUrlBlacklist;

            // Only hook up view only after the above churn is done.
            taskRepeater.model = tasksModel;
        }
    }

    readonly property TaskManagerApplet.Backend backend: TaskManagerApplet.Backend {
        id: backend

        onAddLauncher: url => {
            tasks.addLauncher(url);
        }
    }

    DBus.DBusServiceWatcher {
        id: effectWatcher
        busType: DBus.BusType.Session
        watchedService: "org.kde.KWin.Effect.WindowView1"
    }

    readonly property Component taskInitComponent: Component {
        Timer {
            interval: 200
            running: true

            onTriggered: {
                const task = parent as Task;
                if (task) {
                    tasks.tasksModel.requestPublishDelegateGeometry(task.modelIndex(), tasks.backend.globalRect(task), task);
                }
                destroy();
            }
        }
    }

    Connections {
        target: Plasmoid

        function onLocationChanged(): void {
            if (TaskTools.taskManagerInstanceCount >= 2) {
                return;
            }
            // This is on a timer because the panel may not have
            // settled into position yet when the location prop-
            // erty updates.
            console.log(
                "location=", Plasmoid.location,
                "tasks.width=", tasks.width,
                "tasks.height=", tasks.height,
                "taskList.height=", taskList.height,
                "centerOffset=", taskList.centerOffset
            );
            iconGeometryTimer.start();
        }
    }

    Connections {
        target: Plasmoid.containment

        function onScreenGeometryChanged(): void {
            iconGeometryTimer.start();
        }
    }

    Mpris.Mpris2Model {
        id: mpris2Source
    }

    Item {
        anchors.fill: parent

        TaskManager.VirtualDesktopInfo {
            id: virtualDesktopInfo
        }

        TaskManager.ActivityInfo {
            id: activityInfo
            readonly property string nullUuid: "00000000-0000-0000-0000-000000000000"
        }

        Loader {
            id: pulseAudio
            sourceComponent: tasks.pulseAudioComponent
            active: tasks.pulseAudioComponent.status === Component.Ready
        }

        Timer {
            id: iconGeometryTimer

            interval: 500
            repeat: false

            onTriggered: {
                tasks.publishIconGeometries(taskList.children, tasks);
            }
        }

        Binding {
            target: Plasmoid
            property: "status"
            value: {
                if (tasks.metaShowActive) {
                    return PlasmaCore.Types.NeedsAttentionStatus;
                }
                if (tasksModel.anyTaskDemandsAttention && Plasmoid.configuration.unhideOnAttention) {
                    return PlasmaCore.Types.NeedsAttentionStatus;
                }
                return PlasmaCore.Types.PassiveStatus;
            }
            restoreMode: Binding.RestoreBinding
        }

        Connections {
            target: Plasmoid.configuration

            function onSkinNameChanged() {
                console.log("Nueva skin detectada: " + Plasmoid.configuration.skinName);
                loadSkinConfig(); // La función que lee el .ini y carga la imagen
            }

            function onIconSizeChanged() {
                loadSkinConfig();
            }

            // Ajustes en vivo del skin "macOS Dock" (radio de esquinas y tono
            // del panel): releen el skin para reconstruir skinParams.
            function onTahoeFrameRadiusChanged() { loadSkinConfig(); }
            function onTahoeTintStrengthChanged() { loadSkinConfig(); }
            function onTahoeTintDarkChanged() { loadSkinConfig(); }
            function onTahoeBlurInsetChanged() { loadSkinConfig(); }
            function onTahoeFrameOffsetChanged() { loadSkinConfig(); }

            function onLaunchersChanged(): void {
                tasksModel.launcherList = Plasmoid.configuration.launchers
            }
            function onGroupingAppIdBlacklistChanged(): void {
                tasksModel.groupingAppIdBlacklist = Plasmoid.configuration.groupingAppIdBlacklist;
            }
            function onGroupingLauncherUrlBlacklistChanged(): void {
                tasksModel.groupingLauncherUrlBlacklist = Plasmoid.configuration.groupingLauncherUrlBlacklist;
            }
        }

        Component {
            id: busyIndicator
            PlasmaComponents3.BusyIndicator {}
        }

        // Save drag data
        Item {
            id: dragHelper

            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction | Qt.MoveAction | Qt.LinkAction
            Drag.onDragFinished: dropAction => {
                tasks.dragSource = null;
            }
        }

        KSvg.FrameSvgItem {
            id: taskFrame

            visible: false

            imagePath: tasks.skinParams.imagetask
            prefix: TaskTools.taskPrefix("normal", Plasmoid.location)
        }

        MouseHandler {
            id: mouseHandler

            anchors.fill: parent

            target: taskList

            onUrlsDropped: urls => {
                // If all dropped URLs point to application desktop files, we'll add a launcher for each of them.
                const createLaunchers = urls.every(item => tasks.backend.isApplication(item));

                if (createLaunchers) {
                    urls.forEach(item => addLauncher(item));
                    return;
                }

                if (!hoveredItem) {
                    return;
                }

                // Otherwise we'll just start a new instance of the application with the URLs as argument,
                // as you probably don't expect some of your files to open in the app and others to spawn launchers.
                tasksModel.requestOpenUrls((hoveredItem as Task).modelIndex(), urls);
            }
        }

        ToolTipDelegate {
            id: openWindowToolTipDelegate
            visible: false
        }

        ToolTipDelegate {
            id: pinnedAppToolTipDelegate
            visible: false
        }

        Loader {
            id: backgroundLoader

            anchors.fill: parent
            sourceComponent: (Plasmoid.configuration.skinName === "Default Plasma") ? defaultSkin : customSkin
        }

        // --- Componente 1: DEFAULT (SVG) ---
        Component {
            id: defaultSkin
            Item {
                id: internalCanvas

                readonly property bool vertical: tasks.vertical

                readonly property real horizontalMargins:
                shadowItem.margins.left + shadowItem.margins.right

                readonly property real verticalMargins:
                shadowItem.margins.top + shadowItem.margins.bottom

                readonly property real baseIconsSize:
                taskRepeater.count * Plasmoid.configuration.iconSize +
                Math.max(0, taskRepeater.count - 1) * taskList.spacing

                readonly property real verticalOffsetX: -Kirigami.Units.smallSpacing * 0.5


                readonly property real currentGrowth:
                Math.max(
                    0,
                    (taskList.iconsTotalSize + taskList.spacing * 2)
                    - baseIconsSize
                ) / 2

                readonly property real panelThickness:
                Plasmoid.configuration.iconSize * 1.20

                KSvg.FrameSvgItem {
                    id: shadowItem

                    imagePath: "widgets/panel-background"
                    prefix: "shadow"

                    z: -2

                    width: vertical
                    ? panelThickness + verticalMargins
                    : horizontalMargins + baseIconsSize + (currentGrowth * 2) + Kirigami.Units.smallSpacing * 2


                    height: vertical
                    ? baseIconsSize + (currentGrowth * 2) + verticalMargins
                    : panelThickness + verticalMargins + Kirigami.Units.smallSpacing * 0.2

                    x: {
                        if (!vertical)
                            return (parent.width - width) / 2;

                        if (vertical && Plasmoid.location === PlasmaCore.Types.RightEdge)
                            return (taskList.width - width) - Kirigami.Units.smallSpacing * 0.8;

                        return - (verticalMargins/2 + Kirigami.Units.smallSpacing * 0.9);
                    }


                    y: {
                        if (vertical)
                            return (parent.height - height) / 2;

                        // Panel arriba
                        if (tasks.isTopPanel)
                            return - ((verticalMargins / 2) + Kirigami.Units.smallSpacing * 0.8);

                        // Panel abajo
                        return (taskList.height - height + (verticalMargins / 2)) + Kirigami.Units.smallSpacing * 0.6;
                    }
                }

                KSvg.FrameSvgItem {
                    id: backgroundItem

                    imagePath: "widgets/panel-background"
                    prefix: ""

                    z: -1

                    width: vertical
                    ? panelThickness
                    : baseIconsSize + (currentGrowth * 2) + Kirigami.Units.smallSpacing * 2

                    height: vertical
                    ? baseIconsSize + (currentGrowth * 2)
                    : panelThickness + Kirigami.Units.smallSpacing * 0.2

                    x: {
                        if (!vertical)
                            return (parent.width - width) / 2;

                        if (vertical && Plasmoid.location === PlasmaCore.Types.RightEdge)
                            return taskList.width - width - (verticalMargins / 2) - Kirigami.Units.smallSpacing * 0.8;

                        return - (Kirigami.Units.smallSpacing * 0.9 );
                    }

                    y: {
                        if (vertical)
                            return (parent.height - height) / 2;

                        // Panel arriba
                        if (tasks.isTopPanel)
                            return - Kirigami.Units.smallSpacing * 0.8;

                        // Panel abajo
                       return (taskList.height - height) + Kirigami.Units.smallSpacing * 0.6;
                    }

                    readonly property int blurRadius:
                    tasks.skinParams.blurRadius || 18

                    function updateBlur() {

                        if (!tasks.skinParams.blur)
                            return;

                        const win = backgroundItem?.Window?.window;

                        if (!win)
                            return;

                        if (typeof win.visible !== "undefined" && !win.visible)
                            return;

                        var pos = mapToItem(null, 0, 0);

                        backend.setBlurBehind(
                            win,
                            true,
                            pos.x,
                            pos.y,
                            width,
                            height,
                            blurRadius
                        );

                        if (win.requestUpdate)
                            win.requestUpdate();
                    }

                    function scheduleBlurUpdate() {
                        Qt.callLater(updateBlur)
                    }

                    onWidthChanged: scheduleBlurUpdate()
                    onHeightChanged: scheduleBlurUpdate()
                    onXChanged: scheduleBlurUpdate()
                    onYChanged: scheduleBlurUpdate()
                    onWindowChanged: scheduleBlurUpdate()

                    onVisibleChanged: {
                        if (visible)
                            scheduleBlurUpdate()
                    }
                }
            }
        }

        // --- Componente 2: CUSTOM SKIN ---
        Component {
            id: customSkin
            BorderImage {
                id: dockBackground
                cache: true
                smooth: true
                asynchronous: true
                visible: source.toString() !== ""
                opacity: 1.0
                readonly property real spacing: Kirigami.Units.largeSpacing
                readonly property real topMarginSkin: tasks.containmentItem.height - 76
                readonly property real leftMarginSkin: tasks.containmentItem.width - 76

                property real rightPanelOffset:(tasks.vertical && !tasks.isLeftPanel) ? ((tasks.containmentItem.width / 2) + Kirigami.Units.smallSpacing * 3) : 0

                // Cuánto crecieron los iconos con zoom respecto al base
                readonly property real currentGrowth: Math.max(0, taskList.maxZoom + spacing * 8
                ) / 2

                property real dynamicLeftMargin: tasks.skinParams.outLeft
                + taskList.centerOffset
                - currentGrowth

                property real dynamicRightMargin: tasks.skinParams.outRight
                + taskList.centerOffset
                - currentGrowth

                anchors {
                    fill: parent

                    leftMargin: tasks.vertical
                    ? (tasks.isLeftPanel
                    ? (tasks.skinParams.outBottom || 0)
                    : (tasks.skinParams.outTop + leftMarginSkin || 0)) // <-- CORREGIDO: Se añade aquí para el panel derecho
                    : (dockBackground.dynamicLeftMargin || 0)

                    rightMargin: tasks.vertical
                    ? (tasks.isLeftPanel
                    ? (tasks.skinParams.outTop + leftMarginSkin || 0)
                    : (tasks.skinParams.outBottom || 0)) // <-- CORREGIDO: Se quita de aquí para el panel derecho
                    : (dockBackground.dynamicRightMargin || 0)

                    topMargin: tasks.vertical
                    ? ((tasks.skinParams.outRight || 0)
                    + taskList.centerOffset
                    - currentGrowth)
                    : (tasks.isTopPanel
                    ? (tasks.skinParams.outBottom || 0)
                    : (tasks.skinParams.outTop + topMarginSkin || 0))

                    bottomMargin: tasks.vertical
                    ? ((tasks.skinParams.outLeft || 0)
                    + taskList.centerOffset
                    - currentGrowth)
                    : (tasks.isTopPanel
                    ? (tasks.skinParams.outTop + topMarginSkin || 0)
                    : (tasks.skinParams.outBottom || 0))
                }

              source: {
                  if (tasks.vertical) {
                      return tasks.isLeftPanel
                      ? tasks.skinParams.imageLeft
                      : tasks.skinParams.imageRight;
                  }

                  return tasks.isTopPanel
                  ? tasks.skinParams.imageTop
                  : tasks.skinParams.imageBottom;
              }

                border {
                    left: tasks.vertical
                    ? (tasks.isLeftPanel
                    ? tasks.skinParams.bottom
                    : tasks.skinParams.top)
                    : tasks.skinParams.left

                    top: tasks.vertical
                    ? tasks.skinParams.right
                    : tasks.skinParams.top

                    right: tasks.vertical
                    ? (tasks.isLeftPanel
                    ? tasks.skinParams.top
                    : tasks.skinParams.bottom)
                    : tasks.skinParams.right

                    bottom: tasks.vertical
                    ? tasks.skinParams.left
                    : tasks.skinParams.bottom
                }

                horizontalTileMode: BorderImage.Stretch
                verticalTileMode: BorderImage.Stretch
                z: -1

                // Marco vectorial estilo macOS (sin imagen): un rectángulo
                // redondeado con un filo claro fino sobre el blur nativo de KWin.
                // El radio coincide por construcción con el de la región de blur
                // (mismo blurRadius), así que el filo sigue el borde difuminado.
                // Se dibuja sólo si el skin activa "frame"; el resto de skins no
                // se ven afectados. Estilo configurable desde el Config.qml del
                // skin (frameColor / frameFill / frameBorder / frameRadius).
                Rectangle {
                    id: dockFrame

                    // Desplazamiento fino (sub-píxel) del filo respecto al borde
                    // del blur. Positivo = hacia fuera, para tapar el borde difuso
                    // del blur de KWin (que asoma unos px); negativo = hacia dentro.
                    // Es float y con antialiasing, así que se ajusta finísimo — algo
                    // imposible en la propia región de blur, que es de píxeles enteros.
                    readonly property real frameOff: tasks.skinParams.frameOffset || 0

                    anchors.fill: parent
                    anchors.margins: -frameOff
                    visible: tasks.skinParams.frame === true
                    antialiasing: true
                    color: tasks.skinParams.frameFill || "transparent"
                    radius: Math.max(0, ((tasks.skinParams.frameRadius !== undefined
                             && tasks.skinParams.frameRadius !== null)
                            ? tasks.skinParams.frameRadius
                            : dockBackground.blurRadius) + frameOff)
                    border.width: (tasks.skinParams.frameBorder !== undefined
                                   && tasks.skinParams.frameBorder !== null)
                                  ? tasks.skinParams.frameBorder : 1
                    border.color: tasks.skinParams.frameColor || "#59ffffff"
                }

                // --- INTEGRACIÓN DEL BLUR ---

                // Radio de blur
                readonly property int blurRadius: tasks.skinParams.blurRadius || 24

                // Cuánto se encoge la región de blur hacia dentro respecto al
                // marco. El blur de KWin es una convolución cuyo borde difuso
                // sobresale unos píxeles del recorte; metiéndolo un poco, ese
                // borde queda por debajo del filo del marco y no asoma. 0 = igual
                // que el marco (comportamiento anterior).
                readonly property int blurInset: tasks.skinParams.blurInset || 0
                onBlurInsetChanged: updateBlur(true)

                // (Re)aplica la región de blur del dock.
                // Con recover=true, además fuerza a KWin a releer la región y a
                // repintarla; esto es necesario para restaurar el blur cuando KWin
                // dejó de difuminar la zona por haber quedado ocluida (p. ej. tras
                // Win+D con una ventana maximizada). En el camino normal (cambios
                // de geometría) se omite para no introducir parpadeos.
                function updateBlur(recover) {
                    if (!tasks.skinParams.blur)
                        return;

                    const win = dockBackground?.Window?.window;

                    if (!win || (typeof win.visible !== "undefined" && !win.visible))
                        return;

                    if (width <= 0 || height <= 0)
                        return;

                    const pos = mapToItem(null, 0, 0);

                    if (recover) {
                        // Limpiar primero para que una región idéntica no sea un no-op.
                        backend.setBlurBehind(win, false, 0, 0, 0, 0, 0);
                    }

                    // Metemos la región "k" px hacia dentro y reducimos el radio en
                    // la misma cantidad, de modo que quede concéntrica con el marco
                    // (inset uniforme por los cuatro lados y esquinas).
                    const k = Math.max(0, Math.min(blurInset, Math.floor(Math.min(width, height) / 2) - 1));
                    backend.setBlurBehind(win, true, pos.x + k, pos.y + k, width - 2 * k, height - 2 * k, Math.max(0, blurRadius - k));

                    if (win.requestUpdate)
                        win.requestUpdate();

                    if (recover) {
                        // Forzar daño en la superficie con un cambio de opacidad
                        // imperceptible: KWin no vuelve a difuminar una región ocluida
                        // hasta que el dock produce un fotograma nuevo.
                        dockBackground.opacity = (dockBackground.opacity > 0.9995) ? 0.999 : 1.0;
                    }
                }

                // --- CONEXIONES PARA ACTUALIZACIÓN DINÁMICA ---

                function scheduleBlurUpdate() {
                    Qt.callLater(updateBlur)
                }

                onWidthChanged: scheduleBlurUpdate()
                onHeightChanged: scheduleBlurUpdate()
                onXChanged: scheduleBlurUpdate()
                onYChanged: scheduleBlurUpdate()

                onWindowChanged: scheduleBlurUpdate()

                // Al cambiar el radio en vivo (ajustes de "macOS Dock") hay que
                // reconstruir la región del blur y forzar el repintado, porque un
                // cambio de forma no genera daño en la superficie por sí solo.
                onBlurRadiusChanged: updateBlur(true)

                onVisibleChanged: {
                    if (visible)
                        scheduleBlurUpdate()
                }

                // KWin deja de difuminar la región del dock cuando ésta queda
                // ocluida (ventana maximizada, "Mostrar escritorio"/Win+D, ...) y
                // no la restaura hasta que la superficie produce daño. En lugar de
                // sondear sin parar, reafirmamos el blur en una ráfaga corta
                // disparada por los eventos que pueden provocar esa pérdida. En
                // reposo el coste es nulo.
                // Mientras llegan eventos —y hasta unos segundos después del
                // último— reaplicamos el blur cada 500 ms, sin pausas, para no
                // perder el instante en que KWin deja caer la región tras la
                // transición. En reposo el timer se detiene solo (coste nulo).
                Timer {
                    id: blurWatchdog
                    interval: 500
                    repeat: true
                    property int ticksLeft: 0
                    onTriggered: {
                        dockBackground.updateBlur(true);
                        if (--ticksLeft <= 0)
                            stop();
                    }
                }

                function kickBlurRecovery() {
                    if (!tasks.skinParams.blur)
                        return;
                    dockBackground.updateBlur(true);   // inmediato
                    blurWatchdog.ticksLeft = 10;        // ~5 s tras el último evento
                    if (!blurWatchdog.running)
                        blurWatchdog.start();
                }

                // Win+D / "Mostrar escritorio": efecto del compositor, sin señal en
                // el modelo de tareas. Lo detectamos vía KWindowSystem (backend C++).
                Connections {
                    target: tasks.backend
                    enabled: tasks.skinParams.blur === true
                    function onShowingDesktopChanged() { dockBackground.kickBlurRecovery() }
                }

                // Apertura/cierre/maximización/minimización de ventanas: sí cambian
                // el modelo de tareas y pueden ocluir o liberar la zona del dock.
                Connections {
                    target: tasks.tasksModel
                    enabled: tasks.skinParams.blur === true
                    function onActiveTaskChanged() { dockBackground.kickBlurRecovery() }
                    function onCountChanged() { dockBackground.kickBlurRecovery() }
                    function onDataChanged() { dockBackground.kickBlurRecovery() }
                }

                // Cambio de escritorio virtual: puede revelar un escritorio vacío
                // o una ventana maximizada distinta sin tocar el modelo de tareas,
                // y KWin no reevalúa por su cuenta la región del dock.
                Connections {
                    target: virtualDesktopInfo
                    enabled: tasks.skinParams.blur === true
                    function onCurrentDesktopChanged() { dockBackground.kickBlurRecovery() }
                }

                // Heartbeat con compuerta de estado: "Mostrar escritorio" es un
                // estado sostenido del que KWin puede soltar la región del dock en
                // cualquier momento sin emitir más señales; mientras está activo lo
                // reafirmamos a baja frecuencia. Es declarativo: cuando showingDesktop
                // vuelve a false el timer se detiene solo y el coste en reposo es nulo.
                Timer {
                    interval: 1000
                    repeat: true
                    running: tasks.skinParams.blur === true && tasks.backend.showingDesktop
                    onTriggered: dockBackground.updateBlur(true)
                }
            }
        }

        TriangleMouseFilter {
            id: tmf
            filterTimeOut: 300
            active: false
            blockFirstEnter: false

            edge: {
                switch (Plasmoid.location) {
                case PlasmaCore.Types.BottomEdge:
                    return Qt.TopEdge;
                case PlasmaCore.Types.TopEdge:
                    return Qt.BottomEdge;
                case PlasmaCore.Types.LeftEdge:
                    return Qt.RightEdge;
                case PlasmaCore.Types.RightEdge:
                    return Qt.LeftEdge;
                default:
                    return Qt.TopEdge;
                }
            }

            LayoutMirroring.enabled: tasks.shouldBeMirrored(Plasmoid.configuration.reverseMode, Application.layoutDirection, tasks.vertical)

            anchors {
                left: parent.left
                top: parent.top
            }

            height: taskList.height
            width: taskList.width

            TaskList {
                id: taskList

                property real smoothMouse: -1
                property bool insideDock: false
                property alias animating: taskList.animating
                readonly property real spacing: Kirigami.Units.smallSpacing
                readonly property real _baseSize: Plasmoid.configuration.iconSize
                readonly property real _sigma: _baseSize * Plasmoid.configuration.amplitud

                readonly property real totalWidth: tasks.taskRepeater.count * _baseSize

                readonly property real _zoom: (Plasmoid.configuration.magnification || 0) / 100
                readonly property real maxZoom: 1.0 + (Plasmoid.configuration.magnification || 0) / 100

                readonly property real baseContentSize: taskRepeater.count * Plasmoid.configuration.iconSize + Math.max(0, taskRepeater.count - 1) * spacing

                // Integral gaussiana aproximada
                readonly property real zoomExtraSize: _zoom * _sigma * Math.sqrt(2 * Math.PI)

                property real contentSize: Math.ceil(baseContentSize + zoomExtraSize + spacing * 4)

               readonly property real iconsTotalSize: {
                   // Dependencia explícita en la revisión del Repeater: al añadir
                   // un icono, "count" cambia antes de que el delegado exista, así
                   // que itemAt(nuevoÍndice) es null y su ancho nunca se lee => el
                   // binding no vuelve a evaluarse cuando el delegado aparece y esta
                   // suma se queda corta (el fondo/marco no cubren el icono nuevo
                   // hasta que otro evento fuerza el recálculo). itemRevision se
                   // incrementa en onItemAdded/onItemRemoved, cuando el delegado ya
                   // existe, forzando aquí una reevaluación con el ancho real.
                   let _rev = taskRepeater.itemRevision;
                   let total = 0;

                   for (let i = 0; i < taskRepeater.count; ++i) {
                       let item = taskRepeater.itemAt(i);

                       if (item) {

                           total += tasks.vertical
                           ? item.height
                           : item.width;

                           if (i > 0)
                               total += spacing;
                       }
                   }

                   // Suelo garantizado: cada delegado vivo mide iconSize * zoomFactor
                   // con zoomFactor >= 1, así que la suma real NUNCA puede ser menor
                   // que baseContentSize (count * iconSize + huecos). Si sale menor es
                   // porque algún delegado aún no existe (justo al abrir una app): en
                   // ese hueco de 1-N frames "total" queda corto, centerOffset se
                   // infla y la última app se dibuja fuera del plasmoide -> visible
                   // pero sin ventana debajo => zona muerta (no hay hover ni click).
                   // Apoyando el valor en baseContentSize el centrado ya es correcto
                   // desde el primer frame tras crecer "count", sin esperar al delegado.
                   return Math.max(total, baseContentSize);
               }

               readonly property real centerOffset: {
                   let availableSize = tasks.vertical
                   ? height
                   : width;

                   return (availableSize - iconsTotalSize) / 2;
               }

                Layout.maximumWidth: contentSize
                Layout.maximumHeight: contentSize

                width: {
                    if (tasks.vertical) {
                        return Math.ceil(
                            Plasmoid.configuration.iconSize *
                            taskList.maxZoom +
                            spacing * 4
                        );
                    }

                    return contentSize;
                }

                height: {
                    if (tasks.vertical) {
                        return contentSize;
                    }

                    return tasks.height;
                }

                flow: {
                    if (tasks.vertical) {
                        return Plasmoid.configuration.forceStripes ? Grid.LeftToRight : Grid.TopToBottom
                    }
                    return Plasmoid.configuration.forceStripes ? Grid.TopToBottom : Grid.LeftToRight
                }

                onAnimatingChanged: {
                    if (!animating) {
                        tasks.publishIconGeometries(children, tasks);
                    }
                }

                HoverHandler {
                    id: dockHoverHandler

                    // DEBUG: última posición del puntero (en coords del plasmoide).
                    property real _lastPointX: -1
                    property real _lastPointY: -1

                    onPointChanged: {
                        let mappedPos = taskList.mapToItem(tasks, point.position.x, point.position.y)

                        _lastPointX = mappedPos.x;
                        _lastPointY = mappedPos.y;

                        // Ignoramos los eventos "cola" que el HoverHandler sigue emitiendo
                        // tras salir del dock (hovered=false). Si actualizáramos smoothMouse
                        // con ellos, el centro de la gaussiana se desplazaría mientras el
                        // zoom se desvanece y el colapso se vería entrecortado. Con el
                        // puntero fuera, smoothMouse queda CONGELADO y el zoom se apaga
                        // limpiamente en su sitio vía entryProgress. También cancela cualquier
                        // salida/reset pendiente porque el cursor sí está dentro.
                        if (!dockHoverHandler.hovered)
                            return;

                        let mousePos = tasks.vertical ? mappedPos.y : mappedPos.x

                        if (taskList.smoothMouse < 0) {
                            taskList.smoothMouse = mousePos
                        } else {
                            taskList.smoothMouse +=
                            (mousePos - taskList.smoothMouse) * 0.3
                        }

                        taskList.insideDock = true
                        exitTimer.stop()
                        smoothResetTimer.stop()
                    }

                    onHoveredChanged: {
                        if (hovered) {
                            // Al recuperar el hover (p. ej. tras un micro-parpadeo del
                            // reflow) cancelamos la salida pendiente: eso evita que el
                            // zoom colapse mientras el ratón se mueve dentro del dock.
                            taskList.insideDock = true;
                            exitTimer.stop();
                            smoothResetTimer.stop();
                        } else {
                            // DEBUG: al perder el hover, volcamos la geometría para
                            // ver si la ventana del panel es más estrecha que el
                            // contenido (contentSize) y por cuánto, y dónde estaba el
                            // puntero respecto al borde derecho del contenido.
                            const win = tasks?.Window?.window;
                            const lastIconRight = taskList.centerOffset + taskList.iconsTotalSize;
                            console.log("WT-DBG hover-lost"
                                + " ptrX=" + Math.round(dockHoverHandler._lastPointX)
                                + " plasmoidW=" + Math.round(tasks.width)
                                + " windowW=" + (win ? Math.round(win.width) : "n/a")
                                + " contentSize=" + Math.round(taskList.contentSize)
                                + " taskListW=" + Math.round(taskList.width)
                                + " centerOffset=" + Math.round(taskList.centerOffset)
                                + " iconsTotal=" + Math.round(taskList.iconsTotalSize)
                                + " lastIconRight=" + Math.round(lastIconRight)
                                + " count=" + taskRepeater.count);
                            exitTimer.restart();
                        }
                    }
                }

                // DEBUG: estado del zoom mientras el cursor está en el dock. Nos dice
                // qué "compuerta" apaga el zoom (insideDock / smoothMouse / entryProgress).
                Timer {
                    id: dbgZoomTimer
                    interval: 300
                    repeat: true
                    running: dockHoverHandler.hovered || taskList.insideDock
                    onTriggered: {
                        const n = taskRepeater.count;
                        const first = n > 0 ? taskRepeater.itemAt(0) : null;
                        const last = n > 1 ? taskRepeater.itemAt(n - 1) : null;
                        console.log("WT-DBG zoom"
                            + " smoothMouse=" + Math.round(taskList.smoothMouse)
                            + " _zoom=" + (Plasmoid.configuration.magnification || 0)
                            + " iconSize=" + Plasmoid.configuration.iconSize
                            + " tasksH=" + Math.round(tasks.height)
                            + " | zf0=" + (first ? first.zoomFactor.toFixed(2) : "n/a")
                            + " x0=" + (first ? Math.round(first.x) : "n/a")
                            + " w0=" + (first ? Math.round(first.width) : "n/a")
                            + " h0=" + (first ? Math.round(first.height) : "n/a")
                            + " | zfLast=" + (last ? last.zoomFactor.toFixed(2) : "n/a")
                            + " xLast=" + (last ? Math.round(last.x) : "n/a")
                            + " wLast=" + (last ? Math.round(last.width) : "n/a"));
                    }
                }

                // DEBUG: re-mide la geometría un rato después de añadirse una app,
                // para comparar con el instante del "task-added" y ver el transitorio.
                Timer {
                    id: dbgSettleTimer
                    interval: 1500
                    repeat: false
                    onTriggered: {
                        const win = tasks?.Window?.window;
                        console.log("WT-DBG settled(+1.5s)"
                            + " plasmoidW=" + Math.round(tasks.width)
                            + " windowW=" + (win ? Math.round(win.width) : "n/a")
                            + " contentSize=" + Math.round(taskList.contentSize)
                            + " taskListW=" + Math.round(taskList.width)
                            + " count=" + taskRepeater.count);
                    }
                }

                Timer {
                    id: exitTimer
                    // Histéresis de salida mínima (como el original). El anti-parpadeo
                    // ya no depende de este intervalo: cada recuperación de hover (y cada
                    // punto con hovered=true, ~cada frame al mover) cancela el timer, así
                    // que 40 ms bastan para puentear un parpadeo de 1-2 frames y aun así
                    // el zoom cae de inmediato al salir de verdad.
                    interval: 40
                    repeat: false
                    onTriggered: {
                        if (!dockHoverHandler.hovered) {
                            taskList.insideDock = false;
                            // Programamos el reset de smoothMouse para DESPUÉS de que
                            // termine el desvanecimiento (no ahora: ponerlo a -1 haría
                            // que zoomFactor devuelva 1.0 de golpe y el colapso sería
                            // instantáneo/brusco).
                            smoothResetTimer.restart();
                        }
                    }
                }

                // Tras el desvanecimiento completo del zoom al salir, "olvidamos" la
                // última posición del ratón. Así, al volver a entrar, el primer punto
                // hace que smoothMouse SALTE a la posición real en vez de deslizarse
                // desde donde salió (que se vería como una ola entrando de lado).
                Timer {
                    id: smoothResetTimer
                    interval: 260
                    repeat: false
                    onTriggered: {
                        if (!dockHoverHandler.hovered && !taskList.insideDock) {
                            taskList.smoothMouse = -1;
                        }
                    }
                }

                Repeater {
                    id: taskRepeater
                    model: tasksModel

                    // Se incrementa cada vez que un delegado se crea o se destruye,
                    // es decir, cuando itemAt() ya devuelve (o ya no devuelve) el
                    // item. iconsTotalSize lo lee para recalcular con el ancho real
                    // en cuanto el icono nuevo existe, sin esperar a otro evento.
                    property int itemRevision: 0
                    onItemAdded: {
                        taskRepeater.itemRevision++;
                        // DEBUG: geometría justo al añadirse una app, y de nuevo tras
                        // un rato para ver si la ventana del panel "alcanza" al
                        // contenido y cuánto tarda.
                        const win = tasks?.Window?.window;
                        console.log("WT-DBG task-added"
                            + " plasmoidW=" + Math.round(tasks.width)
                            + " windowW=" + (win ? Math.round(win.width) : "n/a")
                            + " contentSize=" + Math.round(taskList.contentSize)
                            + " taskListW=" + Math.round(taskList.width)
                            + " count=" + taskRepeater.count);
                        dbgSettleTimer.restart();
                    }
                    onItemRemoved: taskRepeater.itemRevision++

                    delegate: Task {
                        id: taskItem
                        tasksRoot: tasks
                        dockRef: taskList

                        x: {
                            if (tasks.vertical && tasks.isLeftPanel)
                                return 0;

                            if (tasks.vertical)
                                return (parent.width / 2) - (taskList.spacing * 3);

                            return itemPos;
                        }

                        y: {
                            if (isTopPanel)
                                return  0;

                            if (tasks.vertical)
                                return itemPos;

                            return 0;
                        }

                        property real itemPos: {
                            let pos = taskList.centerOffset;

                            for (let i = 0; i < index; ++i) {
                                let previousItem = taskRepeater.itemAt(i);

                                let size = previousItem
                                ? (tasks.vertical
                                ? previousItem.height
                                : previousItem.width)
                                : Plasmoid.configuration.iconSize;

                                pos += size + taskList.spacing;
                            }

                            return pos;
                        }

                        width: tasks.vertical
                        ? Plasmoid.configuration.iconSize
                        : (Plasmoid.configuration.iconSize * zoomFactor)

                        height: tasks.vertical
                        ? (Plasmoid.configuration.iconSize * zoomFactor)
                        : undefined
                    }
                }
            }
        }

        // Gestiona la vinculación de propiedades una vez que el componente se carga en memoria.
        Loader {
            id: penguinLoader
            active: ((!tasks.vertical) && Plasmoid.configuration.cairoPenguinEnabled)
            z: 999
            anchors.bottom: tasks.isTopPanel ? undefined : parent.bottom
            anchors.top: tasks.isTopPanel ? parent.top : undefined
            anchors.topMargin: tasks.isTopPanel ? Plasmoid.configuration.iconSize / 3 : 0

            source: "CairoPenguin.qml"

            // Pasa los enlaces (bindings) al componente cargado
            onLoaded: {
                let calculateMinX = () => taskList.x + taskList.centerOffset;
                let calculateMaxX = () => calculateMinX() + taskList.iconsTotalSize - item.width;

                item.minX = Qt.binding(calculateMinX);
                item.maxX = Qt.binding(calculateMaxX);
            }
        }

        readonly property Component groupDialogComponent: Qt.createComponent("GroupDialog.qml")
        property GroupDialog groupDialog
    }

    readonly property Component groupDialogComponent: Qt.createComponent("GroupDialog.qml")
    property GroupDialog groupDialog

    readonly property bool supportsLaunchers: true

    function hasLauncher(url: url): bool {
        return tasksModel.launcherPosition(url) !== -1;
    }

    function addLauncher(url: url): void {
        if (Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable) {
            tasksModel.requestAddLauncher(url);
        }
    }

    function removeLauncher(url: url): void {
        if (Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable) {
            tasksModel.requestRemoveLauncher(url);
        }
    }

    // This is called by plasmashell in response to a Meta+number shortcut.
    // TODO: Change type to int
    function activateTaskAtIndex(index: var): void {
        if (typeof index !== "number") {
            return;
        }

        const task = taskRepeater.itemAt(index) as Task;
        if (task) {
            TaskTools.activateTask(task.modelIndex(), task.model, null, task, Plasmoid, this, effectWatcher.registered);
        }
    }

    function createContextMenu(rootTask, modelIndex, args = {}) {
        const initialArgs = Object.assign(args, {
            visualParent: rootTask,
            modelIndex,
            mpris2Source,
            backend,
        });
        return contextMenuComponent.createObject(rootTask, initialArgs);
    }

    function shouldBeMirrored(reverseMode, layoutDirection, vertical): bool {
        // LayoutMirroring is only horizontal
        if (vertical) {
            return layoutDirection === Qt.RightToLeft;
        }

        if (layoutDirection === Qt.LeftToRight) {
            return reverseMode;
        }
        return !reverseMode;
    }

    Component.onCompleted: {
        TaskTools.taskManagerInstanceCount += 1;
        requestLayout.connect(iconGeometryTimer.restart);
        applyBackgroundHint();
        // --- CARGAR SKIN AL INICIAR ---
        loadSkinConfig();
    }

    Component.onDestruction: {
        TaskTools.taskManagerInstanceCount -= 1;
    }

    // para hacer panel transparente
    Timer {
        id: initializeAppletTimer
        interval: 1200
        repeat: false // Lo hacemos repetir hasta que encuentre el contenedor
        running: true

        property int step: 0
        readonly property int maxStep: 5

        onTriggered: {
            console.log("Intento de transparencia número: " + (step + 1));
            applyBackgroundHint();

            if (tasks.containmentItem !== null || step >= maxStep) {
                stop(); // Se detiene cuando lo logra o alcanza el límite
            }
            step++;
        }
    }
}
