import AppKit

final class KeyboardMonitor {
    private var eventMonitor: Any?
    private var triggerDetector: TriggerDetector
    private let onTrigger: (TranslationTrigger) -> Void

    init(triggers: [TranslationTrigger], onTrigger: @escaping (TranslationTrigger) -> Void) {
        self.triggerDetector = TriggerDetector(triggers: triggers)
        self.onTrigger = onTrigger
    }

    @discardableResult
    func start() -> Bool {
        guard eventMonitor == nil else {
            return true
        }

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else {
                return
            }

            guard !event.isARepeat else {
                return
            }

            guard let characters = event.characters, !characters.isEmpty else {
                return
            }

            guard let trigger = self.triggerDetector.ingest(characters) else {
                return
            }

            // The global monitor observes the key event before some target apps have
            // committed the trigger's last character to their accessibility value. A
            // tiny delay lets the target field finish processing it before we inspect it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.onTrigger(trigger)
            }
        }

        return eventMonitor != nil
    }

    func stop() {
        guard let eventMonitor else {
            return
        }

        NSEvent.removeMonitor(eventMonitor)
        self.eventMonitor = nil
        triggerDetector.reset()
    }

    deinit {
        stop()
    }
}
