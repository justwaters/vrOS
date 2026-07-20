import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var streamManager: StreamManager

    var body: some View {
        Form {
            Section("Head Tracking Deadband") {
                Picker("Mode", selection: $streamManager.deadbandMode) {
                    ForEach(DeadbandMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: streamManager.deadbandMode) { _ in
                    streamManager.sendDeadband()
                }
            }

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
        .frame(width: 300, height: 260)
    }
}
