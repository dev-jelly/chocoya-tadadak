import AppKit

final class SettingsViewController: NSViewController {
    private let keySoundManager: KeySoundManager
    private var themePopup: NSPopUpButton!
    private var volumeSlider: NSSlider!

    // MARK: - Init

    init(keySoundManager: KeySoundManager) {
        self.keySoundManager = keySoundManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Lifecycle

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 140))
        setupUI()
    }

    // MARK: - UI

    private func setupUI() {
        // Theme label
        let themeLabel = NSTextField(labelWithString: "Theme:")
        themeLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(themeLabel)

        // Theme popup
        themePopup = NSPopUpButton()
        themePopup.translatesAutoresizingMaskIntoConstraints = false
        themePopup.addItems(withTitles: KeySoundManager.availableThemes())
        let idx = themePopup.indexOfItem(withTitle: keySoundManager.currentTheme)
        if idx != -1 {
            themePopup.selectItem(at: idx)
        }
        themePopup.target = self
        themePopup.action = #selector(themeChanged(_:))
        view.addSubview(themePopup)

        // Volume label
        let volumeLabel = NSTextField(labelWithString: "Volume:")
        volumeLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(volumeLabel)

        // Volume slider
        volumeSlider = NSSlider(value: Double(keySoundManager.volume), minValue: 0, maxValue: 1, target: self, action: #selector(volumeChanged(_:)))
        volumeSlider.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(volumeSlider)

        // Layout
        NSLayoutConstraint.activate([
            themeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            themeLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            
            themePopup.leadingAnchor.constraint(equalTo: themeLabel.trailingAnchor, constant: 12),
            themePopup.centerYAnchor.constraint(equalTo: themeLabel.centerYAnchor),
            themePopup.widthAnchor.constraint(equalToConstant: 150),

            volumeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            volumeLabel.topAnchor.constraint(equalTo: themeLabel.bottomAnchor, constant: 24),

            volumeSlider.leadingAnchor.constraint(equalTo: volumeLabel.trailingAnchor, constant: 12),
            volumeSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            volumeSlider.centerYAnchor.constraint(equalTo: volumeLabel.centerYAnchor)
        ])
    }

    // MARK: - Actions

    @objc private func themeChanged(_ sender: NSPopUpButton) {
        guard let theme = sender.titleOfSelectedItem else { return }
        keySoundManager.loadSounds(theme: theme)
    }

    @objc private func volumeChanged(_ sender: NSSlider) {
        keySoundManager.volume = Float(sender.doubleValue)
    }
}
