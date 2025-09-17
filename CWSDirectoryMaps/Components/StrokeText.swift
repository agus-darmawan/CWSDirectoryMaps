//
//  StrokeText.swift
//  CWSDirectoryMaps
//
//  HD-quality stroke text component with zoom support
//

import SwiftUI

struct StrokeText: View {
    let text: String
    let fontSize: CGFloat
    let textColor: Color
    let outlineColor: Color
    let lineWidth: CGFloat
    let fixedWidth: CGFloat?
    
    init(
        text: String,
        fontSize: CGFloat,
        textColor: Color = .primary,
        outlineColor: Color = .white,
        lineWidth: CGFloat = 1.0,
        fixedWidth: CGFloat? = nil
    ) {
        self.text = text
        self.fontSize = fontSize
        self.textColor = textColor
        self.outlineColor = outlineColor
        self.lineWidth = lineWidth
        self.fixedWidth = fixedWidth
    }
    
    var body: some View {
        ZStack {
            // Create comprehensive outline using 12 directions for smoother result
            ForEach(0..<12, id: \.self) { i in
                let angle = Double(i) * .pi / 6 // 30-degree increments
                let xOffset = cos(angle) * Double(lineWidth)
                let yOffset = sin(angle) * Double(lineWidth)
                
                Text(text)
                    .font(.system(size: fontSize, weight: .bold, design: .default))
                    .foregroundColor(outlineColor)
                    .offset(x: xOffset, y: yOffset)
            }
            
            // Additional inner outline for better definition
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) * .pi / 4 // 45-degree increments
                let xOffset = cos(angle) * Double(lineWidth * 0.5)
                let yOffset = sin(angle) * Double(lineWidth * 0.5)
                
                Text(text)
                    .font(.system(size: fontSize, weight: .bold, design: .default))
                    .foregroundColor(outlineColor)
                    .offset(x: xOffset, y: yOffset)
            }
            
            // Main text
            Text(text)
                .font(.system(size: fontSize, weight: .bold, design: .default))
                .foregroundColor(textColor)
        }
        .lineLimit(1)
        .frame(width: fixedWidth, height: fontSize * 1.5)
        .minimumScaleFactor(0.5)
    }
}


// MARK: - Convenience Initializers
extension StrokeText {
    /// Store label with blue text and white outline
    static func storeLabel(
        text: String,
        fontSize: CGFloat,
        fixedWidth: CGFloat? = nil
    ) -> StrokeText {
        StrokeText(
            text: text,
            fontSize: fontSize,
            textColor: Color(UIColor.systemBlue),
            outlineColor: .white,
            lineWidth: max(0.5, fontSize * 0.08), // Adaptive line width
            fixedWidth: fixedWidth
        )
    }
    
    /// Navigation text with custom colors
    static func navigationLabel(
        text: String,
        fontSize: CGFloat,
        textColor: Color = .primary,
        outlineColor: Color = .white,
        fixedWidth: CGFloat? = nil
    ) -> StrokeText {
        StrokeText(
            text: text,
            fontSize: fontSize,
            textColor: textColor,
            outlineColor: outlineColor,
            lineWidth: max(0.3, fontSize * 0.06),
            fixedWidth: fixedWidth
        )
    }
}
