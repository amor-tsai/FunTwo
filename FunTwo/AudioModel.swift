//
//  AudioModel.swift
//  AudioLabSwift
//
//  Created by Eric Larson 
//  Copyright © 2020 Eric Larson. All rights reserved.
//

import Foundation
import Accelerate

class AudioModel {
    
    // MARK: Properties
    private var BUFFER_SIZE:Int
    private var WINDOW_SIZE:UInt = 7
    private var _lockInFrequency1:Float
    private var _lockInFrequency2:Float
    
    // thse properties are for interfaceing with the API
    // the user can access these arrays at any time and plot them if they like
    var timeData:[Float]
    var fftData:[Float]
    var lockInFrequency1:Float{//open to use with only getter function
        get{return self._lockInFrequency1}
    }
    var lockInFrequency2:Float{//open to use with only getter function
        get{return self._lockInFrequency2}
    }
    var timer:Timer?
    
    // MARK: Public Methods
    init(buffer_size:Int) {
        BUFFER_SIZE = buffer_size
        // anything not lazily instatntiated should be allocated here
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
        _lockInFrequency1 = 0.0
        _lockInFrequency2 = 0.0
        timer = nil
    }
    
    // public function for starting processing of microphone data
    func startMicrophoneProcessing(withFps:Double){
        // setup the microphone to copy to circualr buffer
        if let manager = self.audioManager{
            manager.inputBlock = self.handleMicrophone
            
            // repeat this fps times per second using the timer class
            //   every time this is called, we update the arrays "timeData" and "fftData"
            
            guard self.timer == nil else {
                return
            }
            self.timer = Timer.scheduledTimer(timeInterval: 1.0/withFps, target: self,
                                 selector: #selector(self.runEveryInterval),
                                 userInfo: nil,
                                 repeats: true)
        }
    }
    
    //Call this function to stop the timer
    func stopTimer() {
        self.timer?.invalidate()
        self.timer = nil
    }
    
    // You must call this when you want the audio to start being handled by our model
    func play(){
        if let manager = self.audioManager{
            manager.play()
        }
        print("it's playing")
    }
    
    // call this when you want the audio to pause being handled by this model
    func pause(){
        if let manager = self.audioManager{
            manager.pause()
        }
        print("it stops playing")
    }
    
    //Get the max frequency if the maximum value locates at the “index”
    func getFrequencyFromIndex(index:Int,data:[Float]) -> Float{
        if (index == 0) {
            return 0;
        }
        
        let f2 = Float(index) * self.frequencyResolution;
        let m1 = data[index - 1];
        let m2 = data[index];
        let m3 = data[index + 1];
        
        return(f2 + ((m1 - m3) / (m3+m1-2.0 * m2)) * self.frequencyResolution / 2.0);
    }
    
    //reset the two largest frequency detected to zero
    func lockFrequencyReset() {
        self._lockInFrequency2 = 0.0
        self._lockInFrequency1 = 0.0
    }
    
    //==========================================
    // MARK: Private Properties
    private lazy var audioManager:Novocaine? = {
        return Novocaine.audioManager()
    }()
    
    private lazy var fftHelper:FFTHelper? = {
        return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
    }()
    
    private lazy var frequencyResolution = {
        return Float(audioManager!.samplingRate)/Float(BUFFER_SIZE)
    }()
    
    private lazy var inputBuffer:CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    private lazy var peakFinder:PeakFinder? = {
        return PeakFinder.init(frequencyResolution: self.frequencyResolution)
    }()
    
    
    //==========================================
    // MARK: Private Methods
    // NONE for this model
    
    //==========================================
    // MARK: Model Callback Methods
    @objc
    private func runEveryInterval(){
        if inputBuffer != nil {
            // copy time data to swift array
            self.inputBuffer!.fetchFreshData(&timeData,
                                             withNumSamples: Int64(BUFFER_SIZE))
            
            // now take FFT
            fftHelper!.performForwardFFT(withData: &timeData,
                                         andCopydBMagnitudeToBuffer: &fftData)
            
            // at this point, we have saved the data to the arrays:
            //   timeData: the raw audio samples
            //   fftData:  the FFT of those same samples
            // the user can now use these variables however they like
            
            self.findTwoPeaksFromFFtData(windowSize: WINDOW_SIZE)
            self.findPeaksFromFFTData(windowSize: Int(WINDOW_SIZE))
        }
    }
    
    //==========================================
    // MARK: Audiocard Callbacks
    // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
    // and in swift this translates to:
    private func handleMicrophone (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {
        // copy samples from the microphone into circular buffer
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    }
    
    
    //find two peaks from the fftData
    private func findTwoPeaksFromFFtData(windowSize:UInt){
        if let arr = self.peakFinder?.getFundamentalPeaks(
            fromBuffer: &fftData,
            withLength: UInt(BUFFER_SIZE)/2,
            usingWindowSize: windowSize,
            andPeakMagnitudeMinimum: 0,
            aboveFrequency: 1.0){
            
            for i in 0..<arr.count {
                if let peakObj = arr[i] as? Peak {
                    print(
                        "the \(i) peak is \(peakObj.frequency) index of peak is \(peakObj.index) magnitude is \(peakObj.magnitude)"
                    )
                    if i==0,lockInFrequency1<peakObj.frequency {
                        _lockInFrequency1 = peakObj.frequency
                    }
                    if i==1,lockInFrequency2<peakObj.frequency {
                        _lockInFrequency2 = peakObj.frequency
                    }
                }
            }
        }
    }
    
    //
    private func findPeaksFromFFTData(windowSize:Int){
        var peaks = [Int]()
        for i in 0..<(BUFFER_SIZE/2-windowSize) {
            let mid = windowSize/2+i
            var maxValue:Float = 0.0
            var maxIndex:vDSP_Length = 0
            vDSP_maxvi(&(fftData[i]), 1, &maxValue, &maxIndex, vDSP_Length(windowSize));
            maxIndex += UInt(i)
//            print("max value is \(maxValue) and maxIndex is \(maxIndex)")
            if (mid == maxIndex)  {
                peaks.append(Int(maxIndex)+i*windowSize)
            }
        }
        print(peaks)
    }
    
        
}
