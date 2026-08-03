import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const listEl = document.getElementById("list");
const statusEl = document.getElementById("status");
const bannerEl = document.getElementById("banner");
const toggleBtn = document.getElementById("toggle");
const refreshBtn = document.getElementById("refresh");
const roomsEl = document.getElementById("rooms");
const roomFormEl = document.getElementById("room-form");
const newRoomBtn = document.getElementById("new-room");
const pageTitleEl = document.getElementById("page-title");
const tabModBtn = document.getElementById("tab-moderation");
const tabRoomsBtn = document.getElementById("tab-rooms");

const cfg = window.HARVEST_ADMIN_CONFIG;
let showAll = false;
let activeTab = "moderation";
let roomsCache = [];
let openDetailId = null;
let detailMsgLimit = 100;

function fatal(msg) {
  bannerEl.style.display = "block";
  bannerEl.textContent = msg;
  statusEl.textContent = "";
}

if (!cfg || !cfg.SUPABASE_URL || cfg.SERVICE_ROLE_KEY === "REPLACE_ME" || !cfg.SERVICE_ROLE_KEY) {
  fatal("Missing configuration. Copy config.example.js to config.js and fill in your Supabase URL + service_role key.");
  throw new Error("missing config");
}

const supabase = createClient(cfg.SUPABASE_URL, cfg.SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const escape = (s) =>
  String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));

function fmtDate(iso) {
  if (!iso) return "";
  try { return new Date(iso).toLocaleString(); } catch { return iso; }
}

async function load() {
  statusEl.textContent = "Loading…";
  let query = supabase.from("moderation_queue").select("*").order("created_at", { ascending: false });
  if (!showAll) query = query.eq("status", "pending");

  const { data, error } = await query;
  if (error) {
    fatal("Query failed: " + error.message + " — did you run admin/schema.sql?");
    return;
  }
  render(data || []);
  const pending = (data || []).filter((r) => r.status === "pending").length;
  statusEl.textContent = showAll ? `${data.length} reports` : `${pending} pending`;
}

function render(rows) {
  if (!rows.length) {
    listEl.innerHTML = `<div class="empty">No ${showAll ? "" : "pending "}reports. 🎉</div>`;
    return;
  }
  listEl.innerHTML = rows.map(reportCard).join("");
  listEl.querySelectorAll("[data-action]").forEach((btn) => {
    btn.addEventListener("click", () =>
      onAction(btn.dataset.action, btn.dataset.id, btn.dataset.reported, {
        msgId: btn.dataset.msg,
        communityId: btn.dataset.community,
      }));
  });
}

function reportCard(r) {
  const photos = Array.isArray(r.reported_photos) ? r.reported_photos.filter(Boolean) : [];
  const photoHtml = photos.length
    ? `<div class="photos">${photos.slice(0, 3).map((u) => `<img src="${escape(u)}" alt="" />`).join("")}</div>`
    : `<div class="photos"><div class="no-photo">no photo</div></div>`;

  const reviewed = r.status !== "pending";
  const statusPill = reviewed
    ? `<span class="pill done">${escape(r.action_taken || "reviewed")}</span>`
    : "";
  const bannedPill = r.reported_is_banned ? `<span class="pill banned">banned</span>` : "";

  const isMessage = r.target_type === "community_message";
  const messageBlock = isMessage
    ? `<div class="desc">In <b>${escape(r.target_community_name || "a room")}</b>: "${escape(r.target_message_content || "(removed)")}"</div>`
    : "";

  const actions = reviewed
    ? ""
    : isMessage
    ? `<div class="actions">
         <button class="ghost" data-action="dismiss" data-id="${r.id}" data-reported="${escape(r.reported_id)}">Dismiss</button>
         <button data-action="remove-msg" data-id="${r.id}" data-msg="${escape(r.target_id)}">Remove message</button>
         <button data-action="ban-room" data-id="${r.id}" data-reported="${escape(r.reported_id)}" data-community="${escape(r.target_community_id)}">Ban from room</button>
         <button class="danger" data-action="ban" data-id="${r.id}" data-reported="${escape(r.reported_id)}">Ban &amp; eject user</button>
       </div>`
    : `<div class="actions">
         <button class="ghost" data-action="dismiss" data-id="${r.id}" data-reported="${escape(r.reported_id)}">Dismiss</button>
         <button data-action="remove" data-id="${r.id}" data-reported="${escape(r.reported_id)}">Remove content</button>
         <button class="danger" data-action="ban" data-id="${r.id}" data-reported="${escape(r.reported_id)}">Ban &amp; eject user</button>
       </div>`;

  return `
    <div class="report ${reviewed ? "reviewed" : ""}">
      <div class="report-top">
        ${photoHtml}
        <div class="meta">
          <div class="name">${escape(r.reported_nickname || r.reported_id)}
            <span class="pill reason">${escape(r.reason || "report")}</span>${bannedPill}${statusPill}
          </div>
          ${r.reported_bio ? `<div class="bio">${escape(r.reported_bio)}</div>` : ""}
          ${r.description ? `<div class="desc">"${escape(r.description)}"</div>` : ""}
          ${messageBlock}
          <div class="sub">Reported by ${escape(r.reporter_nickname || r.reporter_id || "unknown")} · ${fmtDate(r.created_at)}</div>
          ${actions}
        </div>
      </div>
    </div>`;
}

