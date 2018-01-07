//
//  ImagePickerTrayController.swift
//  ImagePickerTrayController
//
//  Created by Laurin Brandner on 14.10.16.
//  Copyright © 2016 Laurin Brandner. All rights reserved.
//

import UIKit
import Photos

fileprivate let itemSpacing: CGFloat = 1

/// The media type an instance of ImagePickerSheetController can display
public enum ImagePickerMediaType {
    case image
    case video
    case imageAndVideo
}

@objc public protocol ImagePickerTrayControllerDelegate {
    
    @objc optional func controller(_ controller: ImagePickerTrayController, willSelectAsset asset: PHAsset)
    @objc optional func controller(_ controller: ImagePickerTrayController, didSelectAsset asset: PHAsset)
    
    @objc optional func controller(_ controller: ImagePickerTrayController, willDeselectAsset asset: PHAsset)
    @objc optional func controller(_ controller: ImagePickerTrayController, didDeselectAsset asset: PHAsset)
    
    @objc optional func controller(_ controller: ImagePickerTrayController, didTakeImage image:UIImage)
}

public let ImagePickerTrayWillShow: Notification.Name = Notification.Name(rawValue: "ch.laurinbrandner.ImagePickerTrayWillShow")
public let ImagePickerTrayDidShow: Notification.Name = Notification.Name(rawValue: "ch.laurinbrandner.ImagePickerTrayDidShow")

public let ImagePickerTrayWillHide: Notification.Name = Notification.Name(rawValue: "ch.laurinbrandner.ImagePickerTrayWillHide")
public let ImagePickerTrayDidHide: Notification.Name = Notification.Name(rawValue: "ch.laurinbrandner.ImagePickerTrayDidHide")

public let ImagePickerTrayFrameUserInfoKey = "ImagePickerTrayFrame"
public let ImagePickerTrayAnimationDurationUserInfoKey = "ImagePickerTrayAnimationDuration"

fileprivate let animationDuration: TimeInterval = 0.25

public class ImagePickerTrayController: UIViewController, CameraViewDelegate {
    
    fileprivate(set) lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = itemSpacing
        layout.minimumLineSpacing = itemSpacing

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.contentInset = UIEdgeInsets(top: 1, left: 0, bottom: 2, right: 1)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        
        collectionView.register(ActionCell.self, forCellWithReuseIdentifier: NSStringFromClass(ActionCell.self))
        collectionView.register(CameraCell.self, forCellWithReuseIdentifier: NSStringFromClass(CameraCell.self))
        collectionView.register(ImageCell.self, forCellWithReuseIdentifier: NSStringFromClass(ImageCell.self))
        
