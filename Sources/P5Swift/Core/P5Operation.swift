import CoreGraphics

enum P5Operation {
    case fill(CGColor)
    case noFill
    case stroke(CGColor)
    case noStroke
    case strokeWeight(CGFloat)
    
    case background(CGColor)
    case line(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat)
    case rect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)
    case square(x: CGFloat, y: CGFloat, extent: CGFloat)
    case ellipse(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)
    
    case rotate(CGFloat)
    case translate(x: CGFloat, y: CGFloat)
    
    case push
    case pop
}
