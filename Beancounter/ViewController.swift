//
//  ViewController.swift
//  Beancounter
//
//  Created by Richard Broberg on 3/7/17.
//  Copyright © 2017 Richard Broberg. All rights reserved.
//

import UIKit
import CoreBluetooth
import AudioToolbox

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    var clearCharacteristic: CBCharacteristic!
    var manager: CBCentralManager!
    var peripheral: CBPeripheral!
    var checkRSSITimer: Timer!
    
    let BEAN_NAME = "rick first bean"
    let BEAN_SCRATCH_UUID = CBUUID(string: "a495ff21-c5b1-4b44-b512-1370f02d74de")
    let BEAN_SCRATCH_CLEAR_UUID = CBUUID(string: "a495ff22-c5b1-4b44-b512-1370f02d74de")
    let BEAN_SERVICE_UUID = CBUUID(string: "a495ff20-c5b1-4b44-b512-1370f02d74de")

    @IBOutlet weak var labelCount: UILabel!
    @IBOutlet weak var rssi: UILabel!

    @IBOutlet weak var clearButton: UIButton!
    @IBAction func clearMe(_ sender: Any) {
        let nsval = NSString(string: "x")
        let data = Data(bytes: nsval.utf8String!, count: nsval.length)

        peripheral?.writeValue(data, for: clearCharacteristic!, type: CBCharacteristicWriteType.withResponse)
    }
    @IBOutlet weak var notify: UISwitch!
    @IBOutlet weak var screenToggle: UISwitch!
    @IBAction func screenOn(_ sender: Any) {
        // keep screen on
        UIApplication.shared.isIdleTimerDisabled = screenToggle!.isOn
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        manager = CBCentralManager(delegate: self, queue: nil)
        clearButton!.isEnabled = false
        checkRSSITimer = Timer.scheduledTimer(timeInterval: 5.0, target:self,
                                              selector: #selector(ViewController.checkRSSI),
                                              userInfo: nil, repeats: true)
    }
 
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func checkRSSI()
    {
        peripheral.readRSSI()
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == CBManagerState.poweredOn {
            central.scanForPeripherals(withServices: nil, options: nil)
        } else {
            print("Bluetooth not available.")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let device = (advertisementData as NSDictionary).object(forKey: CBAdvertisementDataLocalNameKey) as? NSString {
            if device.contains(BEAN_NAME) == true {
                self.manager.stopScan()
                
                self.peripheral = peripheral
                self.peripheral.delegate = self
                
                manager.connect(peripheral, options: nil)
                print("that's my boy!")
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(nil)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services! {
            let thisService = service as CBService
            
            if service.uuid == BEAN_SERVICE_UUID {
                peripheral.discoverCharacteristics(nil, for: thisService)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics! {
            let thisCharacteristic = characteristic as CBCharacteristic
            
            if thisCharacteristic.uuid == BEAN_SCRATCH_UUID {
                self.peripheral.setNotifyValue(true, for: thisCharacteristic)
                self.peripheral.readValue(for: thisCharacteristic)
            }
            if thisCharacteristic.uuid == BEAN_SCRATCH_CLEAR_UUID {
                self.clearCharacteristic = thisCharacteristic
                clearButton!.isEnabled = true
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        rssi!.text = "\(RSSI)"
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        var count:UInt16 = 0;
        
        if characteristic.uuid == BEAN_SCRATCH_UUID {
            var bytes = Array(repeating: 0 as UInt8, count: 4) //MemoryLayout.size(ofValue: count)/MemoryLayout<UInt8>.size)
            
            characteristic.value!.copyBytes(to: &bytes, count: 4)
            let data16 = bytes.map { UInt16($0) }
            count = 256 * data16[1] + data16[0]
            labelCount.text = "\(count)"
            
            if notify!.isOn {
                AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        central.scanForPeripherals(withServices: nil, options: nil)
    }
}

