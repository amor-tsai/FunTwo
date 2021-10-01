//
//  GViewController.swift
//  FunTwo
//
//  Created by Amor on 2021/9/24.
//

import Foundation
import UIKit
import AVFoundation
import CoreAudio

// As a ViewController of the SecondVC view in the Second Story Board
class GViewController: UIViewController {
    let myUnit = ToneOutputUnit()
    @IBOutlet weak var textDB: UILabel!
    @IBOutlet weak var dB: UILabel!
    @IBOutlet weak var HZ: UILabel!
    @IBOutlet weak var hzValue: UILabel!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var frequency: UILabel!
    @IBOutlet weak var objectPosition: UILabel!
    
    var recorder: AVAudioRecorder!
    var levelTimer = Timer()
    var trueDB: Float = 0.00
    let LEVEL_THRESHOLD: Float = -10.0
    struct AudioConstants{
        static let AUDIO_BUFFER_SIZE = 1024*16
        static let FPS:Double = 20.0
    }
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    
    @IBOutlet weak var pause: UIButton!
    @IBAction func pausePressed(_ sender: Any) {
        myUnit.stop()
    }
    
    @IBAction func sliderDidSlide(_ sender: UISlider) {
        let value = sender.value
        self.hzValue.text = String(value)
        myUnit.setFrequency(freq: Double(value))
        myUnit.enableSpeaker()
        myUnit.setToneTime(t: 20000)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        pause.backgroundColor = .clear
        self.textDB.text = "dB:"
        let documents = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0])
        let url = documents.appendingPathComponent("record.caf")

        let recordSettings: [String: Any] = [
            AVFormatIDKey:              kAudioFormatAppleIMA4,
            AVSampleRateKey:            44100.0,
            AVNumberOfChannelsKey:      2,
            AVEncoderBitRateKey:        12800,
            AVLinearPCMBitDepthKey:     16,
            AVEncoderAudioQualityKey:   AVAudioQuality.max.rawValue
        ]

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSession.Category.playAndRecord)
            try audioSession.setActive(true)
            try recorder = AVAudioRecorder(url:url, settings: recordSettings)

        } catch {
            return
        }

        recorder.prepareToRecord()
        recorder.isMeteringEnabled = true
        recorder.record()

        levelTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(levelTimerCallback), userInfo: nil, repeats: true)

        // start up the audio model here, querying microphone
        audio.startMicrophoneProcessing(withFps: AudioConstants.FPS)
        
        //play the audio
        audio.play()
        
        Timer.scheduledTimer(timeInterval: 0.3, target: self,
            selector: #selector(self.updateDoppler),
            userInfo: nil,
            repeats: true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        recorder.stop()
    }
    
    var prevFreq : Float = 0.0
    var movementThreshhold : Float = 10
    @objc func updateDoppler(){
        let newFreq : Float = audio.getFrequencyOfSinWaveFromFFtData(aboveFrequency: 16000) ?? 0.0
        self.frequency.text = String(newFreq)
        if newFreq > prevFreq + movementThreshhold{
            self.objectPosition.text = "Approching!"
        }else if newFreq < prevFreq - movementThreshhold{
            self.objectPosition.text = "Going Away!"
        }else{
            self.objectPosition.text = "Not Moving."
        }
        prevFreq = newFreq
    }
    
    
    @objc func levelTimerCallback() {
        recorder.updateMeters()
        let level = recorder.averagePower(forChannel: 0)
        trueDB = level + 60.0
        self.dB.text = String(trueDB)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    
}
