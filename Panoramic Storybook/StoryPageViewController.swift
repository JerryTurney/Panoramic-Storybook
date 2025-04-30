import UIKit
import SceneKit
import AVFoundation

// MARK: Flip-book UIPageViewController subclass
class StoryPageViewController: UIPageViewController, UIPageViewControllerDataSource {
    private var totalPages: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = self

        // Dynamically count Story_<n>.jpg files
        totalPages = computePageCount()

        // Start at first page
        let firstVC = makeContentVC(for: 0)
        setViewControllers([firstVC], direction: .forward, animated: false)
    }

    // Count sequentially named JPEGs: Story_0.jpg, Story_1.jpg, ...
    private func computePageCount() -> Int {
        var count = 0
        while Bundle.main.path(forResource: "Story_\(count)", ofType: "jpg") != nil {
            count += 1
        }
        return count
    }

    private func makeContentVC(for index: Int) -> PageContentViewController {
        let vc = PageContentViewController()
        vc.pageIndex = index
        vc.totalPages = totalPages
        return vc
    }

    func pageViewController(_ pvc: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let current = (viewController as? PageContentViewController)?.pageIndex,
              current > 0 else { return nil }
        return makeContentVC(for: current - 1)
    }

    func pageViewController(_ pvc: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let current = (viewController as? PageContentViewController)?.pageIndex,
              current + 1 < totalPages else { return nil }
        return makeContentVC(for: current + 1)
    }
}

// MARK: Individual page content
class PageContentViewController: UIViewController {
    var pageIndex: Int = 0
    var totalPages: Int = 1

    private var sceneView: SCNView!
    private var cameraNode: SCNNode!
    private var decelLink: CADisplayLink?
    private var panVelocity: CGFloat = 0
    private var initialFOV: CGFloat = 80
    private let minFOV: CGFloat = 30
    private let maxFOV: CGFloat = 100

    private var textView: UITextView!
    private var playButton: UIButton!
    private var audioPlayer: AVAudioPlayer?
    private var isPlaying = true

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        if pageIndex == 0 {
            setupCover()
        } else {
            setupPanorama()
            setupTextAndAudio()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard sceneView != nil else { return }

        // Layout 360 image (top 3/4)
        let fullHeight = view.bounds.height
        let imageHeight = fullHeight * 0.75
        sceneView.frame = CGRect(x: 0,
                                 y: 0,
                                 width: view.bounds.width,
                                 height: imageHeight)

        // Layout text box (bottom 1/4)
        textView.frame = CGRect(x: 0,
                                y: imageHeight,
                                width: view.bounds.width,
                                height: fullHeight - imageHeight)

        // Position speaker button just above text area
        let buttonSize = CGSize(width: 44, height: 44)
        let padding: CGFloat = 8
        let yPos = sceneView.bounds.height - buttonSize.height - padding
        playButton.frame = CGRect(
            x: (sceneView.bounds.width - buttonSize.width) / 2,
            y: yPos,
            width: buttonSize.width,
            height: buttonSize.height
        )
    }

    private func setupCover() {
        let iv = UIImageView(frame: view.bounds)
        iv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        iv.contentMode = .scaleAspectFill
        iv.image = UIImage(named: "Story_0.jpg")
        view.addSubview(iv)
    }

