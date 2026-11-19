(() => {
  const API = "/proxy";
  const state = {
    query: "",
    results: [],
    selected: null,
    networkData: null,
    circles: new Set([1]),
    view: "graph",
    network: null,
    searchTimer: null,
    searchRequestId: 0,
  };

  const els = {
    searchInput: document.getElementById("searchInput"),
    clearBtn: document.getElementById("clearBtn"),
    searchStatus: document.getElementById("searchStatus"),
    results: document.getElementById("results"),
    workspace: document.getElementById("workspace"),
    personBanner: document.getElementById("personBanner"),
    stats: document.getElementById("stats"),
    board: document.getElementById("board"),
    listHint: document.getElementById("listHint"),
    graphView: document.getElementById("graphView"),
    graphNote: document.getElementById("graphNote"),
    connectionList: document.getElementById("connectionList"),
    loadingOverlay: document.getElementById("loadingOverlay"),
    detail: document.getElementById("detail"),
  };

  function escapeHtml(v) {
    return String(v ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  async function apiGet(path) {
    const res = await fetch(`${API}/${path.replace(/^\//, "")}`, {
      headers: { Accept: "application/json" },
    });
    if (!res.ok) throw new Error(`API ${res.status}`);
    return res.json();
  }

  function isPersonalId(q) {
    return /^\d{11}$/.test(q.trim());
  }

  async function searchPeople(query) {
    const q = query.trim();
    if (q.length < 1) return [];
    if (isPersonalId(q)) {
      const params = new URLSearchParams({ page: "1", idNumber: q });
      const data = await apiGet(`people/search?${params}`);
      return (data.items || []).slice(0, 5);
    }
    if (q.length < 2) return [];

    let suggestions = await apiGet(`person/${encodeURIComponent(q)}`);
    if (!Array.isArray(suggestions) || !suggestions.length) {
      const params = new URLSearchParams({ page: "1", name: q });
      const data = await apiGet(`people/search?${params}`);
      suggestions = data.items || [];
    }
    return suggestions.slice(0, 5).map((it) => ({
      id: it.id,
      name: it.name,
      idNumber: it.idNumber,
      nationality: it.nationality,
      compCnt: it.compCnt,
    }));
  }

  function analyzeGraph(graph, seedId) {
    const nodes = {};
    for (const n of graph.nodes || []) nodes[n.id] = { ...n };
    const edges = graph.edges || [];
    const seed = `person${seedId}`;

    for (const e of edges) {
      for (const x of [e.from, e.to]) {
        if (x.startsWith("person") && !nodes[x]) {
          nodes[x] = { id: x, label: null, idCode: null, group: "user" };
        }
      }
    }

    const p2c = new Map();
    const c2p = new Map();
    const add = (map, k, v) => {
      if (!map.has(k)) map.set(k, new Set());
      map.get(k).add(v);
    };
    for (const e of edges) {
      const a = e.from;
      const b = e.to;
      if (a.startsWith("person") && b.startsWith("company")) {
        add(p2c, a, b);
        add(c2p, b, a);
      } else if (b.startsWith("person") && a.startsWith("company")) {
        add(p2c, b, a);
        add(c2p, a, b);
      }
    }

    const seedCompanies = p2c.get(seed) || new Set();
    const circle1 = new Set();
    const circle1Rows = [];
    for (const comp of seedCompanies) {
      for (const p of c2p.get(comp) || []) {
        if (p === seed) continue;
        circle1.add(p);
        circle1Rows.push([p, comp]);
      }
    }

    const circle2Rows = [];
    for (const p1 of circle1) {
      for (const comp of p2c.get(p1) || []) {
        if (seedCompanies.has(comp)) continue;
        for (const p2 of c2p.get(comp) || []) {
          if (p2 === seed || p2 === p1 || circle1.has(p2)) continue;
          circle2Rows.push([p2, comp, p1]);
        }
      }
    }

    const people = {};
    const companies = {};
    const links = [];
    const linkset = new Set();

    const personKey = (pid) => {
      const n = nodes[pid] || {};
      const idNum = n.idCode || "";
      const name = n.label || pid;
      if (!n.label || String(n.label).startsWith("person")) return null;
      return { key: idNum ? `pid:${idNum}` : `name:${name}`, name, personalId: idNum || "" };
    };

    const companyKey = (cid) => {
      const n = nodes[cid] || {};
      const code = n.idCode || "";
      const name = n.label || cid;
      const key = code ? `co:${code}` : `co:${name}`;
      companies[key] = { id: key, name, code };
      return key;
    };

    const upsertPerson = (pid, circle) => {
      const info = personKey(pid);
      if (!info) return null;
      const prev = people[info.key];
      if (!prev || prev.circle > circle) {
        people[info.key] = {
          id: info.key,
          name: info.name,
          personalId: info.personalId,
          circle,
        };
      }
      return info.key;
    };

    const addLink = (a, b, circle) => {
      if (!a || !b) return;
      const k = `${a}|${b}|${circle}`;
      if (linkset.has(k)) return;
      linkset.add(k);
      links.push({ from: a, to: b, circle });
    };

    const seedKey = upsertPerson(seed, 0);
    for (const [p, comp] of circle1Rows) {
      const pk = upsertPerson(p, 1);
      const ck = companyKey(comp);
      addLink(seedKey, ck, 1);
      addLink(pk, ck, 1);
    }
    for (const [p2, comp, p1] of circle2Rows) {
      const p1k = upsertPerson(p1, 1);
      const p2k = upsertPerson(p2, 2);
      const ck = companyKey(comp);
      addLink(p1k, ck, 2);
      addLink(p2k, ck, 2);
    }
    for (const comp of seedCompanies) {
      addLink(seedKey, companyKey(comp), 1);
    }

    const peopleList = Object.values(people);
    return {
      people,
      companies,
      links,
      stats: {
        companies: Object.keys(companies).length,
        circle1: peopleList.filter((p) => p.circle === 1).length,
        circle2People: peopleList.filter((p) => p.circle === 2).length,
        links: links.length,
      },
    };
  }

  function setStatus(text) {
    els.searchStatus.textContent = text || "";
  }

  function setLoading(on) {
    els.loadingOverlay.classList.toggle("hidden", !on);
  }

  function renderResults(items) {
    if (!items.length) {
      els.results.classList.add("hidden");
      els.results.innerHTML = "";
      return;
    }
    els.results.classList.remove("hidden");
    els.results.innerHTML = items
      .slice(0, 5)
      .map((it, i) => {
        const name = String(it.name || "").replace(/^:\s*/, "").trim();
        return `<button type="button" class="result-item" data-idx="${i}">
          <p class="name">${escapeHtml(name)}</p>
          <p class="pid">${escapeHtml(it.idNumber || "პირადი ნომერი —")}</p>
        </button>`;
      })
      .join("");
  }

  async function onSearchInput() {
    const q = els.searchInput.value.trim();
    state.query = q;
    els.clearBtn.classList.toggle("hidden", !q);
    clearTimeout(state.searchTimer);

    if (q.length < 2 && !isPersonalId(q)) {
      state.results = [];
      renderResults([]);
      setStatus("");
      return;
    }

    setStatus("იძებნება…");
    const requestId = ++state.searchRequestId;
    state.searchTimer = setTimeout(async () => {
      try {
        const items = await searchPeople(q);
        if (requestId !== state.searchRequestId) return;
        if (els.searchInput.value.trim() !== q) return;
        state.results = items.slice(0, 5);
        renderResults(state.results);
        setStatus(state.results.length ? `${state.results.length} შემოთავაზება` : "ვერ მოიძებნა");
      } catch (err) {
        if (requestId !== state.searchRequestId) return;
        console.error(err);
        setStatus("ძიება ვერ მოხერხდა");
        renderResults([]);
      }
    }, 160);
  }

  function renderPersonBanner(name, person, stats) {
    const href = person.idNumber
      ? `https://companyinfo.ge/ka/people/search?name=${encodeURIComponent(name)}&idNumber=${encodeURIComponent(person.idNumber)}`
      : `https://companyinfo.ge/ka/people/search?name=${encodeURIComponent(name)}`;
    const meta = [person.nationality, person.compCnt != null ? `${person.compCnt} კომპანია რეესტრში` : ""]
      .filter(Boolean)
      .join(" · ");
    els.personBanner.innerHTML = `
      <div class="profile-top">
        <div>
          <h2>${escapeHtml(name)}</h2>
          <p class="pid">${escapeHtml(person.idNumber || "პირადი ნომერი —")}</p>
          ${meta ? `<p class="meta">${escapeHtml(meta)}</p>` : ""}
        </div>
        <a class="profile-link" href="${href}" target="_blank" rel="noopener">CompanyInfo ↗</a>
      </div>
    `;
  }

  function renderStats(stats) {
    if (!stats) {
      els.stats.innerHTML = "";
      return;
    }
    els.stats.innerHTML = `
      <div class="stat"><b>${stats.circle1}</b><span>თანამეწილე · წრე I</span></div>
      <div class="stat"><b>${stats.circle2People}</b><span>მე-2 წრე</span></div>
      <div class="stat"><b>${stats.companies}</b><span>კომპანია</span></div>
      <div class="stat"><b>${stats.links}</b><span>კავშირი</span></div>
    `;
  }

  async function selectPerson(person) {
    state.selected = person;
    els.results.classList.add("hidden");
    els.workspace.classList.remove("hidden");
    const name = String(person.name || "").replace(/^:\s*/, "").trim();
    renderPersonBanner(name, person, null);
    renderStats(null);
    els.detail.innerHTML = `<p class="detail-empty">აირჩიეთ პირი ან კომპანია სიიდან / რუკიდან დეტალებისთვის</p>`;
    setLoading(true);
    setStatus("");

    try {
      const level = state.circles.has(2) ? 4 : 2;
      const graph = await apiGet(`relationship-graph?person=${person.id}&level=${level}`);
      state.networkData = analyzeGraph(graph, person.id);
      const seedKey = person.idNumber ? `pid:${person.idNumber}` : `name:${name}`;
      if (!state.networkData.people[seedKey]) {
        state.networkData.people[seedKey] = {
          id: seedKey,
          name,
          personalId: person.idNumber || "",
          circle: 0,
        };
      } else {
        state.networkData.people[seedKey].circle = 0;
        state.networkData.people[seedKey].name = name;
        state.networkData.people[seedKey].personalId =
          person.idNumber || state.networkData.people[seedKey].personalId;
      }
      renderPersonBanner(name, person, state.networkData.stats);
      renderStats(state.networkData.stats);
      try {
        refreshViews();
      } catch (viewErr) {
        console.error(viewErr);
        els.graphView.innerHTML = `<p class="empty-state">რუკა ვერ დაიხატა</p>`;
      }
    } catch (err) {
      console.error(err);
      els.connectionList.innerHTML = `<p class="empty-state">კავშირების ჩატვირთვა ვერ მოხერხდა</p>`;
      if (state.network) {
        try { state.network.destroy(); } catch (_) {}
        state.network = null;
      }
      els.graphView.innerHTML = `<p class="empty-state">კავშირების ჩატვირთვა ვერ მოხერხდა</p>`;
    } finally {
      setLoading(false);
    }
  }

  function showDetail(kind, meta) {
    if (kind === "person") {
      const circleLabel =
        meta.circle === 0 ? "არჩეული პირი" : meta.circle === 1 ? "თანამეწილე · წრე I" : "მეორე წრე";
      const href = meta.personalId
        ? `https://companyinfo.ge/ka/people/search?name=${encodeURIComponent(meta.name)}&idNumber=${encodeURIComponent(meta.personalId)}`
        : `https://companyinfo.ge/ka/people/search?name=${encodeURIComponent(meta.name)}`;
      els.detail.innerHTML = `
        <h3>${escapeHtml(meta.name)}</h3>
        <p class="pid-lg">${escapeHtml(meta.personalId || "პირადი ნომერი —")}</p>
        <p>${circleLabel}</p>
        <p><a href="${href}" target="_blank" rel="noopener">გახსნა CompanyInfo-ში</a></p>
      `;
    } else {
      const href = meta.code
        ? `https://companyinfo.ge/ka/corporations/search?name=${encodeURIComponent(meta.name)}&idCode=${encodeURIComponent(meta.code)}`
        : `https://companyinfo.ge/ka/corporations/search?name=${encodeURIComponent(meta.name)}`;
      els.detail.innerHTML = `
        <h3>${escapeHtml(meta.name)}</h3>
        <p class="pid-lg">${escapeHtml(meta.code || "კოდი —")}</p>
        <p>კომპანია</p>
        <p><a href="${href}" target="_blank" rel="noopener">გახსნა CompanyInfo-ში</a></p>
      `;
    }
  }

  function buildTreeModel() {
    const data = state.networkData;
    if (!data) return null;
    const showC2 = state.circles.has(2);
    const seed = Object.values(data.people).find((p) => p.circle === 0);
    if (!seed) return null;

    const seedCompanies = new Set();
    const coToC1 = new Map();
    const coToC2 = new Map();

    for (const l of data.links) {
      const personId = l.from.startsWith("co:") ? l.to : l.from;
      const companyId = l.from.startsWith("co:") ? l.from : l.to;
      const person = data.people[personId];
      const company = data.companies[companyId];
      if (!person || !company) continue;

      if (personId === seed.id) {
        seedCompanies.add(companyId);
        continue;
      }
      if (person.circle === 1) {
        if (!coToC1.has(companyId)) coToC1.set(companyId, new Map());
        coToC1.get(companyId).set(personId, person);
      } else if (person.circle === 2 && showC2) {
        if (!coToC2.has(companyId)) coToC2.set(companyId, new Map());
        coToC2.get(companyId).set(personId, person);
      }
    }

    const columns = [...seedCompanies]
      .map((id) => data.companies[id])
      .filter(Boolean)
      .sort((a, b) => a.name.localeCompare(b.name, "ka"))
      .map((company) => {
        const people = [...(coToC1.get(company.id)?.values() || [])].sort((a, b) =>
          a.name.localeCompare(b.name, "ka")
        );
        return { company, people };
      });

    const c2Groups = showC2
      ? [...coToC2.entries()]
          .map(([companyId, peopleMap]) => {
            const company = data.companies[companyId];
            if (!company || seedCompanies.has(companyId)) return null;
            const people = [...peopleMap.values()].sort((a, b) =>
              a.name.localeCompare(b.name, "ka")
            );
            if (!people.length) return null;
            return { company, people };
          })
          .filter(Boolean)
          .sort((a, b) => a.company.name.localeCompare(b.company.name, "ka"))
      : [];

    return { seed, columns, c2Groups, showC2 };
  }

  function shorten(s, n) {
    const t = String(s || "");
    return t.length > n ? t.slice(0, n - 1) + "…" : t;
  }

  function estimateTextWidth(text, size, weight) {
    const avg = weight >= 700 ? size * 0.62 : size * 0.55;
    return Math.ceil(String(text || "").length * avg);
  }

  function drawGraph() {
    if (state.network) {
      try { state.network.destroy(); } catch (_) {}
      state.network = null;
    }

    const tree = buildTreeModel();
    if (!tree) {
      els.graphView.innerHTML = `<p class="empty-state">კავშირები ვერ მოიძებნა</p>`;
      els.graphNote.classList.add("hidden");
      return;
    }

    const { seed, columns, c2Groups, showC2 } = tree;
    const PAD_X = 28;
    const PAD_TOP = 28;
    const SEED_H = 56;
    const CO_H = 44;
    const PERSON_H = 34;
    const GAP_Y1 = 54;
    const GAP_Y2 = 36;
    const COL_GAP = 28;
    const PERSON_GAP = 8;
    const MAX_C2_SHOW = 48;

    // Cap people per company column visually but keep structure clear
    const laid = columns.map((col) => {
      const people = col.people;
      const truncated = people.length > 24;
      const shown = truncated ? people.slice(0, 24) : people;
      const cols = shown.length > 12 ? 2 : 1;
      const rows = Math.ceil(shown.length / cols) || 1;
      const label = shorten(col.company.name, 22);
      const personW = 148;
      const blockW = Math.max(
        estimateTextWidth(label, 13, 700) + 28,
        cols * personW + (cols - 1) * 10,
        160
      );
      const blockH = CO_H + GAP_Y2 + rows * (PERSON_H + PERSON_GAP) - PERSON_GAP + (truncated ? 26 : 0);
      return { ...col, shown, truncated, cols, rows, label, personW, blockW, blockH };
    });

    const contentW = laid.reduce((s, c) => s + c.blockW, 0) + Math.max(laid.length - 1, 0) * COL_GAP;
    const seedLabel = shorten(seed.name, 28);
    const seedW = Math.max(220, estimateTextWidth(seedLabel, 16, 700) + 48);
    const width = Math.max(contentW, seedW) + PAD_X * 2;

    let x = PAD_X + Math.max(0, (width - PAD_X * 2 - contentW) / 2);
    for (const col of laid) {
      col.x = x;
      col.cx = x + col.blockW / 2;
      x += col.blockW + COL_GAP;
    }

    const seedX = width / 2;
    const seedY = PAD_TOP + SEED_H / 2;
    const coY = PAD_TOP + SEED_H + GAP_Y1 + CO_H / 2;
    const peopleTop = PAD_TOP + SEED_H + GAP_Y1 + CO_H + GAP_Y2;
    const c1Bottom = peopleTop + Math.max(0, ...laid.map((c) => c.blockH - CO_H - GAP_Y2));

    const hits = new Map();
    hits.set(seed.id, { kind: "person", meta: seed });

    const lines = [];
    const nodes = [];

    // seed → horizontal bus → companies
    if (laid.length) {
      const busY = seedY + SEED_H / 2 + 18;
      lines.push(`<path d="M${seedX} ${seedY + SEED_H / 2} V${busY}" class="map-link seed" />`);
      if (laid.length > 1) {
        const minCx = laid[0].cx;
        const maxCx = laid[laid.length - 1].cx;
        lines.push(`<path d="M${minCx} ${busY} H${maxCx}" class="map-link seed" />`);
      }
      for (const col of laid) {
        lines.push(`<path d="M${col.cx} ${busY} V${coY - CO_H / 2}" class="map-link seed" />`);
      }
    }

    nodes.push(`
      <g class="map-node seed" data-kind="person" data-id="${escapeHtml(seed.id)}" transform="translate(${seedX}, ${seedY})">
        <title>${escapeHtml(seed.name)} · ${escapeHtml(seed.personalId || "")}</title>
        <rect x="${-seedW / 2}" y="${-SEED_H / 2}" width="${seedW}" height="${SEED_H}" rx="16" />
        <text class="t-kicker" y="-8">არჩეული</text>
        <text class="t-main" y="12">${escapeHtml(seedLabel)}</text>
      </g>`);

    for (const col of laid) {
      hits.set(col.company.id, { kind: "company", meta: col.company });
      nodes.push(`
        <g class="map-node co" data-kind="company" data-id="${escapeHtml(col.company.id)}" transform="translate(${col.cx}, ${coY})">
          <title>${escapeHtml(col.company.name)} · ${escapeHtml(col.company.code || "")}</title>
          <rect x="${-col.blockW / 2}" y="${-CO_H / 2}" width="${col.blockW}" height="${CO_H}" rx="12" />
          <text class="t-main" y="1">${escapeHtml(col.label)}</text>
          <text class="t-sub" y="16">${col.people.length} თანამეწილე</text>
        </g>`);

      // company to people bus
      const localTop = peopleTop;
      lines.push(`<path d="M${col.cx} ${coY + CO_H / 2} V${localTop - 8}" class="map-link c1" />`);

      col.shown.forEach((p, i) => {
        hits.set(p.id, { kind: "person", meta: p });
        const colIdx = i % col.cols;
        const rowIdx = Math.floor(i / col.cols);
        const stackW = col.cols * col.personW + (col.cols - 1) * 10;
        const left = col.cx - stackW / 2;
        const px = left + colIdx * (col.personW + 10) + col.personW / 2;
        const py = localTop + PERSON_H / 2 + rowIdx * (PERSON_H + PERSON_GAP);
        if (rowIdx === 0) {
          lines.push(`<path d="M${col.cx} ${localTop - 8} H${px} V${py - PERSON_H / 2}" class="map-link c1" />`);
        } else {
          lines.push(`<path d="M${px} ${py - PERSON_H / 2 - PERSON_GAP} V${py - PERSON_H / 2}" class="map-link c1 soft" />`);
        }
        const pname = shorten(p.name, 16);
        nodes.push(`
          <g class="map-node c1" data-kind="person" data-id="${escapeHtml(p.id)}" transform="translate(${px}, ${py})">
            <title>${escapeHtml(p.name)} · ${escapeHtml(p.personalId || "")}</title>
            <rect x="${-col.personW / 2}" y="${-PERSON_H / 2}" width="${col.personW}" height="${PERSON_H}" rx="10" />
            <text class="t-main" y="1">${escapeHtml(pname)}</text>
            <text class="t-sub" y="13">${escapeHtml(p.personalId || "—")}</text>
          </g>`);
      });

      if (col.truncated) {
        const ty = localTop + col.rows * (PERSON_H + PERSON_GAP) + 4;
        nodes.push(`<text class="map-more" x="${col.cx}" y="${ty}">+${col.people.length - col.shown.length} სიაში</text>`);
      }
    }

    let height = c1Bottom + 40;
    let c2Note = "";

    if (showC2) {
      const flatC2 = [];
      for (const g of c2Groups) {
        for (const p of g.people) {
          flatC2.push({ person: p, company: g.company });
        }
      }
      const truncated = flatC2.length > MAX_C2_SHOW;
      const shownC2 = truncated ? flatC2.slice(0, MAX_C2_SHOW) : flatC2;
      const c2Cols = Math.min(4, Math.max(2, Math.ceil(Math.sqrt(shownC2.length || 1))));
      const c2PersonW = 140;
      const c2GapX = 14;
      const c2GapY = 10;
      const c2Rows = Math.ceil((shownC2.length || 1) / c2Cols);
      const c2BlockW = c2Cols * c2PersonW + (c2Cols - 1) * c2GapX;
      const c2StartY = c1Bottom + 70;
      const c2OriginX = width / 2 - c2BlockW / 2;

      nodes.push(`<text class="map-section" x="${width / 2}" y="${c1Bottom + 36}">წრე II · ${flatC2.length}</text>`);
      lines.push(`<path d="M${width / 2} ${c1Bottom + 8} V${c1Bottom + 24}" class="map-link c2" />`);

      shownC2.forEach((item, i) => {
        const c = i % c2Cols;
        const r = Math.floor(i / c2Cols);
        const px = c2OriginX + c * (c2PersonW + c2GapX) + c2PersonW / 2;
        const py = c2StartY + PERSON_H / 2 + r * (PERSON_H + c2GapY);
        hits.set(`${item.person.id}|c2`, { kind: "person", meta: item.person });
        hits.set(item.person.id, { kind: "person", meta: item.person });
        nodes.push(`
          <g class="map-node c2" data-kind="person" data-id="${escapeHtml(item.person.id)}" transform="translate(${px}, ${py})">
            <title>${escapeHtml(item.person.name)} · ${escapeHtml(item.company.name)}</title>
            <rect x="${-c2PersonW / 2}" y="${-PERSON_H / 2}" width="${c2PersonW}" height="${PERSON_H}" rx="10" />
            <text class="t-main" y="1">${escapeHtml(shorten(item.person.name, 15))}</text>
            <text class="t-sub" y="13">${escapeHtml(shorten(item.company.name, 16))}</text>
          </g>`);
      });

      height = c2StartY + c2Rows * (PERSON_H + c2GapY) + 36;
      if (truncated) {
        c2Note = `რუკაზე მე-2 წრიდან ${MAX_C2_SHOW} პირი ჩანს; სრულ სიაში — ყველა (${flatC2.length}).`;
      }
    }

    els.graphView.innerHTML = `
      <svg class="hierarchy-map" viewBox="0 0 ${Math.ceil(width)} ${Math.ceil(height)}" width="${Math.ceil(width)}" height="${Math.ceil(height)}" role="img" aria-label="კავშირების რუკა">
        <g class="map-lines">${lines.join("")}</g>
        <g class="map-nodes">${nodes.join("")}</g>
      </svg>
    `;

    els.graphView.querySelectorAll(".map-node").forEach((el) => {
      el.addEventListener("click", () => {
        els.graphView.querySelectorAll(".map-node.is-active").forEach((n) => n.classList.remove("is-active"));
        el.classList.add("is-active");
        const hit = hits.get(el.dataset.id);
        if (!hit) return;
        showDetail(hit.kind, hit.meta);
      });
    });

    els.graphNote.classList.toggle("hidden", !c2Note);
    els.graphNote.textContent = c2Note;
  }

  function drawList() {
    const data = state.networkData;
    const rows = [];
    for (const l of data.links) {
      if (l.circle === 2 && !state.circles.has(2)) continue;
      const personId = l.from.startsWith("co:") ? l.to : l.from;
      const companyId = l.from.startsWith("co:") ? l.from : l.to;
      const person = data.people[personId];
      const company = data.companies[companyId];
      if (!person || person.circle === 0 || !company) continue;
      if (person.circle === 2 && !state.circles.has(2)) continue;
      rows.push({ person, company, circle: person.circle });
    }

    const uniq = new Map();
    for (const r of rows) {
      const k = `${r.person.id}|${r.company.id}`;
      if (!uniq.has(k)) uniq.set(k, r);
    }
    const list = [...uniq.values()].sort(
      (a, b) => a.circle - b.circle || a.person.name.localeCompare(b.person.name, "ka")
    );

    const c1 = list.filter((r) => r.circle === 1);
    const c2 = list.filter((r) => r.circle === 2);
    els.listHint.textContent = state.circles.has(2)
      ? `${c1.length} თანამეწილე · ${c2.length} მე-2 წრის ჩანაწერი`
      : `${c1.length} თანამეწილე`;

    if (!list.length) {
      els.connectionList.innerHTML = `<p class="empty-state">კავშირები ვერ მოიძებნა</p>`;
      return;
    }

    const blocks = [];
    const flat = [];
    const pushSection = (title, items) => {
      if (!items.length) return;
      blocks.push(`<p class="section-title">${escapeHtml(title)}</p>`);
      for (const r of items) {
        const i = flat.length;
        flat.push(r);
        blocks.push(`<div class="conn-row" data-i="${i}">
          <span class="dot c${r.circle}"></span>
          <div>
            <p class="title">${escapeHtml(r.person.name)}</p>
            <p class="sub">${escapeHtml(r.person.personalId || "პირადი ნომერი —")}<br>${escapeHtml(r.company.name)}${r.company.code ? " · " + escapeHtml(r.company.code) : ""}</p>
          </div>
        </div>`);
      }
    };

    pushSection(`თანამეწილეები · წრე I (${c1.length})`, c1);
    if (state.circles.has(2)) {
      pushSection(`მათი სხვა კომპანიების მეწილეები · წრე II (${c2.length})`, c2);
    }

    els.connectionList.innerHTML = blocks.join("");
    els.connectionList.querySelectorAll(".conn-row").forEach((row) => {
      row.addEventListener("click", () => {
        els.connectionList.querySelectorAll(".conn-row").forEach((r) => r.classList.remove("is-active"));
        row.classList.add("is-active");
        showDetail("person", flat[Number(row.dataset.i)].person);
      });
    });
  }

  function refreshViews() {
    if (!state.networkData) return;

    els.board.classList.remove("mode-list", "mode-graph", "mode-split");
    els.board.classList.add(`mode-${state.view}`);
    els.board.classList.toggle("depth-2", state.circles.has(2));

    if (state.view === "list") {
      drawList();
    } else if (state.view === "graph") {
      drawGraph();
    } else {
      drawList();
      drawGraph();
    }
  }

  els.searchInput.addEventListener("input", onSearchInput);
  els.searchInput.addEventListener("keydown", (e) => {
    if (e.key === "Enter" && state.results[0]) {
      e.preventDefault();
      selectPerson(state.results[0]);
    }
  });
  els.clearBtn.addEventListener("click", () => {
    els.searchInput.value = "";
    els.clearBtn.classList.add("hidden");
    state.results = [];
    renderResults([]);
    setStatus("");
    els.searchInput.focus();
  });
  els.results.addEventListener("click", (e) => {
    const btn = e.target.closest("[data-idx]");
    if (!btn) return;
    const person = state.results[Number(btn.dataset.idx)];
    if (person) selectPerson(person);
  });

  document.querySelectorAll("#circleFilter button").forEach((btn) => {
    btn.addEventListener("click", async () => {
      document.querySelectorAll("#circleFilter button").forEach((b) => b.classList.remove("is-active"));
      btn.classList.add("is-active");
      const next = new Set(btn.dataset.circles.split(",").map(Number));
      const needRefetch = next.has(2) && !state.circles.has(2) && state.selected;
      state.circles = next;
      if (needRefetch) await selectPerson(state.selected);
      else refreshViews();
    });
  });

  document.querySelectorAll("[data-view]").forEach((btn) => {
    btn.addEventListener("click", () => {
      document.querySelectorAll("[data-view]").forEach((b) => b.classList.remove("is-active"));
      btn.classList.add("is-active");
      state.view = btn.dataset.view;
      refreshViews();
    });
  });

  setTimeout(() => els.searchInput.focus(), 80);
})();
