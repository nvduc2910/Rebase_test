//
//  MergeMusicToVideo.swift
//  MyScoop
//
//  Created by SOCIAL MYSCOOP on 7/2/18.
//  Copyright © 2018 SOCIAL MYSCOOP. All rights reserved.
//

import AVKit
import AVFoundation
import AssetsLibrary
import LLVideoEditor
import RxSwift
import Photos
import RealmSwift
import NextLevelSessionExporter

class DataPost: NSObject {
    
    var scoop: ScoopPublish?
    var isSaveDraf: Bool?
    var outputVideoOrientation: UIDeviceOrientation?
    var overlayImage: UIImage?
    var templateId: Template?
    var imageCapture: UIImage?
    var arrayVideoSegment: NSMutableArray?
    var arrayVideosTemp: NSMutableArray?
    var imageThumb: UIImage?
    var music: Music?
    var urlCompareVideo: hihihídhi2
    
    override init() {
        super.init()
    }
}

class VideoEditor: NSObject {
    
    static let instance = VideoEditor()
    
    var disposeBag = DisposeBag()
    
    var compressing = PublishSubject<([UIImage], CGFloat, Bool)>()
    var startProgress = PublishSubject<Void>()
    var progressFinished = PublishSubject<ScoopPublish>()
    var startPostScoop = PublishSubject<ScoopPublish>()
    var saving = PublishSubject<([UIImage], CGFloat)>()
    var uploading = PublishSubject<Double>()
    var uploadFail = PublishSubject<(String, ScoopPublish)>()
    var progressFail = PublishSubject<(String, DataPost?)>()
    var autoReProgress = PublishSubject<DataPost?>()
    var posting = PublishSubject<Void>()
    var saved = PublishSubject<ScoopPublish>()
    var updateScoopSaved = PublishSubject<ScoopPublish>()
    var savedScoopSucess = PublishSubject<Void>()
    var saveFail = PublishSubject<(String, ScoopPublish)>()
    var bottomConstraint: CGFloat = 0
    var startUploadFirebase = PublishSubject<Void>()
    var arrayVideosTemp: NSMutableArray = NSMutableArray(array: [])
    
    var scoop: ScoopPublish?
    var dataPost: DataPost?
    var blurViewVideo: UIView?
    var isCompressing: Bool = false
    var isForeground: Bool = false
    let textLayer = CATextLayer()
    var timmer: Timer?
    
    override init() {
        super.init()
        self.savedScoopSucess.do(onNext: { [weak self] _ in
            guard let `self` = self else { return }
            self.isCompressing = false
        }).subscribe().disposed(by: disposeBag)
        
        self.progressFail.do(onNext: { [weak self] _ in
            guard let `self` = self else { return }
            self.isCompressing = false
        }).subscribe().disposed(by: disposeBag)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.appEnterForeGround), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    @objc func appEnterForeGround() {
        if self.isCompressing {
            self.isForeground = true
        }
    }
    
