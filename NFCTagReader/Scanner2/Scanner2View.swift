//
//  Scanner2View.swift
//  NFCTagReader
//
//  Created by Leo on 19/08/21.
//  Copyright © 2021 Apple. All rights reserved.
//

import CoreNFC
import Foundation
import UIKit

class Scanner2View: UIViewController, NFCTagReaderSessionDelegate {
    let 

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        <#code#>
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        <#code#>
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        <#code#>
    }
}
