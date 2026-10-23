import Foundation

@main
struct DailyFireLinuxMain {
    static func main() async {
        let report = await DailyFireChecks.run()
        if report.failures.isEmpty {
            print("PASS daily fire checks (\(report.checks))")
            return
        }
        for failure in report.failures {
            fputs("FAIL \(failure)\n", stderr)
        }
        print("FAIL \(report.failures.count) of \(report.checks)")
        exit(1)
    }
}
