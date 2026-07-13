import Foundation
import IOKit
import IOKit.usb
import IOKit.usb.IOUSBLib

public struct USBDevice: Identifiable, Sendable {
    public let id: String
    public let vendorID: UInt16
    public let productID: UInt16
    public let name: String
    public let serialNumber: String?
    public let locationID: UInt32

    public init(id: String, vendorID: UInt16, productID: UInt16, name: String, serialNumber: String?, locationID: UInt32) {
        self.id = id
        self.vendorID = vendorID
        self.productID = productID
        self.name = name
        self.serialNumber = serialNumber
        self.locationID = locationID
    }
}

public actor USBDeviceManager {
    private var notificationPort: IONotificationPortRef?
    private var deviceAddedIterator: io_iterator_t = 0
    private var deviceRemovedIterator: io_iterator_t = 0
    private var connectedDevices: [String: USBDevice] = [:]

    public nonisolated let deviceUpdates: AsyncStream<[USBDevice]>
    private let continuation: AsyncStream<[USBDevice]>.Continuation

    public init() {
        (deviceUpdates, continuation) = AsyncStream.makeStream()
        setupNotifications()
    }

    deinit {
        stopNotifications()
    }

    private func setupNotifications() {
        notificationPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let notificationPort = notificationPort else { return }

        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName) as NSMutableDictionary
        matchingDict[kUSBVendorID] = 0x05AC // Apple vendor ID as example

        var kr = IOServiceAddMatchingNotification(
            notificationPort,
            kIOFirstMatchNotification,
            matchingDict,
            deviceAddedCallback,
            Unmanaged.passUnretained(self).toOpaque(),
            &deviceAddedIterator
        )
        if kr == KERN_SUCCESS {
            deviceAddedCallback(Unmanaged.passUnretained(self).toOpaque(), deviceAddedIterator)
        }

        kr = IOServiceAddMatchingNotification(
            notificationPort,
            kIOTerminatedNotification,
            matchingDict,
            deviceRemovedCallback,
            Unmanaged.passUnretained(self).toOpaque(),
            &deviceRemovedIterator
        )
        if kr == KERN_SUCCESS {
            deviceRemovedCallback(Unmanaged.passUnretained(self).toOpaque(), deviceRemovedIterator)
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(notificationPort), .commonModes)
    }

    private func stopNotifications() {
        if deviceAddedIterator != 0 { IOObjectRelease(deviceAddedIterator) }
        if deviceRemovedIterator != 0 { IOObjectRelease(deviceRemovedIterator) }
        if let port = notificationPort { IONotificationPortDestroy(port) }
    }

    private func deviceAddedCallback(_ context: UnsafeMutableRawPointer?, _ iterator: io_iterator_t) {
        let manager = Unmanaged<USBDeviceManager>.fromOpaque(context!).takeUnretainedValue()
        var device = IOIteratorNext(iterator)
        while device != 0 {
            Task { await manager.handleDeviceAdded(device!) }
            IOObjectRelease(device)
            device = IOIteratorNext(iterator)
        }
    }

    private func deviceRemovedCallback(_ context: UnsafeMutableRawPointer?, _ iterator: io_iterator_t) {
        let manager = Unmanaged<USBDeviceManager>.fromOpaque(context!).takeUnretainedValue()
        var device = IOIteratorNext(iterator)
        while device != 0 {
            Task { await manager.handleDeviceRemoved(device!) }
            IOObjectRelease(device)
            device = IOIteratorNext(iterator)
        }
    }

    private func handleDeviceAdded(_ device: io_object_t) async {
        guard let usbDevice = createUSBDevice(from: device) else { return }
        connectedDevices[usbDevice.id] = usbDevice
        continuation.yield(Array(connectedDevices.values))
    }

    private func handleDeviceRemoved(_ device: io_object_t) async {
        if let usbDevice = createUSBDevice(from: device) {
            connectedDevices.removeValue(forKey: usbDevice.id)
            continuation.yield(Array(connectedDevices.values))
        }
    }

    private func createUSBDevice(from device: io_object_t) -> USBDevice? {
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(device, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let props = properties?.takeRetainedValue() as? [String: Any] else { return nil }

        guard let vendorID = props[kUSBVendorID] as? UInt16,
              let productID = props[kUSBProductID] as? UInt16,
              let locationID = props[kUSBAddress] as? UInt32 else { return nil }

        let name = (props[kUSBProductString] as? String) ?? "Unknown Device"
        let serialNumber = props[kUSBSerialNumberString] as? String
        let id = "\(vendorID):\(productID):\(locationID)"

        return USBDevice(id: id, vendorID: vendorID, productID: productID, name: name, serialNumber: serialNumber, locationID: locationID)
    }

    public func getConnectedDevices() async -> [USBDevice] {
        return Array(connectedDevices.values)
    }
}
EOF