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
