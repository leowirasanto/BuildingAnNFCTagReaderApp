/*
See LICENSE folder for this sample's licensing information.

Abstract:
The view controller that scans and displays NDEF messages.
*/

import UIKit
import CoreNFC

/// - Tag: MessagesTableViewController
class MessagesTableViewController: UITableViewController, NFCTagReaderSessionDelegate {

    let challenge: [UInt8] = [0x00, 0x84, 0x00, 0x00, 0x08]
    let secureRead: [UInt8] = [0x90, 0x32, 0x03, 0x00, 0x0A, 0x12, 0x01]
    let secureReadLength: UInt8 = 0x00

    var readerRandom: [UInt8] = []
    var cardRandom: [UInt8] = []

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

    func getRandomBytes(count: Int = 8) -> Data? {
        var keyData = Data(count: count)
        let result = keyData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!)
        }

        if result == errSecSuccess {
            return keyData
        } else {
            return nil
        }
    }

    func challenge(session: NFCTagReaderSession, tag: NFCISO7816Tag, completion: @escaping (() -> Void)) {
        guard let challengeAPDU = NFCISO7816APDU(data: Data(self.challenge)) else {
            session.invalidate(errorMessage: "Unable to challenge")
            return
        }

        tag.sendCommand(apdu: challengeAPDU) { data, sw1, sw2, error in
            guard error == nil, sw1 == 144, sw2 == 0 else {
                session.invalidate(errorMessage: "Try again: \(error?.localizedDescription ?? "")")
                return
            }

            self.cardRandom = [UInt8](data)
            completion()
        }
    }

    func secureRead(session: NFCTagReaderSession, tag: NFCISO7816Tag, completion: @escaping ((_ secureReadPurse: [UInt8]) -> Void)) {
        var secureReadPurse: [UInt8] = self.secureRead
        secureReadPurse.append(contentsOf: self.readerRandom)
        secureReadPurse.append(self.secureReadLength)

        guard let secureAPDU = NFCISO7816APDU.init(data: Data(secureReadPurse)) else {
            session.invalidate(errorMessage: "Unable to read balance")
            return
        }

        tag.sendCommand(apdu: secureAPDU) { data, sw1, sw2, error in
            guard error == nil, sw1 == 144, sw2 == 0 else {
                session.invalidate(errorMessage: "Try again: \(error?.localizedDescription ?? "")")
                return
            }

            let balanceHex = data.subdata(in: 3..<5).hexString()
            let balance = UInt32(balanceHex, radix: 16) ?? 0

            debugPrint("Saldo: \(balance)")
            completion(secureReadPurse)
        }
    }

    func writeRequest(session: NFCTagReaderSession, tag: NFCISO7816Tag, secureReadPurse: [UInt8]) {
        var request = secureReadPurse[0..<5]
        request.append(contentsOf: [0x18, 0x01])
        request.append(contentsOf: self.readerRandom)

        debugPrint("Write Request: \(request)")

        guard let writeRequestAPDU = NFCISO7816APDU(data: Data(request)) else {
            session.invalidate(errorMessage: "Unable to connect to tag")
            return
        }

        tag.sendCommand(apdu: writeRequestAPDU) { data, sw1, sw2, error in
            guard error == nil, sw1 == 144, sw2 == 0 else {
                session.invalidate(errorMessage: "Try again: \(error?.localizedDescription ?? "")")
                return
            }

            let cardNumber = data.subdata(in: 8..<16)
            debugPrint("Card number: \(cardNumber.hexString())")

            let cardBalance = data.subdata(in: 2..<5)
            let balance = UInt32(cardBalance.hexString(), radix: 16) ?? 0
            debugPrint("Card balance: \(balance)")

            let maxBalanceLimit = data.subdata(in: 78..<81)
            let maxBalance = UInt32(maxBalanceLimit.hexString(), radix: 16) ?? 0
            debugPrint("Max Balance Limit: \(maxBalance)")

            let random = self.readerRandom
            let card = self.cardRandom

            let cardData: [UInt8] = [
                0x00, 0x00,
                data[8], data[9], data[10], data[11], data[12], data[13], data[14], data[15],
                data[16], data[17], data[18], data[19], data[20], data[21], data[22], data[23],
                random[0], random[1], random[2], random[3], random[4], random[5], random[6], random[7],
                card[0], card[1], card[2], card[3], card[4], card[5], card[6], card[7],
                0x00, 0x00, 0x00, 0x00,
                data[1],
                data[2], data[3], data[4],
                data[28], data[29], data[30], data[31],
                data[32], data[33], data[34], data[35], data[36], data[37], data[38], data[39],
                data[42], data[43], data[44], data[45],
                data[46], data[47], data[48], data[49], data[50], data[51], data[52], data[53],
                data[54], data[55], data[56], data[57], data[58], data[59], data[60], data[61],
                data[63],
                data[94],
                data[95], data[96], data[97], data[98], data[99], data[100], data[101], data[102],
                data[103], data[104], data[105], data[106], data[107], data[108], data[109], data[110]
            ]

            debugPrint(cardData)
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

            if case let .iso7816(nfcTag) = tag {
                guard let random = self.getRandomBytes() else {
                    session.invalidate(errorMessage: "Unable to challenge")
                    return
                }

                self.readerRandom = [UInt8](random)

                self.challenge(session: session, tag: nfcTag) {
                    self.secureRead(session: session, tag: nfcTag) {
                        self.writeRequest(session: session, tag: nfcTag, secureReadPurse: $0)
                    }
                }

            } else {
                // Fallback on earlier versions
                session.invalidate(errorMessage: "OS Not Supported")
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
    func hexString() -> String {
        return self.map { String(format: "%02hhx", $0) }.joined()
    }

    var bytes: [UInt8] {
        return [UInt8](self)
    }
}
