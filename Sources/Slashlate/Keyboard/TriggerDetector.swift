struct TriggerDetector {
    let triggers: [TranslationTrigger]

    private let maxLength: Int
    private var buffer = ""

    init(triggers: [TranslationTrigger] = TranslationTrigger.all) {
        precondition(!triggers.isEmpty, "At least one trigger is required")
        precondition(triggers.allSatisfy { !$0.sequence.isEmpty }, "Triggers must not be empty")
        self.triggers = triggers
        maxLength = triggers.map(\.sequence.count).max() ?? 0
    }

    /// Feeds typed characters and returns the trigger they complete, if any.
    mutating func ingest(_ characters: String) -> TranslationTrigger? {
        guard !characters.isEmpty else {
            return nil
        }

        buffer.append(contentsOf: characters)

        if buffer.count > maxLength {
            buffer = String(buffer.suffix(maxLength))
        }

        guard let trigger = triggers.first(where: { buffer.hasSuffix($0.sequence) }) else {
            return nil
        }

        buffer.removeAll(keepingCapacity: true)
        return trigger
    }

    mutating func reset() {
        buffer.removeAll(keepingCapacity: true)
    }
}