async function markReviewed(reportId, action) {
  return supabase
    .from("user_reports")
    .update({ status: "reviewed", action_taken: action, reviewed_at: new Date().toISOString() })
    .eq("id", reportId);
}

async function onAction(action, reportId, reportedId, extra = {}) {
  try {
    if (action === "dismiss") {
      await markReviewed(reportId, "dismissed");
    } else if (action === "remove") {
      if (!confirm("Remove this user's bio and photos?")) return;
      const { error } = await supabase.from("users").update({ bio: null, photos: [] }).eq("id", reportedId);
      if (error) throw error;
      await markReviewed(reportId, "content_removed");
    } else if (action === "ban") {
      if (!confirm("Ban and eject this user? They'll be signed out and removed from the app.")) return;
      let { error } = await supabase.from("users").update({ is_banned: true }).eq("id", reportedId);
      if (error) throw error;
      // Deactivate all of their matches so they vanish from others' inboxes immediately.
      await supabase
        .from("matches")
        .update({ is_active: false, unmatched_at: new Date().toISOString() })
        .or(`user1_id.eq.${reportedId},user2_id.eq.${reportedId}`);
      await markReviewed(reportId, "banned");
    } else if (action === "remove-msg") {
      if (!confirm("Remove this message for everyone?")) return;
      const { error } = await supabase
        .from("community_messages")
        .update({ is_removed: true, removed_at: new Date().toISOString() })
        .eq("id", extra.msgId);
      if (error) throw error;
      await markReviewed(reportId, "content_removed");
    } else if (action === "ban-room") {
      if (!confirm("Ban this user from this room?")) return;
      const { error } = await supabase
        .from("community_members")
        .update({ status: "banned" })
        .eq("community_id", extra.communityId)
        .eq("user_id", reportedId);
      if (error) throw error;
      await markReviewed(reportId, "content_removed");
    }
    await load();
  } catch (e) {
    alert("Action failed: " + (e.message || e));
  }
}

async function loadRooms() {
  statusEl.textContent = "Loading rooms…";
  const { data, error } = await supabase
    .from("communities")
    .select("*")
    .order("display_order", { ascending: true });
  if (error) {
    fatal("Rooms query failed: " + error.message);
    return;
  }
  roomsCache = data || [];
  roomsEl.innerHTML = roomsCache.map(roomCard).join("") ||
    `<div class="empty">No rooms yet. Create one!</div>`;
  roomsEl.querySelectorAll("[data-raction]").forEach((btn) => {
    btn.addEventListener("click", () => onRoomAction(btn.dataset.raction, btn.dataset.id));
  });
  statusEl.textContent = `${roomsCache.length} rooms`;
  openDetailId = null;
}