        return collectionView
    }()
    
    fileprivate lazy var cameraView: CameraView = {
        let cameraView = CameraView()
        cameraView.delegate = self
        
        return cameraView
    }()
    
    fileprivate let imageManager = PHCachingImageManager()
    fileprivate var assets = [PHAsset]()
    fileprivate lazy var requestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        
        return options
    }()
    
    public var allowsMultipleSelection = true {
        didSet {
            if isViewLoaded {
                collectionView.allowsMultipleSelection = allowsMultipleSelection
            }
        }
    }
    public var allowsAutorotation = false
    
    fileprivate var imageSize: CGSize = .zero
    var heightConstraint: NSLayoutConstraint?
    let portraitTrayHeight: CGFloat
    let landscapeTrayHeight: CGFloat
    
    override public var shouldAutorotate: Bool {
        return self.allowsAutorotation
    }
    
    /// The actual Tray Height.
    // This is done based on current orientation, because that is correct while transitioning
    // If the orientation is faceUp or faceDown, we look at the StatusBar orientation.
    
    var trayHeight: CGFloat {
        let orientation = UIDevice.current.orientation
        
        switch orientation {
            case .portrait:
                return portraitTrayHeight
            case .portraitUpsideDown:
                return portraitTrayHeight
            case .landscapeLeft:
                return landscapeTrayHeight
            case .landscapeRight:
                return landscapeTrayHeight
            default:
                // in case of 'unknown' look at the screen size
                let screenSize = self.view.bounds.size
                if screenSize.width < screenSize.height {
                    return portraitTrayHeight
                } else {
                    return landscapeTrayHeight
                }
        }
    }
    
    fileprivate let actionCellWidth: CGFloat = 100
    fileprivate weak var actionCell: ActionCell?

    public fileprivate(set) var actions = [ImagePickerAction]()

    fileprivate var sections: [Int] {
        let actionSection = (actions.count > 0) ? 1 : 0
        let cameraSection = UIImagePickerController.isSourceTypeAvailable(.camera) && AVCaptureDevice.authorizationStatus(for: AVMediaType.video) == .authorized ? 1 : 0
        let assetSection = assets.count
        
        return [actionSection, cameraSection, assetSection]
    }
    
    public var delegate: ImagePickerTrayControllerDelegate?

    /// If set to `true` the tray can be dragged down in order to dismiss it
    /// Defaults to `true`
    public var allowsInteractivePresentation: Bool {
        get {
            return transitionController?.allowsInteractiveTransition ?? false
        }
        set {
            transitionController?.allowsInteractiveTransition = newValue
        }
    }
    private var transitionController: TransitionController?
    
    // MARK: - Initialization
    
    public init() {
        self.portraitTrayHeight = 216
		self.landscapeTrayHeight = 140
        
        super.init(nibName: nil, bundle: nil)

        transitionController = TransitionController(trayController: self)
        modalPresentationStyle = .custom
        transitioningDelegate = transitionController
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    
    public override func loadView() {
        super.loadView()
        
        view.backgroundColor = UIColor(red: 209.0/255.0, green: 213.0/255.0, blue: 218.0/255.0, alpha: 1.0)
        view.addSubview(collectionView)
        
        if #available(iOS 11, *) {
            collectionView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
            collectionView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor).isActive = true
            collectionView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor).isActive = true
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        } else {
            collectionView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
            collectionView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
            collectionView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        }

        collectionView.allowsMultipleSelection = allowsMultipleSelection
        
        let numberOfRows = (UIDevice.current.userInterfaceIdiom == .pad) ? 3 : 2
        let totalItemSpacing = CGFloat(numberOfRows-1)*itemSpacing + collectionView.contentInset.vertical
        let side = round((self.trayHeight - totalItemSpacing)/CGFloat(numberOfRows))
        self.imageSize = CGSize(width: side, height: side)
        
        self.requestAccess()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        fetchAssets()
        let orientation = UIApplication.shared.statusBarOrientation
        
        // check orientation, so the CameraView can be displayed in the proper orientation
        let angle: CGFloat
        switch orientation {
        case .portrait:
            angle = 0.0
        case .portraitUpsideDown:
            angle = CGFloat.pi
        case .landscapeLeft:
            angle = CGFloat.pi / 2
        case .landscapeRight:
            angle = -CGFloat.pi / 2
        default:
            angle = 0.0
        }

        let viewTransform = CGAffineTransform(rotationAngle: angle)
        self.cameraView.transform = viewTransform
        
        let screenSize = UIScreen.main.bounds.size
		let screenWidth = screenSize.width
        let screenHeight = screenSize.height
        let imagePickerFrame = CGRect(x: 0, y: screenHeight - self.trayHeight, width: screenWidth, height: self.trayHeight)
        self.post(name: ImagePickerTrayWillShow, frame: imagePickerFrame, duration: 0.25)
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        reloadActionCellDisclosureProgress()
        self.collectionView.reloadData()
    }
    
    override public func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Resize the Tray to fit in the Landcape or Portrait layout
        let numberOfRows = (UIDevice.current.userInterfaceIdiom == .pad) ? 3 : 2
        let totalItemSpacing = CGFloat(numberOfRows-1)*itemSpacing + collectionView.contentInset.vertical
        let side = round((self.trayHeight - totalItemSpacing)/CGFloat(numberOfRows))
        self.imageSize = CGSize(width: side, height: side)

        self.heightConstraint?.constant = -self.trayHeight
        self.collectionView.reloadData()
        
        let angle: CGFloat
        
        switch UIDevice.current.orientation {
        case .portrait:
            angle = 0.0
        case .portraitUpsideDown:
            angle = CGFloat.pi
        case .landscapeLeft:
            angle = -CGFloat.pi / 2
        case .landscapeRight:
            angle = CGFloat.pi / 2
        default:
            return
        }
        
        // When rotating, iOS shall always use the shortest way to rotate to the desired angle.
        // When rotating 180 degrees (for instance from landscapeLeft to landcapeRight),
        //  we need to make sure it rotates the way we want it to, hence the 0.01
        //  (which will be corrected in the completion handler)
        // Especially the transition between the two landscapes occurs a lot, because
        //   many apps do not support upsideDown Portrait.
        
        let almost = angle + 0.01
        let viewTransform = CGAffineTransform(rotationAngle: almost)
        
        coordinator.animate(alongsideTransition: { (context) in
            self.cameraView.transform = viewTransform
        }) { (context) in
            self.cameraView.transform = CGAffineTransform(rotationAngle: angle)
        }

        // If the device rotates orientation, the area not covered by the Top ViewController's view (i.e. the ImagePickerTrayViewController) will be covered by a Black UIView.
        // This is standard behaviour with rotating UIViewControllers.
        // Because we specifically do not want this, we must find the guilty one.
        // Actually, it can be done by just finding the subview with type UITransitionView, but as this is private api, we cannot use that.
        // as there are only two subviews, we can clip them both. For now, no harm done (iOS 11).
        
        // Beware, this is ugly code. Retest with every iOS release!!
        // if somebody finds a nicer solution, let me know!
        if let window = self.view.window {
            for view in window.subviews {
                view.clipsToBounds = true
            }
        }
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        let screenSize = UIScreen.main.bounds.size
        let screenWidth = screenSize.width
        let screenHeight = screenSize.height
        let imagePickerFrame = CGRect(x: 0, y: screenHeight, width: screenWidth, height: self.trayHeight)
        self.post(name: ImagePickerTrayWillHide, frame: imagePickerFrame, duration: 0.25)
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.cameraView.stopCamera()
        
        let screenSize = UIScreen.main.bounds.size
        let screenWidth = screenSize.width
        let screenHeight = screenSize.height
        let imagePickerFrame = CGRect(x: 0, y: screenHeight, width: screenWidth, height: self.trayHeight)
        self.post(name: ImagePickerTrayDidHide, frame: imagePickerFrame, duration: 0.25)
    }
    
    // MARK: - Action
    
    public func add(action: ImagePickerAction) {
        actions.append(action)
    }
    
    // MARK: - Images
    
    private func fetchAssets() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 100
        
        let result = PHAsset.fetchAssets(with: options)
        result.enumerateObjects({ asset, index, stop in
            self.assets.append(asset)
        })
    }
    
    private func requestImage(for asset: PHAsset, completion: @escaping (_ image: UIImage?) -> ()) {
        requestOptions.isSynchronous = true
        let size = scale(imageSize: imageSize)
        
        // Workaround because PHImageManager.requestImageForAsset doesn't work for burst images
        if asset.representsBurst {
            imageManager.requestImageData(for: asset, options: requestOptions) { data, _, _, _ in
                let image = data.flatMap { UIImage(data: $0) }
                completion(image)
            }
        }
        else {
            imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: requestOptions) { image, _ in
                completion(image)
            }
        }
    }
    
    private func prefetchImages(for asset: PHAsset) {
        let size = scale(imageSize: imageSize)
        imageManager.startCachingImages(for: [asset], targetSize: size, contentMode: .aspectFill, options: requestOptions)
    }
    
    private func scale(imageSize size: CGSize) -> CGSize {
        let scale = UIScreen.main.scale
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
    
    // MARK: - CameraViewDelegate
    
    func cameraView(cameraView: CameraView, didTake image: UIImage) {
        self.delegate?.controller?(self, didTakeImage: image)
    }
    
    // MARK: -
    
    private func reloadActionCellDisclosureProgress() {
        if sections[0] > 0 {
            actionCell?.disclosureProcess = (collectionView.contentOffset.x / (actionCellWidth/2))
        }
    }
    
    private func post(name: Notification.Name, frame: CGRect, duration: TimeInterval?) {
        var userInfo: [AnyHashable: Any] = [ImagePickerTrayFrameUserInfoKey: frame]
        if let duration = duration {
            userInfo[ImagePickerTrayAnimationDurationUserInfoKey] = duration
        }
        
        NotificationCenter.default.post(name: name, object: self, userInfo: userInfo)
    }
    
    private func requestAccess() {
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let authStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
            switch authStatus {
            case .authorized : break
            case .denied : self.showPhotoAlert()
            case .restricted : break
            case .notDetermined :
                // request permission
                AVCaptureDevice.requestAccess(for: AVMediaType.video) {
                    (granted) in
                    DispatchQueue.main.async {
                        self.collectionView.reloadSections(IndexSet(integer: 1))
                    }
                    if granted {
                        print("Video granted")
                    } else {
                        print("Video not granted")
                    }
                }
            }
        }
        
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let photos = PHPhotoLibrary.authorizationStatus()
            if photos == .notDetermined {
                PHPhotoLibrary.requestAuthorization {
                    (status) in
                    print("Photo library access \(status)")
                    DispatchQueue.main.async {
                        self.fetchAssets()
                        self.collectionView.reloadSections(IndexSet(integer: 2))
                    }
                }
            }
        }
    }
    
    private func showPhotoAlert() {
        let appName = self.applicationName
        
        let alertController = UIAlertController(title: "Permissions", message: "Your privacy settings in iOS do not allow the use of the Camera and / or Photos. Please go to your iOS Settings > Privacy > Photo's and / or iOS Settings > Privacy > Camera and allow \(appName) to use them.", preferredStyle: .alert)
        
        let OKAction = UIAlertAction(title: "OK", style: .default) { action in
            // ...
        }
        alertController.addAction(OKAction)
        self.present(alertController, animated: true)
    }
    
    private var applicationName: String {
        if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
            return displayName
        } else {
            return Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
        }
    }

}

