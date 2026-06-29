const columns = 20;
const rows = 24;
const moveInterval = 140;
const bestScoreKey = "RetroSnakeBestScore";
const languageKey = "AppLanguage";
const soundEnabledKey = "SoundEnabled";
const volumeLevelKey = "VolumeLevel";

const dictionary = {
  en: {
    title: "RETRO SNAKE",
    best: "Best",
    play: "Play",
    settings: "Settings",
    soundOn: "Sound: ON",
    soundOff: "Sound: OFF",
    volume: "Volume",
    language: "Language: EN",
    back: "Back",
    paused: "PAUSED",
    continue: "Continue",
    restart: "Restart",
    mainMenu: "Main Menu",
    gameOver: "GAME OVER",
    score: "Score",
  },
  ru: {
    title: "РЕТРО ЗМЕЙКА",
    best: "Рекорд",
    play: "Играть",
    settings: "Настройки",
    soundOn: "Звук: ВКЛ",
    soundOff: "Звук: ВЫКЛ",
    volume: "Громкость",
    language: "Язык: RU",
    back: "Назад",
    paused: "ПАУЗА",
    continue: "Продолжить",
    restart: "Заново",
    mainMenu: "Главное меню",
    gameOver: "ИГРА ОКОНЧЕНА",
    score: "Счет",
  },
};

const vectors = {
  up: { x: 0, y: -1 },
  down: { x: 0, y: 1 },
  left: { x: -1, y: 0 },
  right: { x: 1, y: 0 },
};

const opposites = {
  up: "down",
  down: "up",
  left: "right",
  right: "left",
};

const elements = {
  canvas: document.querySelector("#board"),
  score: document.querySelector("#score"),
  bestScore: document.querySelector("#bestScore"),
  finalScore: document.querySelector("#finalScore"),
  finalBestScore: document.querySelector("#finalBestScore"),
  mainMenu: document.querySelector("#mainMenu"),
  pauseMenu: document.querySelector("#pauseMenu"),
  gameOverMenu: document.querySelector("#gameOverMenu"),
  settingsMenu: document.querySelector("#settingsMenu"),
  soundToggle: document.querySelector("#soundToggle"),
  languageToggle: document.querySelector("#languageToggle"),
  volumeLabel: document.querySelector("#volumeLabel"),
};

const ctx = elements.canvas.getContext("2d");

const audioSources = {
  background: "/public/sounds/background.mp3",
  eat: "/public/sounds/eat.wav",
  gameover: "/public/sounds/gameover.wav",
};

const audio = {
  context: null,
  buffers: {},
  loading: {},
  backgroundSource: null,
  backgroundGain: null,
  effectGain: null,
  fallback: {},
  unlocked: false,
};

const state = {
  screen: "mainMenu",
  previousScreen: "mainMenu",
  snake: [],
  food: null,
  direction: "right",
  requestedDirection: null,
  score: 0,
  bestScore: readNumber(bestScoreKey, 0),
  language: localStorage.getItem(languageKey) === "ru" ? "ru" : "en",
  soundEnabled: readBoolean(soundEnabledKey, true),
  volumeLevel: clamp(readNumber(volumeLevelKey, 5), 1, 10),
  lastMoveTime: 0,
  gameRunning: false,
  touchStart: null,
};

function readNumber(key, fallback) {
  const value = Number.parseInt(localStorage.getItem(key) ?? "", 10);
  return Number.isFinite(value) ? value : fallback;
}

