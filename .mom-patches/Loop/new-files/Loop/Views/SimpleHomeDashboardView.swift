//
//  SimpleHomeDashboardView.swift
//  Loop
//

import SwiftUI
import HealthKit
import LoopKit
import LoopKitUI

final class SimpleHomeDashboardViewModel: ObservableObject {
    struct LastBolus {
        var amountText: String
        var timeText: String
    }

    @Published var activeInsulinText: String
    @Published var lastBolus: LastBolus?
    @Published var basalItems: [RepeatingScheduleValue<Double>]
    @Published var currentBasalText: String
    @Published var activityLevels: [TemporaryScheduleOverridePreset]
    @Published var activeActivityID: UUID?
    @Published var activeActivityDetail: String?

    var onSelectActivity: (TemporaryScheduleOverridePreset?) -> Void = { _ in }
    var onEditBasal: () -> Void = {}
    var onAddActivity: () -> Void = {}
    var onEditActivity: (TemporaryScheduleOverridePreset) -> Void = { _ in }

    init() {
        self.activeInsulinText = "—"
        self.lastBolus = nil
        self.basalItems = []
        self.currentBasalText = "—"
        self.activityLevels = []
        self.activeActivityID = nil
        self.activeActivityDetail = nil
    }

    static func defaultActivityLevels() -> [TemporaryScheduleOverridePreset] {
        [
            TemporaryScheduleOverridePreset(
                symbol: "🏋️",
                name: NSLocalizedString("Workout", comment: "Default activity level name for exercise"),
                settings: TemporaryScheduleOverrideSettings(unit: .milligramsPerDeciliter, targetRange: nil, insulinNeedsScaleFactor: 0.5),
                duration: .finite(.hours(2))
            ),
            TemporaryScheduleOverridePreset(
                symbol: "🚶",
                name: NSLocalizedString("Active", comment: "Default activity level name for being active"),
                settings: TemporaryScheduleOverrideSettings(unit: .milligramsPerDeciliter, targetRange: nil, insulinNeedsScaleFactor: 0.8),
                duration: .finite(.hours(3))
            ),
            TemporaryScheduleOverridePreset(
                symbol: "😌",
                name: NSLocalizedString("Chilling", comment: "Default activity level name for resting"),
                settings: TemporaryScheduleOverrideSettings(unit: .milligramsPerDeciliter, targetRange: nil, insulinNeedsScaleFactor: 1.0),
                duration: .indefinite
            )
        ]
    }

    func apply(
        activeInsulinText: String,
        lastBolus: LastBolus?,
        basalItems: [RepeatingScheduleValue<Double>],
        currentBasalText: String,
        activityLevels: [TemporaryScheduleOverridePreset],
        activeOverride: TemporaryScheduleOverride?
    ) {
        self.activeInsulinText = activeInsulinText
        self.lastBolus = lastBolus
        self.basalItems = basalItems
        self.currentBasalText = currentBasalText
        self.activityLevels = activityLevels

        if let activeOverride, !activeOverride.hasFinished() {
            switch activeOverride.context {
            case .preset(let preset):
                activeActivityID = preset.id
            default:
                activeActivityID = nil
            }

            switch activeOverride.duration {
            case .finite:
                let endTime = DateFormatter.localizedString(from: activeOverride.activeInterval.end, dateStyle: .none, timeStyle: .short)
                activeActivityDetail = String(format: NSLocalizedString("Until %@", comment: "Home screen subtitle for a timed activity level"), endTime)
            case .indefinite:
                activeActivityDetail = NSLocalizedString("Until you change it", comment: "Home screen subtitle for an activity level without an end time")
            }
        } else {
            activeActivityID = nil
            activeActivityDetail = nil
        }
    }
}

