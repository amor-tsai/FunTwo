//
//  CTViewController.swift
//  FunTwo
//
//  Created by Amor on 2021/10/1.
//

import Foundation
import UIKit

// It's for Third.storyboard
class CTViewController:UIViewController{
    struct AudioConstants{
        static let AUDIO_BUFFER_SIZE = 1024*16
        static let FPS:Double = 20.0
    }
    
    @IBOutlet weak var CurrHZLable: UILabel!
    @IBOutlet weak var ActionDetectionLable: UILabel!
    
    
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
        
        audio.startProcessingSinewaveForPlayback(withFreq: 20000.0)
        
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
            selector: #selector(self.updateGraph),
            userInfo: nil,
            repeats: true)
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        audio.pause()
        audio.stopTimer()
    }
    
    
    @IBAction func SliderDidChanged(_ sender: UISlider) {
        self.CurrHZLable.text = "\(sender.value)"
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
        
//        audio.getFrequencyOfSinWaveFromFFtData(aboveFrequency: 10000.0)
    }
    
}
