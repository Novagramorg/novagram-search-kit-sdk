import Foundation

/// How much a `NovagramMessageArchiveStore` keeps per account.
public struct NovagramArchiveLimits: Equatable {
    public static let defaultMaxRecordsPerAccount = 20_000
    public static let defaultMaxAge: Int32 = 90 * 24 * 60 * 60

    public var maxRecordsPerAccount: Int
    /// Records whose edit or deletion is older than this many seconds are dropped.
    public var maxAge: Int32

    public init(maxRecordsPerAccount: Int = NovagramArchiveLimits.defaultMaxRecordsPerAccount, maxAge: Int32 = NovagramArchiveLimits.defaultMaxAge) {
        self.maxRecordsPerAccount = max(maxRecordsPerAccount, 0)
        self.maxAge = max(maxAge, 0)
    }
}

/// A thread-safe, file-backed archive of edited versions and deleted messages, one file per account in `directory`.
///
/// Each file is versioned JSON lines: a header, a snapshot, then appended changes. A torn last line is skipped on
/// load and the file is rewritten atomically; changes are compacted into a new snapshot when they outgrow it.
/// An account is loaded lazily on first use and then served from memory.
public final class NovagramMessageArchiveStore {
    public static let formatVersion = 1
    static let formatName = "novagram-message-archive"
    static let compactionSlack = 1_000

    public let directory: URL
    public let limits: NovagramArchiveLimits

    private let now: () -> Int32
    private let lock = NSLock()
    private var accounts: [Int64: AccountArchive] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// A store in `directory`; `now` returns the current unix time in seconds.
    public init(directory: URL, limits: NovagramArchiveLimits = NovagramArchiveLimits(), now: @escaping () -> Int32 = { Int32(truncatingIfNeeded: Int64(Date().timeIntervalSince1970)) }) {
        self.directory = directory
        self.limits = limits
        self.now = now
    }

    /// The archive file of an account.
    public func fileURL(accountRecordId: Int64) -> URL {
        return directory.appendingPathComponent("\(NovagramMessageArchiveStore.formatName)-\(accountRecordId).jsonl")
    }

    /// Saves one record. A deleted record replaces the one of the same message, keeping the earliest deletion time;
    /// an edited version is skipped when the message already has a version with the same text.
    /// Returns true when the archive changed.
    @discardableResult
    public func save(_ record: NovagramArchivedMessage) -> Bool {
        return save([record]) > 0
    }

    /// Saves records with one file write per account. Returns how many changed the archive.
    @discardableResult
    public func save(_ records: [NovagramArchivedMessage]) -> Int {
        lock.lock()
        defer { lock.unlock() }
        var changed = 0
        var order: [Int64] = []
        var grouped: [Int64: [NovagramArchivedMessage]] = [:]
        for record in records {
            if grouped[record.accountRecordId] == nil {
                order.append(record.accountRecordId)
            }
            grouped[record.accountRecordId, default: []].append(record)
        }
        let cutoff = ageCutoff()
        for accountRecordId in order {
            let archive = loadedArchive(accountRecordId)
            var lines: [LogLine] = []
            for record in grouped[accountRecordId] ?? [] where Int64(record.kind.eventDate) >= cutoff {
                guard let stored = archive.merged(record) else { continue }
                archive.put(stored)
                if archive.accountPeerId == nil {
                    archive.accountPeerId = stored.accountPeerId
                }
                lines.append(LogLine(op: LogLine.put, record: stored))
            }
            guard !lines.isEmpty else { continue }
            changed += lines.count
            archive.prune(cutoff: cutoff, maxCount: limits.maxRecordsPerAccount)
            persist(lines, archive: archive)
        }
        return changed
    }

    /// The archived records of one message, oldest event first.
    public func records(accountRecordId: Int64, chatPeerId: Int64, messageId: Int32) -> [NovagramArchivedMessage] {
        lock.lock()
        defer { lock.unlock() }
        return loadedArchive(accountRecordId).rows.values
            .filter { $0.record.chatPeerId == chatPeerId && $0.record.messageId == messageId }
            .sorted { $1.key.precedes($0.key) }
            .map { $0.record }
    }

