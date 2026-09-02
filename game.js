const COLORS = {
  coral: { label: "珊瑚红", hex: "#e86b5b", dark: "#bd4c42", pale: "#fde9e3", border: "#efb5aa", ring: "#f7d6ce" },
  sun: { label: "向日黄", hex: "#e6b93f", dark: "#a8781d", pale: "#fff5d8", border: "#ecd48d", ring: "#faebba" },
  leaf: { label: "叶绿色", hex: "#5b9c72", dark: "#377453", pale: "#e7f3e9", border: "#b7d7c0", ring: "#d4ead8" },
  lake: { label: "湖蓝色", hex: "#4d96a3", dark: "#286b77", pale: "#e4f1f2", border: "#b5d6d9", ring: "#d1e7e8" }
};

const COLOR_KEYS = Object.keys(COLORS);
const MAX_QUEUE = 4;
const MAX_RECYCLE = 5;
const STATION_DISTANCES = [0.125, 0.375, 0.625, 0.875];
const BELT_END = 1.02;

const patternRows = [
  "....c.....",
  "...ccc....",
  "..cyyyy c..".replaceAll(" ", ""),
  ".cyybyyy c.".replaceAll(" ", ""),
  ".cyyyyyy c.".replaceAll(" ", ""),
  "..cyyyy c..".replaceAll(" ", ""),
  "...ccc....",
  "....ggg...",
  "....g.....",
  ".........."
];

const CHAR_TO_COLOR = { c: "coral", y: "sun", g: "leaf", b: "lake", l: "lake" };
const pattern = patternRows.flatMap((row, rowIndex) => [...row].map((char, column) => ({
  id: `${rowIndex}-${column}`,
  row: rowIndex,
  column,
  color: CHAR_TO_COLOR[char] || null
}))).filter((cell) => cell.color);
const CAPACITY_RANGES = {
  coral: [11, 15],
  sun: [14, 19],
  leaf: [3, 4],
  lake: [1, 1]
};
const WAVE_MACHINE_COUNT = 1;
const SAFE_LAYOUT_ATTEMPTS = 30;
const MACHINE_LAYOUT = [
  { left: "50%", top: "97%", shiftX: "-50%", shiftY: "-50%" },
  { left: "94%", top: "50%", shiftX: "-50%", shiftY: "-50%" },
  { left: "50%", top: "3%", shiftX: "-50%", shiftY: "-50%" },
  { left: "6%", top: "50%", shiftX: "-50%", shiftY: "-50%" }
];

const elements = {
  board: document.querySelector("#stitchBoard"),
  legend: document.querySelector("#colorLegend"),
  machineRow: document.querySelector("#machineRow"),
  materialsGrid: document.querySelector("#materialsGrid"),
  beltTrack: document.querySelector("#beltTrack"),
  conveyorBalls: document.querySelector("#conveyorBalls"),
  recycleBalls: document.querySelector("#recycleBalls"),
  recycleZone: document.querySelector("#recycleZone"),
  progressValue: document.querySelector("#progressValue"),
  recycleValue: document.querySelector("#recycleValue"),
  recycleCapacity: document.querySelector("#recycleCapacity"),
  queueCapacity: document.querySelector("#queueCapacity"),
  beltStatus: document.querySelector("#beltStatus"),
  toast: document.querySelector("#toast"),
  overlay: document.querySelector("#resultOverlay"),
  resultSeal: document.querySelector("#resultSeal"),
  resultKicker: document.querySelector("#resultKicker"),
  resultTitle: document.querySelector("#resultTitle"),
  resultCopy: document.querySelector("#resultCopy"),
  resultProgress: document.querySelector("#resultProgress")
};

let state;
let nextBallId = 1;
let animationFrame;
let lastFrameTime = 0;
let toastTimer;
let busyTimers = {};
let gameSession = 0;

function createRng(seed) {
  let value = seed >>> 0;
  return () => {
    value = (value * 1664525 + 1013904223) >>> 0;
    return value / 4294967296;
  };
}

function randomInt(rng, min, max) {
  return Math.floor(rng() * (max - min + 1)) + min;
}

function shuffle(items, rng) {
  const result = [...items];
  for (let index = result.length - 1; index > 0; index -= 1) {
    const swapIndex = Math.floor(rng() * (index + 1));
    [result[index], result[swapIndex]] = [result[swapIndex], result[index]];
  }
  return result;
}

