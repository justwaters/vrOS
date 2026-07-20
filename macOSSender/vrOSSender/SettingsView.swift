import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var streamManager: StreamManager

    var body: some View {
        Form {
            Section("Barrel Distortion") {
                HStack {
                    Text("k1:")
                    TextField("k1", value: $streamManager.distortionK1, format: .number.precision(.fractionLength(3)))
                        .frame(width: 100)
                        .onChange(of: streamManager.distortionK1) { _ in
                            streamManager.sendDistortion()
                        }
                }
                HStack {
                    Text("k2:")
                    TextField("k2", value: $streamManager.distortionK2, format: .number.precision(.fractionLength(3)))
                        .frame(width: 100)
                        .onChange(of: streamManager.distortionK2) { _ in
                            streamManager.sendDistortion()
                        }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 300, height: 180)
    }
}
