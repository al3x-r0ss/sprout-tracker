# 🌱 Sprout — Personal Growth Tracker

A purple-themed personal finance tracker with a light mode (default) and dark
mode toggle. Log savings/investment/income entries, watch a growth chart
build over time, watch a little plant grow in its pot as your balance
climbs, keep a daily logging streak going, and set goals with progress bars.
Single static site — no build step — backed by Supabase for storage and auth.

**Files that must all be uploaded together** (they reference each other):
`index.html`, `manifest.json`, `favicon.ico`, `logo-192.png`, `logo-512.png`,
`apple-touch-icon.png`, `supabase-schema.sql`, `README.md`, `.gitignore`.
The logo/icon files are what make the app's icon show up correctly when
someone bookmarks it or adds it to a phone home screen.

---

## 1. Create your Supabase project

1. Go to [supabase.com](https://supabase.com) → **New Project**.
2. Pick a name, password (for the DB), and region. Wait ~2 min for it to spin up.
3. In the left sidebar go to **SQL Editor** → **New query**.
4. Open `supabase-schema.sql` from this folder, paste its full contents in, and click **Run**.
   This creates the `entries` and `goals` tables and locks them down with
   Row Level Security so each account only ever sees its own data.
5. Go to **Authentication → Providers** and make sure **Email** is enabled (it is by default).
   - Optional: under **Authentication → Settings**, turn off "Confirm email" if you want
     to sign in immediately after signing up without checking your inbox (fine for personal use).
6. Go to **Project Settings → API**. You'll need two values from this page:
   - **Project URL**
   - **anon public** key

---

## 2. Connect the app to Supabase

Open `index.html` and find this block near the bottom:

```js
const SUPABASE_URL = 'YOUR_SUPABASE_URL';
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
```

Replace both values with the ones from Project Settings → API, then save.

> **Is it safe to put the anon key in client code?** Yes — it's designed to be
> public. Your data stays private because of the Row Level Security policies
> you just created in step 1, which restrict every row to its owning user.

---

## 3. Push to GitHub

From this project folder:

```bash
git init
git add .
git commit -m "Initial commit — Sprout growth tracker"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/sprout-tracker.git
git push -u origin main
```

(Create the empty repo on GitHub first at github.com/new, don't initialize it
with a README so the push above doesn't conflict.)

---

## 4. Deploy to Vercel

1. Go to [vercel.com](https://vercel.com) → **Add New → Project**.
2. Import the GitHub repo you just pushed.
3. Framework preset: choose **Other** (it's a static site — no build command needed).
4. Leave build/output settings blank and click **Deploy**.
5. Vercel gives you a live URL (e.g. `sprout-tracker.vercel.app`) — that's your app.

Because the Supabase keys are already baked into `index.html`, there's nothing
else to configure on Vercel's side. Every future `git push` to `main` will
auto-redeploy.

---

## 5. Create your account

Visit your Vercel URL, click **Create an account**, sign up with your email +
a password, and start logging entries. Since this is for personal use, you're
the only one who'll ever sign up — but if "Confirm email" is on in Supabase,
check your inbox for the confirmation link first.

---

## How the gamification works

- **Level** = `floor(total balance / $500) + 1`. Every $500 of net growth is a level.
- **Badges**: 🌱 Lvl 1-4 → 🥉 Lvl 5-9 → 🥈 Lvl 10-19 → 🥇 (kept simple, tweak
  `badgeForLevel()` in `index.html` to change thresholds or emoji).
- **Goals** track progress against your *total* balance, not a separate pot —
  simple to reason about for a personal tracker with one running balance.

## Friends & leaderboard

You can add friends by email and see a leaderboard of Level, badge, and
streak — but **never** anyone's dollar amounts, entries, or goal names.
Only goal *completion percentage* is shared, never targets or balances.

**To enable this, run the SQL again:** open `supabase-schema.sql`, copy the
whole file (it now includes the new `profiles`, `friendships`, and
`public_stats` tables, a signup trigger, and a locked-down email lookup),
and run it in your Supabase SQL Editor — it's safe to re-run even though
you ran an earlier version before, since every statement uses
`if not exists` / `drop policy if exists` guards.

**On privacy:** emails are not browsable. Nobody can list or search other
users generally — adding a friend requires typing their *exact* email,
which is checked through a narrow database function that only ever
returns a yes/no + id, never a list. Once you send or receive a request,
that one other person's email becomes visible to you (needed to show it in
the UI); if you remove the friendship, that visibility goes away again.

## Customizing

Everything is in the single `index.html` file:
- Colors are CSS variables at the top of the `<style>` block (`--primary`, `--gold`, etc).
- Level thresholds: `levelFromTotal()` and `levelProgress()`.
- Categories: edit the `<select id="entryCategory">` options and the `CAT_LABELS` map together.

## Local preview before deploying

No build tools needed — just open `index.html` directly in a browser, or run:

```bash
python3 -m http.server 8000
```

and visit `http://localhost:8000`.
