/*
See LICENSE folder for this sample's licensing information.

Abstract:
The view controller that scans and displays NDEF messages.
*/

import UIKit
import CoreNFC

struct CardInfo {
    let cardNumber: String
    let cardData: Data
    let balance: UInt32
    let maxBalanceLimit: UInt32
}

/// - Tag: MessagesTableViewController
class MessagesTableViewController: UITableViewController, NFCTagReaderSessionDelegate {

    let challenge: [UInt8] = [0x00, 0x84, 0x00, 0x00, 0x08]
    
    let secureRead: [UInt8] = [0x90, 0x32, 0x03, 0x00, 0x0A, 0x12, 0x01]
    let secureReadLength: UInt8 = 0x00
    
    let creditCommand: [UInt8] = [0x90, 0x36, 0x14, 0x01, 0x25, 0x03, 0x14, 0x02, 0x14, 0x03]
    let creditCommandLength: UInt8 = 0x18

    var readerRandom: [UInt8] = []
    var cardRandom: [UInt8] = []

    // MARK: - Properties

    let reuseIdentifier = "reuseIdentifier"
    var detectedMessages = [NFCNDEFMessage]()
    var session: NFCTagReaderSession?

    
    override func viewDidAppear(_ animated: Bool) {
        self.beginScanning(self)
    }
    
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

    func secureRead(session: NFCTagReaderSession, tag: NFCISO7816Tag, completion: @escaping ((_ card: CardInfo) -> Void)) {
        let card = self.cardRandom
        let reader = self.readerRandom

        var secureReadPurse: [UInt8] = self.secureRead
        secureReadPurse.append(contentsOf: reader)
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

            let balanceHex = data.subdata(in: 2..<5).hexString()
            let balance = UInt32(balanceHex, radix: 16) ?? 0

            let cardNumber = data.subdata(in: 8..<16).hexString()

            let maxLimitHex = data.subdata(in: 78..<81).hexString()
            let maxLimit = UInt32(maxLimitHex, radix: 16) ?? 0

            let cardData: [UInt8] = [
                0x00, 0x01,
                data[8], data[9], data[10], data[11], data[12], data[13], data[14], data[15],
                data[16], data[17], data[18], data[19], data[20], data[21], data[22], data[23],
                reader[0], reader[1], reader[2], reader[3], reader[4], reader[5], reader[6], reader[7],
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
            
            let cardInfo = CardInfo(
                cardNumber: cardNumber,
                cardData: Data(cardData),
                balance: balance,
                maxBalanceLimit: maxLimit
            )
            
            session.invalidate()
            completion(cardInfo)
        }
    }
    
    func updateCredit(session: NFCTagReaderSession, tag: NFCISO7816Tag, cardData: [UInt8], completion: @escaping (() -> Void)) {
        let reader = self.readerRandom
        
        // Sample cryptogram
        guard let cryptogramData = "060027102AC4791F00000000000000000AF5A63C2FA31C2FCE9EEDED503B4ED4".data(using: .hexadecimal) else {
            return
        }
        
        let cryptogram = [UInt8](cryptogramData)
        
        var writeCommand = self.creditCommand
        writeCommand.append(contentsOf: reader)
        writeCommand.append(contentsOf: cryptogram[16..<32])
        writeCommand.append(contentsOf: cryptogram[8..<16])
        writeCommand.append(creditCommandLength)
        
        guard let updateAPDU = NFCISO7816APDU.init(data: Data(writeCommand)) else {
            session.invalidate(errorMessage: "Unable to update balance")
            return
        }
        
        tag.sendCommand(apdu: updateAPDU) { data, sw1, sw2, error in
            guard error == nil, sw1 == 144, sw2 == 0 else {
                session.invalidate(errorMessage: "Try again: \(error?.localizedDescription ?? "")")
                return
            }
            
            debugPrint("Updated: \([UInt8](data))")
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
                    self.secureRead(session: session, tag: nfcTag) { card in
                        debugPrint("Card Number: \(card.cardNumber)")
                        debugPrint("Balance: \(card.balance)")
                        debugPrint("Max Balance Limit: \(card.maxBalanceLimit)")
                        debugPrint("Card Data: \(card.cardData)")
                        
                        self.updateCredit(session: session, tag: nfcTag, cardData: [UInt8](card.cardData)) {
                            
                        }
                    }
                }
                
                
            } else {
                // Fallback on earlier versions
                session.invalidate(errorMessage: "OS Not Supported")
            }
        }
    }
}

extension String {
    enum ExtendedEncoding {
        case hexadecimal
    }

    func data(using encoding: ExtendedEncoding) -> Data? {
        guard count % 2 == 0 else {
            return nil
        }
        
        var data: Data = .init(capacity: count / 2)
        
        var evenIndex = true
        for i in indices {
            if evenIndex {
                let byteRange = i...index(after: i)
                guard let byte = UInt8(self[byteRange], radix: 16) else {
                    return nil
                }
                data.append(byte)
            }
            evenIndex.toggle()
        }
        
        return data
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
