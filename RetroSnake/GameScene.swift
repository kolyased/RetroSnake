//
//  GameScene.swift
//  RetroSnake
//
//  Created by Николай Чернобоков on 29.06.2026.
//

import SpriteKit

enum Direction {
    case up
    case down
    case left
    case right

    var vector: GridPoint {
        switch self {
        case .up:
            return GridPoint(x: 0, y: 1)
        case .down:
            return GridPoint(x: 0, y: -1)
        case .left:
            return GridPoint(x: -1, y: 0)
        case .right:
            return GridPoint(x: 1, y: 0)
        }
    }

    func isOpposite(of direction: Direction) -> Bool {
        switch (self, direction) {
        case (.up, .down), (.down, .up), (.left, .right), (.right, .left):
            return true
        default:
            return false
        }
    }
}

enum GameState {
    case mainMenu
    case playing
    case paused
    case settings
    case gameOver
}

enum AppLanguage: String {
    case english = "en"
    case russian = "ru"
}

struct GridPoint: Hashable {
    let x: Int
    let y: Int
}

final class GameScene: SKScene {
    private enum NodeName {
        static let playButton = "playButton"
        static let settingsButton = "settingsButton"
        static let settingsFromPauseButton = "settingsFromPauseButton"
        static let soundToggleButton = "soundToggleButton"
        static let volumeMinusButton = "volumeMinusButton"
        static let volumePlusButton = "volumePlusButton"
        static let languageToggleButton = "languageToggleButton"
        static let settingsBackButton = "settingsBackButton"
        static let pauseButton = "pauseButton"
        static let resumeButton = "resumeButton"
        static let restartButton = "restartButton"
        static let mainMenuButton = "mainMenuButton"
        static let upButton = "upButton"
        static let downButton = "downButton"
        static let leftButton = "leftButton"
        static let rightButton = "rightButton"
    }

    private let columns = 20
    private let rows = 24
    private let moveInterval: TimeInterval = 0.14
    private let bestScoreKey = "RetroSnakeBestScore"
    private let appLanguageKey = "AppLanguage"
    private let localization: [AppLanguage: [String: String]] = [
        .english: [
            "title": "RETRO SNAKE",
            "best": "Best",
            "play": "Play",
            "settings": "Settings",
            "soundOn": "Sound: ON",
            "soundOff": "Sound: OFF",
            "volume": "Volume",
            "language": "Language: EN",
            "back": "Back",
            "paused": "PAUSED",
            "continue": "Continue",
            "restart": "Restart",
            "mainMenu": "Main Menu",
            "gameOver": "GAME OVER",
            "score": "Score"
        ],
        .russian: [
            "title": "РЕТРО ЗМЕЙКА",
            "best": "Рекорд",
            "play": "Играть",
            "settings": "Настройки",
            "soundOn": "Звук: ВКЛ",
            "soundOff": "Звук: ВЫКЛ",
            "volume": "Громкость",
            "language": "Язык: RU",
            "back": "Назад",
            "paused": "ПАУЗА",
            "continue": "Продолжить",
            "restart": "Заново",
            "mainMenu": "Главное меню",
            "gameOver": "ИГРА ОКОНЧЕНА",
            "score": "Счет"
        ]
    ]

    private var topBarContainer = SKNode()
    private var boardContainer = SKNode()
    private var controlsContainer = SKNode()
    private var mainMenuContainer = SKNode()
    private var pauseOverlay = SKNode()
    private var settingsOverlay = SKNode()
    private var gameOverOverlay = SKNode()

    private var pauseLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private var scoreLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private var soundToggleLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private var volumeLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private var languageToggleLabel = SKLabelNode(fontNamed: "Menlo-Bold")

    private var cellSize: CGFloat = 16
    private var boardOrigin = CGPoint.zero
    private var boardSize = CGSize.zero

