import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type SupabaseAdmin = ReturnType<typeof createClient>;

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

async function fetchIds(query: Promise<any>): Promise<string[]> {
  const result = await query;
  if (result.error) {
    throw new Error(result.error.message);
  }
  return (result.data ?? []).map((row) => row.id);
}

async function deleteMatching(
  admin: SupabaseAdmin,
  table: string,
  column: string,
  value: string,
) {
  const { error } = await admin.from(table).delete().eq(column, value);
  if (error) {
    throw new Error(`${table}: ${error.message}`);
  }
}

async function deleteMatchingAny(
  admin: SupabaseAdmin,
  table: string,
  filter: string,
) {
  const { error } = await admin.from(table).delete().or(filter);
  if (error) {
    throw new Error(`${table}: ${error.message}`);
  }
}

async function deleteIn(
  admin: SupabaseAdmin,
  table: string,
  column: string,
  values: string[],
) {
  if (values.length == 0) return;

  const { error } = await admin.from(table).delete().in(column, values);
  if (error) {
    throw new Error(`${table}: ${error.message}`);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, { success: false, message: "Method not allowed." });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const authHeader = req.headers.get("Authorization");

    if (!supabaseUrl || !supabaseAnonKey || !serviceRoleKey) {
      return jsonResponse(500, {
        success: false,
        message: "Supabase environment variables are missing for delete-account.",
      });
    }

    if (!authHeader) {
      return jsonResponse(401, { success: false, message: "Missing authorization header." });
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    });

    const admin = createClient(supabaseUrl, serviceRoleKey);

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) {
      return jsonResponse(401, { success: false, message: "Unauthorized." });
    }

    const userId = user.id;

    const matchIds = await fetchIds(
      admin
        .from("matches")
        .select("id")
        .or(`user1_id.eq.${userId},user2_id.eq.${userId}`),
    );

    const conversationIds = await fetchIds(
      admin
        .from("conversations")
        .select("id")
        .or(`user1_id.eq.${userId},user2_id.eq.${userId}`),
    );

    const messageIdsFromConversations = conversationIds.length > 0
      ? await fetchIds(
          admin
            .from("messages")
            .select("id")
            .in("conversation_id", conversationIds),
        )
      : [];

    const messageIdsFromSender = await fetchIds(
      admin
        .from("messages")
        .select("id")
        .eq("sender_id", userId),
    );

    const messageIds = Array.from(new Set([
      ...messageIdsFromConversations,
      ...messageIdsFromSender,
    ]));

    await deleteIn(admin, "message_reactions", "message_id", messageIds);
    await deleteMatching(admin, "message_reactions", "user_id", userId);

    await deleteIn(admin, "ready_to_move_checks", "conversation_id", conversationIds);
    await deleteIn(admin, "ready_to_move_checks", "match_id", matchIds);
    await deleteMatching(admin, "ready_to_move_checks", "user_id", userId);

    await deleteIn(admin, "red_flag_reports", "conversation_id", conversationIds);
    await deleteMatchingAny(
      admin,
      "red_flag_reports",
      `reporter_id.eq.${userId},reported_user_id.eq.${userId}`,
    );

    await deleteIn(admin, "safety_analyses", "conversation_id", conversationIds);
    await deleteIn(admin, "safety_analyses", "match_id", matchIds);
    await deleteMatching(admin, "safety_analyses", "user_id", userId);

    await deleteIn(admin, "match_scores", "match_id", matchIds);
    await deleteIn(admin, "messages", "conversation_id", conversationIds);
    await deleteMatching(admin, "messages", "sender_id", userId);

    await deleteIn(admin, "conversations", "id", conversationIds);
    await deleteIn(admin, "matches", "id", matchIds);

    await deleteMatching(admin, "gardener_chat_history", "user_id", userId);
    await deleteMatching(admin, "gardener_daily_quiz_tracking", "user_id", userId);
    await deleteMatching(admin, "gardener_interactions", "user_id", userId);
    await deleteMatching(admin, "gardener_quiz_responses", "user_id", userId);
    await deleteMatching(admin, "gardener_user_insights", "user_id", userId);
    await deleteMatching(admin, "growth_progress", "user_id", userId);
    await deleteMatching(admin, "photos", "user_id", userId);
    await deleteMatching(admin, "user_activities", "user_id", userId);
    await deleteMatching(admin, "user_hobbies", "user_id", userId);
    await deleteMatching(admin, "user_preferences", "user_id", userId);
    await deleteMatching(admin, "user_rewards", "user_id", userId);
    await deleteMatching(admin, "user_safety_settings", "user_id", userId);
    await deleteMatching(admin, "user_subscriptions", "user_id", userId);
    await deleteMatching(admin, "user_usage", "user_id", userId);
    await deleteMatching(admin, "user_values_brought", "user_id", userId);
    await deleteMatching(admin, "user_values_sought", "user_id", userId);

    await deleteMatchingAny(
      admin,
      "swipes",
      `swiper_id.eq.${userId},swiped_id.eq.${userId}`,
    );
    await deleteMatchingAny(
      admin,
      "user_blocks",
      `blocker_id.eq.${userId},blocked_id.eq.${userId}`,
    );
    await deleteMatchingAny(
      admin,
      "user_reports",
      `reporter_id.eq.${userId},reported_id.eq.${userId}`,
    );

    const { error: deleteUserRowError } = await admin
      .from("users")
      .delete()
      .eq("id", userId);

    if (deleteUserRowError) {
      throw new Error(`users: ${deleteUserRowError.message}`);
    }

    const { error: deleteAuthError } = await admin.auth.admin.deleteUser(userId);

    if (deleteAuthError) {
      throw new Error(`auth.users: ${deleteAuthError.message}`);
    }

    return jsonResponse(200, {
      success: true,
      message: "Account deleted successfully.",
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown deletion error.";
    return jsonResponse(500, {
      success: false,
      message,
    });
  }
});
