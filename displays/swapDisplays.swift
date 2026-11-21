#!/usr/bin/env swift
/*
 swapDisplays — true A<->B toggle for the two MAG 274QF X24 displays.

 States (wallpapers + main always follow the VIRTUAL sides):
   A (target):  physical-left MAG  = virtual left,  non-main, "Dunes left.png"
                physical-right MAG = virtual right, main,     "Dunes right.png"
   B (swapped): the virtual sides of the two MAGs are exchanged.
   (An arrangement with the main on the virtual left is also recognized and
    normalized by the same uniform rule.)

 One run: swaps the virtual sides of the two MAGs (the virtual-left display
 moves to (0,0) and becomes main; the virtual-right display moves to
 (-2560,0)), enforces 120Hz on both MAGs, and puts the wallpapers on their
 virtual sides. EVERY other attached display (e.g. an iPad via Sidecar) is
 strictly untouched: no geometry, wallpaper, refresh-rate or main change —
 verified before and after.

 Usage:
   swapDisplays             perform the toggle
   swapDisplays --dry-run   show the plan, change nothing
   swapDisplays --state     show the current state report only
 Exit codes: 0 = success, 1 = aborted or failed (see printed message).
*/

import CoreGraphics
import Darwin
import Foundation

// MARK: - Configuration
let MAG_LEFT_SERIAL  = "CE4H245301931"   // EDID serial of the physical-left MAG
let MAG_RIGHT_SERIAL = "CE4H245301978"   // EDID serial of the physical-right MAG
let MAG_W: Int32 = 2560
let MAG_H: Int32 = 1440
let TARGET_HZ: Double = 120.0
let HOME = NSHomeDirectory()
let LEFT_WP  = HOME + "/Style/Wallpapers/Dunes/Dunes left.png"
let RIGHT_WP = HOME + "/Style/Wallpapers/Dunes/Dunes right.png"
let LOCK_PATH = NSTemporaryDirectory() + "swapDisplays.lock"
// DCP index = unit number - DCP_OFFSET. Serials only feed the report labels
// (which MAG is "physical left"); the toggle logic itself is identity-free.
// If the reported labels ever look mirrored, flip DCP_OFFSET to 2 or swap the
// two serial constants above — nothing else needs to change.
let DCP_OFFSET = 1
let PRE_READ_ATTEMPTS = 8          // pre-read wallpaper retries (settle window)
let PRE_READ_DELAY_S: Double = 3
let FIGHT_ITERS = 12               // post-change stabilization loop
let FIGHT_DELAY_S: Double = 3

// MARK: - Utilities
func die(_ msg: String) -> Never {
    FileHandle.standardError.write(("[swapDisplays] " + msg + "\n").data(using: .utf8)!)
    exit(1)
}

func runCmd(_ args: [String]) -> (out: String, ok: Bool)? {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: args[0])
    p.arguments = Array(args.dropFirst())
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { return nil }
    // Drain the pipe BEFORE waiting — ioreg emits >2MB and a full pipe buffer
    // would deadlock the child (write) and us (wait) otherwise.
    let outData = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    // Lossy: ioreg output contains raw binary bytes that are not valid UTF-8.
    let out = String(decoding: outData, as: UTF8.self)
    return (out, p.terminationStatus == 0)
}

/// AppleScript wallpaper list, one entry per active display ("desktop").
func wallpaperList() -> [String]? {
    guard let r = runCmd(["/usr/bin/osascript", "-e",
                          "tell application \"System Events\" to get picture of every desktop"]),
          r.ok else { return nil }
    let items = r.out.split(separator: ",").map {
        $0.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return items.isEmpty ? nil : items
}

func setDesktopPicture(_ index1Based: Int, _ path: String) -> Bool {
    let script = "tell application \"System Events\" to set picture of desktop \(index1Based) to \"\(path)\""
    guard let r = runCmd(["/usr/bin/osascript", "-e", script]) else { return false }
    return r.ok
}

// MARK: - IORegistry: DCP index -> (EDID serial, product name) (read fresh every run)
/// Parse `"Key" = "value"` or `"Key"="value"` (also plain numeric) from one ioreg line.
func parseProp(_ s: String, key: String) -> String? {
    guard let kr = s.range(of: "\"\(key)\"") else { return nil }
    var rest = s[kr.upperBound...]
    while let f = rest.first, f == " " || f == "\t" { rest = rest.dropFirst() }
    guard let eq = rest.firstIndex(of: "=") else { return nil }
    rest = rest[rest.index(after: eq)...]
    while let f = rest.first, f == " " || f == "\t" { rest = rest.dropFirst() }
    if rest.first == "\"" {
        rest = rest.dropFirst()
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[..<end])
    }
    let v = rest.prefix(while: { $0.isNumber })
    return v.isEmpty ? nil : String(v)
}

