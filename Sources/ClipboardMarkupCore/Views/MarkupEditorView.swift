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
    @AppStorage("markupEditor.colorHex") private var colorHex = "#FF3B30"
    @AppStorage("markupEditor.lineWeight") private var lineWidth = 8.0
    @AppStorage("markupEditor.textSize") private var fontSize = 42.0

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
                fontSize: $fontSize,
                selectedKind: selectedElement?.kind,
                canDeleteSelectedMarkup: selectedElementID != nil,
                hasMarkupElements: !elements.isEmpty,
                onDeleteSelectedMarkup: deleteSelectedElement,
                onRevertMarkup: revertMarkup
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            MarkupCanvas(
                originalImage: originalImage,
                elements: $elements,
                selectedElementID: $selectedElementID,
                tool: tool,
                colorHex: colorHex,
                lineWidth: lineWidth,
                fontSize: fontSize
            )
            .padding(12)

            Divider()

            HStack {
                Spacer()

                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .appFont(size: 13)
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    onSave(elements.filter(\.isRenderable))
                } label: {
                    Label("Save", systemImage: "checkmark")
                        .appFont(size: 13)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .padding(12)
        }
        .onDeleteCommand(perform: deleteSelectedElement)
        .onChange(of: selectedElementID) { oldValue, newValue in
            pruneEmptyTextElement(id: oldValue)
            syncControlsFromSelection(newValue)
        }
        .onChange(of: colorHex) { _, _ in
            applyControlsToSelection()
        }
        .onChange(of: lineWidth) { _, _ in
            applyControlsToSelection()
        }
        .onChange(of: fontSize) { _, _ in
            applyControlsToSelection()
        }
    }

    private var selectedElement: MarkupElement? {
        guard let selectedElementID else {
            return nil
        }

        return elements.first { $0.id == selectedElementID }
    }

    private func syncControlsFromSelection(_ id: MarkupElement.ID?) {
        guard let id,
              let element = elements.first(where: { $0.id == id })
        else {
            return
        }

        colorHex = element.colorHex
        lineWidth = element.lineWidth
        fontSize = element.fontSize
    }

    private func applyControlsToSelection() {
        guard let selectedElementID,
              let index = elements.firstIndex(where: { $0.id == selectedElementID })
        else {
            return
        }

        elements[index].colorHex = colorHex
        switch elements[index].kind {
        case .arrow, .rectangle:
            elements[index].lineWidth = lineWidth
        case .text:
            elements[index].fontSize = fontSize
        }
    }

    private func deleteSelectedElement() {
        guard let selectedElementID else {
            return
        }
        elements.removeAll { $0.id == selectedElementID }
        self.selectedElementID = nil
    }

    private func revertMarkup() {
        elements.removeAll()
        selectedElementID = nil
    }

    private func pruneEmptyTextElement(id: MarkupElement.ID?) {
        guard let id else {
            return
        }

        elements.removeAll { element in
            element.id == id && element.kind == .text && !element.isRenderable
        }
    }
}

private struct MarkupToolbar: View {
    @Binding var tool: MarkupTool
    @Binding var colorHex: String
    @Binding var lineWidth: Double
    @Binding var fontSize: Double
    let selectedKind: MarkupElement.Kind?
    let canDeleteSelectedMarkup: Bool
    let hasMarkupElements: Bool
    let onDeleteSelectedMarkup: () -> Void
    let onRevertMarkup: () -> Void

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

