import AppKit
import AVFoundation
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var keySoundManager = KeySoundManager()
    private var settingsWindow: NSWindow?
    private var eventTap: CFMachPort?
    private var globalKeyDownMonitor: Any?
    private var globalFlagsChangedMonitor: Any?
    private var globalKeyUpMonitor: Any?
    private var accessibilityCheckTimer: Timer?
    // Track currently pressed modifier keys (since they fire flagsChanged, not keyDown)
    private var pressedModifierKeyCodes: Set<Int> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        ensureAccessibilityAndSetupInputMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let eventTap = eventTap {
            CFMachPortInvalidate(eventTap)
        }
        if let monitor = globalKeyDownMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = globalFlagsChangedMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = globalKeyUpMonitor { NSEvent.removeMonitor(monitor) }
        accessibilityCheckTimer?.invalidate()
    }

    // MARK: - Setup Methods

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if let img = NSImage(named: "MenuBarIcon") {
                img.isTemplate = true
                button.image = img
            } else {
                if let custom = NSImage(named: "chocoya-tadadak") {
                    button.image = custom
                } else {
                    button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Chocoya Tadadak")
                }
            }
            button.action = #selector(openSettings)
            button.target = self
        }

        let menu = NSMenu()
        let openItem = NSMenuItem(title: "Open Settings…", action: #selector(openSettings), keyEquivalent: ",")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit Chocoya Tadadak", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    // Setup global key listener via CGEvent tap (requires Accessibility permission)
    private func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        if let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                       place: .headInsertEventTap,
                                       options: .defaultTap,
                                       eventsOfInterest: CGEventMask(eventMask),
                                       callback: { _, type, event, refcon in
                                           let unmanagedSelf = Unmanaged<AppDelegate>.fromOpaque(refcon!).takeUnretainedValue()
                                           switch type {
                                           case .keyDown:
                                               // Play only on first keyDown (not auto-repeat)
                                               let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
                                               if !isRepeat {
                                                   let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
                                                   unmanagedSelf.keySoundManager.play(forKeyCode: keyCode)
                                               }
                                           case .keyUp:
                                               let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
                                               unmanagedSelf.keySoundManager.play(forKeyCode: keyCode)
                                           case .flagsChanged:
                                               // Modifier keys (Shift/Option/Control/Command/CapsLock)
                                               let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
                                               if unmanagedSelf.pressedModifierKeyCodes.contains(keyCode) {
                                                   // Likely a key-up; remove from set
                                                   unmanagedSelf.pressedModifierKeyCodes.remove(keyCode)
                                               } else {
                                                   // Key-down transition; play and record
                                                   unmanagedSelf.pressedModifierKeyCodes.insert(keyCode)
                                                   unmanagedSelf.keySoundManager.play(forKeyCode: keyCode)
                                               }
                                           default:
                                               break
                                           }
                                           return Unmanaged.passUnretained(event)
                                       },
                                       userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())) {
            eventTap = tap
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        } else {
            print("Tadadak: Failed to create event tap; please ensure Accessibility permission is granted.")
        }
    }

    // MARK: - Accessibility & Fallback

    private func ensureAccessibilityAndSetupInputMonitoring() {
        if hasAccessibilityPermission(prompt: true) {
            setupEventTap()
        } else {
            // Temporary fallback so users still get sounds without Accessibility
            setupGlobalMonitorFallback()
            startAccessibilityMonitoring()
        }
    }

    private func hasAccessibilityPermission(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: CFDictionary = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func setupGlobalMonitorFallback() {
        if globalKeyDownMonitor == nil {
            globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] ev in
                guard let self else { return }
                // Play only on first keyDown (ignore auto-repeat)
                if !ev.isARepeat {
                    self.keySoundManager.play(forKeyCode: Int(ev.keyCode))
                }
            }
        }
        if globalFlagsChangedMonitor == nil {
            globalFlagsChangedMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] ev in
                guard let self else { return }
                let keyCode = Int(ev.keyCode)
                if self.pressedModifierKeyCodes.contains(keyCode) {
                    self.pressedModifierKeyCodes.remove(keyCode)
                } else {
                    self.pressedModifierKeyCodes.insert(keyCode)
                    self.keySoundManager.play(forKeyCode: keyCode)
                }
            }
        }
        // Key-Up monitor for fallback
        if globalKeyUpMonitor == nil {
            globalKeyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] ev in
                guard let self else { return }
                self.keySoundManager.play(forKeyCode: Int(ev.keyCode))
            }
        }
    }

    private func tearDownGlobalMonitorFallback() {
        if let monitor = globalKeyDownMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyDownMonitor = nil
        }
        if let monitor = globalFlagsChangedMonitor {
            NSEvent.removeMonitor(monitor)
            globalFlagsChangedMonitor = nil
        }
        if let monitor = globalKeyUpMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyUpMonitor = nil
        }
    }

    private func startAccessibilityMonitoring() {
        accessibilityCheckTimer?.invalidate()
        accessibilityCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.hasAccessibilityPermission(prompt: false) {
                self.accessibilityCheckTimer?.invalidate()
                self.accessibilityCheckTimer = nil
                self.tearDownGlobalMonitorFallback()
                self.setupEventTap()
            }
        }
        RunLoop.main.add(accessibilityCheckTimer!, forMode: .common)
    }

    // MARK: - Actions

    @objc private func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let vc = SettingsViewController(keySoundManager: keySoundManager)
        let window = NSWindow(contentViewController: vc)
        window.title = "Tadadak Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior.insert(.canJoinAllSpaces)
        window.center()
        window.makeKeyAndOrderFront(nil)
        settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