func dcpToInfo() -> [Int: (serial: String?, product: String?)] {
    guard let r = runCmd(["/usr/sbin/ioreg", "-l", "-w0", "-p", "IOService"]), r.ok else { return [:] }
    let lines = r.out.components(separatedBy: "\n")
    var map: [Int: (String?, String?)] = [:]
    for (i, line) in lines.enumerated() {
        guard let d = parseProp(line, key: "DCPIndex").flatMap(Int.init) else { continue }
        var serial: String? = nil, product: String? = nil
        let lo = max(0, i - 30), hi = min(lines.count - 1, i + 30)
        for j in lo...hi {
            let l = lines[j]
            if serial == nil, let s = parseProp(l, key: "AlphanumericSerialNumber") { serial = s }
            if product == nil, let pn = parseProp(l, key: "ProductName") { product = pn }
        }
        map[d] = (serial, product)
    }
    return map
}

// MARK: - Display snapshot
struct Disp {
    let id: CGDirectDisplayID
    var main: Bool
    var x: Int32
    var y: Int32
    var w: Int32
    var h: Int32
    var unit: Int
    var hz: Double
    var name: String
    var serial: String?
    var isMag: Bool
    var isBuiltin: Bool
    var magLabel: String {
        if serial == MAG_LEFT_SERIAL { return "MAG physical left (\(MAG_LEFT_SERIAL.suffix(3)))" }
        if serial == MAG_RIGHT_SERIAL { return "MAG physical right (\(MAG_RIGHT_SERIAL.suffix(3)))" }
        return isMag ? "MAG (unknown serial)" : "other — untouched"
    }
}

func snapshotDisplays() -> [Disp] {
    var n: UInt32 = 0
    CGGetActiveDisplayList(0, nil, &n)
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(n))
    CGGetActiveDisplayList(n, &ids, &n)
    return ids.map { id in
        let b = CGDisplayBounds(id)
        return Disp(id: id,
                    main: CGDisplayIsMain(id) == 1,
                    x: Int32(b.origin.x), y: Int32(b.origin.y),
                    w: Int32(b.size.width), h: Int32(b.size.height),
                    unit: Int(CGDisplayUnitNumber(id)),
                    hz: CGDisplayCopyDisplayMode(id).map { $0.refreshRate } ?? 0,
                    name: "?",
                    serial: nil, isMag: false,
                    isBuiltin: CGDisplayIsBuiltin(id) == 1)
    }
}

// MARK: - Slot ordering candidates for "get picture of every desktop"
/// The legacy list order is a function of geometry. Measured on this setup:
/// bottom-most display first, then left-to-right (y descending, x ascending).
/// Every run re-validates the chosen rule against the wallpaper invariant.
enum SlotOrder: Int, CaseIterable {
    case yDescXAsc, xAscYDesc, mainFirstThenYDescXAsc, idAsc, idDesc

    func apply(_ ds: [Disp]) -> [Disp] {
        switch self {
        case .yDescXAsc:
            return ds.sorted { a, b in a.y == b.y ? a.x < b.x : a.y > b.y }
        case .xAscYDesc:
            return ds.sorted { a, b in a.x == b.x ? a.y > b.y : a.x < b.x }
        case .mainFirstThenYDescXAsc:
            return ds.sorted { a, b in
                if a.main != b.main { return b.main }
                return a.y == b.y ? a.x < b.x : a.y > b.y
            }
        case .idAsc:  return ds.sorted { $0.id < $1.id }
        case .idDesc: return ds.sorted { $0.id > $1.id }
        }
    }
}

// MARK: - Classification (MAGs by live EDID serial)
func classify(_ all: [Disp], dcpInfo: [Int: (serial: String?, product: String?)]) -> [Disp] {
    var out: [Disp] = []
    for var d in all {
        let dcp = d.unit - DCP_OFFSET
        if let info = dcpInfo[dcp] {
            d.serial = info.serial
            if let pn = info.product { d.name = pn }
        }
        d.isMag = (d.serial == MAG_LEFT_SERIAL || d.serial == MAG_RIGHT_SERIAL)
        out.append(d)
    }
    return out
}