    var body: some View {
        HStack(spacing: 10) {
            MarkupToolButton(tool: .select, isSelected: tool == .select) {
                tool = .select
            }

            ToolbarSeparator()

            HStack(spacing: 5) {
                MarkupToolButton(tool: .arrow, isSelected: tool == .arrow) {
                    tool = .arrow
                }

                MarkupToolButton(tool: .rectangle, isSelected: tool == .rectangle) {
                    tool = .rectangle
                }

                LineWeightMenu(selection: $lineWidth, isDisabled: selectedKind == .text)
            }

            ToolbarSeparator()

            HStack(spacing: 5) {
                MarkupToolButton(tool: .text, isSelected: tool == .text) {
                    tool = .text
                }

                ToolbarValueStepper(
                    title: "Size",
                    systemImage: "textformat.size",
                    value: $fontSize,
                    range: 18...96,
                    step: 1,
                    isDisabled: selectedKind != .text
                )
                .help("Select text to change its size")
            }

            ToolbarSeparator()

            ColorPickerMenu(selection: $colorHex, palette: palette)

            Spacer()

            Button {
                onRevertMarkup()
            } label: {
                Label("Revert Markup", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(!hasMarkupElements)
            .help("Remove all markup and restore the original image")

            Button(role: .destructive) {
                onDeleteSelectedMarkup()
            } label: {
                Label("Delete selected markup", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .tint(.red)
            .disabled(!canDeleteSelectedMarkup)
            .help("Delete selected markup")
        }
    }
}

private struct MarkupToolButton: View {
    let tool: MarkupTool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: tool.systemImage)
                .symbolRenderingMode(.hierarchical)
                .appFont(size: tool == .text ? 12 : 13, weight: .semibold)
                .foregroundStyle(Color.primary)
                .frame(width: 26, height: 26)
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .background(
            isSelected ? Color.primary.opacity(0.12) : Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.primary.opacity(0.28) : Color.secondary.opacity(0.18), lineWidth: 1)
        }
        .help(tool.title)
    }
}

private struct ToolbarSeparator: View {
    var body: some View {
        Divider()
            .frame(height: 24)
    }
}

private struct ColorPickerMenu: View {
    @Binding var selection: String
    let palette: [String]

    var body: some View {
        Menu {
            ForEach(palette, id: \.self) { swatch in
                Button {
                    selection = swatch
                } label: {
                    Label {
                        Text(colorName(for: swatch))
                    } icon: {
                        Image(nsImage: swatchImage(for: swatch, diameter: 12))
                            .renderingMode(.original)
                    }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(nsImage: swatchImage(for: selection, diameter: 14))
                    .renderingMode(.original)

                Text(colorName(for: selection))
                    .appFont(size: 12, weight: .medium)

                Image(systemName: "chevron.down")
                    .appFont(size: 8, weight: .semibold)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            }
        }
        .menuStyle(.borderlessButton)
        .help("Color")
    }

    private func colorName(for hex: String) -> String {
        switch hex {
        case "#FF3B30":
            "Red"
        case "#FF9500":
            "Orange"
        case "#FFCC00":
            "Yellow"
        case "#34C759":
            "Green"
        case "#007AFF":
            "Blue"
        case "#AF52DE":
            "Purple"
        case "#FFFFFF":
            "White"
        case "#111111":
            "Black"
        default:
            hex
        }
    }

    private func swatchImage(for hex: String, diameter: CGFloat) -> NSImage {
        let image = NSImage(size: CGSize(width: diameter, height: diameter))
        image.lockFocus()
        let rect = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        let path = NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
        (NSColor(hex: hex) ?? .systemRed).setFill()
        path.fill()
        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()
        image.unlockFocus()
        return image
    }
}

private struct LineWeightMenu: View {
    @Binding var selection: Double
    let isDisabled: Bool

    private let weights = [2.0, 4.0, 6.0, 8.0, 12.0, 16.0, 20.0, 24.0, 28.0]

    var body: some View {
        Menu {
            ForEach(weights, id: \.self) { weight in
                Button {
                    selection = weight
                } label: {
                    HStack {
                        if roundedSelection == Int(weight) {
                            Image(systemName: "checkmark")
                        }
                        Text("\(Int(weight)) pt")
                    }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "line.3.horizontal.decrease")
                    .symbolRenderingMode(.hierarchical)
                    .appFont(size: 12, weight: .semibold)

                Text("\(roundedSelection)")
                    .appFont(size: 12, weight: .medium, design: .monospaced)

                Image(systemName: "chevron.down")
                    .appFont(size: 8, weight: .semibold)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            }
        }
        .menuStyle(.borderlessButton)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .help("Line weight")
    }