// MARK: - UICollectionViewDataSource

extension ImagePickerTrayController: UICollectionViewDataSource {
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sections[section]
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch indexPath.section {
        case 0:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NSStringFromClass(ActionCell.self), for: indexPath) as! ActionCell
            cell.actions = actions
            actionCell = cell
            reloadActionCellDisclosureProgress()
            cell.clipsToBounds = true
            return cell
        case 1:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NSStringFromClass(CameraCell.self), for: indexPath) as! CameraCell
            if cell.cameraView == nil {
                cell.cameraView = self.cameraView
                cell.cameraOverlayView = CameraOverlayView()
            }
            cell.clipsToBounds = true
            return cell
        case 2:
            let asset = assets[indexPath.item]
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NSStringFromClass(ImageCell.self), for: indexPath) as! ImageCell
            cell.isVideo = (asset.mediaType == .video)
            cell.isRemote = (asset.sourceType != .typeUserLibrary)
            requestImage(for: asset) { cell.imageView.image = $0 }
            cell.clipsToBounds = true
            return cell
        default:
            fatalError("More than 3 sections is invalid.")
        }
    }
}

// MARK: - UICollectionViewDelegate

extension ImagePickerTrayController: UICollectionViewDelegate {
    
    public func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        guard indexPath.section == sections.count - 1 else {
            return false
        }
        
