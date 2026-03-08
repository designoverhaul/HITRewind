#!/usr/bin/env python3
"""Bulk extract official channel videos for ALL remaining categories and upload to Airtable."""

import subprocess, json, time, urllib.request, sys

YOUTUBE_API_KEY = "AIzaSyBiNw2RoGEbxTMGNiApi3TBZ-EH8oQXy24"
AIRTABLE_API_KEY = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
AIRTABLE_BASE = "appxCBIOkiJEZiph7"
AIRTABLE_TABLE = "tblSq6zqj4c6aXDhB"
FLD_TITLE = "fldO1e3nYAVfMVy60"
FLD_ARTIST = "fldJ1DiGlTjd9tuqn"
FLD_VIDEO_ID = "fldmWemcnY3I1JJvV"
FLD_DATE = "fldpbanMc1tNvI6xQ"
FLD_DURATION = "fldInoLuZjSZBBQ2J"

CATEGORIES = {
    "Jam Bands": {
        "Bela Fleck": "https://www.youtube.com/channel/UCptlnsqjPBIf4-C9XuXek_Q",
        "Billy Strings": "https://www.youtube.com/channel/UC7PLUlfQMnPtf4sjZ7N5gXA",
        "Goose": "https://www.youtube.com/channel/UCNMe_yeW_kCrjRImbUiQ3ZA",
        "Grateful Dead": "https://www.youtube.com/channel/UCPuuuhmMW7jh6roOrIV9yRw",
        "Phish": "https://www.youtube.com/channel/UCDEPOd0RCvw8iSTqFpSBZLA",
        "String Cheese Incident": "https://www.youtube.com/channel/UCp0-IPbm6I9LlBG2fWUNmLg",
        "The Disco Biscuits": "https://www.youtube.com/channel/UCMUHJbzpOsOv4VvGt_ntVrg",
        "Umphrey's McGee": "https://www.youtube.com/channel/UC6cl-exv_SHGPpYyLgwYTpw",
        "Widespread Panic": "https://www.youtube.com/channel/UCKmXntvZFs9VBYknXMMzIbw",
    },
    "Pop": {
        "Addison Rae": "https://www.youtube.com/channel/UCsjVdwXJydmlSLVT2zDuwpQ",
        "Adele": "https://www.youtube.com/channel/UComP_epzeKzvBX156r6pm1Q",
        "Ariana Grande": "https://www.youtube.com/channel/UC9CoOnJkIBMdeijd9qYoT_g",
        "Avril Lavigne": "https://www.youtube.com/channel/UC_k8KFBzEf0uQ8LRFSAgSUA",
        "Backstreet Boys": "https://www.youtube.com/channel/UC1OR2YNQLZJYFdQjFrPWvVw",
        "Billie Eilish": "https://www.youtube.com/channel/UCiGm_E4ZwYSHV3bcW1pnSeQ",
        "Blackpink": "https://www.youtube.com/channel/UCOmHUn--16B90oW2L6FRR3A",
        "Bruno Mars": "https://www.youtube.com/channel/UCoUM-UJ7rirJYP8CQ0EIaHA",
        "Celine Dion": "https://www.youtube.com/channel/UC_yGU4qz9zAjEWLQxCg9NZQ",
        "Chappell Roan": "https://www.youtube.com/channel/UCTKTRVaWrythRIGNfZYBp2A",
        "Charli XCX": "https://www.youtube.com/channel/UCOvEMf00DnwdkpOCRWdc6uA",
        "Christina Aguilera": "https://www.youtube.com/channel/UCgBN6eQyZPnsApiL1QW44Hg",
        "Coldplay": "https://www.youtube.com/channel/UCDPM_n1atn2ijUwHd0NNRQw",
        "Demi Lovato": "https://www.youtube.com/channel/UCZkURf9tDolFOeuw_4RD7XQ",
        "Dua Lipa": "https://www.youtube.com/channel/UC-J-KZfRV8c13fOCkhXdLiQ",
        "Ed Sheeran": "https://www.youtube.com/channel/UC0C-w0YjGpqDXGB8IHb662A",
        "Harry Styles": "https://www.youtube.com/channel/UCZFWPqqPkFlNwIxcpsLOwew",
        "Jonas Brothers": "https://www.youtube.com/channel/UCFvXnyAhluG3sa6p3eOs_LA",
        "Justin Bieber": "https://www.youtube.com/channel/UCIwFjwMjI0y7PDBVEO9-bkQ",
        "Justin Timberlake": "https://www.youtube.com/channel/UCsXfDf1CDgU3SCt0gxJNXGg",
        "Katy Perry": "https://www.youtube.com/channel/UCYvmuw-JtVrTZQ-7Y4kd63Q",
        "Kelly Clarkson": "https://www.youtube.com/channel/UCoRUmyNL8KEYftmxRA2n3SQ",
        "Lady Gaga": "https://www.youtube.com/channel/UCNL1ZadSjHpjm4q9j2sVtOA",
        "Lana Del Rey": "https://www.youtube.com/channel/UCqk3CdGN_j8IR9z4uBbVPSg",
        "Lizzo": "https://www.youtube.com/channel/UCXVMHu5xDH1oOfUGvaLyjGg",
        "Lorde": "https://www.youtube.com/channel/UCOxhwqKKlVq_NaD0LVffGuw",
        "Mariah Carey": "https://www.youtube.com/channel/UCurpiDXSkcUbgdMwHNZkrCg",
        "Miley Cyrus": "https://www.youtube.com/channel/UCn7dB9UMTBDjKtEKBy_XISw",
        "Olivia Dean": "https://www.youtube.com/channel/UCT3cEUoL1X0_BxN6q7LVH1w",
        "Olivia Rodrigo": "https://www.youtube.com/channel/UCy3zgWom-5AGypGX_FVTKpg",
        "One Direction": "https://www.youtube.com/channel/UCb2HGwORFBo94DmRx4oLzow",
        "OneRepublic": "https://www.youtube.com/channel/UCi4EDAgjULwwNBHOg1aaCig",
        "P!nk": "https://www.youtube.com/channel/UCXJDX1KK6t121Z9FLhu5o2A",
        "Paramore": "https://www.youtube.com/channel/UCc7_woMAIVIW2mAr1rPCsFQ",
        "Post Malone": "https://www.youtube.com/channel/UCeLHszkByNZtPKcaVXOCOQQ",
        "Sabrina Carpenter": "https://www.youtube.com/channel/UCPKWE1H6xhxwPlqUlKgHb_w",
        "Shawn Mendes": "https://www.youtube.com/channel/UC4-TgOSMJHn-LtY4zCzbQhw",
        "Taylor Swift": "https://www.youtube.com/channel/UCqECaJ8Gagnn7YCbPEzWH6g",
        "The Killers": "https://www.youtube.com/channel/UCkhyoTaWKuB-Rdbb6Z3Z5DA",
        "The Marias": "https://www.youtube.com/@TheMarias",
        "The Weeknd": "https://www.youtube.com/channel/UC0WP5P-ufpRfjbNrmOWwLBQ",
        "sombr": "https://www.youtube.com/channel/UCXlqFQmZZOb78teSnAqhuwA",
    },
    "R&B": {
        "Alicia Keys": "https://www.youtube.com/channel/UCK5X3f0fxO4YnVKVZP8p6hg",
        "Aretha Franklin": "https://www.youtube.com/channel/UCGDOBEUVPWkzmHo4dDa96zQ",
        "Beyonce": "https://www.youtube.com/channel/UCuHzBCaKmtaLcRAOoazhCPA",
        "Camila Cabello": "https://www.youtube.com/channel/UCio_FVgKVgqcHrRiXDpnqbw",
        "D'Angelo": "https://www.youtube.com/channel/UCKCWQOVUfdlDYX2_238_AeQ",
        "Daniel Caesar": "https://www.youtube.com/channel/UCKJg5mkBn18dtRFWUy_v1mw",
        "Doja Cat": "https://www.youtube.com/channel/UCzpl23pGTHVYqvKsgY0A-_w",
        "Elvis Presley": "https://www.youtube.com/channel/UCW6G95TBLCh5SdC-DHDSf5w",
        "H.E.R": "https://www.youtube.com/channel/UCFwC3Ryue6CorFm2xCEG0Aw",
        "James Brown": "https://www.youtube.com/channel/UCOCZxe0gNRA7c3PGWPGoiGg",
        "John Legend": "https://www.youtube.com/channel/UCEa-JnNdYCIFn3HMhjGEWpQ",
        "Khalid": "https://www.youtube.com/channel/UCkntT5Je5DDopF70YUsnuEQ",
        "Lauryn Hill": "https://www.youtube.com/channel/UCYcofFCRA6l398IofsT6R2A",
        "Marvin Gaye": "https://www.youtube.com/channel/UCV0Arhg2bZuyL6CutipMduw",
        "Prince": "https://www.youtube.com/channel/UCv3mNSNjuWldihk1DUdnGtw",
        "Ray Charles": "https://www.youtube.com/channel/UCuDb3PN8JzDZLY-TUosFkgw",
        "Rihanna": "https://www.youtube.com/channel/UC2xskkQVFEpLcGFnNSLQY0A",
        "SZA": "https://www.youtube.com/channel/UCO5IQ70V7l-XpHW40HwaGsw",
        "Stevie Wonder": "https://www.youtube.com/channel/UCGD7CfG3JgZF52QpIRivV1Q",
        "Summer Walker": "https://www.youtube.com/channel/UCSpNS4dJ8wIScwMqatIdiQw",
        "TIna Turner": "https://www.youtube.com/channel/UCfOTTeREY6_1LSW5M0bdG7g",
        "The Temptations": "https://www.youtube.com/channel/UCee8VNCWfOCYccbFhDM8B_A",
        "Usher": "https://www.youtube.com/channel/UCaNrhBiXsXIM2epDl_kEzgQ",
        "Whitney Houston": "https://www.youtube.com/channel/UC7fzrpTArAqDHuB3Hbmd_CQ",
    },
    "Hip Hop": {
        "A$AP Rocky": "https://www.youtube.com/channel/UCHE7rAi1Fw1CBmQXFtvJmrw",
        "Beastie Boys": "https://www.youtube.com/channel/UCX62fwFYJNo5U-Flu2V-kGQ",
        "Cardi B": "https://www.youtube.com/channel/UCxMAbVFmxKUVGAll0WVGpFw",
        "Chance the Rapper": "https://www.youtube.com/channel/UCeXp3EC97_rUl_e2vgM3gLg",
        "Drake": "https://www.youtube.com/channel/UCByOQJjav0CUDwxCk-jVNRQ",
        "Eminem": "https://www.youtube.com/channel/UC20vb-R_px4CguHzzBPhoyQ",
        "Future": "https://www.youtube.com/channel/UCFNosi99Sp0_eLilBiXmmXA",
        "J. Cole": "https://www.youtube.com/channel/UCnc6db-y3IU7CkT_yeVXdVg",
        "Jay Z": "https://www.youtube.com/channel/UCN-sc1xJr-QQNj_uNIM9wTA",
        "Juice WRLD": "https://www.youtube.com/channel/UC3_471gFY-nl4Fi0MX8eoIQ",
        "Kanye West": "https://www.youtube.com/channel/UCs6eXM7s8Vl5WcECcRHc2qQ",
        "Kendrick Lamar": "https://www.youtube.com/channel/UC3lBXcrKFnFAFkfVk5WuKcQ",
        "Lil Wayne": "https://www.youtube.com/channel/UCO9zJy7HWrIS3ojB4Lr7Yqw",
        "Megan Three Stallion": "https://www.youtube.com/channel/UCKrdjiuS66yXOdEZ_cOD_TA",
        "Nas": "https://www.youtube.com/channel/UChE4aVxHHk5Mx9fZ2DaPJGw",
        "Nicki Minaj": "https://www.youtube.com/channel/UCaum3Yzdl3TbBt8YUeUGZLQ",
        "OutKast": "https://www.youtube.com/channel/UCaziuyHLR37c2jBkHrYSQMA",
        "Run-DMC": "https://www.youtube.com/channel/UCLPo8s1MY3FOzzSwWZP0ZvQ",
        "Snoop Dogg": "https://www.youtube.com/channel/UC-OO324clObi3H-U0bP77dw",
        "Travis Scott": "https://www.youtube.com/channel/UCtxdfwb9wfkoGocVUAJ-Bmg",
        "Tyler, the Creator": "https://www.youtube.com/channel/UCsQBsZJltmLzlsJNG7HevBg",
        "Wu-Tang Clan": "https://www.youtube.com/channel/UCl0q_XqiWDMA-Q9SzUO3y-Q",
    },
    "Country": {
        "Alan Jackson": "https://www.youtube.com/channel/UCChNoYrjZP3ymvjh2BKBPbA",
        "Brad Paisley": "https://www.youtube.com/channel/UCjjFKRDdhWbvAQEG7cNs5qQ",
        "Carrie Underwood": "https://www.youtube.com/channel/UCBxZZfQ8R2xtk0YEU1d8l4Q",
        "Chris Stapleton": "https://www.youtube.com/channel/UC_uPAFZghRvM1W89Rt-opZw",
        "Dolly Parton": "https://www.youtube.com/channel/UCuGuRQHrvoNsD-AolV0X39g",
        "Eric Church": "https://www.youtube.com/channel/UCO83-v8Iqb9yN2RnyBrZkwQ",
        "George Strait": "https://www.youtube.com/channel/UCOmZHz5W3F17HraXlJveEJA",
        "Jason Aldean": "https://www.youtube.com/channel/UCw0F_Xuz0VqemtMAtEfHTdA",
        "Johnny Cash": "https://www.youtube.com/channel/UCLwdOhL6TKbmjRtZ8wIr-Bg",
        "Loretta Lynn": "https://www.youtube.com/channel/UCazGoeKn0U-L1evwEnJg6kA",
        "Luke Bryan": "https://www.youtube.com/channel/UCntGDhwr_YA88wVr0WpOMEA",
        "Luke Combs": "https://www.youtube.com/channel/UCOSIXyYdT93OzpRnAuWaKjQ",
        "Morgan Wallen": "https://www.youtube.com/channel/UCzIyoPv6j1MAZpDHKLGP_eA",
        "Tim McGraw": "https://www.youtube.com/channel/UC2mK990tp7umnN6Y-DEGpDg",
        "Willie Nelson": "https://www.youtube.com/channel/UCdBD6uy0ZuX7sLK4__Ll6LQ",
        "Zach Bryan": "https://www.youtube.com/channel/UCwK3C8Vgphad4PweezfUBAQ",
    },
    "Jazz": {
        "Charles Mingus": "https://www.youtube.com/channel/UCR4P2JbCWZie0w6xQZJLDCQ",
        "Chet Baker": "https://www.youtube.com/channel/UCiLq_AE4ThU4ZDqjOO2KFcg",
        "Dave Brubeck": "https://www.youtube.com/channel/UCt9j7GVh_NwJjbnFcJItReA",
        "Dizzy Gillespie": "https://www.youtube.com/channel/UCdDCVfOk2X2KZGOXfndL26A",
        "Duke Ellington": "https://www.youtube.com/channel/UCreGqqIJb0RfJ30WkgxWTgg",
        "Ella Fitzgerald": "https://www.youtube.com/channel/UC63nGmKVdVhiZr_bWhJVGGg",
        "Herbie Hancock": "https://www.youtube.com/channel/UC-w3aQyKGcYe9JnhnhExaNQ",
        "John Coltrane": "https://www.youtube.com/channel/UCGiKlUaxFFNXkEYIW6mfbBQ",
        "Kamasi Washington": "https://www.youtube.com/channel/UCyWhax3C9dATbDI170G4sxQ",
        "Louis Armstrong": "https://www.youtube.com/channel/UC9ZFNi6DcduUn9KUMhOnFUQ",
        "Miles Davis": "https://www.youtube.com/channel/UC1ZS17c0DlqUjsXZK3K_bgA",
        "Oscar Peterson": "https://www.youtube.com/channel/UC_nSZBMhne3ihfNggYhsHEg",
        "Thelonious Monk": "https://www.youtube.com/channel/UCHiOp5Z2ECvD00UChyfM5Xw",
        "Wynton Marsalis": "https://www.youtube.com/channel/UCGrcWKuyxxwnIHg1101zabA",
    },
    "Latin": {
        "Bad Bunny": "https://www.youtube.com/channel/UCmBA_wu8xGg1OfOkfW13Q0Q",
        "Carlos Vives": "https://www.youtube.com/channel/UChcn-n6L8vYHzsqOwOubdRQ",
        "Daddy Yankee": "https://www.youtube.com/channel/UC9TO_oo4c_LrOiKNaY6aysA",
        "Enrique Iglesias": "https://www.youtube.com/channel/UC-6czyMkxDi8E8akPl0c7_w",
        "Feid": "https://www.youtube.com/@Feid",
        "J Balvin": "https://www.youtube.com/channel/UCt-k6JwNWHMXDBGm9IYHdsg",
        "Juanes": "https://www.youtube.com/channel/UCbGmbLGPhxIlp1JF4tybiAg",
        "Karol G": "https://www.youtube.com/channel/UCz9yS18zJGQObwUL_K-ICnw",
        "Luis Fonsi": "https://www.youtube.com/channel/UCxoq-PAQeAdk_zyg8YS0JqA",
        "Maluma": "https://www.youtube.com/channel/UClZuKq2m0Qu-HkopkSBLpEw",
        "Marc Anthony": "https://www.youtube.com/channel/UCiKsRIULyLr783nNZm-JlAQ",
        "Ozuna": "https://www.youtube.com/channel/UCjIA3wwhi0QjSOXAZwOXbPA",
        "Peso Pluma": "https://www.youtube.com/channel/UCzrM_068Odho89mTRrrxqbA",
        "Rauw Alejandro": "https://www.youtube.com/channel/UC_Av98lDjf5KvFib5elhpYg",
        "Romeo Santos": "https://www.youtube.com/channel/UCyxbZF7_PK4nLiexj0kkCNg",
        "Rosalia": "https://www.youtube.com/channel/UCQt9awGIFZeldFsATZNeJag",
        "Shakira": "https://www.youtube.com/channel/UCYLNGLIzMhRTi6ZOLjAPSmw",
    },
    "Indi": {
        "Arcade Fire": "https://www.youtube.com/channel/UCIIGxQ6BA9MwIJXBu47SyZQ",
        "Band of Horses": "https://www.youtube.com/channel/UCD5QVN7OwJhnx6iO9L3uT_Q",
        "Bjork": "https://www.youtube.com/channel/UCFbRdRGijPR4oBjQ0fVCSmw",
        "Bon Iver": "https://www.youtube.com/channel/UCci2c90HJbY0VAS3_eLF3Wg",
        "Death Cab for Cutie": "https://www.youtube.com/channel/UCOtn115fCfFKIxG7_Quv9ZA",
        "Fleet Foxes": "https://www.youtube.com/@FleetFoxes",
        "Florence + The Machine": "https://www.youtube.com/channel/UC5MujsH-hrVWHBBfSSmv18A",
        "Khruangbin": "https://www.youtube.com/channel/UCZGBua-dvwfSdcF9AskDIgw",
        "LCD Soundsystem": "https://www.youtube.com/@lcdsoundsystem1689",
        "Mac DeMarco": "https://www.youtube.com/channel/UCqnMk5GA1spXDiHYFcPN-eA",
        "Modest Mouse": "https://www.youtube.com/channel/UCBEGcyJUC-0SFTJ1t45yOzw",
        "My Morning Jacket": "https://www.youtube.com/channel/UCKARN4GSFIOiKUIpCtRlO9g",
        "Pavement": "https://www.youtube.com/channel/UCVjleeSDIuZ7WjeProi91Bg",
        "Phoebe Bridgers": "https://www.youtube.com/channel/UCh4PO1W9tVmHujIPZnfK8TQ",
        "Sufjan Stevens": "https://www.youtube.com/channel/UCMi8tQF_L7rd6YcmSt7MXrQ",
        "Tame Impala": "https://www.youtube.com/channel/UCEGJtJpwHlpUoMlAOlCWdAA",
        "The National": "https://www.youtube.com/channel/UCeiRyLo_Q9q4tlv9aaQJF5w",
        "The Shins": "https://www.youtube.com/channel/UCwKTbPQOdBFrkSvGrO-8v3g",
        "The Strokes": "https://www.youtube.com/channel/UC_JnlnBEy6F7CuwIQ-KSGBg",
        "The White Stripes": "https://www.youtube.com/channel/UC0sQemK7pgX5fYy0k1MFsHg",
        "Vampire Weekend": "https://www.youtube.com/channel/UCOMsN9AXZP9Jey0Pl8BBf2g",
        "Wilco": "https://www.youtube.com/channel/UCVdVWoOy-V2r2dcFsMAWN9Q",
    },
    "Electronic": {
        "Avicii": "https://www.youtube.com/channel/UCPHjpfnnGklkRBBTd0k6aHg",
        "Calvin Harris": "https://www.youtube.com/channel/UCIjYyZxkFucP_W-tmXg_9Ow",
        "Chemical Brothers": "https://www.youtube.com/channel/UCvyAsTkXVoCQtFG-rGhwCKw",
        "Daft Punk": "https://www.youtube.com/channel/UC_kRDKYrUlrbtrSiyu5Tflg",
        "David Guetta": "https://www.youtube.com/channel/UC1l7wYrva1qCH-wgqcHaaRg",
        "Deadmau5": "https://www.youtube.com/channel/UCYEK6xds6eo-3tr4xRdflmQ",
        "Diplo": "https://www.youtube.com/channel/UCKp7UVaoVuiW1qtyPLPVFMQ",
        "Eric Prydz": "https://www.youtube.com/channel/UCOjTxt7xBAjh1NraToYYlog",
        "Flume": "https://www.youtube.com/channel/UCXAhoI7XO2kafTMjocm0jCg",
        "Kygo": "https://www.youtube.com/channel/UCCFJeI-2sT_cWgz-QJRgbCw",
        "Marshmello": "https://www.youtube.com/channel/UCEdvpU2pFRCVqU6yIPyTpMQ",
        "Martin Garrix": "https://www.youtube.com/channel/UC5H_KXkPbEsGs0tFt8R35mA",
        "Skrillex": "https://www.youtube.com/channel/UC_TVqp_SyG6j5hG-xVRy95A",
        "Swedish House Mafia": "https://www.youtube.com/channel/UC5HEq5U--O5nn134mizyCcw",
        "Tiësto": "https://www.youtube.com/channel/UCO59y9XJIJZS5i86lUOvMGA",
        "Zedd": "https://www.youtube.com/channel/UCPNokRZ9hacjIQ3IQL6HNUQ",
    },
    "I ❤️ '80s": {
        "Bon Jovi": "https://www.youtube.com/channel/UCkBwnm7GOfYHsacwUjriC-w",
        "Bruce Springsteen": "https://www.youtube.com/channel/UCkZu0HAGinESFynhe3R4hxQ",
        "Cyndi Lauper": "https://www.youtube.com/channel/UC8vzbjthwDMK8dAHEte6eMQ",
        "Def Leppard": "https://www.youtube.com/channel/UCZjBqZjGsmI5OAVsLSroaWQ",
        "Depeche Mode": "https://www.youtube.com/channel/UC90vR_MFeheV3V6nmjvXIng",
        "Duran Duran": "https://www.youtube.com/channel/UC3Pb3fztIUVLCisYZgygcjg",
        "Genesis": "https://www.youtube.com/channel/UChv9FR8xwUxEkdBUVu4VUOw",
        "Kiss": "https://www.youtube.com/channel/UCyOw2FDjfQOFQH7paKxNVvA",
        "Madonna": "https://www.youtube.com/channel/UC81VD6eeuLLSfyY_D-N8sVw",
        "Michael Jackson": "https://www.youtube.com/channel/UC5OrDvL9DscpcAstz7JnQGA",
        "New Order": "https://www.youtube.com/channel/UCeROFwqsf3ADf02l5JzVKJg",
        "Phil Collins": "https://www.youtube.com/channel/UC4JeRiQvPQ_nb1BZWjk9QoA",
        "Talking Heads": "https://www.youtube.com/channel/UCtdA-aw9mKFluSFoIT92wWw",
        "Tears for Fears": "https://www.youtube.com/channel/UCyH3IAelkUFM0u6Iacx22lA",
        "The Cure": "https://www.youtube.com/channel/UCL_zMdXdM51oSi5XpxTvRtQ",
        "The Police": "https://www.youtube.com/channel/UCuCY8MR9LcAGIXetnKx5SnQ",
        "The Smiths": "https://www.youtube.com/@thesmithsofficial",
        "U2": "https://www.youtube.com/channel/UC4gPNusMDwx2Xm-YI35AkCA",
        "Van Halen": "https://www.youtube.com/channel/UCfOTTeREY6_1LSW5M0bdG7g",
        "XTC": "https://www.youtube.com/@xtcvevo4643",
    },
}

