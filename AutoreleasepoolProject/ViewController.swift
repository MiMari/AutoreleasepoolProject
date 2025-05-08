import UIKit
import Foundation

enum SegmentControlRelease: Int, CaseIterable {
    case autorelease
    case noAutorelease
    
    var name: String {
        switch self {
        case .autorelease:
            return "With autorelease"
        case .noAutorelease:
            return "Without autorelease"
        }
    }
}

enum WorkType: Int, CaseIterable {
    case image = 0
    case json
    case dateFormatter
    
    var name: String {
        switch self {
        case .image:
            return "Image"
        case .json:
            return "JSON"
        case .dateFormatter:
            return "DateFormatter"
        }
    }
}

enum SegmentControlSelection: Int, CaseIterable {
    case customThread = 0
    case mainThread
    case task
    case customQueue = 3
    
    static var allThreadCases: [SegmentControlSelection] {
        return [.customThread, .mainThread]
    }
    
    var name: String {
        switch self {
        case .customThread:
            return "Custom Thread"
        case .customQueue:
            return "Custom Queue"
        case .mainThread:
            return "Main Thread"
        case .task:
            return "Task"
        }
    }
}

enum QueueType: Int, CaseIterable {
    case serial
    case serialWorkItem
    case serialNever
    case concurrent
    case concurrentWorkItem
    case concurrentNever
    case globalQueue
    case main
    
    var name: String {
        switch self {
        case .serial:
            return "serial"
        case .serialWorkItem:
            return "SWI"
        case .serialNever:
            return "SN"
        case .concurrent:
            return "conc"
        case .concurrentWorkItem:
            return "CWI"
        case .concurrentNever:
            return "CN"
        case .main:
            return "main"
        case .globalQueue:
            return "global"
        }
    }
    
}

class ViewController: UIViewController {
    
    let serial = DispatchQueue(label: "serial", qos: .userInteractive)
    let serialWorkItem = DispatchQueue(label: "serialWorkItem", qos: .userInteractive, autoreleaseFrequency: .workItem)
    let serialNever = DispatchQueue(label: "serialNever", qos: .userInteractive, autoreleaseFrequency: .never)
    let concurrent = DispatchQueue(label: "concurrent", qos: .userInteractive, attributes: .concurrent)
    let concurrentWorkItem = DispatchQueue(label: "concurrentWorkItem", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .workItem)
    let concurrentNever = DispatchQueue(label: "concurrentNever", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .never)
    
    var backgroundThread: Thread?
    
    let threadSegmentControl: UISegmentedControl = {
        let segmentControl = UISegmentedControl(items: SegmentControlSelection.allCases.map(\.name))
        segmentControl.selectedSegmentIndex = 3
        return segmentControl
    }()
    
    let workTypeSegmentControl: UISegmentedControl = {
        let segmentControl = UISegmentedControl(items: WorkType.allCases.map(\.name))
        segmentControl.selectedSegmentIndex = 0
        return segmentControl
    }()
    
    let releaseTypeSegmentControl: UISegmentedControl = {
        let segmentControl = UISegmentedControl(items: SegmentControlRelease.allCases.map(\.name))
        segmentControl.selectedSegmentIndex = 0
        return segmentControl
    }()
    
