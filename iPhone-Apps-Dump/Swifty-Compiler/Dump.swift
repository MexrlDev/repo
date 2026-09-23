//
//  Dump.swift - Mexrldev MIT
//

import Foundation

public enum DumpEverything {

	// ---- Knobs ----------------------------------------------------------
	private static let sampleSymbolLimit = 30

	// ---- Well-known paths ----------------------------------------------
	private static let libcCandidates = [
		"/lib/x86_64-linux-gnu/libc-2.27.so",
		"/lib/x86_64-linux-gnu/libc.so.6",
		"/usr/lib/x86_64-linux-gnu/libc.so.6",
		"/lib64/libc.so.6"
	]
	private static let pthreadCandidates = [
		"/lib/x86_64-linux-gnu/libpthread-2.27.so",
		"/lib/x86_64-linux-gnu/libpthread.so.0",
		"/usr/lib/x86_64-linux-gnu/libpthread.so.0"
	]

	// ====================================================================
	//  ENTRY POINT
	// ====================================================================

	public static func run() {
		capabilityProbes()

		dumpProcessIdentity()
		dumpCmdline()
		dumpMaps()
		dumpSharedObjects()
		dumpImportableModules()
		dumpLoadedModuleMetadata()
		dumpSymbolCounts()
		dumpSymbolSamples()
		dumpKeyCFunctions()
		dumpTimeAndLocale()
		dumpStatus()
		dumpStat()
		dumpLimits()
		dumpMounts()
		dumpEnvironment()
		dumpMeminfo()
		dumpCpuinfo()
		dumpKernelVersion()
		dumpBundleNote()
		dumpEnvironmentConstraints()

		footer("DUMP COMPLETE")
	}

	// ====================================================================
	//  CAPABILITY PROBES
	// ====================================================================

	private static func capabilityProbes() {
		section("CAPABILITY PROBES")

		let readPath = "/etc/hostname"
		if let data = FileManager.default.contents(atPath: readPath) {
			print("  read  \(readPath): OK (\(data.count) bytes)")
		} else {
			print("  read  \(readPath): FAILED")
		}

		let pid = ProcessInfo.processInfo.processIdentifier
		let writePath = "/tmp/dump_probe_\(pid).tmp"
		let payload = Data("probe\n".utf8)
		let writeOK = FileManager.default.createFile(atPath: writePath, contents: payload)
		print("  write \(writePath): \(writeOK ? "OK" : "FAILED")")
		if writeOK { try? FileManager.default.removeItem(atPath: writePath) }

		let tmpList = listDirectory("/tmp")
		print("  list  /tmp: \(tmpList.count) entries")

		let spawnOK = runAndWait("/bin/true", args: [])
		print("  exec  /bin/true: \(spawnOK == 0 ? "OK (exit 0)" : "FAILED (exit \(spawnOK.map(String.init) ?? "nil"))")")

		let nmExists = FileManager.default.fileExists(atPath: "/usr/bin/nm")
		print("  tool  /usr/bin/nm: \(nmExists ? "present" : "missing")")
	}

	// ====================================================================
	//  SECTION HELPERS
	// ====================================================================

	private static func header(_ t: String) {
		print("══════════════════════════════════════════════")
		print("🔍  \(t)")
		print("══════════════════════════════════════════════")
	}
	private static func footer(_ t: String) {
		print("══════════════════════════════════════════════")
		print("✅  \(t)")
		print("══════════════════════════════════════════════")
	}
	private static func section(_ t: String) {
		print("\n\n▶︎  \(t)")
		print("----------------------------------------------")
	}
	private static func read(_ p: String) -> String? {
		try? String(contentsOfFile: p, encoding: .utf8)
	}
	private static func resolveSymlink(_ p: String) -> String {
		(try? FileManager.default.destinationOfSymbolicLink(atPath: p)) ?? "?"
	}
	private static func dumpFile(_ p: String) {
		section(p)
		if let c = read(p) { print(c.trimmingCharacters(in: .newlines)) } else { print("<could not read>") }
	}
	private static func listDirectory(_ p: String) -> [String] {
		(try? FileManager.default.contentsOfDirectory(atPath: p)) ?? []
	}
	private static func rightPad(_ s: String, to n: Int) -> String {
		s.count >= n ? s : String(repeating: " ", count: n - s.count) + s
	}
	private static func humanSize(_ b: Int) -> String {
		let units = ["B", "KB", "MB", "GB"]
		var v = Double(b)
		var i = 0
		while v >= 1024 && i < units.count - 1 {
			v /= 1024
			i += 1
		}
		if i == 0 { return "\(b) B" }
		let rounded = (v * 10).rounded() / 10
		return "\(rounded) \(units[i])"
	}

