// Explicitly user-authorized activation of the existing canonical Studio app only.
// swift tools/qa/studio_activate.swift WINDOW_ID
import Foundation
import AppKit
import CoreGraphics

_ = NSApplication.shared
_ = CGMainDisplayID()
guard CommandLine.arguments.count == 2, let id = UInt32(CommandLine.arguments[1]),
      let windows = CGWindowListCopyWindowInfo(.optionAll,kCGNullWindowID) as? [[String:Any]],
      let window = windows.first(where: { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == id
          && ($0[kCGWindowName as String] as? String ?? "").contains("/places/AsurasPath.rbxlx") }),
      let pid = window[kCGWindowOwnerPID as String] as? Int32,
      let app = NSRunningApplication(processIdentifier:pid), app.bundleIdentifier == "com.Roblox.RobloxStudio"
else { fputs("Confirmed canonical Studio window unavailable\n",stderr); exit(1) }
let before = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
let requested = app.activate(options:[])
RunLoop.current.run(until:Date().addingTimeInterval(1))
let after = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
let result:[String:Any] = ["windowID":id,"pid":pid,"requested":requested,"before":before,"after":after,
                          "studioActive":app.isActive]
print(String(data:try JSONSerialization.data(withJSONObject:result,options:[.sortedKeys]),encoding:.utf8)!)
if after != "com.Roblox.RobloxStudio" { exit(2) }