struct SimpleHomeDashboardView: View {
    @ObservedObject var viewModel: SimpleHomeDashboardViewModel
    @Environment(\.insulinTintColor) private var insulinTintColor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            statsRow
            activitySection
            basalSection
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(
                title: NSLocalizedString("Active Insulin", comment: "Home screen title for insulin on board"),
                value: viewModel.activeInsulinText,
                detail: NSLocalizedString("Still working", comment: "Home screen caption for active insulin")
            )
            statCard(
                title: NSLocalizedString("Last Bolus", comment: "Home screen title for most recent bolus"),
                value: viewModel.lastBolus?.amountText ?? NSLocalizedString("None yet", comment: "Home screen value when no bolus has been given"),
                detail: viewModel.lastBolus?.timeText ?? " "
            )
        }
    }

    private func statCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .bold()
                .foregroundColor(insulinTintColor)
            Text(detail)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(NSLocalizedString("Activity", comment: "Home screen title for activity levels"))
                    .font(.headline)
                Spacer()
                Button(action: viewModel.onAddActivity) {
                    Label(NSLocalizedString("Add", comment: "Button to add an activity level"), systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    activityChip(
                        title: NSLocalizedString("Normal", comment: "Activity level that uses the usual basal schedule"),
                        symbol: "🏠",
                        isSelected: viewModel.activeActivityID == nil
                    ) {
                        viewModel.onSelectActivity(nil)
                    }

                    ForEach(viewModel.activityLevels, id: \.id) { level in
                        activityChip(
                            title: level.name,
                            symbol: level.symbol,
                            isSelected: viewModel.activeActivityID == level.id
                        ) {
                            if viewModel.activeActivityID == level.id {
                                viewModel.onSelectActivity(nil)
                            } else {
                                viewModel.onSelectActivity(level)
                            }
                        }
                        .onLongPressGesture {
                            viewModel.onEditActivity(level)
                        }
                    }
                }
            }

            if let detail = viewModel.activeActivityDetail, viewModel.activeActivityID != nil {
                Text(detail)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                Text(NSLocalizedString("Hold an activity to edit it.", comment: "Hint explaining how to edit a home screen activity level"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func activityChip(title: String, symbol: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(symbol)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? insulinTintColor : Color(.secondarySystemBackground))
            .foregroundColor(isSelected ? Color.white : Color.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var basalSection: some View {
        Button(action: viewModel.onEditBasal) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(NSLocalizedString("Daily Basal", comment: "Home screen title for the basal schedule graph"))
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(viewModel.currentBasalText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.secondary)
                }

                BasalScheduleProfileChart(items: viewModel.basalItems)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SimpleActivityLevelEditor: View {
    @Environment(\.dismissAction) private var dismiss

    @State private var name: String
    @State private var symbol: String
    @State private var basalPercent: Double
    @State private var durationHours: Double

    private let existingID: UUID?
    private let onSave: (TemporaryScheduleOverridePreset) -> Void
    private let onDelete: (() -> Void)?

    private static let symbols = ["🏋️", "🚶", "😌", "😴", "💼", "🍽️", "🚗", "🎉"]

    init(
        preset: TemporaryScheduleOverridePreset?,
        onSave: @escaping (TemporaryScheduleOverridePreset) -> Void,
        onDelete: (() -> Void)?
    ) {
        existingID = preset?.id
        _name = State(initialValue: preset?.name ?? "")
        _symbol = State(initialValue: preset?.symbol ?? "😌")
        _basalPercent = State(initialValue: (preset?.settings.insulinNeedsScaleFactor ?? 1.0) * 100)
        switch preset?.duration {
        case .finite(let interval):
            _durationHours = State(initialValue: interval.hours)
        default:
            _durationHours = State(initialValue: 0)
        }
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        Form {
            Section(header: Text(NSLocalizedString("Name", comment: "Section title for activity level name"))) {
                TextField(NSLocalizedString("Chilling", comment: "Placeholder for a new activity level name"), text: $name)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(Self.symbols, id: \.self) { option in
                            Button(action: { symbol = option }) {
                                Text(option)
                                    .font(.title2)
                                    .padding(8)
                                    .background(symbol == option ? Color.accentColor.opacity(0.2) : Color.clear)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Section(
                header: Text(NSLocalizedString("Basal amount", comment: "Section title for activity basal percentage")),
                footer: Text(NSLocalizedString("100% keeps the usual daily basal. Lower this for exercise.", comment: "Explanation of activity basal percentage"))
            ) {
                Stepper(value: $basalPercent, in: 10...200, step: 10) {
                    Text(String(format: NSLocalizedString("%d%% of usual basal", comment: "Activity level basal percentage"), Int(basalPercent)))
                }
            }

            Section(header: Text(NSLocalizedString("How long", comment: "Section title for activity duration"))) {
                Picker(NSLocalizedString("Duration", comment: "Picker title for activity duration"), selection: $durationHours) {
                    Text(NSLocalizedString("Until I change it", comment: "Activity duration that stays on until cleared")).tag(0.0)
                    Text(NSLocalizedString("1 hour", comment: "One hour activity duration")).tag(1.0)
                    Text(NSLocalizedString("2 hours", comment: "Two hour activity duration")).tag(2.0)
                    Text(NSLocalizedString("4 hours", comment: "Four hour activity duration")).tag(4.0)
                    Text(NSLocalizedString("8 hours", comment: "Eight hour activity duration")).tag(8.0)
                }
            }

            if onDelete != nil {
                Section {
                    Button(role: .destructive, action: delete) {
                        Text(NSLocalizedString("Delete Activity", comment: "Button to delete an activity level"))
                    }
                }
            }
        }
        .navigationBarTitle(existingID == nil
                            ? NSLocalizedString("Add Activity", comment: "Title for adding an activity level")
                            : NSLocalizedString("Edit Activity", comment: "Title for editing an activity level"),
                            displayMode: .inline)
        .navigationBarItems(
            leading: Button(NSLocalizedString("Cancel", comment: "Cancel activity editor"), action: dismiss),
            trailing: Button(NSLocalizedString("Save", comment: "Save activity editor"), action: save)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        )
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let duration: TemporaryScheduleOverride.Duration = durationHours == 0 ? .indefinite : .finite(.hours(durationHours))
        let preset = TemporaryScheduleOverridePreset(
            id: existingID ?? UUID(),
            symbol: symbol,
            name: trimmed,
            settings: TemporaryScheduleOverrideSettings(unit: .milligramsPerDeciliter, targetRange: nil, insulinNeedsScaleFactor: basalPercent / 100),
            duration: duration
        )
        onSave(preset)
        dismiss()
    }

    private func delete() {
        onDelete?()
        dismiss()
    }
}
