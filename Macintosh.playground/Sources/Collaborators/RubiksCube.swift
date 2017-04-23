import Foundation
import UIKit
import SceneKit
import SpriteKit

public class RubiksCube: MacApp{
    
    /// The application main view
    public weak var container: UIView? = RubiksCubeView()
    
    public var desktopIcon: UIImage?
    
    public var identifier: String? = "rubikscube"
    
    public var windowTitle: String? = "Rubik's Cube"
    
    public var menuActions: [MenuAction]? = nil
    
    public var contentMode: ContentStyle = .light
    
    public var keepInMemory: Bool = false
    
    lazy public var uniqueIdentifier: String = {
        return UUID().uuidString
    }()
    
    public func sizeForWindow() -> CGSize {
        return CGSize(width: 250, height: 250)
    }
    
    public init(){
        desktopIcon = UIImage.withBezierPath(pathForIcon(), size: CGSize(width: 65, height: 65))
    }
    
    public func willTerminateApplication() {
        container = nil
    }
    
    public func willLaunchApplication(in view: OSWindow, withApplicationWindow appWindow: OSApplicationWindow) {
        container = RubiksCubeView()
    }
    
    func pathForIcon()->[SpecificBezierPath]{
        var sbpa = [SpecificBezierPath]()
        
        let size = MacAppDesktopView.width
        let boxSize = size / 5
        let startPos: CGFloat = boxSize
        
        for x in 0...2 {
            for y in 0...2 {
                let path = UIBezierPath(rect: CGRect(x: startPos + (CGFloat(x) * boxSize), y: startPos + (CGFloat(y) * boxSize), width: boxSize, height: boxSize))
                sbpa.append(SpecificBezierPath(path: path, stroke: true, fill: true, strokeColor: UIColor.black, fillColor: UIColor.clear))
            }
        }
        
        return sbpa
    }
}

