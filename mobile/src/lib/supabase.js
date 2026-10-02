import { createClient } from "@supabase/supabase-js";

const url = process.env.EXPO_PUBLIC_SUPABASE_URL || "";
const anon = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY || "";

export const supabase = createClient(url, anon);

export async function reportSighting({ tagId, lat, lng, rssi, battery, status }) {
  const { error } = await supabase.from("sightings").insert({
    tag_id: tagId,
    lat,
    lng,
    rssi,
    battery,
    status,
  });
  if (error) {
    throw error;
  }
}