	// ====================================================================
	//  PROCESS IDENTITY
	// ====================================================================

	private static func dumpProcessIdentity() {
		section("PROCESS IDENTITY")
		print("pid:                \(ProcessInfo.processInfo.processIdentifier)")
		let stat = read("/proc/self/stat")?.split(separator: " ") ?? []
		print("ppid:               \(stat.count > 3 ? String(stat[3]) : "?")")
		print("exe:                \(resolveSymlink("/proc/self/exe"))")
		print("cwd:                \(resolveSymlink("/proc/self/cwd"))")
		print("root:               \(resolveSymlink("/proc/self/root"))")
		print("hostname:           \(ProcessInfo.processInfo.hostName)")
		print("os version:         \(ProcessInfo.processInfo.operatingSystemVersionString)")
		print("processor count:    \(ProcessInfo.processInfo.processorCount)")
		print("active processors:  \(ProcessInfo.processInfo.activeProcessorCount)")
		print("physical memory:    \(ProcessInfo.processInfo.physicalMemory) bytes")
		print("system uptime:      \(ProcessInfo.processInfo.systemUptime) s")
		print("globally unique id: \(ProcessInfo.processInfo.globallyUniqueString)")
	}

	// ====================================================================
	//  COMMAND LINE
	// ====================================================================

	private static func dumpCmdline() {
		section("COMMAND LINE")
		if let data = FileManager.default.contents(atPath: "/proc/self/cmdline") {
			let args = data.split(separator: 0).map { String(decoding: $0, as: UTF8.self) }
			for (i, a) in args.enumerated() { print("[\(i)] \(a)") }
		} else {
			print("<could not read /proc/self/cmdline>")
		}
	}

	// ====================================================================
	//  MEMORY MAPS
	// ====================================================================

	private static func dumpMaps() {
		section("FULL MEMORY MAPS (/proc/self/maps)")
		guard let maps = read("/proc/self/maps") else {
			print("<could not read>")
			return
		}
		let lines = maps.split(separator: "\n", omittingEmptySubsequences: true)
		print("Total mapped regions: \(lines.count)\n")
		for (i, line) in lines.enumerated() {
			print("\(rightPad(String(i), to: 4))  \(line)")
		}
	}

	// ====================================================================
	//  UNIQUE SHARED OBJECTS
	// ====================================================================

	private static func dumpSharedObjects() {
		section("UNIQUE SHARED OBJECTS")
		guard let maps = read("/proc/self/maps") else {
			print("<no maps>")
			return
		}
		var seen = Set<String>()
		var ordered: [String] = []
		var counts: [String: Int] = [:]
		for line in maps.split(separator: "\n", omittingEmptySubsequences: true) {
			let parts = line.split(separator: " ", omittingEmptySubsequences: true)
			guard parts.count >= 6 else { continue }
			let path = parts.dropFirst(5).joined(separator: " ")
			guard path.hasPrefix("/") else { continue }
			if seen.insert(path).inserted { ordered.append(path) }
			counts[path, default: 0] += 1
		}
		print("Total unique objects: \(ordered.count)\n")
		for (i, p) in ordered.enumerated() {
			let r = counts[p] ?? 0
			let label = r == 1 ? "1 region" : "\(r) regions"
			print("\(rightPad(String(i), to: 3))  \(p)   [\(label)]")
		}
	}

