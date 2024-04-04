//
//  LogReaderViewController.swift
//  ExampleApp
//
//  Created by Sergei Semko on 4/2/24.
//

import UIKit

enum TypeOfLogsFile {
    case logs
    case userDefaultsLogs
    
    var nameOfFile: String {
        switch self {
        case .logs:
            EALogManager.shared.logFileName
        case .userDefaultsLogs:
            EALogManager.shared.logUserDefaultsFileName
        }
    }
}

final class LogReaderViewController: UIViewController {
    
    private let typeOfFile: TypeOfLogsFile
    
    private lazy var textView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = .systemFont(ofSize: 15, weight: .regular)
        return textView
    }()
    
    init(openFile: TypeOfLogsFile) {
        self.typeOfFile = openFile
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        switch typeOfFile {
        case .logs:
            textView.text = EALogManager.shared.readMainLogs()
        case .userDefaultsLogs:
            textView.text = EALogManager.shared.readUserDefaultsLogs()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        DispatchQueue.main.async {
            if !self.textView.text.isEmpty {
                let range = (self.textView.text as NSString).length - 1
                let bottom = NSMakeRange(range, 1)
                
                self.textView.scrollRangeToVisible(bottom)
            }
        }
    }
}

private extension LogReaderViewController {
    func setupLayout() {
        view.backgroundColor = .systemBackground
        view.addSubview(textView)
        
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
}