    func mergeVideo(_ scoop: ScoopPublish, isSaveDraf: Bool, outputVideoOrientation: UIDeviceOrientation, overlayImage: UIImage?, templateId: Template, imageCapture: UIImage?, arrayVideoSegment: NSMutableArray, arrayVideosTemp: NSMutableArray, music: Music?, imageThumb: UIImage, urlCompareVideo: URL? = nil) {
        self.isCompressing = true
        dataPost = DataPost()
        dataPost?.scoop = scoop
        dataPost?.isSaveDraf = isSaveDraf
        dataPost?.outputVideoOrientation = outputVideoOrientation
        dataPost?.overlayImage = overlayImage
        dataPost?.templateId = templateId
        dataPost?.imageThumb = imageThumb
        dataPost?.imageCapture = imageCapture
        dataPost?.arrayVideoSegment = arrayVideoSegment
        dataPost?.arrayVideosTemp = arrayVideosTemp
        dataPost?.music = music
        dataPost?.urlCompareVideo = urlCompareVideo
        self.scoop = scoop
        self.scoop?.idTemp = UUID().uuidString
        self.arrayVideosTemp = arrayVideosTemp
        self.scoop?.images = [imageThumb]
        self.scoop?.bottom = self.bottomConstraint
        compressing.onNext(([imageThumb], bottomConstraint, isSaveDraf))
        
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        let overlayLayer = CALayer()
        let compareLayyer = CALayer()
        
        parentLayer.frame = CGRect(x: 0, y: 0, width: Constant.VIDEO_EXPORT_WIDTH, height: Constant.VIDEO_EXPORT_HEIGHT)
        
        videoLayer.frame = CGRect(x: 0, y: 0, width: Constant.VIDEO_EXPORT_WIDTH, height: Constant.VIDEO_EXPORT_HEIGHT)
        
        if outputVideoOrientation == .portrait {
            
            overlayLayer.contents = overlayImage?.byRotateLeft90()?.cgImage
        }else {
            overlayLayer.contents = overlayImage?.cgImage
        }
        
        overlayLayer.frame = CGRect(x: 0 ,y: 0 , width: Constant.VIDEO_EXPORT_WIDTH, height: Constant.VIDEO_EXPORT_HEIGHT)
        
        parentLayer.addSublayer(videoLayer)
        
        if urlCompareVideo != nil {
            if templateId == .CommentView {
                parentLayer.addSublayer(overlayLayer)
            }
            self.mergeVideosArray(withLayer: arrayVideoSegment, templateID: 0, video: videoLayer, parent: parentLayer, outputVideoOrientation) {  [weak self] (urloutput, result) in
                guard let `self` = self else { return }
                if result {
                    
                    if templateId == .CommentView {
                        
                        if let size = urlCompareVideo?.getSizeVideo(), size.height > size.width, let currentSize = urlCompareVideo?.getDefaultSizeVideo(), currentSize.height != size.height {
                            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                            let fileName = String(Date().timeIntervalSince1970).toBase64() + ".mp4"
                            let exportURL = documentsDirectory.appendingPathComponent(fileName)
                            let videoEditor = LLVideoEditor(videoURL: urlCompareVideo!)
                            arrayVideosTemp.add(exportURL)
                            
                            videoEditor?.rotate(LLRotateDegree90)
                            
                            videoEditor?.export(to: exportURL, completionBlock: { [weak self] (session) in
                                
                                guard let `self` = self else { return }
                                
                                switch (session?.status)! {
                                case .completed:
                                    Utilities.instance.urlTemp.append(exportURL)
                                    self.mergeVideosSidebySide(firstUrl: exportURL, SecondUrl: urloutput!, targetSize: CGSize(width: Constant.VIDEO_EXPORT_WIDTH, height: Constant.VIDEO_EXPORT_HEIGHT), templateId, completion: { (exportURL) in
                                        guard let exportURL = exportURL else { return }
                                        if let url = music?.url {
                                            
                                            self.mergeVideoAndMusicWithVolume(videoURL: exportURL, audioURL: url, startAudioTime: 0, volumeVideo: 1, volumeAudio: (music?.volume)!, complete: { [weak self] (urlVideo) in
                                                
                                                guard let `self` = self else { return }
                                                if urlVideo != nil {
                                                    DispatchQueue.main.async {
                                                        self.uploadVideo(urlVideo!, isSaveDraf: isSaveDraf, scoop: scoop)
                                                    }
                                                }else {
                                                    
                                                }
                                            })
                                            
                                        }else {
                                            
                                            self.uploadVideo(exportURL, isSaveDraf: isSaveDraf, scoop: scoop)
                                        }
                                    })
                                    
                                case .cancelled, .failed, .unknown:
                                    if self.isForeground && self.isCompressing {
                                        self.autoReProgress.onNext(self.dataPost)
                                    }else {
                                        if let error = session?.error {
                                            self.progressFail.onNext((error.localizedDescription, self.dataPost))
                                        }
                                    }
                                    break

                                default:
                                    break
                                }
                            })
                            
                            return
                        }
                        
                        self.mergeVideosSidebySide(firstUrl: urlCompareVideo!, SecondUrl: urloutput!, targetSize: CGSize(width: Constant.VIDEO_EXPORT_WIDTH, height: Constant.VIDEO_EXPORT_HEIGHT), templateId, completion: { (exportURL) in
                            guard let exportURL = exportURL else { return }
                            if let url = music?.url {
                                
                                self.mergeVideoAndMusicWithVolume(videoURL: exportURL, audioURL: url, startAudioTime: 0, volumeVideo: 1, volumeAudio: (music?.volume)!, complete: { [weak self] (urlVideo) in
                                    
                                    guard let `self` = self else { return }
                                    if urlVideo != nil {
                                        Utilities.instance.urlTemp.append(urlVideo!)
                                        DispatchQueue.main.async {
                                            self.uploadVideo(urlVideo!, isSaveDraf: isSaveDraf, scoop: scoop)
                                        }
                                    }else {
                                        
                                    }
                                })
                                
                            }else {
                                
                                self.uploadVideo(exportURL, isSaveDraf: isSaveDraf, scoop: scoop)
                            }
                        })
                    }else {
                        self.blurVideo(urlCompareVideo!, urlBellow: urloutput!) { [weak self] (video) in
                            guard let `self` = self else { return }
                            
                            let parentLayer = CALayer()
                            let videoLayer = CALayer()
                            let overlayLayer = CALayer()
                            
                            parentLayer.frame = CGRect(x: 0, y: 0, width: Constant.VIDEO_EXPORT_WIDTH, height: Constant.VIDEO_EXPORT_HEIGHT)
                            
                            videoLayer.frame = CGRect(x: 0, y: 0, width: Constant.VIDEO_EXPORT_WIDTH, height: Constant.VIDEO_EXPORT_HEIGHT)
                            
                            overlayLayer.contents = overlayImage?.cgImage
                            overlayLayer.frame = CGRect(x: 0 ,y: 0 , width: Constant.VIDEO_EXPORT_WIDTH, height: Constant.VIDEO_EXPORT_HEIGHT)
                            
                            parentLayer.addSublayer(videoLayer)
                            
                            overlayLayer.masksToBounds = true
                            //                        parentLayer.addSublayer(compareLayer)
                            parentLayer.addSublayer(overlayLayer)
                            
                            self.mergeVideoWithImage(videoURL: video!, videoLayer: videoLayer, parentLayer: parentLayer, completion: { [weak self] (urlVideo) in
                                guard let `self` = self else { return }
                                Utilities.instance.urlTemp.append(urlVideo!)
                                if let url = music?.url {
                                    self.mergeVideoAndMusicWithVolume(videoURL: urlVideo!, audioURL: url, startAudioTime: 0, volumeVideo: 1, volumeAudio: (music?.volume)!, complete: { [weak self] (urlVideo) in
                                        
                                        guard let `self` = self else { return }
                                        
                                        if let url = urlVideo {
                                            Utilities.instance.urlTemp.append(url)
                                            //                                        self.progressFinished.onNext(self.scoop!)
                                            DispatchQueue.main.async {
                                                self.uploadVideo(urlVideo!, isSaveDraf: isSaveDraf, scoop: scoop)
                                            }
                                        }
                                    })
                                }else {
                                    DispatchQueue.main.async {
                                        if urlVideo != nil {
                                            self.uploadVideo(urlVideo!, isSaveDraf: isSaveDraf, scoop: scoop)
                                        }
                                        
                                    }
                                }
                            })
                        }
                    }
                }
            }
        }else {
            
            if templateId == .CompareView {
                videoLayer.frame = CGRect(x: Constant.VIDEO_EXPORT_WIDTH/4, y: 0, width: Constant.VIDEO_EXPORT_WIDTH, height: Constant.VIDEO_EXPORT_HEIGHT)
                
                compareLayyer.backgroundColor = UIColor.white.cgColor
                compareLayyer.frame = CGRect(x: 0 ,y: 0 , width: Constant.VIDEO_EXPORT_WIDTH/2, height: Constant.VIDEO_EXPORT_HEIGHT)
                let imageLayer = CALayer()
                imageLayer.masksToBounds = true
                imageLayer.frame = CGRect(x: 0 ,y: 0 , width: Constant.VIDEO_EXPORT_WIDTH/2, height: Constant.VIDEO_EXPORT_HEIGHT)
                imageLayer.contents = imageCapture?.cgImage
                compareLayyer.addSublayer(imageLayer)
                parentLayer.addSublayer(compareLayyer)
            }
            
            overlayLayer.masksToBounds = true
            parentLayer.addSublayer(overlayLayer)
            
            if templateId == .Vlog {
                let imageLayer = CALayer()
                imageLayer.contents = #imageLiteral(resourceName: "ic_rec").cgImage
                let x = Constant.VIDEO_EXPORT_WIDTH * 24 / 667
                let width = Constant.VIDEO_EXPORT_WIDTH * 20 / 667
                
                let yImage = Constant.VIDEO_EXPORT_HEIGHT * 35 / 375
                
                let y: CGFloat = Constant.VIDEO_EXPORT_HEIGHT - width - yImage
                
                imageLayer.frame = CGRect(x: x, y: y, width: width, height: width)
                imageLayer.masksToBounds = true
                let animation = CABasicAnimation(keyPath: "opacity")
                animation.duration = 0.3
                animation.repeatCount = .infinity
                animation.autoreverses = true
                animation.fromValue = NSNumber(floatLiteral: 1.0)
                animation.toValue = NSNumber(floatLiteral: 0)
                
                animation.beginTime = AVCoreAnimationBeginTimeAtZero
                imageLayer.add(animation, forKey: "animateOpacity")
                parentLayer.addSublayer(imageLayer)
            }
            
            self.mergeVideosArray(withLayer: arrayVideoSegment, templateID: 0, video: videoLayer, parent: parentLayer, outputVideoOrientation) { [weak self] (urloutput, result) in
                
                guard let `self` = self else { return }
                
                if result == true && urloutput != nil {
                    if outputVideoOrientation == .portrait {
                        
                        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                        let fileName = String(Date().timeIntervalSince1970).toBase64() + ".mp4"
                        let exportURL = documentsDirectory.appendingPathComponent(fileName)
                        let videoEditor = LLVideoEditor(videoURL: urloutput!)
                        arrayVideosTemp.add(exportURL)
                        
                        videoEditor?.rotate(LLRotateDegree90)
                        
                        videoEditor?.export(to: exportURL, completionBlock: { [weak self] (session) in
                            
                            guard let `self` = self else { return }
                            
                            switch (session?.status)! {
                            case .completed:
                                Utilities.instance.urlTemp.append(urloutput!)
                                //                                Utilities.instance.urlTemp.append(exportURL)
                                if let url = music?.url {
                                    
                                    self.mergeVideoAndMusicWithVolume(videoURL: exportURL, audioURL: url, startAudioTime: 0, volumeVideo: 1, volumeAudio: (music?.volume)!, size: CGSize(width: Constant.VIDEO_EXPORT_WIDTH_PORTRAIT, height: Constant.VIDEO_EXPORT_HEIGHT_PORTRAIT), complete: { [weak self] (urlVideo) in
                                        
                                        guard let `self` = self else { return }
                                        if urlVideo != nil {
                                            Utilities.instance.urlTemp.append(urlVideo!)
                                            DispatchQueue.main.async {
                                                self.uploadVideo(urlVideo!, isSaveDraf: isSaveDraf, scoop: scoop)
                                            }
                                        }else {
                                            
                                        }
                                    })
                                    
                                }else {
                                    
                                    self.uploadVideo(exportURL, isSaveDraf: isSaveDraf, scoop: scoop)
                                }
                            case .cancelled, .failed, .unknown:
                                
                                if self.isForeground && self.isCompressing {
                                    self.autoReProgress.onNext(self.dataPost)
                                }else {
                                    if let error = session?.error {
                                        self.progressFail.onNext((error.localizedDescription, self.dataPost))
                                    }
                                }
                               
                                break
                            default:
                                self.progressFail.onNext(("Processing fail", self.dataPost))
                                break
                            }
                        })
                    }else {
                        
                        if let url = music?.url {
                            
                            self.mergeVideoAndMusicWithVolume(videoURL: urloutput!, audioURL: url, startAudioTime: 0, volumeVideo: 1, volumeAudio: (music?.volume)!, complete: { [weak self] (urlVideo) in
                                
                                guard let `self` = self else { return }
                                
                                if urlVideo != nil {
                                    Utilities.instance.urlTemp.append(urlVideo!)
                                    DispatchQueue.main.async {
                                        self.uploadVideo(urlVideo!, isSaveDraf: isSaveDraf, scoop: scoop)
                                    }
                                }else {
                                    
                                    
                                }
                            })
                        }else {
                            self.uploadVideo(urloutput!, isSaveDraf: isSaveDraf, scoop: scoop)
                        }
                    }
                }
            }
        }
        
    }
    
