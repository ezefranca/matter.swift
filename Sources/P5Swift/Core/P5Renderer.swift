import CoreGraphics

final class P5Renderer {
    private struct DrawingStyle {
        var fillColor: CGColor? = CGColor(gray: 1, alpha: 1)
        var strokeColor: CGColor? = CGColor(gray: 0, alpha: 1)
        var strokeWeight: CGFloat = 1
    }

    var size: CGSize = .zero

    private var operations: [P5Operation] = []
    private var style = DrawingStyle()

    func addOperation(_ operation: P5Operation) {
        operations.append(operation)
    }

    func render(in context: CGContext) {
        var styleStack: [DrawingStyle] = []

        for operation in operations {
            switch operation {
            case .fill(let color):
                style.fillColor = color
            case .noFill:
                style.fillColor = nil
            case .stroke(let color):
                style.strokeColor = color
            case .noStroke:
                style.strokeColor = nil
            case .strokeWeight(let weight):
                style.strokeWeight = weight
            case .background(let bgColor):
                background(bgColor, in: context)
            case .line(let x1, let y1, let x2, let y2):
                line(x1, y1, x2, y2, in: context)
            case .rect(let x, let y, let w, let h):
                draw(
                    CGRect(x: x, y: y, width: w, height: h),
                    in: context
                )
            case .square(let x, let y, let extent):
                draw(
                    CGRect(x: x, y: y, width: extent, height: extent),
                    in: context
                )
            case .ellipse(let x, let y, let width, let height):
                drawEllipse(
                    CGRect(
                        x: x - width / 2,
                        y: y - height / 2,
                        width: width,
                        height: height
                    ),
                    in: context
                )
            case .rotate(let angle):
                context.rotate(by: angle)
            case .translate(let x, let y):
                context.translateBy(x: x, y: y)
            case .push:
                context.saveGState()
                styleStack.append(style)
            case .pop:
                guard let savedStyle = styleStack.popLast() else {
                    continue
                }
                context.restoreGState()
                style = savedStyle
            }
        }
        operations.removeAll()
    }

    private func background(_ color: CGColor, in context: CGContext) {
        context.saveGState()
        context.setFillColor(color)
        context.fill(CGRect(origin: .zero, size: size))
        context.restoreGState()
    }

    private func line(
        _ x1: CGFloat,
        _ y1: CGFloat,
        _ x2: CGFloat,
        _ y2: CGFloat,
        in context: CGContext
    ) {
        guard let strokeColor = style.strokeColor else {
            return
        }

        context.saveGState()
        context.setStrokeColor(strokeColor)
        context.setLineWidth(style.strokeWeight)
        context.beginPath()
        context.move(to: CGPoint(x: x1, y: y1))
        context.addLine(to: CGPoint(x: x2, y: y2))
        context.strokePath()
        context.restoreGState()
    }

    private func draw(_ rectangle: CGRect, in context: CGContext) {
        context.beginPath()
        context.addRect(rectangle)
        drawCurrentPath(in: context)
    }

    private func drawEllipse(_ rectangle: CGRect, in context: CGContext) {
        context.beginPath()
        context.addEllipse(in: rectangle)
        drawCurrentPath(in: context)
    }

    private func drawCurrentPath(in context: CGContext) {
        switch (style.fillColor, style.strokeColor) {
        case let (fillColor?, strokeColor?):
            context.setFillColor(fillColor)
            context.setStrokeColor(strokeColor)
            context.setLineWidth(style.strokeWeight)
            context.drawPath(using: .fillStroke)
        case let (fillColor?, nil):
            context.setFillColor(fillColor)
            context.drawPath(using: .fill)
        case let (nil, strokeColor?):
            context.setStrokeColor(strokeColor)
            context.setLineWidth(style.strokeWeight)
            context.drawPath(using: .stroke)
        case (nil, nil):
            context.beginPath()
        }
    }
}
