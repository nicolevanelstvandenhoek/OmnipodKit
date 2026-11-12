//
//  ManualTempBasalEntryView.swift
//  OmnipodKit
//
//  From OmniBLE/PumpManageUI/Views/ManualTempBasalEntryView.swift
//  Created by Pete Schwamb on 5/14/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKitUI
import LoopKit


struct ManualTempBasalEntryView: View {

    @Environment(\.guidanceColors) var guidanceColors
    @Environment(\.colorScheme) private var colorScheme

    var enactBasal: ((Double,TimeInterval,@escaping (PumpManagerError?)->Void) -> Void)?
    var didCancel: (() -> Void)?

    @State private var rateEntered: Double = 0.0
    @State private var durationEntered: TimeInterval = .hours(0.5)
    @State private var showPicker: Bool = false
    @State private var error: PumpManagerError?
    @State private var enacting: Bool = false
    @State private var showingErrorAlert: Bool = false
    @State private var showingMissingConfigAlert: Bool = false

    var allowedRates: [Double]

    init(enactBasal: ((Double,TimeInterval,@escaping (PumpManagerError?)->Void) -> Void)? = nil, didCancel: (() -> Void)? = nil, allowedRates: [Double]) {
        self.enactBasal = enactBasal
        self.didCancel = didCancel
        self.allowedRates = allowedRates
        // This is to handle the temporary situation of devs/testers migrating from OmniBLEPumpManagerState with no
        // max temp basal set
        if allowedRates.count == 1 && allowedRates[0] == 0.0 {
            _showingMissingConfigAlert = State(initialValue: true)
        }
    }

    private static let rateFormatter: QuantityFormatter = {
        let quantityFormatter = QuantityFormatter(for: .internationalUnitsPerHour)
        quantityFormatter.numberFormatter.minimumFractionDigits = 2
        return quantityFormatter
    }()

    private var rateUnitsLabel: some View {
        Text(QuantityFormatter(for: .internationalUnitsPerHour).localizedUnitStringWithPlurality())
            .foregroundColor(Color(.secondaryLabel))
    }

    private static let durationFormatter: QuantityFormatter = {
        let quantityFormatter = QuantityFormatter(for: .hour)
        quantityFormatter.numberFormatter.minimumFractionDigits = 1
        quantityFormatter.numberFormatter.maximumFractionDigits = 1
        quantityFormatter.unitStyle = .long
        return quantityFormatter
    }()

    private var durationUnitsLabel: some View {
        Text(QuantityFormatter(for: .hour).localizedUnitStringWithPlurality())
            .foregroundColor(Color(.secondaryLabel))
    }

    func formatRate(_ rate: Double) -> String {
        return ManualTempBasalEntryView.rateFormatter.string(from: LoopQuantity(unit: .internationalUnitsPerHour, doubleValue: rate)) ?? ""
    }

    func formatDuration(_ duration: TimeInterval) -> String {
        // Own unit word: the shared formatter capitalizes it in some languages ("0,5 Uur")
        let number = ManualTempBasalEntryView.durationFormatter.numberFormatter.string(from: NSNumber(value: duration.hours)) ?? ""
        let unit = duration.hours == 1
            ? LocalizedString("hour", comment: "Unit for singular hour in pod life remaining")
            : LocalizedString("hours", comment: "Unit for plural hours in pod life remaining")
        return number + " " + unit
    }

