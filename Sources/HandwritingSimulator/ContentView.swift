import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = HandwritingViewModel()
    @State private var leftWidth: CGFloat = 250

    var body: some View {
        HStack(spacing: 0) {
            // Left panel – controls
            VStack(alignment: .leading, spacing: 12) {
                Text("✍️ Handwriting Simulator")
                    .font(.title2.bold())
                Divider()

                Text("Homework Text")
                    .font(.headline)
                TextEditor(text: $viewModel.inputText)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(minHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary))

                Picker("Paper", selection: $viewModel.selectedPaper) {
                    Text("Lined").tag(PaperType.lined)
                    Text("Graph").tag(PaperType.graph)
                    Text("Blank").tag(PaperType.blank)
                }
                .pickerStyle(.segmented)

                ColorPicker("Ink Color", selection: $viewModel.inkColor)

                HStack {
                    Text("Speed")
                    Slider(value: $viewModel.writingSpeed, in: 0.3...3.0)
                    Text(String(format: "%.1fx", viewModel.writingSpeed))
                        .frame(width: 40)
                }

                Button("🖊 Animate Writing") {
                    viewModel.startAnimation()
                }
                .disabled(viewModel.isAnimating)
                .buttonStyle(.bordered)

                Button("🎥 Export Movie") {
                    viewModel.exportMovie()
                }
                .buttonStyle(.bordered)

                Spacer()

                Text("Class 11 Mago’s Templates")
                    .font(.caption.bold())
                ScrollView(.vertical) {
                    ForEach(SampleTexts.all, id: \.title) { sample in
                        Button(sample.title) {
                            viewModel.inputText = sample.text
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                }
                .frame(maxHeight: 100)
            }
            .padding()
            .frame(width: leftWidth)

            // Divider that can be dragged
            Color.gray.opacity(0.3)
                .frame(width: 6)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newWidth = leftWidth + value.translation.width
                            leftWidth = min(max(180, newWidth), 500)
                        }
                )

            // Right panel – canvas
            HandwritingCanvas(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(white: 0.95))
        }
    }
}

struct HandwritingCanvas: View {
    @ObservedObject var viewModel: HandwritingViewModel

    var body: some View {
        GeometryReader { geometry in
            if let image = viewModel.renderedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ZStack {
                    if let bg = PaperBackgrounds.image(for: viewModel.selectedPaper, size: geometry.size) {
                        Image(nsImage: bg)
                            .resizable()
                    }
                    Text("Type text on the left and press **Animate**")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}