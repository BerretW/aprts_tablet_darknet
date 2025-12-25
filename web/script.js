function escapeHtml(text) {
  if (!text) return "";
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

var DarknetApp = {
  currentView: "system",
  mySerial: null,
  currentReputation: 0,
  activeChatJobId: null,

  init: function () {
    // Počkáme na element s ID serialu
    let serialEl = document.getElementById("my-serial");
    if (!serialEl) {
      setTimeout(() => DarknetApp.init(), 100);
      return;
    }
    this.mySerial = serialEl.value;

    // Listener pro zprávy z Lua
    window.addEventListener("message", this.onMessage);

    // Enter v chatu pro odeslání
    let chatInput = document.getElementById("chat-text");
    if (chatInput) {
      chatInput.addEventListener("keydown", function (e) {
        if (e.key === "Enter") DarknetApp.sendMessage();
      });
    }

    // Načíst default view
    this.switchView("system");
  },

  // Přepínání stránek
  switchView: function (viewName) {
    this.currentView = viewName;

    // UI Tabs styl
    document
      .querySelectorAll(".nav-btn")
      .forEach((btn) => btn.classList.remove("active"));
    let activeBtn = document.querySelector(
      `.nav-btn[onclick="DarknetApp.switchView('${viewName}')"]`
    );
    if (activeBtn) activeBtn.classList.add("active");

    // Loading state
    document.getElementById("content-area").innerHTML =
      '<div style="text-align:center; padding:20px; color:#555;">Načítání dat...</div>';

    // Request data od serveru
    System.pluginAction("darknet", "fetchData", { view: viewName });
  },

  // Příjem dat z Lua
  onMessage: function (event) {
    let data = event.data;

    if (data.action === "darknet_updateData") {
      DarknetApp.currentReputation = data.reputation;
      let repEl = document.getElementById("display-rep");
      if (repEl) repEl.innerText = data.reputation;

      // Zde voláme rendery a předáváme activeJob pro filtrování
      if (data.view === "system")
        DarknetApp.renderSystemJobs(data.systemJobs, data.activeJob);
      if (data.view === "market") DarknetApp.renderMarket(data.marketJobs);
      if (data.view === "myjobs")
        DarknetApp.renderMyJobs(data.postedJobs, data.activeJob);
    } else if (data.action === "darknet_updateChat") {
      DarknetApp.openChatModal(data.messages, data.jobId);
    } else if (data.action === "darknet_newChatMessage") {
      DarknetApp.appendChatMessage(data.message);
    }
  },

  // --- RENDERERY ---

  renderSystemJobs: function (jobs, activeJob) {
    let html = "";

    // Pokud existuje aktivní systémová zakázka, získáme její ID
    let activeId = activeJob && activeJob.isSystemJob ? activeJob.id : null;

    for (let [id, job] of Object.entries(jobs)) {
      // Pokud je tato zakázka právě aktivní, přeskočíme ji (nezobrazíme v nabídce)
      if (activeId === id) continue;

      let isLocked = DarknetApp.currentReputation < job.minReputation;
      let lockedClass = isLocked ? "locked" : "unlocked";
      let btnAttr = isLocked
        ? "disabled"
        : `onclick="System.pluginAction('darknet', 'acceptSystemJob', {jobId: '${id}'})"`;
      let btnText = isLocked
        ? `ZAMČENO (Rep: ${job.minReputation})`
        : "PŘIJMOUT KONTRAKT";

      html += `
                <div class="job-card ${lockedClass}" style="opacity: ${
        isLocked ? 0.5 : 1
      }">
                    <div class="job-title">${
                      job.label
                    } <span style="float:right; font-size:10px; color:#00b894">+$${
        job.payout || 0
      }</span></div>
                    <div class="job-desc">${job.description}</div>
                    <div class="job-reward">Odměna Reputace: +${
                      job.repReward
                    }</div>
                    <button class="btn" ${btnAttr} style="width:100%">${btnText}</button>
                </div>
            `;
    }

    if (html === "")
      html =
        '<div style="text-align:center; padding:20px; color:#555;">Žádné další dostupné zakázky.</div>';

    document.getElementById("content-area").innerHTML = html;
  },

  renderMarket: function (jobs) {
    let html = "";

    // Formulář (jen pro zkušené - hranice 100 rep)
    if (DarknetApp.currentReputation >= 100) {
      html += `
                <div class="new-job-form">
                    <div style="color:#d63031; margin-bottom:5px;">NOVÁ ZAKÁZKA (ANONYMNÍ)</div>
                    <input id="new-title" class="input-dark" placeholder="Předmět">
                    <input id="new-desc" class="input-dark" placeholder="Popis">
                    <input id="new-reward" class="input-dark" type="number" placeholder="Odměna ($)">
                    <button class="btn" onclick="DarknetApp.createJob()">VYPSAT ZAKÁZKU</button>
                </div>
            `;
    }

    if (!jobs || jobs.length === 0) {
      html += '<div style="color:#555;">Žádné dostupné zakázky na trhu.</div>';
    } else {
      jobs.forEach((job) => {
        // [NOVÉ] Použití escapeHtml u title a description
        html += `
                <div class="job-card unlocked">
                    <div class="job-title">${escapeHtml(
                      job.title
                    )} <span class="job-price">$${job.reward}</span></div>
                    <div class="job-desc">${escapeHtml(job.description)}</div>
                    <div style="font-size:9px; color:#555;">ID: ${
                      job.id
                    } | Zadavatel: ${job.creator_serial.slice(-4)}</div>
                    <button class="btn" onclick="System.pluginAction('darknet', 'acceptCustomJob', {jobId: ${
                      job.id
                    }})">PŘIJMOUT</button>
                </div>
            `;
      });
    }
    document.getElementById("content-area").innerHTML = html;
  },

  renderMyJobs: function (posted, active) {
    let html =
      '<h3 style="color:#aaa; border-bottom:1px solid #333">AKTIVNÍ PRÁCE</h3>';

    if (active) {
      // Rozhodování, zda zobrazit CHAT nebo instrukce
      let chatBtn = "";
      let statusLabel = "";

      if (active.isSystemJob) {
        // Systémová zakázka -> Žádný chat
        statusLabel =
          '<span style="color:#ff7675; font-size:10px;">(SYSTÉMOVÁ MISE)</span>';
        chatBtn = `<div style="font-size:10px; color:#aaa; margin-top:5px; border-top:1px dashed #444; padding-top:5px;"><i>Sleduj GPS a splň instrukce. Chat není dostupný.</i></div>`;
      } else {
        // Hráčská zakázka -> Chat
        statusLabel =
          '<span style="color:#00b894; font-size:10px;">(P2P KONTRAKT)</span>';
        chatBtn = `<button class="btn btn-chat" onclick="System.pluginAction('darknet', 'fetchChat', {jobId: ${active.id}})">OTEVŘÍT KOMUNIKACI</button>`;
      }

      html += `
                <div class="job-card active-job">
                    <div class="job-title" style="color:#00b894">${active.title} ${statusLabel}</div>
                    <div class="job-desc">${active.description}</div>
                    <div style="font-size:10px; margin-bottom:5px;">Odměna: $${active.reward}</div>
                    ${chatBtn}
                </div>
            `;
    } else {
      html +=
        '<div style="color:#555; margin-bottom:20px;">Nemáš aktivní zakázku.</div>';
    }

    html +=
      '<h3 style="color:#aaa; border-bottom:1px solid #333">MNOU VYPSANÉ</h3>';
    if (posted && posted.length > 0) {
      posted.forEach((job) => {
        let statusColor = job.status === "active" ? "#00b894" : "#e17055";
        let statusText =
          job.status === "active" ? "PROBÍHÁ" : "ČEKÁ NA PŘIJETÍ";
        let chatBtn =
          job.status === "active"
            ? `<button onclick="System.pluginAction('darknet', 'fetchChat', {jobId: ${job.id}})" style="background:#fff; color:black; border:none; cursor:pointer; padding:2px 5px;">CHAT</button>`
            : "";

        html += `
                    <div style="background:#111; border-left:3px solid ${statusColor}; padding:10px; margin-bottom:5px;">
                        <div style="display:flex; justify-content:space-between;">
                            <span>${escapeHtml(job.title)}</span>
                        <span style="color:${statusColor}; font-size:10px;">${statusText}</span>
                        </div>
                        <div style="margin-top:5px; font-size:10px;">
                            ${chatBtn}
                            <button class="btn-delete" onclick="System.pluginAction('darknet', 'finishCustomJob', {jobId: ${
                              job.id
                            }})">UKONČIT</button>
                        </div>
                    </div>
                `;
      });
    } else {
      html += '<div style="color:#555;">Žádné vypsané zakázky.</div>';
    }
    document.getElementById("content-area").innerHTML = html;
  },

  // --- AKCE ---

  createJob: function () {
    let t = document.getElementById("new-title").value;
    let d = document.getElementById("new-desc").value;
    let r = document.getElementById("new-reward").value;
    if (t && d && r) {
      System.pluginAction("darknet", "createCustomJob", {
        title: t,
        description: d,
        reward: r,
      });
    }
  },

  // --- CHAT ---

  openChatModal: function (messages, jobId) {
    this.activeChatJobId = jobId;
    document.getElementById("chat-modal").style.display = "flex";
    let container = document.getElementById("chat-messages");
    container.innerHTML = "";

    messages.forEach((msg) => {
      this.appendChatMessage(msg);
    });

    // Scroll down
    container.scrollTop = container.scrollHeight;
  },

  appendChatMessage: function (msg) {
    if (msg.job_id && msg.job_id != this.activeChatJobId) return;

    let isMe = msg.sender_serial === this.mySerial;
    let div = document.createElement("div");
    div.className = `msg ${isMe ? "right" : "left"}`;

    // [NOVÉ] Použití innerText místo innerHTML nebo vkládání stringu
    // Tím prohlížeč automaticky bere text jako text, ne jako kód.
    div.innerText = msg.message;

    let container = document.getElementById("chat-messages");
    container.appendChild(div);
    container.scrollTop = container.scrollHeight;
  },

  sendMessage: function () {
    let input = document.getElementById("chat-text");
    let val = input.value;
    if (val && this.activeChatJobId) {
      System.pluginAction("darknet", "sendChat", {
        jobId: this.activeChatJobId,
        message: val,
      });
      input.value = "";
    }
  },

  closeChat: function () {
    document.getElementById("chat-modal").style.display = "none";
    this.activeChatJobId = null;
  },
};

// Init
setTimeout(() => DarknetApp.init(), 200);
