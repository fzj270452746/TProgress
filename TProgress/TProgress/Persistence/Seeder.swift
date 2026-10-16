import Foundation
import CoreData

/// Fills a fresh store with a lived-in community: circles, check-ins, recaps,
/// posts with media, threads and message history. Runs once — an existing store
/// is left exactly as the user left it.
enum Seeder {

    // MARK: - Entry

    static func seedIfNeeded() {
        let stack = CoreDataStack.shared
        guard stack.count(CDUser.self) == 0 else { return }
        seed(into: stack.context)
        stack.save()
    }

    // MARK: - People

    private struct SeedPerson {
        let username: String
        let displayName: String
        let bio: String
        let seed: Int64
        let friendState: FriendState
        let streak: Int32
        let checkIns: Int32
        let followsMe: Bool
        let iFollow: Bool
    }

    private static let people: [SeedPerson] = [
        SeedPerson(username: "mira.k", displayName: "Mira Kovač",
                   bio: "Bus reader. Morning pages. Two books behind and fine with it.",
                   seed: 11, friendState: .friends, streak: 34, checkIns: 212,
                   followsMe: true, iFollow: true),
        SeedPerson(username: "jonas_v", displayName: "Jonas Vestberg",
                   bio: "Piano, badly, daily. Week six of the same four bars.",
                   seed: 24, friendState: .friends, streak: 41, checkIns: 268,
                   followsMe: true, iFollow: true),
        SeedPerson(username: "nadia", displayName: "Nadia Osei",
                   bio: "Lake swimmer. Reads aloud to a seven year old critic.",
                   seed: 37, friendState: .friends, streak: 19, checkIns: 131,
                   followsMe: true, iFollow: true),
        SeedPerson(username: "elenap", displayName: "Elena Petrova",
                   bio: "200 words before sunrise, most days.",
                   seed: 52, friendState: .requested, streak: 12, checkIns: 88,
                   followsMe: false, iFollow: true),
        SeedPerson(username: "tomasr", displayName: "Tomás Rivera",
                   bio: "Studio hours. Cold hands, warm ideas.",
                   seed: 65, friendState: .incoming, streak: 27, checkIns: 174,
                   followsMe: true, iFollow: false),
        SeedPerson(username: "deshawn", displayName: "DeShawn Miller",
                   bio: "Runs in bad weather. One page a day, longhand.",
                   seed: 78, friendState: .none, streak: 8, checkIns: 63,
                   followsMe: false, iFollow: false),
        SeedPerson(username: "arjun", displayName: "Arjun Mehta",
                   bio: "Slow reader. Re-reads pages on purpose.",
                   seed: 91, friendState: .none, streak: 23, checkIns: 150,
                   followsMe: true, iFollow: false),
        SeedPerson(username: "sofia", displayName: "Sofia Lindqvist",
                   bio: "Scales, then one hard bar. Slow group on Saturdays.",
                   seed: 104, friendState: .none, streak: 16, checkIns: 97,
                   followsMe: false, iFollow: false),
        SeedPerson(username: "kenji", displayName: "Kenji Watanabe",
                   bio: "Pots. Most of them get thrown out. That's the ratio.",
                   seed: 117, friendState: .none, streak: 31, checkIns: 205,
                   followsMe: true, iFollow: false),
        SeedPerson(username: "harriet", displayName: "Harriet Boyle",
                   bio: "Outlines on trains. Plays the bridge badly.",
                   seed: 130, friendState: .none, streak: 6, checkIns: 41,
                   followsMe: false, iFollow: false),
        SeedPerson(username: "priya", displayName: "Priya Raman",
                   bio: "Fourth attempt at the same glaze. Closer every time.",
                   seed: 143, friendState: .none, streak: 22, checkIns: 143,
                   followsMe: true, iFollow: false),
        SeedPerson(username: "marcus", displayName: "Marcus Bell",
                   bio: "Twenty seconds in the lake. Sends drafts to two people.",
                   seed: 156, friendState: .none, streak: 5, checkIns: 34,
                   followsMe: false, iFollow: false)
    ]