function roomCard(c) {
  const thumb = c.image_url
    ? `<img class="room-thumb" src="${escape(c.image_url)}" alt="" />`
    : `<div class="no-thumb">🌱</div>`;
  return `
    <div class="room ${c.is_active ? "" : "inactive"}" id="room-${c.id}">
      <div class="room-top">
        ${thumb}
        <div class="meta">
          <div class="name">${escape(c.name)}
            <span class="pill kind">${escape(c.kind)}</span>
            ${c.is_active ? "" : `<span class="pill off">inactive</span>`}
          </div>
          <div class="sub">/${escape(c.slug)} · ${c.member_count ?? 0} members · order ${c.display_order ?? 0}</div>
          ${criteriaSummary(c.criteria)}
          ${c.description ? `<div class="desc">${escape(c.description)}</div>` : ""}
          <div class="actions">
            <button class="ghost" data-raction="detail" data-id="${c.id}">Members &amp; chat</button>
            <button data-raction="edit" data-id="${c.id}">Edit</button>
            <button data-raction="toggle-active" data-id="${c.id}">${c.is_active ? "Deactivate" : "Activate"}</button>
            <button class="danger" data-raction="delete" data-id="${c.id}">Delete</button>
          </div>
        </div>
      </div>
      <div class="room-detail" id="detail-${c.id}"></div>
    </div>`;
}

/// One line describing a room's restrictions, so it's obvious from the list
/// which rooms are gated and why.
function criteriaSummary(criteria) {
  if (!criteria || typeof criteria !== "object") return "";
  const bits = [];

  if (criteria.age) {
    bits.push(`age ${criteria.age.min ?? "any"}–${criteria.age.max ?? "any"}`);
  }
  if (criteria.height_cm) {
    bits.push(`height ${criteria.height_cm.min ?? "any"}–${criteria.height_cm.max ?? "any"}cm`);
  }
  for (const key of Object.keys(CRITERIA_OPTIONS)) {
    const values = criteria[key];
    if (Array.isArray(values) && values.length) {
      bits.push(`${CRITERIA_LABELS[key].toLowerCase()}: ${values.join(", ")}`);
    }
  }
  if (criteria.location) {
    const where = criteria.location.label || `${criteria.location.lat}, ${criteria.location.lng}`;
    bits.push(`within ${criteria.location.radius_miles} mi of ${where}`);
  }

  if (!bits.length) return "";
  return `<div class="sub"><span class="pill kind">restricted</span> ${escape(bits.join(" · "))}</div>`;
}

function openRoomForm(room) {
  const c = room || {};
  roomFormEl.style.display = "";
  roomFormEl.innerHTML = `
    <div class="form-card">
      <div class="grid">
        <div><label>Name</label><input id="rf-name" value="${escape(c.name || "")}" /></div>
        <div><label>Slug</label><input id="rf-slug" value="${escape(c.slug || "")}" placeholder="auto from name" /></div>
        <div><label>Kind</label>
          <select id="rf-kind">
            ${["everyone", "seeking_connection", "relationship_stage", "peer"]
              .map((k) => `<option value="${k}" ${c.kind === k ? "selected" : ""}>${k}</option>`).join("")}
          </select>
        </div>
        <div><label>Display order</label><input id="rf-order" type="number" value="${c.display_order ?? 0}" /></div>
        <textarea id="rf-desc" placeholder="Description">${escape(c.description || "")}</textarea>
        <div><label>Banner image</label><input id="rf-image" type="file" accept="image/*" /></div>
        ${criteriaFieldset(c.criteria || {})}
        <div style="align-self:end; display:flex; gap:8px; justify-content:flex-end;">
          <button class="ghost" id="rf-cancel">Cancel</button>
          <button class="green" id="rf-save">${c.id ? "Save changes" : "Create room"}</button>
        </div>
      </div>
    </div>`;
  document.getElementById("rf-cancel").addEventListener("click", () => {
    roomFormEl.style.display = "none";
  });
  document.getElementById("rf-save").addEventListener("click", () => saveRoom(c.id || null, c.image_url || null));
  document.getElementById("rf-geocode").addEventListener("click", geocodeRoomLocation);
  roomFormEl.scrollIntoView({ behavior: "smooth" });
}

