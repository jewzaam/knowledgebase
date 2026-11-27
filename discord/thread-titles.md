# Discord card thread titles and attention marker

- A card thread title is only `#NN [State] title`. It is renamed only when the board status changes (router `syncCards`); the rename strips any old leading status emoji.
- Session state (working, waiting, done) is never written to a title. Discord limits channel renames (reportedly about 2 per 10 minutes, unverified), and every emoji flip spent that quota.
- Attention (card `waiting:user` or in User review) is a bell reaction on the thread starter message. `board-tick` writes `_claude/state/board/attention.json` (card numbers); the router adds or removes the reaction. After a restart it checks the real reaction, so nothing is duplicated or left stale.
- Per-message reactions on user messages (seen, working, done) are separate and unchanged.
- Source: card thelenorith/work#62.
