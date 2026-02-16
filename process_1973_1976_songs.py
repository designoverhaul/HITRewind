#!/usr/bin/env python3
"""
Process 1973-1976 Billboard Hot 100 songs and add them to Airtable MTvVideosNEW table.
Searches YouTube for the best music video for each song.

For 1970s content, uses multiple search strategies since MTV didn't exist until 1981:
- Official music videos (some were made for TV promotion)
- Remastered/VEVO versions
- Performance clips from TV shows (Soul Train, TopPop, etc.)
"""

import urllib.request
import urllib.parse
import urllib.error
import time
import json
import re
import sys
import ssl
from typing import Optional, Dict, List, Tuple

# Create SSL context that doesn't verify certificates (for macOS compatibility)
ssl_context = ssl.create_default_context()
ssl_context.check_hostname = False
ssl_context.verify_mode = ssl.CERT_NONE

# Configuration
YOUTUBE_API_KEY = "AIzaSyChKL0fUHEfc1AlKe0ks53Y2wT78gxLiJE"
AIRTABLE_API_KEY = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
AIRTABLE_BASE_ID = "appxCBIOkiJEZiph7"
AIRTABLE_TABLE_ID = "tblNwqwVyflL8hNDy"  # MTvVideosNEW

# Billboard Hot 100 Songs Data (Rank, Title, Artist)
SONGS_1973 = [
    (1, "Tie a Yellow Ribbon Round the Ole Oak Tree", "Tony Orlando and Dawn"),
    (2, "Bad, Bad Leroy Brown", "Jim Croce"),
    (3, "Killing Me Softly with His Song", "Roberta Flack"),
    (4, "Let's Get It On", "Marvin Gaye"),
    (5, "My Love", "Paul McCartney & Wings"),
    (6, "Why Me", "Kris Kristofferson"),
    (7, "Crocodile Rock", "Elton John"),
    (8, "Will It Go Round in Circles", "Billy Preston"),
    (9, "You're So Vain", "Carly Simon"),
    (10, "Touch Me in the Morning", "Diana Ross"),
    (11, "The Night the Lights Went Out in Georgia", "Vicki Lawrence"),
    (12, "Playground in My Mind", "Clint Holmes"),
    (13, "Brother Louie", "Stories"),
    (14, "Delta Dawn", "Helen Reddy"),
    (15, "Me and Mrs. Jones", "Billy Paul"),
    (16, "Frankenstein", "The Edgar Winter Group"),
    (17, "Drift Away", "Dobie Gray"),
    (18, "Little Willy", "Sweet"),
    (19, "You Are the Sunshine of My Life", "Stevie Wonder"),
    (20, "Half-Breed", "Cher"),
    (21, "That Lady", "The Isley Brothers"),
    (22, "Pillow Talk", "Sylvia Robinson"),
    (23, "We're an American Band", "Grand Funk Railroad"),
    (24, "Right Place Wrong Time", "Dr. John"),
    (25, "Wildflower", "Skylark"),
    (26, "Superstition", "Stevie Wonder"),
    (27, "Loves Me Like a Rock", "Paul Simon"),
    (28, "The Morning After", "Maureen McGovern"),
    (29, "Rocky Mountain High", "John Denver"),
    (30, "Stuck in the Middle with You", "Stealers Wheel"),
    (31, "Shambala", "Three Dog Night"),
    (32, "Love Train", "The O'Jays"),
    (33, "I'm Gonna Love You Just a Little More Baby", "Barry White"),
    (34, "Say, Has Anybody Seen My Sweet Gypsy Rose", "Tony Orlando and Dawn"),
    (35, "Keep on Truckin'", "Eddie Kendricks"),
    (36, "Danny's Song", "Anne Murray"),
    (37, "Dancing in the Moonlight", "King Harvest"),
    (38, "Monster Mash", "Bobby 'Boris' Pickett"),
    (39, "Natural High", "Bloodstone"),
    (40, "Diamond Girl", "Seals and Crofts"),
    (41, "Long Train Runnin'", "The Doobie Brothers"),
    (42, "Give Me Love (Give Me Peace on Earth)", "George Harrison"),
    (43, "If You Want Me to Stay", "Sly & the Family Stone"),
    (44, "Daddy's Home", "Jermaine Jackson"),
    (45, "Neither One of Us (Wants to Be the First to Say Goodbye)", "Gladys Knight & the Pips"),
    (46, "I'm Doin' Fine Now", "New York City"),
    (47, "Could It Be I'm Falling in Love", "The Spinners"),
    (48, "Daniel", "Elton John"),
    (49, "Midnight Train to Georgia", "Gladys Knight & the Pips"),
    (50, "Smoke on the Water", "Deep Purple"),
    (51, "The Cover of the Rolling Stone", "Dr. Hook & The Medicine Show"),
    (52, "Behind Closed Doors", "Charlie Rich"),
    (53, "Your Mama Don't Dance", "Loggins and Messina"),
    (54, "Feelin' Stronger Every Day", "Chicago"),
    (55, "The Cisco Kid", "War"),
    (56, "Live and Let Die", "Paul McCartney & Wings"),
    (57, "Ring Ring", "ABBA"),
    (58, "I Believe in You (You Believe in Me)", "Johnnie Taylor"),
    (59, "Sing", "The Carpenters"),
    (60, "Ain't No Woman (Like the One I've Got)", "The Four Tops"),
    (61, "Dueling Banjos", "Eric Weissberg & Steve Mandell"),
    (62, "Higher Ground", "Stevie Wonder"),
    (63, "Here I Am (Come and Take Me)", "Al Green"),
    (64, "My Maria", "B.W. Stevenson"),
    (65, "Superfly", "Curtis Mayfield"),
    (66, "Last Song", "Edward Bear"),
    (67, "Get Down", "Gilbert O'Sullivan"),
    (68, "Reelin' in the Years", "Steely Dan"),
    (69, "Hocus Pocus", "Focus"),
    (70, "Yesterday Once More", "The Carpenters"),
    (71, "Boogie Woogie Bugle Boy", "Bette Midler"),
    (72, "Clair", "Gilbert O'Sullivan"),
    (73, "Do It Again", "Steely Dan"),
    (74, "Kodachrome", "Paul Simon"),
    (75, "Why Can't We Live Together", "Timmy Thomas"),
    (76, "Do You Wanna Dance?", "Bette Midler"),
    (77, "So Very Hard to Go", "Tower of Power"),
    (78, "Rockin' Pneumonia and the Boogie Woogie Flu", "Johnny Rivers"),
    (79, "Ramblin' Man", "The Allman Brothers Band"),
    (80, "Masterpiece", "The Temptations"),
    (81, "Peaceful", "Helen Reddy"),
    (82, "One of a Kind (Love Affair)", "The Spinners"),
    (83, "Funny Face", "Donna Fargo"),
    (84, "Funky Worm", "Ohio Players"),
    (85, "Angie", "The Rolling Stones"),
    (86, "Jambalaya (On the Bayou)", "Blue Ridge Rangers"),
    (87, "Don't Expect Me to Be Your Friend", "Lobo"),
    (88, "Break Up to Make Up", "The Stylistics"),
    (89, "Daisy a Day", "Jud Strunk"),
    (90, "Also Sprach Zarathustra (2001)", "Deodato"),
    (91, "Stir It Up", "Johnny Nash"),
    (92, "Money", "Pink Floyd"),
    (93, "Gypsy Man", "War"),
    (94, "The World Is a Ghetto", "War"),
    (95, "Yes We Can Can", "The Pointer Sisters"),
    (96, "Free Ride", "The Edgar Winter Group"),
    (97, "Space Oddity", "David Bowie"),
    (98, "It Never Rains in Southern California", "Albert Hammond"),
    (99, "The Twelfth of Never", "Donny Osmond"),
    (100, "Papa Was a Rollin' Stone", "The Temptations"),
]

