# The export format

An export is a folder StudyBot writes on demand (Settings → Data → Export everything) into
`~/Downloads/StudyBot exports/`. It is the third copy of your data, independent of both Macs
and the server (§16 "Client backup"), and it is meant to be readable in a text editor in 2035
(§16 "After July 2029"). Format version 1.

```
StudyBot export 2026-09-16 1105/
  README.txt                    what the folder is, in plain words
  manifest.json                 formatVersion, exportedAt, appVersion, deviceID, cursor, counts
  notes/
    2026-09-28 Online lectures.md   one Markdown file per session that has notes
    revisions.json                  every NoteRevision kept while typing (last 20 per session)
    conflict-losers.json            versions replaced by a sync from the other Mac
  records/
    assignment.json               every record of that type, tombstones included
    module.json  term.json  session.json  evidence.json  …  one file per type
  programme/
    events.json                   the programme calendar as imported (never synced)
  attachments/                    files, once attachments exist; empty today
  sync-state.json                 cursor and server address; never the token
```

## Records

Each `records/<type>.json` is an array of:

```json
{
  "type": "assignment",
  "sync": { "id": "…", "createdAt": "…", "updatedAt": "…", "version": 8, "baseVersion": 8,
            "seq": 4839, "deletedAt": null, "dirty": false, "deviceID": "…" },
  "fields": { "title": "Programming coursework 1", "status": "drafting", "mentorName": "Dr Patel" }
}
```

`sync` is the record's metadata verbatim, so a restore puts the store back exactly where it
was, including which records still had unsynced edits. `fields` is every field, including
ones written by a newer build than the one exporting (`mentorName` above), so an older
build's export loses nothing (§3.10a). Dates are ISO 8601 UTC, milliseconds when present.

## Notes

`notes/<date> <title>.md`:

```markdown
# Online lectures

28 September 2026 · COM1018DA Programming

## Live notes

- sets, relations, functions
ASK: does the exam expect proofs

## Questions to ask

- does the exam expect proofs
```

Followed by `## Transcript` and `## Structured` when the session has them. The live notes are
exactly as typed; `ASK:` lines are not rewritten.

## Restore

Settings → Data → Restore from an export… → choose the folder. Every record in the export is
written back with its metadata; records already in the store with the same id are replaced;
nothing else is touched. Revisions and losers are added if missing. The sync state is restored
without the token, so the next sync reconciles with the server: newer server versions win by
the usual rule and anything the export had that the server lost is offered back.

`ExportBundleTests` exports a store holding every type, unknown fields, notes, revisions,
losers, a tombstone and the calendar, restores it into an empty store, and asserts equality
type by type.
