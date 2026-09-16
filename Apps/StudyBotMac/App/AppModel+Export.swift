import Foundation
import StudyBotCore
import StudyBotKit

/// Export and restore (§16): the weekly automatic export, the on-demand one, and restoring
/// a bundle into this store.
extension AppModel {
    // MARK: Export and restore (§16)

    /// Runs the weekly export when it is due: on launch and then hourly. Keeps twelve.
    func startAutomaticExports() {
        exportTimer?.cancel()
        exportTimer = Task { [weak self] in
            while !Task.isCancelled {
                await self?.runAutomaticExportIfDue()
                try? await Task.sleep(for: .seconds(3_600))
            }
        }
    }

    func runAutomaticExportIfDue() async {
        guard let database, ExportSchedule.isDue(lastExportAt: lastAutomaticExportAt, now: now()) else {
            return
        }
        do {
            let parent = try exportsFolder()
            let version =
                Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
            let (url, _) = try await ExportBundle.write(
                from: database, into: parent, appVersion: version, deviceID: deviceID, now: now(),
                automatic: true)
            lastAutomaticExportAt = now()
            ExportSchedule.prune(in: parent)
            automaticExportStatus =
                "Weekly export ran into Downloads/StudyBot exports/\(url.lastPathComponent)."
        } catch {
            automaticExportStatus = DiskSpace.saveFailureMessage(for: error, subject: "The weekly export")
        }
    }

    private func exportsFolder() throws -> URL {
        let downloads = try FileManager.default.url(
            for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return downloads.appendingPathComponent("StudyBot exports", isDirectory: true)
    }

    /// Writes a bundle into ~/Downloads/StudyBot exports. On demand from Settings.
    func exportEverything() async {
        guard let database else { return }
        do {
            let parent = try exportsFolder()
            let version =
                Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
            let (url, manifest) = try await ExportBundle.write(
                from: database, into: parent, appVersion: version, deviceID: deviceID, now: now())
            lastExportURL = url
            let notes = manifest.counts["notes"] ?? 0
            let records = manifest.counts.filter {
                !["notes", "programmeEvents", "noteRevisions", "conflictLosers"].contains($0.key)
            }.values.reduce(0, +)
            dataStatus =
                "Exported \(records) records and \(notes) notes to Downloads/StudyBot exports/\(url.lastPathComponent)."
        } catch {
            dataStatus = DiskSpace.saveFailureMessage(for: error, subject: "The export")
        }
    }

    /// Reads a bundle back into this store and reloads every screen.
    func restore(from folder: URL) async {
        guard let database else { return }
        do {
            let summary = try await ExportBundle.restore(from: folder, into: database)
            await assignments?.load()
            await notes?.load()
            await evidence?.load()
            await hours?.load()
            await revision?.load()
            await sync?.load()
            try await reloadProgramme()
            dataStatus =
                "Restored \(summary.records) records, \(summary.noteRevisions) note versions and \(summary.programmeEvents) calendar events from \(folder.lastPathComponent)."
        } catch let error as ExportError {
            dataStatus = error.message
        } catch {
            dataStatus = "Couldn't restore: \(error.localizedDescription)"
        }
    }
}