// ---------------------------------------------------------------------------
// Room access criteria
//
// Written to communities.criteria (jsonb). Absent key = no constraint. The
// gating itself lives in available_communities() — nothing here is enforced
// client-side, and the iOS app needs no change to respect it.
// ---------------------------------------------------------------------------

const CRITERIA_OPTIONS = {
  gender: ["male", "female", "non-binary"],
  relationship_status: ["single", "dating", "in a relationship", "married"],
  looking_for: ["Dating", "Relationship", "Long-term Commitment", "Marriage"],
  faith: ["Christianity", "Islam", "Judaism", "Buddhism", "Hinduism", "Spiritual", "Agnostic", "Atheist", "Other"],
  children_status: ["Want someday", "Don't want", "Have & want more", "Have & don't want more", "Not sure", "Prefer not to say"],
  smoking: ["Never", "Sometimes", "Often", "Prefer not to say"],
  drinking: ["Never", "Socially", "Often", "Prefer not to say"],
  cannabis: ["Never", "Sometimes", "Often", "Prefer not to say"],
};

const CRITERIA_LABELS = {
  gender: "Gender",
  relationship_status: "Relationship status",
  looking_for: "Looking for",
  faith: "Faith",
  children_status: "Children",
  smoking: "Smoking",
  drinking: "Drinking",
  cannabis: "Cannabis",
};

function multiSelect(key, selected) {
  const chosen = Array.isArray(selected) ? selected.map(String) : [];
  const opts = CRITERIA_OPTIONS[key]
    .map((v) => `<option value="${escape(v)}" ${chosen.includes(v) ? "selected" : ""}>${escape(v)}</option>`)
    .join("");
  return `
    <div>
      <label>${CRITERIA_LABELS[key]}</label>
      <select id="rf-c-${key}" multiple size="4">${opts}</select>
    </div>`;
}

function criteriaFieldset(criteria) {
  const loc = criteria.location || {};
  const age = criteria.age || {};
  const height = criteria.height_cm || {};
  const isRestricted = Object.keys(criteria).length > 0;

  return `
    <details id="rf-criteria" ${isRestricted ? "open" : ""} style="grid-column:1/-1;">
      <summary style="cursor:pointer; margin:8px 0;">
        <strong>Restrictions</strong>
        <span class="muted"> — leave empty for a room everyone can see</span>
      </summary>
      <div class="form-card" style="margin-top:8px;">
        <p class="muted" style="margin-top:0;">
          All set restrictions must be met. A member whose profile leaves a
          restricted field blank does <strong>not</strong> qualify. Existing
          members keep access regardless.
        </p>
        <div class="grid">
          <div><label>Min age</label><input id="rf-c-age-min" type="number" min="18" max="99" value="${age.min ?? ""}" /></div>
          <div><label>Max age</label><input id="rf-c-age-max" type="number" min="18" max="99" value="${age.max ?? ""}" /></div>
          <div><label>Min height (cm)</label><input id="rf-c-h-min" type="number" value="${height.min ?? ""}" /></div>
          <div><label>Max height (cm)</label><input id="rf-c-h-max" type="number" value="${height.max ?? ""}" /></div>
          ${Object.keys(CRITERIA_OPTIONS).map((k) => multiSelect(k, criteria[k])).join("")}
        </div>
        <hr />
        <div class="grid">
          <div style="grid-column:1/-1;">
            <label>Location</label>
            <input id="rf-c-loc-label" value="${escape(loc.label || "")}" placeholder="e.g. Washington, DC" />
          </div>
          <div><label>Radius (miles)</label><input id="rf-c-loc-radius" type="number" min="1" value="${loc.radius_miles ?? ""}" /></div>
          <div><label>Latitude</label><input id="rf-c-loc-lat" value="${loc.lat ?? ""}" readonly /></div>
          <div><label>Longitude</label><input id="rf-c-loc-lng" value="${loc.lng ?? ""}" readonly /></div>
          <div style="align-self:end;"><button class="ghost" id="rf-geocode" type="button">Look up place</button></div>
          <div id="rf-geocode-status" class="muted" style="grid-column:1/-1;"></div>
        </div>
      </div>
    </details>`;
}

