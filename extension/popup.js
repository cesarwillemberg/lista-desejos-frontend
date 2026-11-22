const storage = globalThis.browser?.storage || chrome.storage;
const tabs = globalThis.browser?.tabs || chrome.tabs;

const apiInput = document.querySelector("#api");
const loginForm = document.querySelector("#login");
const addForm = document.querySelector("#add");
const message = document.querySelector("#message");
const who = document.querySelector("#who");
const listSelect = document.querySelector("#list");

function say(text) {
  message.textContent = text;
}

async function saved() {
  return await storage.local.get(["token", "api", "email"]);
}

async function request(path, options = {}) {
  const state = await saved();
  const base = (apiInput.value || state.api || "").replace(/\/$/, "");
  const headers = { ...(options.headers || {}) };
  if (state.token) headers.Authorization = `Bearer ${state.token}`;
  if (options.body) headers["content-type"] = "application/json";
  const response = await fetch(`${base}${path}`, { ...options, headers });
  const text = await response.text();
  const data = text ? JSON.parse(text) : {};
  if (!response.ok) throw new Error(data.detail || "Não foi possível falar com a Wishly.");
  return data;
}

async function fillTab() {
  const [tab] = await tabs.query({ active: true, currentWindow: true });
  if (!tab) return;
  document.querySelector("#title").value = tab.title || "";
  document.querySelector("#url").value = tab.url || "";
}

async function showLists() {
  const lists = await request("/api/lists");
  listSelect.replaceChildren();
  for (const list of lists.lists || []) {
    const option = document.createElement("option");
    option.value = list.id;
    option.textContent = list.name;
    listSelect.append(option);
  }
  const state = await saved();
  who.textContent = state.email || "";
  loginForm.hidden = true;
  addForm.hidden = false;
}

loginForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  say("");
  try {
    const data = await request("/api/auth/login", {
      method: "POST",
      body: JSON.stringify({
        email: document.querySelector("#email").value,
        password: document.querySelector("#password").value,
      }),
    });
    await storage.local.set({
      token: data.token,
      api: apiInput.value.replace(/\/$/, ""),
      email: data.user.email,
    });
    await showLists();
    await fillTab();
  } catch (error) {
    say(error.message);
  }
});

addForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  say("");
  try {
    await request(`/api/lists/${listSelect.value}/items`, {
      method: "POST",
      body: JSON.stringify({
        name: document.querySelector("#title").value,
        url: document.querySelector("#url").value,
        priority: document.querySelector("#priority").value,
        note: document.querySelector("#note").value,
      }),
    });
    say("Entrou na lista.");
  } catch (error) {
    say(error.message);
  }
});

document.querySelector("#logout").addEventListener("click", async () => {
  await storage.local.remove(["token", "email"]);
  addForm.hidden = true;
  loginForm.hidden = false;
});

saved().then(async (state) => {
  if (state.api) apiInput.value = state.api;
  if (!state.token) return;
  try {
    await showLists();
    await fillTab();
  } catch (error) {
    say(error.message);
  }
});
