//
//  PodDiagnosticsView.swift
//  OmnipodKit
//
//  From OmniBLE/PumpManageUI/Views/PodDiagnosticsView.swift
//  Created by Joseph Moran on 11/25/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI
import HealthKit


protocol DiagnosticCommands {
    func playTestBeeps() async throws
    func readPulseLog() async throws -> String
    func readPulseLogPlus() async throws -> String
    func readActivationTime() async throws -> String
    func readTriggeredAlerts() async throws -> String
    func getDetailedStatus() async throws -> DetailedStatus
    func pumpManagerDetails() -> String
}

struct PodDiagnosticsView: View  {

    var title: String

    var diagnosticCommands: DiagnosticCommands
    var podOk: Bool
    var noPod: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        List {
            Group {
            NavigationLink(destination: ReadPodStatusView(getDetailedStatus: diagnosticCommands.getDetailedStatus)) {
                OmniElara.actionLabel(
                    FrameworkLocalText("Read Pod Status", comment: "Text for read pod status navigation link")
                        .foregroundColor(Color.primary),
                    systemImage: "info.circle",
                    color: .blue
                )
            }
            .disabled(noPod)

            NavigationLink(destination: PlayTestBeepsView(playTestBeeps: {
                try await diagnosticCommands.playTestBeeps()
            })) {
                OmniElara.actionLabel(
                    FrameworkLocalText("Play Test Beeps", comment: "Text for play test beeps navigation link")
                        .foregroundColor(Color.primary),
                    systemImage: "speaker.wave.2",
                    color: Color("LoopGreen")
                )
            }
            .disabled(!podOk)

            NavigationLink(destination: ReadPodInfoView(
                title: LocalizedString("Read Pulse Log", comment: "Text for read pulse log title"),
                actionString: LocalizedString("Reading Pulse Log...", comment: "Text for read pulse log action"),
                failedString: LocalizedString("Failed to read pulse log", comment: "Alert title for error when reading pulse log"),
                action: { try await diagnosticCommands.readPulseLog() }))
            {
                OmniElara.actionLabel(
                    FrameworkLocalText("Read Pulse Log", comment: "Text for read pulse log navigation link")
                        .foregroundColor(Color.primary),
                    systemImage: "list.bullet.rectangle",
                    color: .gray
                )
            }
            .disabled(noPod)

            NavigationLink(destination: ReadPodInfoView(
                title: LocalizedString("Read Pulse Log Plus", comment: "Text for read pulse log plus title"),
                actionString: LocalizedString("Reading Pulse Log Plus...", comment: "Text for read pulse log plus action"),
                failedString: LocalizedString("Failed to read pulse log plus", comment: "Alert title for error when reading pulse log plus"),
                action: { try await diagnosticCommands.readPulseLogPlus() }))
            {
                OmniElara.actionLabel(
                    FrameworkLocalText("Read Pulse Log Plus", comment: "Text for read pulse log plus navigation link")
                        .foregroundColor(Color.primary),
                    systemImage: "list.bullet.rectangle.portrait",
                    color: .gray
                )
            }
            .disabled(noPod)

            NavigationLink(destination: ReadPodInfoView(
                title: LocalizedString("Read Activation Time", comment: "Text for read activation time title"),
                actionString: LocalizedString("Reading Activation Time...", comment: "Text for read activation time action"),
                failedString: LocalizedString("Failed to read activation time", comment: "Alert title for error when reading activation time"),
                action: { try await diagnosticCommands.readActivationTime() }))
            {
                OmniElara.actionLabel(
                    FrameworkLocalText("Read Activation Time", comment: "Text for read activation time navigation link")
                        .foregroundColor(Color.primary),
                    systemImage: "timer",
                    color: .orange
                )
            }
            .disabled(noPod)

            NavigationLink(destination: ReadPodInfoView(
                title: LocalizedString("Read Triggered Alerts", comment: "Text for read triggered alerts title"),
                actionString: LocalizedString("Reading Triggered Alerts...", comment: "Text for read triggered alerts action"),
                failedString: LocalizedString("Failed to read triggered alerts", comment: "Alert title for error when reading triggered alerts"),
                action: { try await diagnosticCommands.readTriggeredAlerts() }))
            {
                OmniElara.actionLabel(
                    FrameworkLocalText("Read Triggered Alerts", comment: "Text for read triggered alerts navigation link")
                        .foregroundColor(Color.primary),
                    systemImage: "exclamationmark.triangle",
                    color: .red
                )
            }
            .disabled(noPod)

            NavigationLink(destination: PumpManagerDetailsView() { diagnosticCommands.pumpManagerDetails() })
            {
                OmniElara.actionLabel(
                    FrameworkLocalText("Pump Manager Details", comment: "Text for pump manager details navigation link")
                        .foregroundColor(Color.primary),
                    systemImage: "gearshape",
                    color: .gray
                )
            }

            }
            .listRowBackground(OmniElara.isActive ? OmniElara.cardFill(colorScheme) : nil)
        }
        .insetGroupedListStyle()
        .scrollContentBackground(OmniElara.isActive ? .hidden : .automatic)
        .background(OmniElara.isActive ? AnyView(OmniElara.background(colorScheme).ignoresSafeArea()) : AnyView(EmptyView()))
        .navigationTitle(title)
    }
}