/// Resolves the typed place via OpenStreetMap Nominatim and shows what it
/// found. Coordinates are never guessed silently — the lat/lng inputs are
/// read-only and only this button fills them.
async function geocodeRoomLocation() {
  const query = document.getElementById("rf-c-loc-label").value.trim();
  const status = document.getElementById("rf-geocode-status");
  if (!query) {
    status.textContent = "Type a place first.";
    return;
  }
  status.textContent = "Looking up…";
  try {
    const url =
      "https://nominatim.openstreetmap.org/search?format=json&limit=1&q=" +
      encodeURIComponent(query);
    const res = await fetch(url, { headers: { Accept: "application/json" } });
    if (!res.ok) throw new Error("lookup failed (" + res.status + ")");
    const hits = await res.json();
    if (!hits.length) {
      status.textContent = `No match for "${query}". Try a more specific place.`;
      return;
    }
    document.getElementById("rf-c-loc-lat").value = Number(hits[0].lat).toFixed(6);
    document.getElementById("rf-c-loc-lng").value = Number(hits[0].lon).toFixed(6);
    status.textContent = `Resolved to: ${hits[0].display_name}`;
  } catch (e) {
    status.textContent = "Lookup failed: " + (e.message || e);
  }
}

const selectedValues = (id) =>
  Array.from(document.getElementById(id).selectedOptions).map((o) => o.value);

const numOrNull = (id) => {
  const raw = document.getElementById(id).value.trim();
  if (raw === "") return null;
  const n = Number(raw);
  return Number.isFinite(n) ? n : null;
};

/// Builds the criteria object, omitting anything left empty so an
/// unrestricted room stores exactly {}.
function collectCriteria() {
  const criteria = {};

  for (const key of Object.keys(CRITERIA_OPTIONS)) {
    const values = selectedValues(`rf-c-${key}`);
    if (values.length) criteria[key] = values;
  }

  const range = (minId, maxId) => {
    const min = numOrNull(minId);
    const max = numOrNull(maxId);
    if (min === null && max === null) return null;
    const out = {};
    if (min !== null) out.min = min;
    if (max !== null) out.max = max;
    return out;
  };

  const age = range("rf-c-age-min", "rf-c-age-max");
  if (age) criteria.age = age;
  const height = range("rf-c-h-min", "rf-c-h-max");
  if (height) criteria.height_cm = height;

  const lat = numOrNull("rf-c-loc-lat");
  const lng = numOrNull("rf-c-loc-lng");
  const radius = numOrNull("rf-c-loc-radius");
  if (lat !== null && lng !== null && radius !== null) {
    criteria.location = {
      lat,
      lng,
      radius_miles: radius,
      label: document.getElementById("rf-c-loc-label").value.trim(),
    };
  }

  return criteria;
}

const slugify = (s) =>
  s.toLowerCase().trim().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");

async function saveRoom(id, existingImageUrl) {
  const name = document.getElementById("rf-name").value.trim();
  if (!name) return alert("Name is required.");
  const slug = document.getElementById("rf-slug").value.trim() || slugify(name);
  const row = {
    name,
    slug,
    kind: document.getElementById("rf-kind").value,
    display_order: parseInt(document.getElementById("rf-order").value, 10) || 0,
    description: document.getElementById("rf-desc").value.trim() || null,
    image_url: existingImageUrl,
    criteria: collectCriteria(),
  };

  // A half-filled location is a mistake worth catching: without coordinates
  // the restriction silently does nothing.
  const locLabel = document.getElementById("rf-c-loc-label").value.trim();
  const locRadius = document.getElementById("rf-c-loc-radius").value.trim();
  if ((locLabel || locRadius) && !row.criteria.location) {
    return alert(
      'Location restriction incomplete. Enter a place, press "Look up place" to resolve coordinates, and set a radius — or clear all three.'
    );
  }

  try {
    const file = document.getElementById("rf-image").files[0];
    if (file) {
      const ext = (file.name.split(".").pop() || "jpg").toLowerCase();
      const path = `${slug}-${Date.now()}.${ext}`;
      const { error: upErr } = await supabase.storage
        .from("community-images")
        .upload(path, file, { upsert: true });
      if (upErr) throw upErr;
      row.image_url = supabase.storage.from("community-images").getPublicUrl(path).data.publicUrl;
    }

    const { error } = id
      ? await supabase.from("communities").update(row).eq("id", id)
      : await supabase.from("communities").insert({ ...row, is_active: true });
    if (error) throw error;

    roomFormEl.style.display = "none";
    await loadRooms();
  } catch (e) {
    fatal("Save failed: " + (e.message || e));
  }
}

