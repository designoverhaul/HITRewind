# YouTube Video Curator - Agent Memory

## API Key
- Airtable key in Constants.swift: `pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b`
- The key provided in task prompts may differ — always verify against Constants.swift

## Airtable Delete Workaround
- The Airtable MCP does NOT have a delete tool
- Use curl DELETE with the key from Constants.swift:
  `curl -s -X DELETE "https://api.airtable.com/v0/{baseId}/{tableId}?records[]={id1}&records[]={id2}..." -H "Authorization: Bearer {key}"`
- Max 10 records per DELETE request

## Years Completed in MTvVideosNEW
- 1973-1979, 1980-1999, 2001, 2002, 2021, 2022, 2023, 2024, 2025
- 1991 replaced with DDDoor list (completed 2026-03-03)
- 1990 replaced with DDDoor list (completed 2026-03-03)
- 1989 replaced with DDDoor list (completed 2026-03-03)
- 1988 added fresh from DDDoor list (completed 2026-03-03)
- 1987 added fresh from DDDoor list (completed 2026-03-03)
- 1986 replaced with DDDoor list (completed 2026-03-03)
- 1985 replaced with DDDoor list (completed 2026-03-03)
- 1984 added fresh from DDDoor list (completed 2026-03-03)
- 1983 added fresh from DDDoor list (completed 2026-03-03)
- 1982 replaced with DDDoor list (completed 2026-03-03)
- 1981 added fresh from DDDoor list (completed 2026-03-03)
- 1980 added fresh from DDDoor list (completed 2026-03-03)
- 1979 replaced with DDDoor list (completed 2026-03-03)
- 1978 replaced with DDDoor list (completed 2026-03-03)
- 1977 replaced with DDDoor list (completed 2026-03-03)

## DDDoor Migration Warning: Pre-Existing Records
- When migrating a year, ALWAYS check if records already exist before adding new ones
- The fetch-then-compare approach is essential: fetch existing, add new, then delete old
- Problem encountered on 1980 and 1977: pre-existing Billboard records in DB (75 each time)
- Pattern: add 100 new DDDoor records first, then identify+delete old records
- OLD record identification: compare title against DDDoor list; also check for wrong rank on DDDoor-titled records
- After deletions, verify correct count: some new records may get accidentally deleted if logic is too aggressive — re-add any missing ranks
- After deletion, verify with pagination (pageSize=100) — offset token means >100 records still exist
- Duplicate rank detection: use Counter(ranks) to find ranks appearing >1 time after all operations
- SAFER approach: build a set of (rank, title) pairs from DDDoor, then delete any record NOT matching exact (rank, title)

## yt-dlp Search Pattern
- Command: `yt-dlp "ytsearch1:{title} {artist} official music video" --get-id --get-title --no-warnings`
- Returns title on line 1, video ID on line 2
- URL format: `https://www.youtube.com/watch?v={id}`
- Run in batches via shell loop for efficiency

## Notes on Specific Searches
- "Buggin' Out" by ATCQ: search without "official music video" suffix gets the right dedicated video (P9oTCzWRuvQ)
- "Jazz (We've Got)" by ATCQ shares a combined video with "Buggin' Out" (cxN4nKk2cfk) — acceptable
- For pre-2000 songs, upscaled/remastered versions are fine if no native official MV exists