    var body: some View {
        NavigationView {
            VStack {
                List {
                    Group {
                    if OmniElara.isActive {
                        // The chosen rate and duration as tiles above the wheels
                        HStack(spacing: 8) {
                            OmniElara.tile(LocalizedString("Rate", comment: "Label text for basal rate summary"), scheme: colorScheme) {
                                Text(formatRate(rateEntered))
                                    .font(.system(size: 18, weight: .heavy))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            OmniElara.tile(LocalizedString("Duration", comment: "Elara temp basal tile: duration"), scheme: colorScheme) {
                                Text(formatDuration(durationEntered))
                                    .font(.system(size: 18, weight: .heavy))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                    } else {
                    HStack {
                        Text(LocalizedString("Rate", comment: "Label text for basal rate summary"))
                        Spacer()
                        Text(String(format: LocalizedString("%1$@ for %2$@", comment: "Summary string for temporary basal rate configuration page"), formatRate(rateEntered), formatDuration(durationEntered)))
                    }
                    }
                    }
                    .listRowBackground(OmniElara.isActive ? OmniElara.cardFill(colorScheme) : nil)
                    HStack {
                        Picker(selection: $rateEntered) {
                            ForEach(allowedRates, id: \.self) { value in
                                Text(formatRate(value))
                            }
                        } label: {
                            EmptyView()
                        }
                        .pickerStyle(.wheel)

                        Picker(selection: $durationEntered) {
                            ForEach(Pod.supportedTempBasalDurations, id: \.self) { value in
                                Text(formatDuration(value))
                            }
                        } label: {
                            EmptyView()
                        }
                        .pickerStyle(.wheel)
                    }
                    .frame(maxHeight: 162.0)
                    .alert(isPresented: $showingMissingConfigAlert, content: { missingConfigAlert })
                    .listRowBackground(OmniElara.isActive ? OmniElara.cardFill(colorScheme) : nil)
                    Section {
                        HStack(alignment: .top, spacing: 8) {
                            if OmniElara.isActive {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.footnote)
                                    .foregroundColor(guidanceColors.warning)
                            }
                            Text(LocalizedString("Your insulin delivery will not be automatically adjusted until the temporary basal rate finishes or is canceled.", comment: "Description text on manual temp basal action sheet"))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .listRowBackground(OmniElara.isActive ? guidanceColors.warning.opacity(0.14) : nil)
                    }
                }
                .scrollContentBackground(OmniElara.isActive ? .hidden : .automatic)
                Button(action: {
                    enacting = true
                    enactBasal?(rateEntered, durationEntered) { (error) in
                        if let error = error {
                            self.error = error
                            showingErrorAlert = true
                        }
                        enacting = false
                    }
                }) {
                    HStack {
                        if enacting {
                            ProgressView()
                        } else {
                            Text(LocalizedString("Set Temporary Basal", comment: "Button text for setting manual temporary basal rate"))
                        }
                    }
                }
                .buttonStyle(ActionButtonStyle(.primary))
                .padding()
            }
            .background(OmniElara.isActive ? AnyView(OmniElara.background(colorScheme).ignoresSafeArea()) : AnyView(EmptyView()))
            .navigationTitle(LocalizedString("Temporary Basal", comment: "Navigation Title for ManualTempBasalEntryView"))
            .navigationBarItems(trailing: cancelButton)
            .alert(isPresented: $showingErrorAlert, content: { errorAlert })
            .disabled(enacting)
        }
    }

    var errorAlert: SwiftUI.Alert {
        let errorMessage = errorMessage(error: error!)
        return SwiftUI.Alert(
            title: Text(LocalizedString("Temporary Basal Failed", comment: "Alert title for a failure to set temporary basal")),
            message: errorMessage)
    }

    func errorMessage(error: PumpManagerError) -> Text {
        if let recovery = error.recoverySuggestion {
            return Text(String(format: LocalizedString("Unable to set a temporary basal rate: %1$@\n\n%2$@", comment: "Alert format string for a failure to set temporary basal with recovery suggestion. (1: error description) (2: recovery text)"), error.localizedDescription, recovery))
        } else {
            return Text(String(format: LocalizedString("Unable to set a temporary basal rate: %1$@", comment: "Alert format string for a failure to set temporary basal. (1: error description)"), error.localizedDescription))
        }
    }

    var missingConfigAlert: SwiftUI.Alert {
        return SwiftUI.Alert(
            title: Text(LocalizedString("Missing Config", comment: "Alert title for missing temp basal configuration")),
            message: Text(LocalizedString("This PumpManager has not been configured with a maximum basal rate because it was added before manual temp basal was a feature. Please set a new maximum basal rate.", comment: "Alert format string for missing temp basal configuration."))
        )
    }

    var cancelButton: some View {
        Button(LocalizedString("Cancel", comment: "Cancel button text in navigation bar on insert cannula screen")) {
            didCancel?()
        }
        .accessibility(identifier: "button_cancel")
    }
}


