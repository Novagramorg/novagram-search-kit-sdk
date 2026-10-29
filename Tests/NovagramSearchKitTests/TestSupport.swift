import Foundation
import NovagramSearchKit

final class SteppingTime {
    private(set) var value: TimeInterval = 0
    let step: TimeInterval

    init(step: TimeInterval) {
        self.step = step
    }

    var clock: NovagramSearchClock {
        return NovagramSearchClock { [self] in
            let current = self.value
            self.value += self.step
            return current
        }
    }
}

struct TestMessage {
    let id: Int
    let text: String
}

final class IsolatedDefaults {
    let suiteName = "NovagramSearchKitTests.\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("UserDefaults suite unavailable")
        }
        self.defaults = defaults
    }

    func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