# Note: Some artists appear in multiple categories (e.g. Grateful Dead in Classic Rock + Jam Bands,
# Coldplay in Modern Rock + Pop). We skip duplicates already uploaded.
ALREADY_DONE = set()

def yt_dlp_extract(channel_url, max_videos=40):
    cmd = [
        "yt-dlp", "--flat-playlist", f"--playlist-end={max_videos}",
        "--print", "%(id)s|||%(title)s|||%(duration)s",
        f"{channel_url}/videos"
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        videos = []
        for line in result.stdout.strip().split("\n"):
            if "|||" not in line:
                continue
            parts = line.split("|||")
            if len(parts) >= 3:
                vid_id, title, dur = parts[0], parts[1], parts[2]
                dur_secs = int(float(dur)) if dur and dur != "NA" else 0
                videos.append({"id": vid_id, "title": title, "duration": dur_secs})
        return videos
    except Exception as e:
        print(f"  yt-dlp error: {e}")
        return []

def youtube_api_dates(video_ids):
    dates = {}
    for i in range(0, len(video_ids), 50):
        batch = video_ids[i:i+50]
        ids_str = ",".join(batch)
        url = f"https://www.googleapis.com/youtube/v3/videos?part=snippet&id={ids_str}&key={YOUTUBE_API_KEY}&maxResults=50"
        try:
            req = urllib.request.Request(url)
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read())
                for item in data.get("items", []):
                    dates[item["id"]] = item["snippet"]["publishedAt"][:10]
        except Exception as e:
            print(f"  YouTube API error: {e}")
    return dates

