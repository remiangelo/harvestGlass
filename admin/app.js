import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const listEl = document.getElementById("list");
const statusEl = document.getElementById("status");
const bannerEl = document.getElementById("banner");
const toggleBtn = document.getElementById("toggle");
const refreshBtn = document.getElementById("refresh");

const cfg = window.HARVEST_ADMIN_CONFIG;
let showAll = false;

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
    btn.addEventListener("click", () => onAction(btn.dataset.action, btn.dataset.id, btn.dataset.reported));
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

  const actions = reviewed
    ? ""
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
          ${r.description ? `<div class="desc">“${escape(r.description)}”</div>` : ""}
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

async function onAction(action, reportId, reportedId) {
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
    }
    await load();
  } catch (e) {
    alert("Action failed: " + (e.message || e));
  }
}

toggleBtn.addEventListener("click", () => {
  showAll = !showAll;
  toggleBtn.textContent = showAll ? "Show pending" : "Show all";
  load();
});
refreshBtn.addEventListener("click", load);

load();