    private var snake: [GridPoint] = []
    private var food: GridPoint?
    private var direction: Direction = .right
    private var requestedDirection: Direction?
    private var score = 0
    private var bestScore = 0
    private var lastMoveTime: TimeInterval = 0
    private var gameState: GameState = .mainMenu
    private var previousState: GameState = .mainMenu
    private var currentLanguage: AppLanguage = .english
    private var isGameRunning = false
    private var isGamePaused = false
    private var didShowGameOver = false
    private var touchStartPoint: CGPoint?

    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.035, green: 0.04, blue: 0.05, alpha: 1)
        bestScore = UserDefaults.standard.integer(forKey: bestScoreKey)
        loadLanguage()
        AudioManager.shared.loadSettings()

        setupLayout()
        showMainMenu()
        print("GameScene didMove size: \(size), children: \(children.count)")
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard view != nil else { return }

        setupLayout()
        renderGameBoard()
        switch gameState {
        case .mainMenu:
            showMainMenu()
        case .paused:
            showPauseOverlay()
        case .gameOver:
            showGameOverOverlay()
        case .settings:
            showSettingsOverlay()
        case .playing:
            pauseOverlay.removeAllChildren()
            settingsOverlay.removeAllChildren()
            gameOverOverlay.removeAllChildren()
            updateVisibleUIForState()
        }
    }

    func setupLayout() {
        guard size.width > 0, size.height > 0 else { return }

        removeAllChildren()

        topBarContainer = SKNode()
        boardContainer = SKNode()
        controlsContainer = SKNode()
        mainMenuContainer = SKNode()
        pauseOverlay = SKNode()
        settingsOverlay = SKNode()
        gameOverOverlay = SKNode()

        boardContainer.zPosition = 0
        topBarContainer.zPosition = 10
        controlsContainer.zPosition = 10
        pauseOverlay.zPosition = 30
        gameOverOverlay.zPosition = 30
        settingsOverlay.zPosition = 40
        mainMenuContainer.zPosition = 40

        addChild(topBarContainer)
        addChild(boardContainer)
        addChild(controlsContainer)
        addChild(pauseOverlay)
        addChild(gameOverOverlay)
        addChild(settingsOverlay)
        addChild(mainMenuContainer)

        setupTopBar()
        setupGameBoard()
        setupControls()
        updateVisibleUIForState()
    }

    func setupTopBar() {
        guard let view else { return }

        let safeTop = view.safeAreaInsets.top
        let sidePadding: CGFloat = 24
        let buttonSize = CGSize(width: 80, height: 50)
        let topY = size.height - safeTop - 24 - buttonSize.height / 2
        let pauseX = sidePadding + buttonSize.width / 2

        let pauseHitArea = SKShapeNode(rectOf: CGSize(width: 96, height: 64), cornerRadius: 8)
        pauseHitArea.name = NodeName.pauseButton
        pauseHitArea.position = CGPoint(x: pauseX, y: topY)
        pauseHitArea.fillColor = SKColor.white.withAlphaComponent(0.001)
        pauseHitArea.strokeColor = .clear
        pauseHitArea.lineWidth = 0
        pauseHitArea.zPosition = 30
        topBarContainer.addChild(pauseHitArea)

        let pauseButton = SKShapeNode(rectOf: buttonSize, cornerRadius: 8)
        pauseButton.name = NodeName.pauseButton
        pauseButton.position = CGPoint(x: pauseX, y: topY)
        pauseButton.fillColor = SKColor(red: 0.08, green: 0.1, blue: 0.12, alpha: 1)
        pauseButton.strokeColor = SKColor(red: 0.28, green: 0.95, blue: 0.36, alpha: 1)
        pauseButton.lineWidth = 1.5
        pauseButton.zPosition = 20
        topBarContainer.addChild(pauseButton)

        let barWidth: CGFloat = 6
        let barHeight: CGFloat = 26
        for xPosition in [-7, 7] {
            let pauseBar = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight), cornerRadius: 1.5)
            pauseBar.name = NodeName.pauseButton
            pauseBar.position = CGPoint(x: CGFloat(xPosition), y: 0)
            pauseBar.fillColor = .white
            pauseBar.strokeColor = .clear
            pauseButton.addChild(pauseBar)
        }

        scoreLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        scoreLabel.fontSize = 30
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.position = CGPoint(x: size.width - sidePadding, y: topY)
        topBarContainer.addChild(scoreLabel)

        updateScoreLabel()
    }

    func setupGameBoard() {
        guard let view else { return }

        let safeTop = view.safeAreaInsets.top
        let topBarBottom = size.height - safeTop - 66
        let controlsTop = controlsAreaTopY() + 18
        let availableHeight = max(220, topBarBottom - controlsTop - 18)
        let availableWidth = size.width - 14

        cellSize = floor(min(availableWidth / CGFloat(columns), availableHeight / CGFloat(rows)))
        cellSize = max(10, cellSize)

        boardSize = CGSize(width: cellSize * CGFloat(columns), height: cellSize * CGFloat(rows))
        boardOrigin = CGPoint(
            x: (size.width - boardSize.width) / 2,
            y: controlsTop + (availableHeight - boardSize.height) / 2
        )

        let boardFrame = SKShapeNode(rect: CGRect(origin: boardOrigin, size: boardSize), cornerRadius: 0)
        boardFrame.fillColor = SKColor(red: 0.015, green: 0.025, blue: 0.02, alpha: 1)
        boardFrame.strokeColor = SKColor(red: 0.28, green: 0.95, blue: 0.36, alpha: 1)
        boardFrame.lineWidth = 2
        boardFrame.zPosition = 0
        boardContainer.addChild(boardFrame)
    }

    func setupControls() {
        guard let view else { return }

        let safeBottom = view.safeAreaInsets.bottom
        let buttonSize = controlButtonSize()
        let gap: CGFloat = 10
        let centerX = size.width / 2
        let centerY = safeBottom + buttonSize * 1.5 + gap + 14

        addControlButton(symbol: "▲", name: NodeName.upButton, position: CGPoint(x: centerX, y: centerY + buttonSize + gap), size: buttonSize)
        addControlButton(symbol: "◀", name: NodeName.leftButton, position: CGPoint(x: centerX - buttonSize - gap, y: centerY), size: buttonSize)
        addControlButton(symbol: "▶", name: NodeName.rightButton, position: CGPoint(x: centerX + buttonSize + gap, y: centerY), size: buttonSize)
        addControlButton(symbol: "▼", name: NodeName.downButton, position: CGPoint(x: centerX, y: centerY - buttonSize - gap), size: buttonSize)
    }

    func startGame() {
        score = 0
        direction = .right
        requestedDirection = nil
        gameState = .playing
        isGameRunning = true
        isGamePaused = false
        didShowGameOver = false
        lastMoveTime = 0
        mainMenuContainer.removeAllChildren()
        pauseOverlay.removeAllChildren()
        settingsOverlay.removeAllChildren()
        gameOverOverlay.removeAllChildren()
        updateVisibleUIForState()
        AudioManager.shared.playBackgroundMusic()

        let startX = columns / 2
        let startY = rows / 2
        snake = [
            GridPoint(x: startX, y: startY),
            GridPoint(x: startX - 1, y: startY),
            GridPoint(x: startX - 2, y: startY)
        ]

        spawnFood()
        updateScoreLabel()
        renderGameBoard()
    }

    func restartGame() {
        startGame()
    }

    func moveSnake() {
        guard gameState == .playing, isGameRunning, let head = snake.first else { return }

        changeDirection()

        let vector = direction.vector
        let newHead = GridPoint(x: head.x + vector.x, y: head.y + vector.y)

        if newHead.x < 0 || newHead.x >= columns || newHead.y < 0 || newHead.y >= rows {
            gameOver()
            return
        }

        let didEatFood = newHead == food
        let bodyToCheck = didEatFood ? snake : Array(snake.dropLast())
        if bodyToCheck.contains(newHead) {
            gameOver()
            return
        }

        snake.insert(newHead, at: 0)

        if didEatFood {
            score += 1
            updateScoreLabel()
            AudioManager.shared.playEatSound()
            spawnFood()
        } else {
            snake.removeLast()
        }

        renderGameBoard()
    }

    func spawnFood() {
        var freeCells: [GridPoint] = []
        let occupied = Set(snake)

        for y in 0..<rows {
            for x in 0..<columns {
                let cell = GridPoint(x: x, y: y)
                if !occupied.contains(cell) {
                    freeCells.append(cell)
                }
            }
        }

        food = freeCells.randomElement()
    }

    func changeDirection() {
        guard let nextDirection = requestedDirection else { return }
        requestedDirection = nil

        if !nextDirection.isOpposite(of: direction) {
            direction = nextDirection
        }
    }

    func gameOver() {
        guard gameState != .gameOver, !didShowGameOver else { return }

        gameState = .gameOver
        isGameRunning = false
        didShowGameOver = true
        AudioManager.shared.playGameOverSound()

        if score > bestScore {
            bestScore = score
            UserDefaults.standard.set(bestScore, forKey: bestScoreKey)
        }

        showGameOverOverlay()
    }

    func pauseGame() {
        guard gameState == .playing, isGameRunning else { return }
        gameState = .paused
        isGamePaused = true
        showPauseOverlay()
    }

    func resumeGame() {
        guard gameState == .paused, isGameRunning else { return }
        gameState = .playing
        isGamePaused = false
        pauseOverlay.removeAllChildren()
        settingsOverlay.removeAllChildren()
        gameOverOverlay.removeAllChildren()
        updateVisibleUIForState()
        lastMoveTime = 0
    }

    func updateScoreLabel() {
        scoreLabel.text = "\(score)"
    }

    override func update(_ currentTime: TimeInterval) {
        guard gameState == .playing, isGameRunning else { return }

        if lastMoveTime == 0 {
            lastMoveTime = currentTime
            return
        }

        if currentTime - lastMoveTime >= moveInterval {
            lastMoveTime = currentTime
            moveSnake()
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        if handleButtonTap(at: location) {
            touchStartPoint = nil
            return
        }

        touchStartPoint = gameState == .playing ? location : nil
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        let location = touch.location(in: self)
        if let start = touchStartPoint {
            handleSwipe(from: start, to: location)
        }

        touchStartPoint = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStartPoint = nil
    }

    private func addControlButton(symbol: String, name: String, position: CGPoint, size: CGFloat) {
        let button = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 8)
        button.name = name
        button.position = position
        button.fillColor = SKColor(red: 0.08, green: 0.1, blue: 0.12, alpha: 1)
        button.strokeColor = SKColor(red: 0.86, green: 0.9, blue: 0.88, alpha: 1)
        button.lineWidth = 2
        controlsContainer.addChild(button)

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.name = name
        label.text = symbol
        label.fontSize = size * 0.42
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        button.addChild(label)
    }

    private func controlButtonSize() -> CGFloat {
        min(70, max(60, size.width * 0.18))
    }

    private func controlsAreaTopY() -> CGFloat {
        let safeBottom = view?.safeAreaInsets.bottom ?? 0
        let buttonSize = controlButtonSize()
        let gap: CGFloat = 10
        let centerY = safeBottom + buttonSize * 1.5 + gap + 14

        return centerY + buttonSize + gap + buttonSize / 2
    }

    private func renderGameBoard() {
        boardContainer.children
            .filter { $0.name == "snakeSegment" || $0.name == "food" }
            .forEach { $0.removeFromParent() }

        if let food {
            let foodNode = SKShapeNode(ellipseIn: cellRect(for: food).insetBy(dx: cellSize * 0.16, dy: cellSize * 0.16))
            foodNode.name = "food"
            foodNode.fillColor = SKColor(red: 0.95, green: 0.12, blue: 0.11, alpha: 1)
            foodNode.strokeColor = .clear
            foodNode.zPosition = 2
            boardContainer.addChild(foodNode)
        }

        for (index, segment) in snake.enumerated() {
            let segmentNode = SKShapeNode(rect: cellRect(for: segment).insetBy(dx: 1, dy: 1), cornerRadius: 0)
            segmentNode.name = "snakeSegment"
            segmentNode.fillColor = index == 0
                ? SKColor(red: 0.55, green: 1.0, blue: 0.35, alpha: 1)
                : SKColor(red: 0.22, green: 0.82, blue: 0.22, alpha: 1)
            segmentNode.strokeColor = SKColor(red: 0.04, green: 0.18, blue: 0.05, alpha: 1)
            segmentNode.lineWidth = 1
            segmentNode.zPosition = 3
            boardContainer.addChild(segmentNode)
        }
    }

    private func cellRect(for point: GridPoint) -> CGRect {
        CGRect(
            x: boardOrigin.x + CGFloat(point.x) * cellSize,
            y: boardOrigin.y + CGFloat(point.y) * cellSize,
            width: cellSize,
            height: cellSize
        )
    }

    private func handleButtonTap(at location: CGPoint) -> Bool {
        for node in nodes(at: location) {
            guard let name = interactionName(for: node) else { continue }

            switch name {
            case NodeName.playButton where gameState == .mainMenu:
                mainMenuContainer.removeAllChildren()
                startGame()
                return true
            case NodeName.settingsButton where gameState == .mainMenu:
                showSettings(from: .mainMenu)
                return true
            case NodeName.settingsFromPauseButton where gameState == .paused:
                showSettings(from: .paused)
                return true
            case NodeName.settingsBackButton where gameState == .settings:
                closeSettings()
                return true
            case NodeName.soundToggleButton where gameState == .settings:
                toggleSound()
                return true
            case NodeName.volumeMinusButton where gameState == .settings:
                changeVolume(by: -1)
                return true
            case NodeName.volumePlusButton where gameState == .settings:
                changeVolume(by: 1)
                return true
            case NodeName.languageToggleButton where gameState == .settings:
                toggleLanguage()
                return true
            case NodeName.pauseButton where gameState == .playing:
                pauseGame()
                return true
            case NodeName.resumeButton where gameState == .paused:
                resumeGame()
                return true
            case NodeName.restartButton where gameState == .paused || gameState == .gameOver:
                restartGame()
                return true
            case NodeName.mainMenuButton where gameState == .paused || gameState == .gameOver:
                returnToMainMenu()
                return true
            case NodeName.upButton where gameState == .playing:
                requestDirection(.up)
                return true
            case NodeName.downButton where gameState == .playing:
                requestDirection(.down)
                return true
            case NodeName.leftButton where gameState == .playing:
                requestDirection(.left)
                return true
            case NodeName.rightButton where gameState == .playing:
                requestDirection(.right)
                return true
            default:
                continue
            }
        }

        return false
    }

    private func handleSwipe(from start: CGPoint, to end: CGPoint) {
        let delta = CGPoint(x: end.x - start.x, y: end.y - start.y)
        guard max(abs(delta.x), abs(delta.y)) > 28 else { return }

        if abs(delta.x) > abs(delta.y) {
            requestDirection(delta.x > 0 ? .right : .left)
        } else {
            requestDirection(delta.y > 0 ? .up : .down)
        }
    }

    private func requestDirection(_ newDirection: Direction) {
        guard gameState == .playing, isGameRunning else { return }
        requestedDirection = newDirection
    }

    private func returnToMainMenu() {
        gameState = .mainMenu
        previousState = .mainMenu
        isGameRunning = false
        isGamePaused = false
        didShowGameOver = false
        requestedDirection = nil
        touchStartPoint = nil

        if score > bestScore {
            bestScore = score
            UserDefaults.standard.set(bestScore, forKey: bestScoreKey)
        } else {
            bestScore = UserDefaults.standard.integer(forKey: bestScoreKey)
        }

        pauseOverlay.removeAllChildren()
        settingsOverlay.removeAllChildren()
        gameOverOverlay.removeAllChildren()
        mainMenuContainer.removeAllChildren()
        AudioManager.shared.stopBackgroundMusic()
        updateVisibleUIForState()
        showMainMenu()
    }

    private func showMainMenu() {
        guard size.width > 80, size.height > 120 else { return }

        gameState = .mainMenu
        previousState = .mainMenu
        isGameRunning = false
        isGamePaused = false
        didShowGameOver = false
        snake.removeAll()
        food = nil
        boardContainer.children
            .filter { $0.name == "snakeSegment" || $0.name == "food" }
            .forEach { $0.removeFromParent() }
        pauseOverlay.removeAllChildren()
        settingsOverlay.removeAllChildren()
        gameOverOverlay.removeAllChildren()
        mainMenuContainer.removeAllChildren()
        updateScoreLabel()
        AudioManager.shared.stopBackgroundMusic()
        updateVisibleUIForState()

        let horizontalPadding: CGFloat = 32
        let menuWidth = size.width - horizontalPadding * 2
        let menuHeight = min(360, max(320, size.height * 0.42))
        let menuCenterY = mainMenuCenterY(menuHeight: menuHeight)

        let menuContainer = SKShapeNode(rectOf: CGSize(width: menuWidth, height: menuHeight), cornerRadius: 8)
        menuContainer.position = CGPoint(x: size.width / 2, y: menuCenterY)
        menuContainer.fillColor = SKColor(red: 0.02, green: 0.025, blue: 0.03, alpha: 0.96)
        menuContainer.strokeColor = SKColor(red: 0.28, green: 0.95, blue: 0.36, alpha: 1)
        menuContainer.lineWidth = 2
        mainMenuContainer.addChild(menuContainer)

        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = localized("title")
        title.fontSize = min(38, menuWidth * 0.11)
        title.fontColor = SKColor(red: 0.42, green: 1.0, blue: 0.28, alpha: 1)
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: menuHeight * 0.28)
        fitLabel(title, maxWidth: menuWidth - 28, minFontSize: 22)
        menuContainer.addChild(title)

        let bestLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        bestLabel.text = "\(localized("best")) \(bestScore)"
        bestLabel.fontSize = 22
        bestLabel.fontColor = .white
        bestLabel.horizontalAlignmentMode = .center
        bestLabel.verticalAlignmentMode = .center
        bestLabel.position = CGPoint(x: 0, y: menuHeight * 0.12)
        fitLabel(bestLabel, maxWidth: menuWidth - 28, minFontSize: 14)
        menuContainer.addChild(bestLabel)

        addMenuButton(
            title: localized("play"),
            name: NodeName.playButton,
            position: CGPoint(x: 0, y: -menuHeight * 0.09),
            size: CGSize(width: 190, height: 58),
            parent: menuContainer
        )
        addMenuButton(
            title: localized("settings"),
            name: NodeName.settingsButton,
            position: CGPoint(x: 0, y: -menuHeight * 0.29),
            size: CGSize(width: 190, height: 50),
            parent: menuContainer
        )
        print("Main menu shown: sceneSize=\(size), menuCenter=(\(size.width / 2), \(menuCenterY)), menuSize=(\(menuWidth), \(menuHeight)), menuChildren=\(mainMenuContainer.children.count)")
    }

    private func updateVisibleUIForState() {
        let settingsFromMainMenu = gameState == .settings && previousState == .mainMenu
        let showsGameUI = gameState == .playing
            || gameState == .paused
            || gameState == .gameOver
            || (gameState == .settings && previousState == .paused)

        mainMenuContainer.isHidden = gameState != .mainMenu
        boardContainer.isHidden = !showsGameUI
        topBarContainer.isHidden = !showsGameUI
        controlsContainer.isHidden = !showsGameUI || gameState == .settings
        pauseOverlay.isHidden = gameState != .paused
        gameOverOverlay.isHidden = gameState != .gameOver
        settingsOverlay.isHidden = gameState != .settings

        if settingsFromMainMenu {
            boardContainer.isHidden = true
            topBarContainer.isHidden = true
            controlsContainer.isHidden = true
        }

        pauseLabel.text = ""
    }

    private func interactionName(for node: SKNode) -> String? {
        node.name ?? node.parent?.name
    }

    private func mainMenuCenterY(menuHeight: CGFloat) -> CGFloat {
        let rawSafeTop = view?.safeAreaInsets.top ?? 0
        let rawSafeBottom = view?.safeAreaInsets.bottom ?? 0
        let safeTop = rawSafeTop < size.height * 0.25 ? rawSafeTop : 0
        let safeBottom = rawSafeBottom < size.height * 0.25 ? rawSafeBottom : 0

        let topLimit = size.height - safeTop - 24
        let bottomLimit = safeBottom + 24
        let minCenterY = menuHeight / 2 + 24
        let maxCenterY = size.height - menuHeight / 2 - 24

        let centeredY = (topLimit + bottomLimit) / 2
        let lowerBound = minCenterY
        let upperBound = max(lowerBound, maxCenterY)

        return min(max(centeredY, lowerBound), upperBound)
    }

    private func addMenuButton(title: String, name: String, position: CGPoint, size: CGSize, parent: SKNode) {
        let button = SKShapeNode(rectOf: size, cornerRadius: 8)
        button.name = name
        button.position = position
        button.fillColor = SKColor(red: 0.18, green: 0.72, blue: 0.2, alpha: 1)
        button.strokeColor = .white
        button.lineWidth = 1.5
        parent.addChild(button)

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.name = name
        label.text = title
        label.fontSize = 22
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        fitLabel(label, maxWidth: size.width - 16, minFontSize: 14)
        button.addChild(label)
    }

    private func showGameOverOverlay() {
        pauseOverlay.removeAllChildren()
        settingsOverlay.removeAllChildren()
        gameOverOverlay.removeAllChildren()
        updateVisibleUIForState()

        let panelSize = CGSize(width: min(size.width - 44, 300), height: 292)
        let panel = SKShapeNode(rectOf: panelSize, cornerRadius: 8)
        panel.position = CGPoint(x: size.width / 2, y: boardOrigin.y + boardSize.height / 2)
        panel.fillColor = SKColor(red: 0.02, green: 0.025, blue: 0.03, alpha: 0.94)
        panel.strokeColor = SKColor(red: 0.95, green: 0.12, blue: 0.11, alpha: 1)
        panel.lineWidth = 2
        panel.zPosition = 20
        gameOverOverlay.addChild(panel)

        addOverlayLabel(localized("gameOver"), fontSize: 28, y: 98, parent: panel)
        addOverlayLabel("\(localized("score")) \(score)", fontSize: 20, y: 50, parent: panel)
        addOverlayLabel("\(localized("best")) \(bestScore)", fontSize: 20, y: 16, parent: panel)

        let restartButton = SKShapeNode(rectOf: CGSize(width: 170, height: 48), cornerRadius: 8)
        restartButton.name = NodeName.restartButton
        restartButton.position = CGPoint(x: 0, y: -44)
        restartButton.fillColor = SKColor(red: 0.18, green: 0.72, blue: 0.2, alpha: 1)
        restartButton.strokeColor = .white
        restartButton.lineWidth = 1.5
        panel.addChild(restartButton)

        let restartLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        restartLabel.name = NodeName.restartButton
        restartLabel.text = localized("restart")
        restartLabel.fontSize = 20
        restartLabel.fontColor = .white
        restartLabel.verticalAlignmentMode = .center
        restartLabel.horizontalAlignmentMode = .center
        fitLabel(restartLabel, maxWidth: 154, minFontSize: 14)
        restartButton.addChild(restartLabel)

        addMenuButton(
            title: localized("mainMenu"),
            name: NodeName.mainMenuButton,
            position: CGPoint(x: 0, y: -108),
            size: CGSize(width: 170, height: 48),
            parent: panel
        )
    }

    private func showPauseOverlay() {
        pauseOverlay.removeAllChildren()
        settingsOverlay.removeAllChildren()
        gameOverOverlay.removeAllChildren()
        updateVisibleUIForState()

        let panelSize = CGSize(width: min(size.width - 44, 300), height: 334)
        let panel = SKShapeNode(rectOf: panelSize, cornerRadius: 8)
        panel.position = CGPoint(x: size.width / 2, y: boardOrigin.y + boardSize.height / 2)
        panel.fillColor = SKColor(red: 0.02, green: 0.025, blue: 0.03, alpha: 0.94)
        panel.strokeColor = SKColor(red: 0.28, green: 0.95, blue: 0.36, alpha: 1)
        panel.lineWidth = 2
        panel.zPosition = 30
        pauseOverlay.addChild(panel)

        addOverlayLabel(localized("paused"), fontSize: 30, y: 122, parent: panel)
        addMenuButton(
            title: localized("continue"),
            name: NodeName.resumeButton,
            position: CGPoint(x: 0, y: 62),
            size: CGSize(width: 190, height: 48),
            parent: panel
        )
        addMenuButton(
            title: localized("settings"),
            name: NodeName.settingsFromPauseButton,
            position: CGPoint(x: 0, y: 0),
            size: CGSize(width: 190, height: 48),
            parent: panel
        )
        addMenuButton(
            title: localized("restart"),
            name: NodeName.restartButton,
            position: CGPoint(x: 0, y: -62),
            size: CGSize(width: 190, height: 48),
            parent: panel
        )
        addMenuButton(
            title: localized("mainMenu"),
            name: NodeName.mainMenuButton,
            position: CGPoint(x: 0, y: -124),
            size: CGSize(width: 190, height: 48),
            parent: panel
        )
    }

    private func showSettings(from state: GameState) {
        previousState = state
        gameState = .settings
        isGamePaused = state == .paused
        mainMenuContainer.isHidden = true
        showSettingsOverlay()
    }

    private func closeSettings() {
        settingsOverlay.removeAllChildren()

        switch previousState {
        case .mainMenu:
            showMainMenu()
        case .paused:
            gameState = .paused
            isGamePaused = true
            showPauseOverlay()
        default:
            gameState = .mainMenu
            showMainMenu()
        }
    }

    private func toggleSound() {
        AudioManager.shared.setSoundEnabled(!AudioManager.shared.soundEnabled)
        if AudioManager.shared.soundEnabled, previousState != .mainMenu {
            AudioManager.shared.playBackgroundMusic()
        }
        updateSettingsLabels()
    }

    private func changeVolume(by delta: Int) {
        AudioManager.shared.setVolumeLevel(AudioManager.shared.volumeLevel + delta)
        updateSettingsLabels()
    }

    private func toggleLanguage() {
        currentLanguage = currentLanguage == .english ? .russian : .english
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: appLanguageKey)
        updateLocalizedTexts()
    }

    private func loadLanguage() {
        let savedLanguage = UserDefaults.standard.string(forKey: appLanguageKey)
        currentLanguage = AppLanguage(rawValue: savedLanguage ?? "") ?? .english
    }

    private func localized(_ key: String) -> String {
        localization[currentLanguage]?[key] ?? localization[.english]?[key] ?? key
    }

    private func updateLocalizedTexts() {
        updateScoreLabel()

        switch gameState {
        case .mainMenu:
            showMainMenu()
        case .paused:
            showPauseOverlay()
        case .settings:
            showSettingsOverlay()
        case .gameOver:
            showGameOverOverlay()
        case .playing:
            updateVisibleUIForState()
        }
    }

    private func showSettingsOverlay() {
        settingsOverlay.removeAllChildren()
        pauseOverlay.removeAllChildren()
        gameOverOverlay.removeAllChildren()
        updateVisibleUIForState()

        let panelSize = CGSize(width: min(size.width - 36, 340), height: 430)
        let panel = SKShapeNode(rectOf: panelSize, cornerRadius: 8)
        panel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        panel.fillColor = SKColor(red: 0.02, green: 0.025, blue: 0.03, alpha: 0.96)
        panel.strokeColor = SKColor(red: 0.28, green: 0.95, blue: 0.36, alpha: 1)
        panel.lineWidth = 2
        panel.zPosition = 40
        settingsOverlay.addChild(panel)

        addOverlayLabel(localized("settings").uppercased(), fontSize: 30, y: 166, parent: panel)

        let soundButton = SKShapeNode(rectOf: CGSize(width: 250, height: 48), cornerRadius: 8)
        soundButton.name = NodeName.soundToggleButton
        soundButton.position = CGPoint(x: 0, y: 104)
        soundButton.fillColor = SKColor(red: 0.18, green: 0.72, blue: 0.2, alpha: 1)
        soundButton.strokeColor = .white
        soundButton.lineWidth = 1.5
        panel.addChild(soundButton)

        soundToggleLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        soundToggleLabel.name = NodeName.soundToggleButton
        soundToggleLabel.fontSize = 20
        soundToggleLabel.fontColor = .white
        soundToggleLabel.verticalAlignmentMode = .center
        soundToggleLabel.horizontalAlignmentMode = .center
        soundButton.addChild(soundToggleLabel)

        volumeLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        volumeLabel.fontSize = 20
        volumeLabel.fontColor = .white
        volumeLabel.verticalAlignmentMode = .center
        volumeLabel.horizontalAlignmentMode = .center
        volumeLabel.position = CGPoint(x: 0, y: 44)
        panel.addChild(volumeLabel)

        addMenuButton(
            title: "-",
            name: NodeName.volumeMinusButton,
            position: CGPoint(x: -58, y: -8),
            size: CGSize(width: 52, height: 48),
            parent: panel
        )
        addMenuButton(
            title: "+",
            name: NodeName.volumePlusButton,
            position: CGPoint(x: 58, y: -8),
            size: CGSize(width: 52, height: 48),
            parent: panel
        )

        let languageButton = SKShapeNode(rectOf: CGSize(width: 250, height: 48), cornerRadius: 8)
        languageButton.name = NodeName.languageToggleButton
        languageButton.position = CGPoint(x: 0, y: -72)
        languageButton.fillColor = SKColor(red: 0.18, green: 0.72, blue: 0.2, alpha: 1)
        languageButton.strokeColor = .white
        languageButton.lineWidth = 1.5
        panel.addChild(languageButton)

        languageToggleLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        languageToggleLabel.name = NodeName.languageToggleButton
        languageToggleLabel.fontSize = 20
        languageToggleLabel.fontColor = .white
        languageToggleLabel.verticalAlignmentMode = .center
        languageToggleLabel.horizontalAlignmentMode = .center
        languageButton.addChild(languageToggleLabel)

        addMenuButton(
            title: localized("back"),
            name: NodeName.settingsBackButton,
            position: CGPoint(x: 0, y: -140),
            size: CGSize(width: 190, height: 48),
            parent: panel
        )

        updateSettingsLabels()
    }

    private func updateSettingsLabels() {
        soundToggleLabel.fontSize = 20
        volumeLabel.fontSize = 20
        languageToggleLabel.fontSize = 20
        soundToggleLabel.text = AudioManager.shared.soundEnabled ? localized("soundOn") : localized("soundOff")
        volumeLabel.text = "\(localized("volume")): \(AudioManager.shared.volumeLevel)/10"
        languageToggleLabel.text = localized("language")
        fitLabel(soundToggleLabel, maxWidth: 230, minFontSize: 14)
        fitLabel(volumeLabel, maxWidth: 300, minFontSize: 14)
        fitLabel(languageToggleLabel, maxWidth: 230, minFontSize: 14)
    }

    private func addOverlayLabel(_ text: String, fontSize: CGFloat, y: CGFloat, parent: SKNode) {
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: y)
        let maxWidth = (parent as? SKShapeNode)?.frame.width ?? size.width - 44
        fitLabel(label, maxWidth: maxWidth - 24, minFontSize: 14)
        parent.addChild(label)
    }

    private func fitLabel(_ label: SKLabelNode, maxWidth: CGFloat, minFontSize: CGFloat) {
        while label.frame.width > maxWidth && label.fontSize > minFontSize {
            label.fontSize -= 1
        }
    }
}