SONGS_1974 = [
    (1, "The Way We Were", "Barbra Streisand"),
    (2, "Seasons in the Sun", "Terry Jacks"),
    (3, "Love's Theme", "Love Unlimited Orchestra"),
    (4, "Come and Get Your Love", "Redbone"),
    (5, "Dancing Machine", "The Jackson 5"),
    (6, "The Loco-Motion", "Grand Funk Railroad"),
    (7, "TSOP (The Sound of Philadelphia)", "MFSB"),
    (8, "The Streak", "Ray Stevens"),
    (9, "Bennie and the Jets", "Elton John"),
    (10, "One Hell of a Woman", "Mac Davis"),
    (11, "Until You Come Back to Me (That's What I'm Gonna Do)", "Aretha Franklin"),
    (12, "Jungle Boogie", "Kool & the Gang"),
    (13, "Midnight at the Oasis", "Maria Muldaur"),
    (14, "You Make Me Feel Brand New", "The Stylistics"),
    (15, "Show and Tell", "Al Wilson"),
    (16, "Spiders and Snakes", "Jim Stafford"),
    (17, "Rock On", "David Essex"),
    (18, "Sunshine on My Shoulders", "John Denver"),
    (19, "Sideshow", "Blue Magic"),
    (20, "Hooked on a Feeling", "Blue Swede"),
    (21, "Billy Don't Be a Hero", "Bo Donaldson and The Heywoods"),
    (22, "Band on the Run", "Paul McCartney and Wings"),
    (23, "The Most Beautiful Girl", "Charlie Rich"),
    (24, "Time in a Bottle", "Jim Croce"),
    (25, "Annie's Song", "John Denver"),
    (26, "Let Me Be There", "Olivia Newton-John"),
    (27, "Sundown", "Gordon Lightfoot"),
    (28, "(You're) Having My Baby", "Paul Anka"),
    (29, "Rock Me Gently", "Andy Kim"),
    (30, "Boogie Down", "Eddie Kendricks"),
    (31, "You're Sixteen", "Ringo Starr"),
    (32, "If You Love Me (Let Me Know)", "Olivia Newton-John"),
    (33, "Dark Lady", "Cher"),
    (34, "Best Thing That Ever Happened to Me", "Gladys Knight & the Pips"),
    (35, "Feel Like Makin' Love", "Roberta Flack"),
    (36, "Just Don't Want to Be Lonely", "The Main Ingredient"),
    (37, "Nothing from Nothing", "Billy Preston"),
    (38, "Rock Your Baby", "George McCrae"),
    (39, "Top of the World", "The Carpenters"),
    (40, "The Joker", "Steve Miller Band"),
    (41, "I've Got to Use My Imagination", "Gladys Knight & the Pips"),
    (42, "The Show Must Go On", "Three Dog Night"),
    (43, "Rock the Boat", "The Hues Corporation"),
    (44, "Smokin' in the Boys Room", "Brownsville Station"),
    (45, "Living for the City", "Stevie Wonder"),
    (46, "Then Came You", "Dionne Warwick & The Spinners"),
    (47, "The Night Chicago Died", "Paper Lace"),
    (48, "The Entertainer", "Marvin Hamlisch"),
    (49, "Waterloo", "ABBA"),
    (50, "The Air That I Breathe", "The Hollies"),
    (51, "Rikki Don't Lose That Number", "Steely Dan"),
    (52, "Mockingbird", "Carly Simon & James Taylor"),
    (53, "Help Me", "Joni Mitchell"),
    (54, "You Won't See Me", "Anne Murray"),
    (55, "Never, Never Gonna Give You Up", "Barry White"),
    (56, "Tell Me Something Good", "Rufus & Chaka Khan"),
    (57, "You and Me Against the World", "Helen Reddy"),
    (58, "Rock and Roll Heaven", "The Righteous Brothers"),
    (59, "Hollywood Swinging", "Kool & the Gang"),
    (60, "Be Thankful for What You Got", "William DeVaughn"),
    (61, "Hang on in There Baby", "Johnny Bristol"),
    (62, "Eres tu", "Mocedades"),
    (63, "Takin' Care of Business", "Bachman-Turner Overdrive"),
    (64, "Radar Love", "Golden Earring"),
    (65, "Please Come to Boston", "Dave Loggins"),
    (66, "Keep on Smilin'", "Wet Willie"),
    (67, "Lookin' for a Love", "Bobby Womack"),
    (68, "Put Your Hands Together", "The O'Jays"),
    (69, "On and On", "Gladys Knight & the Pips"),
    (70, "Oh Very Young", "Cat Stevens"),
    (71, "Leave Me Alone (Ruby Red Dress)", "Helen Reddy"),
    (72, "Goodbye Yellow Brick Road", "Elton John"),
    (73, "(I've Been) Searchin' So Long", "Chicago"),
    (74, "Oh My My", "Ringo Starr"),
    (75, "For the Love of Money", "The O'Jays"),
    (76, "I Shot the Sheriff", "Eric Clapton"),
    (77, "Jet", "Paul McCartney and Wings"),
    (78, "Don't Let the Sun Go Down on Me", "Elton John"),
    (79, "Tubular Bells", "Mike Oldfield"),
    (80, "A Love Song", "Anne Murray"),
    (81, "I'm Leaving It Up to You", "Donny and Marie Osmond"),
    (82, "Hello It's Me", "Todd Rundgren"),
    (83, "I Love", "Tom T. Hall"),
    (84, "Clap for the Wolfman", "The Guess Who featuring Wolfman Jack"),
    (85, "I'll Have to Say I Love You in a Song", "Jim Croce"),
    (86, "The Lord's Prayer", "Sister Janet Mead"),
    (87, "Trying to Hold on to My Woman", "Lamont Dozier"),
    (88, "Don't You Worry 'bout a Thing", "Stevie Wonder"),
    (89, "A Very Special Love Song", "Charlie Rich"),
    (90, "My Girl Bill", "Jim Stafford"),
    (91, "Helen Wheels", "Paul McCartney and Wings"),
    (92, "My Mistake (Was to Love You)", "Diana Ross & Marvin Gaye"),
    (93, "Wildwood Weed", "Jim Stafford"),
    (94, "Beach Baby", "The First Class"),
    (95, "Me and Baby Brother", "War"),
    (96, "Rockin' Roll Baby", "The Stylistics"),
    (97, "I Honestly Love You", "Olivia Newton-John"),
    (98, "Call on Me", "Chicago"),
    (99, "Wild Thing", "Fancy"),
    (100, "Mighty Love", "The Spinners"),
]

