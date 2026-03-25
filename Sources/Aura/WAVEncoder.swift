import Foundation

enum WAVEncoder {
    static func wrapPCM16Mono(pcmData: Data, sampleRate: Int) -> Data {
        let byteRate = sampleRate * 2
        let blockAlign: UInt16 = 2
        let bitsPerSample: UInt16 = 16
        let dataSize = UInt32(pcmData.count)
        let chunkSize = UInt32(36) + dataSize

        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        data.append(contentsOf: chunkSize.littleEndianBytes)
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        data.append(contentsOf: UInt32(16).littleEndianBytes)
        data.append(contentsOf: UInt16(1).littleEndianBytes)
        data.append(contentsOf: UInt16(1).littleEndianBytes)
        data.append(contentsOf: UInt32(sampleRate).littleEndianBytes)
        data.append(contentsOf: UInt32(byteRate).littleEndianBytes)
        data.append(contentsOf: blockAlign.littleEndianBytes)
        data.append(contentsOf: bitsPerSample.littleEndianBytes)
        data.append("data".data(using: .ascii)!)
        data.append(contentsOf: dataSize.littleEndianBytes)
        data.append(pcmData)
        return data
    }

    static func wrapPCM16Mono(samples: [Float], sampleRate: Int) -> Data {
        wrapPCM16Mono(pcmData: pcm16Data(from: samples), sampleRate: sampleRate)
    }

    static func pcm16Data(from samples: [Float]) -> Data {
        var pcm = Data(capacity: samples.count * MemoryLayout<Int16>.size)
        for sample in samples {
            var intValue = Int16(max(-1, min(1, sample)) * Float(Int16.max))
            pcm.append(Data(bytes: &intValue, count: MemoryLayout<Int16>.size))
        }
        return pcm
    }
}

private extension FixedWidthInteger {
    var littleEndianBytes: [UInt8] {
        withUnsafeBytes(of: littleEndian) { Array($0) }
    }
}