    /// The account the reviewer signs in with. Created here so its shelf is not
    /// empty the first time they open My Works.
    static let primaryUsername = "test"

    // MARK: - Circles

    private struct SeedHabit {
        let name: String
        let blurb: String
        let symbol: String
        let accentIndex: Int32
        let members: Int32
        let cadence: String
        let category: String
        let joined: Bool
        let progress: Double
        let streak: Int32
        let totalMinutes: Int32
        let seed: Int64
    }

    private static let habits: [SeedHabit] = [
        SeedHabit(name: "Morning Pages", blurb: "Three pages before the world wakes up.",
                  symbol: "square.and.pencil", accentIndex: 0, members: 4820,
                  cadence: "Daily", category: "Writing", joined: true,
                  progress: 0.82, streak: 34, totalMinutes: 1240, seed: 201),
        SeedHabit(name: "Deep Reading", blurb: "Twenty pages. No screens, no skimming.",
                  symbol: "book.closed", accentIndex: 1, members: 7310,
                  cadence: "Daily", category: "Reading", joined: true,
                  progress: 0.64, streak: 19, totalMinutes: 890, seed: 202),
        SeedHabit(name: "Piano Practice", blurb: "Scales first, then the one hard bar.",
                  symbol: "pianokeys", accentIndex: 2, members: 2140,
                  cadence: "Weekdays", category: "Music", joined: true,
                  progress: 0.55, streak: 41, totalMinutes: 1620, seed: 203),
        SeedHabit(name: "Trail Miles", blurb: "Five kilometres. Any pace, any weather.",
                  symbol: "figure.run", accentIndex: 3, members: 5940,
                  cadence: "4× a week", category: "Movement", joined: true,
                  progress: 0.71, streak: 12, totalMinutes: 2180, seed: 204),
        SeedHabit(name: "Cold Plunge", blurb: "Two minutes. That is the whole ask.",
                  symbol: "snowflake", accentIndex: 4, members: 1180,
                  cadence: "3× a week", category: "Recovery", joined: false,
                  progress: 0.28, streak: 4, totalMinutes: 96, seed: 205),
        SeedHabit(name: "Studio Hours", blurb: "Show up to the work, even when it is dull.",
                  symbol: "paintbrush.pointed", accentIndex: 5, members: 3320,
                  cadence: "Daily", category: "Craft", joined: false,
                  progress: 0.47, streak: 27, totalMinutes: 3040, seed: 206),
        SeedHabit(name: "Language Drill", blurb: "Ten minutes on the same two hundred words.",
                  symbol: "character.book.closed", accentIndex: 1, members: 4260,
                  cadence: "Daily", category: "Language", joined: false,
                  progress: 0.36, streak: 16, totalMinutes: 610, seed: 207),
        SeedHabit(name: "Gratitude Log", blurb: "Three lines before bed. No performance.",
                  symbol: "heart.text.square", accentIndex: 3, members: 2870,
                  cadence: "Daily", category: "Reflection", joined: false,
                  progress: 0.58, streak: 23, totalMinutes: 340, seed: 208),
        SeedHabit(name: "Lights Out", blurb: "Screens down at eleven. Every single night.",
                  symbol: "moon.stars", accentIndex: 5, members: 6450,
                  cadence: "Nightly", category: "Recovery", joined: false,
                  progress: 0.43, streak: 8, totalMinutes: 0, seed: 209),
        SeedHabit(name: "Kitchen Table", blurb: "Cook one real meal, however plain.",
                  symbol: "fork.knife", accentIndex: 2, members: 1930,
                  cadence: "4× a week", category: "Craft", joined: false,
                  progress: 0.51, streak: 11, totalMinutes: 780, seed: 210)
    ]

    // MARK: - Posts

