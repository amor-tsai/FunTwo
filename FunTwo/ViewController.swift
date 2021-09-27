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
    
    struct AudioConstants{
        static let AUDIO_BUFFER_SIZE = 8000
    }
    
    // setup audio model
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    lazy var graph:MetalGraph? = {
        return MetalGraph(mainView: self.view)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        // add in graphs for display
        graph?.addGraph(withName: "fft",
                        shouldNormalize: true,
                        numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/2)
        
        graph?.addGraph(withName: "time",
            shouldNormalize: false,
            numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE)
        
        // start up the audio model here, querying microphone
        audio.startMicrophoneProcessing(withFps: 5)
        
        //load the audio file
//        audio.startAudioPlayProcessing()
        
        //play the audio
        audio.play()
        
        // run the loop for updating the graph peridocially
        Timer.scheduledTimer(timeInterval: 0.2, target: self,
            selector: #selector(self.updateGraph),
            userInfo: nil,
            repeats: true)
        
//        self.Lable1.text = audio.fftData
        
        Timer.scheduledTimer(timeInterval: 0.2, target: self,
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
    }
    

}