// MARK: - State model
/// Uniform rule: virtual-left MAG -> (0,0) + main; virtual-right MAG -> (-2560,0).
struct Plan {
    var letterBefore: Character   // "A" or "B" (which side the physical-left MAG is on)
    var mainOnLeft: Bool          // main on the virtual left (C layout, normalized)
    var toOrigin: Disp            // moves to (0,0), becomes main
    var toLeft: Disp              // moves to (-2560,0)
    var stateBeforeText: String {
        var s = letterBefore == "A" ? "A (your target)" : "B (swapped)"
        if mainOnLeft { s += "  [main on virtual left — will be normalized]" }
        return s
    }
    var letterAfter: Character { letterBefore == "A" ? "B" : "A" }
    var stateAfterText: String { letterAfter == "A" ? "A (your target)" : "B (swapped)" }
}

func makePlan(_ ds: [Disp]) -> Plan? {
    let mags = ds.filter { $0.isMag }
    guard mags.count == 2 else { return nil }
    guard mags.allSatisfy({ $0.w == MAG_W && $0.h == MAG_H && $0.y == 0 }) else { return nil }
    let xs = Set(mags.map { $0.x })
    guard xs == Set([-MAG_W, 0]) || xs == Set([0, MAG_W]) else { return nil }
    guard let mainD = ds.first(where: { $0.main }), mainD.isMag else { return nil }
    let vl = mags.min(by: { $0.x < $1.x })!   // virtual-left MAG
    let vr = mags.max(by: { $0.x < $1.x })!   // virtual-right MAG
    let letter: Character = (vl.serial == MAG_LEFT_SERIAL) ? "A" : "B"
    return Plan(letterBefore: letter, mainOnLeft: mainD.id == vl.id, toOrigin: vl, toLeft: vr)
}

// MARK: - Slot-order validation (the wallpaper invariant)
/// In any canonical state, left.png is on the virtual-left MAG and right.png on
/// the virtual-right MAG. Pick the first ordering rule consistent with that.
func acceptOrder(_ list: [String], _ ds: [Disp]) -> SlotOrder? {
    let mags = ds.filter { $0.isMag }
    guard mags.count == 2, ds.count == list.count else { return nil }
    let vl = mags.min(by: { $0.x < $1.x })!
    let vr = mags.max(by: { $0.x < $1.x })!
    for rule in SlotOrder.allCases {
        let ordered = rule.apply(ds)
        guard ordered.count == list.count else { continue }
        func wp(_ d: Disp) -> String? {
            ordered.firstIndex(where: { $0.id == d.id }).map { list[$0] }
        }
        if wp(vl) == LEFT_WP && wp(vr) == RIGHT_WP { return rule }
    }
    return nil
}

func wpOf(_ d: Disp, in rule: SlotOrder, list: [String], ds: [Disp]) -> String? {
    let ordered = rule.apply(ds)
    guard let i = ordered.firstIndex(where: { $0.id == d.id }), i < list.count else { return nil }
    return list[i]
}

// MARK: - CG geometry (transactional, as proven in earlier versions)
func pickMode(_ id: CGDirectDisplayID, curHz: Double) -> (mode: CGDisplayMode, needChange: Bool, note: String) {
    let cur = CGDisplayCopyDisplayMode(id)!
    if abs(curHz - TARGET_HZ) < 0.25 { return (cur, false, "already \(String(format: "%.1f", curHz))Hz — no change") }
    if let arr = CGDisplayCopyAllDisplayModes(id, nil) {
        for i in 0..<CFArrayGetCount(arr) {
            let m = Unmanaged<CGDisplayMode>.fromOpaque(CFArrayGetValueAtIndex(arr, i)).takeUnretainedValue()
            let mw = Int(m.pixelWidth), mh = Int(m.pixelHeight)
            if mw == Int(MAG_W), mh == Int(MAG_H), abs(m.refreshRate - TARGET_HZ) < 0.25 {
                return (m, true, "\(String(format: "%.1f", curHz))Hz -> \(String(format: "%.1f", TARGET_HZ))Hz")
            }
        }
    }
    return (cur, false, "WARNING: no \(String(format: "%.1f", TARGET_HZ))Hz mode found; keeping \(String(format: "%.1f", curHz))Hz")
}

