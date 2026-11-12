//
//  ExpirationReminderPickerView.swift
//  OmnipodKit
//
//  From OmniBLE/PumpManageUI/Views/ExpirationReminderPickerView.swift
//  Created by Pete Schwamb on 5/17/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI


struct ExpirationReminderPickerView: View {
    
    static let expirationReminderHoursAllowed = 0...24
    
    var expirationReminderDefault: Binding<Int>
    
    var collapsible: Bool = true
    
    @State var showingHourPicker: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    
    var expirationDefaultFormatter = QuantityFormatter(for: .hour)
    
    var expirationDefaultString: String {
        return expirationReminderHourString(expirationReminderDefault.wrappedValue)
    }
    
    var body: some View {
        VStack {
            if OmniElara.isActive && !collapsible {
                OmniElara.tile(LocalizedString("Expiration Reminder Default", comment: "Label text for expiration reminder default row"), scheme: colorScheme) {
                    Text(expirationDefaultString)
                        .font(.system(size: 18, weight: .heavy))
                }
            } else {
            HStack {
                Text(LocalizedString("Expiration Reminder Default", comment: "Label text for expiration reminder default row"))
                Spacer()
                if collapsible {
                    Button(expirationDefaultString) {
                        withAnimation {
                            showingHourPicker.toggle()
                        }
                    }
                } else {
                    Text(expirationDefaultString)
                }
            }
            }
            if showingHourPicker {
                Picker(selection: expirationReminderDefault) {
                    ForEach(Array(Self.expirationReminderHoursAllowed), id: \.self) { value in
                        Text(expirationReminderHourString(value))
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.wheel)
            }
        }
    }
    
    private func expirationReminderHourString(_ value: Int) -> String {
        if value > 0 {
            // "7 u" instead of the shared formatter's untranslated "7 hr"
            return "\(value) " + LocalizedString("h", comment: "Short unit for hours in pod life remaining")
        } else {
            return LocalizedString("No Reminder", comment: "Value text for no expiration reminder")
        }
    }
}

struct ExpirationReminderPickerView_Previews: PreviewProvider {
    static var previews: some View {
        ExpirationReminderPickerView(expirationReminderDefault: .constant(2))
    }
}