SONGS_1975 = [
    (1, "Love Will Keep Us Together", "Captain & Tennille"),
    (2, "Rhinestone Cowboy", "Glen Campbell"),
    (3, "Philadelphia Freedom", "Elton John"),
    (4, "Before the Next Teardrop Falls", "Freddy Fender"),
    (5, "My Eyes Adored You", "Frankie Valli"),
    (6, "Some Kind of Wonderful", "Grand Funk Railroad"),
    (7, "Shining Star", "Earth, Wind & Fire"),
    (8, "Fame", "David Bowie"),
    (9, "Laughter in the Rain", "Neil Sedaka"),
    (10, "One of These Nights", "Eagles"),
    (11, "Thank God I'm a Country Boy", "John Denver"),
    (12, "Jive Talkin'", "Bee Gees"),
    (13, "Best of My Love", "Eagles"),
    (14, "Lovin' You", "Minnie Riperton"),
    (15, "Kung Fu Fighting", "Carl Douglas"),
    (16, "Black Water", "The Doobie Brothers"),
    (17, "The Ballroom Blitz", "Sweet"),
    (18, "(Hey Won't You Play) Another Somebody Done Somebody Wrong Song", "B.J. Thomas"),
    (19, "He Don't Love You (Like I Love You)", "Tony Orlando and Dawn"),
    (20, "At Seventeen", "Janis Ian"),
    (21, "Pick Up the Pieces", "Average White Band"),
    (22, "The Hustle", "Van McCoy & the Soul City Symphony"),
    (23, "Lady Marmalade", "Labelle"),
    (24, "Why Can't We Be Friends?", "War"),
    (25, "Love Won't Let Me Wait", "Major Harris"),
    (26, "Boogie On Reggae Woman", "Stevie Wonder"),
    (27, "Wasted Days and Wasted Nights", "Freddy Fender"),
    (28, "Angie Baby", "Helen Reddy"),
    (29, "Fight the Power", "The Isley Brothers"),
    (30, "Jackie Blue", "Ozark Mountain Daredevils"),
    (31, "Fire", "Ohio Players"),
    (32, "Magic", "Pilot"),
    (33, "Please Mr. Postman", "The Carpenters"),
    (34, "Sister Golden Hair", "America"),
    (35, "Lucy in the Sky with Diamonds", "Elton John"),
    (36, "Mandy", "Barry Manilow"),
    (37, "Have You Never Been Mellow", "Olivia Newton-John"),
    (38, "Could It Be Magic", "Barry Manilow"),
    (39, "Cat's in the Cradle", "Harry Chapin"),
    (40, "Wildfire", "Michael Martin Murphey"),
    (41, "I'm Not Lisa", "Jessi Colter"),
    (42, "Listen to What the Man Said", "Wings"),
    (43, "I'm Not in Love", "10cc"),
    (44, "I Can Help", "Billy Swan"),
    (45, "Fallin' in Love", "Hamilton, Joe Frank & Reynolds"),
    (46, "Feelings", "Morris Albert"),
    (47, "When Will I Be Loved", "Linda Ronstadt"),
    (48, "Chevy Van", "Sammy Johns"),
    (49, "You're the First, the Last, My Everything", "Barry White"),
    (50, "Please Mr. Please", "Olivia Newton-John"),
    (51, "You're No Good", "Linda Ronstadt"),
    (52, "Dynomite", "Bazuka"),
    (53, "Walking in Rhythm", "The Blackbyrds"),
    (54, "The Way We Were/Try to Remember", "Gladys Knight & the Pips"),
    (55, "Midnight Blue", "Melissa Manchester"),
    (56, "Don't Call Us, We'll Call You", "Sugarloaf"),
    (57, "Poetry Man", "Phoebe Snow"),
    (58, "How Long?", "Ace"),
    (59, "Express", "B.T. Express"),
    (60, "That's the Way of the World", "Earth, Wind & Fire"),
    (61, "Lady", "Styx"),
    (62, "Bad Time", "Grand Funk"),
    (63, "Only Women Bleed", "Alice Cooper"),
    (64, "Doctor's Orders", "Carol Douglas"),
    (65, "Get Down Tonight", "KC and the Sunshine Band"),
    (66, "One Man Woman/One Woman Man", "Paul Anka & Odia Coates"),
    (67, "You Are So Beautiful", "Joe Cocker"),
    (68, "Feel Like Makin' Love", "Bad Company"),
    (69, "How Sweet It Is (To Be Loved by You)", "James Taylor"),
    (70, "Dance with Me", "Orleans"),
    (71, "Cut the Cake", "Average White Band"),
    (72, "Never Can Say Goodbye", "Gloria Gaynor"),
    (73, "I Don't Like to Sleep Alone", "Paul Anka & Odia Coates"),
    (74, "Morning Side of the Mountain", "Donny & Marie Osmond"),
    (75, "When Will I See You Again", "The Three Degrees"),
    (76, "Get Down, Get Down (Get on the Floor)", "Joe Simon"),
    (77, "I'm Sorry", "John Denver"),
    (78, "Killer Queen", "Queen"),
    (79, "Shoeshine Boy", "Eddie Kendricks"),
    (80, "Do It ('Til You're Satisfied)", "B.T. Express"),
    (81, "Can't Get It Out of My Head", "Electric Light Orchestra"),
    (82, "Sha-La-La (Make Me Happy)", "Al Green"),
    (83, "Lonely People", "America"),
    (84, "You Got the Love", "Rufus"),
    (85, "The Rockford Files Theme", "Mike Post"),
    (86, "It Only Takes a Minute", "Tavares"),
    (87, "No No Song", "Ringo Starr"),
    (88, "Junior's Farm", "Paul McCartney & Wings"),
    (89, "Bungle in the Jungle", "Jethro Tull"),
    (90, "Long Tall Glasses (I Can Dance)", "Leo Sayer"),
    (91, "Misty", "Ray Stevens"),
    (92, "Someone Saved My Life Tonight", "Elton John"),
    (93, "Bad Blood", "Neil Sedaka"),
    (94, "Only Yesterday", "The Carpenters"),
    (95, "I'm on Fire", "Dwight Twilley Band"),
    (96, "Only You (And You Alone)", "Ringo Starr"),
    (97, "Third Rate Romance", "Amazing Rhythm Aces"),
    (98, "You Ain't Seen Nothing Yet", "Bachman-Turner Overdrive"),
    (99, "Swearin' to God", "Frankie Valli"),
    (100, "Get Dancin'", "Disco-Tex and the Sex-O-Lettes"),
]