function createLevel() {
  const levelSeed = Math.floor(Math.random() * 0xFFFFFFFF) >>> 0;
  const rng = createRng(levelSeed);
  const totalMachineCapacity = Object.fromEntries(COLOR_KEYS.map((color) => {
    const [min, max] = CAPACITY_RANGES[color];
    return [color, randomInt(rng, min, max)];
  }));
  const levelPattern = pattern.map((cell) => ({ ...cell, active: false }));
  COLOR_KEYS.forEach((color) => {
    const availableCells = shuffle(levelPattern.filter((cell) => cell.color === color), rng);
    availableCells.slice(0, totalMachineCapacity[color]).forEach((cell) => { cell.active = true; });
  });
  const activeCellsByColor = Object.fromEntries(COLOR_KEYS.map((color) => [
    color,
    shuffle(levelPattern.filter((cell) => cell.active && cell.color === color), rng)
  ]));
  const remaining = { ...totalMachineCapacity };
  const orderWaves = [];
  let waveId = 1;
  let isFirstWave = true;
  while (Object.values(remaining).some((count) => count > 0)) {
    const availableColors = COLOR_KEYS.filter((color) => remaining[color] > 0);
    const publishedColors = isFirstWave && remaining.coral > 0
      ? ["coral"]
      : shuffle(availableColors, rng).slice(0, Math.min(WAVE_MACHINE_COUNT, availableColors.length));
    const quotas = {};
    const cellIds = [];
    publishedColors.forEach((color) => {
      const quota = remaining[color] <= 6 ? remaining[color] : randomInt(rng, 2, 6);
      quotas[color] = quota;
      cellIds.push(...activeCellsByColor[color].splice(0, quota).map((cell) => cell.id));
      remaining[color] -= quota;
    });
    orderWaves.push({
      id: waveId++, 
      publishedColors,
      quotas,
      cellIds
    });
    isFirstWave = false;
  }
  return {
    levelSeed,
    rng,
    pattern: levelPattern,
    totalMachineCapacity,
    activeCellIds: levelPattern.filter((cell) => cell.active).map((cell) => cell.id),
    orderWaves
  };
}

function buildMaterialLanes(orderedBalls, rng) {
  const lanes = COLOR_KEYS.map((color, laneIndex) => ({ id: laneIndex + 1, balls: [] }));
  const laneOrder = shuffle([0, 1, 2, 3], rng);
  orderedBalls.forEach((ball, index) => {
    lanes[laneOrder[index % lanes.length]].balls.push(ball);
  });
  return lanes;
}

function hasSafeMaterialRoute(lanes, orderWaves) {
  const positions = lanes.map(() => 0);
  for (const wave of orderWaves) {
    for (const color of wave.publishedColors) {
      const quota = wave.quotas[color];
      for (let count = 0; count < quota; count += 1) {
        const laneIndex = lanes.findIndex((lane, index) => lane.balls[positions[index]]?.color === color);
        if (laneIndex < 0) return false;
        positions[laneIndex] += 1;
      }
    }
  }
  return true;
}

function createMaterialLanes(level) {
  const activeBalls = level.orderWaves.flatMap((wave, waveIndex) => wave.cellIds.map((cellId) => {
    const cell = level.pattern.find((item) => item.id === cellId);
    return { id: nextBallId++, color: cell.color, waveIndex };
  }));
  const spareBalls = level.pattern.filter((cell) => !cell.active).map((cell) => ({ id: nextBallId++, color: cell.color }));
  spareBalls.push({ id: nextBallId++, color: "coral" });
  const orderedBalls = [...activeBalls, ...shuffle(spareBalls, level.rng)];
  for (let attempt = 0; attempt < SAFE_LAYOUT_ATTEMPTS; attempt += 1) {
    const lanes = buildMaterialLanes(orderedBalls, level.rng);
    if (hasSafeMaterialRoute(lanes, level.orderWaves)) return lanes;
  }
  return buildMaterialLanes(orderedBalls, level.rng);
}