	// ====================================================================
	//  IMPORTABLE MODULES
	// ====================================================================

	private static func dumpImportableModules() {
		section("IMPORTABLE MODULES")
		let dirs = [
			"/usr/lib/swift/linux",
			"/usr/lib/swift/linux/x86_64",
			"/usr/lib/swift",
			"/usr/local/lib/swift/linux",
			"/usr/local/lib/swift/linux/x86_64"
		]
		var modules = Set<String>()
		var docs = Set<String>()
		var subdirs = Set<String>()
		var libs = Set<String>()
		for dir in dirs {
			for e in listDirectory(dir) {
				if e.hasSuffix(".swiftmodule") {
					modules.insert(String(e.dropLast(12)))
				} else if e.hasSuffix(".swiftdoc") {
					docs.insert(String(e.dropLast(9)))
				} else if e.hasSuffix(".so") {
					var n = e
					if n.hasPrefix("lib") { n.removeFirst(3) }
					if n.hasSuffix(".so") { n.removeLast(3) }
					libs.insert(n)
				} else if !e.hasSuffix(".swiftinterface") && !e.hasSuffix(".swift") {
					var isDir: ObjCBool = false
					if FileManager.default.fileExists(atPath: dir + "/" + e, isDirectory: &isDir),
						isDir.boolValue
					{
						subdirs.insert(e)
					}
				}
			}
		}
		print("── Importable names ──")
		for name in modules.union(libs).union(subdirs).filter({ !$0.hasPrefix(".") }).sorted() {
			var tags: [String] = []
			if modules.contains(name) { tags.append("swiftmodule") }
			if docs.contains(name) { tags.append("swiftdoc") }
			if libs.contains(name) { tags.append("runtime.so") }
			if subdirs.contains(name) { tags.append("module dir") }
			print("  • \(name)  [\(tags.joined(separator: ", "))]")
		}
		print("\n── Currently loaded ──")
		for n in loadedModuleNames() { print("  • \(n)") }
		print("\n── Runtime .so files on disk ──")
		for e in listDirectory("/usr/lib/swift/linux").filter({ $0.hasSuffix(".so") }).sorted() {
			print("  • \(e)")
		}
		print("\n── Toolchain ──")
		let env = ProcessInfo.processInfo.environment
		for k in ["SWIFT_BRANCH", "SWIFT_PLATFORM", "SWIFT_VERSION", "SWIFT_WEBROOT"] {
			print("  \(k): \(env[k] ?? "<unset>")")
		}
	}

	private static func loadedModuleNames() -> [String] {
		var found = Set<String>()
		guard let maps = read("/proc/self/maps") else { return [] }
		for line in maps.split(separator: "\n", omittingEmptySubsequences: true) {
			let parts = line.split(separator: " ", omittingEmptySubsequences: true)
			guard parts.count >= 6 else { continue }
			let path = parts.dropFirst(5).joined(separator: " ")
			if path.hasSuffix(".swiftmodule"), let last = path.split(separator: "/").last {
				found.insert(String(last.dropLast(12)))
			} else if path.contains("/libswift") && path.hasSuffix(".so"),
				let last = path.split(separator: "/").last
			{
				var b = String(last)
				if b.hasSuffix(".so") { b.removeLast(3) }
				if b.hasPrefix("lib") { b.removeFirst(3) }
				found.insert(b)
			}
		}
		return found.sorted()
	}

	// ====================================================================
	//  LOADED MODULE METADATA
	// ====================================================================

