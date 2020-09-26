import AudioKit
import AVFoundation
import SwiftUI

struct TanhDistortionData {
    var pregain: AUValue = 2.0
    var postgain: AUValue = 0.5
    var positiveShapeParameter: AUValue = 0.0
    var negativeShapeParameter: AUValue = 0.0
    var rampDuration: AUValue = 0.02
    var balance: AUValue = 0.5
}

class TanhDistortionConductor: ObservableObject, ProcessesPlayerInput {

    let engine = AudioEngine()
    let player = AudioPlayer()
    let distortion: TanhDistortion
    let dryWetMixer: DryWetMixer
    let playerPlot: NodeOutputPlot
    let distortionPlot: NodeOutputPlot
    let mixPlot: NodeOutputPlot
    let buffer: AVAudioPCMBuffer

    init() {
        let url = Bundle.main.resourceURL?.appendingPathComponent("Samples/beat.aiff")
        let file = try! AVAudioFile(forReading: url!)
        buffer = try! AVAudioPCMBuffer(file: file)!

        distortion = TanhDistortion(player)
        dryWetMixer = DryWetMixer(player, distortion)
        playerPlot = NodeOutputPlot(player)
        distortionPlot = NodeOutputPlot(distortion)
        mixPlot = NodeOutputPlot(dryWetMixer)
        engine.output = dryWetMixer

        playerPlot.plotType = .rolling
        playerPlot.shouldFill = true
        playerPlot.shouldMirror = true
        playerPlot.setRollingHistoryLength(128)
        distortionPlot.plotType = .rolling
        distortionPlot.color = .blue
        distortionPlot.shouldFill = true
        distortionPlot.shouldMirror = true
        distortionPlot.setRollingHistoryLength(128)
        mixPlot.color = .purple
        mixPlot.shouldFill = true
        mixPlot.shouldMirror = true
        mixPlot.plotType = .rolling
        mixPlot.setRollingHistoryLength(128)
    }

    @Published var data = TanhDistortionData() {
        didSet {
            distortion.$pregain.ramp(to: data.pregain, duration: data.rampDuration)
            distortion.$postgain.ramp(to: data.postgain, duration: data.rampDuration)
            distortion.$positiveShapeParameter.ramp(to: data.positiveShapeParameter, duration: data.rampDuration)
            distortion.$negativeShapeParameter.ramp(to: data.negativeShapeParameter, duration: data.rampDuration)
            dryWetMixer.balance = data.balance
        }
    }

    func start() {
        playerPlot.start()
        distortionPlot.start()
        mixPlot.start()

        do {
            try engine.start()
            // player stuff has to be done after start
            player.scheduleBuffer(buffer, at: nil, options: .loops)
        } catch let err {
            Log(err)
        }
    }

    func stop() {
        engine.stop()
    }
}

struct TanhDistortionView: View {
    @ObservedObject var conductor = TanhDistortionConductor()

    var body: some View {
        ScrollView {
            PlayerControls(conductor: conductor)
            ParameterSlider(text: "Pregain",
                            parameter: self.$conductor.data.pregain,
                            range: 0.0...10.0,
                            units: "Generic")
            ParameterSlider(text: "Postgain",
                            parameter: self.$conductor.data.postgain,
                            range: 0.0...10.0,
                            units: "Generic")
            ParameterSlider(text: "Positive Shape Parameter",
                            parameter: self.$conductor.data.positiveShapeParameter,
                            range: -10.0...10.0,
                            units: "Generic")
            ParameterSlider(text: "Negative Shape Parameter",
                            parameter: self.$conductor.data.negativeShapeParameter,
                            range: -10.0...10.0,
                            units: "Generic")
            ParameterSlider(text: "Balance",
                            parameter: self.$conductor.data.balance,
                            range: 0...1,
                            units: "%")
            DryWetMixPlotsView(dry: conductor.playerPlot, wet: conductor.distortionPlot, mix: conductor.mixPlot)
        }
        .padding()
        .navigationBarTitle(Text("Tanh Distortion"))
        .onAppear {
            self.conductor.start()
        }
        .onDisappear {
            self.conductor.stop()
        }
    }
}

struct TanhDistortion_Previews: PreviewProvider {
    static var previews: some View {
        TanhDistortionView()
    }
}