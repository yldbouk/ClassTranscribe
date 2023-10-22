//
//  AudioConverter.swift
//  ClassTranscribe
//
//  Created by Youssef Dbouk on 10/20/23.
//  Some code is from AudioKit. Thanks
//

import Foundation
import AVFoundation

class FormatConverter {
    static func convertAudioFileToPCMArray(inputURL: URL) -> [Float]! {

        var inputFile: ExtAudioFileRef?
        var outputFile: ExtAudioFileRef?

        func closeFiles() {
            if let strongFile = inputFile {
                if noErr != ExtAudioFileDispose(strongFile) {
                    print("Error disposing input file, could have a memory leak")
                }
            }
            inputFile = nil

            if let strongFile = outputFile {
                if noErr != ExtAudioFileDispose(strongFile) {
                    print("Error disposing output file, could have a memory leak")
                }
            }
            outputFile = nil
        }

        // make sure these are closed on any exit to avoid leaking the file objects
        defer {
            closeFiles()
        }

        if noErr != ExtAudioFileOpenURL(inputURL as CFURL, &inputFile) {
            print("Unable to open the input file.")
            return nil
        }

        guard let strongInputFile = inputFile else {
            print("Unable to open the input file.")
            return nil
        }

        var inputDescription = AudioStreamBasicDescription()
        var inputDescriptionSize = UInt32(MemoryLayout.stride(ofValue: inputDescription))

        if noErr != ExtAudioFileGetProperty(strongInputFile,
                                            kExtAudioFileProperty_FileDataFormat,
                                            &inputDescriptionSize,
                                            &inputDescription)
        {
            print("Unable to get the input file data format.")
            return nil
        }

        var outputDescription = createOutputDescription(inputDescription: inputDescription)
        
        guard 
            inputURL.pathExtension.lowercased() != ".wav"  ||
            inputDescription.mSampleRate        != 16000   ||
            inputDescription.mChannelsPerFrame  != 1       ||
            inputDescription.mBitsPerChannel    != 16
        else {
            print("No conversion is needed, formats are the same.")
            return waveToPCMArray(outputURL: inputURL)
        }

        
        // Create destination file
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        print("Converting to \(outputURL)")
        if noErr != ExtAudioFileCreateWithURL(outputURL as CFURL,
                                              kAudioFileWAVEType,
                                              &outputDescription,
                                              nil,
                                              AudioFileFlags.eraseFile.rawValue, // overwrite old file if present
                                              &outputFile)
        {
            print("Unable to create output file at \(outputURL.path). " +
                                "dstFormat \(outputDescription)")
            return nil
        }

        guard let strongOutputFile = outputFile else {
            print("Output file is nil.")
            return nil
        }

        // The format must be linear PCM (kAudioFormatLinearPCM).
        // You must set this in order to encode or decode a non-PCM file data format.
        // You may set this on PCM files to specify the data format used in your calls
        // to read/write.
        if noErr != ExtAudioFileSetProperty(strongInputFile,
                                            kExtAudioFileProperty_ClientDataFormat,
                                            inputDescriptionSize,
                                            &outputDescription)
        {
            print("Unable to set data format on input file.")
            return nil
        }

        if noErr != ExtAudioFileSetProperty(strongOutputFile,
                                            kExtAudioFileProperty_ClientDataFormat,
                                            inputDescriptionSize,
                                            &outputDescription)
        {
            print("Unable to set the output file data format.")
            return nil
        }
        let bufferByteSize: UInt32 = 32768
        var srcBuffer = [UInt8](repeating: 0, count: Int(bufferByteSize))
        var sourceFrameOffset: UInt32 = 0

        srcBuffer.withUnsafeMutableBytes { body in
            while true {
                let mBuffer = AudioBuffer(mNumberChannels: inputDescription.mChannelsPerFrame,
                                          mDataByteSize: bufferByteSize,
                                          mData: body.baseAddress)

                var fillBufList = AudioBufferList(mNumberBuffers: 1,
                                                  mBuffers: mBuffer)
                var frameCount: UInt32 = 0

                if outputDescription.mBytesPerFrame > 0 {
                    frameCount = bufferByteSize / outputDescription.mBytesPerFrame
                }

                if noErr != ExtAudioFileRead(strongInputFile,
                                             &frameCount,
                                             &fillBufList)
                {
                    print("Error reading from the input file.")
                    return
                }
                // EOF
                if frameCount == 0 { break }

                sourceFrameOffset += frameCount

                if noErr != ExtAudioFileWrite(strongOutputFile,
                                              frameCount,
                                              &fillBufList)
                {
                    print("Error reading from the output file.")
                    return
                }
            }
        }
        closeFiles()

        let floats = waveToPCMArray(outputURL: outputURL)
        try? FileManager.default.removeItem(at: outputURL)
        return floats
    }
    
    
    
    
    
    
    
    
    
    
    
    
    static func createOutputDescription(inputDescription: AudioStreamBasicDescription) -> AudioStreamBasicDescription
    {
        let mFormatID: AudioFormatID = kAudioFormatLinearPCM

        let mSampleRate = 16000
        let mChannelsPerFrame = 1
        var mBitsPerChannel = 16
        
        // For example: don't allow upsampling to 24bit if the src is 16
        if inputDescription.mBitsPerChannel < 16 {
            mBitsPerChannel = Int(inputDescription.mBitsPerChannel)
        }

        var mBytesPerFrame = mBitsPerChannel / 8
        var mBytesPerPacket = mBytesPerFrame

        if mBitsPerChannel == 0 {
            mBitsPerChannel = 16
            mBytesPerPacket = 2
            mBytesPerFrame = 2
        }

        var mFormatFlags: AudioFormatFlags = kLinearPCMFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger

        if true, mBitsPerChannel == 8 {
            // if is 8 BIT PER CHANNEL, remove kAudioFormatFlagIsSignedInteger
            mFormatFlags &= ~kAudioFormatFlagIsSignedInteger
        }

        return AudioStreamBasicDescription(
                   mSampleRate: Float64(mSampleRate),
                   mFormatID: mFormatID,
                   mFormatFlags: mFormatFlags,
                   mBytesPerPacket: UInt32(mBytesPerPacket),
                   mFramesPerPacket: 1,
                   mBytesPerFrame: UInt32(mBytesPerFrame),
                   mChannelsPerFrame: UInt32(mChannelsPerFrame),
                   mBitsPerChannel: UInt32(mBitsPerChannel),
                   mReserved: 0)
    }
    
    
    
    private static func waveToPCMArray(outputURL: URL) -> [Float] {
        let data = try! Data(contentsOf: outputURL) // Handle error here

        let floats = stride(from: 44, to: data.count, by: 2).map {
            return data[$0..<$0 + 2].withUnsafeBytes {
                let short = Int16(littleEndian: $0.load(as: Int16.self))
                return max(-1.0, min(Float(short) / 32767.0, 1.0))
            }
        }
        return floats
    }
}
