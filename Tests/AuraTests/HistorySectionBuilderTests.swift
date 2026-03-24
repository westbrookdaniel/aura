import Foundation
import Testing
@testable import Aura

struct HistorySectionBuilderTests {
    @Test
    func groupsItemsIntoTodayYesterdayAndOlderDates() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let todayItem = VoiceTextHistoryItem(
            id: UUID(),
            text: "today",
            createdAt: now.addingTimeInterval(-60)
        )
        let yesterdayItem = VoiceTextHistoryItem(
            id: UUID(),
            text: "yesterday",
            createdAt: calendar.date(byAdding: .day, value: -1, to: now)!.addingTimeInterval(-120)
        )
        let olderDate = calendar.date(byAdding: .day, value: -3, to: now)!
        let olderItem = VoiceTextHistoryItem(
            id: UUID(),
            text: "older",
            createdAt: olderDate
        )

        let sections = HistorySectionBuilder.makeSections(
            from: [olderItem, yesterdayItem, todayItem],
            now: now,
            calendar: calendar
        )

        #expect(sections.map(\.title).prefix(2).elementsEqual(["Today", "Yesterday"]))
        #expect(sections.count == 3)
        #expect(sections[0].items == [todayItem])
        #expect(sections[1].items == [yesterdayItem])
        #expect(sections[2].items == [olderItem])
        #expect(sections[2].title != "Today")
        #expect(sections[2].title != "Yesterday")
    }

    @Test
    func sortsItemsWithinEachDayNewestFirst() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let newer = VoiceTextHistoryItem(
            id: UUID(),
            text: "newer",
            createdAt: now.addingTimeInterval(-30)
        )
        let older = VoiceTextHistoryItem(
            id: UUID(),
            text: "older",
            createdAt: now.addingTimeInterval(-300)
        )

        let sections = HistorySectionBuilder.makeSections(
            from: [older, newer],
            now: now,
            calendar: calendar
        )

        #expect(sections.count == 1)
        #expect(sections[0].title == "Today")
        #expect(sections[0].items == [newer, older])
    }
}