function createInitialState() {
  nextBallId = 1;
  const level = createLevel();
  return {
    pattern: level.pattern,
    activeCellIds: level.activeCellIds,
    levelSeed: level.levelSeed,
    totalMachineCapacity: level.totalMachineCapacity,
    orderWaves: level.orderWaves,
    currentWaveIndex: 0,
    stitchedCells: [],
    materialLanes: createMaterialLanes(level),
    conveyorQueue: [],
    recycleBin: [],
    machineCapacity: Object.fromEntries(COLOR_KEYS.map((color) => [color, level.orderWaves[0].quotas[color] || 0])),
    status: "playing",
    activeMachine: null
  };
}

function styleVars(color) {
  const info = COLORS[color];
  return `--lane-color:${info.hex};--lane-dark:${info.dark};--lane-pale:${info.pale};--lane-border:${info.border};--lane-ring:${info.ring};--machine-color:${info.hex};--machine-dark:${info.dark};--machine-pale:${info.pale};--machine-border:${info.border};--ball-color:${info.hex};--cell-color:${info.hex};--cell-pale:${info.pale};`;
}

function renderStatic() {
  elements.legend.innerHTML = COLOR_KEYS.map((color) => `<span class="legend-item"><i class="legend-dot" style="background:${COLORS[color].hex}"></i>${COLORS[color].label}</span>`).join("");
  elements.board.innerHTML = Array.from({ length: 100 }, (_, index) => `<div class="stitch-cell" data-cell="${Math.floor(index / 10)}-${index % 10}"></div>`).join("");
  elements.machineRow.innerHTML = COLOR_KEYS.map((color, index) => {
    const layout = MACHINE_LAYOUT[index];
    return `<div class="machine-card" data-machine="${color}" style="${styleVars(color)}--station-left:${layout.left};--station-top:${layout.top};--station-shift-x:${layout.shiftX};--station-shift-y:${layout.shiftY};"><div class="machine-icon"><span class="needle"></span></div><span class="machine-name">${COLORS[color].label}机</span><span class="machine-index">STATION 0${index + 1}</span><span class="machine-capacity"><strong class="machine-capacity-value">0</strong><small class="machine-capacity-label">可接收</small></span><span class="machine-exhausted">已完成</span><span class="machine-unpublished">待发布</span></div>`;
  }).join("");
}

function renderMaterials() {
  elements.materialsGrid.innerHTML = state.materialLanes.map((lane) => {
    const visibleBalls = lane.balls.map((ball, index) => {
      const color = COLORS[ball.color];
      const isTop = index === 0;
      return `<button class="yarn-ball${isTop ? " is-top" : ""}" type="button" data-lane-id="${lane.id}" data-ball-id="${ball.id}" style="--ball-color:${color.hex}" ${isTop && state.status === "playing" && state.conveyorQueue.length < MAX_QUEUE ? "" : "disabled"} aria-label="${isTop ? "送出" : "等待中的"}${color.label}毛线团"><span class="ball-number">${String(index + 1).padStart(2, "0")}</span></button>`;
    }).join("");
    return `<div class="material-lane" style="${styleVars(lane.balls[0]?.color || COLOR_KEYS[lane.id - 1])}"><div class="lane-header"><span class="lane-title"><i class="lane-swatch"></i>材料区 0${lane.id}</span><span class="lane-count">${lane.balls.length} 枚</span></div><div class="yarn-stack">${visibleBalls || `<div class="lane-empty">这一列已取完</div>`}</div></div>`;
  }).join("");
}

function renderBoard() {
  const stitched = new Set(state.stitchedCells);
  elements.board.querySelectorAll(".stitch-cell").forEach((cell) => {
    const cellData = state.pattern.find((item) => item.id === cell.dataset.cell);
    cell.className = "stitch-cell";
    cell.removeAttribute("style");
    if (cellData) {
      cell.classList.add("target");
      cell.style.cssText = styleVars(cellData.color);
      if (!cellData.active) cell.classList.add("inactive");
    }
    if (cellData && stitched.has(cellData.id)) cell.classList.add("stitched");
  });
}

