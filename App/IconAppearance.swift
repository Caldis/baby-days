import SwiftUI
#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
enum IconAppearance {
    private static var applying = false
    static func apply(_ zodiac: Zodiac, completion: @escaping (String?) -> Void) {
        #if os(iOS) || os(tvOS)
        #if os(tvOS)
        let name: String? = zodiac == .snake ? nil : "ZodiacTV-\(zodiac.rawValue)"
        #else
        let name: String? = zodiac == .snake ? nil : zodiac.iconName
        #endif
        guard UIApplication.shared.alternateIconName != name, !applying else { return }
        guard UIApplication.shared.supportsAlternateIcons else {
            completion("当前设备不支持更换图标, 可在真机上重试")
            return
        }
        applying = true
        UIApplication.shared.setAlternateIconName(name) { error in
            DispatchQueue.main.async {
                applying = false
                completion(error.map { "系统未能更换图标, 请稍后重试: \($0.localizedDescription)" })
                // A newer selection may arrive while the system is still applying the previous one
                let latest = BabyProfile.load().iconZodiac
                if error == nil && latest != zodiac { apply(latest, completion: completion) }
            }
        }
        #elseif os(macOS)
        guard zodiac != .snake else { NSApplication.shared.applicationIconImage = nil; return }
        guard let source = NSImage(named: "IconPreview-\(zodiac.rawValue)") else { return }
        let image = NSImage(size: NSSize(width: 1024, height: 1024))
        image.lockFocus()
        NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 1024, height: 1024), xRadius: 225, yRadius: 225).addClip()
        source.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024))
        image.unlockFocus()
        NSApplication.shared.applicationIconImage = image
        #endif
    }
}
