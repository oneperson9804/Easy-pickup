import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let status = UILabel()
    private let saveButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let saveQueue = DispatchQueue(label: "EasyPickup.ShareSave")
    private var sharedTexts: [String] = []
    private var sharedImages: [URL] = []
    private var loadingComplete = false
    private var cancelled = false
    private var saving = false

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
        cancelButton.setTitle("取消", for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelShare), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [title, status, explanation, saveButton, cancelButton])
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
        guard !providers.isEmpty else {
            showError("请选择可分享的文字或图片。"); return
        }
        loadProvider(providers, at: 0)
    }

    // Providers may call back on arbitrary queues. All selection state and UI
    // changes are serialized on the main queue; file copies stay off it.
    private func loadProvider(_ providers: [NSItemProvider], at index: Int) {
        guard !cancelled else { return }
        guard index < providers.count else {
            loadingComplete = true
            status.text = [
                sharedImages.isEmpty ? nil : "已选择 \(sharedImages.count) 张图片，将在易取件中识别。",
                sharedTexts.isEmpty ? nil : String(sharedTexts.joined(separator: "\n\n").prefix(300))
            ].compactMap { $0 }.joined(separator: "\n\n")
            saveButton.isEnabled = !sharedImages.isEmpty || !sharedTexts.isEmpty
            return
        }
        let provider = providers[index]
        status.text = "正在读取第 \(index + 1) / \(providers.count) 项…"
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] url, error in
                guard let url, error == nil else {
                    self?.showError(error?.localizedDescription ?? "无法读取图片，请重新分享。"); return
                }
                let suffix = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
                let copy = FileManager.default.temporaryDirectory.appendingPathComponent("easy-pickup-\(UUID().uuidString).\(suffix)")
                do {
                    try FileManager.default.copyItem(at: url, to: copy)
                    DispatchQueue.main.async { [weak self] in
                        guard let self, !self.cancelled else {
                            try? FileManager.default.removeItem(at: copy); return
                        }
                        self.sharedImages.append(copy)
                        self.loadProvider(providers, at: index + 1)
                    }
                } catch {
                    try? FileManager.default.removeItem(at: copy)
                    self?.showError(error.localizedDescription)
                }
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, error in
                let text: String?
                if let value = item as? String { text = value }
                else if let value = item as? NSAttributedString { text = value.string }
                else if let value = item as? Data { text = String(data: value, encoding: .utf8) }
                else { text = nil }
                guard let text, !text.isEmpty, error == nil else {
                    self?.showError("没有可读取的文字，请重新分享。"); return
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self, !self.cancelled else { return }
                    self.sharedTexts.append(text)
                    self.loadProvider(providers, at: index + 1)
                }
            }
        } else {
            showError("分享中有不支持的文件，请重新选择文字或图片。")
        }
    }

    @objc private func save() {
        guard loadingComplete, !saving, !cancelled else { return }
        saving = true
        saveButton.isEnabled = false; cancelButton.isEnabled = false
        status.text = "正在保存待确认内容…"
        let text = sharedTexts.joined(separator: "\n\n")
        let images = sharedImages
        saveQueue.async { [weak self] in
            do {
                try SharedIncomingStore.save(text: text, images: images)
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.saving = false
                    self.removeTemporaryImages()
                    self.status.text = "已保存。请打开易取件，确认识别结果后添加。"
                    let alert = UIAlertController(title: "已存入易取件", message: "请打开易取件确认添加。", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "完成", style: .default) { [weak self] _ in
                        self?.extensionContext?.completeRequest(returningItems: nil)
                    })
                    self.present(alert, animated: true)
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.saving = false
                    self.cancelButton.isEnabled = true
                    self.showError("保存失败，可重试：\(error.localizedDescription)", retrySave: true)
                }
            }
        }
    }

    private func showError(_ message: String, retrySave: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.cancelled else { return }
            self.status.text = message
            self.saveButton.isEnabled = retrySave && self.loadingComplete
            if !retrySave { self.removeTemporaryImages() }
        }
    }

    @objc private func cancelShare() {
        guard !saving else { return }
        cancelled = true
        removeTemporaryImages()
        extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    }

    private func removeTemporaryImages() {
        for image in sharedImages { try? FileManager.default.removeItem(at: image) }
        sharedImages = []
    }
}