async function onRoomAction(action, id) {
  const room = roomsCache.find((c) => c.id === id);
  if (!room) return;
  try {
    if (action === "edit") {
      openRoomForm(room);
    } else if (action === "toggle-active") {
      const { error } = await supabase
        .from("communities")
        .update({ is_active: !room.is_active })
        .eq("id", id);
      if (error) throw error;
      await loadRooms();
    } else if (action === "delete") {
      if (!confirm(
        `PERMANENTLY delete "${room.name}"?\n\nThis removes the room, ALL its messages, reactions, and memberships. ` +
        `Prefer Deactivate to hide it without losing history.`
      )) return;
      // Explicit ordered deletes — don't rely on FK cascade config.
      // Each is error-checked: a failed child delete must abort the parent
      // delete, not silently orphan rows.
      for (const table of [
        "community_message_reactions",
        "community_messages",
        "community_members",
        "community_prompts",
      ]) {
        const { error: childErr } = await supabase.from(table).delete().eq("community_id", id);
        if (childErr) throw childErr;
      }
      const { error } = await supabase.from("communities").delete().eq("id", id);
      if (error) throw error;
      await loadRooms();
    } else if (action === "detail") {
      await toggleRoomDetail(id);
    }
  } catch (e) {
    alert("Action failed: " + (e.message || e));
  }
}

async function toggleRoomDetail(id) {
  const panel = document.getElementById(`detail-${id}`);
  if (openDetailId === id) {
    panel.classList.remove("open");
    openDetailId = null;
    return;
  }
  document.querySelectorAll(".room-detail.open").forEach((p) => p.classList.remove("open"));
  openDetailId = id;
  detailMsgLimit = 100;
  await renderRoomDetail(id);
}

async function renderRoomDetail(id) {
  const panel = document.getElementById(`detail-${id}`);
  panel.classList.add("open");
  panel.innerHTML = `<div class="panel">Loading…</div>`;

  const [membersRes, msgsRes] = await Promise.all([
    supabase
      .from("community_members")
      .select("user_id, role, status, joined_at, users!user_id(nickname)")
      .eq("community_id", id)
      .order("joined_at", { ascending: true }),
    supabase
      .from("community_messages")
      .select("id, sender_id, content, is_removed, created_at, users!sender_id(nickname)")
      .eq("community_id", id)
      .order("created_at", { ascending: false })
      .limit(detailMsgLimit),
  ]);

  if (membersRes.error || msgsRes.error) {
    panel.innerHTML = `<div class="panel">Load failed: ${escape((membersRes.error || msgsRes.error).message)}</div>`;
    return;
  }

  const members = membersRes.data || [];
  const msgs = msgsRes.data || [];

  panel.innerHTML = `
    <div class="panel">
      <h3>Members (${members.length})</h3>
      ${members.map((m) => memberRow(id, m)).join("") || `<div class="sub">Nobody here yet.</div>`}
    </div>
    <div class="panel">
      <h3>Latest messages</h3>
      ${msgs.map((m) => messageRow(id, m)).join("") || `<div class="sub">No messages yet.</div>`}
      ${msgs.length >= detailMsgLimit
        ? `<div class="actions"><button class="ghost" data-daction="older" data-room="${id}">Load older</button></div>`
        : ""}
    </div>`;

  panel.querySelectorAll("[data-daction]").forEach((btn) => {
    btn.addEventListener("click", () =>
      onDetailAction(btn.dataset.daction, btn.dataset.room, btn.dataset.user, btn.dataset.msg));
  });
}

