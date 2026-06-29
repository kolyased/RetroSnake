//
//  GameViewController.swift
//  RetroSnake
//
//  Created by Николай Чернобоков on 29.06.2026.
//

import UIKit
import SpriteKit

class GameViewController: UIViewController {
    private var gameScene: GameScene?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let view = self.view as? SKView {
            view.ignoresSiblingOrder = true
            view.showsFPS = false
            view.showsNodeCount = false
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        presentGameSceneIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentGameSceneIfNeeded()
    }

    private func presentGameSceneIfNeeded() {
        guard let view = self.view as? SKView else { return }

        let sceneSize = view.bounds.size
        guard sceneSize.width > 0, sceneSize.height > 0 else { return }

        if let gameScene {
            if gameScene.size != sceneSize {
                gameScene.size = sceneSize
            }
            return
        }

        let scene = GameScene(size: sceneSize)
        scene.scaleMode = .resizeFill
        gameScene = scene
        view.presentScene(scene)
        print("GameScene presented with size: \(sceneSize)")
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
}
