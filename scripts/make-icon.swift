#!/usr/bin/env swift
//
// Generates the Harbor Lens app icon into Assets.xcassets/AppIcon.appiconset.
//
// Usage:
//   swift scripts/make-icon.swift             # write icon PNGs + Contents.json
//   swift scripts/make-icon.swift --preview   # also write .build/icon-preview.png
//
// The icon is a magnifier held over a stepped trajectory: the glass contains
// the path (so the ring never reads as a "prohibited" slash), the steps are
// marked with nodes, and the step under inspection is tinted with the app's
// comparison orange. Artwork is drawn in a 1024x1024 design space (y-up) and
// rendered natively at every pixel size, so small sizes stay crisp instead of
// being downsampled from the master.

import CoreGraphics
import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Helpers

private func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
	CGColor(
		srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
		green: CGFloat((hex >> 8) & 0xFF) / 255,
		blue: CGFloat(hex & 0xFF) / 255,
		alpha: alpha
	)
}

private func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
	CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: locations)!
}

/// A trajectory drawn as a stepped polyline, with node markers at chosen
/// vertices.
private struct Route {
	let points: [CGPoint]
	let nodeIndices: [Int]
	/// A segment redrawn in the comparison color, or nil for a plain route.
	let accentSegment: (start: Int, end: Int)?

	func addSubpath(_ ctx: CGContext, from start: Int, to end: Int) {
		for index in start...end {
			if index == start {
				ctx.move(to: points[index])
			} else {
				ctx.addLine(to: points[index])
			}
		}
	}

	func add(to ctx: CGContext) {
		addSubpath(ctx, from: 0, to: points.count - 1)
	}
}

private func drawCircle(_ center: CGPoint, radius: CGFloat, fill: CGColor, shadow: Bool, in ctx: CGContext) {
	let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
	ctx.saveGState()
	if shadow {
		ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 12, color: rgb(0x02070C, 0.55))
	}
	ctx.addEllipse(in: rect)
	ctx.setFillColor(fill)
	ctx.fillPath()
	ctx.restoreGState()
}

// MARK: - Design constants

private let designSize: CGFloat = 1024
private let bodyRect = CGRect(x: 100, y: 100, width: 824, height: 824)
private let bodyRadius: CGFloat = 185.4

// Magnifier lens, large enough to be the icon's silhouette.
private let lensCenter = CGPoint(x: 495, y: 555)
private let lensRadius: CGFloat = 250
private let ringWidth: CGFloat = 48

private let handleAngle: CGFloat = -56 * .pi / 180
private let handleStartRadius: CGFloat = lensRadius - 20
private let handleEndRadius: CGFloat = lensRadius + 150
private let handleWidth: CGFloat = 74

private let routeWidth: CGFloat = 44
private let nodeRadius: CGFloat = 32

private let primaryColor = rgb(0x3EE0BF)
private let comparisonColor = rgb(0xF4703F)

/// Steps of a run, rising left to right inside the glass. Vertex 2 is the
/// inspected step, so the segment leaving it carries the comparison color.
private let route = Route(
	points: [
		CGPoint(x: 330, y: 470),
		CGPoint(x: 455, y: 470),
		CGPoint(x: 455, y: 565),
		CGPoint(x: 575, y: 565),
		CGPoint(x: 575, y: 650),
		CGPoint(x: 660, y: 650),
	],
	nodeIndices: [0, 2, 5],
	accentSegment: (2, 3)
)

/// Widens strokes and nodes on small renders so the icon keeps its contrast
/// once a stroke would otherwise be thinner than a pixel.
private func strokeBoost(for size: CGFloat) -> CGFloat {
	switch size {
	case ..<24: return 2
	case ..<48: return 1.6
	case ..<96: return 1.35
	case ..<192: return 1.15
	default: return 1
	}
}

// MARK: - Drawing

