import CoreLocation
import MapKit

/// Google encoded polyline format (precision 5), compatible with Strava and others.
enum Polyline {
    static func encode(_ coordinates: [CLLocationCoordinate2D]) -> String {
        var result = ""
        var lastLat = 0, lastLng = 0
        for coordinate in coordinates {
            let lat = Int((coordinate.latitude * 1e5).rounded())
            let lng = Int((coordinate.longitude * 1e5).rounded())
            result += encodeValue(lat - lastLat) + encodeValue(lng - lastLng)
            lastLat = lat
            lastLng = lng
        }
        return result
    }

    static func decode(_ string: String?) -> [CLLocationCoordinate2D] {
        guard let bytes = string.map({ Array($0.utf8) }), !bytes.isEmpty else { return [] }
        var coordinates: [CLLocationCoordinate2D] = []
        var index = 0, lat = 0, lng = 0
        while index < bytes.count {
            guard let dLat = decodeValue(bytes, &index), let dLng = decodeValue(bytes, &index) else { break }
            lat += dLat
            lng += dLng
            coordinates.append(CLLocationCoordinate2D(latitude: Double(lat) / 1e5, longitude: Double(lng) / 1e5))
        }
        return coordinates
    }

    static func boundingRect(_ coordinates: [CLLocationCoordinate2D]) -> MKMapRect {
        let rect = coordinates.reduce(MKMapRect.null) { rect, c in
            rect.union(MKMapRect(origin: MKMapPoint(c), size: MKMapSize(width: 0, height: 0)))
        }
        return rect.insetBy(dx: -rect.width * 0.15 - 200, dy: -rect.height * 0.15 - 200)
    }

    private static func encodeValue(_ value: Int) -> String {
        var v = value < 0 ? ~(value << 1) : value << 1
        var chunk = ""
        while v >= 0x20 {
            chunk.append(Character(UnicodeScalar(UInt8((0x20 | (v & 0x1f)) + 63))))
            v >>= 5
        }
        chunk.append(Character(UnicodeScalar(UInt8(v + 63))))
        return chunk
    }

    private static func decodeValue(_ bytes: [UInt8], _ index: inout Int) -> Int? {
        var result = 0, shift = 0
        while index < bytes.count {
            let b = Int(bytes[index]) - 63
            index += 1
            result |= (b & 0x1f) << shift
            shift += 5
            if b < 0x20 { return (result & 1) != 0 ? ~(result >> 1) : result >> 1 }
        }
        return nil
    }
}
