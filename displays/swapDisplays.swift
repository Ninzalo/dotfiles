import Foundation
import CoreGraphics

func activeDisplays() -> [CGDirectDisplayID] {
    var count: UInt32 = 0
    CGGetActiveDisplayList(0, nil, &count)
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetActiveDisplayList(count, &ids, &count)
    return Array(ids.prefix(Int(count)))
}

let ids = activeDisplays()
let externals = ids.filter { CGDisplayIsBuiltin($0) == 0 }
guard externals.count >= 2 else { exit(1) }

var bounds = [CGDirectDisplayID: CGRect]()
for id in externals { bounds[id] = CGDisplayBounds(id) }

let sorted = externals.sorted { bounds[$0]!.origin.x < bounds[$1]!.origin.x }
let left = sorted.first!, right = sorted.last!

var config: CGDisplayConfigRef?
guard CGBeginDisplayConfiguration(&config) == .success, let cfg = config else { exit(2) }

let lx = Int32(bounds[left]!.origin.x), ly = Int32(bounds[left]!.origin.y)
let rx = Int32(bounds[right]!.origin.x), ry = Int32(bounds[right]!.origin.y)

if CGConfigureDisplayOrigin(cfg, left, rx, ry) != .success || CGConfigureDisplayOrigin(cfg, right, lx, ly) != .success {
    CGCancelDisplayConfiguration(cfg)
    exit(3)
}

if CGCompleteDisplayConfiguration(cfg, .forSession) != .success { exit(4) }
print("OK")