SONGS_1976 = [
    (1, "Silly Love Songs", "Wings"),
    (2, "Don't Go Breaking My Heart", "Elton John & Kiki Dee"),
    (3, "Disco Lady", "Johnnie Taylor"),
    (4, "December, 1963 (Oh, What a Night)", "The Four Seasons"),
    (5, "Play That Funky Music", "Wild Cherry"),
    (6, "Kiss and Say Goodbye", "The Manhattans"),
    (7, "Love Machine", "The Miracles"),
    (8, "50 Ways to Leave Your Lover", "Paul Simon"),
    (9, "Love Is Alive", "Gary Wright"),
    (10, "A Fifth of Beethoven", "Walter Murphy & The Big Apple Band"),
    (11, "Sara Smile", "Hall & Oates"),
    (12, "Afternoon Delight", "Starland Vocal Band"),
    (13, "I Write the Songs", "Barry Manilow"),
    (14, "Fly, Robin, Fly", "Silver Convention"),
    (15, "Love Hangover", "Diana Ross"),
    (16, "Get Closer", "Seals and Crofts"),
    (17, "More, More, More", "Andrea True Connection"),
    (18, "Bohemian Rhapsody", "Queen"),
    (19, "Misty Blue", "Dorothy Moore"),
    (20, "Boogie Fever", "The Sylvers"),
    (21, "I'd Really Love to See You Tonight", "England Dan & John Ford Coley"),
    (22, "You Sexy Thing", "Hot Chocolate"),
    (23, "Love Hurts", "Nazareth"),
    (24, "Get Up and Boogie", "Silver Convention"),
    (25, "Take It to the Limit", "Eagles"),
    (26, "(Shake, Shake, Shake) Shake Your Booty", "KC and the Sunshine Band"),
    (27, "Sweet Love", "Commodores"),
    (28, "Right Back Where We Started From", "Maxine Nightingale"),
    (29, "Theme from S.W.A.T.", "Rhythm Heritage"),
    (30, "Love Rollercoaster", "Ohio Players"),
    (31, "You Should Be Dancing", "Bee Gees"),
    (32, "You'll Never Find Another Love Like Mine", "Lou Rawls"),
    (33, "Golden Years", "David Bowie"),
    (34, "Moonlight Feels Right", "Starbuck"),
    (35, "Only Sixteen", "Dr. Hook"),
    (36, "Let Your Love Flow", "The Bellamy Brothers"),
    (37, "Dream Weaver", "Gary Wright"),
    (38, "Turn the Beat Around", "Vicki Sue Robinson"),
    (39, "Lonely Night (Angel Face)", "Captain & Tennille"),
    (40, "All by Myself", "Eric Carmen"),
    (41, "Love to Love You Baby", "Donna Summer"),
    (42, "Deep Purple", "Donny & Marie Osmond"),
    (43, "Theme from Mahogany (Do You Know Where You're Going To)", "Diana Ross"),
    (44, "Sweet Thing", "Rufus"),
    (45, "That's the Way (I Like It)", "KC and the Sunshine Band"),
    (46, "A Little Bit More", "Dr. Hook"),
    (47, "Shannon", "Henry Gross"),
    (48, "If You Leave Me Now", "Chicago"),
    (49, "Lowdown", "Boz Scaggs"),
    (50, "Show Me the Way", "Peter Frampton"),
    (51, "Dream On", "Aerosmith"),
    (52, "I Love Music", "The O'Jays"),
    (53, "Say You Love Me", "Fleetwood Mac"),
    (54, "Times of Your Life", "Paul Anka"),
    (55, "Devil Woman", "Cliff Richard"),
    (56, "Fooled Around and Fell in Love", "Elvin Bishop"),
    (57, "Convoy", "C. W. McCall"),
    (58, "Welcome Back", "John Sebastian"),
    (59, "Sing a Song", "Earth, Wind & Fire"),
    (60, "Heaven Must Be Missing an Angel", "Tavares"),
    (61, "I'll Be Good to You", "The Brothers Johnson"),
    (62, "Rock and Roll Music", "The Beach Boys"),
    (63, "Shop Around", "Captain & Tennille"),
    (64, "Saturday Night", "Bay City Rollers"),
    (65, "Island Girl", "Elton John"),
    (66, "Let's Do It Again", "The Staple Singers"),
    (67, "Let 'Em In", "Wings"),
    (68, "Baby Face", "Wing and a Prayer Fife and Drum Corps"),
    (69, "This Masquerade", "George Benson"),
    (70, "Evil Woman", "Electric Light Orchestra"),
    (71, "Wham Bam", "Silver"),
    (72, "I'm Easy", "Keith Carradine"),
    (73, "Wake Up Everybody", "Harold Melvin & the Blue Notes"),
    (74, "Summer", "War"),
    (75, "Let Her In", "John Travolta"),
    (76, "Fox on the Run", "Sweet"),
    (77, "Rhiannon", "Fleetwood Mac"),
    (78, "Got to Get You into My Life", "The Beatles"),
    (79, "Fanny (Be Tender with My Love)", "Bee Gees"),
    (80, "Getaway", "Earth, Wind & Fire"),
    (81, "She's Gone", "Hall & Oates"),
    (82, "Still the One", "Orleans"),
    (83, "You're My Best Friend", "Queen"),
    (84, "With Your Love", "Jefferson Starship"),
    (85, "Slow Ride", "Foghat"),
    (86, "Who'd She Coo?", "Ohio Players"),
    (87, "The Boys Are Back in Town", "Thin Lizzy"),
    (88, "Walk Away from Love", "David Ruffin"),
    (89, "Baby, I Love Your Way (Live)", "Peter Frampton"),
    (90, "Young Hearts Run Free", "Candi Staton"),
    (91, "Breaking Up Is Hard to Do", "Neil Sedaka"),
    (92, "Money Honey", "Bay City Rollers"),
    (93, "Give Up the Funk (Tear the Roof off the Sucker)", "Parliament"),
    (94, "Junk Food Junkie", "Larry Groce"),
    (95, "Tryin' to Get the Feeling Again", "Barry Manilow"),
    (96, "Rock and Roll All Nite", "Kiss"),
    (97, "Disco Duck", "Rick Dees & His Cast of Idiots"),
    (98, "Take the Money and Run", "Steve Miller Band"),
    (99, "Squeeze Box", "The Who"),
    (100, "Country Boy (You Got Your Feet in L.A.)", "Glen Campbell"),
]

