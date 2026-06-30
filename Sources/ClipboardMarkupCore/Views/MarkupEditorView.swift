import AppKit
import SwiftUI

struct MarkupEditorView: View {
    let originalImage: NSImage
    let initialElements: [MarkupElement]
    let onCancel: () -> Void
    let onSave: ([MarkupElement]) -> Void

    @State private var elements: [MarkupElement]
    @State private var selectedElementID: MarkupElement.ID?
    @State private var tool = MarkupTool.arrow
    @State private var colorHex = "#FF3B30"
    @State private var lineWidth = 8.0
    @State private var fontName = "Helvetica Neue"
    @State private var fontSize = 42.0
    @State private var textValue = "Text"

    init(
        originalImage: NSImage,
        initialElements: [MarkupElement],
        onCancel: @escaping () -> Void,
        onSave: @escaping ([MarkupElement]) -> Void
    ) {
        self.originalImage = originalImage
        self.initialElements = initialElements
        self.onCancel = onCancel
        self.onSave = onSave
        _elements = State(initialValue: initialElements)
    }

    var body: some View {
        VStack(spacing: 0) {
            MarkupToolbar(
                tool: $tool,
                colorHex: $colorHex,
                lineWidth: $lineWidth,
                fontName: $fontName,
                fontSize: $fontSize,
                textValue: $textValue
            )
            .padding(12)

            Divider()

            MarkupCanvas(
                originalImage: originalImage,
                elements: $elements,
                selectedElementID: $selectedElementID,
                tool: tool,
                colorHex: colorHex,
                lineWidth: lineWidth,
                fontName: fontName,
                fontSize: fontSize,
                textValue: textValue
            )
            .padding(12)

            Divider()

            HStack {
                Button {
                    deleteSelectedElement()
                } label: {
                    Label("Delete", systemImage: "trash")
                        .appFont(size: 13)
                }
                .disabled(selectedElementID == nil)

                Spacer()

                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .appFont(size: 13)
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    onSave(elements)
                } label: {
                    Label("Save", systemImage: "checkmark")
                        .appFont(size: 13)
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .onChange(of: selectedElementID) { _, newValue in
            syncControlsFromSelection(newValue)
        }
        .onChange(of: colorHex) { _, _ in
            applyControlsToSelection()
        }
        .onChange(of: lineWidth) { _, _ in
            applyControlsToSelection()
        }
        .onChange(of: fontName) { _, _ in
            applyControlsToSelection()
        }
        .onChange(of: fontSize) { _, _ in
            applyControlsToSelection()
        }
        .onChange(of: textValue) { _, _ in
            applyControlsToSelection()
        }
    }

    private func syncControlsFromSelection(_ id: MarkupElement.ID?) {
        guard let id,
              let element = elements.first(where: { $0.id == id })
        else {
            return
        }

        colorHex = element.colorHex
        lineWidth = element.lineWidth
        fontName = element.fontName
        fontSize = element.fontSize
        if element.kind == .text {
            textValue = element.text
        }
    }

    private func applyControlsToSelection() {
        guard let selectedElementID,
              let index = elements.firstIndex(where: { $0.id == selectedElementID })
        else {
            return
        }

        elements[index].colorHex = colorHex
        elements[index].lineWidth = lineWidth
        elements[index].fontName = fontName
        elements[index].fontSize = fontSize
        if elements[index].kind == .text {
            elements[index].text = textValue
        }
    }

    private func deleteSelectedElement() {
        guard let selectedElementID else {
            return
        }
        elements.removeAll { $0.id == selectedElementID }
        self.selectedElementID = nil
    }
}

private struct MarkupToolbar: View {
    @Environment(\.appFontScale) private var appFontScale

    @Binding var tool: MarkupTool
    @Binding var colorHex: String
    @Binding var lineWidth: Double
    @Binding var fontName: String
    @Binding var fontSize: Double
    @Binding var textValue: String

    private let palette = [
        "#FF3B30",
        "#FF9500",
        "#FFCC00",
        "#34C759",
        "#007AFF",
        "#AF52DE",
        "#FFFFFF",
        "#111111"
    ]

    private let fontOptions = [
        "Helvetica Neue",
        "Avenir Next",
        "Menlo",
        "Georgia",
        "Impact"
    ]

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(MarkupTool.allCases) { candidate in
                    Button {
                        tool = candidate
                    } label: {
                        Image(systemName: candidate.systemImage)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.bordered)
                    .tint(tool == candidate ? .accentColor : nil)
                    .help(candidate.title)
                }
            }

            Divider()
                .frame(height: 24)

            HStack(spacing: 6) {
                ForEach(palette, id: \.self) { swatch in
                    Button {
                        colorHex = swatch
                    } label: {
                        Circle()
                            .fill(Color(hex: swatch))
                            .overlay {
                                Circle()
                                    .stroke(Color.primary.opacity(colorHex == swatch ? 0.9 : 0.25), lineWidth: colorHex == swatch ? 3 : 1)
                            }
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .help(swatch)
                }
            }

            Divider()
                .frame(height: 24)

            Image(systemName: "line.diagonal")
                .foregroundStyle(.secondary)
                .appFont(size: 13)
            Slider(value: $lineWidth, in: 2...28, step: 1)
                .frame(width: 110)
                .help("Line width")

            Divider()
                .frame(height: 24)

            TextField("Text", text: $textValue)
                .font(.system(size: max(8, 13 * appFontScale)))
                .textFieldStyle(.roundedBorder)
                .frame(width: 160)

            Picker("Font", selection: $fontName) {
                ForEach(fontOptions, id: \.self) { font in
                    Text(font)
                        .font(.custom(font, size: max(8, 12 * appFontScale)))
                        .tag(font)
                }
            }
            .labelsHidden()
            .frame(width: 150)

            Image(systemName: "textformat.size")
                .foregroundStyle(.secondary)
                .appFont(size: 13)
            Slider(value: $fontSize, in: 18...96, step: 1)
                .frame(width: 120)
                .help("Text size")

            Spacer()
        }
    }
}