    /// The number of records of an account.
    public func count(accountRecordId: Int64) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return loadedArchive(accountRecordId).rows.count
    }

    /// A search snapshot of an account, cached until the next change.
    public func index(accountRecordId: Int64) -> NovagramArchiveIndex {
        lock.lock()
        defer { lock.unlock() }
        let archive = loadedArchive(accountRecordId)
        if let index = archive.index {
            return index
        }
        let index = NovagramArchiveIndex(unsortedRows: Array(archive.rows.values))
        archive.index = index
        return index
    }

    /// Removes every record of a chat, for example when the chat is deleted.
    public func remove(chatPeerId: Int64, accountRecordId: Int64) {
        lock.lock()
        defer { lock.unlock() }
        let archive = loadedArchive(accountRecordId)
        guard archive.removeChat(chatPeerId) else { return }
        persist([LogLine(op: LogLine.removeChat, chatPeerId: chatPeerId)], archive: archive)
    }

    /// Removes everything of an account and its file, for example at logout.
    public func clear(accountRecordId: Int64) {
        lock.lock()
        defer { lock.unlock() }
        accounts[accountRecordId] = AccountArchive(accountRecordId: accountRecordId)
        try? FileManager.default.removeItem(at: fileURL(accountRecordId: accountRecordId))
    }

    /// Applies the age and count limits now; they are also applied on load and on every save.
    public func prune(accountRecordId: Int64) {
        lock.lock()
        defer { lock.unlock() }
        let archive = loadedArchive(accountRecordId)
        if archive.prune(cutoff: ageCutoff(), maxCount: limits.maxRecordsPerAccount) {
            rewrite(archive)
        }
    }

    private func ageCutoff() -> Int64 {
        return Int64(now()) - Int64(limits.maxAge)
    }

    private func loadedArchive(_ accountRecordId: Int64) -> AccountArchive {
        if let archive = accounts[accountRecordId] {
            return archive
        }
        let archive = load(accountRecordId)
        accounts[accountRecordId] = archive
        return archive
    }

    private func load(_ accountRecordId: Int64) -> AccountArchive {
        let archive = AccountArchive(accountRecordId: accountRecordId)
        guard let data = try? Data(contentsOf: fileURL(accountRecordId: accountRecordId)), !data.isEmpty else {
            return archive
        }
        let lines = data.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true)
        var needsRewrite = data.last != UInt8(ascii: "\n")
        if let first = lines.first, let header = try? decoder.decode(Header.self, from: Data(first)), header.format == NovagramMessageArchiveStore.formatName {
            guard header.version <= NovagramMessageArchiveStore.formatVersion else {
                archive.isWritable = false
                return archive
            }
            archive.accountPeerId = header.accountPeerId
        } else {
            needsRewrite = true
        }
        for line in lines.dropFirst() {
            guard let entry = try? decoder.decode(LogLine.self, from: Data(line)) else {
                needsRewrite = true
                continue
            }
            archive.apply(entry)
        }
        archive.pendingLines = max(lines.count - 2, 0)
        if archive.prune(cutoff: ageCutoff(), maxCount: limits.maxRecordsPerAccount) {
            needsRewrite = true
        }
        if needsRewrite {
            rewrite(archive)
        }
        return archive
    }

    private func persist(_ lines: [LogLine], archive: AccountArchive) {
        guard archive.isWritable else { return }
        let url = fileURL(accountRecordId: archive.accountRecordId)
        if archive.needsRewrite || archive.pendingLines + lines.count > archive.rows.count + NovagramMessageArchiveStore.compactionSlack || !FileManager.default.fileExists(atPath: url.path) {
            rewrite(archive)
            return
        }
        var data = Data()
        for line in lines {
            guard let encoded = try? encoder.encode(line) else { continue }
            data.append(encoded)
            data.append(UInt8(ascii: "\n"))
        }
        if NovagramMessageArchiveStore.append(data, to: url) {
            archive.pendingLines += lines.count
        } else {
            archive.needsRewrite = true
        }
    }

    private func rewrite(_ archive: AccountArchive) {
        guard archive.isWritable else { return }
        let header = Header(format: NovagramMessageArchiveStore.formatName, version: NovagramMessageArchiveStore.formatVersion, accountRecordId: archive.accountRecordId, accountPeerId: archive.accountPeerId)
        let records = NovagramArchiveIndex(unsortedRows: Array(archive.rows.values)).records
        do {
            var data = try encoder.encode(header)
            data.append(UInt8(ascii: "\n"))
            data.append(try encoder.encode(LogLine(op: LogLine.snapshot, records: records)))
            data.append(UInt8(ascii: "\n"))
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            try data.write(to: fileURL(accountRecordId: archive.accountRecordId), options: .atomic)
            archive.pendingLines = 0
            archive.needsRewrite = false
        } catch {
            archive.needsRewrite = true
        }
    }

    private static func append(_ data: Data, to url: URL) -> Bool {
        let descriptor = open(url.path, O_WRONLY | O_APPEND)
        guard descriptor >= 0 else { return false }
        defer { close(descriptor) }
        return data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Bool in
            guard var pointer = buffer.baseAddress else { return true }
            var remaining = buffer.count
            while remaining > 0 {
                let written = write(descriptor, pointer, remaining)
                if written < 0 {
                    if errno == EINTR {
                        continue
                    }
                    return false
                }
                remaining -= written
                pointer += written
            }
            return true
        }
    }
}

