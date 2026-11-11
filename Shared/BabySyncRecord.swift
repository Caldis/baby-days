import Foundation

/// A monotonic, device-tied timestamp, shared by individual fields rather than the whole list.
struct BabySyncStamp: Codable, Equatable, Comparable, Sendable {
    var tick: Int64
    var writer: String

    static let initial = BabySyncStamp(tick: 0, writer: "")
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.tick == rhs.tick ? lhs.writer < rhs.writer : lhs.tick < rhs.tick
    }
}

struct BabySyncField<Value: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    var value: Value
    var stamp: BabySyncStamp

    mutating func merge(_ other: Self) {
        if stamp < other.stamp { self = other }
        else if stamp == other.stamp && value != other.value {
            // Old, pre-sync backups can have distinct values with the same initial stamp.
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            if let lhs = try? encoder.encode(value), let rhs = try? encoder.encode(other.value),
               lhs.lexicographicallyPrecedes(rhs) { self = other }
        }
    }
}

/// Deleted IDs are never reused. Keeping the tombstone prevents an offline edit from reviving one.
struct BabySyncRecord: Codable, Equatable, Sendable {
    static let keyPrefix = "baby.v1."
    var format = 1
    var id: String
    var name: BabySyncField<String>
    var birth: BabySyncField<BirthDate>
    var created: BabySyncStamp
    var deleted = false

    init(baby: Baby, stamp: BabySyncStamp = .initial) {
        id = baby.id
        name = BabySyncField(value: baby.name, stamp: stamp)
        birth = BabySyncField(value: baby.birth, stamp: stamp)
        created = stamp
    }

    private enum CodingKeys: String, CodingKey { case format, id, name, birth, created, deleted }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        format = try container.decode(Int.self, forKey: .format)
        id = try container.decode(String.self, forKey: .id)
        created = try container.decode(BabySyncStamp.self, forKey: .created)
        deleted = try container.decode(Bool.self, forKey: .deleted)
        if deleted {
            name = BabySyncField(value: "", stamp: .initial)
            birth = BabySyncField(value: BirthDate(year: 2025, month: 1, day: 1), stamp: .initial)
        } else {
            name = try container.decode(BabySyncField<String>.self, forKey: .name)
            birth = try container.decode(BabySyncField<BirthDate>.self, forKey: .birth)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(format, forKey: .format)
        try container.encode(id, forKey: .id)
        try container.encode(created, forKey: .created)
        try container.encode(deleted, forKey: .deleted)
        if !deleted {
            try container.encode(name, forKey: .name)
            try container.encode(birth, forKey: .birth)
        }
    }

    mutating func markDeleted() {
        deleted = true
        name = BabySyncField(value: "", stamp: .initial)
        birth = BabySyncField(value: BirthDate(year: 2025, month: 1, day: 1), stamp: .initial)
    }

    var key: String { Self.keyPrefix + id }
    var lastTick: Int64 { max(created.tick, max(name.stamp.tick, birth.stamp.tick)) }
    var isValid: Bool {
        format == 1 && !id.isEmpty && key.utf8.count <= 64 && name.value.count <= 100
            && BirthDate(storageValue: birth.value.storageValue) != nil
            && [created.tick, name.stamp.tick, birth.stamp.tick].allSatisfy { $0 >= 0 && $0 < Int64.max - 1 }
            && [created.writer, name.stamp.writer, birth.stamp.writer].allSatisfy { $0.utf8.count <= 128 }
    }
    var baby: Baby {
        // Stable across repeated imports, and changes when any displayed data changes.
        Baby(id: id, name: name.value, birth: birth.value,
             revision: "\(name.stamp.tick)-\(name.stamp.writer)-\(birth.stamp.tick)-\(birth.stamp.writer)")
    }

    mutating func merge(_ other: Self) {
        guard id == other.id else { return }
        name.merge(other.name)
        birth.merge(other.birth)
        created = min(created, other.created)
        deleted = deleted || other.deleted
        if deleted { markDeleted() }
    }

    static func decode(_ data: Data, key: String) -> Self? {
        guard let value = try? JSONDecoder().decode(Self.self, from: data), value.isValid,
              value.key == key else { return nil }
        return value
    }
}

/// This local journal lives in the same JSON transaction as the visible collection.
struct BabySyncState: Codable, Equatable, Sendable {
    var writer = UUID().uuidString
    var clock: Int64 = 0
    var records: [String: BabySyncRecord] = [:]

    init(babies: [Baby] = []) {
        for baby in babies { records[baby.id] = BabySyncRecord(baby: baby) }
    }

    mutating func merge(_ incoming: [BabySyncRecord]) {
        for item in incoming where item.isValid {
            if var existing = records[item.id] {
                existing.merge(item)
                records[item.id] = existing
            } else { records[item.id] = item }
            clock = max(clock, item.lastTick)
        }
    }

    /// Apply only the user's edits relative to the snapshot they edited. Concurrent arrivals survive.
    mutating func edit(from base: BabySyncState, to babies: [Baby], now: Date = .now) {
        merge(Array(base.records.values))
        let before = records
        let tick = max(Int64(now.timeIntervalSince1970 * 1000), clock + 1)
        let stamp = BabySyncStamp(tick: tick, writer: writer)
        let desired = Dictionary(babies.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        for (id, old) in base.records where !old.deleted && desired[id] == nil {
            records[id]?.markDeleted()
        }
        for baby in babies {
            guard records[baby.id]?.deleted != true else { continue }
            if let old = base.records[baby.id], var record = records[baby.id] {
                if old.name.value != baby.name { record.name = BabySyncField(value: baby.name, stamp: stamp) }
                if old.birth.value != baby.birth { record.birth = BabySyncField(value: baby.birth, stamp: stamp) }
                records[baby.id] = record
            } else { records[baby.id] = BabySyncRecord(baby: baby, stamp: stamp) }
        }
        if records != before { clock = max(clock, tick) }
    }

    func babies(keeping order: [Baby]) -> [Baby] {
        let existing = Set(order.map(\.id))
        let retained = order.compactMap { records[$0.id] }.filter { !$0.deleted }
        let added = records.values.filter { !existing.contains($0.id) && !$0.deleted }.sorted {
            $0.created == $1.created ? $0.id < $1.id : $0.created < $1.created
        }
        return (retained + added).map(\.baby)
    }
}
