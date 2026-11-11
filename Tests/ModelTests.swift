import Foundation

@main
struct ModelTests {
    static func main() throws {
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            if !condition() { fatalError(message) }
        }
        let sample = BirthDate(year: 2025, month: 1, day: 1)
        check(Zodiac(birth: sample) == .dragon, "Gregorian New Year is still the previous lunar year")
        // Synthetic calendar boundary fixtures, unrelated to any real profile
        check(Zodiac(birth: BirthDate(year: 2025, month: 1, day: 28)) == .dragon, "Lunar New Year's Eve")
        check(Zodiac(birth: BirthDate(year: 2025, month: 1, day: 29)) == .snake, "Lunar New Year's Day")
        for (index, zodiac) in Zodiac.allCases.enumerated() {
            check(Zodiac(birth: BirthDate(year: 2008 + index, month: 7, day: 1)) == zodiac, "All 12 zodiac years")
        }
        check(BirthDate(storageValue: "2025-02-30") == nil, "Reject normalized invalid dates")
        let suite = "com.caldis.babydays.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(sample.storageValue, forKey: BabyProfile.birthDateKey)
        var state = BabyProfile.load(from: defaults)
        check(state.babies.count == 1, "Migrate legacy birthday")
        let original = state.selected!.id
        check(original == "legacy-baby", "Concurrent first migration must resolve the same stable ID")
        check(BabyProfile.load(from: defaults).selected?.id == original, "Migration must preserve identity")
        let later = BirthDate(date: BabyAge.calendar.date(byAdding: .month, value: 2, to: sample.date())!)
        var second = Baby(name: "示例宝宝二", birth: later)
        state.upsert(second)
        second.name = "新称呼"
        state.upsert(second)
        check(state.babies.count == 2 && state.babies.last?.name == "新称呼", "Edit without duplicate IDs")
        state = BabyProfile.save(state, to: defaults)
        check(BabyProfile.baby(id: original, from: defaults)?.zodiac == .dragon, "First widget keeps first baby's theme")
        check(BabyProfile.baby(id: second.id, from: defaults)?.zodiac == .snake, "Second widget uses its own theme")
        state.iconMode = "automatic"; state.iconBabyID = second.id
        check(state.iconZodiac == second.zodiac, "Auto icon follows explicitly chosen baby")
        var changed = state.babies.last!
        changed.birth = sample
        state.upsert(changed)
        check(state.iconZodiac == .dragon, "Changing birthday updates the followed icon without changing the baby ID")
        state.remove(id: original)
        check(state.selected?.id == second.id, "Deleting selected baby selects remaining baby")
        check(!state.babies.contains { $0.id == original }, "Deleted widget association cannot match another baby")
        state = BabyProfile.save(state, to: defaults)
        check(BabyProfile.baby(id: original, from: defaults) == nil, "Removed widget does not fall back to remaining baby")
        check(BabyProfile.load(from: defaults) == state, "Round trip multiple profiles and icon preferences")
        state.remove(id: second.id)
        check(state.iconZodiac == .snake, "No babies falls back to default snake icon")
        state = BabyProfile.save(state, to: defaults)
        defaults.set(sample.storageValue, forKey: BabyProfile.birthDateKey)
        check(BabyProfile.load(from: defaults).babies.isEmpty, "Never reimport legacy date after deleting all babies")
        state.iconMode = "pig"
        check(state.iconZodiac == .pig, "Manual icon independent of birthday")
        print("Passed: lunar boundary, 12 zodiac years, validation, migration, stable IDs, deletion, icon selection, storage")
    }
}