    private struct SeedPost {
        let author: String
        let text: String
        let kind: PostKind
        let topic: String
        let habit: String?
        let amount: Double
        let unit: String
        let minutes: Int32
        let media: Int
        let video: Bool
        let likes: Int32
        let ageHours: Int
        let likedByMe: Bool
    }

    /// At most one video post per topic: a shipped clip is addressed by topic
    /// name, so a second video post in the same topic would play the same
    /// footage twice on one page. Everything else carries stills.
    private static let posts: [SeedPost] = [
        SeedPost(author: "mira.k",
                 text: "Five pages of The Idiot on the bus before work. Half asleep, but the streak survives. That was the entire goal today.",
                 kind: .progress, topic: "reading", habit: "Deep Reading",
                 amount: 5, unit: "pages", minutes: 12, media: 1, video: false,
                 likes: 128, ageHours: 2, likedByMe: true),

        SeedPost(author: "jonas_v",
                 text: "Ten minutes at the piano. Same four bars, over and over. My left hand finally stopped fighting me.",
                 kind: .progress, topic: "music", habit: "Piano Practice",
                 amount: 10, unit: "min", minutes: 10, media: 1, video: true,
                 likes: 214, ageHours: 5, likedByMe: false),

        SeedPost(author: "deshawn",
                 text: "3k in the rain. Slower than Tuesday. Still counts.",
                 kind: .checkIn, topic: "running", habit: "Trail Miles",
                 amount: 3, unit: "km", minutes: 22, media: 2, video: false,
                 likes: 96, ageHours: 7, likedByMe: false),

        SeedPost(author: "elenap",
                 text: "Wrote 200 words before the sun came up. They are bad words, but they exist now, and yesterday they did not.",
                 kind: .progress, topic: "writing", habit: "Morning Pages",
                 amount: 200, unit: "words", minutes: 25, media: 1, video: false,
                 likes: 342, ageHours: 9, likedByMe: true),

        SeedPost(author: "tomasr",
                 text: "Went to the studio with nothing. Sat there forty minutes. Left with one good idea and cold hands.",
                 kind: .progress, topic: "studio", habit: "Studio Hours",
                 amount: 40, unit: "min", minutes: 40, media: 3, video: false,
                 likes: 187, ageHours: 12, likedByMe: false),

        SeedPost(author: "nadia",
                 text: "Two minutes in the lake. That is the whole ask. Done before my brain caught up.",
                 kind: .checkIn, topic: "cold", habit: "Cold Plunge",
                 amount: 2, unit: "min", minutes: 2, media: 1, video: true,
                 likes: 421, ageHours: 14, likedByMe: false),

        SeedPost(author: "mira.k",
                 text: "30 days of morning pages: 8,400 words. Two of them were good. That is the trade and I would take it again.",
                 kind: .summary, topic: "summary", habit: "Morning Pages",
                 amount: 8400, unit: "words", minutes: 0, media: 2, video: false,
                 likes: 764, ageHours: 20, likedByMe: true),

        SeedPost(author: "arjun",
                 text: "Finished chapter twelve. Stopped fighting the urge to skim and read the whole thing twice instead.",
                 kind: .progress, topic: "reading", habit: "Deep Reading",
                 amount: 18, unit: "pages", minutes: 45, media: 1, video: false,
                 likes: 73, ageHours: 26, likedByMe: false),

        SeedPost(author: "sofia",
                 text: "Scales for fifteen minutes. Boring. Necessary. Nobody claps for scales.",
                 kind: .checkIn, topic: "music", habit: "Piano Practice",
                 amount: 15, unit: "min", minutes: 15, media: 1, video: false,
                 likes: 159, ageHours: 30, likedByMe: false),

        SeedPost(author: "kenji",
                 text: "First 10k since March. Walked the last kilometre and felt no shame about it at all.",
                 kind: .progress, topic: "running", habit: "Trail Miles",
                 amount: 10, unit: "km", minutes: 68, media: 2, video: false,
                 likes: 288, ageHours: 34, likedByMe: true),

        SeedPost(author: "harriet",
                 text: "Outlined three scenes on the train. None of them will survive the first draft, but the shape is there now.",
                 kind: .progress, topic: "writing", habit: "Morning Pages",
                 amount: 3, unit: "scenes", minutes: 35, media: 1, video: false,
                 likes: 112, ageHours: 38, likedByMe: false),

        SeedPost(author: "jonas_v",
                 text: "Week six recap: 62 minutes at the piano, up fourteen on week five. Slow is fine. Slow is the plan.",
                 kind: .summary, topic: "summary", habit: "Piano Practice",
                 amount: 62, unit: "min", minutes: 0, media: 1, video: false,
                 likes: 203, ageHours: 44, likedByMe: false),

        SeedPost(author: "priya",
                 text: "Two hours on the same glaze recipe. Fourth attempt. Closer than the third, which is all I asked for.",
                 kind: .progress, topic: "studio", habit: "Studio Hours",
                 amount: 120, unit: "min", minutes: 120, media: 3, video: false,
                 likes: 176, ageHours: 50, likedByMe: true),

        SeedPost(author: "marcus",
                 text: "Twenty seconds in the lake today. Not two minutes. Twenty seconds. I will take it and come back tomorrow.",
                 kind: .checkIn, topic: "cold", habit: "Cold Plunge",
                 amount: 20, unit: "sec", minutes: 1, media: 0, video: false,
                 likes: 389, ageHours: 55, likedByMe: false),

        SeedPost(author: "nadia",
                 text: "Read aloud to my kid for twelve minutes. She picked the book. I picked the voices. Best twelve minutes of the day.",
                 kind: .progress, topic: "reading", habit: "Deep Reading",
                 amount: 12, unit: "min", minutes: 12, media: 1, video: false,
                 likes: 512, ageHours: 61, likedByMe: true),

        SeedPost(author: "sofia",
                 text: "5k with the slow group. Chatted the whole way round. Best run this month and it was the slowest.",
                 kind: .checkIn, topic: "running", habit: "Trail Miles",
                 amount: 5, unit: "km", minutes: 39, media: 2, video: false,
                 likes: 145, ageHours: 70, likedByMe: false),

        SeedPost(author: "deshawn",
                 text: "One page. Longhand. My handwriting is getting worse and my sentences are getting shorter. Both feel like progress.",
                 kind: .progress, topic: "writing", habit: "Morning Pages",
                 amount: 1, unit: "page", minutes: 20, media: 2, video: false,
                 likes: 167, ageHours: 78, likedByMe: false),

        SeedPost(author: "harriet",
                 text: "Learned the bridge. It is four chords and it took me an hour. Posting it anyway.",
                 kind: .progress, topic: "music", habit: "Piano Practice",
                 amount: 60, unit: "min", minutes: 60, media: 1, video: false,
                 likes: 231, ageHours: 86, likedByMe: true),

        SeedPost(author: "elenap",
                 text: "90 days. I missed eleven days and I came back eleven times. That is the whole skill, and nobody puts it on a poster.",
                 kind: .summary, topic: "summary", habit: "Morning Pages",
                 amount: 90, unit: "days", minutes: 0, media: 1, video: false,
                 likes: 918, ageHours: 96, likedByMe: true),

        SeedPost(author: "kenji",
                 text: "Threw out six pots. Kept one. The ratio is improving, which is a strange thing to be proud of.",
                 kind: .progress, topic: "studio", habit: "Studio Hours",
                 amount: 7, unit: "pots", minutes: 180, media: 3, video: false,
                 likes: 254, ageHours: 104, likedByMe: false),

        SeedPost(author: "tomasr",
                 text: "Fifteen pages of Perec. Had to read page forty three times before it opened. Worth every one of them.",
                 kind: .progress, topic: "reading", habit: "Deep Reading",
                 amount: 15, unit: "pages", minutes: 50, media: 0, video: false,
                 likes: 88, ageHours: 116, likedByMe: false),

        SeedPost(author: "priya",
                 text: "Lake was six degrees. My hands did not work properly for ten minutes afterwards. Would do again.",
                 kind: .checkIn, topic: "cold", habit: "Cold Plunge",
                 amount: 2, unit: "min", minutes: 2, media: 1, video: false,
                 likes: 302, ageHours: 128, likedByMe: false),

        SeedPost(author: "marcus",
                 text: "Sent the draft to two people. Terrifying. Necessary. They have not replied yet and I have checked four times.",
                 kind: .progress, topic: "writing", habit: "Morning Pages",
                 amount: 2400, unit: "words", minutes: 0, media: 1, video: false,
                 likes: 476, ageHours: 140, likedByMe: true),

        SeedPost(author: "arjun",
                 text: "Rest day. Walked four kilometres instead of running. Legs already feel better than they did this morning.",
                 kind: .checkIn, topic: "running", habit: "Trail Miles",
                 amount: 4, unit: "km", minutes: 48, media: 1, video: false,
                 likes: 134, ageHours: 152, likedByMe: false)
    ]

