# NovagramSearchKit

The platform-independent search logic of Novagram, shared by the macOS app (SwiftPM) and the iOS app (Bazel).
Foundation only: Postbox, TelegramCore, SwiftSignalKit and UI stay in the apps as thin adapters.

## What is inside

| Folder           | Contents                                                                                                                                                           |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Core/`          | `NovagramSearchText` (case, diacritic, apostrophe and whitespace normalization) and `NovagramSearchClock` (injectable time).                                       |
| `ChatFilter/`    | Exact `"phrase"` and `re:` search inside a chat: query parsing, per-message matcher, page filter with time and size caps, paging rules, paging-state cache.        |
| `Filters/`       | Global search Messages filters (date range, Unread only, Mentions only, header title parts) and the filled-paging rules (20 results, 5 extra pages, 3 auto-loads). |
| `SavedSearches/` | Saved and pinned global search queries per account in the `pro_messager` suite, JSON compatible with both apps.                                                    |
| `Translation/`   | Translated-query rules (3+ characters, no `#`/`$`, no section when equal to the query) and the 200-entry cache.                                                    |
| `Settings/`      | `novagram_search_features` (default on), `novagram_search_translate` (default off), key and deep-link slug constants.                                              |

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