	private static func dumpLoadedModuleMetadata() {
		section("LOADED MODULE METADATA (size + mtime)")
		let loaded = Set(loadedModuleNames())
		let dirs = ["/usr/lib/swift/linux/x86_64", "/usr/lib/swift/linux"]
		var rows: [(String, String, Int, Date?, Bool)] = []
		for dir in dirs {
			for e in listDirectory(dir) {
				let full = dir + "/" + e
				var name: String? = nil
				if e.hasSuffix(".swiftmodule") {
					name = String(e.dropLast(12))
				} else if e.hasSuffix(".so") {
					var n = e
					if n.hasPrefix("lib") { n.removeFirst(3) }
					if n.hasSuffix(".so") { n.removeLast(3) }
					name = n
				}
				guard let nm = name else { continue }
				let attrs = try? FileManager.default.attributesOfItem(atPath: full)
				let size = (attrs?[.size] as? NSNumber)?.intValue ?? 0
				let mtime = attrs?[.modificationDate] as? Date
				rows.append((nm, full, size, mtime, loaded.contains(nm)))
			}
		}
		rows.sort { a, b in
			if a.4 != b.4 { return a.4 && !b.4 }
			return a.0 < b.0
		}
		let fmt = DateFormatter()
		fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
		fmt.timeZone = TimeZone(identifier: "UTC")
		for r in rows {
			let mark = r.4 ? "● LOADED " : "  on disk"
			let ts = r.3.map { fmt.string(from: $0) } ?? "?"
			print("  \(mark)  \(r.0.padding(toLength: 26, withPad: " ", startingAt: 0))  \(rightPad(humanSize(r.2), to: 9))  \(ts)  \(r.1)")
		}
	}

	// ====================================================================
	//  SYMBOL COUNTS
	// ====================================================================

	private static func dumpSymbolCounts() {
		section("DYNAMIC SYMBOL COUNTS (nm)")
		let nm = "/usr/bin/nm"
		guard FileManager.default.fileExists(atPath: nm) else {
			print("nm missing; skipping.")
			return
		}
		for lib in listDirectory("/usr/lib/swift/linux").filter({ $0.hasSuffix(".so") }).sorted() {
			let full = "/usr/lib/swift/linux/" + lib
			let d = countSymbols(full, nm: nm, args: ["-D", "--defined-only"])
			let u = countSymbols(full, nm: nm, args: ["-D", "--undefined-only"])
			let t = countSymbols(full, nm: nm, args: ["-D"])
			if let d = d, let u = u, let t = t {
				print("  \(lib)")
				print("      defined:   \(d)")
				print("      undefined: \(u)")
				print("      total:     \(t)")
			} else {
				print("  \(lib): <nm failed>")
			}
		}
	}

	private static func countSymbols(_ path: String, nm: String, args: [String]) -> Int? {
		guard let out = runCapture(nm, args: args + [path]) else { return nil }
		return out.split(separator: "\n", omittingEmptySubsequences: true).count
	}

	// ====================================================================
	//  SYMBOL NAME SAMPLES
	// ====================================================================

	private static func dumpSymbolSamples() {
		section("SYMBOL NAME SAMPLES (first \(sampleSymbolLimit) per library)")
		let nm = "/usr/bin/nm"
		guard FileManager.default.fileExists(atPath: nm) else {
			print("nm missing; skipping.")
			return
		}
		for lib in listDirectory("/usr/lib/swift/linux").filter({ $0.hasSuffix(".so") }).sorted() {
			let full = "/usr/lib/swift/linux/" + lib
			guard let out = runCapture(nm, args: ["-D", "--defined-only", full]) else {
				print("  \(lib): <nm failed>")
				continue
			}
			let lines = out.split(separator: "\n", omittingEmptySubsequences: true)
			print("\n  ── \(lib)  (showing \(min(sampleSymbolLimit, lines.count)) of \(lines.count)) ──")
			for line in lines.prefix(sampleSymbolLimit) {
				let cols = line.split(separator: " ", omittingEmptySubsequences: true)
				if cols.count >= 3 {
					print("      \(cols[1])  \(cols[2])")
				} else {
					print("      \(line)")
				}
			}
		}
	}

	// ====================================================================
	//  KEY C FUNCTIONS PRESENT
	// ====================================================================