private struct MarkupCanvas: View {
    let originalImage: NSImage
    @Binding var elements: [MarkupElement]
    @Binding var selectedElementID: MarkupElement.ID?
    let tool: MarkupTool
    let colorHex: String
    let lineWidth: Double
    let fontName: String
    let fontSize: Double
    let textValue: String

    @State private var draftElement: MarkupElement?

    var body: some View {
        GeometryReader { geometry in
            let imageRect = aspectFitRect(imageSize: originalImage.size, containerSize: geometry.size)

            ZStack(alignment: .topLeading) {
                Image(nsImage: originalImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)

                ZStack(alignment: .topLeading) {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(creationGesture(canvasSize: imageRect.size))

                    ForEach($elements) { $element in
                        MarkupElementOverlay(
                            element: $element,
                            selectedElementID: $selectedElementID,
                            canvasSize: imageRect.size
                        )
                    }

                    if let draftElement {
                        MarkupElementDrawing(element: draftElement, canvasSize: imageRect.size, isSelected: false)
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: imageRect.width, height: imageRect.height)
                .offset(x: imageRect.minX, y: imageRect.minY)
            }
        }
        .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }

    private func creationGesture(canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard tool == .arrow || tool == .rectangle else {
                    return
                }

                let start = normalizedPoint(from: value.startLocation, canvasSize: canvasSize)
                let current = normalizedPoint(from: value.location, canvasSize: canvasSize)
                let kind: MarkupElement.Kind = tool == .arrow ? .arrow : .rectangle

                if draftElement == nil {
                    draftElement = MarkupElement(
                        kind: kind,
                        start: start,
                        end: current,
                        colorHex: colorHex,
                        lineWidth: lineWidth,
                        fontName: fontName,
                        fontSize: fontSize
                    )
                } else {
                    draftElement?.end = current
                }
            }
            .onEnded { value in
                switch tool {
                case .select:
                    selectedElementID = nil
                case .text:
                    let location = normalizedPoint(from: value.location, canvasSize: canvasSize)
                    let text = textValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    let element = MarkupElement(
                        kind: .text,
                        start: location,
                        end: location,
                        text: text.isEmpty ? "Text" : text,
                        colorHex: colorHex,
                        lineWidth: lineWidth,
                        fontName: fontName,
                        fontSize: fontSize
                    )
                    elements.append(element)
                    selectedElementID = element.id
                case .arrow, .rectangle:
                    guard let draftElement,
                          distance(from: draftElement.start, to: draftElement.end, in: canvasSize) > 8
                    else {
                        self.draftElement = nil
                        return
                    }
                    elements.append(draftElement)
                    selectedElementID = draftElement.id
                    self.draftElement = nil
                }
            }
    }
}

