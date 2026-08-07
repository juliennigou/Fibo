import BackgroundTasks
import Foundation

enum BackgroundRefresh {
    static let identifier = "com.juliennigou.Fibo.refresh"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