    func mergeVideoAndMusicWithVolume(videoURL: URL, audioURL: URL, startAudioTime: Float64, volumeVideo: Float, volumeAudio: Float, size: CGSize? = nil, complete: @escaping (URL?) -> Void) -> Void {
        
        //Create Asset from record and music
        let assetVideo: AVURLAsset = AVURLAsset(url: videoURL)
        let assetMusic: AVURLAsset = AVURLAsset(url: audioURL)
        
        let composition: AVMutableComposition = AVMutableComposition()
        let compositionVideo: AVMutableCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: CMPersistentTrackID())!
        let compositionAudioVideo: AVMutableCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: CMPersistentTrackID())!
        let compositionAudioMusic: AVMutableCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: CMPersistentTrackID())!
        
        //Add video to the final record
        do {
            try compositionVideo.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: assetVideo.duration), of: assetVideo.tracks(withMediaType: AVMediaType.video)[0], at: CMTime.zero)
            
        } catch _ {
            
        }
        
        //Extract audio from the video and the music
        let audioMix: AVMutableAudioMix = AVMutableAudioMix()
        var audioMixParam: [AVMutableAudioMixInputParameters] = []
        
        let assetVideoTrack: AVAssetTrack = assetVideo.tracks(withMediaType: AVMediaType.audio)[0]
        let assetMusicTrack: AVAssetTrack = assetMusic.tracks(withMediaType: AVMediaType.audio)[0]
        
        let videoParam: AVMutableAudioMixInputParameters = AVMutableAudioMixInputParameters(track: assetVideoTrack)
        videoParam.trackID = compositionAudioVideo.trackID
        
        let musicParam: AVMutableAudioMixInputParameters = AVMutableAudioMixInputParameters(track: assetMusicTrack)
        musicParam.trackID = compositionAudioMusic.trackID
        
        //Set final volume of the audio record and the music
        videoParam.setVolume(volumeVideo, at: CMTime.zero)
        musicParam.setVolume(volumeAudio, at: CMTime.zero)
        
        //Add setting
        audioMixParam.append(musicParam)
        audioMixParam.append(videoParam)
        
        //Add audio on final record
        //First: the audio of the record and Second: the music
        do {
            try compositionAudioVideo.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: assetVideo.duration), of: assetVideoTrack, at: CMTime.zero)
        } catch _ {
            assertionFailure()
        }
        
        do {
            try compositionAudioMusic.insertTimeRange(CMTimeRangeMake(start: CMTimeMake(value: Int64(startAudioTime * 10000), timescale: 10000), duration: assetVideo.duration), of: assetMusicTrack, at: CMTime.zero)
        } catch _ {
            assertionFailure()
        }
        
        //Add parameter
        audioMix.inputParameters = audioMixParam
        
        self.exportURL(asset: composition, mainCompositonInst: nil, size: size, audioMix: audioMix) { (url, isResult) in
            complete(url)
        }
    }
    
    func uploadVideo(_ url: URL, isSaveDraf: Bool, scoop: ScoopPublish, isRetry: Bool = false) {
        
        Utilities.instance.finalURL = [url]
        let newArrTempURL = Utilities.instance.urlTemp.filter { newURL -> Bool in
            return url != newURL
        }
        Utilities.instance.urlTemp = newArrTempURL
        self.deleteVideoFile(Utilities.instance.urlTemp)
        DispatchQueue.main.async {
            let realm = try! Realm()
        
        let scoopPublish : ScoopPublish = scoop
        if scoop.mediaSize.isEmpty {
            
            try! realm.write {
                let asset : AVURLAsset = AVURLAsset(url: url)
                if let size = asset.fileSize {
                    scoopPublish.mediaSize = "\(size/1024) KB"
                }
                let duration : CMTime = asset.duration
                let seconds = CMTimeGetSeconds(duration)
                let date = Date(timeIntervalSince1970: seconds)
                let dateFormatter = DateFormatter(withFormat: "m:ss", locale: "UTC")
                scoopPublish.lenght = dateFormatter.string(from: date)
            }
       
        }
        try! realm.write {
          scoopPublish.isWaitToUpload = MyScoopReference.share.IS_UPLOADING_SCOOP_REF
        }
        var isSaved: Bool = false
        
        if isSaveDraf {
            self.saveVideo(url, scoopPublish: scoopPublish, isAutoSave: false)
            isSaved = true
        }else if !isRetry {
            self.saveVideo(url, scoopPublish: scoopPublish, isAutoSave: true)
            isSaved = true
        }
        
        if !isSaveDraf {

            if !MyScoopReference.share.IS_UPLOADING_SCOOP_REF {
                 self.upload(scoopPublish, url: url)
            }
        }else {
            
            if !isSaved {
                self.saveVideo(url, scoopPublish: scoopPublish, isAutoSave: false)
            }
        }
        }
    }
    
    
    func upload(_ scoopPublish: ScoopPublish, url: URL) {
        
        do {
            let reachability = try Reachability.reachabilityForInternetConnection()
            if !reachability.isReachable() {
                self.uploadFail.onNext(("Sorry, uploading had to stop because your connection dropped suddenly.", self.scoop!))
                return 
            }
        }catch {}
        
        if scoopPublish.linksOnline.count > 0 {
            DispatchQueue.main.async {
                VideoEditor.instance.updateScoopSaved.onNext(scoopPublish)
                self.startPostScoop.onNext(scoopPublish)
            }
            return
        }
        
        DispatchQueue.main.async {
            if let firebaseService =  ServiceContainer.sharedInstance.getResolver().resolve(FirebaseServiceType.self) {
                
                self.startUploadFirebase.onNext(())
                firebaseService.uploadFile(url, type: TypeData.video, templateID: scoopPublish.template_id, progress: { [weak self] (progress) in
                    
                    guard let `self` = self else { return }
                    self.uploading.onNext(progress)
                }).continueWith(block: { [weak self] (task) -> Any? in
                    
                    guard let `self` = self else { return nil }
                    if task.error == nil {
                        //                        DispatchQueue.main.async {
                        self.posting.onNext(())
                        scoopPublish.mediaLink = task.result as! String
                        let links = List<String>()
                        links.append(scoopPublish.mediaLink)
                        scoopPublish.mediaLinks = links
                        scoopPublish.mediaLinkIds = links
                        scoopPublish.linksOnline = links
                        scoopPublish.mediaIds = [scoopPublish.mediaLink]
                        VideoEditor.instance.updateScoopSaved.onNext(scoopPublish)
                        self.startPostScoop.onNext(scoopPublish)
                        //                        }
                    }else {
                        scoopPublish.typeData = .video
                        
                        do {
                            let reachability = try Reachability.reachabilityForInternetConnection()
                            if reachability.isReachable() || task.error?.code != -1009 {
                                self.uploadFail.onNext(((task.error?.localizedDescription)!, self.scoop!))
                            }else {
                                self.uploadFail.onNext(("Sorry, uploading had to stop because your connection dropped suddenly.", self.scoop!))
                            }
                        }catch {
                            
                        }
                        
                    }
                    return nil
                })
            }
        }
    }
    
    func saveVideo(_ url: URL, scoopPublish: ScoopPublish, isAutoSave: Bool = false) {
        
        print(scoopPublish.linksOnline)
        let fileName = url.absoluteURL.lastPathComponent
        scoopPublish.mediaId = fileName
        let links = List<String>()
        links.append(scoopPublish.mediaId)
        scoopPublish.mediaLinks = links
        scoopPublish.mediaLinkIds = links
        scoopPublish.mediaIds = [fileName]
        scoopPublish.urlMedia = url.absoluteURL.absoluteString
        scoopPublish.isAutoSave = isAutoSave
        if isAutoSave == false {
            scoopPublish.isWaitToUpload = false
        }
        saved.onNext(scoopPublish)
    }
    
    func saveImage(image: UIImage, scoop: ScoopPublish,_ bottom: CGFloat, _ isAutoSave: Bool = false) {
        
        //        if checkSaveImage(scoop) {
        //            return
        //        }
        
        print(scoop.isWaitToUpload)
        if !isAutoSave {
            VideoEditor.instance.saving.onNext(([image], bottom))
        }
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = String(Date().timeIntervalSince1970).toBase64() + ".jpg"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        if let data = image.jpegData(compressionQuality: 1.0),
            !FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try data.write(to: fileURL)
                scoop.mediaId = fileName
                let links = List<String>()
                links.append(scoop.mediaId)
                scoop.mediaLinks = links
                scoop.mediaLinkIds = links
                scoop.mediaIds = [fileName]
                scoop.urlMedia = fileURL.absoluteString
                scoop.isAutoSave = isAutoSave
                VideoEditor.instance.saved.onNext(scoop)
                print(scoop.isWaitToUpload)
            }catch {
                VideoEditor.instance.saveFail.onNext((error.localizedDescription, scoop))
            }
        }
    }
    
    func saveImage(images: [UIImage], scoop: ScoopPublish,_ bottom: CGFloat, _ isAutoSave: Bool = false) {

        if !isAutoSave {
            VideoEditor.instance.saving.onNext((images, bottom))
        }
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        var numnerofImage: Int = 0
        let links = List<String>()
        let linkIds = List<String>()
        for item in images {
            let fileName = String(Date().timeIntervalSince1970).toBase64() + ".jpg"
            let fileURL = documentsDirectory.appendingPathComponent(fileName)
            if let data = item.jpegData(compressionQuality: 1.0),
                !FileManager.default.fileExists(atPath: fileURL.path) {
                do {
                    try data.write(to: fileURL)
                    links.append(fileURL.absoluteString)
                    linkIds.append(fileName)
                    numnerofImage += 1
                    if numnerofImage == images.count {
                        scoop.mediaId = fileName
                        scoop.mediaLinks = links
                        scoop.isAutoSave = isAutoSave
                        scoop.mediaLinkIds = linkIds
                        VideoEditor.instance.saved.onNext(scoop)
                    }
                    
                } catch {
                    VideoEditor.instance.saveFail.onNext((error.localizedDescription, scoop))
                }
            }
        }
    }
    

    func saveImage(images: List<String>, thumb: UIImage, scoop: ScoopPublish,_ bottom: CGFloat, _ isAutoSave: Bool = false) {
        
        //        if checkSaveImage(scoop) {
        //            return
        //        }
        if !isAutoSave {
            VideoEditor.instance.saving.onNext(([thumb], bottom))
        }
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        var numnerofImage: Int = 0
        let links = List<String>()
        let linkIds = List<String>()
        for item in images {
            let fileName = String(Date().timeIntervalSince1970).toBase64() + ".jpg"
            let fileURL = documentsDirectory.appendingPathComponent(fileName)
            
            let imageView = UIImageView()
            
            imageView.loadImage(item, placeHolder: nil) { (image, e, cache, url) in
                
                if let image = image {
                    if let data = image.jpegData(compressionQuality: 1.0),
                        !FileManager.default.fileExists(atPath: fileURL.path) {
                        do {
                            try data.write(to: fileURL)
                            links.append(fileURL.absoluteString)
                            linkIds.append(fileName)
                            numnerofImage += 1
                            if numnerofImage == images.count {
                                scoop.mediaId = fileName
                                scoop.mediaLinks = links
                                scoop.isAutoSave = isAutoSave
                                scoop.mediaLinkIds = linkIds
                                VideoEditor.instance.saved.onNext(scoop)
                            }
                            
                        } catch {
                            
                            VideoEditor.instance.saveFail.onNext((error.localizedDescription, scoop))
                        }
                    }
                }else {
                    if e != nil {
                        VideoEditor.instance.saveFail.onNext(((e?.localizedDescription)!, scoop))
                    }else {
                        let error = NSError(domain: "myScoop", code: -998, userInfo: [NSLocalizedDescriptionKey : "Can't save image"])
                        VideoEditor.instance.saveFail.onNext((error.localizedDescription, scoop))
                    }
                    
                }
            }
        }
    }
    
    
    func uploadPhoto(_ scoopPublish: ScoopPublish, image: UIImage, bottom: CGFloat, _ isRetry: Bool = false) {
        
        let data = image.compressImage()
        scoopPublish.mediaSize = "\((Double((data?.count)!)/1024)) KB"
        
        VideoEditor.instance.compressing.onNext(([image], bottom, false))
        let realm = try! Realm()
        try! realm.write {
            scoopPublish.isWaitToUpload = MyScoopReference.share.IS_UPLOADING_SCOOP_REF
        }
        if !isRetry {
            self.saveImage(image: image, scoop: scoopPublish, bottom, true)
        }
       
        if MyScoopReference.share.IS_UPLOADING_SCOOP_REF {
           return
        }
        self.startUploadFirebase.onNext(())
        ServiceContainer.sharedInstance.getResolver().resolve(FirebaseServiceType.self)?.uploadData(data!, type: TypeData.image, templateID: scoopPublish.template_id, progress: { (progress) in
            self.uploading.onNext(progress)
            
        }, folderName: "scoops").continueWith(block: { (task) -> Any? in
            
            if task.error == nil {
                
                scoopPublish.mediaLink = task.result as! String
                let links = List<String>()
                links.append(scoopPublish.mediaLink)
                scoopPublish.mediaLinks = links
                scoopPublish.linksOnline = links
                scoopPublish.mediaIds = [scoopPublish.mediaLink]
                VideoEditor.instance.updateScoopSaved.onNext(scoopPublish)
                VideoEditor.instance.startPostScoop.onNext(scoopPublish)
            }else {
                scoopPublish.data = data
                scoopPublish.typeData = .image
                scoopPublish.images = [image]
                scoopPublish.bottom = bottom
                
                do {
                    let reachability = try Reachability.reachabilityForInternetConnection()
                    if reachability.isReachable() && task.error?.code != -1009{
                        VideoEditor.instance.uploadFail.onNext(((task.error?.localizedDescription)!, scoopPublish))
                    }else {
                        VideoEditor.instance.uploadFail.onNext(("Sorry, uploading had to stop because your connection dropped suddenly.", scoopPublish))
                    }
                }catch {
                    
                }
                
            }
            return nil
        })
    }
    
    func uploadPhoto(_ scoopPublish: ScoopPublish, images: [UIImage], bottom: CGFloat, _ isRetry: Bool = false) {
        
        VideoEditor.instance.compressing.onNext((images, bottom, false))
        let realm = try! Realm()
        try! realm.write {
            scoopPublish.isWaitToUpload = MyScoopReference.share.IS_UPLOADING_SCOOP_REF
        }
        if !isRetry {
            self.saveImage(images: images, scoop: scoopPublish, bottom, true)
        }
        
        var medias: [AlbumMedia] = []
        
        for item in images {
            let album = AlbumMedia()
            album.image = item
            album.mediaId = String(Date().timeIntervalSince1970).toBase64()
            medias.append(album)
        }
        
        var imageIds: [String] = []
        let linksUploaded = List<String>()
        
        if MyScoopReference.share.IS_UPLOADING_SCOOP_REF {
            return
        }
        
        for item in medias {
            
            let data = item.image?.jpegData(compressionQuality: 1.0)
            self.startUploadFirebase.onNext(())
            ServiceContainer.sharedInstance.getResolver().resolve(FirebaseServiceType.self)?.uploadImage(data!, type: TypeData.image, templateID: scoopPublish.template_id, name: item.mediaId!, progress: { (progress) in
                print(progress)
            }, folderName: "scoops").continueWith(block: { (task) -> Any? in
                
                if task.error == nil {
                    print("Upload sucessful")
                    let link = task.result as! String
                    if let index = medias.index(where: { album -> Bool in
                        return link.contains((album.mediaId)!)
                    }) {
                        medias[index].mediaLink = link
                    }
                    let arr = medias.filter({ album -> Bool in
                        return album.mediaLink == nil
                    })
                    
                    if arr.count == 0 {
                        
                        for media in medias {
                            imageIds.append(media.mediaLink!)
                            linksUploaded.append(media.mediaLink!)
                        }
                        scoopPublish.mediaIds = imageIds
                        scoopPublish.linksOnline = linksUploaded
                        VideoEditor.instance.updateScoopSaved.onNext(scoopPublish)
                        VideoEditor.instance.startPostScoop.onNext(scoopPublish)
                    }
                }else {
                    scoopPublish.data = data
                    scoopPublish.typeData = .image
                    scoopPublish.images = images
                    scoopPublish.bottom = bottom
                    
                    do {
                        let reachability = try Reachability.reachabilityForInternetConnection()
                        if reachability.isReachable() && task.error?.code != -1009 {
                            VideoEditor.instance.uploadFail.onNext(((task.error?.localizedDescription)!, scoopPublish))
                        }else {
                            VideoEditor.instance.uploadFail.onNext(("Sorry, uploading had to stop because your connection dropped suddenly.", scoopPublish))
                        }
                    }catch {
                        
                    }
                }
                return nil
            })
        }
    }
    
    func mergeVideos(firstUrl : URL , SecondUrl : URL, urlBellow: URL, targetSize: CGSize, completion: @escaping (_ result: URL?)->()) {
        
        let isPortrait = targetSize.height < targetSize.width
        
        _ = targetSize.width / targetSize.height
        let secondRadito = targetSize.height / targetSize.width
        
        let firstAssets = AVAsset(url: firstUrl)
        let secondAssets = AVAsset(url: SecondUrl)
        
        let mixComposition = AVMutableComposition()
        let firstTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let seconTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        let compositionAudioVideo: AVMutableCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: CMPersistentTrackID())!
        
        do{
            try   firstTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: firstAssets.duration), of: firstAssets.tracks(withMediaType: .video)[0], at: CMTime.zero)
            try seconTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: secondAssets.duration), of: secondAssets.tracks(withMediaType: .video)[0], at: CMTime.zero)
        }catch{
        }
        
        let mainInstraction = AVMutableVideoCompositionInstruction()
        
        mainInstraction.timeRange  = CMTimeRangeMake(start: CMTime.zero, duration: firstAssets.duration)
        
        let firstLayerInstraction = AVMutableVideoCompositionLayerInstruction(assetTrack: firstTrack!)
        let secondLayerInstraction = AVMutableVideoCompositionLayerInstruction(assetTrack: seconTrack!)
        
        let size = (seconTrack?.naturalSize)!
        
        if size.width == size.height {
            
            let scale = CGAffineTransform(scaleX: 0.5, y: 0.5)
            let yFirstLayer = (targetSize.height - size.height/2) / 2
            
            let move = CGAffineTransform(translationX: 0, y: yFirstLayer)
            let transform = scale.concatenating(move)
            firstLayerInstraction.setTransform(transform, at: CMTime.zero)
            
            _ = targetSize.height/2/size.height
            
            let secondScale = CGAffineTransform(scaleX: 1, y: 1)
            let xSecondLayer = -(targetSize.width - size.width/2)/2
            let secondMove = CGAffineTransform(translationX: xSecondLayer, y: 0)
            let secondTransform = secondScale.concatenating(secondMove)
            secondLayerInstraction.setTransform(secondTransform, at: CMTime.zero)
            
        }else if isPortrait {
            
            let secondScale = CGAffineTransform(scaleX: secondRadito, y: secondRadito)
            let xSecondLayer = targetSize.width/4 - targetSize.height * secondRadito / 2
            let secondMove = CGAffineTransform(translationX: xSecondLayer, y: 0)
            let secondTransform = secondScale.concatenating(secondMove)
            firstLayerInstraction.setTransform(secondTransform, at: CMTime.zero)
            
            let yRatio = targetSize.width/2/size.width
            let scale = CGAffineTransform(scaleX: yRatio, y: yRatio)
            let x = -((size.width * yRatio) - (targetSize.width/2))/2
            let y = -((size.height * yRatio) - targetSize.height)/2
            
            let move = CGAffineTransform(translationX: x, y: y)
            let transform = scale.concatenating(move)
            
            secondLayerInstraction.setTransform(transform, at: CMTime.zero)
        }else {
            let scale = CGAffineTransform(scaleX: 0.5, y: 0.5)
            let yFirstLayer = (size.height - size.height/2) / 2
            
            let move = CGAffineTransform(translationX: 0, y: yFirstLayer)
            let transform = scale.concatenating(move)
            firstLayerInstraction.setTransform(transform, at: CMTime.zero)
            
            _ = targetSize.height/2/size.height
            
            let secondScale = CGAffineTransform(scaleX: 1, y: 1)
            let xSecondLayer = -(size.width - size.width/2)/2
            let secondMove = CGAffineTransform(translationX: xSecondLayer, y: 0)
            let secondTransform = secondScale.concatenating(secondMove)
            secondLayerInstraction.setTransform(secondTransform, at: CMTime.zero)
        }
        
        mainInstraction.layerInstructions = [firstLayerInstraction , secondLayerInstraction]
        
        let  mainCompositonInst = AVMutableVideoComposition()
        mainCompositonInst.instructions = [mainInstraction]
        mainCompositonInst.frameDuration = CMTimeMake(value: 1, timescale: 30)
        let newSize = isPortrait ? CGSize(width: targetSize.width/2, height: targetSize.height) : CGSize(width: targetSize.height/2, height: targetSize.width)
        mainCompositonInst.renderSize = newSize
        
        //Extract audio from the video and the music
        let audioMix: AVMutableAudioMix = AVMutableAudioMix()
        var audioMixParam: [AVMutableAudioMixInputParameters] = []
        
        let assetVideoTrack: AVAssetTrack = firstAssets.tracks(withMediaType: AVMediaType.audio)[0]
        
        let videoParam: AVMutableAudioMixInputParameters = AVMutableAudioMixInputParameters(track: firstTrack)
        videoParam.trackID = compositionAudioVideo.trackID
        
        //Set final volume of the audio record and the music
        videoParam.setVolume(1, at: CMTime.zero)
        
        audioMixParam.append(videoParam)
        
        //Add audio on final record
        //First: the audio of the record and Second: the music
        do {
            try compositionAudioVideo.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: firstAssets.duration), of: assetVideoTrack, at: CMTime.zero)
        } catch _ {
            assertionFailure()
        }
        
        //Add parameter
        audioMix.inputParameters = audioMixParam
        
        self.exportURL(asset: mixComposition, mainCompositonInst: mainCompositonInst, size: newSize, audioMix: audioMix) { (url, isResult) in
            if isResult {
                self.mergeVideosSidebySide(firstUrl: url!, SecondUrl: urlBellow, targetSize: CGSize(width: Constant.VIDEO_EXPORT_WIDTH, height: Constant.VIDEO_EXPORT_HEIGHT)) { videOutput in
                    if let url = videOutput {
                        Utilities.instance.urlTemp.append(url)
                    }
                    completion(videOutput)
                }
                
            }else {
                completion(nil)
            }
        }
    }
    
    func mergeVideosSidebySide(firstUrl : URL , SecondUrl : URL, targetSize: CGSize, _ template: Template = .CompareView, completion: @escaping (_ result: URL?)->())  {
        
        let firstAssets = AVAsset(url: firstUrl)
        let secondAssets = AVAsset(url: SecondUrl)
        
        let mixComposition = AVMutableComposition()
        
        let firstTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let seconTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        let compositionAudioVideo: AVMutableCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: CMPersistentTrackID())!
        let compositionAudioMusic: AVMutableCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: CMPersistentTrackID())!
        
        do{
            if secondAssets.duration > firstAssets.duration {
                
                try   firstTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: firstAssets
                    .duration), of: firstAssets.tracks(withMediaType: .video)[0], at: CMTime.zero)
            }else {
                try   firstTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: secondAssets.duration), of: firstAssets.tracks(withMediaType: .video)[0], at: CMTime.zero)
            }
            
            try seconTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: secondAssets.duration), of: secondAssets.tracks(withMediaType: .video)[0], at: CMTime.zero)
        }catch{
            
        }
        let mainInstraction = AVMutableVideoCompositionInstruction()
        
        mainInstraction.timeRange  = CMTimeRangeMake(start: CMTime.zero, duration: secondAssets.duration)
        
        let firstLayerInstraction = AVMutableVideoCompositionLayerInstruction(assetTrack: firstTrack!)
        let secondLayerInstraction = AVMutableVideoCompositionLayerInstruction(assetTrack: seconTrack!)
        let size = firstUrl.getSizeVideo()!
        var scale: CGAffineTransform?
        
        if size.width == targetSize.width/2 {
            scale = CGAffineTransform(scaleX: 1, y: 1)
            
        }else {
            scale = CGAffineTransform(scaleX: targetSize.width/2/size.width, y: targetSize.height/size.height)
        }
        
        var move = CGAffineTransform(translationX: 0, y: 0)
        var transform = scale?.concatenating(move)
        
        var secondSize = (seconTrack?.naturalSize)!
        var secondScale = CGAffineTransform(scaleX: targetSize.width/secondSize.width, y: targetSize.height/secondSize.height)
        let xSecondLayer = targetSize.width/4
        var secondMove = CGAffineTransform(translationX: xSecondLayer, y: 0)
        var secondTransform = secondScale.concatenating(secondMove)
        
        if template == .CommentView {
            
            let widthTarget: CGFloat = (targetSize.width * (Utilities.instance.commentFrame?.size.width ?? Constant.VIDEO_EXPORT_WIDTH)) / 667
            
            let heighTarget = (targetSize.height * (Utilities.instance.commentFrame?.size.height ?? Constant.VIDEO_EXPORT_HEIGHT)) / 375
            
            let y = targetSize.height - heighTarget
            
            scale = CGAffineTransform(scaleX: widthTarget/size.width, y: heighTarget/size.height)
            move = CGAffineTransform(translationX: 0, y: y)
            
            transform = scale?.concatenating(move)
            secondSize = (seconTrack?.naturalSize)!
            
            secondScale = CGAffineTransform(scaleX: 1, y: 1)
            secondMove = CGAffineTransform(translationX: 0, y: 0)
            secondTransform = secondScale.concatenating(secondMove)
        }
        
        firstLayerInstraction.setTransform(transform!, at: CMTime.zero)
        secondLayerInstraction.setTransform(secondTransform, at: CMTime.zero)
        
        mainInstraction.layerInstructions = [firstLayerInstraction , secondLayerInstraction]
        
        let  mainCompositonInst = AVMutableVideoComposition()
        mainCompositonInst.instructions = [mainInstraction]
        mainCompositonInst.frameDuration = CMTimeMake(value: 1, timescale: 30)
        mainCompositonInst.renderSize = targetSize
        
        //Extract audio from the video and the music
        let audioMix: AVMutableAudioMix = AVMutableAudioMix()
        var audioMixParam: [AVMutableAudioMixInputParameters] = []
        
        let assetMusicTrack: AVAssetTrack = firstAssets.tracks(withMediaType: AVMediaType.audio)[0]
        let assetVideoTrack: AVAssetTrack = secondAssets.tracks(withMediaType: AVMediaType.audio)[0]
        
        let videoParam: AVMutableAudioMixInputParameters = AVMutableAudioMixInputParameters(track: assetVideoTrack)
        videoParam.trackID = compositionAudioVideo.trackID
        
        let musicParam: AVMutableAudioMixInputParameters = AVMutableAudioMixInputParameters(track: assetMusicTrack)
        musicParam.trackID = compositionAudioMusic.trackID
        
        //Set final volume of the audio record and the music
        videoParam.setVolume(1, at: CMTime.zero)
        if Utilities.instance.isEarPieceAvailable {
            musicParam.setVolume(Constant.VOLUME_MUSIC, at: CMTime.zero)
        }else {
            musicParam.setVolume(0, at: CMTime.zero)
        }
        //        musicParam.setVolume(0, at: kCMTimeZero)
        
        audioMixParam.append(musicParam)
        audioMixParam.append(videoParam)
        
        //Add audio on final record
        //First: the audio of the record and Second: the music
        do {
            try compositionAudioVideo.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: secondAssets.duration), of: assetVideoTrack, at: CMTime.zero)
        } catch _ {
            assertionFailure()
        }
        
        do {
            try compositionAudioMusic.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: secondAssets.duration), of: assetMusicTrack, at: CMTime.zero)
        } catch _ {
            assertionFailure()
        }
        
        //Add parameter
        audioMix.inputParameters = audioMixParam
        
        self.exportURL(asset: mixComposition, mainCompositonInst: mainCompositonInst, size: targetSize, audioMix: audioMix) { (url, isResult) in
            completion(url)
        }
    }
    
    
    func mergeVideoWithImage(videoURL : URL , videoLayer : CALayer, parentLayer: CALayer, completion: @escaping (_ result: URL?)->()) {
        
        let firstAssets = AVAsset(url: videoURL)
        
        let mixComposition = AVMutableComposition()
        let firstTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let compositionAudioVideo: AVMutableCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: CMPersistentTrackID())!
        do{
            try   firstTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: firstAssets.duration), of: firstAssets.tracks(withMediaType: .video)[0], at: CMTime.zero)
        }catch{
        }
        
        var size = (firstTrack?.naturalSize)!
        
        var scale = CGAffineTransform(scaleX: 1, y: 1)
        var move = CGAffineTransform(translationX: 0, y: 0)
        if size.width > size.height {
            scale = CGAffineTransform(scaleX: Constant.VIDEO_EXPORT_WIDTH/size.width , y:  Constant.VIDEO_EXPORT_HEIGHT/size.height)
            var translationX: CGFloat = 0
            var translationY: CGFloat = 0
            size = CGSize(width: Constant.VIDEO_EXPORT_WIDTH, height: Constant.VIDEO_EXPORT_HEIGHT)
            if scale.a < 1 {
                translationX = (size.width - Constant.VIDEO_EXPORT_WIDTH) / 2
            }
            
            if scale.d < 1 {
                
                translationY = (size.height - Constant.VIDEO_EXPORT_HEIGHT) / 2
            }
            
            move = CGAffineTransform(translationX: translationX, y: translationY)
        }else if size.width == size.height {
            scale = CGAffineTransform(scaleX: Constant.VIDEO_EXPORT_WIDTH/size.width , y:  Constant.VIDEO_EXPORT_WIDTH/size.width)
            var translationX: CGFloat = 0
            var translationY: CGFloat = 0
            size = CGSize(width: Constant.VIDEO_EXPORT_WIDTH, height: Constant.VIDEO_EXPORT_WIDTH)
            if scale.a < 1 {
                translationX = (size.width - Constant.VIDEO_EXPORT_WIDTH) / 2
            }
            
            if scale.d < 1 {
                
                translationY = (size.height - Constant.VIDEO_EXPORT_HEIGHT) / 2
            }
            
            move = CGAffineTransform(translationX: translationX, y: translationY)
        } else {
            scale = CGAffineTransform(scaleX: Constant.VIDEO_EXPORT_WIDTH_PORTRAIT/size.width , y: Constant.VIDEO_EXPORT_HEIGHT_PORTRAIT/size.height)
            size = CGSize(width: Constant.VIDEO_EXPORT_WIDTH_PORTRAIT, height: Constant.VIDEO_EXPORT_HEIGHT_PORTRAIT)
            var translationX: CGFloat = 0
            var translationY: CGFloat = 0
            if scale.a < 1 {
                translationX = (size.width - Constant.VIDEO_EXPORT_WIDTH_PORTRAIT) / 2
            }
            
            if scale.d < 1 {
                
                translationY = (size.height - Constant.VIDEO_EXPORT_HEIGHT_PORTRAIT) / 2
            }
            
            move = CGAffineTransform(translationX: translationX, y: translationY)
        }
        
        let firstLayerInstraction = AVMutableVideoCompositionLayerInstruction(assetTrack: firstTrack!)
        let mainInstraction = AVMutableVideoCompositionInstruction()
        
        mainInstraction.timeRange  = CMTimeRangeMake(start: CMTime.zero, duration: firstAssets.duration)
        let transform = scale.concatenating(move)
        firstLayerInstraction.setTransform(transform, at: CMTime.zero)
        
        mainInstraction.layerInstructions = [firstLayerInstraction]
        
        let  mainCompositonInst = AVMutableVideoComposition()
        mainCompositonInst.instructions = [mainInstraction]
        mainCompositonInst.frameDuration = CMTimeMake(value: 1, timescale: 30)
        mainCompositonInst.renderSize = size
        mainCompositonInst.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
        
        let audioMix: AVMutableAudioMix = AVMutableAudioMix()
        
        var audioMixParam: [AVMutableAudioMixInputParameters] = []
        
        let assetVideoTrack: AVAssetTrack = firstAssets.tracks(withMediaType: AVMediaType.audio)[0]
        
        let videoParam: AVMutableAudioMixInputParameters = AVMutableAudioMixInputParameters(track: assetVideoTrack)
        videoParam.trackID = compositionAudioVideo.trackID
        
        videoParam.setVolume(1.0, at: CMTime.zero)
        
        audioMixParam.append(videoParam)
        
        do {
            try compositionAudioVideo.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: firstAssets.duration), of: assetVideoTrack, at: CMTime.zero)
        } catch _ {
            assertionFailure()
        }
        
        audioMix.inputParameters = audioMixParam
        
        self.exportURL(asset: mixComposition, mainCompositonInst: mainCompositonInst, size: size, audioMix: audioMix) { (url, isResult) in
            completion(url)
        }
        
    }
    
    func blurVideo(_ url: URL, urlBellow: URL, completion: @escaping (_ result: URL?)->()) {
        
        //        let arr = NSMutableArray(array: [url])
        
        let firstAssets = AVAsset(url: url)
        let mixComposition = AVMutableComposition()
        let firstTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        do{
            try   firstTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: firstAssets.duration), of: firstAssets.tracks(withMediaType: .video)[0], at: CMTime.zero)
        }catch{
            
        }
        
        let sizeOriginal = firstTrack?.naturalSize
        
        let size = url.getSizeVideo()!
        
        if sizeOriginal?.width == size.height && size.width != size.height {
            
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileName = String(Date().timeIntervalSince1970).toBase64() + ".mp4"
            let exportURL = documentsDirectory.appendingPathComponent(fileName)
            
            let videoEditor = LLVideoEditor(videoURL: url)
            
            videoEditor?.rotate(LLRotateDegree90)
            
            videoEditor?.export(to: exportURL, completionBlock: { [weak self] (session) in
                
                guard let `self` = self else { return }
                
                switch (session?.status)! {
                case .completed:
                    Utilities.instance.urlTemp.append(exportURL)
                    self.addOverlayBlurVideo(exportURL, urlBellow: urlBellow){ (video) in
                        completion(video)
                    }
                    break
                case .cancelled, .failed, .unknown:

                    if self.isForeground && self.isCompressing {
                        self.autoReProgress.onNext(self.dataPost)
                    }else {
                        if let error = session?.error {
                            self.progressFail.onNext((error.localizedDescription, self.dataPost))
                        }
                    }
                    break
                default:
                    self.progressFail.onNext(("Processing fail", self.dataPost))
                    break
                }
            })
        }else {
            
            self.addOverlayBlurVideo(url, urlBellow: urlBellow){ (video) in
                completion(video)
            }
        }
    }
    
    func addOverlayBlurVideo(_ url: URL, urlBellow: URL, completion: @escaping (_ result: URL?)->()) {
        
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        var overlayLayer = CALayer()
        
        var rect = CGRect(x: 0, y: 0, width: Constant.VIDEO_EXPORT_WIDTH, height: Constant.VIDEO_EXPORT_HEIGHT)
        
        let firstAssets = AVAsset(url: url)
        let mixComposition = AVMutableComposition()
        let firstTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        do{
            try   firstTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: firstAssets.duration), of: firstAssets.tracks(withMediaType: .video)[0], at: CMTime.zero)
        }catch{
            
        }
        
        let size = (firstTrack?.naturalSize)!
        
        
        if size.width > size.height {
            
            rect = CGRect(x: 0, y: 0, width: Constant.VIDEO_EXPORT_WIDTH, height: Constant.VIDEO_EXPORT_HEIGHT)
            parentLayer.frame = rect
            videoLayer.frame = rect
            overlayLayer.frame = rect
        }else if  size.width == size.height{
            rect = CGRect(x: 0, y: 0, width: Constant.VIDEO_EXPORT_WIDTH, height: Constant.VIDEO_EXPORT_WIDTH)
            parentLayer.frame = rect
            videoLayer.frame = rect
            overlayLayer.frame = rect
        } else {
            rect = CGRect(x: 0, y: 0, width: Constant.VIDEO_EXPORT_WIDTH_PORTRAIT, height: Constant.VIDEO_EXPORT_HEIGHT_PORTRAIT)
            parentLayer.frame = rect
            videoLayer.frame = rect
            overlayLayer.frame = rect
        }
        
        parentLayer.addSublayer(videoLayer)
        overlayLayer.masksToBounds = true
        parentLayer.addSublayer(overlayLayer)
        
        
        self.mergeVideoWithImage(videoURL: url, videoLayer: videoLayer, parentLayer: parentLayer) { (videoURL) in
            
            if let videoURL = videoURL {
                DispatchQueue.main.async {
                    
                    if size.width > size.height {
                        if size.width < Constant.VIDEO_EXPORT_WIDTH {
                            self.blurViewVideo = UIView(frame: rect)
                        }else {
                            
                            self.blurViewVideo = UIView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: size))
                        }
                    }else if size.width == size.height{
                        self.blurViewVideo = UIView(frame: rect)
                    }else {
                        
                        if size.width < Constant.VIDEO_EXPORT_WIDTH_PORTRAIT {
                            self.blurViewVideo = UIView(frame: rect)
                        }else {
                            
                            self.blurViewVideo = UIView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: size))
                        }
                    }
                    
                    self.blurViewVideo?.addVisualBlurView((self.blurViewVideo?.frame)!)
                    overlayLayer = (self.blurViewVideo?.layer)!
                    parentLayer.addSublayer(videoLayer)
                    overlayLayer.masksToBounds = true
                    parentLayer.addSublayer(overlayLayer)
                }
                self.mergeVideoWithImage(videoURL: url, videoLayer: videoLayer, parentLayer: parentLayer) { (videooutput) in
                    
                    if let videooutput = videooutput {
                        var targetSize = CGSize(width: rect.size.height, height: rect.size.width)
                        if targetSize.width == targetSize.height {
                            targetSize.height = Constant.VIDEO_EXPORT_HEIGHT
                        }
                        self.mergeVideos(firstUrl: videoURL, SecondUrl: videooutput, urlBellow: urlBellow, targetSize: targetSize) { (urlVideo) in
                            completion(urlVideo)
                        }
                    }
                }
            }
        }
    }
    
    // Remove file
    
    func deleteVideoFile(_ videoUrl: [URL]) {
        do {
            let nsDocumentDirectory = FileManager.SearchPathDirectory.documentDirectory
            let nsUserDomainMask    = FileManager.SearchPathDomainMask.userDomainMask
            let paths               = NSSearchPathForDirectoriesInDomains(nsDocumentDirectory, nsUserDomainMask, true)
            if let dirPath          = paths.first
            {
                for item in videoUrl {
                    let url = URL(fileURLWithPath: dirPath).appendingPathComponent(item.absoluteURL.lastPathComponent)
                    try FileManager.default.removeItem(at: url)
                }
            }
        }
        catch let error as NSError {
            print("Ooops! Something went wrong: \(error)")
        }
    }
    
    // MERGE LAYER
    
    func mergeVideosArray(withLayer assets: NSMutableArray, templateID: Int, video videoLayer: CALayer?, parent parentLayer: CALayer?, _ outputVideoOrientation: UIDeviceOrientation? = nil, completion: @escaping (URL?, Bool) -> Void) {
        
        self.mergeVideos(withFileURLs: assets as! [URL], video: videoLayer, parent: parentLayer) { (url, e) in
            if let error = e {
                self.progressFail.onNext((error.localizedDescription, self.dataPost))
            }else {
                if url != nil {
                    self.deleteVideoFile(assets as! [URL])
                    completion(url, true)
                }else {
                    completion(nil, false)
                }
            }
        }
    }
    
    func exportURL(asset: AVMutableComposition, mainCompositonInst: AVMutableVideoComposition?, size: CGSize? = nil, audioMix: AVAudioMix? = nil , completion: @escaping (URL?, Bool) -> Void) {
        let exporter = NextLevelSessionExporter(withAsset: asset)
        exporter.outputFileType = AVFileType.mp4
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = String(Date().timeIntervalSince1970).toBase64() + ".mp4"
        let outputURL = documentsDirectory.appendingPathComponent(fileName)
        exporter.outputURL = outputURL
        exporter.videoComposition = mainCompositonInst
        let compressionDict: [String: Any] = [
            AVVideoAverageBitRateKey: NSNumber(integerLiteral: 4000000),
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel as String,
            ]
        
        let sizeExport = size != nil ? size! : CGSize(width: Constant.VIDEO_EXPORT_WIDTH, height: Constant.VIDEO_EXPORT_HEIGHT)
        exporter.videoOutputConfiguration = [
            AVVideoCodecKey: AVVideoCodecH264,
            AVVideoWidthKey: NSNumber(integerLiteral: Int(sizeExport.width)),
            AVVideoHeightKey: NSNumber(integerLiteral: Int(sizeExport.height)),
            AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
            AVVideoCompressionPropertiesKey: compressionDict
        ]
        exporter.audioMix = audioMix
        exporter.audioOutputConfiguration = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVEncoderBitRateKey: NSNumber(integerLiteral: 128000),
            AVNumberOfChannelsKey: NSNumber(integerLiteral: 2),
            AVSampleRateKey: NSNumber(value: Float(44100))
        ]
        
        do {
            try exporter.export(completionHandler: { (status) in
                switch status {
                case .completed:
                    print("video export completed")
                    Utilities.instance.urlTemp.append(outputURL)
                    completion(outputURL, true)
                    break
                case .cancelled, .failed, .unknown:
                    print("video export cancelled")
                    if self.isForeground && self.isCompressing {
                        self.autoReProgress.onNext(self.dataPost)
                        completion(nil, false)
                    }else {
                        self.progressFail.onNext(("Processing fail!", self.dataPost))
                        completion(nil, false)
                    }
//                    self.progressFail.onNext(("Processing fail!", self.dataPost))
//                    completion(nil, false)
                    break
                default:
                    self.progressFail.onNext(("Processing fail!", self.dataPost))
                    completion(nil, false)
                    break
                }
            })
        } catch {
            print("failed to export")
            self.progressFail.onNext(("Processing fail!", self.dataPost))
            completion(nil, false)
        }
    }
    
    func getVideoOrientation(from asset: AVAsset?) -> UIImage.Orientation {
        let videoTrack: AVAssetTrack? = asset?.tracks(withMediaType: .video)[0]
        let size: CGSize? = videoTrack?.naturalSize
        let txf: CGAffineTransform? = videoTrack?.preferredTransform
        
        if size?.width == txf?.tx && size?.height == txf?.ty {
            return .left
        } else if txf?.tx == 0 && txf?.ty == 0 {
            return .right
        } else if txf?.tx == 0 && txf?.ty == size?.width {
            return .down
        } else {
            return .up
        }
    }
    
    func mergeVideos(withFileURLs videoFileURLs: [URL], video videoLayer: CALayer?, parent parentLayer: CALayer?, completion: @escaping (_ mergedVideoURL: URL?, _ error: Error?) -> Void) {
        
        let composition = AVMutableComposition()
        guard let videoTrack: AVMutableCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            completion(nil, videoTarckError())
            return
        }
        guard let audioTrack: AVMutableCompositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            completion(nil, audioTarckError())
            return
        }
        var instructions = [AVVideoCompositionInstructionProtocol]()
        var isError = false
        var currentTime: CMTime = CMTime.zero
        var videoSize = CGSize.zero
        var highestFrameRate = 0
        
        for  videoFileURL in videoFileURLs {
            let options = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
            let asset = AVURLAsset(url: videoFileURL, options: options)
            guard let videoAsset: AVAssetTrack = asset.tracks(withMediaType: .video).first else {
                completion(nil, videoTarckError())
                return
            }
            guard let audioAsset: AVAssetTrack = asset.tracks(withMediaType: .audio).first else {
                completion(nil, audioTarckError())
                return
            }
            videoSize = videoAsset.naturalSize
            let currentFrameRate = Int(roundf((videoAsset.nominalFrameRate)))
            highestFrameRate = (currentFrameRate > highestFrameRate) ? currentFrameRate : highestFrameRate
            let trimmingTime: CMTime = CMTimeMake(value: Int64(lround(Double((videoAsset.nominalFrameRate) / (videoAsset.nominalFrameRate)))), timescale: Int32((videoAsset.nominalFrameRate)))
            let timeRange: CMTimeRange = CMTimeRangeMake(start: trimmingTime, duration: CMTimeSubtract((videoAsset.timeRange.duration), trimmingTime))
            do {
                try videoTrack.insertTimeRange(timeRange, of: videoAsset, at: currentTime)
                try audioTrack.insertTimeRange(timeRange, of: audioAsset, at: currentTime)
                
                let videoCompositionInstruction = AVMutableVideoCompositionInstruction.init()
                videoCompositionInstruction.timeRange = CMTimeRangeMake(start: currentTime, duration: timeRange.duration)
                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
                
                var tx: Int = 0
                if videoSize.width - videoAsset.naturalSize.width != 0 {
                    tx = Int((videoSize.width - videoAsset.naturalSize.width) / 2)
                }
                var ty: Int = 0
                if videoSize.height - videoAsset.naturalSize.height != 0 {
                    ty = Int((videoSize.height - videoAsset.naturalSize.height) / 2)
                }
                var Scale = CGAffineTransform(scaleX: 1, y: 1)
                if tx != 0 && ty != 0 {
                    if tx <= ty {
                        let factor = Float(videoSize.width / videoAsset.naturalSize.width)
                        Scale = CGAffineTransform(scaleX: CGFloat(factor), y: CGFloat(factor))
                        tx = 0
                        ty = Int((videoSize.height - videoAsset.naturalSize.height * CGFloat(factor)) / 2)
                    }
                    if tx > ty {
                        let factor = Float(videoSize.height / videoAsset.naturalSize.height)
                        Scale = CGAffineTransform(scaleX: CGFloat(factor), y: CGFloat(factor))
                        ty = 0
                        tx = Int((videoSize.width - videoAsset.naturalSize.width * CGFloat(factor)) / 2)
                    }
                }
                let Move = CGAffineTransform(translationX: CGFloat(tx), y: CGFloat(ty))
                layerInstruction.setTransform(Scale.concatenating(Move), at: CMTime.zero)
                videoCompositionInstruction.layerInstructions = [layerInstruction]
                instructions.append(videoCompositionInstruction)
                currentTime = CMTimeAdd(currentTime, timeRange.duration)
            } catch {
                print("Unable to load data: \(error)")
                isError = true
                completion(nil, error)
            }
        }
        
        if isError == false {
            let mutableVideoComposition = AVMutableVideoComposition.init()
            mutableVideoComposition.instructions = instructions
            mutableVideoComposition.frameDuration = CMTimeMake(value: 1, timescale: Int32(highestFrameRate))
            mutableVideoComposition.renderSize = CGSize(width: Constant.VIDEO_EXPORT_WIDTH, height: Constant.VIDEO_EXPORT_HEIGHT)
            mutableVideoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer!, in: parentLayer!)
            self.exportURL(asset: composition, mainCompositonInst: mutableVideoComposition) { (url, isResult) in
                if isResult {
                    completion(url, nil)
                }else {
                    completion(nil, nil)
                }
                
            }
        }
    }
    func videoTarckError() -> Error {
        let userInfo: [AnyHashable : Any] =
            [ NSLocalizedDescriptionKey :  NSLocalizedString("error", value: "Provide correct video file", comment: "") ,
              NSLocalizedFailureReasonErrorKey : NSLocalizedString("error", value: "No video track available", comment: "")]
        return NSError(domain: "DPVideoMerger", code: 404, userInfo: (userInfo as! [String : Any]))
    }
    func audioTarckError() -> Error {
        let userInfo: [AnyHashable : Any] =
            [ NSLocalizedDescriptionKey :  NSLocalizedString("error", value: "Video file had no Audio track", comment: "") ,
              NSLocalizedFailureReasonErrorKey : NSLocalizedString("error", value: "No Audio track available", comment: "")]
        return NSError(domain: "DPVideoMerger", code: 404, userInfo: (userInfo as! [String : Any]))
    }
    
    func generateMergedVideoFilePath() -> String {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = String(Date().timeIntervalSince1970).toBase64() + ".mp4"
        let exportURL = documentsDirectory.appendingPathComponent(fileName)
        return exportURL.absoluteString
    }
}