private func drawIcon(_ ctx: CGContext, size: CGFloat) {
	let boost = strokeBoost(for: size)
	let simplified = size < 48
	let body = RoundedRectangle(cornerRadius: bodyRadius, style: .continuous).path(in: bodyRect).cgPath
	let lensRect = CGRect(
		x: lensCenter.x - lensRadius,
		y: lensCenter.y - lensRadius,
		width: lensRadius * 2,
		height: lensRadius * 2
	)

	// Squircle with the soft baked shadow macOS icons carry.
	ctx.saveGState()
	ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: rgb(0x040B12, 0.5))
	ctx.addPath(body)
	ctx.setFillColor(rgb(0x0A1928))
	ctx.fillPath()
	ctx.restoreGState()

	ctx.saveGState()
	ctx.addPath(body)
	ctx.clip()

	// Harbor at dusk: deep teal fading into navy, with a soft glow behind the lens.
	ctx.drawLinearGradient(
		gradient([rgb(0x1A5A66), rgb(0x081421)], [0, 1]),
		start: CGPoint(x: 512, y: bodyRect.maxY),
		end: CGPoint(x: 512, y: bodyRect.minY),
		options: []
	)
	ctx.drawRadialGradient(
		gradient([rgb(0x7FE9D8, 0.10), rgb(0x7FE9D8, 0)], [0, 1]),
		startCenter: lensCenter,
		startRadius: 0,
		endCenter: lensCenter,
		endRadius: 470,
		options: []
	)

	// Magnifier handle, tucked underneath the lens ring.
	let direction = CGPoint(x: cos(handleAngle), y: sin(handleAngle))
	let handleStart = CGPoint(
		x: lensCenter.x + direction.x * handleStartRadius,
		y: lensCenter.y + direction.y * handleStartRadius
	)
	let handleEnd = CGPoint(
		x: lensCenter.x + direction.x * handleEndRadius,
		y: lensCenter.y + direction.y * handleEndRadius
	)
	let handle = CGMutablePath()
	handle.move(to: handleStart)
	handle.addLine(to: handleEnd)

	ctx.saveGState()
	ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: rgb(0x02070C, 0.5))
	ctx.setLineCap(.round)
	ctx.setLineWidth(handleWidth * boost)
	ctx.setStrokeColor(rgb(0x17506B))
	ctx.addPath(handle)
	ctx.strokePath()
	ctx.restoreGState()

	ctx.saveGState()
	ctx.setLineCap(.round)
	ctx.addPath(handle)
	ctx.setLineWidth(handleWidth * boost)
	ctx.replacePathWithStrokedPath()
	ctx.clip()
	ctx.drawLinearGradient(
		gradient([rgb(0x45B8D2), rgb(0x17506B)], [0, 1]),
		start: handleStart,
		end: handleEnd,
		options: []
	)
	ctx.restoreGState()

	// Glass: a translucent disc that lifts whatever sits under it. It stays
	// darker on small renders so the route does not dissolve into the tint.
	ctx.saveGState()
	ctx.addEllipse(in: lensRect)
	ctx.clip()
	ctx.drawRadialGradient(
		gradient([rgb(0x9FEFE0, size < 48 ? 0.07 : 0.22), rgb(0x9FEFE0, size < 48 ? 0.02 : 0.05)], [0, 1]),
		startCenter: lensCenter,
		startRadius: 0,
		endCenter: lensCenter,
		endRadius: lensRadius,
		options: []
	)
	ctx.restoreGState()

	// The run inside the glass, with its step markers.
	let nodes = simplified ? [route.nodeIndices.first!, route.nodeIndices.last!] : route.nodeIndices
	ctx.saveGState()
	ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 16, color: rgb(0x02070C, 0.5))
	ctx.setLineCap(.round)
	ctx.setLineJoin(.round)
	ctx.setLineWidth(routeWidth * boost)
	ctx.setStrokeColor(primaryColor)
	route.add(to: ctx)
	ctx.strokePath()
	if let accent = route.accentSegment {
		ctx.setStrokeColor(comparisonColor)
		route.addSubpath(ctx, from: accent.start, to: accent.end)
		ctx.strokePath()
	}
	ctx.restoreGState()

	for index in nodes {
		drawCircle(route.points[index], radius: nodeRadius * boost, fill: rgb(0xFFFFFF), shadow: true, in: ctx)
	}

	// Lens ring with a glassy top-left to bottom-right gradient.
	let ring = CGMutablePath()
	ring.addArc(center: lensCenter, radius: lensRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
	ctx.saveGState()
	ctx.setLineWidth(ringWidth * boost)
	ctx.addPath(ring)
	ctx.replacePathWithStrokedPath()
	ctx.clip()
	ctx.drawLinearGradient(
		gradient([rgb(0xA8F6E4), rgb(0x3AA9C9), rgb(0x1C6E93)], [0, 0.55, 1]),
		start: CGPoint(x: lensCenter.x - 320, y: lensCenter.y + 320),
		end: CGPoint(x: lensCenter.x + 320, y: lensCenter.y - 320),
		options: []
	)
	ctx.restoreGState()

	// Specular highlight on the upper-left of the ring.
	if size >= 48 {
		ctx.saveGState()
		ctx.setLineCap(.round)
		ctx.setLineWidth(13 * boost)
		ctx.setStrokeColor(rgb(0xFFFFFF, 0.5))
		ctx.addArc(center: lensCenter, radius: lensRadius, startAngle: 1.85, endAngle: 2.6, clockwise: false)
		ctx.strokePath()
		ctx.restoreGState()
	}

	// Inner rim keeps the squircle edge defined against dark backgrounds.
	ctx.addPath(body)
	ctx.setLineWidth(4)
	ctx.setStrokeColor(rgb(0xFFFFFF, 0.09))
	ctx.strokePath()

	ctx.restoreGState()
}

