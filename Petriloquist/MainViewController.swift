//
//  MainViewController.swift
//  Petriloquist
//
//  Created by Kirill Shteffen on 29/03/2019.
//  Copyright © 2019 BlackBricks. All rights reserved.
//

import UIKit

class MainViewController: UIViewController {

    @IBOutlet weak var connectView: UIView!
    @IBOutlet weak var downloadView: UIView!
    
    @IBOutlet weak var listenButton: UIButton!
    @IBOutlet weak var talkButton: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let tapConnect = UITapGestureRecognizer(target: self, action: #selector(connectToDevice))
        connectView.addGestureRecognizer(tapConnect)
        
        let tapDownload = UITapGestureRecognizer(target: self, action: #selector(downloadVoice))
        downloadView.addGestureRecognizer(tapDownload)
        
        talkButton.addTarget(self, action:#selector(talkBtnPressed(_:)), for: .touchDown)
        //talkButton.addTarget(self, action:#selector(talkBtnReleased(_:)), for: .touchUpInside)
        
        
        
    }
    
    @objc func connectToDevice() {
        print("Start connecting...")
    }
    
    @objc func downloadVoice() {
        print("Start downloading...")
    }
    
    @objc func startVoiceRecording() {
        
            print("TALK PRESSED")
      
    }
    
    @objc func startVoiceListen() {
        print("LISTEN PRESSED")
    }
    
    @objc func talkButtonSelection() {
        talkButton.isSelected = true
    }
    
    @objc func talkBtnPressed(_ sender: Any) {
        perform(#selector(startVoiceRecording) , with: (Any).self, afterDelay: 0)
    }
    
    @objc func talkBtnReleased(_ sender: Any) {
        talkButton.isSelected = false
    }
}
