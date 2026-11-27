//
//  PodDetailsView.swift
//  OmnipodKit
//
//  From OmniBLE/PumpManageUI/Views/PodDetailsView.swift
//  Created by Pete Schwamb on 4/14/20.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKitUI


struct PodDetails {
    var podType: PodType
    var address: UInt32
    var lotNumber: UInt32
    var sequenceNumber: UInt32
    var firmwareVersion: String
    var bleFirmwareVersion: String
    var deviceName: String?
    var totalDelivery: Double?
    var lastStatus: Date?
    var fault: DetailedStatus?
    var activatedAt: Date?
    var deliveryStoppedAt: Date?
    var podTime: TimeInterval
}

struct PodDetailsView: View {
    @Environment(\.guidanceColors) var guidanceColors
    // Not private: a private stored property would make the memberwise init private too
    @Environment(\.colorScheme) var colorScheme

    /// How much insulin the user puts in each pod (set once, used for every pod).
    @AppStorage("TrioPodFillUnits") var fillUnits: Double = 200
    @State var showFillEditor = false
    @State var fillInput = ""
    
    var podDetails: PodDetails
    var title: String
    
    let statusAgeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()

        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.maximumUnitCount = 1
        formatter.unitsStyle = .short

        return formatter
    }()

    let activeTimeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()

        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = .full

        return formatter
    }()

    let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .medium
        dateFormatter.doesRelativeDateFormatting = true
        return dateFormatter
    }()

    private func row(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }

    var totalDeliveryText: String {
        if let delivery = podDetails.totalDelivery {
            return String(format: LocalizedString("%@ U", comment: "Format string for total delivery on pod details screen"), delivery.twoDecimals)
        } else {
            return LocalizedString("NA", comment: "String shown on pod details for total delivery when not available.")
        }
    }

    /// Returns the string for the number of hours pod was active to two decimals. This value is always
    /// based on the pod's internal clock whether it is from a faulted, deactivated or currently active pod.
    var podHoursText: String {
        let podTime: TimeInterval

        if let faultTime = podDetails.fault?.faultEventTimeSinceActivation {
            /// Since the pod has a valid faultEventTimeSinceActivation, use this rather than the pod's time.
            /// Reset type pod faults return atypical fault time values that will not be considered valid on decode.
            podTime = faultTime
        } else {
            /// Otherwise use the always increasing podTime to compute the pod
            /// hours for reset pod faults, deactivated pods, or currently active pods.
            podTime = podDetails.podTime
        }
        return podTime.hours.twoDecimals
    }

    var lastStatusText: String {
        if let lastStatus = podDetails.lastStatus, let ageString = statusAgeFormatter.string(from: Date().timeIntervalSince(lastStatus)) {
            return String(format: LocalizedString("%@ ago", comment: "Format string for last status date on pod details screen"), ageString)
        } else {
            return LocalizedString("NA", comment: "String shown on pod details for last status date when not available.")
        }
    }

    var body: some View {
        if OmniElara.isActive {
            elaraBody
        } else {
            classicBody
        }
    }

    // MARK: - Elara

    private var podHours: Double {
        if let faultTime = podDetails.fault?.faultEventTimeSinceActivation { return faultTime.hours }
        return podDetails.podTime.hours
    }

    private var lotText: String {
        podDetails.podType.isEros
            ? String(format: "L%05u", podDetails.lotNumber)
            : lotDecode(lot: podDetails.lotNumber).readableText
    }

    private func units(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1))) + " " + LocalizedString("U", comment: "Insulin unit")
    }

    private func elaraRow(_ symbol: String, _ color: Color, _ label: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color.opacity(0.15)))
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .textSelection(.enabled)
        }
    }

    /// The least insulin a pod should be filled with.
    private static let minimumFill: Double = 100

    /// Enough for 80 hours (72 + the 8 hour extension) plus 20%, rounded up to 5 U. Nil without enough data.
    private func neededWithMargin(used: Double) -> Double? {
        guard podHours >= 12, used > 0 else { return nil }
        let needed = used / podHours * 80
        return (needed * 1.2 / 5).rounded(.up) * 5
    }

    /// Fill amount from the pod's use, never below the minimum fill. Nil without enough data.
    private func advisedFill(used: Double) -> Double? {
        neededWithMargin(used: used).map { max(Self.minimumFill, $0) }
    }

    @ViewBuilder private var insulinCard: some View {
        if let used = podDetails.totalDelivery {
            let left = max(0, fillUnits - used)
            let removed = podDetails.deliveryStoppedAt != nil
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    fillInput = String(Int(fillUnits))
                    showFillEditor = true
                } label: {
                    HStack {
                        Text(LocalizedString("Filled", comment: "Pod details: insulin put in the pod"))
                            .foregroundColor(.primary)
                        Spacer()
                        Text(units(fillUnits).replacingOccurrences(of: ",0 ", with: " ").replacingOccurrences(of: ".0 ", with: " "))
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor(.primary)
                        Image(systemName: "pencil")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color("LoopGreen"))
                    }
                }
                .buttonStyle(.plain)

                GeometryReader { geo in
                    let fraction = fillUnits > 0 ? min(1, used / fillUnits) : 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.orange.opacity(0.28))
                        Capsule().fill(Color("Insulin")).frame(width: geo.size.width * fraction)
                    }
                }
                .frame(height: 10)

                HStack {
                    (Text(units(used)).bold().foregroundColor(Color("Insulin"))
                        + Text(" " + LocalizedString("used", comment: "Pod details: insulin given from this pod")))
                    Spacer()
                    (Text(units(left)).bold().foregroundColor(.orange)
                        + Text(" " + (removed
                            ? LocalizedString("left when removed", comment: "Pod details: insulin still in the pod when it was removed")
                            : LocalizedString("still in the Pod", comment: "Pod details: insulin still in the active pod"))))
                }
                .font(.caption)
                .foregroundColor(.secondary)

                if let advised = advisedFill(used: used) {
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        if advised < fillUnits - 5, let withMargin = neededWithMargin(used: used), withMargin < Self.minimumFill {
                            (Text(String(format: LocalizedString("Fill next time %@ U, the minimum for a Pod.", comment: "Pod details advice when the use is below the minimum fill (1: units)"), String(Int(advised)))).bold()
                                + Text(" " + String(
                                    format: LocalizedString("You used %1$@ U in %2$@ hours. A full 80 hours (with the extension) needs about %3$@ U; with 20%% margin that is %4$@ U, but a Pod must be filled with at least %5$@ U. That is about %6$@ U less waste per Pod.", comment: "Pod details advice explanation below the minimum fill (1: used, 2: hours, 3: needed for 80 h, 4: with margin, 5: minimum fill, 6: saved)"),
                                    String(Int(used.rounded())),
                                    String(Int(podHours.rounded())),
                                    String(Int((used / podHours * 80).rounded())),
                                    String(Int(withMargin)),
                                    String(Int(Self.minimumFill)),
                                    String(Int((fillUnits - advised).rounded()))
                                )))
                        } else if advised < fillUnits - 5 {
                            (Text(String(format: LocalizedString("Fill next time about %@ U.", comment: "Pod details advice (1: units)"), String(Int(advised)))).bold()
                                + Text(" " + String(
                                    format: LocalizedString("You used %1$@ U in %2$@ hours. A full 80 hours (with the extension) needs about %3$@ U; with 20%% margin that is %4$@ U, about %5$@ U less waste per Pod.", comment: "Pod details advice explanation (1: used, 2: hours, 3: needed for 80 h, 4: advised, 5: saved)"),
                                    String(Int(used.rounded())),
                                    String(Int(podHours.rounded())),
                                    String(Int((used / podHours * 80).rounded())),
                                    String(Int(advised)),
                                    String(Int((fillUnits - advised).rounded()))
                                )))
                        } else {
                            Text(LocalizedString("Your fill matches your use.", comment: "Pod details: no change advised"))
                        }
                    }
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(9)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color("LoopGreen").opacity(0.12)))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color("LoopGreen").opacity(0.3)))
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var elaraBody: some View {
        List {
            Group {
                Group {
                    if podDetails.totalDelivery != nil {
                        Section(header: Text(LocalizedString("Insulin", comment: "Pod details section: insulin in the pod"))) {
                            insulinCard
                        }
                    }
                    Section(header: Text(LocalizedString("Usage", comment: "Pod details section: use of the pod"))) {
                        elaraRow("drop.fill", Color("Insulin"), LocalizedString("Total Delivery", comment: "description label for total delivery pod details row"), totalDeliveryText)
                        elaraRow("timer", .orange, LocalizedString("Pod Hours", comment: "description label for pod hours pod details row"), podHoursText)
                        if let activatedAt = podDetails.activatedAt {
                            elaraRow("play.fill", Color("LoopGreen"), LocalizedString("Activation", comment: "description label for activation pod details row"), dateFormatter.string(from: activatedAt))
                        }
                        if let deliveryStoppedAt = podDetails.deliveryStoppedAt {
                            elaraRow(
                                podDetails.fault != nil ? "exclamationmark.triangle.fill" : "stop.fill",
                                guidanceColors.critical,
                                podDetails.fault != nil
                                    ? LocalizedString("Faulted", comment: "description label for faulted pod details row")
                                    : LocalizedString("Deactivation", comment: "description label for deactivation pod details row"),
                                dateFormatter.string(from: deliveryStoppedAt)
                            )
                        } else {
                            elaraRow("clock", .gray, LocalizedString("Last Status", comment: "description label for last status date pod details row"), lastStatusText)
                        }
                    }
                    Section(header: Text(LocalizedString("Pod", comment: "Pod details section: the pod itself"))) {
                        elaraRow("square", .gray, LocalizedString("Pod Type", comment: "description label for pod type pod details row"), String(describing: podDetails.podType.description))
                        if let deviceName = podDetails.deviceName {
                            elaraRow("antenna.radiowaves.left.and.right", .gray, LocalizedString("Device Name", comment: "description label for device name pod details row"), deviceName)
                        }
                        elaraRow("number", Color("LoopGreen"), LocalizedString("Lot", comment: "description label for lot pod details row"), lotText)
                        if !podDetails.podType.isEros {
                            elaraRow("number", .gray, LocalizedString("Lot Number", comment: "description label for lot number pod details row"), String(describing: podDetails.lotNumber))
                        }
                        elaraRow("number", .gray, LocalizedString("Sequence Number", comment: "description label for sequence number pod details row"), String(format: "%07d", podDetails.sequenceNumber))
                        elaraRow("point.3.connected.trianglepath.dotted", .gray, LocalizedString("Address", comment: "description label for address pod details row"), String(format: "0x%08X", podDetails.address))
                    }
                    Section(header: Text(LocalizedString("Firmware", comment: "Pod details section: firmware versions"))) {
                        elaraRow("gearshape.fill", .gray, LocalizedString("Firmware Version", comment: "description label for firmware version pod details row"), podDetails.firmwareVersion)
                        elaraRow("dot.radiowaves.left.and.right", .blue, LocalizedString("BLE Firmware Version", comment: "description label for ble firmware version pod details row"), podDetails.bleFirmwareVersion)
                    }
                    faultSection
                }
                .listRowBackground(OmniElara.cardFill(colorScheme))
            }
            .elaraRows()
        }
        .elaraListBackground()
        .scrollContentBackground(.hidden)
        .background(OmniElara.background(colorScheme).ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.automatic)
        .alert(LocalizedString("Filled", comment: "Pod details: insulin put in the pod"), isPresented: $showFillEditor) {
            TextField("200", text: $fillInput)
                .keyboardType(.numberPad)
            Button(LocalizedString("Cancel", comment: "Cancel button title"), role: .cancel) {}
            Button(LocalizedString("Save", comment: "Save button title")) {
                if let value = Double(fillInput), value >= 85, value <= 200 {
                    fillUnits = value
                }
            }
        } message: {
            Text(LocalizedString("How many units do you put in each Pod (85 – 200)?", comment: "Pod details: fill amount prompt"))
        }
    }

    @ViewBuilder private var faultSection: some View {
        if let fault = podDetails.fault, let pdmRef = fault.pdmRef {
            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(guidanceColors.critical)
                        Text(LocalizedString("Pod Fault Details", comment: "description label for pod fault details"))
                            .fontWeight(.semibold)
                    }.padding(.vertical, 4)
                    let faultCode = fault.faultEventCode
                    Text(String(format: LocalizedString("Internal Pod fault code %1$@\n%2$@\nRef: %3$@\n",
                            comment: "The format string for the pod fault info: (1: fault code) (2: fault description) (3: pdm ref string)"),
                            String(format: "%03u", faultCode.rawValue), faultCode.faultDescription, pdmRef))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var classicBody: some View {
        List {
            Group {
                row(LocalizedString("Pod Type", comment: "description label for pod type pod details row"), value: String(describing: podDetails.podType.description))
                if let deviceName = podDetails.deviceName {
                    row(LocalizedString("Device Name", comment: "description label for device name pod details row"), value: deviceName)
                }
                row(LocalizedString("Address", comment: "description label for address pod details row"), value: String(format: "0x%08X", podDetails.address))
                if podDetails.podType.isEros {
                    row(LocalizedString("Lot", comment: "description label for lot pod details row"),
                        value: String(format: "L%05u", podDetails.lotNumber))
                } else {
                    row(LocalizedString("Lot", comment: "description label for lot pod details row"),
                        value: lotDecode(lot: podDetails.lotNumber).readableText)
                    row(LocalizedString("Lot Number", comment: "description label for lot number pod details row"),
                        value: String(describing: podDetails.lotNumber))
                }
                row(LocalizedString("Sequence Number", comment: "description label for sequence number pod details row"), value: String(format: "%07d", podDetails.sequenceNumber))
                row(LocalizedString("Firmware Version", comment: "description label for firmware version pod details row"), value: podDetails.firmwareVersion)
                row(LocalizedString("BLE Firmware Version", comment: "description label for ble firmware version pod details row"), value: podDetails.bleFirmwareVersion)
                row(LocalizedString("Total Delivery", comment: "description label for total delivery pod details row"), value: totalDeliveryText)
                row(LocalizedString("Pod Hours", comment: "description label for pod hours pod details row"), value: podHoursText)
                if let activatedAt = podDetails.activatedAt {
                    row(LocalizedString("Activation", comment: "description label for activation pod details row"), value: dateFormatter.string(from: activatedAt))
                }
                if let deliveryStoppedAt = podDetails.deliveryStoppedAt {
                    if podDetails.fault != nil {
                        row(LocalizedString("Faulted", comment: "description label for faulted pod details row"), value: dateFormatter.string(from: deliveryStoppedAt))
                    } else {
                        row(LocalizedString("Deactivation", comment: "description label for deactivation pod details row"), value: dateFormatter.string(from: deliveryStoppedAt))
                    }
                } else {
                    row(LocalizedString("Last Status", comment: "description label for last status date pod details row"), value: lastStatusText)
                }
                if let fault = podDetails.fault, let pdmRef = fault.pdmRef {
                    Section {
                        VStack(alignment: .leading) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(guidanceColors.critical)
                                Text(LocalizedString("Pod Fault Details", comment: "description label for pod fault details"))
                                    .fontWeight(.semibold)
                            }.padding(.vertical, 4)
                            let faultCode = fault.faultEventCode
                            Text(String(format: LocalizedString("Internal Pod fault code %1$@\n%2$@\nRef: %3$@\n",
                                    comment: "The format string for the pod fault info: (1: fault code) (2: fault description) (3: pdm ref string)"),
                                    String(format: "%03u", faultCode.rawValue), faultCode.faultDescription, pdmRef))
                                .fixedSize(horizontal: false, vertical: true)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .elaraRows()
        }
        .elaraListBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.automatic)
    }
}

struct PodDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        PodDetailsView(podDetails: PodDetails(podType: dashType, address: 0x17012345, lotNumber: 123456789, sequenceNumber: 1234567, firmwareVersion: "4.3.2", bleFirmwareVersion: "1.2.3", deviceName: "DashPreviewPod", totalDelivery: 99, lastStatus: Date(), fault: nil, activatedAt: Date().addingTimeInterval(.days(2)), deliveryStoppedAt: nil, podTime: .days(2)), title: "Pod Details")
    }
}