func flipGeometry(_ plan: Plan,
                  modeOrigin: CGDisplayMode, hzOrigin: Bool,
                  modeLeft: CGDisplayMode, hzLeft: Bool) -> Bool {
    var config: CGDisplayConfigRef?
    guard CGBeginDisplayConfiguration(&config) == .success, let c = config else { return false }
    var ok = true
    if hzOrigin, CGConfigureDisplayWithDisplayMode(c, plan.toOrigin.id, modeOrigin, nil) != .success { ok = false }
    if hzLeft, CGConfigureDisplayWithDisplayMode(c, plan.toLeft.id, modeLeft, nil) != .success { ok = false }
    if ok, CGConfigureDisplayOrigin(c, plan.toOrigin.id, 0, 0) != .success { ok = false }
    if ok, CGConfigureDisplayOrigin(c, plan.toLeft.id, -MAG_W, 0) != .success { ok = false }
    let result: CGError = ok ? CGCompleteDisplayConfiguration(c, .forSession)
                             : CGCancelDisplayConfiguration(c)
    return ok && result == .success
}

// MARK: - Report helpers
func reportLine(_ d: Disp, wp: String?) -> String {
    let mainStr = d.main ? "main" : "non-main"
    let wpStr = wp.map { (($0 as NSString).lastPathComponent) } ?? "?"
    let hzStr = String(format: "%.1fHz", d.hz)
    let label = (d.magLabel + " (" + d.name + ")").padding(toLength: 56, withPad: " ", startingAt: 0)
    return "  id=\(d.id)  \(label) pos=(\(d.x), \(d.y))  " +
           mainStr.padding(toLength: 8, withPad: " ", startingAt: 0) +
           "  " + hzStr.padding(toLength: 7, withPad: " ", startingAt: 0) +
           "  wp=\(wpStr)"
}

// MARK: - Main
let args = Array(CommandLine.arguments.dropFirst())
let dryRun = args.contains("--dry-run")
let stateOnly = args.contains("--state")

// Lock: refuse to run concurrently (two simultaneous runs fought before).
let lockFD = open(LOCK_PATH, O_CREAT | O_RDWR, 0o644)
if lockFD < 0 { die("cannot open lock file") }
if flock(lockFD, LOCK_EX | LOCK_NB) != 0 {
    die("another swapDisplays is already running — aborting to avoid a fight")
}

// 1. Classify.
let dcpInfo = dcpToInfo()
var all = classify(snapshotDisplays(), dcpInfo: dcpInfo)
let mags = all.filter { $0.isMag }
guard Set(mags.map { $0.serial! }) == Set([MAG_LEFT_SERIAL, MAG_RIGHT_SERIAL]), mags.count == 2 else {
    die("expected exactly the two MAG serials (\(MAG_LEFT_SERIAL), \(MAG_RIGHT_SERIAL)); " +
        "found: " + all.compactMap { $0.serial }.joined(separator: ", ") +
        " — is a display unplugged or misdetected? No changes made.")
}
if let mainD = all.first(where: { $0.main }), !mainD.isMag {
    die("the main display is \"\(mainD.name)\" (id \(mainD.id)) — not one of the MAGs. " +
        "This script never runs with the main display on another screen. No changes made.")
}

if stateOnly {
    let list = wallpaperList() ?? []
    let rule = acceptOrder(list, all)
    var perId: [CGDirectDisplayID: String] = [:]
    if let rule { for (i, d) in rule.apply(all).enumerated() where i < list.count { perId[d.id] = list[i] } }
    print("== swapDisplays: current state ==")
    for d in all { print(reportLine(d, wp: perId[d.id])) }
    print("slot order: " + (rule.map { String(describing: $0) } ??
          "not validated (wallpapers not in the canonical arrangement)"))
    exit(0)
}

// 2. Plan (all guards below abort BEFORE any change).
guard let plan = makePlan(all) else {
    die("MAG layout is not the expected horizontal arrangement (both 2560x1440 at y=0, adjacent, " +
        "one at the origin) — check System Settings > Displays (mirroring? odd position? resolution?) " +
        "and try again. No changes made.")
}
let others = all.filter { !$0.isMag }

