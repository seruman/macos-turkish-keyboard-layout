#!/usr/bin/env swift
import Carbon
import Foundation

let layoutName = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Turkish Q Legacy (Fixed)"

print("Looking for layout: \(layoutName)")

let conditions = [
    kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource
] as CFDictionary

guard let sources = TISCreateInputSourceList(conditions, true)?.takeRetainedValue() as? [TISInputSource] else {
    print("Error: Could not get input source list")
    exit(1)
}

var targetSource: TISInputSource?
for source in sources {
    if let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) {
        let name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
        if name == layoutName {
            targetSource = source
            break
        }
    }
}

guard let source = targetSource else {
    print("Error: Layout '\(layoutName)' not found")
    print("\nAvailable layouts:")
    for source in sources {
        if let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) {
            let name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
            print("  - \(name)")
        }
    }
    exit(1)
}

let enableResult = TISEnableInputSource(source)
if enableResult != noErr {
    print("Warning: TISEnableInputSource returned \(enableResult)")
}

let selectResult = TISSelectInputSource(source)
if selectResult != noErr {
    print("Error: TISSelectInputSource returned \(selectResult)")
    exit(1)
}

print("Successfully enabled and selected: \(layoutName)")