// MARK: - Rendering

private func renderIcon(size: Int) -> CGImage {
	let space = CGColorSpace(name: CGColorSpace.sRGB)!
	guard
		let ctx = CGContext(
			data: nil,
			width: size,
			height: size,
			bitsPerComponent: 8,
			bytesPerRow: 0,
			space: space,
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		)
	else {
		fatalError("could not create a \(size)x\(size) bitmap context")
	}
	ctx.scaleBy(x: CGFloat(size) / designSize, y: CGFloat(size) / designSize)
	drawIcon(ctx, size: CGFloat(size))
	guard let image = ctx.makeImage() else {
		fatalError("could not render the \(size)x\(size) icon")
	}
	return image
}

private func writePNG(_ image: CGImage, to url: URL) {
	guard
		let destination = CGImageDestinationCreateWithURL(
			url as CFURL,
			UTType.png.identifier as CFString,
			1,
			nil
		)
	else {
		fatalError("could not open \(url.path) for writing")
	}
	CGImageDestinationAddImage(destination, image, nil)
	guard CGImageDestinationFinalize(destination) else {
		fatalError("could not write \(url.path)")
	}
}

private func writePreview(master: CGImage, images: [(Int, CGImage)], to url: URL) {
	let sheetWidth = 1600
	let sheetHeight = 640
	let space = CGColorSpace(name: CGColorSpace.sRGB)!
	guard
		let ctx = CGContext(
			data: nil,
			width: sheetWidth,
			height: sheetHeight,
			bitsPerComponent: 8,
			bytesPerRow: 0,
			space: space,
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		)
	else {
		fatalError("could not create the preview context")
	}
	ctx.setFillColor(rgb(0x6E6E73))
	ctx.fill(CGRect(x: 0, y: 0, width: sheetWidth, height: sheetHeight))
	ctx.interpolationQuality = .none

	// Master at half size, then the small renders magnified for inspection.
	ctx.draw(master, in: CGRect(x: 32, y: 64, width: 512, height: 512))

	let zoom: [(size: Int, scale: CGFloat)] = [(256, 1), (128, 2), (64, 3), (32, 4), (16, 4)]
	var x: CGFloat = 576
	for (size, scale) in zoom {
		guard let image = images.first(where: { $0.0 == size })?.1 else { continue }
		let side = CGFloat(size) * scale
		ctx.draw(image, in: CGRect(x: x, y: 64, width: side, height: side))
		x += side + 20
	}
	guard let sheet = ctx.makeImage() else {
		fatalError("could not render the preview sheet")
	}
	writePNG(sheet, to: url)
}

// MARK: - Entry point

let repoRoot = URL(fileURLWithPath: #filePath)
	.resolvingSymlinksInPath()
	.deletingLastPathComponent()
	.deletingLastPathComponent()
let iconSet = repoRoot.appending(path: "HarborTrajectoryViewer/Assets.xcassets/AppIcon.appiconset")
let fileManager = FileManager.default
try? fileManager.createDirectory(at: iconSet, withIntermediateDirectories: true)

let assets: [(name: String, size: Int)] = [
	("icon_16x16.png", 16),
	("icon_16x16@2x.png", 32),
	("icon_32x32.png", 32),
	("icon_32x32@2x.png", 64),
	("icon_128x128.png", 128),
	("icon_128x128@2x.png", 256),
	("icon_256x256.png", 256),
	("icon_256x256@2x.png", 512),
	("icon_512x512.png", 512),
	("icon_512x512@2x.png", 1024),
]

var rendered: [Int: CGImage] = [:]
for size in Set(assets.map(\.size)).sorted() {
	rendered[size] = renderIcon(size: size)
}
for asset in assets {
	writePNG(rendered[asset.size]!, to: iconSet.appending(path: asset.name))
	print("wrote \(asset.name) (\(asset.size)x\(asset.size))")
}

if CommandLine.arguments.contains("--preview") {
	let previewDirectory = repoRoot.appending(path: ".build")
	try? fileManager.createDirectory(at: previewDirectory, withIntermediateDirectories: true)
	let previewURL = previewDirectory.appending(path: "icon-preview.png")
	writePreview(
		master: rendered[1024]!,
		images: [16, 32, 64, 128, 256].map { ($0, rendered[$0]!) },
		to: previewURL
	)
	print("wrote \(previewURL.path)")
}