	private static func dumpKeyCFunctions() {
		section("KEY C FUNCTIONS PRESENT")

		var symbolSet = Set<String>()

		if let libcPath = libcCandidates.first(where: { FileManager.default.fileExists(atPath: $0) }) {
			print("Scanning \(libcPath)")
			if let out = runCapture("/usr/bin/nm", args: ["-D", "--defined-only", libcPath]) {
				for name in extractSymbolNames(from: out) { symbolSet.insert(name) }
			}
		} else {
			print("libc not found at any expected path.")
		}

		if let pthreadPath = pthreadCandidates.first(where: { FileManager.default.fileExists(atPath: $0) }) {
			print("Scanning \(pthreadPath)")
			if let out = runCapture("/usr/bin/nm", args: ["-D", "--defined-only", pthreadPath]) {
				for name in extractSymbolNames(from: out) { symbolSet.insert(name) }
			}
		} else {
			print("libpthread not found at any expected path (OK on glibc >= 2.34).")
		}

		print("")

		let groups: [(String, [String])] = [
			("memory", ["malloc", "calloc", "realloc", "free", "memcpy", "memmove", "memset"]),
			("io", ["open", "close", "read", "write", "fopen", "fclose", "fread", "fwrite", "lseek"]),
			("process", ["fork", "execve", "waitpid", "exit", "_exit", "getpid", "getppid"]),
			("threads", ["pthread_create", "pthread_join", "pthread_mutex_init", "pthread_mutex_lock"]),
			("net", ["socket", "bind", "listen", "accept", "connect", "send", "recv", "getaddrinfo"]),
			("fs", ["stat", "fstat", "lstat", "unlink", "rename", "mkdir", "rmdir", "chmod"]),
			("time", ["time", "gettimeofday", "clock_gettime", "nanosleep"]),
			("random", ["rand", "random", "getrandom", "srand"]),
			("env", ["getenv", "setenv", "unsetenv", "environ"]),
			("signal", ["signal", "sigaction", "kill", "raise"]),
			("strings", ["strlen", "strcmp", "strcpy", "snprintf", "printf", "fprintf"])
		]

		for (group, syms) in groups {
			print("  \(group):")
			for s in syms {
				let mark = symbolSet.contains(s) ? "✓" : "✗"
				print("    \(mark) \(s)")
			}
		}
	}

	/// Extract bare symbol names from `nm -D` output.
	/// Handles lines like:
	///     0000000000042120 T malloc
	///     0000000000042120 T stat@@GLIBC_2.2.5
	/// and versioned aliases, stripping the `@...` suffix.
	private static func extractSymbolNames(from nmOutput: String) -> [String] {
		var names: [String] = []
		for line in nmOutput.split(separator: "\n", omittingEmptySubsequences: true) {
			let cols = line.split(separator: " ", omittingEmptySubsequences: true)
			guard cols.count >= 3 else { continue }
			var name = String(cols.last!)
			// Strip glibc version suffix, e.g. `stat@@GLIBC_2.2.5` → `stat`
			if let atIdx = name.firstIndex(of: "@") {
				name = String(name[..<atIdx])
			}
			guard !name.isEmpty else { continue }
			names.append(name)

			if name == "__xstat" { names.append("stat") }
			if name == "__fxstat" { names.append("fstat") }
			if name == "__lxstat" { names.append("lstat") }
		}
		return names
	}

	// ====================================================================
	//  TIME AND LOCALE
	// ====================================================================

	private static func dumpTimeAndLocale() {
		section("TIME AND LOCALE")
		let now = Date()
		let utc = DateFormatter()
		utc.dateFormat = "yyyy-MM-dd HH:mm:ss"
		utc.timeZone = TimeZone(identifier: "UTC")
		print("now (UTC):           \(utc.string(from: now))")
		print("unix epoch:          \(Int(now.timeIntervalSince1970))")
		print("timezone identifier: \(TimeZone.current.identifier)")
		print("timezone offset:     \(TimeZone.current.secondsFromGMT()) s")
		print("locale identifier:   \(Locale.current.identifier)")
		print("calendar:            \(Calendar.current.identifier)")
	}

	// ====================================================================
	//  /proc DUMPS
	// ====================================================================