private struct MarkupElementOverlay: View {
    @Binding var element: MarkupElement
    @Binding var selectedElementID: MarkupElement.ID?
    let canvasSize: CGSize

    @State private var dragBase: MarkupElement?

    private var isSelected: Bool {
        selectedElementID == element.id
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            MarkupElementDrawing(element: element, canvasSize: canvasSize, isSelected: isSelected)
                .allowsHitTesting(false)

            hitTarget
                .onTapGesture {
                    selectedElementID = element.id
                }
                .gesture(moveGesture)

            if isSelected {
                handles
            }
        }
    }

    @ViewBuilder
    private var hitTarget: some View {
        switch element.kind {
        case .arrow:
            let rect = inflatedLineBounds(start: element.start.cgPoint(in: canvasSize), end: element.end.cgPoint(in: canvasSize), amount: 24)
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        case .rectangle:
            let rect = rectFrom(element.start, element.end, canvasSize: canvasSize)
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .frame(width: max(rect.width, 20), height: max(rect.height, 20))
                .position(x: rect.midX, y: rect.midY)
        case .text:
            Text(element.text)
                .font(.custom(element.fontName, size: CGFloat(element.fontSize)))
                .padding(8)
                .opacity(0.01)
                .contentShape(Rectangle())
                .position(element.start.cgPoint(in: canvasSize))
        }
    }

    @ViewBuilder
    private var handles: some View {
        switch element.kind {
        case .arrow:
            handle(at: element.start, handle: .start)
            handle(at: element.end, handle: .end)
        case .rectangle:
            handle(at: element.start, handle: .start)
            handle(at: element.end, handle: .end)
        case .text:
            EmptyView()
        }
    }

    private var moveGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if dragBase == nil {
                    dragBase = element
                    selectedElementID = element.id
                }
                guard var updated = dragBase else {
                    return
                }
                updated.translate(
                    dx: value.translation.width / max(canvasSize.width, 1),
                    dy: value.translation.height / max(canvasSize.height, 1)
                )
                element = updated
            }
            .onEnded { _ in
                dragBase = nil
            }
    }

    private func handle(at point: NormalizedPoint, handle: ResizeHandle) -> some View {
        Circle()
            .fill(Color(nsColor: .windowBackgroundColor))
            .overlay {
                Circle().stroke(Color.accentColor, lineWidth: 2)
            }
            .frame(width: 12, height: 12)
            .position(point.cgPoint(in: canvasSize))
            .gesture(resizeGesture(handle: handle))
            .help("Resize")
    }

    private func resizeGesture(handle: ResizeHandle) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if dragBase == nil {
                    dragBase = element
                    selectedElementID = element.id
                }
                guard var updated = dragBase else {
                    return
                }

                let dx = value.translation.width / max(canvasSize.width, 1)
                let dy = value.translation.height / max(canvasSize.height, 1)

                switch handle {
                case .start:
                    updated.start = updated.start.translatedBy(dx: dx, dy: dy)
                case .end:
                    updated.end = updated.end.translatedBy(dx: dx, dy: dy)
                }
                element = updated
            }
            .onEnded { _ in
                dragBase = nil
            }
    }
}

