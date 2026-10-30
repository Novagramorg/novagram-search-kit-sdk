# NovagramSearchKit

The platform-independent search logic of Novagram, shared by the macOS app (SwiftPM) and the iOS app (Bazel).
Foundation only: Postbox, TelegramCore, SwiftSignalKit and UI stay in the apps as thin adapters.

## What is inside

| Folder           | Contents |
| ---------------- | -------- |
| `Core/`          | `NovagramSearchText` (case, diacritic, apostrophe and whitespace normalization, script letter checks), `NovagramSearchTransliteration` (Uzbek Latin and Cyrillic), `NovagramSearchQuery` (OR/NOT/phrase/hashtag query language), `NovagramSearchLanguage` (language detection), `NovagramSearchConversion` (transliteration and translation plan) and `NovagramSearchClock` (injectable time). |
| `ChatFilter/`    | Exact `"phrase"` and `re:` search inside a chat: query parsing, per-message matcher, page filter with time and size caps, paging rules, paging-state cache. `re:` is matched in any letter case (`Re:\d+` works) when the character after the colon is not whitespace; `re: invoice` stays plain text and an invalid pattern falls back to plain text. |
| `Filters/`       | Global search Messages filters (date range, Unread only, Mentions only, header title parts) and the filled-paging rules (20 results, 5 extra pages, 3 auto-loads). |
| `SavedSearches/` | Saved and pinned global search queries per account in the `pro_messager` suite, JSON compatible with both apps. |
| `Translation/`   | Translated-query rules (3+ characters, no `#`/`$`, no section when equal to the query) and the 200-entry cache. |
| `Settings/`      | `novagram_search_features` (default on), `novagram_search_translate` (default off), `novagram_search_translate_langs` (translated-section languages, legacy fallback to `auto_translate_lang`, at most 3 server translations), key and deep-link slug constants. |
| `Jobs/`          | Job search: post parser, salary and contact parsers, presets, filter model, per-account store, channel relevance and spam guard. |
| `Archive/`       | Search in edit history and deleted messages: the archived record, a search index over any records, paged search with privacy exclusion, an optional file store per account and the macOS legacy edit-history import. |

## Query language

`NovagramSearchQuery.parse(_:)` understands `a | b`, `a yoki b`, `a или b`, `a or b` (OR), `-word` and `-"phrase"` (NOT), `"phrase"`, `«phrase»` and `#tag`.
Terms match at a word start, in both Uzbek scripts. `parse(_:languages:translations:)` adds transliterations and translations as OR alternatives; `serverQueries` (at most 5) and `hashtagTerms` (at most 3) feed the server search.

## Jobs

| Type | Purpose |
| ---- | ------- |
| `NovagramJobPostParser` | `parse(_:)` returns a `NovagramJobPostInfo`: kind (vacancy, resume, unknown), title, salary, cities, work formats, employment, experience, contacts. |
| `NovagramJobPostInfo`, `NovagramJobSalary`, `NovagramJobContact`, `NovagramJobCity` | Parsed post data. |
| `NovagramJobMode`, `NovagramJobPostKind`, `NovagramJobWorkFormat`, `NovagramJobEmployment`, `NovagramJobCurrency`, `NovagramJobPeriod` | Filter and post enums. |
| `NovagramJobFilter` | Mode, query, cities, formats, period, salary-only and languages; `accepts(text:info:date:now:query:)` takes a `NovagramSearchQuery`. |
| `NovagramJobSavedSearch`, `NovagramJobAccount` | A saved search with its alert switch; the account it belongs to. |
| `NovagramJobStore` | Thread-safe saved searches (20), watched channels (30) and last filter per account in `pro_messager`, `novagram_job_search_<peerId>` keys. |
| `NovagramJobPresets` | Hashtags and keywords per mode, 20 cities, channel discovery queries. |
| `NovagramJobChannelRelevance` | Channel discovery queries and the job signal of a channel title or username. |
| `NovagramJobSpamGuard` | Rejects crypto, betting and promo sources and posts. |

## Archive

Search in previous versions of edited messages and in deleted messages. The search works on plain records, so each app
can keep the data where it already is.

| Type | Purpose |
| ---- | ------- |
| `NovagramArchivedMessage` | One record: account peer and record id, chat peer id, message id, thread id, author, send date, text and kind `.edited(editDate:)` (one record per previous version, `editDate` = when it was replaced) or `.deleted(deletedAt:)`. `editedVersions(...)` turns a message's previous texts with their dates into edited records. |
| `NovagramArchiveIndex` | An immutable, deduplicated, normalized snapshot sorted by edit or deletion time, newest first. Build it from any records. |
| `NovagramArchiveSearch` | `search(_:in:isChatExcluded:)` over an index or a record array. Filters: kinds (`.edited`, `.deleted`, `.all`), account, chat. Matching uses `NovagramSearchQuery` (OR/NOT/phrases, Uzbek Latin and Cyrillic). An empty query lists every record. Paging by `NovagramArchiveSearchCursor`, stable when newer records arrive. |
| `NovagramArchiveSearchRequest`, `NovagramArchiveSearchPage`, `NovagramArchiveKinds` | The request (default 50 results, at most 200) and one page of results. |
| `NovagramMessageArchiveStore` | Optional persistence for an app that has no database copy: one JSON-lines file per account in a directory the app gives, a versioned header, append plus atomic compaction, a torn last line skipped on load. Deleted records are upserted (the earliest deletion time is kept), edited versions are deduplicated by text. Limits: 20,000 records and 90 days per account (`NovagramArchiveLimits`). `remove(chatPeerId:accountRecordId:)`, `clear(accountRecordId:)` at logout, `index(accountRecordId:)` for search. |
| `NovagramArchiveMacLegacyImport` | Reads the old macOS edit history (`uz.fenixuz.app.editedHistory` suite, `msg_<chat>_<message>` keys). |

Privacy: `isChatExcluded` is required and must return true for hidden and locked chats; their records never appear,
even in an in-chat search. Load the store and build an index off the main thread: about 300 ms for 20,000 records on a
debug build, then a search takes under 50 ms.

```swift
let index = store.index(accountRecordId: accountRecordId)
let request = NovagramArchiveSearchRequest(rawQuery: "uchrashuv", kinds: .deleted)
let page = NovagramArchiveSearch.search(request, in: index, isChatExcluded: { hiddenChats.contains($0) })
```

## macOS integration

```sh
git submodule add https://github.com/Novagramorg/novagram-search-kit-sdk.git packages/NovagramSearchKit
```

In the package that uses it:

```swift
dependencies: [
    .package(name: "NovagramSearchKit", path: "../NovagramSearchKit")
],
targets: [
    .target(name: "NovagramCore", dependencies: [
        .product(name: "NovagramSearchKit", package: "NovagramSearchKit")
    ])
]
```

## iOS integration

```sh
git submodule add https://github.com/Novagramorg/novagram-search-kit-sdk.git submodules/Novagram/SearchKit
```

Add the Bazel dependency to the module that uses it:

```python
deps = [
    "//submodules/Novagram/SearchKit:NovagramSearchKit",
]
```

The `BUILD` file builds the module with `-warnings-as-errors` and no dependencies.

## Tests

```sh
swift build -Xswiftc -warnings-as-errors
swift test
```

## License

NovagramSearchKit is licensed under GPL-2.0-or-later.

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General
Public License as published by the Free Software Foundation; either version 2 of the License, or (at your
option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details. The full text is in [LICENSE](LICENSE).
