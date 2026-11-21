import Foundation
import CoreGraphics

func fail(_ code: Int32, _ msg: String) -> Never {
    FileHandle.standardError.write(Data("\(msg)\n".utf8))
    exit(code)
}

func osascript(_ script: String) -> String? {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    p.arguments = ["-e", script]
    let out = Pipe()
    p.standardOutput = out
    p.standardError = Pipe()
    do { try p.run() } catch { return nil }
    p.waitUntilExit()
    guard p.terminationStatus == 0 else { return nil }
    let data = out.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)
}

// osascript prints a list as "path1, path2" — split into elements
func splitList(_ s: String) -> [String] {
    s.split(separator: ",").map {
        $0.trimmingCharacters(in: .whitespacesAndNewlines)
           .replacingOccurrences(of: "^file\\s+", with: "", options: .regularExpression)
    }.filter { !$0.isEmpty }
}

func appleQuote(_ s: String) -> String {
    s.replacingOccurrences(of: "\\", with: "\\\\")
     .replacingOccurrences(of: "\"", with: "\\\"")
}

struct Disp {
    let id: CGDirectDisplayID
    let origin: CGPoint
    let width: CGFloat
    let isMain: Bool
}

func externalDisplays() -> [Disp] {
    var count: UInt32 = 0
    CGGetActiveDisplayList(0, nil, &count)
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetActiveDisplayList(count, &ids, &count)
    var out: [Disp] = []
    for id in ids.prefix(Int(count)) where CGDisplayIsBuiltin(id) == 0 {
        let b = CGDisplayBounds(id)
        out.append(Disp(id: id, origin: b.origin, width: b.width,
                        isMain: CGDisplayIsMain(id) == 1))
    }
    return out
}

// ---------------------------------------------------------------------------
// 1. Current display state
// ---------------------------------------------------------------------------

let pre = externalDisplays()
guard pre.count == 2 else {
    fail(1, "swapDisplays: expected 2 external displays, found \(pre.count)")
}
let main0  = pre.first { $0.isMain } ?? pre[0]
let other0 = pre.first { $0.id != main0.id }!
let otherOnLeft = other0.origin.x < main0.origin.x

// 2. Current wallpapers.  `get picture of every desktop` is in DESKTOP order:
//    desktop 1 == the MAIN display, desktop 2 == the other one.
//    Wallpapers are kept at their SCREEN POSITION: after the swap the left
//    monitor must still show what the left monitor showed, and same for the
//    right — i.e. the wallpaper values follow the physical positions.
guard let listing = osascript("tell application \"System Events\" to get picture of every desktop") else {
    fail(5, "swapDisplays: could not read desktop pictures")
}
let before = splitList(listing)
guard before.count == 2 else { fail(5, "swapDisplays: expected 2 desktop pictures") }
let mainWall  = before[0]
let otherWall = before[1]
let leftWall  = otherOnLeft ? otherWall : mainWall
let rightWall = otherOnLeft ? mainWall : otherWall

// 3. Geometry swap: the other display takes the origin — and with it the
//    "main" designation, which macOS always attaches to the display at (0,0)
//    — while the main display moves to the side the other one used to occupy.
var config: CGDisplayConfigRef?
guard CGBeginDisplayConfiguration(&config) == .success, let cfg = config else {
    fail(2, "swapDisplays: CGBeginDisplayConfiguration failed")
}
let mainNewX: Int32 = otherOnLeft ? Int32(other0.width) : -Int32(main0.width)
if CGConfigureDisplayOrigin(cfg, other0.id, 0, 0) != .success ||
   CGConfigureDisplayOrigin(cfg, main0.id, mainNewX, Int32(main0.origin.y)) != .success {
    CGCancelDisplayConfiguration(cfg)
    fail(3, "swapDisplays: CGConfigureDisplayOrigin failed")
}
if CGCompleteDisplayConfiguration(cfg, .forSession) != .success {
    fail(4, "swapDisplays: CGCompleteDisplayConfiguration failed")
}

// 4. Post-swap state, in desktop numbers (desktop 1 == new main).
Thread.sleep(forTimeInterval: 0.5)
let post = externalDisplays()
guard post.count == 2 else {
    fail(8, "swapDisplays: display count changed after the swap")
}
let newMain  = post.first { $0.isMain } ?? post[0]
let newLeft  = post.min { $0.origin.x < $1.origin.x }!
let leftDesktop: Int  = newLeft.id == newMain.id ? 1 : 2
let rightDesktop: Int = leftDesktop == 1 ? 2 : 1

func wallpapersNow() -> [String]? {
    guard let cur = osascript("tell application \"System Events\" to get picture of every desktop") else { return nil }
    let c = splitList(cur)
    return c.count == 2 ? c : nil
}

// Position-anchored check: left monitor shows leftWall, right shows rightWall.
func matchesTarget() -> Bool {
    guard let c = wallpapersNow() else { return false }
    let leftNow  = leftDesktop == 1 ? c[0] : c[1]
    let rightNow = leftDesktop == 1 ? c[1] : c[0]
    return leftNow == leftWall && rightNow == rightWall
}

func setBoth() {
    let script = """
    tell application "System Events"
        set picture of desktop \(leftDesktop) to POSIX file "\(appleQuote(leftWall))"
        set picture of desktop \(rightDesktop) to POSIX file "\(appleQuote(rightWall))"
    end tell
    """
    _ = osascript(script)
}

// 5. After the reconfiguration the wallpaper agent re-applies its stored
//    assignments, so the freshly-set pictures can be clobbered for a short
//    window (observed: a few seconds, occasionally longer).  Fight it: read
//    first; while the state is wrong, re-apply the targets and keep going
//    until two consecutive reads 3 s apart both match — i.e. the pictures
//    actually stick.  When the state is already correct this takes ~3 s with
//    no sets at all.
var good = 0
for _ in 0..<90 {
    if matchesTarget() {
        good += 1
        if good >= 2 { break }
    } else {
        good = 0
        setBoth()
    }
    Thread.sleep(forTimeInterval: 3)
}
if good < 2 {
    fail(6, "swapDisplays: displays swapped, but wallpapers did not reach the expected state")
}

print("OK")