extension NovagramMessageArchiveStore: @unchecked Sendable {}

private struct Header: Codable {
    let format: String
    let version: Int
    let accountRecordId: Int64
    let accountPeerId: Int64?
}

private struct LogLine: Codable {
    static let put = "put"
    static let snapshot = "snapshot"
    static let removeChat = "removeChat"

    let op: String
    var record: NovagramArchivedMessage?
    var records: [NovagramArchivedMessage]?
    var chatPeerId: Int64?

    init(op: String, record: NovagramArchivedMessage? = nil, records: [NovagramArchivedMessage]? = nil, chatPeerId: Int64? = nil) {
        self.op = op
        self.record = record
        self.records = records
        self.chatPeerId = chatPeerId
    }
}

private final class AccountArchive {
    static let linearPruneLimit = 16

    let accountRecordId: Int64
    var accountPeerId: Int64?
    var rows: [NovagramArchivedMessage.Identity: NovagramArchiveIndex.Row] = [:]
    var index: NovagramArchiveIndex?
    var pendingLines = 0
    var needsRewrite = false
    var isWritable = true

    init(accountRecordId: Int64) {
        self.accountRecordId = accountRecordId
    }

    func merged(_ record: NovagramArchivedMessage) -> NovagramArchivedMessage? {
        guard let existing = rows[record.identity]?.record else {
            return record
        }
        guard case let .deleted(newDeletedAt) = record.kind, case let .deleted(oldDeletedAt) = existing.kind else {
            return nil
        }
        let updated = NovagramArchivedMessage(accountPeerId: record.accountPeerId, accountRecordId: record.accountRecordId, chatPeerId: record.chatPeerId, messageId: record.messageId, threadId: record.threadId ?? existing.threadId, authorPeerId: record.authorPeerId ?? existing.authorPeerId, date: record.date, kind: .deleted(deletedAt: min(oldDeletedAt, newDeletedAt)), text: record.text)
        return updated == existing ? nil : updated
    }

    func put(_ record: NovagramArchivedMessage) {
        let identity = record.identity
        let normalized = rows[identity].flatMap { $0.record.text == record.text ? $0.normalizedText : nil }
        rows[identity] = NovagramArchiveIndex.row(record, normalizedText: normalized)
        index = nil
    }

    func apply(_ line: LogLine) {
        switch line.op {
        case LogLine.put:
            if let record = line.record {
                put(record)
            }
        case LogLine.snapshot:
            for record in line.records ?? [] {
                put(record)
            }
        case LogLine.removeChat:
            if let chatPeerId = line.chatPeerId {
                _ = removeChat(chatPeerId)
            }
        default:
            break
        }
    }

    func removeChat(_ chatPeerId: Int64) -> Bool {
        let before = rows.count
        rows = rows.filter { $0.key.chatPeerId != chatPeerId }
        guard rows.count != before else { return false }
        index = nil
        return true
    }

    @discardableResult
    func prune(cutoff: Int64, maxCount: Int) -> Bool {
        let before = rows.count
        rows = rows.filter { Int64($0.value.key.eventDate) >= cutoff }
        let overflow = rows.count - maxCount
        if overflow > 0 && overflow <= AccountArchive.linearPruneLimit {
            for _ in 0..<overflow {
                guard let oldest = rows.values.min(by: { $1.key.precedes($0.key) }) else { break }
                rows.removeValue(forKey: oldest.record.identity)
            }
        } else if overflow > 0 {
            let kept = rows.values.sorted { $0.key.precedes($1.key) }.prefix(maxCount)
            var trimmed: [NovagramArchivedMessage.Identity: NovagramArchiveIndex.Row] = [:]
            for row in kept {
                trimmed[row.record.identity] = row
            }
            rows = trimmed
        }
        guard rows.count != before else { return false }
        index = nil
        return true
    }
}