function memberRow(roomId, m) {
  const nick = escape(m.users?.nickname || m.user_id);
  const rolePill = m.role === "moderator" ? `<span class="pill mod">mod</span>` : "";
  const statusPill = m.status === "banned" ? `<span class="pill room-banned">banned</span>`
    : m.status === "left" ? `<span class="pill off">left</span>` : "";
  const actions =
    m.status === "banned"
      ? `<button data-daction="unban" data-room="${roomId}" data-user="${m.user_id}">Unban</button>`
      : `<button data-daction="ban" data-room="${roomId}" data-user="${m.user_id}">Ban</button>` +
        (m.role === "moderator"
          ? `<button class="ghost" data-daction="demote" data-room="${roomId}" data-user="${m.user_id}">Demote</button>`
          : `<button class="ghost" data-daction="promote" data-room="${roomId}" data-user="${m.user_id}">Make mod</button>`);
  return `
    <div class="mrow">
      <span class="who">${nick}${rolePill}${statusPill}</span>
      <span class="when">${fmtDate(m.joined_at)}</span>
      ${actions}
    </div>`;
}

function messageRow(roomId, m) {
  const nick = escape(m.users?.nickname || m.sender_id);
  return `
    <div class="mrow">
      <span class="who">${nick}</span>
      <span class="when">${fmtDate(m.created_at)}</span>
      ${m.is_removed
        ? `<button data-daction="restore" data-room="${roomId}" data-msg="${m.id}">Restore</button>`
        : `<button data-daction="remove" data-room="${roomId}" data-msg="${m.id}">Remove</button>
           <button class="danger" data-daction="ban" data-room="${roomId}" data-user="${m.sender_id}">Ban author</button>`}
      <span class="txt ${m.is_removed ? "removed" : ""}">${escape(m.content)}</span>
    </div>`;
}

async function onDetailAction(action, roomId, userId, msgId) {
  try {
    if (action === "older") {
      detailMsgLimit += 100;
    } else if (action === "ban") {
      if (!confirm("Ban this user from this room?")) return;
      const { error } = await supabase
        .from("community_members")
        .update({ status: "banned" })
        .eq("community_id", roomId)
        .eq("user_id", userId);
      if (error) throw error;
    } else if (action === "unban") {
      const { error } = await supabase
        .from("community_members")
        .update({ status: "active" })
        .eq("community_id", roomId)
        .eq("user_id", userId);
      if (error) throw error;
    } else if (action === "promote" || action === "demote") {
      const { error } = await supabase
        .from("community_members")
        .update({ role: action === "promote" ? "moderator" : "member" })
        .eq("community_id", roomId)
        .eq("user_id", userId);
      if (error) throw error;
    } else if (action === "remove") {
      if (!confirm("Remove this message for everyone?")) return;
      const { error } = await supabase
        .from("community_messages")
        .update({ is_removed: true, removed_at: new Date().toISOString() })
        .eq("id", msgId);
      if (error) throw error;
    } else if (action === "restore") {
      const { error } = await supabase
        .from("community_messages")
        .update({ is_removed: false, removed_at: null })
        .eq("id", msgId);
      if (error) throw error;
    }
    await renderRoomDetail(roomId);
  } catch (e) {
    alert("Action failed: " + (e.message || e));
  }
}

function switchTab(name) {
  activeTab = name;
  const rooms = name === "rooms";
  tabModBtn.classList.toggle("active", !rooms);
  tabRoomsBtn.classList.toggle("active", rooms);
  pageTitleEl.textContent = rooms ? "Rooms" : "Moderation";
  listEl.style.display = rooms ? "none" : "";
  roomsEl.style.display = rooms ? "" : "none";
  roomFormEl.style.display = "none";
  toggleBtn.style.display = rooms ? "none" : "";
  newRoomBtn.style.display = rooms ? "" : "none";
  rooms ? loadRooms() : load();
}

tabModBtn.addEventListener("click", () => switchTab("moderation"));
tabRoomsBtn.addEventListener("click", () => switchTab("rooms"));
newRoomBtn.addEventListener("click", () => openRoomForm(null));

toggleBtn.addEventListener("click", () => {
  showAll = !showAll;
  toggleBtn.textContent = showAll ? "Show pending" : "Show all";
  load();
});
refreshBtn.addEventListener("click", () => (activeTab === "rooms" ? loadRooms() : load()));

load();
