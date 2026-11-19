
import SwiftUI
import SwiftData

struct JotHistoryView: View {

    // MARK: - Environment

    @Environment(\.colorScheme)
    private var colorScheme

    @Environment(\.dismiss)
    private var dismiss

    @Query private var allJots: [DailyJot]

    // MARK: - Calendar State

    @State private var displayedMonth = Date.now
    @State private var selectedDate = Date.now

    private let weekdays = [
        "M", "T", "W", "T", "F", "S", "S"
    ]

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 0), spacing: 0),
        count: 7
    )

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        return calendar
    }

    // MARK: - Jot Data

    private var groupedJots: [String: [DailyJot]] {
        Dictionary(
            grouping: allJots.filter {
                !$0.content.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty
            },
            by: \.dayKey
        )
    }

    private var selectedJots: [DailyJot] {
        let key = JotDay.key(for: selectedDate)

        return (groupedJots[key] ?? [])
            .sorted {
                if $0.position == $1.position {
                    return $0.createdAt < $1.createdAt
                }

                return $0.position < $1.position
            }
    }

    // MARK: - Month Calculation

    private var monthStart: Date {
        calendar.dateInterval(
            of: .month,
            for: displayedMonth
        )?.start ?? displayedMonth
    }

    private var monthDates: [Date] {
        guard let range = calendar.range(
            of: .day,
            in: .month,
            for: monthStart
        ) else {
            return []
        }

        return range.compactMap { day in
            calendar.date(
                byAdding: .day,
                value: day - 1,
                to: monthStart
            )
        }
    }

    private var leadingBlanks: Int {
        let weekday = calendar.component(
            .weekday,
            from: monthStart
        )

        return (
            weekday - calendar.firstWeekday + 7
        ) % 7
    }

    private var canMoveForward: Bool {
        calendar.compare(
            displayedMonth,
            to: .now,
            toGranularity: .month
        ) == .orderedAscending
    }

    // MARK: - Main View

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 24
                ) {
                    pageHeader

                    monthSelector

                    calendarCard

                    calendarLegend

                    selectedDayPreview

                    openJotsButton
                }
                .padding(AppTheme.screenPadding)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
            }
            .scrollIndicators(.hidden)
            .background {
                AppTheme.background(colorScheme)
                    .ignoresSafeArea()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .confirmationAction
                ) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(
                        AppTheme.text(colorScheme)
                    )
                }
            }
        }
        .environment(
            \.locale,
            Locale(identifier: "en_US")
        )
    }

    // MARK: - Page Header

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 8) {

            Text("Jot history.")
                .font(.system(
                    size: 42,
                    weight: .medium
                ))
                .tracking(-1.8)
                .foregroundStyle(
                    AppTheme.text(colorScheme)
                )
                .accessibilityAddTraits(.isHeader)

            Text("Every thought has its place.")
                .font(.system(size: 15))
                .foregroundStyle(
                    AppTheme.secondaryText(colorScheme)
                )
        }
    }

    // MARK: - Month Selector

    private var monthSelector: some View {
        HStack {

            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(
                        size: 16,
                        weight: .medium
                    ))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Previous month")

            Spacer()

            Text(
                displayedMonth,
                format: .dateTime
                    .month(.wide)
                    .year()
            )
            .font(.system(
                size: 17,
                weight: .medium
            ))

            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(
                        size: 16,
                        weight: .medium
                    ))
                    .frame(width: 44, height: 44)
            }
            .disabled(!canMoveForward)
            .opacity(canMoveForward ? 1 : 0.3)
            .accessibilityLabel("Next month")
        }
        .foregroundStyle(
            AppTheme.text(colorScheme)
        )
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassEffect(.regular, in: Capsule())
    }

    // MARK: - Calendar Grid

    private var calendarCard: some View {

        let daysWithJots = Set(groupedJots.keys)
        let dates = monthDates

        let totalCells = (
            (leadingBlanks + dates.count + 6) / 7
        ) * 7

        return VStack(spacing: 12) {

            // Weekday Header

            LazyVGrid(columns: columns, spacing: 0) {

                ForEach(
                    weekdays.indices,
                    id: \.self
                ) { index in

                    Text(weekdays[index])
                        .font(.system(
                            size: 12,
                            weight: .medium
                        ))
                        .foregroundStyle(
                            AppTheme.secondaryText(colorScheme)
                        )
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 10)

            // Calendar Dates

            LazyVGrid(columns: columns, spacing: 3) {

                ForEach(0..<totalCells, id: \.self) { index in

                    let dateIndex = index - leadingBlanks

                    if dates.indices.contains(dateIndex) {

                        let date = dates[dateIndex]

                        let hasJots = daysWithJots.contains(
                            JotDay.key(for: date)
                        )

                        let joinsPrevious =
                            hasJots &&
                            index % 7 != 0 &&
                            dateIndex > 0 &&
                            daysWithJots.contains(
                                JotDay.key(
                                    for: dates[dateIndex - 1]
                                )
                            )

                        let joinsNext =
                            hasJots &&
                            index % 7 != 6 &&
                            dateIndex + 1 < dates.count &&
                            daysWithJots.contains(
                                JotDay.key(
                                    for: dates[dateIndex + 1]
                                )
                            )

                        dayCell(
                            date,
                            hasJots: hasJots,
                            joinsPrevious: joinsPrevious,
                            joinsNext: joinsNext
                        )

                    } else {

                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 28)
                    .fill(AppTheme.surface(colorScheme))
            }
        }
    }



    // MARK: - Calendar Day Cell

    private func dayCell(
        _ date: Date,
        hasJots: Bool,
        joinsPrevious: Bool,
        joinsNext: Bool
    ) -> some View {

        let isSelected = calendar.isDate(
            date,
            inSameDayAs: selectedDate
        )

        let isToday = calendar.isDateInToday(date)

        let isFuture = calendar.startOfDay(for: date)
            > calendar.startOfDay(for: .now)

        let day = calendar.component(
            .day,
            from: date
        )

        let textColor: Color =
            isSelected || hasJots
            ? AppTheme.obsidian
            : AppTheme.text(colorScheme)

        return Button {

            withAnimation(.spring(
                response: 0.3,
                dampingFraction: 0.8
            )) {
                selectedDate = date
            }

        } label: {

            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {

                    GeometryReader { geometry in

                        let cellSize = min(
                            geometry.size.width,
                            geometry.size.height
                        )

                        let cornerRadius = cellSize / 2

                        let innerPadding: CGFloat = 4

                        let circleSize = max(
                            0,
                            cellSize - (innerPadding * 2)
                        )

                        ZStack {

                            // MARK: Capsule Background

                            if hasJots {

                                if !joinsPrevious && !joinsNext {

                                    // Perfect circle for single date

                                    Circle()
                                        .fill(AppTheme.lilac)

                                } else {

                                    // Connected capsule

                                    UnevenRoundedRectangle(
                                        topLeadingRadius:
                                            joinsPrevious ? 0 : cornerRadius,

                                        bottomLeadingRadius:
                                            joinsPrevious ? 0 : cornerRadius,

                                        bottomTrailingRadius:
                                            joinsNext ? 0 : cornerRadius,

                                        topTrailingRadius:
                                            joinsNext ? 0 : cornerRadius,

                                        style: .circular
                                    )
                                    .fill(AppTheme.lilac)
                                }
                            }

                            // MARK: Selected Date

                            if isSelected {

                                Circle()
                                    .fill(AppTheme.lime)
                                    .frame(
                                        width: circleSize,
                                        height: circleSize
                                    )

                            } else if isToday {

                                // MARK: Today Outline

                                Circle()
                                    .strokeBorder(
                                        hasJots
                                        ? AppTheme.forestBlack
                                        : AppTheme.secondaryText(
                                            colorScheme
                                        ),
                                        lineWidth: 1
                                    )
                                    .frame(
                                        width: circleSize,
                                        height: circleSize
                                    )
                            }

                            // MARK: Centered Date Number

                            Text("\(day)")
                                .font(.system(
                                    size: 15,
                                    weight: isSelected
                                        ? .semibold
                                        : .medium
                                ))
                                .foregroundStyle(textColor)
                                .monospacedDigit()

                            // MARK: Status Dot

                            if hasJots && isSelected {

                                Circle()
                                    .fill(AppTheme.forestBlack)
                                    .frame(
                                        width: 5,
                                        height: 5
                                    )
                                    .offset(
                                        y: -(circleSize / 2) + 1
                                    )
                            }
                        }
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height
                        )
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .opacity(isFuture ? 0.25 : 1)
        .accessibilityLabel(
            Text(
                date,
                format: .dateTime
                    .month(.wide)
                    .day()
                    .year()
            )
        )
        .accessibilityValue(
            hasJots
            ? "Contains unorganized jots"
            : "No jots"
        )
        .accessibilityAddTraits(
            isSelected ? .isSelected : []
        )
    }


    // MARK: - Calendar Legend

    private var calendarLegend: some View {
        HStack(spacing: 20) {

            legendItem(
                color: AppTheme.lilac,
                title: "Unorganized"
            )

            legendItem(
                color: AppTheme.lime,
                title: "Selected"
            )

            Spacer()
        }
    }

    private func legendItem(
        color: Color,
        title: String
    ) -> some View {
        HStack(spacing: 6) {

            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(
                    AppTheme.secondaryText(colorScheme)
                )
        }
    }

    // MARK: - Selected Date Preview

    private var selectedDayPreview: some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack {

                Text(
                    selectedDate,
                    format: .dateTime
                        .month(.wide)
                        .day()
                )
                .font(.system(
                    size: 24,
                    weight: .medium
                ))
                .foregroundStyle(
                    AppTheme.text(colorScheme)
                )

                Spacer()

                Text(
                    "\(selectedJots.count) " +
                    (selectedJots.count == 1 ? "jot" : "jots")
                )
                .font(.system(size: 13))
                .foregroundStyle(
                    AppTheme.secondaryText(colorScheme)
                )
            }

            VStack(
                alignment: .leading,
                spacing: 16
            ) {
                if selectedJots.isEmpty {
                    Text(
                        "No thoughts recorded on this day."
                    )
                    .font(.system(size: 15))
                    .foregroundStyle(
                        AppTheme.secondaryText(colorScheme)
                    )

                } else {

                    ForEach(
                        selectedJots,
                        id: \.id
                    ) { jot in

                        HStack(
                            alignment: .top,
                            spacing: 12
                        ) {
                            Circle()
                                .fill(AppTheme.lilac)
                                .frame(width: 6, height: 6)
                                .padding(.top, 7)

                            Text(jot.content)
                                .font(.system(size: 16))
                                .foregroundStyle(
                                    AppTheme.text(colorScheme)
                                )
                                .lineSpacing(4)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                        }

                        if jot.id != selectedJots.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .padding(20)
            .background {
                RoundedRectangle(
                    cornerRadius: AppTheme.cardRadius
                )
                .fill(AppTheme.surface(colorScheme))
            }
        }
    }

    // MARK: - Open Historical Jots

    private var openJotsButton: some View {
        NavigationLink {
            ScrollView {
                DailyJotsView(
                    historyDayKey: JotDay.key(
                        for: selectedDate
                    )
                )
                .padding(AppTheme.screenPadding)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background {
                AppTheme.background(colorScheme)
                    .ignoresSafeArea()
            }
            .navigationTitle("Jot history")
            .navigationBarTitleDisplayMode(.inline)

        } label: {

            HStack {
                Spacer()

                Text("Open daily jots")
                    .font(.system(
                        size: 16,
                        weight: .semibold
                    ))

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13))

                Spacer()
            }
            .foregroundStyle(AppTheme.obsidian)
            .padding(.vertical, 18)
            .background(
                AppTheme.lime,
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Change Month

    private func moveMonth(by value: Int) {

        if value > 0 && !canMoveForward {
            return
        }

        guard let newMonth = calendar.date(
            byAdding: .month,
            value: value,
            to: monthStart
        ) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {

            displayedMonth = newMonth

            if calendar.isDate(
                newMonth,
                equalTo: .now,
                toGranularity: .month
            ) {
                selectedDate = .now
            } else {
                selectedDate = newMonth
            }
        }
    }
}

#Preview {
    JotHistoryView()
        .modelContainer(
            for: DailyJot.self,
            inMemory: true
        )
}
