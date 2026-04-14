import AVFoundation
import Foundation

protocol VideoComposing {
    func makeComposition(plan: CompositionPlan, assets: [MediaAssetSnapshot]) -> AVMutableComposition
}

final class VideoComposer: VideoComposing {
    func makeComposition(plan: CompositionPlan, assets: [MediaAssetSnapshot]) -> AVMutableComposition {
        let composition = AVMutableComposition()
        var cursor = CMTime.zero

        for section in plan.sections {
            guard let asset = assets.first(where: { $0.id == section.assetID }),
                  let sourceURL = asset.sourceURL else {
                continue
            }

            let sourceAsset = AVURLAsset(url: sourceURL)
            let clipRange = clipTimeRange(for: section, sourceDuration: sourceAsset.duration)
            let clipDuration = clipRange.duration
            guard clipDuration > .zero else { continue }

            if let sourceTrack = sourceAsset.tracks(withMediaType: .video).first,
               let compositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
                try? compositionTrack.insertTimeRange(
                    clipRange,
                    of: sourceTrack,
                    at: cursor
                )
            }

            if let sourceAudioTrack = sourceAsset.tracks(withMediaType: .audio).first,
               let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                try? compositionAudioTrack.insertTimeRange(
                    clipRange,
                    of: sourceAudioTrack,
                    at: cursor
                )
            }

            cursor = CMTimeAdd(cursor, clipDuration)
        }

        return composition
    }

    func clipTimeRange(for section: CompositionSection, sourceDuration: CMTime) -> CMTimeRange {
        let sourceStart = CMTime(seconds: max(section.startSeconds, 0), preferredTimescale: 600)
        let requestedDuration = CMTime(seconds: max(section.endSeconds - section.startSeconds, 0.5), preferredTimescale: 600)
        let availableDuration = maxCMTime(sourceDuration - sourceStart, .zero)
        let clipDuration = minCMTime(availableDuration, requestedDuration)
        return CMTimeRange(start: sourceStart, duration: clipDuration)
    }

    private func minCMTime(_ lhs: CMTime, _ rhs: CMTime) -> CMTime {
        if CMTimeCompare(lhs, rhs) <= 0 {
            return lhs
        }
        return rhs
    }

    private func maxCMTime(_ lhs: CMTime, _ rhs: CMTime) -> CMTime {
        if CMTimeCompare(lhs, rhs) >= 0 {
            return lhs
        }
        return rhs
    }
}