fileprivate class RubiksCubeView: SCNView, UIGestureRecognizerDelegate {
    
    var defaultGestures: [UIGestureRecognizer]!
    var cube: Cube!
    lazy var pan: UIPanGestureRecognizer = {
        return UIPanGestureRecognizer(target: self, action: #selector(swipe(_:)))
    }()
    let camera = SCNCamera()
    let cameraNode = SCNNode()
    let centerNode = SCNNode()
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    public override init(frame: CGRect, options: [String : Any]? = nil) {
        super.init(frame: frame, options: options)
        setup()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func setup(){
        self.scene = SCNScene()
        self.backgroundColor = UIColor.black
        self.cube = Cube(rubiksView: self)
        
        setupGestures()
        setupCamera()
        setupSpace()
    }
    
    func setupGestures() {
        allowsCameraControl = true
        defaultGestures = self.gestureRecognizers
        allowsCameraControl = false
        
        pan.delegate = self
        addGestureRecognizer(pan)
        for gesture in defaultGestures {
            gesture.delegate = self
            addGestureRecognizer(gesture)
        }
        
    }
    
    func setupCamera() {
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(x: -4, y: 3, z: 5)
        add(node: cameraNode)
        let look = SCNLookAtConstraint(target: centerNode)
        look.isGimbalLockEnabled = true
        cameraNode.constraints = [look]
    }
    
    func setupSpace() {
        for color in UIColor.rubiksColors {
            let exp = SCNParticleSystem()
            exp.loops = true
            exp.birthRate = 100
            exp.emissionDuration = 1.0
            exp.spreadingAngle = 180
            exp.emitterShape = SCNSphere(radius: 50.0)
            exp.particleLifeSpan = 3
            exp.particleLifeSpanVariation = 2
            exp.particleVelocity = 0.5
            exp.particleVelocityVariation = 3
            exp.particleSize = 0.05
            exp.stretchFactor = 0.05
            exp.particleColor = color
            self.scene!.addParticleSystem(exp, transform: SCNMatrix4MakeRotation(0, 0, 0, 0))
        }
    }
    
    func side(from: SCNHitTestResult?) -> Side? {
        guard let from = from else {
            return nil
        }
        
        let pos = from.worldCoordinates
        
        let top = SCNVector3(0, 5, 0).distance(to: pos)
        let bottom = SCNVector3(0, -5, 0).distance(to: pos)
        let left = SCNVector3(-5, 0, 0).distance(to: pos)
        let right = SCNVector3(5, 0, 0).distance(to: pos)
        let back = SCNVector3(0, 0, 5).distance(to: pos)
        let front = SCNVector3(0, 0, -5).distance(to: pos)
        
        let all = [top, bottom, left, right, back, front]
        
        if top.isSmallest(from: all) {
            return .top
        } else if bottom.isSmallest(from: all) {
            return .bottom
        } else if left.isSmallest(from: all) {
            return .left
        } else if right.isSmallest(from: all) {
            return .right
        } else if back.isSmallest(from: all) {
            return .back
        } else if front.isSmallest(from: all) {
            return .front
        }
        
        return nil
    }
    
    func add(node: SCNNode) {
        scene?.rootNode.addChildNode(node)
    }
    
    var startPanPoint: CGPoint?
    var vertical = false
    var horizontal = false
    var offset: CGFloat = 0
    var selectedContainer: SCNNode?
    var selectedSide: Side?
    
    @objc func swipe(_ gestureRecognize: UIPanGestureRecognizer) {
        if cube.animating {
            return
        }
        let velocity = gestureRecognize.velocity(in: self)
        let point = gestureRecognize.location(in: self)
        let isVertical = abs(velocity.y) > abs(velocity.x)
        let isHorizontal = abs(velocity.x) > abs(velocity.y)
        let p = gestureRecognize.location(in: self)
        let hitResults = hitTest(p, options: [:])
        
        if selectedSide == nil {
            selectedSide = side(from: hitResults.first)
            
            if selectedSide == nil {
                return
            }
        }
        
        if startPanPoint == nil {
            startPanPoint = gestureRecognize.location(in: self)
        }
        
        if !vertical && !horizontal {
            vertical = isVertical
            horizontal = isHorizontal
        }
        
        if let rubiksScene = self.overlaySKScene as? RubiksScene {
            rubiksScene.removePlayInfo()
        }
        
        // selects the col/row to be rotated
        if gestureRecognize.state == .began {
            guard let node = hitResults.first?.node, node.position.y >= -2 else {
                return
            }
            
            if vertical {
                // change z, otherwise change y
                if selectedSide == .left || selectedSide == .right {
                    selectedContainer = cube.col(z: node.position.z)
                } else {
                    selectedContainer = cube.col(x: node.position.x)
                }
            } else {
                selectedContainer = cube.row(y: node.position.y)
            }
            add(node: selectedContainer!)
        }
        
        // rotates col/row
        if isVertical && vertical {
            offset = point.y - startPanPoint!.y // they share the same point pan
            if selectedSide == .left || selectedSide == .back {
                // switch its rotation direction
                offset = startPanPoint!.y - point.y
            }
            if selectedSide == .left || selectedSide == .right {
                selectedContainer?.rotation = SCNVector4(x: 0, y: 0, z: 1, w: Float(offset * CGFloat(Double.pi / 180)))
            } else {
                selectedContainer?.rotation = SCNVector4(x: 1, y: 0, z: 0, w: Float(offset * CGFloat(Double.pi / 180)))
            }
            
        } else if isHorizontal && horizontal {
            offset = point.x - startPanPoint!.x
            selectedContainer?.rotation = SCNVector4(x: 0, y: 1, z: 0, w: Float(offset * CGFloat(Double.pi / 180)))
        }
        
        // when it ends snap the col/row into the closest angle
        if gestureRecognize.state == .ended {
            if let container = selectedContainer {
                cube.snap(container: container, vertical: vertical, side: selectedSide!, finished: {
                    for node in self.selectedContainer?.childNodes ?? [SCNNode]() {
                        node.transform = self.selectedContainer!.convertTransform(node.transform, to: nil)
                        self.add(node: node)
                    }
                    self.selectedContainer = nil
                    self.selectedSide = nil
                    self.startPanPoint = nil
                    self.vertical = false
                    self.horizontal = false
                    self.offset = 0;
                    self.cube.animating = false
                })
            }
            
        }

    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        let p1 = gestureRecognizer.location(in: self)
        let hitResults1 = hitTest(p1, options: [:])
        let p2 = otherGestureRecognizer.location(in: self)
        let hitResults2 = hitTest(p2, options: [:])
        
        if hitResults1.isEmpty && hitResults2.isEmpty {
            if let rubiksScene = self.overlaySKScene as? RubiksScene {
                rubiksScene.removeBackgroundInfo()
            }
            return true
        } else {
            if gestureRecognizer == pan {
                return true
            }
            return false
        }
    }
}

fileprivate class Cube {
    
    var animating: Bool = false
    let rubiksView: RubiksCubeView

    public init(rubiksView: RubiksCubeView, fake: Bool = false) {
        self.rubiksView = rubiksView
        
        var toAnimate = [SCNNode]()
        // makes colored 27 SCNBox that makes up the cube
        for x in -1...1 {
            for y in -1...1 {
                for z in -1...1 {
                    let box = SCNBox(width: 0.9, height: 0.9, length: 0.9, chamferRadius: 0.0)
                    
                    let greenMaterial = SCNMaterial()
                    greenMaterial.diffuse.contents = UIColor.rubBlack
                    if z + 1 > 1 {
                        greenMaterial.diffuse.contents = UIColor.rubGreen
                    }
                    
                    let redMaterial = SCNMaterial()
                    redMaterial.diffuse.contents = UIColor.rubBlack
                    if x + 1 > 1 {
                        redMaterial.diffuse.contents = UIColor.rubRed
                    }
                    
                    let blueMaterial = SCNMaterial()
                    blueMaterial.diffuse.contents = UIColor.rubBlack
                    if z - 1 < -1 {
                        blueMaterial.diffuse.contents = UIColor.rubBlue
                    }
                    
                    let orangeMaterial = SCNMaterial()
                    orangeMaterial.diffuse.contents = UIColor.rubBlack
                    if x - 1 < -1 {
                        orangeMaterial.diffuse.contents = UIColor.rubOrange
                    }
                    
                    let whiteMaterial = SCNMaterial()
                    whiteMaterial.diffuse.contents = UIColor.rubBlack
                    if y + 1 > 1 {
                        whiteMaterial.diffuse.contents = UIColor.rubWhite
                    }
                    
                    let yellowMaterial = SCNMaterial()
                    yellowMaterial.diffuse.contents = UIColor.rubBlack
                    if y - 1 < -1 {
                        yellowMaterial.diffuse.contents = UIColor.rubYellow
                    }
                    
                    box.materials = [greenMaterial, redMaterial, blueMaterial, orangeMaterial, whiteMaterial, yellowMaterial]
                    
                    let node = SCNNode(geometry: box)
                    node.position = SCNVector3(x, y, z)
                    
                    if !fake {
                        rubiksView.add(node: node)
                        toAnimate.append(node)
                    } else {
                        rubiksView.add(node: node)
                        node.isHidden = true
                    }
                }
            }
        }
        
        if fake {
            return
        }
        
        // background Rubik's Cube that is hidden and scrambled that will replace
        let fakeCube = Cube(rubiksView: rubiksView, fake: true)
        fakeCube.scramble()
        
        // keeps track of hidden nodes
        var hidden = [SCNNode]()
        for n in self.rubiksView.scene!.rootNode.childNodes {
            if let geo = n.geometry, geo is SCNBox && n.isHidden {
                hidden.append(n)
            }
        }
        
        self.rubiksView.overlaySKScene = RubiksScene(size: self.rubiksView.frame.size)
        
        var animations = [SCNNode : SCNAction]()
        
        for node in toAnimate {
            let replaced = hidden.removeRandom()
            let pos = replaced.position
            let rot = replaced.rotation
            
            let fall = SCNAction.run({ (node) in
                if let _ = node.geometry, let _ = replaced.geometry {
                    node.geometry!.materials = replaced.geometry!.materials
                }
                self.rubiksView.allowsCameraControl = true
                node.rotation = rot
                node.position = pos
            })
            
            
            animations[node] = fall
        }
        
        for (node, animation) in animations {
            node.runAction(animation)
        }
    }
    
    func row(y: Float) -> SCNNode {
        let container = SCNNode()
        
        for node in rubiksView.scene!.rootNode.childNodes {
            if let geo = node.geometry, geo is SCNBox && node.position.y >= -2 && (node.position.y.isclose(to: y) || node.presentation.position.y.isclose(to: y)) {
                container.addChildNode(node)
            }
        }
        return container
    }
    
    func col(x: Float) -> SCNNode {
        let container = SCNNode()
        
        for node in rubiksView.scene!.rootNode.childNodes {
            if let geo = node.geometry, geo is SCNBox && node.position.y >= -2 && (node.position.x.isclose(to: x) || node.presentation.position.x.isclose(to: x)) {
                container.addChildNode(node)
            }
        }
        return container
    }
    
    func col(z: Float) -> SCNNode {
        let container = SCNNode()
        
        for node in rubiksView.scene!.rootNode.childNodes {
            if let geo = node.geometry, geo is SCNBox && node.position.y >= -2 && (node.position.z.isclose(to: z) || node.presentation.position.z.isclose(to: z)) {
                container.addChildNode(node)
            }
        }
        return container
    }
    
    func row(yy: Float) -> SCNNode {
        let container = SCNNode()
        
        for node in rubiksView.scene!.rootNode.childNodes {
            if let geo = node.geometry, geo is SCNBox && node.isHidden && node.position.y >= -2 && (node.position.y.isClose(to: yy) || node.presentation.position.y.isClose(to: yy)) {
                node.removeFromParentNode()
                container.addChildNode(node)
            }
        }
        return container
    }
    
    func col(xx: Float) -> SCNNode {
        let container = SCNNode()
        
        for node in rubiksView.scene!.rootNode.childNodes {
            if let geo = node.geometry, geo is SCNBox && node.isHidden && node.position.y >= -2 && (node.position.x.isClose(to: xx) || node.presentation.position.x.isClose(to: xx)) {
                node.removeFromParentNode()
                container.addChildNode(node)
            }
        }
        return container
    }
    
    func col(zz: Float) -> SCNNode {
        let container = SCNNode()
        
        for node in rubiksView.scene!.rootNode.childNodes {
            if let geo = node.geometry, geo is SCNBox && node.isHidden && node.position.y >= -2 && (node.position.z.isClose(to: zz) || node.presentation.position.z.isClose(to: zz)) {
                node.removeFromParentNode()
                container.addChildNode(node)
            }
        }
        return container
    }
    
    // scrambles cube randomly 63 times
    func scramble() {
        for _ in 0...20 {
            
            for _ in 0...2 {
                var container = SCNNode()
                let randomLevel = Float(Int(arc4random_uniform(2)) - 1)
                let randomTwist = Float(Int(arc4random_uniform(3)))
                var axis = SCNVector4()
                
                if randomTwist == 0 {
                    container = row(yy: randomLevel)
                    axis = SCNVector4(x: 0, y: 1, z: 0, w: Float.randomRotation())
                } else if randomTwist == 1 {
                    container = col(xx: randomLevel)
                    axis = SCNVector4(x: 1, y: 0, z: 0, w: Float.randomRotation())
                } else if randomTwist == 2 {
                    container = col(zz: randomLevel)
                    axis = SCNVector4(x: 0, y: 0, z: 1, w: Float.randomRotation())
                }
                
                container.rotation = axis
                for node in container.childNodes {
                    node.transform = container.convertTransform(node.transform, to: nil)
                    node.isHidden = true
                    node.removeFromParentNode()
                    rubiksView.add(node: node)
                }
                container.removeFromParentNode()
            }
        }
        
    }
    
    // snaps cow/col to closest rotation
    func snap(container: SCNNode, vertical: Bool, side: Side, finished: @escaping () -> ()) {
        self.animating = true
        
        let roundedOffset = Float(Int((abs(rubiksView.offset).truncatingRemainder(dividingBy: 360)) / 90.0 + 0.5) * 90) * Float(Double.pi / 180) * (rubiksView.offset < 0 ? -1 : 1)
        
        var rot: SCNVector4!
        
        if vertical {
            if side == .left || side == .right {
                rot = SCNVector4(x: 0, y: 0, z: 1, w: roundedOffset)
            } else {
                rot = SCNVector4(x: 1, y: 0, z: 0, w: roundedOffset)
            }
        } else {
            rot = SCNVector4(x: 0, y: 1, z: 0, w: roundedOffset)
        }
        
        container.runAction(SCNAction.sequence([SCNAction.rotate(toAxisAngle: rot, duration: 0.2), SCNAction.run({ (node) in
            finished()
            self.animating = false
        })]))
    }

}

fileprivate class RubiksScene: SKScene {
    
    var backgroundDirections: SKLabelNode!
    var playDirections: SKLabelNode!

    override init(size: CGSize) {
        super.init(size: size)
        
        self.scaleMode = .aspectFit
        setupHelp()
    }
    
    func setupHelp() {
        
        let fadeIn = SKAction.fadeIn(withDuration: 1.0)
        
        playDirections = SKLabelNode(text: "Drag on cube to turn blocks")
        playDirections.fontSize = 14.0
        playDirections.position = CGPoint(x: self.frame.midX, y: self.frame.height - 25)
        playDirections.alpha = 0.0
        self.addChild(playDirections)
        
        backgroundDirections = SKLabelNode(text: "Pan on background to move around")
        backgroundDirections.fontSize = 14.0
        backgroundDirections.position = CGPoint(x: self.frame.midX, y: self.frame.height - 45)
        backgroundDirections.alpha = 0.0
        self.addChild(backgroundDirections)
        
        backgroundDirections.run(fadeIn)
        playDirections.run(fadeIn)
        
    }
    
    func removeBackgroundInfo() {
        backgroundDirections.run(SKAction.sequence([SKAction.fadeOut(withDuration: 1.0), SKAction.run({
            self.backgroundDirections.removeFromParent()
        })]))
    }
    
    func removePlayInfo() {
        playDirections.run(SKAction.sequence([SKAction.fadeOut(withDuration: 1.0), SKAction.run({
            self.playDirections.removeFromParent()
        })]))
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

fileprivate enum Side{
    
    case top
    case bottom
    
    case left
    case right
    
    case front
    case back
    
}

fileprivate extension UIColor{
    
    // rubiks colors as an array for easy iteration
    static let rubiksColors = [rubGreen, rubRed, rubBlue, rubOrange, rubWhite, rubYellow]
    
    // rubiks colors
    static let rubGreen = UIColor(red:0.00, green:0.61, blue:0.28, alpha:1.00)
    static let rubRed = UIColor(red:0.72, green:0.07, blue:0.20, alpha:1.00)
    static let rubBlue = UIColor(red:0.00, green:0.27, blue:0.68, alpha:1.00)
    static let rubOrange = UIColor(red:1.00, green:0.35, blue:0.00, alpha:1.00)
    static let rubWhite = UIColor(red:1.00, green:1.00, blue:1.00, alpha:1.00)
    static let rubYellow = UIColor(red:1.00, green:0.84, blue:0.00, alpha:1.00)
    static let rubBlack = UIColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1.00)
    static let floor = UIColor(red:0.31, green:0.17, blue:0.08, alpha:1.00)
    
    // return random rubiks color (used for stars)
    static func randomRubiksColor() -> UIColor {
        return rubiksColors[Int(arc4random_uniform(UInt32(rubiksColors.count)))]
    }
    
}

fileprivate extension SCNVector3 {
    
    // not exact distance (values are not sqaure rooted), just to find the closest distance to point
    func distance(to: SCNVector3) -> Double {
        let x = self.x - to.x
        let y = self.y - to.y
        let z = self.z - to.z
        
        return Double((x * x) + (y * y) + (z * z))
    }
    
}

fileprivate extension Float {
    
    // 5% similiar
    func isClose(to: Float) -> Bool {
        let per = Float(0.5)
        let a = self
        let b = to
        let absA = abs(a)
        let absB = abs(b)
        let diff = abs(a - b)
        
        if (a == 0 || b == 0 || diff <  Float.leastNormalMagnitude) {
            return diff < (per * Float.leastNormalMagnitude)
        } else {
            return diff / (absA + absB) < per
        }
    }
    
    // is between 5% confidence interval
    func isclose(to: Float) -> Bool {
        return abs(self - to) < 0.05 || abs(to - self) < 0.05
    }
    
    // returns a random rotation in 90 degree intervals: 0, 90, 270, 360
    static func randomRotation() -> Float {
        // random between 1 and 359
        let randomDegreeNumber = Int(arc4random_uniform(360) + 1)
        // rounds it to nearest rotation
        let rotation = Float(Int((Double(randomDegreeNumber) / 90.0) + 0.5) * 90) * Float(Double.pi / 180)
        return rotation
    }
}

fileprivate extension Double {
    
    // returns the smallest doule from a array
    func isSmallest(from: [Double]) -> Bool {
        for value in from {
            if self < value {
                return false
            }
        }
        return true
    }
    
}

fileprivate extension Array {
    
    // returns random element in an array
    func random() -> Element {
        return self[Int(arc4random_uniform(UInt32(self.count)))]
    }
    
    // remove random array element and return that element
    mutating func removeRandom() -> Element {
        return self.remove(at: Int(arc4random_uniform(UInt32(self.count))))
    }
}

