//
//  ServerViewController.swift
//  RealmSyncServer
//
//  Created by Dmitry Obukhov on 5/25/16.
//  Copyright © 2016 Realm Inc. All rights reserved.
//

import Cocoa

private struct DefaultValues {
    static let host = "127.0.0.1"
    static let port = 7800
    static let enableAuthentication = true
    static let logLevel: SyncServerLogLevel = .Normal
}

private struct DefaultsKeys {
    static let host = "ServerHost"
    static let port = "ServerPort"
    static let enableAuthentication = "ServerEnableAuthentication"
    static let logLevel = "ServerLogLevel"
}

class ServerViewController: NSViewController {
    
    @IBOutlet weak var hostTextField: NSTextField!
    @IBOutlet weak var portTextField: NSTextField!
    @IBOutlet weak var enableAuthenticationCheckbox: NSButton!
    @IBOutlet weak var logLevelPopUpButton: NSPopUpButton!
    @IBOutlet weak var startStopServerButton: NSButton!
    @IBOutlet weak var resetSyncDataButton: NSButton!
    @IBOutlet var logOutputTextView: NSTextView!
    
    var host: String {
        return NSUserDefaults.standardUserDefaults().stringForKey(DefaultsKeys.host) ?? DefaultValues.host
    }
    
    var port: Int {
        guard let stringValue = NSUserDefaults.standardUserDefaults().stringForKey(DefaultsKeys.port) else {
            return DefaultValues.port
        }
        
        return Int(stringValue) ?? DefaultValues.port
    }
    
    var enableAuthentication: Bool {
        if let value = NSUserDefaults.standardUserDefaults().objectForKey(DefaultsKeys.enableAuthentication) as? Bool {
            return value
        }
        
        return DefaultValues.enableAuthentication
    }
    
    var logLevel: SyncServerLogLevel {
        guard let stringValue = NSUserDefaults.standardUserDefaults().stringForKey(DefaultsKeys.logLevel) , let rawValue = Int(stringValue) else {
            return DefaultValues.logLevel
        }
        
        return SyncServerLogLevel(rawValue: rawValue) ?? DefaultValues.logLevel
    }
    
    let server = SyncServer()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        hostTextField.bind(NSValueBinding, toStandardUserDefaultsKey: DefaultsKeys.host, options: [NSNullPlaceholderBindingOption: DefaultValues.host])
        portTextField.bind(NSValueBinding, toStandardUserDefaultsKey: DefaultsKeys.port, options: [NSNullPlaceholderBindingOption: DefaultValues.port])
        enableAuthenticationCheckbox.bind(NSValueBinding, toStandardUserDefaultsKey: DefaultsKeys.enableAuthentication, options: [NSNullPlaceholderBindingOption: DefaultValues.enableAuthentication])
        logLevelPopUpButton.bind(NSSelectedIndexBinding, toStandardUserDefaultsKey: DefaultsKeys.logLevel, options: [NSNullPlaceholderBindingOption: DefaultValues.logLevel.rawValue])
        
        logOutputTextView.font = NSFont(name: "Menlo", size: 11)
        logOutputTextView.textContainerInset = NSSize(width: 4, height: 6)
        logOutputTextView.delegate = self
        
        server.rootDirectoryURL = NSFileManager.defaultManager().URLForApplicationDataDirectory()
        server.publicKeyURL = NSBundle.mainBundle().URLForResource("public", withExtension: "pem")
        server.delegate = self
        
        updateUI()
    }
    
    private func updateUI() {
        for control in [hostTextField, portTextField, enableAuthenticationCheckbox, logLevelPopUpButton, resetSyncDataButton] {
            control.enabled = !server.running
        }
        
        startStopServerButton.title = server.running ? "Stop server" : "Start server"
    }
    
    private func outputLog(message: String) {
        logOutputTextView.string = logOutputTextView.string?.stringByAppendingString(message)
        logOutputTextView.scrollToEndOfDocument(nil)
    }

}

extension ServerViewController {
    
    @IBAction func startStopServer(sender: AnyObject?) {
        if server.running {
            server.stop()
        } else {
            clearLog()
            
            server.host = host
            server.port = port
            server.enableAuthentication = enableAuthentication
            server.logLevel = logLevel
            
            do {
                try server.start()
            } catch let error as NSError {
                NSAlert(error: error).beginSheetModalForWindow(view.window!, completionHandler: nil)
            }
        }
        
        updateUI()
    }
    
    @IBAction func resetSyncData(sender: AnyObject?) {
        let alert = NSAlert()
        
        alert.messageText = "Reset Sync Data"
        alert.informativeText = "Are you sure you want to delete all Sync Data?"
        alert.addButtonWithTitle("Reset")
        alert.addButtonWithTitle("Cancel")
        
        alert.beginSheetModalForWindow(view.window!) { result in
            if result == NSAlertFirstButtonReturn {
                do {
                    try NSFileManager.defaultManager().removeItemAtURL(NSFileManager.defaultManager().URLForApplicationDataDirectory())
                } catch let error as NSError {
                    NSAlert(error: error).runModal()
                }
            }
        }
    }
    
    @IBAction func clearLog(sender: AnyObject? = nil) {
        logOutputTextView.string = ""
    }
    
}

extension ServerViewController: SyncServerDelegate {
    
    func serverDidStop(server: SyncServer) {
        updateUI()
    }
    
    func serverDidOutputLog(server: SyncServer, message: String) {
        outputLog(message)
    }
    
}

extension ServerViewController: NSTextViewDelegate {
    
    func textView(view: NSTextView, menu: NSMenu, forEvent event: NSEvent, atIndex charIndex: Int) -> NSMenu? {
        menu.insertItem(NSMenuItem.separatorItem(), atIndex: 0)
        menu.insertItem(NSMenuItem(title: "Clear log", action: #selector(clearLog), keyEquivalent: ""), atIndex: 0)
        
        return menu
    }
    
}
