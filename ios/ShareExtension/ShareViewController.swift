import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let status = UILabel()
    private let saveButton = UIButton(type: .system)
    private var sharedText: String?
    private var sharedImage: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.96, green: 0.97, blue: 0.94, alpha: 1)
        let title = UILabel()
        title.text = "存入易取件"; title.font = .boldSystemFont(ofSize: 25)
        title.textColor = UIColor(red: 0.09, green: 0.24, blue: 0.20, alpha: 1)
        status.text = "正在读取分享内容…"; status.numberOfLines = 8; status.font = .systemFont(ofSize: 15)
        let explanation = UILabel()
        explanation.text = "内容只保存在本机。打开易取件后，检查识别结果再确认添加。"
        explanation.numberOfLines = 0; explanation.font = .systemFont(ofSize: 13); explanation.textColor = .secondaryLabel
        saveButton.setTitle("保存为待确认内容", for: .normal)
        saveButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        saveButton.isEnabled = false; saveButton.addTarget(self, action: #selector(save), for: .touchUpInside)
        let cancel = UIButton(type: .system)
        cancel.setTitle("取消", for: .normal); cancel.addTarget(self, action: #selector(cancelShare), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [title, status, explanation, saveButton, cancel])
        stack.axis = .vertical; stack.spacing = 22; stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 28)
        ])
        loadSharedContent()
    }

    private func loadSharedContent() {
        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        let providers = items.flatMap { $0.attachments ?? [] }
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) {
            provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] url, error in
                guard let self else { return }
                guard let url, error == nil else { self.showError(error?.localizedDescription ?? "无法读取图片"); return }
                do {
                    let suffix = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
                    let copy = FileManager.default.temporaryDirectory.appendingPathComponent("easy-pickup-\(UUID().uuidString).\(suffix)")
                    try FileManager.default.copyItem(at: url, to: copy)
                    DispatchQueue.main.async { self.sharedImage = copy; self.status.text = "已选择一张图片，将在易取件中识别。"; self.saveButton.isEnabled = true }
                } catch { self.showError(error.localizedDescription) }
            }
        } else if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, error in
                let text: String?
                if let value = item as? String { text = value }
                else if let value = item as? NSAttributedString { text = value.string }
                else if let value = item as? Data { text = String(data: value, encoding: .utf8) }
                else { text = nil }
                guard let text, !text.isEmpty, error == nil else { self?.showError("没有可读取的文字"); return }
                DispatchQueue.main.async { self?.sharedText = text; self?.status.text = String(text.prefix(300)); self?.saveButton.isEnabled = true }
            }
        } else {
            showError("请选择可分享的文字或一张图片；不支持的来源可使用复制、截图或手动添加。")
        }
    }

    @objc private func save() {
        do {
            try SharedIncomingStore.save(text: sharedText, image: sharedImage)
            if let image = sharedImage { try? FileManager.default.removeItem(at: image) }
            sharedImage = nil; saveButton.isEnabled = false
            status.text = "已保存。请打开易取件，确认识别结果后添加。"
            let alert = UIAlertController(title: "已存入易取件", message: "请打开易取件确认添加。本次操作尚未创建取件记录。", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "完成", style: .default) { [weak self] _ in self?.extensionContext?.completeRequest(returningItems: nil) })
            present(alert, animated: true)
        } catch { showError(error.localizedDescription) }
    }

    private func showError(_ message: String) {
        DispatchQueue.main.async { self.status.text = message; self.saveButton.isEnabled = false }
    }

    @objc private func cancelShare() {
        if let image = sharedImage { try? FileManager.default.removeItem(at: image) }
        extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    }
}
