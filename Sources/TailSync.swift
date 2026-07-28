import Foundation
import Network

final class TailSync {
    private let port: UInt16 = 45831
    private weak var store: MemoryStore?
    private var listener: NWListener?
    private var timer: Timer?
    private let queue = DispatchQueue(label: "dev.aklimageldi.sync", qos: .utility)
    private let deviceName = Host.current().localizedName ?? "Mac"

    init(store: MemoryStore) {
        self.store = store
    }

    func start() {
        startServer()
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.syncNow()
        }
        syncNow()
    }

    func syncNow() {
        queue.async { [weak self] in
            guard let self else { return }
            let peers = self.tailscalePeerIPs()
            if peers.isEmpty {
                Task { @MainActor [weak self] in
                    self?.store?.setSyncMessage("sync_no_peer")
                }
                return
            }
            for ip in peers.prefix(20) {
                self.exchange(with: ip)
            }
        }
    }

    private func startServer() {
        do {
            let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            listener.stateUpdateHandler = { [weak self] state in
                if case .failed(let error) = state {
                    Task { @MainActor [weak self] in
                        self?.store?.setSyncMessage(
                            "sync_service_error_format",
                            arguments: [error.localizedDescription]
                        )
                    }
                }
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            Task { @MainActor [weak self] in
                self?.store?.setSyncMessage("sync_service_start_failed")
            }
        }
    }

    private func handle(_ connection: NWConnection) {
        guard case let .hostPort(host, _) = connection.endpoint,
              isTailnetAddress(host.debugDescription) else {
            connection.cancel()
            return
        }
        connection.start(queue: queue)
        receiveRequest(connection, buffer: Data())
    }

    private func receiveRequest(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 2_000_000) { [weak self] data, _, complete, _ in
            guard let self else {
                connection.cancel()
                return
            }
            var collected = buffer
            if let data { collected.append(data) }

            let separator = Data("\r\n\r\n".utf8)
            guard let headerEnd = collected.range(of: separator) else {
                if !complete && collected.count < 2_000_000 {
                    self.receiveRequest(connection, buffer: collected)
                } else {
                    connection.cancel()
                }
                return
            }
            let headerData = collected[..<headerEnd.lowerBound]
            let header = String(decoding: headerData, as: UTF8.self)
            let contentLength = header
                .split(separator: "\r\n")
                .first(where: { $0.lowercased().hasPrefix("content-length:") })
                .flatMap { Int($0.split(separator: ":").last?.trimmingCharacters(in: .whitespaces) ?? "") } ?? 0
            let bodyStart = headerEnd.upperBound
            let receivedBodyLength = collected.count - bodyStart
            if receivedBodyLength < contentLength && !complete {
                self.receiveRequest(connection, buffer: collected)
                return
            }
            guard receivedBodyLength >= contentLength else {
                connection.cancel()
                return
            }
            let bodyEnd = bodyStart + contentLength
            let body = Data(collected[bodyStart..<bodyEnd])

            if header.hasPrefix("GET /snapshot") {
                Task { @MainActor [weak self] in
                    guard let self, let store = self.store else { return }
                    let envelope = SyncEnvelope(deviceName: self.deviceName, items: store.snapshot())
                    let payload = (try? JSONEncoder().encode(envelope)) ?? Data()
                    self.respond(connection, status: "200 OK", body: payload)
                }
            } else if header.hasPrefix("POST /merge"),
                      let envelope = try? JSONDecoder().decode(SyncEnvelope.self, from: body) {
                Task { @MainActor [weak self] in
                    self?.store?.merge(envelope.items, from: envelope.deviceName)
                    self?.respond(connection, status: "204 No Content", body: Data())
                }
            } else {
                respond(connection, status: "404 Not Found", body: Data())
            }
        }
    }

    private func respond(_ connection: NWConnection, status: String, body: Data) {
        let head = "HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var packet = Data(head.utf8)
        packet.append(body)
        connection.send(content: packet, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func exchange(with ip: String) {
        performRequest(method: "GET", path: "/snapshot", body: Data(), to: ip) {
            [weak self] data in
            guard let self, let data,
                  let remote = try? JSONDecoder().decode(SyncEnvelope.self, from: data) else { return }
            Task { @MainActor [weak self] in
                guard let self, let store = self.store else { return }
                store.merge(remote.items, from: remote.deviceName)
                self.push(store.snapshot(), to: ip)
            }
        }
    }

    private func push(_ items: [MemoryItem], to ip: String) {
        guard let data = try? JSONEncoder().encode(
            SyncEnvelope(deviceName: deviceName, items: items)
        ) else {
            return
        }
        performRequest(method: "POST", path: "/merge", body: data, to: ip) {
            _ in
        }
    }

    private func performRequest(
        method: String,
        path: String,
        body: Data,
        to ip: String,
        completion: @escaping (Data?) -> Void
    ) {
        let host = NWEndpoint.Host(ip)
        let connection = NWConnection(
            host: host,
            port: NWEndpoint.Port(rawValue: port)!,
            using: .tcp
        )
        let requestHead = [
            "\(method) \(path) HTTP/1.1",
            "Host: \(urlHost(ip)):\(port)",
            "Content-Type: application/json",
            "Content-Length: \(body.count)",
            "Connection: close",
            "",
            ""
        ].joined(separator: "\r\n")
        var packet = Data(requestHead.utf8)
        packet.append(body)

        final class RequestState {
            var completed = false
        }
        let state = RequestState()
        let finish: (Data?) -> Void = { data in
            guard !state.completed else { return }
            state.completed = true
            connection.cancel()
            completion(data)
        }

        connection.stateUpdateHandler = { [weak self] connectionState in
            guard let self else {
                finish(nil)
                return
            }
            switch connectionState {
            case .ready:
                connection.send(content: packet, completion: .contentProcessed {
                    error in
                    guard error == nil else {
                        finish(nil)
                        return
                    }
                    self.receiveResponse(
                        connection,
                        buffer: Data(),
                        completion: finish
                    )
                })
            case .failed:
                finish(nil)
            default:
                break
            }
        }
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + 4) {
            finish(nil)
        }
    }

    private func receiveResponse(
        _ connection: NWConnection,
        buffer: Data,
        completion: @escaping (Data?) -> Void
    ) {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 2_000_000
        ) { [weak self] data, _, complete, error in
            guard let self else {
                completion(nil)
                return
            }
            var collected = buffer
            if let data {
                collected.append(data)
            }

            let separator = Data("\r\n\r\n".utf8)
            if let headerEnd = collected.range(of: separator) {
                let headerData = collected[..<headerEnd.lowerBound]
                let header = String(decoding: headerData, as: UTF8.self)
                guard header.hasPrefix("HTTP/1.1 2") else {
                    completion(nil)
                    return
                }
                let contentLength = header
                    .split(separator: "\r\n")
                    .first {
                        $0.lowercased().hasPrefix("content-length:")
                    }
                    .flatMap {
                        Int(
                            $0.split(separator: ":").last?
                                .trimmingCharacters(in: .whitespaces) ?? ""
                        )
                    } ?? 0
                let bodyStart = headerEnd.upperBound
                let receivedBodyLength = collected.count - bodyStart
                if receivedBodyLength >= contentLength {
                    let bodyEnd = bodyStart + contentLength
                    completion(Data(collected[bodyStart..<bodyEnd]))
                    return
                }
            }

            if complete || error != nil || collected.count >= 2_000_000 {
                completion(nil)
            } else {
                self.receiveResponse(
                    connection,
                    buffer: collected,
                    completion: completion
                )
            }
        }
    }

    private func tailscalePeerIPs() -> [String] {
        let candidates = [
            "/usr/local/bin/tailscale",
            "/opt/homebrew/bin/tailscale",
            "/Applications/Tailscale.app/Contents/MacOS/Tailscale"
        ]
        guard let executable = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            Task { @MainActor [weak self] in
                self?.store?.setSyncMessage("sync_cli_missing")
            }
            return []
        }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["status", "--json"]
        var environment = ProcessInfo.processInfo.environment
        environment["TAILSCALE_BE_CLI"] = "1"
        process.environment = environment
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }
        guard process.terminationStatus == 0,
              let object = try? JSONSerialization.jsonObject(with: pipe.fileHandleForReading.readDataToEndOfFile()) as? [String: Any],
              let peers = object["Peer"] as? [String: Any] else { return [] }

        return peers.values.compactMap { value in
            guard let peer = value as? [String: Any],
                  (peer["Online"] as? Bool) == true,
                  let ips = peer["TailscaleIPs"] as? [String] else { return nil }
            return ips.first(where: { !$0.contains(":") }) ?? ips.first
        }
    }

    private func urlHost(_ ip: String) -> String {
        ip.contains(":") ? "[\(ip)]" : ip
    }

    private func isTailnetAddress(_ rawAddress: String) -> Bool {
        let address = rawAddress
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            .split(separator: "%", maxSplits: 1)
            .first
            .map(String.init) ?? rawAddress
        if address.lowercased().hasPrefix("fd7a:115c:a1e0:") {
            return true
        }
        let octets = address.split(separator: ".").compactMap { Int($0) }
        return octets.count == 4 && octets[0] == 100 && (64...127).contains(octets[1])
    }
}
