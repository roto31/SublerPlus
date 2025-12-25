const output = document.getElementById("output");
const dropzone = document.getElementById("dropzone");
const fileInput = document.getElementById("fileInput");
const queryInput = document.getElementById("query");
const searchBtn = document.getElementById("search-btn");
const resultsEl = document.getElementById("results");
const statusEl = document.getElementById("status");
const activityEl = document.getElementById("activity");

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
  const res = await postJSON("/api/search", { query: q, includeAdult: true });
  renderResults(res.results || []);
  statusEl.textContent = "Done";
});

async function handleFiles(fileList) {
  const names = [];
  for (let i = 0; i < fileList.length; i++) {
    names.push(fileList[i].name);
  }
  log(`Dropped: ${names.join(", ")}`);
  await postJSON("/api/files", { files: names, includeAdult: true });
}

async function pollStatus() {
  try {
    const res = await fetch("/api/status");
    const data = await res.json();
    const lines = (data || []).map((ev) => `[${new Date(ev.timestamp).toLocaleTimeString()}] ${ev.message}`);
    statusEl.textContent = lines.join("\n");
    if (activityEl) activityEl.textContent = lines.join("\n");
  } catch (e) {
    // ignore
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
    div.innerHTML = `<h3>${item.title}</h3><div class="meta">Score: ${item.score ?? "–"}</div>`;
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
  });
  return res.json();
}

pollStatus();
