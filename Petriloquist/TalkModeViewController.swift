//
//  TalkModeViewController.swift
//  Petriloquist
//
//  Created by Kirill Shteffen on 11/04/2019.
//  Copyright © 2019 BlackBricks. All rights reserved.
//

import UIKit

class TalkModeViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    func close() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func closeTalkMode(_ sender: UIButton) {
        close()
    }
    
    
}