function renderConveyor() {
  const existing = new Map([...elements.conveyorBalls.children].map((node) => [node.dataset.ballId, node]));
  const activeIds = new Set(state.conveyorQueue.map((item) => String(item.id)));
  existing.forEach((node, id) => { if (!activeIds.has(id)) node.remove(); });
  state.conveyorQueue.forEach((item) => {
    let node = existing.get(String(item.id));
    if (!node) {
      node = document.createElement("div");
      node.className = "moving-ball";
      node.dataset.ballId = item.id;
      node.title = `${COLORS[item.color].label}毛线团`;
      elements.conveyorBalls.appendChild(node);
    }
    node.style.setProperty("--ball-color", COLORS[item.color].hex);
    const point = getLoopPoint(item.progress);
    node.style.left = `${point.x}px`;
    node.style.top = `${point.y}px`;
    node.classList.toggle("is-consumed", item.status === "consumed");
    node.classList.toggle("is-stitching", item.status === "stitching");
  });
}

function getLoopPoint(progress) {
  const width = elements.beltTrack.clientWidth;
  const height = elements.beltTrack.clientHeight;
  const inset = Math.min(48, Math.max(38, Math.min(width, height) * .075));
  const pathWidth = width - inset * 2;
  const pathHeight = height - inset * 2;
  const perimeter = (pathWidth + pathHeight) * 2;
  const distance = (((progress % 1) + 1) % 1) * perimeter;
  if (distance <= pathWidth) return { x: inset + distance, y: height - inset };
  if (distance <= pathWidth + pathHeight) return { x: width - inset, y: height - inset - (distance - pathWidth) };
  if (distance <= pathWidth * 2 + pathHeight) return { x: width - inset - (distance - pathWidth - pathHeight), y: inset };
  return { x: inset, y: inset + (distance - pathWidth * 2 - pathHeight) };
}

function renderRecycle() {
  elements.recycleBalls.innerHTML = state.recycleBin.map((ball) => `<span class="recycle-ball" style="--ball-color:${COLORS[ball.color].hex}" title="${COLORS[ball.color].label}毛线团"></span>`).join("");
  elements.recycleValue.textContent = `${state.recycleBin.length} / ${MAX_RECYCLE}`;
  elements.recycleCapacity.textContent = `${state.recycleBin.length} / ${MAX_RECYCLE}`;
  elements.recycleZone.classList.toggle("shake", state.recycleBin.length >= MAX_RECYCLE);
}

function renderHud() {
  const completed = state.stitchedCells.length;
  const total = state.activeCellIds.length;
  const wave = state.orderWaves[state.currentWaveIndex];
  elements.progressValue.textContent = `${completed} / ${total}`;
  elements.queueCapacity.textContent = `传送带 ${state.conveyorQueue.length} / ${MAX_QUEUE}`;
  elements.machineRow.querySelectorAll(".machine-card").forEach((machine) => {
    const color = machine.dataset.machine;
    const published = Boolean(wave?.publishedColors.includes(color));
    const remaining = state.machineCapacity[color] || 0;
    machine.querySelector(".machine-capacity-value").textContent = published ? remaining : "";
    machine.classList.toggle("is-unpublished", !published);
    machine.classList.toggle("is-exhausted", published && remaining === 0);
  });
  elements.beltStatus.className = "belt-status";
  if (state.status === "lost") {
    elements.beltStatus.classList.add("danger");
    elements.beltStatus.innerHTML = `<span class="status-light"></span>回收区已满`;
  } else if (state.conveyorQueue.length) {
    elements.beltStatus.classList.add("busy");
    elements.beltStatus.innerHTML = `<span class="status-light"></span>绣线运行中`;
  } else if (state.status === "won") {
    elements.beltStatus.innerHTML = `<span class="status-light"></span>图案已完成`;
  } else {
    const labels = wave?.publishedColors.map((color) => COLORS[color].label).join("、") || "";
    elements.beltStatus.innerHTML = `<span class="status-light"></span>第 ${String(state.currentWaveIndex + 1).padStart(2, "0")} 波 · ${labels}订单`;
  }
}

function render() {
  renderMaterials();
  renderBoard();
  renderConveyor();
  renderRecycle();
  renderHud();
  elements.machineRow.querySelectorAll(".machine-card").forEach((machine) => machine.classList.toggle("is-working", machine.dataset.machine === state.activeMachine));
}

function showToast(message, type = "") {
  clearTimeout(toastTimer);
  elements.toast.textContent = message;
  elements.toast.className = `toast visible ${type}`.trim();
  toastTimer = setTimeout(() => { elements.toast.className = "toast"; }, 2100);
}