    /// Posts the signed-in account already owns, so My Works is not empty.
    private static let myPosts: [SeedPost] = [
        SeedPost(author: primaryUsername,
                 text: "Six pages before the meeting. Not the twenty I promised myself, but I opened the book, which is the part I usually fail.",
                 kind: .progress, topic: "reading", habit: "Deep Reading",
                 amount: 6, unit: "pages", minutes: 15, media: 1, video: false,
                 likes: 41, ageHours: 16, likedByMe: false),

        SeedPost(author: primaryUsername,
                 text: "Twelve minutes of scales. My wrists hurt and I played the same bar eleven times. Logging it anyway.",
                 kind: .checkIn, topic: "music", habit: "Piano Practice",
                 amount: 12, unit: "min", minutes: 12, media: 0, video: false,
                 likes: 27, ageHours: 52, likedByMe: false),

        SeedPost(author: primaryUsername,
                 text: "Two weeks in. Fourteen days, nine of them logged. The gap is not the failure. The return is the practice.",
                 kind: .summary, topic: "summary", habit: "Morning Pages",
                 amount: 14, unit: "days", minutes: 0, media: 2, video: false,
                 likes: 88, ageHours: 120, likedByMe: false)
    ]

    // MARK: - Comments

    private static let commentTemplates: [String: [String]] = [
        "reading": [
            "Five pages on a bus is five pages. Respect.",
            "Which translation are you on? I keep bouncing between two.",
            "The half-asleep reading is where the good sentences land.",
            "This is the post that got me to pick my book back up tonight.",
            "Slow reads count double. Nobody believes me.",
            "Keeping the streak is the whole game. Well done."
        ],
        "music": [
            "The left hand is always the last to agree.",
            "Ten minutes is ten minutes. It compounds quietly.",
            "Four bars at a time is exactly how it goes.",
            "Post a clip when the tempo is up?",
            "Least glamorous, most important part of the whole thing.",
            "I have been on the same two bars for a week. Solidarity."
        ],
        "running": [
            "Rain runs hit different. Good work.",
            "Slower than Tuesday still beats the couch.",
            "Walking the last kilometre is just good pacing.",
            "Genuinely motivating, and I hate running.",
            "The streak is the point, not the split.",
            "Rest days are training. Took me years to believe that."
        ],
        "writing": [
            "Bad words that exist beat perfect words that do not.",
            "Sending the draft is the hard part. Good on you.",
            "Longhand changes the rhythm of the sentence. Keep it.",
            "Two hundred before sunrise is a real number.",
            "Three scenes is a good day's work.",
            "The shape surviving is what matters. The scenes can go."
        ],
        "cold": [
            "Two minutes is a long time in a lake.",
            "Six degrees is no joke. How long until your hands worked again?",
            "Twenty seconds counts. Walking in is the hard part.",
            "This is the one I cannot make myself do. Fair play.",
            "Respect. Genuinely. I lasted nine seconds."
        ],
        "studio": [
            "Keeping one out of seven is a good ratio.",
            "Fourth attempt is usually where it turns.",
            "Turning up with nothing is the actual practice.",
            "Cold hands, warm idea. Love this.",
            "The dull hours are the ones that show up in the work."
        ],
        "summary": [
            "Missed eleven, came back eleven. That is the skill nobody talks about.",
            "This recap is worth more than any streak screenshot.",
            "Up fourteen minutes week over week is real movement.",
            "Eight thousand words and two good ones is a fantastic trade.",
            "Reading this made me go and check my own log.",
            "The return is the practice. Saving this one."
        ]
    ]

