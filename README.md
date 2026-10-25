# Square Off

A two-player strategy game: place numbered tokens on a 4×4 grid, then move them in a strict order. First to make a square with four of their tokens wins.

Play against the computer, pass-and-play on one device, or play a friend online.

## Files

- `index.html`: the whole game (rules, computer opponent, online play).
- `schema.sql`: sets up the database for online play. Run it once in Supabase.

## Setup for online play

1. **Supabase project:** create a free project at supabase.com.
2. **Anonymous sign-ins:** Authentication → Sign In / Providers → turn on **Allow anonymous sign-ins** → Save.
3. **Database:** SQL Editor → New query → paste all of `schema.sql` → Run. You should see "Success. No rows returned".
4. **Keys:** Project Settings → API Keys. Copy the **Project URL** and the **publishable key** (`sb_publishable_...`, or the `anon` key on older projects). Never copy the secret / `service_role` key.
5. **Paste into the game:** in `index.html`, search for `PASTE_YOUR` and paste the two values between the quotes.
6. **GitHub:** push `index.html`, `schema.sql` and this README to a GitHub repository.
7. **Render:** New → Static Site → connect the repository. Leave **Build Command** empty (if Render insists, type `echo done`), set **Publish Directory** to `.` → Create Static Site.
8. **Play:** open your `onrender.com` link, choose **Friend online** → **Create online game** → send the link to your friend.

Every push to GitHub redeploys the site automatically.

## How online play works

- Each player is signed in anonymously, so no accounts or passwords are needed.
- A game is one row in the `games` table: a 5-letter code, who sits at Black and White, and the list of moves.
- When you move, the move is added to the list. Supabase Realtime pushes the change to your friend's browser, which replays the moves to draw the same board.
- The database refuses: taking a seat that's already filled, moving when it isn't your turn, adding more than one move at a time, and changing earlier moves. (It doesn't check that a move follows the game's rules; each player's browser does that.)

## Troubleshooting

| What you see | What to check |
|---|---|
| "Online play isn't set up yet" | The two values in `index.html` are still `PASTE_...`, or the change wasn't pushed to GitHub. |
| "Couldn't create the game: Anonymous sign-ins are disabled" | Step 2. |
| "Couldn't create the game: relation "public.games" does not exist" | Step 3 wasn't run, or it was run in a different project. |
| "Invalid API key" | Re-copy the key from step 4. Make sure you used the publishable / anon key. |
| Your friend's moves only appear after a few seconds | Live updates aren't on. Run `schema.sql` again (its last part turns them on). The game checks for new moves every 5 seconds anyway. |
| The page shows an old version | Render takes a minute or two to redeploy after a push. Refresh the page. |

## Optional tidy-up

Finished games stay in the table. To delete games older than 30 days, run this in the SQL Editor:

```sql
delete from public.games where created_at < now() - interval '30 days';
```
