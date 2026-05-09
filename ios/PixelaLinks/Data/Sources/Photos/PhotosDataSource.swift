import Photos
import Foundation

struct PhotosDataSource: ActivityDataSource {
    let type: ActivityType

    func requestAuthorization() async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .notDetermined else { return }
        _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    func fetchTodayTotal() async throws -> Double {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return 0 }
        guard let today = Calendar.current.dateInterval(of: .day, for: .now) else { return 0 }

        switch type {
        case .photoLibraryAddCount:  return countImages(in: today)
        case .screenshotCount:       return countScreenshots(in: today)
        case .videoRecordingDuration: return sumVideoSeconds(in: today)
        default: return 0
        }
    }

    private func countImages(in day: DateInterval) -> Double {
        let opts = PHFetchOptions()
        opts.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate < %@",
            day.start as CVarArg, day.end as CVarArg
        )
        return Double(PHAsset.fetchAssets(with: .image, options: opts).count)
    }

    private func countScreenshots(in day: DateInterval) -> Double {
        let opts = PHFetchOptions()
        opts.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate < %@ AND (mediaSubtypes & %d) != 0",
            day.start as CVarArg, day.end as CVarArg,
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        return Double(PHAsset.fetchAssets(with: .image, options: opts).count)
    }

    private func sumVideoSeconds(in day: DateInterval) -> Double {
        let opts = PHFetchOptions()
        opts.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate < %@",
            day.start as CVarArg, day.end as CVarArg
        )
        let assets = PHAsset.fetchAssets(with: .video, options: opts)
        var total = 0.0
        assets.enumerateObjects { asset, _, _ in total += asset.duration }
        return total
    }
}