        delegate?.controller?(self, willSelectAsset: assets[indexPath.item])
        
        return true
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.controller?(self, didSelectAsset: assets[indexPath.item])
    }
    
    public func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        delegate?.controller?(self, willDeselectAsset: assets[indexPath.item])
        
        return true
    }
    
    public func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        delegate?.controller?(self, didDeselectAsset: assets[indexPath.item])
    }
    
}

// MARK: - UICollectionViewDelegateFlowLayout

extension ImagePickerTrayController: UICollectionViewDelegateFlowLayout {
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let maxItemHeight = collectionView.frame.height - collectionView.contentInset.vertical
        
        switch indexPath.section {
        case 0:	// Action buttons
            // are we portrait?
            return CGSize(width: actionCellWidth, height: maxItemHeight)
        case 1: // Camera cell
            let ratio: CGFloat = 1.5
            let orientation = UIApplication.shared.statusBarOrientation
            if orientation == .portrait || orientation == .portraitUpsideDown {
                return CGSize(width: maxItemHeight / ratio, height: maxItemHeight)
            } else {
                return CGSize(width: maxItemHeight * ratio, height: maxItemHeight)
            }
        case 2: // Image cell
            return imageSize
        default:
            return .zero
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        guard section == 1 else {
            return UIEdgeInsets()
        }
        
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 6)
    }
}

// MARK: - UIScrollViewDelegate

extension ImagePickerTrayController: UIScrollViewDelegate {

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        reloadActionCellDisclosureProgress()
    }
}

// MARK: - UIImagePickerControllerDelegate

extension ImagePickerTrayController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
            delegate?.controller?(self, didTakeImage: image)
        }
    }
    
}
