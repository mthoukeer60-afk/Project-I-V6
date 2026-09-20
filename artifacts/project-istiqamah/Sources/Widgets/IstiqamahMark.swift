import SwiftUI

struct IstiqamahMark: View {
    var primary: Color = Color(red: 0.56, green: 0.83, blue: 0.72)
    var secondary: Color = Color(red: 0.72, green: 0.91, blue: 0.82)

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .fill(primary)
                    .frame(width: side * 0.25, height: side * 0.25)
                    .position(x: side * 0.52, y: side * 0.18)

                IstiqamahStemShape()
                    .fill(primary)

                IstiqamahSweepShape()
                    .fill(secondary)
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct IstiqamahStemShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: point(0.32, 0.88, in: rect))
        path.addLine(to: point(0.32, 0.52, in: rect))
        path.addCurve(
            to: point(0.69, 0.31, in: rect),
            control1: point(0.32, 0.43, in: rect),
            control2: point(0.61, 0.28, in: rect)
        )
        path.addCurve(
            to: point(0.76, 0.40, in: rect),
            control1: point(0.73, 0.32, in: rect),
            control2: point(0.76, 0.35, in: rect)
        )
        path.addLine(to: point(0.76, 0.68, in: rect))
        path.addCurve(
            to: point(0.59, 0.88, in: rect),
            control1: point(0.76, 0.80, in: rect),
            control2: point(0.70, 0.88, in: rect)
        )
        path.closeSubpath()
        return path
    }

    private func point(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
    }
}

private struct IstiqamahSweepShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: point(0.32, 0.88, in: rect))
        path.addCurve(
            to: point(0.76, 0.54, in: rect),
            control1: point(0.36, 0.69, in: rect),
            control2: point(0.60, 0.66, in: rect)
        )
        path.addLine(to: point(0.76, 0.70, in: rect))
        path.addCurve(
            to: point(0.59, 0.88, in: rect),
            control1: point(0.75, 0.81, in: rect),
            control2: point(0.69, 0.88, in: rect)
        )
        path.closeSubpath()
        return path
    }

    private func point(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
    }
}