    private static let genericComments: [String] = [
        "Logged and counted. This is how it is done.",
        "Small and repeatable beats big and occasional.",
        "Saving this for the next day I want to skip.",
        "The consistency here is the impressive part.",
        "Adding this to my own rotation. Thank you."
    ]

    // MARK: - Message history

    private struct SeedMessage {
        let mine: Bool
        let text: String
        let kind: MessageKind
        let minutesAgo: Int
    }

    private struct SeedThread {
        let peer: String
        let unread: Int32
        let messages: [SeedMessage]
    }

    private static let threads: [SeedThread] = [
        SeedThread(peer: "mira.k", unread: 2, messages: [
            SeedMessage(mine: false, text: "Did the pages this morning. Bus was late so I got two extra in.", kind: .text, minutesAgo: 260),
            SeedMessage(mine: true, text: "Late bus is a gift you did not ask for.", kind: .text, minutesAgo: 255),
            SeedMessage(mine: false, text: "Exactly. Trying to talk myself into the same trick tomorrow.", kind: .text, minutesAgo: 250),
            SeedMessage(mine: false, text: "Morning Pages · 3 pages", kind: .checkIn, minutesAgo: 48),
            SeedMessage(mine: false, text: "Logged it. Day 34. Did you get yours in?", kind: .text, minutesAgo: 46),
            SeedMessage(mine: false, text: "No pressure. Genuinely just asking.", kind: .text, minutesAgo: 45)
        ]),
        SeedThread(peer: "jonas_v", unread: 0, messages: [
            SeedMessage(mine: false, text: "Bridge is finally under my fingers. Four chords, one hour.", kind: .text, minutesAgo: 700),
            SeedMessage(mine: true, text: "An hour for four chords sounds about right honestly.", kind: .text, minutesAgo: 690),
            SeedMessage(mine: false, text: "It felt ridiculous. Then it felt good.", kind: .text, minutesAgo: 685),
            SeedMessage(mine: true, text: "Send it when you can play it without swearing.", kind: .text, minutesAgo: 680),
            SeedMessage(mine: false, text: "That might be a while. Piano Practice · 10 min", kind: .checkIn, minutesAgo: 300),
            SeedMessage(mine: false, text: "Day 41. Same four bars, better than yesterday.", kind: .text, minutesAgo: 298)
        ]),
        SeedThread(peer: "nadia", unread: 1, messages: [
            SeedMessage(mine: false, text: "Lake was six degrees this morning. My hands stopped working.", kind: .text, minutesAgo: 1500),
            SeedMessage(mine: true, text: "Six is genuinely dangerous. How long were you in?", kind: .text, minutesAgo: 1490),
            SeedMessage(mine: false, text: "Two minutes. Counted every second of them.", kind: .text, minutesAgo: 1485),
            SeedMessage(mine: true, text: "That is two minutes more than I managed.", kind: .text, minutesAgo: 1480),
            SeedMessage(mine: false, text: "Cold Plunge · 2 min", kind: .checkIn, minutesAgo: 1400),
            SeedMessage(mine: false, text: "Coming Saturday? The slow group runs at eight.", kind: .text, minutesAgo: 120)
        ])
    ]

