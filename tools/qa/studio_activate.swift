// Explicitly user-authorized activation of the existing canonical Studio app only.
// swift tools/qa/studio_activate.swift WINDOW_ID | --list (read-only project window bounds)
import Foundation
import AppKit
import CoreGraphics

_ = NSApplication.shared
_ = CGMainDisplayID()
let projectRoot = FileManager.default.currentDirectoryPath
if CommandLine.arguments.count == 2 && CommandLine.arguments[1] == "--list" {
    let windows = CGWindowListCopyWindowInfo(.optionAll,kCGNullWindowID) as? [[String:Any]] ?? []
    let rows:[[String:Any]] = windows.compactMap { w in
        guard let title = w[kCGWindowName as String] as? String, title.contains(projectRoot + "/"),
              title.contains(".rbxlx"), let pid = w[kCGWindowOwnerPID as String] as? Int32,
              NSRunningApplication(processIdentifier:pid)?.bundleIdentifier == "com.Roblox.RobloxStudio"
        else { return nil }
        return ["windowID":w[kCGWindowNumber as String] ?? 0,"title":title,
                "bounds":w[kCGWindowBounds as String] ?? [:]]
    }
    print(String(data:try JSONSerialization.data(withJSONObject:rows,options:[.sortedKeys]),encoding:.utf8)!)
    exit(0)
}
guard CommandLine.arguments.count == 2, let id = UInt32(CommandLine.arguments[1]),
      let windows = CGWindowListCopyWindowInfo(.optionAll,kCGNullWindowID) as? [[String:Any]],
      let window = windows.first(where: { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == id
          && ($0[kCGWindowName as String] as? String ?? "").contains(projectRoot + "/places/AsurasPath.rbxlx") }),
      let pid = window[kCGWindowOwnerPID as String] as? Int32,
      let app = NSRunningApplication(processIdentifier:pid), app.bundleIdentifier == "com.Roblox.RobloxStudio"
else { fputs("Confirmed canonical Studio window unavailable\n",stderr); exit(1) }
let before = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
let requested = app.activate(options:[.activateAllWindows])
RunLoop.current.run(until:Date().addingTimeInterval(1))
let after = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
let result:[String:Any] = ["windowID":id,"pid":pid,"requested":requested,"before":before,"after":after,
                          "studioActive":app.isActive]
print(String(data:try JSONSerialization.data(withJSONObject:result,options:[.sortedKeys]),encoding:.utf8)!)
if after != "com.Roblox.RobloxStudio" { exit(2) }
