/*
    SPDX-FileCopyrightText: 2012-2016 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager
import plasma.applet.org.kde.plasma.taskmanager as TaskManagerApplet

// Loaded only on Plasma 6.8+, after the native backend loads the stock plugin.
// Its Backend participates in the same dispatcher as stock Task Managers.
TaskManagerApplet.Backend {
    id: root

    required property PlasmoidItem taskManager
    readonly property TaskManager.TasksModel tasksModel: taskManager.tasksModel

    screen: taskManager.screen
    hasActiveTask: tasksModel.count > 0 && tasksModel.activeTask.valid
    showsOnlyCurrentScreen: Plasmoid.configuration.showOnlyCurrentScreen

    onActivateTaskAtIndexRequested: index => taskManager.activateTaskAtIndex(index)
    onActivatePreviousTaskRequested: activateAdjacentTask(-1)
    onActivateNextTaskRequested: activateAdjacentTask(1)
    onMoveActiveTaskBackwardRequested: moveActiveTask(-1)
    onMoveActiveTaskForwardRequested: moveActiveTask(1)

    function activateAdjacentTask(direction: int): void {
        const indices = [];
        const repeater = taskManager.taskRepeater;
        for (let row = 0; row < repeater.count; ++row) {
            const item = repeater.itemAt(row);
            if (!item || item.model.IsLauncher || item.model.IsStartup) {
                continue;
            }
            if (item.model.IsGroupParent) {
                const count = tasksModel.rowCount(item.modelIndex());
                for (let child = 0; child < count; ++child) {
                    indices.push(tasksModel.makeModelIndex(row, child));
                }
            } else if (item.model.IsWindow) {
                indices.push(item.modelIndex());
            }
        }

        for (let i = 0; i < indices.length; ++i) {
            if (tasksModel.data(indices[i], TaskManager.AbstractTasksModel.IsActive)) {
                const next = (i + direction + indices.length) % indices.length;
                tasksModel.requestActivate(indices[next]);
                return;
            }
        }
    }

    function moveActiveTask(direction: int): void {
        if (!tasksModel.activeTask.valid) {
            return;
        }

        // Change the persisted setting, not the model's bound sortMode.
        Plasmoid.configuration.sortingStrategy = 1;
        const active = tasksModel.activeTask;
        if (!active.valid) {
            return;
        }
        const row = active.parent.valid ? active.parent.row : active.row;
        const destination = row + direction;
        if (destination < 0 || destination >= tasksModel.count) {
            return;
        }
        if (tasksModel.move(row, destination)) {
            tasksModel.syncLaunchers();
        }
    }
}