    // MARK: - Asset naming
    //
    // Art is addressed by name. Nothing is bundled with the project, so every
    // lookup misses today and the procedural generator draws instead — drop the
    // matching image set into Assets.xcassets and it appears on the next launch
    // with no code change.

    static func avatarAsset(for username: String) -> String {
        "avatar_" + username
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }

    /// Numbered per topic, counting up across posts rather than within one, so
    /// no two posts in a topic land on the same frame.
    static func mediaAsset(for topic: String, number: Int) -> String {
        "media_\(topic)_\(number)"
    }

    static func videoAsset(for topic: String) -> String {
        "video_\(topic)_poster"
    }

    // MARK: - Building

    private static func seed(into context: NSManagedObjectContext) {
        var usersByUsername: [String: CDUser] = [:]

        for person in people {
            let user = CDUser(context: context)
            user.id = UUID()
            user.username = person.username
            user.displayName = person.displayName
            user.bio = person.bio
            user.avatarAssetName = Seeder.avatarAsset(for: person.username)
            user.avatarSeed = person.seed
            user.joinedAt = TPTime.daysAgo(Int(person.seed % 300) + 30)
            user.streak = person.streak
            user.totalCheckIns = person.checkIns
            user.isCurrentUser = false
            user.isFollowedByMe = person.iFollow
            user.followsMe = person.followsMe
            user.friendState = person.friendState
            user.isBlocked = false
            usersByUsername[person.username] = user
        }

        // The account the reviewer signs in with.
        let me = CDUser(context: context)
        me.id = UUID()
        me.username = primaryUsername
        me.displayName = "You"
        me.bio = "Six pages is a win. Twelve minutes is a win. Writing it down is the whole trick."
        me.avatarSeed = 7
        me.joinedAt = TPTime.daysAgo(148)
        me.streak = 9
        me.totalCheckIns = 118
        me.isCurrentUser = false
        me.isFollowedByMe = false
        me.followsMe = false
        me.friendState = .none
        me.isBlocked = false
        usersByUsername[primaryUsername] = me

        var habitsByTitle: [String: CDHabit] = [:]
        for template in habits {
            let habit = CDHabit(context: context)
            habit.id = UUID()
            habit.name = template.name
            habit.blurb = template.blurb
            habit.iconKey = template.symbol
            habit.accentIndex = template.accentIndex
            habit.memberCount = template.members
            habit.isJoined = template.joined
            habit.cadence = template.cadence
            habit.category = template.category
            habit.todayChecked = template.joined && template.progress > 0.5
            habit.progress = template.progress
            habit.streak = template.streak
            habit.totalMinutes = template.totalMinutes
            habit.seed = template.seed

            seedCheckIns(for: habit, streak: template.streak, context: context)
            // Stage recaps are not seeded any more. They are derived from the
            // log by `RecapService` on the first launch, which is why they can
            // describe the last 30 days rather than a fixed number written here.

            habitsByTitle[template.name] = habit
        }

        // Art is addressed per post, not per topic. Two people logging the same
        // habit still took different photographs, so every post draws the next
        // unused frame from its topic's pool rather than sharing the first one —
        // which is what made a thirteen-tile page repeat itself.
        var mediaCursorByTopic: [String: Int] = [:]

        for (index, template) in (posts + myPosts).enumerated() {
            guard let author = usersByUsername[template.author] else { continue }

            let mediaStart = mediaCursorByTopic[template.topic, default: 1]
            // A video post shows its clip, not a frame from the still pool, so
            // it must not consume a number the next still post would want.
            if !template.video {
                mediaCursorByTopic[template.topic] = mediaStart + template.media
            }

            makePost(
                template,
                author: author,
                habit: template.habit.flatMap { habitsByTitle[$0] },
                seed: Int64(900 + index * 13),
                mediaStart: mediaStart,
                isMine: template.author == primaryUsername,
                context: context
            )
        }

        for thread in threads {
            guard let peer = usersByUsername[thread.peer] else { continue }
            let conversation = CDConversation(context: context)
            conversation.id = UUID()
            conversation.peer = peer
            conversation.unreadCount = thread.unread
            conversation.isMuted = false

            var latest: Date?
            for template in thread.messages {
                let message = CDMessage(context: context)
                message.id = UUID()
                message.text = template.text
                message.isMine = template.mine
                message.kind = template.kind
                message.status = template.mine ? .read : .delivered
                message.createdAt = TPTime.minutesAgo(template.minutesAgo)
                message.conversation = conversation
                if latest == nil || (message.createdAt ?? .distantPast) > (latest ?? .distantPast) {
                    latest = message.createdAt
                }
            }

            conversation.lastMessageAt = latest ?? TPTime.hoursAgo(1)
            conversation.lastMessageText = conversation.sortedMessages.last?.body
        }
    }

