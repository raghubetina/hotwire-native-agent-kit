// Adapted from the Hotwire Native iOS demo.
// Copyright (c) 2024 Hotwire. MIT licensed; see LICENSES.md.
import HotwireNative
import UIKit

final class FormComponent: BridgeComponent {
    override nonisolated class var name: String { "form" }

    private weak var submitItem: UIBarButtonItem?
    private var viewController: UIViewController? {
        delegate?.destination as? UIViewController
    }

    override func onReceive(message: Message) {
        guard let event = Event(rawValue: message.event) else { return }

        switch event {
        case .connect:
            connect(message)
        case .submitEnabled:
            submitItem?.isEnabled = true
        case .submitDisabled:
            submitItem?.isEnabled = false
        case .disconnect:
            removeOwnedButton()
        }
    }

    private func connect(_ message: Message) {
        guard let data: MessageData = message.data(), let viewController else { return }

        removeOwnedButton()
        let action = UIAction { [weak self] _ in
            self?.reply(to: Event.connect.rawValue)
        }
        let item = UIBarButtonItem(title: data.submitTitle, primaryAction: action)
        viewController.navigationItem.rightBarButtonItem = item
        submitItem = item
    }

    private func removeOwnedButton() {
        guard let submitItem else { return }
        if viewController?.navigationItem.rightBarButtonItem === submitItem {
            viewController?.navigationItem.rightBarButtonItem = nil
        }
        self.submitItem = nil
    }
}

private extension FormComponent {
    enum Event: String {
        case connect
        case submitEnabled
        case submitDisabled
        case disconnect
    }

    struct MessageData: Decodable {
        let submitTitle: String
    }
}
