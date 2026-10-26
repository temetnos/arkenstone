import Foundation
import IOKit

public struct FanData: Equatable {
    public var count: Int = 0
    public var speeds: [Int] = []
    public var isFanless: Bool = true
    
    public init(count: Int = 0, speeds: [Int] = [], isFanless: Bool = true) {
        self.count = count
        self.speeds = speeds
        self.isFanless = isFanless
    }
}

public class SMCFanReader {
    public static let shared = SMCFanReader()
    
    private struct SMCVersion { var major: UInt8 = 0; var minor: UInt8 = 0; var build: UInt8 = 0; var reserved: UInt8 = 0; var release: UInt16 = 0 }
    private struct SMCPLimitData { var version: UInt16 = 0; var length: UInt16 = 0; var cpuPLimit: UInt32 = 0; var gpuPLimit: UInt32 = 0; var memPLimit: UInt32 = 0 }
    private struct SMCKeyInfoData { var dataSize: UInt32 = 0; var dataType: UInt32 = 0; var dataAttributes: UInt8 = 0 }

    private struct SMCKeyData {
        var key: UInt32 = 0
        var vers = SMCVersion()
        var pLimitData = SMCPLimitData()
        var keyInfo = SMCKeyInfoData()
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
            (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    }
    
    public init() {}
    
    public func readFans() -> FanData {
        var conn: io_connect_t = 0
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else {
            return FanData(count: 0, speeds: [], isFanless: true)
        }
        defer { IOObjectRelease(service) }
        
        guard IOServiceOpen(service, mach_task_self_, 0, &conn) == kIOReturnSuccess else {
            return FanData(count: 0, speeds: [], isFanless: true)
        }
        defer { IOServiceClose(conn) }
        
        guard let fnumRes = readKey("FNum", conn: conn), let firstByte = fnumRes.bytes.first, firstByte > 0 else {
            return FanData(count: 0, speeds: [], isFanless: true)
        }
        
        let totalFans = Int(firstByte)
        var speeds: [Int] = []
        
        for i in 0..<totalFans {
            if let speedRes = readKey("F\(i)Ac", conn: conn) {
                if speedRes.bytes.count >= 2 {
                    let raw = (UInt16(speedRes.bytes[0]) << 8) | UInt16(speedRes.bytes[1])
                    speeds.append(Int(raw >> 2))
                } else if speedRes.bytes.count >= 4 {
                    let fVal = speedRes.bytes.withUnsafeBytes { $0.load(as: Float.self) }
                    speeds.append(Int(fVal))
                }
            }
        }
        
        return FanData(count: totalFans, speeds: speeds, isFanless: totalFans == 0)
    }
    
    private func readKey(_ keyStr: String, conn: io_connect_t) -> (size: Int, bytes: [UInt8])? {
        guard keyStr.count == 4 else { return nil }
        var keyInt: UInt32 = 0
        for byte in keyStr.utf8 {
            keyInt = (keyInt << 8) | UInt32(byte)
        }
        
        var input = SMCKeyData()
        input.key = keyInt
        input.data8 = 9 // SMC_CMD_READ_KEYINFO
        
        var output = SMCKeyData()
        var outputSize = MemoryLayout<SMCKeyData>.stride
        
        guard IOConnectCallStructMethod(conn, 2, &input, MemoryLayout<SMCKeyData>.stride, &output, &outputSize) == kIOReturnSuccess else {
            return nil
        }
        
        let dataSize = Int(output.keyInfo.dataSize)
        guard dataSize > 0 && dataSize <= 32 else { return nil }
        
        input.keyInfo = output.keyInfo
        input.data8 = 5 // SMC_CMD_READ_BYTES
        
        output = SMCKeyData()
        outputSize = MemoryLayout<SMCKeyData>.stride
        guard IOConnectCallStructMethod(conn, 2, &input, MemoryLayout<SMCKeyData>.stride, &output, &outputSize) == kIOReturnSuccess else {
            return nil
        }
        
        let mirror = Mirror(reflecting: output.bytes)
        let byteArr = mirror.children.prefix(dataSize).compactMap { $0.value as? UInt8 }
        return (dataSize, byteArr)
    }
}
