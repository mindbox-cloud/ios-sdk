//
//  LogReaderViewController.swift
//  ExampleApp
//
//  Created by Sergei Semko on 4/2/24.
//

import UIKit

final class LogReaderViewController: UIViewController {
    
    private lazy var textView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = .systemFont(ofSize: 15, weight: .regular)
        return textView
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        textView.text = EALogManager.shared.readLogs()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !textView.text.isEmpty {
            let location = textView.text.count - 1
            let bottom = NSMakeRange(location, 1)
            
            textView.scrollRangeToVisible(bottom)
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