ALL_SONGS = {
    1973: SONGS_1973,
    1974: SONGS_1974,
    1975: SONGS_1975,
    1976: SONGS_1976,
}


def clean_artist_name(artist: str) -> str:
    """Extract the main artist name from collaboration strings."""
    patterns = [
        r'\s+featuring\s+.*',
        r'\s+feat\.\s+.*',
        r'\s+ft\.\s+.*',
        r'\s+and\s+.*',
        r'\s+with\s+.*',
        r'\s+&\s+.*',
        r'\s+\(.*\)',
    ]

    cleaned = artist
    for pattern in patterns:
        cleaned = re.sub(pattern, '', cleaned, flags=re.IGNORECASE)

    return cleaned.strip()


def search_youtube_video(title: str, artist: str, year: int) -> Tuple[Optional[str], Optional[str]]:
    """
    Search YouTube for the best music video using multiple strategies for 1970s content.

    Returns:
        Tuple of (video_url, video_title) or (None, None) if not found
    """
    # Multiple search queries to try, in order of preference
    search_queries = [
        f"{title} {artist} official music video",
        f"{title} {artist} official video",
        f"{title} {artist} music video",
        f"{title} {artist} {year}",
        f"{title} {artist}",
    ]

    # For 1970s, VEVO and official artist channels often have remastered versions
    clean_artist = clean_artist_name(artist)
    if clean_artist != artist:
        search_queries.insert(2, f"{title} {clean_artist} official video")

    for query in search_queries:
        base_url = "https://www.googleapis.com/youtube/v3/search"
        params = {
            'part': 'snippet',
            'type': 'video',
            'q': query,
            'maxResults': 5,  # Get top 5 results to filter
            'key': YOUTUBE_API_KEY,
            'videoCategoryId': '10',  # Music category
        }

        url = f"{base_url}?{urllib.parse.urlencode(params)}"

        try:
            req = urllib.request.Request(url)
            with urllib.request.urlopen(req, timeout=10, context=ssl_context) as response:
                data = json.loads(response.read().decode())

                if 'items' in data and len(data['items']) > 0:
                    # Prioritize results from official-looking channels
                    for item in data['items']:
                        channel_title = item['snippet']['channelTitle'].lower()
                        video_title = item['snippet']['title'].lower()

                        # Skip if it looks like a cover or tribute
                        skip_keywords = ['cover', 'tribute', 'karaoke', 'instrumental only', 'reaction', 'reacting']
                        if any(kw in video_title for kw in skip_keywords):
                            continue

                        # Prefer official channels
                        official_indicators = ['vevo', 'official', artist.lower().split()[0], clean_artist.lower().split()[0]]
                        is_official = any(ind in channel_title for ind in official_indicators)

                        video_id = item['id']['videoId']
                        video_url = f"https://www.youtube.com/watch?v={video_id}"
                        actual_title = item['snippet']['title']

                        if is_official:
                            return video_url, actual_title

                    # If no official channel found, use first non-cover result
                    for item in data['items']:
                        video_title = item['snippet']['title'].lower()
                        skip_keywords = ['cover', 'tribute', 'karaoke', 'instrumental only', 'reaction']
                        if any(kw in video_title for kw in skip_keywords):
                            continue

                        video_id = item['id']['videoId']
                        video_url = f"https://www.youtube.com/watch?v={video_id}"
                        actual_title = item['snippet']['title']
                        return video_url, actual_title

        except urllib.error.HTTPError as e:
            if e.code == 403:
                print(f"  ⚠️  API quota exceeded or access denied")
                return None, "QUOTA_EXCEEDED"
            print(f"  ❌ HTTP error {e.code}: {str(e)}")
        except Exception as e:
            print(f"  ❌ Search error: {str(e)}")

        # Small delay between search attempts
        time.sleep(0.3)

    return None, None


