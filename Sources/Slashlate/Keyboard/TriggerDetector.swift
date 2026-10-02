struct TriggerDetector {
    let trigger: String

    private var buffer = ""

    init(trigger: String) {
        precondition(!trigger.isEmpty, "Trigger must not be empty")
        self.trigger = trigger
    }

    mutating func ingest(_ characters: String) -> Bool {
        guard !characters.isEmpty else {
            return false
        }

        buffer.append(contentsOf: characters)

        if buffer.count > trigger.count {
            buffer = String(buffer.suffix(trigger.count))
        }

        guard buffer == trigger else {
            return false
        }

        buffer.removeAll(keepingCapacity: true)
        return true
    }

    mutating func reset() {
        buffer.removeAll(keepingCapacity: true)
    }
}