private struct MarkupElementDrawing: View {
    let element: MarkupElement
    let canvasSize: CGSize
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch element.kind {
            case .arrow:
                arrow
            case .rectangle:
                rectangle
            case .text:
                text
            }
        }
    }

    private var arrow: some View {
        let start = element.start.cgPoint(in: canvasSize)
        let end = element.end.cgPoint(in: canvasSize)
        let lineWidth = CGFloat(element.lineWidth)
        let geometry = ArrowGeometry.make(start: start, end: end, lineWidth: lineWidth)
        return ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: start)
                path.addLine(to: geometry.shaftEnd)
            }
            .stroke(Color(hex: element.colorHex), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

            arrowHeadPath(geometry)
                .fill(Color(hex: element.colorHex))

            if isSelected {
                Path { path in
                    path.move(to: start)
                    path.addLine(to: end)
                }
                .stroke(Color.accentColor.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
        }
    }

    private var rectangle: some View {
        let rect = rectFrom(element.start, element.end, canvasSize: canvasSize)
        return ZStack(alignment: .topLeading) {
            Path { path in
                path.addRect(rect)
            }
            .stroke(Color(hex: element.colorHex), style: StrokeStyle(lineWidth: CGFloat(element.lineWidth), lineJoin: .round))

            if isSelected {
                Path { path in
                    path.addRect(rect)
                }
                .stroke(Color.accentColor.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
        }
    }

    private var text: some View {
        Text(element.text)
            .font(.custom(element.fontName, size: CGFloat(element.fontSize)))
            .foregroundStyle(Color(hex: element.colorHex))
            .padding(2)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.accentColor.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
            }
            .position(element.start.cgPoint(in: canvasSize))
    }
}

private enum ResizeHandle {
    case start
    case end
}

private func aspectFitRect(imageSize: CGSize, containerSize: CGSize) -> CGRect {
    guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
        return .zero
    }

    let imageAspect = imageSize.width / imageSize.height
    let containerAspect = containerSize.width / containerSize.height
    let size: CGSize

    if imageAspect > containerAspect {
        size = CGSize(width: containerSize.width, height: containerSize.width / imageAspect)
    } else {
        size = CGSize(width: containerSize.height * imageAspect, height: containerSize.height)
    }

    return CGRect(
        x: (containerSize.width - size.width) / 2,
        y: (containerSize.height - size.height) / 2,
        width: size.width,
        height: size.height
    )
}

private func normalizedPoint(from point: CGPoint, canvasSize: CGSize) -> NormalizedPoint {
    NormalizedPoint(
        x: point.x / max(canvasSize.width, 1),
        y: point.y / max(canvasSize.height, 1)
    )
}

private func rectFrom(_ start: NormalizedPoint, _ end: NormalizedPoint, canvasSize: CGSize) -> CGRect {
    let startPoint = start.cgPoint(in: canvasSize)
    let endPoint = end.cgPoint(in: canvasSize)
    return CGRect(
        x: min(startPoint.x, endPoint.x),
        y: min(startPoint.y, endPoint.y),
        width: abs(endPoint.x - startPoint.x),
        height: abs(endPoint.y - startPoint.y)
    )
}

private func distance(from start: NormalizedPoint, to end: NormalizedPoint, in canvasSize: CGSize) -> CGFloat {
    let startPoint = start.cgPoint(in: canvasSize)
    let endPoint = end.cgPoint(in: canvasSize)
    return hypot(endPoint.x - startPoint.x, endPoint.y - startPoint.y)
}

private func inflatedLineBounds(start: CGPoint, end: CGPoint, amount: CGFloat) -> CGRect {
    CGRect(
        x: min(start.x, end.x),
        y: min(start.y, end.y),
        width: abs(end.x - start.x),
        height: abs(end.y - start.y)
    )
    .insetBy(dx: -amount, dy: -amount)
}

private func arrowHeadPath(_ geometry: ArrowGeometry) -> Path {
    var path = Path()
    path.move(to: geometry.tip)
    path.addLine(to: geometry.leftBase)
    path.addLine(to: geometry.rightBase)
    path.closeSubpath()
    return path
}

private extension NormalizedPoint {
    func cgPoint(in size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
    }
}