    private var roundedSelection: Int {
        Int(round(selection))
    }
}

private struct ToolbarValueStepper: View {
    let title: String
    let systemImage: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let isDisabled: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .appFont(size: 12, weight: .semibold)
                .foregroundStyle(.secondary)
                .frame(width: 14)

            Text("\(title) \(Int(round(value)))")
                .appFont(size: 12, weight: .medium)
                .foregroundStyle(.primary)
                .frame(minWidth: 58, alignment: .leading)

            HStack(spacing: 1) {
                Button {
                    value = max(range.lowerBound, value - step)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 20, height: 20)
                }
                .disabled(isDisabled || value <= range.lowerBound)

                Button {
                    value = min(range.upperBound, value + step)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 20, height: 20)
                }
                .disabled(isDisabled || value >= range.upperBound)
            }
            .buttonStyle(.plain)
            .appFont(size: 10, weight: .semibold)
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        }
        .opacity(isDisabled ? 0.45 : 1)
        .allowsHitTesting(!isDisabled)
    }
}

private struct MarkupCanvas: View {
    let originalImage: NSImage
    @Binding var elements: [MarkupElement]
    @Binding var selectedElementID: MarkupElement.ID?
    let tool: MarkupTool
    let colorHex: String
    let lineWidth: Double
    let fontSize: Double

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
        .onHover { isHovering in
            if isHovering && tool == .text {
                NSCursor.iBeam.set()
            } else {
                NSCursor.arrow.set()
            }
        }
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
                    let element = MarkupElement(
                        kind: .text,
                        start: location,
                        end: location,
                        text: "",
                        colorHex: colorHex,
                        lineWidth: lineWidth,
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
    @FocusState private var isEditingText: Bool

    private var isSelected: Bool {
        selectedElementID == element.id
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if element.kind == .text && isSelected {
                editableText
            } else {
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
        .onAppear {
            if isSelected && element.kind == .text {
                focusTextEditor()
            }
        }
        .onChange(of: isSelected) { _, selected in
            if selected && element.kind == .text {
                focusTextEditor()
            } else {
                isEditingText = false
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
            Text(element.displayText)
                .font(.custom(element.fontName, size: CGFloat(element.fontSize)))
                .padding(8)
                .opacity(0.01)
                .contentShape(Rectangle())
                .position(element.start.cgPoint(in: canvasSize))
        }
    }

    private var editableText: some View {
        TextField("Text", text: $element.text)
            .textFieldStyle(.plain)
            .font(.custom(element.fontName, size: CGFloat(element.fontSize)))
            .foregroundStyle(Color(hex: element.colorHex))
            .focused($isEditingText)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .frame(width: textEditorWidth, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor.opacity(0.72), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
            .position(element.start.cgPoint(in: canvasSize))
            .simultaneousGesture(moveGesture)
            .onTapGesture {
                selectedElementID = element.id
            }
            .help("Edit text")
    }

    private var textEditorWidth: CGFloat {
        let approximateCharacterWidth = max(8, CGFloat(element.fontSize) * 0.58)
        let textLength = max(4, element.text.count)
        let preferredWidth = CGFloat(textLength) * approximateCharacterWidth + 18
        return min(max(82, preferredWidth), max(82, canvasSize.width - 24))
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

    private func focusTextEditor() {
        DispatchQueue.main.async {
            isEditingText = true
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
        Text(element.displayText)
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

private extension MarkupElement {
    var displayText: String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedText.isEmpty ? "Text" : text
    }

    var isRenderable: Bool {
        kind != .text || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
