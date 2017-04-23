import Foundation
import CFNetwork
import UIKit

let printerIP: CFString = "192.168.0.34" as NSString /*Printer IP address*/
let printerPort: UInt32 = 9100 /*Do not change unless you want to use a different protcol*/

public class SwiftSock: NSObject {
    var addr:CFString
    var port:UInt32
    private var writeStream:Unmanaged<CFWriteStream>?
    private var outputStream: OutputStream?
    
    func connect(){
        CFStreamCreatePairWithSocketToHost(nil, addr, port, nil, &writeStream)
        outputStream = writeStream?.takeRetainedValue()
    }
    
    func open(){
        outputStream!.open()
    }
    
    func send(data:String){
        let formatted = data + "\r\n"
        //let x = formatted.components(separatedBy: "\r\n")
        //print(x.count - 1)
        outputStream!.write(data, maxLength: data.lengthOfBytes(using: String.Encoding.utf8))
    }
    
    func close(){
        outputStream!.close()
    }
    
    init(addr_:CFString, port_:UInt32) {
        addr = addr_
        port = port_
    }
    
}

