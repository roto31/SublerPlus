const output = document.getElementById("output");
const dropzone = document.getElementById("dropzone");
const fileInput = document.getElementById("fileInput");
const queryInput = document.getElementById("query");
const searchBtn = document.getElementById("search-btn");
const resultsEl = document.getElementById("results");
const statusEl = document.getElementById("status");
const activityEl = document.getElementById("activity");
const tokenInput = document.getElementById("token");
const homeBtn = document.getElementById("home-btn");
const reloadBtn = document.getElementById("reload-btn");
const livePill = document.getElementById("live-pill");
let lastStatusAt = null;

dropzone.addEventListener("dragover", (e) => {
  e.preventDefault();
  dropzone.classList.add("dragging");
});
dropzone.addEventListener("dragleave", () => dropzone.classList.remove("dragging"));
dropzone.addEventListener("drop", (e) => {
  e.preventDefault();
  dropzone.classList.remove("dragging");
  handleFiles(e.dataTransfer.files);
});
fileInput.addEventListener("change", (e) => handleFiles(e.target.files));

searchBtn.addEventListener("click", async () => {
  const q = queryInput.value.trim();
  if (!q) return;
  statusEl.textContent = "Searching…";
  try {
    const res = await postJSON("/api/search", { query: q, includeAdult: true });
    renderResults(res.results || []);
    statusEl.textContent = "Done";
  } catch (err) {
    statusEl.textContent = "Search failed";
    log(`Search error: ${err.message}`);
  }
});

if (homeBtn) {
  homeBtn.addEventListener("click", () => {
    window.location.href = "/";
  });
}
if (reloadBtn) {
  reloadBtn.addEventListener("click", () => {
    window.location.reload();
  });
}

async function handleFiles(fileList) {
  const names = [];
  const accepted = [];
  const rejected = [];
  for (let i = 0; i < fileList.length; i++) {
    const name = fileList[i].name;
    names.push(name);
    if (isSupported(name)) {
      accepted.push(name);
    } else {
      rejected.push(name);
  }
  }
  if (accepted.length) {
    log(`Accepted: ${accepted.join(", ")}`);
  }
  if (rejected.length) {
    log(`Rejected (unsupported): ${rejected.join(", ")}`);
  }
  try {
    await postJSON("/api/files", { files: accepted, includeAdult: true });
    log(`Queued ${accepted.length} file(s) for processing.`);
  } catch (err) {
    log(`Failed to queue files: ${err.message}`);
  }
}

async function pollStatus() {
  try {
    const res = await fetch("/api/status", { headers: authHeaders() });
    const data = await res.json();
    const lines = (data || []).map((ev) => `[${new Date(ev.timestamp).toLocaleTimeString()}] ${ev.message}`);
    const recent = lines.slice(-10).join("\n");
    statusEl.textContent = recent || "Idle";
    if (activityEl) {
      activityEl.textContent = lines.slice(-20).join("\n") || "No activity yet.";
    }
    lastStatusAt = Date.now();
    setLiveState("ok", "● Live");
  } catch (e) {
    setLiveState("warn", "● Reconnecting…");
    statusEl.textContent = "Connection error";
  } finally {
    setTimeout(pollStatus, 1500);
  }
}

function renderResults(items) {
  resultsEl.innerHTML = "";
  if (!items.length) {
    resultsEl.textContent = "No results.";
    return;
  }
  for (const item of items) {
    const div = document.createElement("div");
    div.className = "result";
    const score = item.score ?? "–";
    const provider = item.source ? `<span class="pill">${item.source}</span>` : "";
    const year = item.year ? `<span class="pill ghost">${item.year}</span>` : "";
    let thumb = "";
    if (item.coverURL) {
      thumb = `<div class="thumb-wrapper"><img src="${item.coverURL}" class="thumb" alt="Artwork" loading="lazy" onerror="this.style.display='none'"></div>`;
    } else {
      thumb = `<div class="thumb-wrapper"><div class="thumb-placeholder">No Artwork</div></div>`;
    }
    div.innerHTML = `${thumb}<div class="result-body"><h3>${item.title}</h3><div class="meta">Score: ${score} ${provider} ${year}</div></div>`;
    resultsEl.appendChild(div);
  }
}

function log(msg) {
  output.value += msg + "\n";
}

async function postJSON(url, payload) {
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
    mode: "same-origin",
    credentials: "omit",
    headers: authHeaders({ "Content-Type": "application/json" }),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`HTTP ${res.status}: ${text}`);
  }
  return res.json();
}

function authHeaders(extra = {}) {
  const headers = { ...extra };
  const token = tokenInput?.value?.trim() || localStorage.getItem("webui_token");
  if (token) {
    headers["X-Auth-Token"] = token;
  }
  return headers;
}

function setLiveState(state, text) {
  if (!livePill) return;
  livePill.textContent = text;
  livePill.className = "status-pill";
  if (state) livePill.classList.add(state);
}

function isSupported(name) {
  const lower = name.toLowerCase();
  return lower.endsWith(".mp4") || lower.endsWith(".m4v") || lower.endsWith(".mov");
}

pollStatus();