    private static func makePost(
        _ template: SeedPost,
        author: CDUser,
        habit: CDHabit?,
        seed: Int64,
        mediaStart: Int,
        isMine: Bool,
        context: NSManagedObjectContext
    ) {
        let post = CDPost(context: context)
        post.id = UUID()
        post.text = template.text
        post.author = author
        post.createdAt = TPTime.hoursAgo(template.ageHours)
        post.kind = template.kind
        post.topicTag = template.habit
        post.habitName = template.habit
        post.amountValue = template.amount
        post.amountUnit = template.unit
        post.durationMinutes = template.minutes
        post.likeCount = template.likes
        post.giftCount = Int32(max(0, Int(template.likes) / 24))
        post.isLikedByMe = template.likedByMe
        post.isMine = isMine
        post.seed = seed

        for index in 0..<template.media {
            let media = CDMedia(context: context)
            media.id = UUID()
            media.order = Int32(index)
            media.seed = seed &+ Int64(index) &* 31
            let isVideo = template.video && index == 0
            media.assetName = isVideo
                ? Seeder.videoAsset(for: template.topic)
                : Seeder.mediaAsset(for: template.topic, number: mediaStart + index)
            media.kind = isVideo ? .video : .image
            media.durationSeconds = isVideo ? Double(18 + (seed % 90)) : 0
            media.caption = nil
            media.post = post
        }

        // Seeded threads arrive with a handful of replies already on them.
        let commentCount = template.media == 0 ? Int.random(in: 3...6) : Int.random(in: 3...6)
        let pool = commentTemplates[template.topic] ?? genericComments
        let authorPool = people.filter { $0.username != template.author }

        for index in 0..<commentCount {
            let comment = CDComment(context: context)
            comment.id = UUID()
            comment.post = post
            comment.text = pool[(index + Int(seed % 3)) % pool.count]
            comment.createdAt = (post.createdAt ?? Date()).addingTimeInterval(Double(600 * (index + 1)))
            comment.likeCount = Int32(Int.random(in: 0...34))
            comment.isLikedByMe = false
            comment.isMine = false

            if let person = authorPool.randomElement(),
               let commenter = fetchUser(person.username, in: context) {
                comment.author = commenter
            } else {
                comment.author = author
            }
        }
    }

    private static func fetchUser(_ username: String, in context: NSManagedObjectContext) -> CDUser? {
        let request = NSFetchRequest<CDUser>(entityName: "CDUser")
        request.predicate = NSPredicate(format: "username == %@", username)
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }

    private static func seedCheckIns(for habit: CDHabit, streak: Int32, context: NSManagedObjectContext) {
        let days = min(Int(streak) + 4, 26)
        guard days > 0 else { return }

        for offset in 0..<days {
            // Deliberate gaps: real logs are not perfect, and the recap depends on it.
            if offset > 3 && offset % 7 == 5 { continue }

            let checkIn = CDCheckIn(context: context)
            checkIn.id = UUID()
            checkIn.habit = habit
            checkIn.date = TPTime.daysAgo(offset)
            checkIn.amountValue = Double(Int.random(in: 8...40))
            checkIn.amountUnit = habit.category == "Reading" ? "pages" : "min"
            checkIn.isMine = true
            checkIn.note = ""
        }
    }

}
