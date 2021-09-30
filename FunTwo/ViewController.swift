//
//  ViewController.swift
//  FunTwo
//
//  Created by Amor on 2021/9/23.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var Lable1: UILabel!
    @IBOutlet weak var Label2: UILabel!
    @IBOutlet weak var ResetButton: UIButton!
    @IBOutlet weak var CurrHZLable: UILabel!
    @IBOutlet weak var PianoNoteLable: UILabel!
    
    struct AudioConstants{
        static let AUDIO_BUFFER_SIZE = 1024*16
        static let FPS:Double = 20.0
    }
    
    // setup audio model
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    lazy var graph:MetalGraph? = {
        return MetalGraph(mainView: self.view)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        //reset button ui style
        ResetButton.backgroundColor = .clear
        ResetButton.setTitleColor(UIColor.black, for: .normal)
        ResetButton.layer.cornerRadius = 5
        ResetButton.layer.borderWidth = 1
        ResetButton.layer.borderColor = UIColor.black.cgColor
        
        // add in graphs for display
//        graph?.addGraph(withName: "fft",
//                        shouldNormalize: true,
//                        numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/2)
//
//        graph?.addGraph(withName: "time",
//            shouldNormalize: false,
//            numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE)
        
        // start up the audio model here, querying microphone
        audio.startMicrophoneProcessing(withFps: AudioConstants.FPS)
        
        //play the audio
        audio.play()
        
        
        // run the loop for updating the graph peridocially
//        Timer.scheduledTimer(timeInterval: 1/AudioConstants.FPS, target: self,
//            selector: #selector(self.updateGraph),
//            userInfo: nil,
//            repeats: true)
        
        Timer.scheduledTimer(timeInterval: 1/AudioConstants.FPS, target: self,
            selector: #selector(self.updateFrequency),
            userInfo: nil,
            repeats: true)
        
    }
    
    //when the view disappear, pause the audio and stop the timer in the audio module
    override func viewDidDisappear(_ animated: Bool) {
        audio.pause()
        audio.stopTimer()
    }
    
    // periodically, update the graph with refreshed FFT Data
    @objc
    func updateGraph(){
        self.graph?.updateGraph(
            data: self.audio.fftData,
            forKey: "fft"
        )
        
        self.graph?.updateGraph(
            data: self.audio.timeData,
            forKey: "time"
        )
    }
    
    @objc
    func updateFrequency(){
        self.Lable1.text = "1st frequency \(audio.lockInFrequency1)"
        self.Label2.text = "2nd largest frequency \(audio.lockInFrequency2)"
        self.CurrHZLable.text = "fundamental frequency: \(audio.fund_frequency)"
        self.PianoNoteLable.text = audio.piano_note
    }
    
    //when tap the button, reset the lock-in frequency to zero
    @IBAction func ResetLockInFrequency(_ sender: Any) {
        audio.lockFrequencyReset()
    }
    
    
}

