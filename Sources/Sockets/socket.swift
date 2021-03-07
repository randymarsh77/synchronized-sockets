import Foundation
import IDisposable
import Scope

public typealias SocketErrorHandler = () throws -> Void

public class Socket : IDisposable
{
	class HandlerWrapper
	{
		var handler: SocketErrorHandler

		init(handler: @escaping SocketErrorHandler)
		{
			self.handler = handler
		}
	}

	var fd: Int32
	var errorHandlers: Array<HandlerWrapper>

	public init (fd: Int32, address: EndpointAddress)
	{
		var set: Int = 1
		setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &set, UInt32(MemoryLayout<Int>.size));

		self.fd = fd
		self.errorHandlers = Array<HandlerWrapper>()
		self.address = address
	}

	public var isValid: Bool { return self.fd > 0 }

	public let address: EndpointAddress

	public func dispose() -> Void
	{
		if (self.fd > 0) { close(self.fd)}
		self.fd = 0
	}

	public func registerErrorHandler(handler: @escaping SocketErrorHandler) -> Scope
	{
		let wrapper = HandlerWrapper(handler: handler)
		self.errorHandlers.append(wrapper)
		return Scope() {
			self.errorHandlers = self.errorHandlers.filter { $0 === wrapper }
		}
	}

	public func read(maxBytes: UInt32) -> Data?
	{
		return self.read(maxBytes, minBytes: 0)
	}

	public func read(_ maxBytes: UInt32, minBytes: UInt32 = 0) -> Data?
	{
		let buffer = malloc(Int(maxBytes))
		var bytesRead = UInt32(0)
		var keepReading = true
		while keepReading {
			let result = recv(self.fd, buffer!.advanced(by: Int(bytesRead)), Int(maxBytes) - Int(bytesRead), 0)
			if result < 0
			{
				for wrapper in self.errorHandlers {
					try! wrapper.handler()
				}
			}
			else if result == 0
			{
				keepReading = false
				self.dispose()
			}
			else
			{
				bytesRead += UInt32(result)
			}
			keepReading = keepReading && minBytes != 0 && bytesRead < minBytes
		}
		return Data(bytesNoCopy: buffer!, count: Int(bytesRead), deallocator: .free)
	}

	public func write(_ data: Data) -> Void
	{
		let result = data.withUnsafeBytes{
			send(self.fd, $0.baseAddress!, data.count, 0)
		}
		if result < 0
		{
			for wrapper in self.errorHandlers {
				try! wrapper.handler()
			}
		}
		else if result != data.count
		{
			print("Tried to send: ", data.count, " but only sent: ", result)
		}
	}
}
