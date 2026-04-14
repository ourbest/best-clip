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
            let preferredDuration = CMTime(seconds: max(section.endSeconds - section.startSeconds, 0.5), preferredTimescale: 600)
            let clipDuration = minCMTime(sourceAsset.duration, preferredDuration)
            guard clipDuration > .zero else { continue }

            if let sourceTrack = sourceAsset.tracks(withMediaType: .video).first,
               let compositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
                try? compositionTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: clipDuration),
                    of: sourceTrack,
                    at: cursor
                )
            }

            if let sourceAudioTrack = sourceAsset.tracks(withMediaType: .audio).first,
               let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                try? compositionAudioTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: clipDuration),
                    of: sourceAudioTrack,
                    at: cursor
                )
            }

            cursor = CMTimeAdd(cursor, clipDuration)
        }

        return composition
    }

    private func minCMTime(_ lhs: CMTime, _ rhs: CMTime) -> CMTime {
        if CMTimeCompare(lhs, rhs) <= 0 {
            return lhs
        }
        return rhs
    }
}