def add_to_airtable(record_data: Dict) -> Tuple[bool, str]:
    """Add a record to Airtable MTvVideosNEW table."""
    url = f"https://api.airtable.com/v0/{AIRTABLE_BASE_ID}/{AIRTABLE_TABLE_ID}"

    payload = json.dumps({'fields': record_data}).encode('utf-8')

    try:
        req = urllib.request.Request(url, data=payload, method='POST')
        req.add_header('Authorization', f'Bearer {AIRTABLE_API_KEY}')
        req.add_header('Content-Type', 'application/json')

        with urllib.request.urlopen(req, timeout=10, context=ssl_context) as response:
            data = json.loads(response.read().decode())
            return True, data.get('id', 'success')
    except urllib.error.HTTPError as e:
        try:
            error_body = e.read().decode()
            error_detail = json.loads(error_body)
            return False, f"HTTP {e.code}: {error_detail}"
        except:
            return False, f"HTTP {e.code}: {str(e)}"
    except Exception as e:
        return False, str(e)


def process_year(year: int, start_rank: int = 1, end_rank: int = 100) -> Dict:
    """
    Process songs for a specific year.

    Args:
        year: Year to process (1973-1976)
        start_rank: Starting rank (1-100)
        end_rank: Ending rank (1-100)

    Returns:
        Results dict with successful, failed, and not_found lists
    """
    if year not in ALL_SONGS:
        print(f"❌ Invalid year: {year}. Valid years are 1973-1976.")
        return {'successful': [], 'failed': [], 'not_found': [], 'quota_exceeded': False}

    songs = ALL_SONGS[year]
    # Filter by rank range
    songs = [(r, t, a) for r, t, a in songs if start_rank <= r <= end_rank]

    results = {
        'successful': [],
        'failed': [],
        'not_found': [],
        'quota_exceeded': False
    }

    print(f"\n🎵 Processing {year} songs (ranks {start_rank}-{end_rank})...")
    print(f"📊 Total songs to process: {len(songs)}\n")

    for i, (rank, title, artist) in enumerate(songs, 1):
        print(f"[{i}/{len(songs)}] {rank}. {title} - {artist}")

        # Search for YouTube video
        video_url, video_title = search_youtube_video(title, artist, year)

        if video_title == "QUOTA_EXCEEDED":
            print(f"\n⛔ API quota exceeded. Stopping processing.")
            results['quota_exceeded'] = True
            break

        if not video_url:
            print(f"  ⚠️  No suitable video found")
            results['not_found'].append({
                'rank': rank,
                'title': title,
                'artist': artist,
                'year': year
            })
            time.sleep(0.5)
            continue

        print(f"  ✅ Found: {video_title}")
        print(f"  🔗 {video_url}")

        # Clean artist name
        cleaned_artist = clean_artist_name(artist)

        # Prepare Airtable record
        record_data = {
            'title': title,
            'url': video_url,
            'Rank': rank,
            'artistName': cleaned_artist,
            'Year': str(year)  # Note: capital 'Year' as string, based on working scripts
        }

        # Add to Airtable
        success, response = add_to_airtable(record_data)

        if success:
            print(f"  ✅ Added to Airtable (ID: {response})")
            results['successful'].append({
                'rank': rank,
                'title': title,
                'artist': artist,
                'video_url': video_url,
                'airtable_id': response
            })
        else:
            print(f"  ❌ Airtable error: {response}")
            results['failed'].append({
                'rank': rank,
                'title': title,
                'artist': artist,
                'video_url': video_url,
                'error': response
            })

        print()

        # Rate limiting
        time.sleep(1.5)

    return results