// 3. Pre-read wallpapers; validate slot order against the invariant.
var list: [String]? = nil
var rule: SlotOrder? = nil
for attempt in 1...PRE_READ_ATTEMPTS {
    if let l = wallpaperList(), let r = acceptOrder(l, all) {
        list = l; rule = r; break
    }
    if attempt < PRE_READ_ATTEMPTS {
        print("[swapDisplays] waiting for wallpaper state to settle (attempt \(attempt)/\(PRE_READ_ATTEMPTS))…")
        Thread.sleep(forTimeInterval: PRE_READ_DELAY_S)
    }
}
guard let list = list, let rule = rule else {
    die("wallpaper state is not the canonical arrangement (left.png on the virtual-left MAG, " +
        "right.png on the virtual-right MAG) and could not be recognized. Set the two wallpapers " +
        "manually in System Settings, wait a few seconds, then run again. No changes made.")
}

// Pre-run per-display wallpapers + other displays' bounds (for verification).
let orderedBefore = rule.apply(all)
var wpBefore: [CGDirectDisplayID: String] = [:]
for (i, d) in orderedBefore.enumerated() where i < list.count { wpBefore[d.id] = list[i] }
var boundsBefore: [CGDirectDisplayID: (Int32, Int32)] = [:]
for d in others { boundsBefore[d.id] = (d.x, d.y) }

// 4. Print the plan.
let (modeA, hzChangeA, noteA) = pickMode(plan.toOrigin.id, curHz: plan.toOrigin.hz)
let (modeB, hzChangeB, noteB) = pickMode(plan.toLeft.id, curHz: plan.toLeft.hz)
print("== swapDisplays ==")
print("state before: " + plan.stateBeforeText)
for d in all { print(reportLine(d, wp: wpBefore[d.id])) }
print("plan:")
print("  geometry : id \(plan.toOrigin.id) -> (0, 0) [becomes main] ; id \(plan.toLeft.id) -> (-2560, 0)")
print("  refresh  : id \(plan.toOrigin.id): " + noteA)
print("  refresh  : id \(plan.toLeft.id): " + noteB)

// Post-flip slot plan (same rule, evaluated on the post-flip geometry).
var post = all
for i in post.indices where post[i].id == plan.toOrigin.id { post[i].x = 0; post[i].y = 0; post[i].main = true }
for i in post.indices where post[i].id == plan.toLeft.id { post[i].x = -MAG_W; post[i].y = 0; post[i].main = false }
let orderedAfter = rule.apply(post)
var slotPlan: [(index: Int, id: CGDirectDisplayID, target: String)] = []
for (i, d) in orderedAfter.enumerated() where d.isMag {
    let target = (d.x == 0 && d.y == 0) ? RIGHT_WP : LEFT_WP
    slotPlan.append((i + 1, d.id, target))
    print("  wallpaper: desktop \(i + 1) (id \(d.id), post-flip \((d.x == 0 ? "virtual right" : "virtual left"))) <- \((target as NSString).lastPathComponent)")
}
for (i, d) in orderedAfter.enumerated() where !d.isMag {
    print("  wallpaper: desktop \(i + 1) (id \(d.id), \(d.name)) — untouched")
}
print("toggle: " + String(plan.letterBefore) + " -> " + String(plan.letterAfter))

if dryRun {
    print("dry run — nothing changed.")
    exit(0)
}

// 5. Apply geometry (+ refresh) atomically.
guard flipGeometry(plan, modeOrigin: modeA, hzOrigin: hzChangeA,
                   modeLeft: modeB, hzLeft: hzChangeB) else {
    die("display reconfiguration failed and was cancelled — no changes made. Run again after a moment.")
}
Thread.sleep(forTimeInterval: 1.5)
all = classify(snapshotDisplays(), dcpInfo: dcpInfo)
guard let v1 = all.first(where: { $0.id == plan.toOrigin.id }),
      let v2 = all.first(where: { $0.id == plan.toLeft.id }) else {
    die("displays disappeared after the geometry change — aborting, check the connections.")
}
guard v1.x == 0, v1.y == 0, v1.main, v2.x == -MAG_W, v2.y == 0, !v2.main else {
    die("geometry did not land as planned (id \(v1.id) at (\(v1.x),\(v1.y)) main=\(v1.main); " +
        "id \(v2.id) at (\(v2.x),\(v2.y)) main=\(v2.main)). Run again to try restoring.")
}