function readBoolean(key, fallback) {
  const value = localStorage.getItem(key);
  if (value === null) return fallback;
  return value === "true";
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function t(key) {
  return dictionary[state.language][key] ?? dictionary.en[key] ?? key;
}

function resizeCanvas() {
  const rect = elements.canvas.getBoundingClientRect();
  const pixelRatio = window.devicePixelRatio || 1;
  elements.canvas.width = Math.round(rect.width * pixelRatio);
  elements.canvas.height = Math.round(rect.width * 1.2 * pixelRatio);
  ctx.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
  draw();
}

function cellSize() {
  return elements.canvas.getBoundingClientRect().width / columns;
}

function draw() {
  const size = cellSize();
  const width = size * columns;
  const height = size * rows;

  ctx.clearRect(0, 0, width, height);
  ctx.fillStyle = "#04100a";
  ctx.fillRect(0, 0, width, height);

  ctx.strokeStyle = "rgba(72, 242, 92, 0.08)";
  ctx.lineWidth = 1;
  for (let x = 1; x < columns; x += 1) {
    ctx.beginPath();
    ctx.moveTo(x * size, 0);
    ctx.lineTo(x * size, height);
    ctx.stroke();
  }
  for (let y = 1; y < rows; y += 1) {
    ctx.beginPath();
    ctx.moveTo(0, y * size);
    ctx.lineTo(width, y * size);
    ctx.stroke();
  }

  if (state.food) {
    ctx.fillStyle = "#f22e28";
    ctx.beginPath();
    ctx.arc(
      state.food.x * size + size / 2,
      state.food.y * size + size / 2,
      size * 0.34,
      0,
      Math.PI * 2
    );
    ctx.fill();
  }

  state.snake.forEach((segment, index) => {
    ctx.fillStyle = index === 0 ? "#8cff59" : "#38d138";
    ctx.strokeStyle = "#0a2e0d";
    ctx.lineWidth = 1;
    ctx.fillRect(segment.x * size + 1, segment.y * size + 1, size - 2, size - 2);
    ctx.strokeRect(segment.x * size + 1, segment.y * size + 1, size - 2, size - 2);
  });
}

function startGame() {
  const startX = Math.floor(columns / 2);
  const startY = Math.floor(rows / 2);

  state.screen = "playing";
  state.previousScreen = "playing";
  state.snake = [
    { x: startX, y: startY },
    { x: startX - 1, y: startY },
    { x: startX - 2, y: startY },
  ];
  state.food = null;
  state.direction = "right";
  state.requestedDirection = null;
  state.score = 0;
  state.lastMoveTime = 0;
  state.gameRunning = true;

  spawnFood();
  playBackground();
  updateUI();
  draw();
}

function restartGame() {
  startGame();
}

function moveSnake() {
  if (state.screen !== "playing" || !state.gameRunning) return;

  if (state.requestedDirection && opposites[state.requestedDirection] !== state.direction) {
    state.direction = state.requestedDirection;
  }
  state.requestedDirection = null;

  const head = state.snake[0];
  const vector = vectors[state.direction];
  const nextHead = { x: head.x + vector.x, y: head.y + vector.y };

  if (nextHead.x < 0 || nextHead.x >= columns || nextHead.y < 0 || nextHead.y >= rows) {
    endGame();
    return;
  }

  const didEat = state.food && sameCell(nextHead, state.food);
  const body = didEat ? state.snake : state.snake.slice(0, -1);
  if (body.some((cell) => sameCell(cell, nextHead))) {
    endGame();
    return;
  }

  state.snake.unshift(nextHead);

  if (didEat) {
    state.score += 1;
    playEffect("eat");
    spawnFood();
  } else {
    state.snake.pop();
  }

  updateScore();
  draw();
}

function sameCell(a, b) {
  return a.x === b.x && a.y === b.y;
}

function spawnFood() {
  const occupied = new Set(state.snake.map((cell) => `${cell.x}:${cell.y}`));
  const freeCells = [];

  for (let y = 0; y < rows; y += 1) {
    for (let x = 0; x < columns; x += 1) {
      if (!occupied.has(`${x}:${y}`)) {
        freeCells.push({ x, y });
      }
    }
  }

  state.food = freeCells[Math.floor(Math.random() * freeCells.length)] ?? null;
}

function endGame() {
  state.screen = "gameOver";
  state.gameRunning = false;
  playEffect("gameover");

  if (state.score > state.bestScore) {
    state.bestScore = state.score;
    localStorage.setItem(bestScoreKey, String(state.bestScore));
  }

  updateUI();
}

function pauseGame() {
  if (state.screen !== "playing" || !state.gameRunning) return;
  state.screen = "paused";
  updateUI();
}

function resumeGame() {
  if (state.screen !== "paused") return;
  state.screen = "playing";
  state.lastMoveTime = 0;
  playBackground();
  updateUI();
}

function returnToMainMenu() {
  if (state.score > state.bestScore) {
    state.bestScore = state.score;
    localStorage.setItem(bestScoreKey, String(state.bestScore));
  }

  state.screen = "mainMenu";
  state.previousScreen = "mainMenu";
  state.gameRunning = false;
  state.snake = [];
  state.food = null;
  state.score = 0;
  state.requestedDirection = null;
  pauseBackground();
  updateUI();
  draw();
}

function openSettings(fromScreen) {
  state.previousScreen = fromScreen;
  state.screen = "settings";
  updateUI();
}

function closeSettings() {
  if (state.previousScreen === "paused") {
    state.screen = "paused";
  } else {
    state.screen = "mainMenu";
  }
  updateUI();
}

function setDirection(direction) {
  if (state.screen !== "playing" || !state.gameRunning) return;
  state.requestedDirection = direction;
}

function updateUI() {
  document.documentElement.lang = state.language;
  document.querySelectorAll("[data-i18n]").forEach((node) => {
    node.textContent = t(node.dataset.i18n);
  });

  elements.bestScore.textContent = String(state.bestScore);
  elements.finalScore.textContent = String(state.score);
  elements.finalBestScore.textContent = String(state.bestScore);
  updateScore();
  updateSettingsLabels();

  elements.mainMenu.hidden = state.screen !== "mainMenu";
  elements.pauseMenu.hidden = state.screen !== "paused";
  elements.gameOverMenu.hidden = state.screen !== "gameOver";
  elements.settingsMenu.hidden = state.screen !== "settings";
  document.body.dataset.screen = state.screen;
}

function updateScore() {
  elements.score.textContent = String(state.score);
}

function updateSettingsLabels() {
  elements.soundToggle.textContent = state.soundEnabled ? t("soundOn") : t("soundOff");
  elements.volumeLabel.textContent = `${t("volume")}: ${state.volumeLevel}/10`;
  elements.languageToggle.textContent = t("language");
}

function toggleSound() {
  state.soundEnabled = !state.soundEnabled;
  localStorage.setItem(soundEnabledKey, String(state.soundEnabled));
  setAudioVolumes();

  if (state.soundEnabled && state.previousScreen === "paused" && state.gameRunning) {
    playBackground();
  } else if (!state.soundEnabled) {
    pauseBackground();
  }

  updateSettingsLabels();
}

function changeVolume(delta) {
  state.volumeLevel = clamp(state.volumeLevel + delta, 1, 10);
  localStorage.setItem(volumeLevelKey, String(state.volumeLevel));
  setAudioVolumes();
  if (state.soundEnabled && state.screen === "settings") {
    playEffect("eat");
  }
  updateSettingsLabels();
}

function toggleLanguage() {
  state.language = state.language === "en" ? "ru" : "en";
  localStorage.setItem(languageKey, state.language);
  updateUI();
}

function setAudioVolumes() {
  const normalizedVolume = state.volumeLevel / 10;
  if (audio.backgroundGain) audio.backgroundGain.gain.value = normalizedVolume * 0.35;
  if (audio.effectGain) audio.effectGain.gain.value = normalizedVolume;

  Object.values(audio.fallback).forEach((player) => {
    player.volume = normalizedVolume;
  });
}

function playBackground() {
  if (!state.soundEnabled) return;
  playBackgroundWithWebAudio().catch(() => playBackgroundFallback());
}

function pauseBackground() {
  if (audio.backgroundSource) {
    audio.backgroundSource.stop();
    audio.backgroundSource.disconnect();
    audio.backgroundSource = null;
  }

  if (audio.fallback.background) {
    audio.fallback.background.pause();
  }
}

function playEffect(playerName) {
  if (!state.soundEnabled) return;
  playEffectWithWebAudio(playerName).catch(() => playEffectFallback(playerName));
}

function ensureAudioContext() {
  if (!audio.context) {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (!AudioContextClass) return null;

    audio.context = new AudioContextClass();
    audio.backgroundGain = audio.context.createGain();
    audio.effectGain = audio.context.createGain();
    audio.backgroundGain.connect(audio.context.destination);
    audio.effectGain.connect(audio.context.destination);
    setAudioVolumes();
  }

  if (audio.context.state === "suspended") {
    audio.context.resume().catch(() => {});
  }

  return audio.context;
}

function unlockAudio() {
  const context = ensureAudioContext();
  if (!context || audio.unlocked) return;

  const source = context.createBufferSource();
  source.buffer = context.createBuffer(1, 1, 22050);
  source.connect(context.destination);
  source.start(0);
  audio.unlocked = true;
  warmAudioBuffers();
}

function warmAudioBuffers() {
  Object.keys(audioSources).forEach((name) => {
    loadAudioBuffer(name).catch(() => {});
  });
}

function loadAudioBuffer(name) {
  const context = ensureAudioContext();
  if (!context) return Promise.reject(new Error("Web Audio is not available"));
  if (audio.buffers[name]) return Promise.resolve(audio.buffers[name]);
  if (audio.loading[name]) return audio.loading[name];

  audio.loading[name] = fetch(audioSources[name])
    .then((response) => {
      if (!response.ok) throw new Error(`Audio request failed: ${name}`);
      return response.arrayBuffer();
    })
    .then((arrayBuffer) => context.decodeAudioData(arrayBuffer))
    .then((buffer) => {
      audio.buffers[name] = buffer;
      return buffer;
    })
    .finally(() => {
      audio.loading[name] = null;
    });

  return audio.loading[name];
}

async function playBackgroundWithWebAudio() {
  const context = ensureAudioContext();
  if (!context) throw new Error("Web Audio is not available");
  if (audio.backgroundSource) return;

  const buffer = await loadAudioBuffer("background");
  if (!state.soundEnabled || !state.gameRunning || state.screen === "mainMenu") return;

  const source = context.createBufferSource();
  source.buffer = buffer;
  source.loop = true;
  source.connect(audio.backgroundGain);
  source.start(0);
  audio.backgroundSource = source;
}

async function playEffectWithWebAudio(name) {
  const context = ensureAudioContext();
  if (!context) throw new Error("Web Audio is not available");

  const buffer = await loadAudioBuffer(name);
  if (!state.soundEnabled) return;

  const source = context.createBufferSource();
  source.buffer = buffer;
  source.connect(audio.effectGain);
  source.start(0);
}

function playBackgroundFallback() {
  const background = getFallbackAudio("background");
  background.loop = true;
  setAudioVolumes();
  background.play().catch(() => {});
}

function playEffectFallback(name) {
  const player = getFallbackAudio(name);
  setAudioVolumes();
  player.currentTime = 0;
  player.play().catch(() => {});
}

function getFallbackAudio(name) {
  if (!audio.fallback[name]) {
    audio.fallback[name] = new Audio(audioSources[name]);
    audio.fallback[name].preload = "auto";
  }

  return audio.fallback[name];
}

function loop(timestamp) {
  if (state.screen === "playing" && state.gameRunning) {
    if (state.lastMoveTime === 0) {
      state.lastMoveTime = timestamp;
    }

    if (timestamp - state.lastMoveTime >= moveInterval) {
      state.lastMoveTime = timestamp;
      moveSnake();
    }
  }

  requestAnimationFrame(loop);
}

function handleAction(action) {
  switch (action) {
    case "play":
      startGame();
      break;
    case "pause":
      pauseGame();
      break;
    case "resume":
      resumeGame();
      break;
    case "restart":
      restartGame();
      break;
    case "main-menu":
      returnToMainMenu();
      break;
    case "settings-main":
      openSettings("mainMenu");
      break;
    case "settings-pause":
      openSettings("paused");
      break;
    case "settings-back":
      closeSettings();
      break;
    case "toggle-sound":
      toggleSound();
      break;
    case "volume-down":
      changeVolume(-1);
      break;
    case "volume-up":
      changeVolume(1);
      break;
    case "toggle-language":
      toggleLanguage();
      break;
  }
}

document.addEventListener("click", (event) => {
  unlockAudio();

  const actionButton = event.target.closest("[data-action]");
  if (actionButton) {
    handleAction(actionButton.dataset.action);
    return;
  }

  const directionButton = event.target.closest("[data-direction]");
  if (directionButton) {
    setDirection(directionButton.dataset.direction);
  }
});

document.addEventListener("keydown", (event) => {
  unlockAudio();

  const keys = {
    ArrowUp: "up",
    KeyW: "up",
    ArrowDown: "down",
    KeyS: "down",
    ArrowLeft: "left",
    KeyA: "left",
    ArrowRight: "right",
    KeyD: "right",
  };

  if (keys[event.code]) {
    event.preventDefault();
    setDirection(keys[event.code]);
  } else if (event.code === "Space") {
    event.preventDefault();
    state.screen === "playing" ? pauseGame() : resumeGame();
  }
});

document.addEventListener(
  "touchstart",
  (event) => {
    unlockAudio();

    if (state.screen !== "playing" || event.touches.length === 0) return;
    const touch = event.touches[0];
    state.touchStart = { x: touch.clientX, y: touch.clientY };
  },
  { passive: false }
);

document.addEventListener(
  "touchend",
  (event) => {
    if (!state.touchStart || event.changedTouches.length === 0) return;
    const touch = event.changedTouches[0];
    const dx = touch.clientX - state.touchStart.x;
    const dy = touch.clientY - state.touchStart.y;
    state.touchStart = null;

    if (Math.max(Math.abs(dx), Math.abs(dy)) <= 28) return;
    if (Math.abs(dx) > Math.abs(dy)) {
      setDirection(dx > 0 ? "right" : "left");
    } else {
      setDirection(dy > 0 ? "down" : "up");
    }
  },
  { passive: false }
);

window.addEventListener("resize", resizeCanvas);

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker.js").catch(() => {});
  });
}

setAudioVolumes();
updateUI();
resizeCanvas();
requestAnimationFrame(loop);
