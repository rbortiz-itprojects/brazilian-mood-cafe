// ============================================================
// Fill these in with your Supabase project values
// (Project Settings > API in the Supabase dashboard)
// ============================================================
const SUPABASE_URL = "https://ahgblhxyrcefbitvqdnz.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFoZ2JsaHh5cmNlZmJpdHZxZG56Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY2MjEzOTAsImV4cCI6MjEwMjE5NzM5MH0.WlGFrHxOp1JT4LKEIrfmrMxq7SU2JJIuv9ieuuef90E";

const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