    let queueTypesSegmentControl: UISegmentedControl = {
        let segmentControl = UISegmentedControl(items: QueueType.allCases.map(\.name))
        segmentControl.selectedSegmentIndex = 0
        return segmentControl
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addSubviews()
        
        //        addObserverToRunloop(runloop: RunLoop.main)
    }
    
    
    // MARK: Observer for Runloop
    private func addObserverToRunloop(runloop: RunLoop) {
        let observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, CFRunLoopActivity.allActivities.rawValue, true, 0) { observer, activity  in
            
            let mode = runloop.currentMode?.rawValue ?? "Unknown Mode"
            switch activity {
            case .entry:
                print("")
                print("✨Entry✨", mode)
            case .afterWaiting:
                print("☀️afterWaiting", mode)
            case .beforeTimers:
                print("-------------------")
                print("⏰beforeTimers", mode)
            case .beforeSources:
                print("🏋🏻‍♀️beforeSources", mode)
            case .beforeWaiting:
                print("💤beforeWaiting", mode)
            case .exit:
                print("✅exit✅", mode)
            default:
                break
            }
        }
        CFRunLoopAddObserver(runloop.getCFRunLoop(), observer, .commonModes)
    }
    
    func createDummyJSONFiles(count: Int, sizeInKB: Int) -> [URL] {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("JSONTest", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        var urls: [URL] = []
        
        let string = String(repeating: "randomString", count: sizeInKB * 128) // ~1KB
        let jsonDict = ["key": string]
        
        for i in 0..<count {
            let url = directory.appendingPathComponent("file\(i).json")
            let data = try! JSONSerialization.data(withJSONObject: jsonDict)
            try! data.write(to: url)
            urls.append(url)
        }
        
        return urls
    }
    
    private func addSubviews() {

        // MARK: Stack with segment controls
        
        let stack = UIStackView(arrangedSubviews: [workTypeSegmentControl,
                                                   queueTypesSegmentControl,
                                                   threadSegmentControl,
                                                   releaseTypeSegmentControl])
        stack.axis = .vertical
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.spacing = 20
        view.addSubview(stack)
        
        stack.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20).isActive = true
        stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20).isActive = true
        stack.heightAnchor.constraint(equalToConstant: 200).isActive = true
        
        // MARK: Button
        
        var configuration = UIButton.customConfigurationButton
        configuration.title = "Run"
        
        let button = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in
            guard
                let self = self,
                let value = SegmentControlSelection(rawValue: self.threadSegmentControl.selectedSegmentIndex),
                let releaseType = SegmentControlRelease(rawValue: self.releaseTypeSegmentControl.selectedSegmentIndex),
                let workType = WorkType(rawValue: self.workTypeSegmentControl.selectedSegmentIndex),
                let queueType = QueueType(rawValue: queueTypesSegmentControl.selectedSegmentIndex)
            else { return }
            
            let files = createDummyJSONFiles(count: 2, sizeInKB: 5)
            
            let insideAction: @Sendable () -> Void
            switch workType {
            case .dateFormatter:
                insideAction = {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    
                    let dateString = "2023-12-31 23:59:59"
                    
                    let date = formatter.date(from: dateString)
                    _ = date
                }
            case .image:
                insideAction = {
                    let image = UIImage(named: "123")
                    _ = image
                }
                
            case .json:
                insideAction = {
                    let data = try! Data(contentsOf: files.first!)
                    let json = try! JSONSerialization.jsonObject(with: data)
                    _ = json
                    
                }
            }
            
            let action: @Sendable () -> Void
            switch releaseType {
            case .autorelease:
                action = {
                    print("🌊 Run autorelease")
                    for _ in 0 ..< 10 {
                        
                        autoreleasepool {
                            
                            for _ in 0 ..< 1_000 {
                                insideAction()
                            }
                        }
                    }
                    Thread.sleep(forTimeInterval: 5)
                    print("🌊 Finish autorelease")
                }
            case .noAutorelease:
                action = {
                    print("🚫🌊 Run no autorelease")
                    for _ in 0 ..< 10 {
                        for _ in 0 ..< 1_000 {
                            insideAction()
                        }
                    }
                    Thread.sleep(forTimeInterval: 5)
                    print("🚫🌊 Finish no autorelease")
                }
            }
            
            switch value {
        
            case .customQueue:
                let queue: DispatchQueue
                switch queueType {
                case .serial:
                    queue = serial
                case .serialWorkItem:
                    queue = serialWorkItem
                case .serialNever:
                    queue = serialNever
                case .concurrent:
                    queue = concurrent
                case .concurrentWorkItem:
                    queue = concurrentWorkItem
                case .concurrentNever:
                    queue = concurrentNever
                case .main:
                    queue = DispatchQueue.main
                case .globalQueue:
                    queue = DispatchQueue.global(qos: .default)
                }
                
                queue.async {
                    print("WorkItem 1", Thread.current)
                    action()
                }
                queue.async {
                    print("WorkItem 2", Thread.current)
                    action()
                }
                
            case .customThread:
                Thread {
                    print("Run task on custom thread")
                    action()
                    action()
                }.start()
            case .mainThread:
                print("Run task on main thread")
                action()
                action()
            case .task:
                Task {
                    action()
                    action()
                }
            }
            
        })
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        
        button.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 100).isActive = true
        button.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
    }
}

extension UIButton {
    
    static var customConfigurationButton: UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.buttonSize = .large
        configuration.baseForegroundColor = .white
        configuration.baseBackgroundColor = #colorLiteral(red: 0.5390238762, green: 0.5196551681, blue: 1, alpha: 1)
        
        return configuration
    }
}