// 6. Apply wallpapers (MAG slots only), then fight the wallpaper agent.
for s in slotPlan where !setDesktopPicture(s.index, s.target) {
    print("[swapDisplays] WARNING: setting desktop \(s.index) to \((s.target as NSString).lastPathComponent) did not report success")
}

var stabilized = false
var lastList: [String]? = nil
for _ in 0..<FIGHT_ITERS {
    Thread.sleep(forTimeInterval: FIGHT_DELAY_S)
    guard let l = wallpaperList(), l.count == all.count else { continue }
    lastList = l
    let ds = classify(snapshotDisplays(), dcpInfo: dcpInfo)
    let ordered = rule.apply(ds)
    var ok = true
    for (i, d) in ordered.enumerated() where i < l.count {
        let w = l[i]
        if d.isMag {
            let target = (d.x == 0 && d.y == 0) ? RIGHT_WP : LEFT_WP
            if w != target {
                ok = false
                _ = setDesktopPicture(i + 1, target)
            }
        } else if let pre = wpBefore[d.id], w != pre {
            // Defensive: an other display's wallpaper changed — restore it.
            ok = false
            _ = setDesktopPicture(i + 1, pre)
        }
    }
    if ok { stabilized = true; break }
}
guard stabilized else {
    let secs = Int(Double(FIGHT_ITERS) * FIGHT_DELAY_S)
    let cur = (lastList ?? []).joined(separator: " | ")
    die("wallpapers did not stabilize within \(secs)s. Current list: \(cur). " +
        "Geometry is already swapped; check the displays and run again.")
}

// 7. Final verification.
all = classify(snapshotDisplays(), dcpInfo: dcpInfo)
let finalList = wallpaperList() ?? []
var problems: [String] = []
for d in all where d.isMag {
    let w = wpOf(d, in: rule, list: finalList, ds: all)
    if d.x == 0, d.y == 0 {
        if !d.main { problems.append("id \(d.id): at (0,0) but not main") }
        if let w, w != RIGHT_WP { problems.append("id \(d.id): wallpaper is \(w), expected \(RIGHT_WP)") }
    } else if d.x == -MAG_W, d.y == 0 {
        if d.main { problems.append("id \(d.id): at (-2560,0) but is main") }
        if let w, w != LEFT_WP { problems.append("id \(d.id): wallpaper is \(w), expected \(LEFT_WP)") }
    } else {
        problems.append("id \(d.id): at unexpected position (\(d.x),\(d.y))")
    }
    if abs(d.hz - TARGET_HZ) > 0.5 && (d.id == plan.toOrigin.id ? hzChangeA : hzChangeB) {
        problems.append("id \(d.id): refresh is \(String(format: "%.1f", d.hz))Hz, expected \(String(format: "%.1f", TARGET_HZ))Hz")
    }
}
for d in all where !d.isMag {
    if let pre = boundsBefore[d.id], (d.x, d.y) != pre {
        problems.append("id \(d.id) (\(d.name)): position changed to (\(d.x),\(d.y)) — expected untouched at (\(pre.0),\(pre.1))")
    }
    if let preW = wpBefore[d.id], let w = wpOf(d, in: rule, list: finalList, ds: all), w != preW {
        problems.append("id \(d.id) (\(d.name)): wallpaper changed to \(w) — expected untouched (\(preW))")
    }
}

print("state after: " + plan.stateAfterText)
for d in all { print(reportLine(d, wp: wpOf(d, in: rule, list: finalList, ds: all))) }
let otherProblems = problems.filter { $0.contains("untouched") || $0.contains("changed to") }
print("other displays (\(others.count)): " + (otherProblems.isEmpty ? "untouched (geometry + wallpaper verified)" : "CHECK PROBLEMS BELOW"))

if problems.isEmpty {
    print("OK: toggled " + String(plan.letterBefore) + " -> " + String(plan.letterAfter) + "." +
          ((!hzChangeA && noteA.contains("WARNING")) || (!hzChangeB && noteB.contains("WARNING")) ?
              "  [WARNING: see refresh notes above]" : ""))
    exit(0)
} else {
    die("verification problems:\n  " + problems.joined(separator: "\n  ") +
        "\nCheck the displays; run again to try restoring.")
}
