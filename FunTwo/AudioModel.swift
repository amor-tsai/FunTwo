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
    private var WINDOW_SIZE:UInt = 17
    private let SENSITIVE_FACTOR:Float = 2.0//to detect whether two fundamental frequencies equals, the abs(diff) should be equal SENSITIVE_FACTOR
    private var sin_wave_debug = false//switch control to open output
    private var piano_debug = true//piano test control to open output
    private var _lockInFrequency1:Float
    private var _lockInFrequency2:Float
//    private var piano_test = true
    private var piano_test = false//switch to control if we should open piano_test
    
    private let HARMONIC_COMPARE_NUM = 5//
    private var harmonicsCount:Int{
        didSet{
            if harmonicsCount == 0{
                _piano_fund_frequency_list = Array.init(repeating: 0.0, count: HARMONIC_COMPARE_NUM)
            }
        }
    }
    private var _piano_note:String
    private var _fund_frequency:Float// to display piano's fundamental frequency
    private var _piano_fund_frequency_list:[Float]
    
    //get from https://en.wikipedia.org/wiki/Piano_key_frequencies
    private let PIANO_NOTES_KEY_LIST = [
        75:"B6",
        74:"A♯6/B♭6",
        73:"A6",
        72:"G♯6/A♭6",
        71:"G6",
        70:"F♯6/G♭6",
        69:"F6",
        68:"E6",
        67:"D♯6/E♭6",
        66:"D6",
        65:"C♯6/D♭6",
        64:"C6 Soprano C",
        63:"B5",
        62:"A♯5/B♭5",
        61:"A5",
        60:"G♯5/A♭5",
        59:"G5",
        58:"F♯5/G♭5",
        57:"F5",
        56:"E5",
        55:"D♯5/E♭5",
        54:"D5",
        53:"C♯5/D♭5",
        52:"C5 Tenor C",
        51:"B4",
        50:"A♯4/B♭4",
        49:"A4",
        48:"G♯4/A♭4",
        47:"G4",
        46:"F♯4/G♭4",
        45:"F4",
        44:"E4",
        43:"D♯4/E♭4",
        42:"D4",
        41:"C♯4/D♭4",
        40:"C4",
        39:"B3",
        38:"A♯3/B♭3",
        37:"A3",
        36:"G♯3/A♭3",
        35:"G3",
        34:"F♯3/G♭3",
        33:"F3",
        32:"E3",
        31:"D♯3/E♭3",
        30:"D3",
        29:"C♯3/D♭3",
        28:"C3",
        27:"B2",
        26:"A♯2/B♭2",
        25:"A2"
    ]
    
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
    
    var fund_frequency:Float{// to get fundamental frequency in the piano note guessing game
        get{return self._fund_frequency}
    }
    
    var piano_note:String{// to get piano note
        get{return self._piano_note}
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
        harmonicsCount = 0
        _piano_note = "Let me guess..."
        _fund_frequency = 0.0
        _piano_fund_frequency_list = Array.init(repeating: 0.0, count: HARMONIC_COMPARE_NUM)
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
    
    //Call this function to stop the timer and reset the lock-in frequency to zero
    func stopTimer() {
        self.timer?.invalidate()
        self.timer = nil
        self.lockFrequencyReset()
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
    
    //return frequency of a sinwave, otherwise, return nil
    //
    func getFrequencyOfSinWaveFromFFtData(aboveFrequency:Float) -> Float? {
        if let arr = self.peakFinder?.getFundamentalPeaks(
            fromBuffer: &fftData,
            withLength: UInt(BUFFER_SIZE)/2,
            usingWindowSize: self.WINDOW_SIZE,
            andPeakMagnitudeMinimum: 0,
            aboveFrequency: aboveFrequency,
            belowFrequency: 0.0), let peakObj=arr[0] as? Peak {
            print("module b detected fre \(peakObj.frequency)")
            return peakObj.frequency
        }
        return nil
    }
    
    //play sinwave
    func startProcessingSinewaveForPlayback(withFreq:Float=330.0){
        let sineFrequency = withFreq
        // Two examples are given that use either objective c or that use swift
        //   the swift code for loop is slightly slower thatn doing this in c,
        //   but the implementations are very similar
        //self.audioManager?.outputBlock = self.handleSpeakerQueryWithSinusoid // swift for loop
        self.audioManager?.setOutputBlockToPlaySineWave(sineFrequency) // c for loop
    }
    
    //reset the two largest frequency detected to zero
    func lockFrequencyReset() {
        self._lockInFrequency2 = 0.0
        self._lockInFrequency1 = 0.0
    }
    
    //To open or close piano test
    // true to open piano test
    // false to close piano test
    func pianoTestSwitch(isOn:Bool) {
        self.piano_test = isOn
        if !self.piano_test {
            self._piano_note = ""
            self._fund_frequency = 0.0
        }
        
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
            
            //make element-add in each array of fftData for SUM_STEP times(I use online piano keyboard to test, and 15 times seem a proper result), so we could get the maximum frequency

            // at this point, we have saved the data to the arrays:
            //   timeData: the raw audio samples
            //   fftData:  the FFT of those same samples
            // the user can now use these variables however they like
            
            self.findTwoPeaksFromFFtData(windowSize: WINDOW_SIZE)
//            self.findPeaksFromFFTData(windowSize: Int(WINDOW_SIZE))
            if self.piano_test {
                self.pianoDetected(windowSize: WINDOW_SIZE)
            }
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
    //the frequency must be above 100Hz
    private func findTwoPeaksFromFFtData(windowSize:UInt){
        if let arr = self.peakFinder?.getFundamentalPeaks(
            fromBuffer: &fftData,
            withLength: UInt(BUFFER_SIZE)/2,
            usingWindowSize: windowSize,
            andPeakMagnitudeMinimum: 0,
            aboveFrequency: 100.0,
            belowFrequency: 0.0){
            
            for i in 0..<arr.count {
                if let peakObj = arr[i] as? Peak {
                    if sin_wave_debug {
                        print(
                            "the \(i) peak is \(peakObj.frequency) index of peak is \(peakObj.index) magnitude is \(peakObj.magnitude)"
                        )
                    }
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
//    private func findPeaksFromFFTData(windowSize:Int){
//        var peaks = [Int]()
//        for i in 0..<(BUFFER_SIZE/2-windowSize) {
//            let mid = windowSize/2+i
//            var maxValue:Float = 0.0
//            var maxIndex:vDSP_Length = 0
//            vDSP_maxvi(&(fftData[i]), 1, &maxValue, &maxIndex, vDSP_Length(windowSize));
//            maxIndex += UInt(i)
////            print("max value is \(maxValue) and maxIndex is \(maxIndex)")
//            if (mid == maxIndex)  {
//                peaks.append(Int(maxIndex)+i*windowSize)
//            }
//        }
//        if peaks.count > 0{
//            print(peaks)
//        }
//    }
    
    //To detect piano notes
    //only support from A2 to B6
    private func pianoDetected(windowSize:UInt) {
//        if sumStepCount<SUM_STEP {return}
        if let arr = self.peakFinder?.getFundamentalPeaks(
            fromBuffer: &fftData,
            withLength: UInt(BUFFER_SIZE)/2,
            usingWindowSize: windowSize,
            andPeakMagnitudeMinimum: 0,
            aboveFrequency: 80.0,
            belowFrequency: 2000.0), let peakObj = arr[0] as? Peak {
//            print("Peaks count: \(arr.count)")
//            for i in 0..<arr.count {
//                if let peakObj = arr[i] as? Peak {
//                    print("index \(peakObj.index) fre \(peakObj.frequency) maganitude \(peakObj.magnitude) multiple \(peakObj.multiple)")
//                }
//            }
            if harmonicsCount == 0{
                _piano_fund_frequency_list[harmonicsCount] = peakObj.frequency
            }else {
                for i in 0..<harmonicsCount{
                    if abs(peakObj.frequency - _piano_fund_frequency_list[i]) > SENSITIVE_FACTOR {
                        print("fund_list \(_piano_fund_frequency_list) curr fre \(peakObj.frequency)")
                        harmonicsCount = 0
                        return
                    }
                }
                _piano_fund_frequency_list[harmonicsCount] = peakObj.frequency
            }
            harmonicsCount += 1
            if harmonicsCount == HARMONIC_COMPARE_NUM {
                _piano_note = self.getPianoNoteByFundamentalFrequency(frequency: peakObj.frequency)
                _fund_frequency = peakObj.frequency
                harmonicsCount = 0
            }
            if piano_debug {
                print("index \(peakObj.index) fre \(peakObj.frequency) maganitude \(peakObj.magnitude) multiple \(peakObj.multiple)")
            }
//                print("peaks count \(arr.count)")
            }
    }
    
    //Given a fundamental frequency, use formula 12*log2(frequency/440)+49 to get its key(suggested by wiki)
    //I may use only 25(A2) to 76(B6), because they may occur in a regular online piano keyboard
    private func getPianoNoteByFundamentalFrequency(frequency:Float) -> String {
        if frequency > 100{
            let key = Int(12*log2(frequency/440) + 49)
            if let note = PIANO_NOTES_KEY_LIST[key] {
                return note
            } else {
                return "\(key) my keys only contain between 25(A2) to 76(B6)"
            }
        }
        return ""
    }
}
