import Foundation
import Time

public struct NetworkLatency: Sendable {
	public let differenceOnReceive: Time
	public let roundTrip: Time
}

extension Socket {
	public func ping() -> NetworkLatency {
		let start = Time.now
		let client = Time.fromSystemTimeStamp(self.getResponse(data: Time.now))
		let end = Time.now
		return NetworkLatency(differenceOnReceive: client - start, roundTrip: end - start)
	}

	public func pong() {
		let _ = self.receiveAndRespond(data: Time.now.systemTimeStamp)
	}
}