function markMachineBusy(color) {
  state.activeMachine = color;
  renderHud();
  elements.machineRow.querySelectorAll(".machine-card").forEach((machine) => machine.classList.toggle("is-working", machine.dataset.machine === color));
  clearTimeout(busyTimers[color]);
  busyTimers[color] = setTimeout(() => {
    if (state.activeMachine === color) {
      state.activeMachine = null;
      elements.machineRow.querySelectorAll(".machine-card").forEach((machine) => machine.classList.remove("is-working"));
    }
  }, 500);
}

function isWaveComplete() {
  const wave = state.orderWaves[state.currentWaveIndex];
  if (!wave) return false;
  return wave.publishedColors.every((color) => state.machineCapacity[color] === 0)
    && !state.conveyorQueue.some((item) => item.status === "stitching" && item.waveIndex === state.currentWaveIndex);
}

function advanceWaveIfReady() {
  if (state.status !== "playing" || !isWaveComplete()) return;
  if (state.currentWaveIndex >= state.orderWaves.length - 1) return;
  state.currentWaveIndex += 1;
  const nextWave = state.orderWaves[state.currentWaveIndex];
  state.machineCapacity = Object.fromEntries(COLOR_KEYS.map((color) => [color, nextWave.quotas[color] || 0]));
  const labels = nextWave.publishedColors.map((color) => COLORS[color].label).join("、");
  showToast(`第 ${String(state.currentWaveIndex + 1).padStart(2, "0")} 波订单：${labels}`);
  render();
}

function stitchAtStation(item, stationIndex) {
  const stationColor = COLOR_KEYS[stationIndex];
  if (item.color !== stationColor) return;
  const wave = state.orderWaves[state.currentWaveIndex];
  if (!wave?.publishedColors.includes(stationColor)) {
    item.rejectReason = "not-published";
    return;
  }
  if (state.machineCapacity[stationColor] <= 0) {
    item.rejectReason = "machine-full";
    return;
  }
  const occupiedCells = new Set([
    ...state.stitchedCells,
    ...state.conveyorQueue.filter((queueItem) => queueItem.status === "stitching" && queueItem.stitchTarget).map((queueItem) => queueItem.stitchTarget.id)
  ]);
  const candidates = state.pattern.filter((cell) => wave.cellIds.includes(cell.id) && !occupiedCells.has(cell.id));
  const target = candidates[Math.floor(Math.random() * candidates.length)];
  if (!target) return;
  state.machineCapacity[stationColor] -= 1;
  item.status = "stitching";
  item.waveIndex = state.currentWaveIndex;
  item.stitchTarget = target;
  markMachineBusy(stationColor);
  shootThreadToCell(item, target, stationColor);
}

function shootThreadToCell(item, target, color) {
  const machine = elements.machineRow.querySelector(`[data-machine="${color}"] .machine-icon`);
  const cell = elements.board.querySelector(`[data-cell="${target.id}"]`);
  if (!machine || !cell) {
    completeStitch(item, target, color);
    return;
  }
  const trackRect = elements.beltTrack.getBoundingClientRect();
  const machineRect = machine.getBoundingClientRect();
  const cellRect = cell.getBoundingClientRect();
  const startX = machineRect.left + machineRect.width / 2 - trackRect.left;
  const startY = machineRect.top + machineRect.height / 2 - trackRect.top;
  const endX = cellRect.left + cellRect.width / 2 - trackRect.left;
  const endY = cellRect.top + cellRect.height / 2 - trackRect.top;
  const deltaX = endX - startX;
  const deltaY = endY - startY;
  const line = document.createElement("div");
  line.className = "thread-shot";
  line.style.setProperty("--thread-color", COLORS[color].hex);
  line.style.setProperty("--thread-angle", `${Math.atan2(deltaY, deltaX)}rad`);
  line.style.left = `${startX}px`;
  line.style.top = `${startY}px`;
  line.style.width = `${Math.max(12, Math.hypot(deltaX, deltaY))}px`;
  elements.beltTrack.appendChild(line);
  requestAnimationFrame(() => line.classList.add("shooting"));
  const session = gameSession;
  setTimeout(() => {
    line.remove();
    if (session === gameSession) completeStitch(item, target, color);
  }, 360);
}

