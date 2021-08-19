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
    var session: NFCTagReaderSession?
    let commands = NFCCommands()

    var readerRandom: [UInt8] = []
    var cardRandom: [UInt8] = []

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNFCSession()
    }

    private func setupNFCSession() {
        guard NFCTagReaderSession.readingAvailable else {
            showAlert(message: "NFC Not supported")
            return
        }

        session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self)
        session?.alertMessage = "Hold your iPhone near the item to learn more about it."
        session?.begin()
    }

    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: { _ in
            alert.dismiss(animated: false, completion: nil)
        }))
        self.present(alert, animated: false, completion: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        debugPrint("session activated")
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        session.invalidate(errorMessage: error.localizedDescription)
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        /// Init function
        let hexStrToByte = Utility.default.hexStrToByte
        let byteToHexStr = Utility.default.byteToHexStr
        let generateRandomBytes = Utility.default.generateRandomBytes()

        guard !tags.isEmpty, let tag = tags.first else {
            session.alertMessage = "Tag not found!"
            DispatchQueue.global().asyncAfter(deadline: .now()) {
                session.restartPolling()
            }
            return
        }

        session.connect(to: tag) { error in
            if error != nil {
                session.invalidate(errorMessage: "Connection error: \(error?.localizedDescription)")
                return
            }

            if case let .iso7816(nfcTag) = tag {
                self.readChallenge(session: session, nfcTag: nfcTag) {
                    <#code#>
                }
            } else {
                session.invalidate(errorMessage: "Unsupported tag")
            }
        }

    }

    // Step 1: Read Challenge
    func readChallenge(session: NFCTagReaderSession, nfcTag: NFCISO7816Tag, completion: (() -> Void)) {
        guard let challengeAPDU = NFCISO7816APDU(data: Data(self.commands.challenge)) else {
            session.invalidate()
            self.showAlert(message: "Incorrect commands")
            return
        }
        nfcTag.sendCommand(apdu: challengeAPDU) { responseData, sw1, sw2, error in
            guard error == nil && (sw1 == 144 && sw2 == 0) else {
                    session.invalidate(errorMessage: "Connection error: \(error?.localizedDescription)")
                    return
            }

        }
    }

    // Step 2: Secure Read
    func secureRead(session: NFCTagReaderSession, nfcTag: NFCISO7816Tag, completion: (() -> Void)) {

    }
}

struct NFCCommands {
    /// Challenge APDU
    let challenge: [UInt8] = [0x00, 0x84, 0x00, 0x00, 0x08]

    /// Secure Read
    let secureRead: [UInt8] = [0x90, 0x32, 0x03, 0x00, 0x0A, 0x12, 0x01]
    let secureReadLength: UInt8 = 0x00

    ///Write
    let creditCommand: [UInt8] = [0x90, 0x36, 0x14, 0x01, 0x25, 0x03, 0x14, 0x02, 0x14, 0x03]
    let creditCommandLength: UInt8 = 0x18

}

open class Utility {

    public static let `default` = Utility()

    open func generateRandomBytes() -> Data? {

        var keyData = Data(count: 8)
        let result = keyData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 8, $0.baseAddress!)
        }
        if result == errSecSuccess {
            return keyData
        } else {
            print("Problem generating random bytes")
            return nil
        }
    }

    open func byteToHexStr(inString: [String], start: Int, end: Int) -> ArraySlice<String> {
        let range = start-1..<end
        let outb = inString[range]
        return outb
    }

    open func hexStrToByte(inStr: String) -> [String] {
        var hexStr = inStr
        if (hexStr.lengthOfBytes(using: .utf8) % 2 > 0) {
            hexStr = "0" + hexStr
        }

        let byteLen = hexStr.lengthOfBytes(using: .utf8)/2
        var outBuff = [String]()
        for i in 0...(byteLen-1) {
            let start = hexStr.index(hexStr.startIndex, offsetBy: i * 2)
            let end = hexStr.index(hexStr.startIndex, offsetBy: i * 2 + 2)
            let range = start..<end

            let hexByte = hexStr[range]
            let myString = String(hexByte)
            outBuff.append(myString)
        }
        return outBuff
    }

}
