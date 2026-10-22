import SwiftUI

/// A readable month grid; changing the date preserves the selected hour and minute.
struct CalendarMonthPicker: View {
    @Binding var selection: Date
    @State private var displayedMonth: Date
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    init(selection: Binding<Date>) {
        _selection = selection
        _displayedMonth = State(initialValue: selection.wrappedValue)
    }

    private var days: [Date] {
        guard let start = calendar.dateInterval(of: .month, for: displayedMonth)?.start else { return [] }
        let offset = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0 - offset, to: start) }
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text(displayedMonth, format: .dateTime.year().month(.wide))
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                monthButton("上一月", symbol: "chevron.left", offset: -1)
                monthButton("下一月", symbol: "chevron.right", offset: 1)
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<7, id: \.self) { index in
                    Text(calendar.veryShortStandaloneWeekdaySymbols[(index + calendar.firstWeekday - 1) % 7])
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        .frame(height: 24).accessibilityHidden(true)
                }
                ForEach(days, id: \.self) { day in
                    let selected = calendar.isDate(day, inSameDayAs: selection)
                    let currentMonth = calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month)
                    Button {
                        if let date = Self.selecting(day, preservingTimeFrom: selection, calendar: calendar) {
                            selection = date
                        }
                    } label: {
                        Text("\(calendar.component(.day, from: day))")
                            .font(.system(size: 14, weight: selected ? .semibold : .regular))
                            .foregroundStyle(selected ? Color.white : calendar.isDateInToday(day)
                                ? Color.accentColor : currentMonth ? Color.primary : Color.secondary.opacity(0.55))
                            .frame(maxWidth: .infinity).frame(height: 34)
                            .background(selected ? Color.accentColor : .clear, in: Circle())
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(day, format: .dateTime.year().month().day().weekday(.wide)))
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .onChange(of: selection) { _, date in
            if !calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month) { displayedMonth = date }
        }
    }

    private func monthButton(_ title: String, symbol: String, offset: Int) -> some View {
        Button {
            if let date = calendar.date(byAdding: .month, value: offset, to: displayedMonth) {
                displayedMonth = calendar.dateInterval(of: .month, for: date)?.start ?? date
            }
        } label: {
            Image(mingCute: symbol, size: 12)
                .frame(width: 28, height: 28).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityLabel(Text(NSLocalizedString(title, comment: "")))
    }

    static func selecting(_ day: Date, preservingTimeFrom date: Date, calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: calendar.component(.hour, from: date),
                      minute: calendar.component(.minute, from: date),
                      second: calendar.component(.second, from: date), of: day)
    }
}


/// Date-only variant of the creation dialog's date row and its existing month picker.
struct CalendarDateSelection: View {
    let label: String
    @Binding var selection: Date
    @State private var showingCalendar = false

    var body: some View {
        Button { showingCalendar = true } label: {
            HStack(spacing: 8) {
                Text(selection, format: .dateTime.year().month().day())
                Spacer(minLength: 0)
            }
            .font(.system(size: 14)).padding(14).calendarEditorRow()
        }
        .buttonStyle(.plain).accessibilityLabel(label)
        .popover(isPresented: $showingCalendar) {
            CalendarMonthPicker(selection: $selection)
                .frame(width: 280).padding(16).fixedSize()
        }
    }
}