function completeStitch(item, target, color) {
  if (state.status !== "playing" || item.status !== "stitching") return;
  state.stitchedCells.push(target.id);
  item.status = "consumed";
  item.removeAt = performance.now() + 320;
  showToast(`${COLORS[color].label}机器完成了一个针脚`);
  if (state.stitchedCells.length === state.activeCellIds.length) {
    state.status = "won";
    showResult("won");
  } else {
    advanceWaveIfReady();
  }
  render();
}

function sendToRecycle(item) {
  state.recycleBin.push(item);
  if (state.recycleBin.length > MAX_RECYCLE) {
    state.status = "lost";
    showResult("lost");
    showToast("回收区超出容量，先整理一下线团", "error");
  } else {
    const message = item.rejectReason === "machine-full"
      ? `${COLORS[item.color].label}机已完成本波接收次数，线团进入回收区`
      : item.rejectReason === "not-published"
        ? `${COLORS[item.color].label}机尚未发布本波订单，线团进入回收区`
        : `${COLORS[item.color].label}线团进入回收区`;
    showToast(message, "error");
  }
  render();
}

function updateConveyor(now) {
  if (!lastFrameTime) lastFrameTime = now;
  const delta = Math.min(.05, (now - lastFrameTime) / 1000);
  lastFrameTime = now;
  if (state.status === "playing") {
    state.conveyorQueue.forEach((item) => {
      if (item.status !== "moving") return;
      const oldProgress = item.progress;
      item.progress += delta * .22;
      STATION_DISTANCES.forEach((distance, stationIndex) => {
        if (oldProgress < distance && item.progress >= distance && item.status === "moving") stitchAtStation(item, stationIndex);
      });
    });
    const finished = [];
    state.conveyorQueue = state.conveyorQueue.filter((item) => {
      if (item.status === "consumed" && now >= item.removeAt) { finished.push(item); return false; }
      if (item.status === "moving" && item.progress >= BELT_END) { finished.push(item); return false; }
      return true;
    });
    finished.forEach((item) => {
      if (item.status === "moving") sendToRecycle(item);
    });
    renderConveyor();
    renderHud();
  }
  animationFrame = requestAnimationFrame(updateConveyor);
}

function dispatchBall(laneId) {
  if (state.status !== "playing") return;
  if (state.conveyorQueue.length >= MAX_QUEUE) {
    showToast("传送带已满，等前面的线团走一走", "error");
    return;
  }
  const lane = state.materialLanes.find((item) => item.id === laneId);
  if (!lane || !lane.balls.length) return;
  const ball = lane.balls.shift();
  state.conveyorQueue.push({ ...ball, progress: 0, status: "moving", processedStation: -1 });
  showToast(`${COLORS[ball.color].label}线团已进入传送带`);
  render();
}

function showResult(result) {
  elements.overlay.hidden = false;
  const won = result === "won";
  elements.resultSeal.textContent = won ? "✦" : "!";
  elements.resultSeal.style.color = won ? "var(--sun-dark)" : "var(--danger)";
  elements.resultSeal.style.background = won ? "#fff7d9" : "#fde8e3";
  elements.resultKicker.textContent = won ? "MISSION COMPLETE" : "WORKTABLE FULL";
  elements.resultTitle.textContent = won ? "花园徽章完成" : "回收区装满了";
  elements.resultCopy.textContent = won ? "所有针脚都已经稳稳落在布面上。" : "这次的错色线团太多了，重新整理材料再试一次。";
  elements.resultProgress.textContent = `${state.stitchedCells.length} / ${state.activeCellIds.length}`;
}

function resetGame() {
  cancelAnimationFrame(animationFrame);
  gameSession += 1;
  elements.beltTrack.querySelectorAll(".thread-shot").forEach((line) => line.remove());
  Object.values(busyTimers).forEach(clearTimeout);
  busyTimers = {};
  state = createInitialState();
  elements.overlay.hidden = true;
  lastFrameTime = 0;
  render();
  animationFrame = requestAnimationFrame(updateConveyor);
}

elements.materialsGrid.addEventListener("click", (event) => {
  const ball = event.target.closest(".yarn-ball");
  if (ball && !ball.disabled) dispatchBall(Number(ball.dataset.laneId));
});
document.querySelector("#resetButton").addEventListener("click", resetGame);
document.querySelector("#resultReset").addEventListener("click", resetGame);

renderStatic();
resetGame();