	private static func dumpStatus() { dumpFile("/proc/self/status") }
	private static func dumpStat() { dumpFile("/proc/self/stat") }
	private static func dumpLimits() { dumpFile("/proc/self/limits") }

	private static func dumpMounts() {
		section("MOUNTS (/proc/self/mountinfo)")
		guard let data = read("/proc/self/mountinfo") else {
			print("<no>")
			return
		}
		let lines = data.split(separator: "\n", omittingEmptySubsequences: true)
		print("Total mounts: \(lines.count)\n")
		for line in lines {
			let parts = line.split(separator: " ")
			if parts.count >= 5 {
				let mp = parts[4]
				let fs = parts.count >= 9 ? parts[parts.count - 3] : "?"
				print("\(mp)  [\(fs)]")
			}
		}
	}

	private static func dumpEnvironment() {
		section("ENVIRONMENT VARIABLES")
		let env = ProcessInfo.processInfo.environment
		print("Total variables: \(env.count)\n")
		for (k, v) in env.sorted(by: { $0.key < $1.key }) {
			print("\(k)=\(v)")
		}
	}

	private static func dumpMeminfo() { dumpFile("/proc/meminfo") }
	private static func dumpCpuinfo() { dumpFile("/proc/cpuinfo") }
	private static func dumpKernelVersion() { dumpFile("/proc/version") }

	// ====================================================================
	//  BUNDLES (safe note)
	// ====================================================================

	private static func dumpBundleNote() {
		section("BUNDLES")
		print("Bundle.allBundles / allFrameworks SEGFAULT on this toolchain.")
		let main = Bundle.main
		print("Bundle.main:")
		print("  path:       \(main.bundlePath)")
		print("  identifier: \(main.bundleIdentifier ?? "<nil>")")
		print("  info keys:  \(main.infoDictionary?.keys.sorted().joined(separator: ", ") ?? "<none>")")
	}

	// ====================================================================
	//  ENVIRONMENT CONSTRAINTS
	// ====================================================================

	private static func dumpEnvironmentConstraints() {
		section("ENVIRONMENT CONSTRAINTS")
		print("  platform:            Swift on Linux (Ubuntu 18.04 base), NOT Apple")
		print("  swift version:       5.1-release")
		print("  arch:                x86_64")
		print("  libc:                glibc 2.27")
		print("  objc interop:        DISABLED (-disable-objc-interop)")
		print("")
		print("  WORKING imports:")
		print("    Foundation, FoundationNetworking, FoundationXML,")
		print("    Dispatch, Glibc, XCTest, Swift")
		print("")
		print("  NOT AVAILABLE:")
		print("    UIKit, AppKit, SwiftUI, Combine, CoreData, Metal, ARKit,")
		print("    CoreLocation, CoreBluetooth, ObjectiveC, Darwin, MachO")
		print("")
		print("  NOTES:")
		print("    • No @objc, no NSObject bridging")
		print("    • URLSession requires FoundationNetworking")
		print("    • XMLParser requires FoundationXML")
		print("    • Bundle.allBundles / allFrameworks SEGFAULT on this build")
		print("    • Bundle.main works")
	}

	// ====================================================================
	//  SUBPROCESS HELPERS
	// ====================================================================

	private static func runCapture(_ path: String, args: [String]) -> String? {
		let task = Process()
		task.executableURL = URL(fileURLWithPath: path)
		task.arguments = args
		let pipe = Pipe()
		task.standardOutput = pipe
		task.standardError = Pipe()
		do { try task.run() } catch { return nil }
		let data = pipe.fileHandleForReading.readDataToEndOfFile()
		task.waitUntilExit()
		guard task.terminationStatus == 0 else { return nil }
		return String(data: data, encoding: .utf8)
	}

	private static func runAndWait(_ path: String, args: [String]) -> Int32? {
		let task = Process()
		task.executableURL = URL(fileURLWithPath: path)
		task.arguments = args
		task.standardOutput = Pipe()
		task.standardError = Pipe()
		do { try task.run() } catch { return nil }
		task.waitUntilExit()
		return task.terminationStatus
	}
}

DumpEverything.run()