    private func setupPanorama() {
        sceneView = SCNView()
        sceneView.backgroundColor = .black
        sceneView.allowsCameraControl = false
        view.addSubview(sceneView)

        let scene = SCNScene()
        sceneView.scene = scene

        let sphere = SCNSphere(radius: 10)
        sphere.segmentCount = 96
        sphere.firstMaterial?.isDoubleSided = true
        sphere.firstMaterial?.cullMode = .front

        // Load and flip image horizontally
        let imageName = "Story_\(pageIndex).jpg"
        if let img = UIImage(named: imageName) {
            sphere.firstMaterial?.diffuse.contents = img
            sphere.firstMaterial?.diffuse.wrapS = .repeat
            sphere.firstMaterial?.diffuse.wrapT = .repeat
            sphere.firstMaterial?.diffuse.contentsTransform = SCNMatrix4MakeScale(-1, 1, 1)
        }

        let sphereNode = SCNNode(geometry: sphere)
        scene.rootNode.addChildNode(sphereNode)

        // Set camera and center initial view on middle of panorama
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = initialFOV
        // Rotate camera so it looks at the center of the image
        cameraNode.eulerAngles.y = Float.pi  // adjust if offset needs fine-tuning
        scene.rootNode.addChildNode(cameraNode)

        sceneView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
        sceneView.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:))))
    }

    private func setupTextAndAudio() {
        // Text box at bottom
        textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = false
        textView.backgroundColor = .black
        textView.textColor = .white
        textView.font = UIFont.preferredFont(forTextStyle: .title1)
        textView.text = loadStoryText(page: pageIndex)
        view.addSubview(textView)

        // Speaker toggle button over image
        playButton = UIButton(type: .system)
        playButton.setTitle("🔊", for: .normal)
        playButton.titleLabel?.font = UIFont.systemFont(ofSize: 28)
        playButton.backgroundColor = UIColor(white: 0, alpha: 0.5)
        playButton.layer.cornerRadius = 22
        playButton.addTarget(self, action: #selector(toggleAudio), for: .touchUpInside)
        sceneView.addSubview(playButton)

        // Prepare audio, start muted
        if let url = Bundle.main.url(forResource: "Story_\(pageIndex)", withExtension: "mp3") {
            audioPlayer = try? AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            isPlaying = false
            playButton.setTitle("🔇", for: .normal)
        }
    }

    private func loadStoryText(page: Int) -> String {
        let base = "Story_\(page)"
        for ext in ["txt", "TXT"] {
            if let path = Bundle.main.path(forResource: base, ofType: ext),
               let text = try? String(contentsOfFile: path) {
                return text
            }
        }
        return ""
    }

    @objc private func toggleAudio() {
        guard let player = audioPlayer else { return }
        if isPlaying {
            player.pause()
            playButton.setTitle("🔇", for: .normal)
        } else {
            player.play()
            playButton.setTitle("🔊", for: .normal)
        }
        isPlaying.toggle()
    }

    @objc private func handlePan(_ gr: UIPanGestureRecognizer) {
        let translation = gr.translation(in: sceneView)
        switch gr.state {
        case .changed:
            let yawDelta = Float(translation.x) * 0.005
            let pitchDelta = Float(translation.y) * 0.005
            cameraNode.eulerAngles.y -= yawDelta
            cameraNode.eulerAngles.x = clamp(
                cameraNode.eulerAngles.x - pitchDelta,
                min: -Float.pi/2 * 0.9,
                max:  Float.pi/2 * 0.9
            )
            gr.setTranslation(.zero, in: sceneView)
        case .ended:
            panVelocity = gr.velocity(in: sceneView).x
            startDeceleration()
        default:
            break
        }
    }

    @objc private func handlePinch(_ gr: UIPinchGestureRecognizer) {
        switch gr.state {
        case .began:
            initialFOV = cameraNode.camera?.fieldOfView ?? initialFOV
        case .changed:
            let newFOV = initialFOV / gr.scale
            cameraNode.camera?.fieldOfView = clamp(newFOV, min: minFOV, max: maxFOV)
        default:
            break
        }
    }

    private func startDeceleration() {
        decelLink?.invalidate()
        decelLink = CADisplayLink(target: self, selector: #selector(handleDecelTick))
        decelLink?.add(to: .main, forMode: .common)
    }

    @objc private func handleDecelTick() {
        panVelocity *= 0.95
        cameraNode.eulerAngles.y -= Float(panVelocity * 0.00005)
        if abs(panVelocity) < 5 {
            decelLink?.invalidate()
            decelLink = nil
        }
    }

    private func clamp<T: Comparable>(_ value: T, min: T, max: T) -> T {
        return Swift.min(Swift.max(value, min), max)
    }
}