def print_summary(all_results: Dict[int, Dict]):
    """Print a summary of all processing results."""
    print("\n" + "=" * 70)
    print("📊 PROCESSING SUMMARY")
    print("=" * 70)

    total_successful = 0
    total_not_found = 0
    total_failed = 0

    for year, results in sorted(all_results.items()):
        successful = len(results['successful'])
        not_found = len(results['not_found'])
        failed = len(results['failed'])

        total_successful += successful
        total_not_found += not_found
        total_failed += failed

        print(f"\n📅 {year}:")
        print(f"   ✅ Successfully added: {successful}")
        print(f"   ⚠️  No video found: {not_found}")
        print(f"   ❌ Failed to add: {failed}")

        if results.get('quota_exceeded'):
            print(f"   ⛔ Processing stopped due to quota limit")

    print(f"\n{'=' * 70}")
    print(f"📈 TOTALS:")
    print(f"   ✅ Successfully added: {total_successful}")
    print(f"   ⚠️  No video found: {total_not_found}")
    print(f"   ❌ Failed to add: {total_failed}")
    print("=" * 70)

    # List songs not found
    all_not_found = []
    for year, results in sorted(all_results.items()):
        all_not_found.extend(results['not_found'])

    if all_not_found:
        print(f"\n⚠️  Songs with no suitable video found ({len(all_not_found)}):")
        print("-" * 70)
        for song in all_not_found:
            print(f"  {song['year']} #{song['rank']}: {song['title']} - {song['artist']}")


