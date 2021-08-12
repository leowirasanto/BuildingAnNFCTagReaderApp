/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The view controller that scans and displays NDEF messages.
*/

import UIKit
import CoreNFC

/// - Tag: MessagesTableViewController
class MessagesTableViewController: UITableViewController, NFCTagReaderSessionDelegate {



    // MARK: - Properties

    let reuseIdentifier = "reuseIdentifier"
    var detectedMessages = [NFCNDEFMessage]()
    var session: NFCTagReaderSession?

    // MARK: - Actions

    /// - Tag: beginScanning
    @IBAction func beginScanning(_ sender: Any) {
        guard NFCTagReaderSession.readingAvailable else {
            let alertController = UIAlertController(
                title: "Scanning Not Supported",
                message: "This device doesn't support tag scanning.",
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            return
        }

        session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self)
        session?.alertMessage = "Hold your iPhone near the item to learn more about it."
        session?.begin()
    }

    // MARK: - NFCNDEFReaderSessionDelegate

    /// - Tag: processingTagData
    func readerSession(_ session: NFCTagReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        DispatchQueue.main.async {
            // Process detected NFCNDEFMessage objects.
            self.detectedMessages.append(contentsOf: messages)
            self.tableView.reloadData()
        }
    }

    /// - Tag: processingNDEFTag

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
    }

    func generateRandomBytes() -> Data? {
        var keyData = Data(count: 8)
        let result = keyData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 8, $0.baseAddress!)
        }

        if result == errSecSuccess {
            return keyData
        } else {
            return nil
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard !tags.isEmpty, let tag = tags.first else {
            session.alertMessage = "Tag not found!"
            DispatchQueue.global().asyncAfter(deadline: .now()) {
                session.restartPolling()
            }
            return
        }

        session.connect(to: tag) { error in
            if let error = error {
                print("Unable to connect to tag: \(error.localizedDescription)")
                session.invalidate(errorMessage: "Unable to connect to tag: \(error.localizedDescription)")
                return
            }

            if case .iso7816(let nfcTag) = tag {
                if #available(iOS 14.0, *) {

                    //Get Challenge
                    //Data Response: 8 bytes random number
                    //SW1/SW2: 90/00
//                    let getChallenge = NFCISO7816APDU(data: Data([
//                        0x00,
//                        0x84,
//                        0x00,
//                        0x00,
//                        0x08,
//                    ]))

                    guard /*let getChallengeApdu = getChallenge, */let trn = self.generateRandomBytes() else {
                        session.invalidate(errorMessage: "Unable to connect to tag")
                        return
                    }
//                    nfcTag.sendCommand(apdu: getChallengeApdu) { data, sw1, sw2, error in
//                        if error != nil {
//                            session.invalidate(errorMessage: "Try again: \(error?.localizedDescription ?? "")")
//                            return
//                        }
//                        debugPrint("Data from nfcTag: \(data), sw1/sw2: \(sw1)/\(sw2)")
//                        session.invalidate()
//                    }


                    let secureRead = NFCISO7816APDU.init(data: Data([
                        0x90,
                        0x32,
                        0x03,
                        0x00,
                        0x0A, 0x12, 0x01,
                                    trn[0],
                                    trn[1],
                                    trn[2],
                                    trn[3],
                                    trn[4],
                                    trn[5],
                                    trn[6],
                                    trn[7], 0x00]))

                    guard let secureApdu = secureRead else {
                        session.invalidate(errorMessage: "Unable to connect to tag")
                        return
                    }

                    nfcTag.sendCommand(apdu: secureApdu) { data, sw1, sw2, error in
                        if error != nil {
                            session.invalidate(errorMessage: "Try again: \(error?.localizedDescription ?? "")")
                            return
                        }

                        let dataKartuHexString = self.hexStrToByte(in: data.hexEncodedString())
                        let purseBalance = self.byteToHextString(in: dataKartuHexString, start: 3, end: 5).joined()
                        let saldo = UInt32(purseBalance, radix: 16) ?? 0

                        debugPrint("Saldo: \(saldo)")
                        debugPrint("Data from nfcTag: \(data), sw1/sw2: \(sw1)/\(sw2)")
                        session.invalidate()
                    }

                } else {
                    // Fallback on earlier versions
                    session.invalidate(errorMessage: "OS Not Supported")
                }

            }
        }
    }

    func byteToHextString(in strings: [String], start: Int, end: Int) -> ArraySlice<String> {
        let range = (start - 1)..<end
        let output = strings[range]
        return output
    }

    func hexStrToByte(in string: String) -> [String] {
        var hexStr = string
        if hexStr.lengthOfBytes(using: .utf8) % 2 > 0 {
            hexStr = "0" + hexStr
        }

        let byteLength = hexStr.lengthOfBytes(using: .utf8) / 2
        var buffer: [String] = []

        for i in 0...(byteLength - 1) {
            let start = hexStr.index(hexStr.startIndex, offsetBy: i * 2)
            let end = hexStr.index(hexStr.startIndex, offsetBy: i * 2 + 2)
            let range = start..<end

            let hexByte = hexStr[range]
            buffer.append(String(hexByte))
        }

        return buffer
    }
}

extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return self.map { String(format: format, $0) }.joined()
    }

    var bytes: [UInt8] {
        return [UInt8](self)
    }
}