def airtable_upload(records):
    url = f"https://api.airtable.com/v0/{AIRTABLE_BASE}/{AIRTABLE_TABLE}"
    headers = {
        "Authorization": f"Bearer {AIRTABLE_API_KEY}",
        "Content-Type": "application/json"
    }
    total = 0
    for i in range(0, len(records), 10):
        batch = records[i:i+10]
        payload = json.dumps({"records": batch}).encode()
        req = urllib.request.Request(url, data=payload, headers=headers, method="POST")
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                result = json.loads(resp.read())
                total += len(result.get("records", []))
        except Exception as e:
            print(f"  Airtable upload error: {e}")
        time.sleep(0.25)
    return total

def process_artist(name, channel_url):
    print(f"  [1/3] Extracting videos from channel...")
    videos = yt_dlp_extract(channel_url)
    if not videos:
        print(f"  SKIP: No videos found")
        return 0
    print(f"  Found {len(videos)} videos")

    print(f"  [2/3] Fetching publish dates...")
    video_ids = [v["id"] for v in videos]
    dates = youtube_api_dates(video_ids)
    print(f"  Got dates for {len(dates)}/{len(videos)} videos")

    records = []
    for v in videos:
        vid_id = v["id"]
        yt_url = f"https://www.youtube.com/watch?v={vid_id}"
        date = dates.get(vid_id, "")
        records.append({
            "fields": {
                FLD_TITLE: v["title"],
                FLD_ARTIST: name,
                FLD_VIDEO_ID: yt_url,
                FLD_DATE: date,
                FLD_DURATION: str(v["duration"]),
            }
        })

    print(f"  [3/3] Uploading {len(records)} records to Airtable...")
    uploaded = airtable_upload(records)
    print(f"  Uploaded {uploaded} records")
    return uploaded

if __name__ == "__main__":
    grand_total = 0
    total_categories = len(CATEGORIES)

    for cat_idx, (cat_name, artists) in enumerate(CATEGORIES.items(), 1):
        print(f"\n{'#'*60}")
        print(f"# CATEGORY {cat_idx}/{total_categories}: {cat_name} ({len(artists)} artists)")
        print(f"{'#'*60}")

        cat_total = 0
        for art_idx, (name, url) in enumerate(artists.items(), 1):
            # Skip if already processed in a previous category
            if name in ALREADY_DONE:
                print(f"\n  [{art_idx}/{len(artists)}] {name} — SKIP (already uploaded)")
                continue

            print(f"\n  [{art_idx}/{len(artists)}] {name}")
            count = process_artist(name, url)
            cat_total += count
            grand_total += count
            ALREADY_DONE.add(name)
            time.sleep(0.5)

        print(f"\n  >>> {cat_name} complete: {cat_total} records")

    print(f"\n{'='*60}")
    print(f"ALL DONE! Uploaded {grand_total} total records across {total_categories} categories")
    print(f"{'='*60}")
