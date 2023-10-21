//
//  AudioConverter.swift
//  ClassTranscribe
//
//  Created by Youssef Dbouk on 10/20/23.
//

import AudioKit
import Foundation

class AudioConverter {
    static func convertAudioFileToPCMArray(fileURL: URL) -> [Float] {
        var options = FormatConverter.Options()
        options.format = .wav
        options.sampleRate = 16000
        options.bitDepth = 16
        options.channels = 1
        options.isInterleaved = false

        var floats: [Float]?
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let converter = FormatConverter(inputURL: fileURL, outputURL: tempURL, options: options)
        converter.start { error in
            if let error {
                print(error)
                return // TODO: implement error handling
            }

            let data = try! Data(contentsOf: tempURL) // Handle error here

            floats = stride(from: 44, to: data.count, by: 2).map {
                return data[$0..<$0 + 2].withUnsafeBytes {
                    let short = Int16(littleEndian: $0.load(as: Int16.self))
                    return max(-1.0, min(Float(short) / 32767.0, 1.0))
                }
            }

            try? FileManager.default.removeItem(at: tempURL)
        }
        return floats!
    }
}