def main():
    """Main entry point."""
    print("🎸 1973-1976 Billboard Hot 100 Video Collector")
    print("=" * 70)

    # Parse command line arguments
    years_to_process = [1973, 1974, 1975, 1976]
    start_rank = 1
    end_rank = 100

    if len(sys.argv) > 1:
        # Can specify years like: python script.py 1973 1974
        # Or single year: python script.py 1975
        try:
            years_to_process = [int(y) for y in sys.argv[1:] if y.isdigit() and 1973 <= int(y) <= 1976]
            if not years_to_process:
                years_to_process = [1973, 1974, 1975, 1976]
        except:
            pass

    print(f"\n📅 Years to process: {years_to_process}")
    print(f"📊 Rank range: {start_rank}-{end_rank}")

    all_results = {}

    for year in years_to_process:
        results = process_year(year, start_rank, end_rank)
        all_results[year] = results

        # Check if we hit quota limit
        if results.get('quota_exceeded'):
            print(f"\n⛔ Stopping due to API quota limit")
            break

        # Save intermediate results
        output_file = f"/Users/aaron/Documents/GitHub/HIt Rewind2 iOS/{year}_processing_results.json"
        with open(output_file, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"\n💾 Saved {year} results to: {output_file}")

        # Pause between years
        if year != years_to_process[-1]:
            print(f"\n⏸️  Pausing 5 seconds before next year...")
            time.sleep(5)

    # Print final summary
    print_summary(all_results)

    # Save complete results
    output_file = "/Users/aaron/Documents/GitHub/HIt Rewind2 iOS/1973_1976_complete_results.json"
    with open(output_file, 'w') as f:
        json.dump(all_results, f, indent=2)
    print(f"\n💾 Complete results saved to: {output_file}")


if __name__ == "__main__":
    main()
