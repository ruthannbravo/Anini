import Foundation
import AVFoundation

enum WordGender: String {
    case masculine = "masculin"
    case feminine  = "féminin"
}

struct WordForm {
    let label: String
    let value: String
}

struct FrenchWord {
    let word: String
    let type: String
    let gender: WordGender?
    let forms: [WordForm]
    let definition: String
    let example: String
    let exampleTranslation: String
    let exampleMasc: String?                 // alternate first-person example for masculine learners
    let practiceQuestions: [String]          // 7 items: index 0 = Sunday … 6 = Saturday
    let practiceListenPhrases: [String?]     // feminine/neutral spoken phrases (parallel to questions)
    let practiceListenPhrasesMasc: [String?] // masculine overrides; empty = no overrides needed

    init(
        word: String,
        type: String,
        gender: WordGender? = nil,
        forms: [WordForm],
        definition: String,
        example: String,
        exampleTranslation: String,
        exampleMasc: String? = nil,
        practiceQuestions: [String],
        practiceListenPhrases: [String?],
        practiceListenPhrasesMasc: [String?] = []
    ) {
        self.word = word
        self.type = type
        self.gender = gender
        self.forms = forms
        self.definition = definition
        self.example = example
        self.exampleTranslation = exampleTranslation
        self.exampleMasc = exampleMasc
        self.practiceQuestions = practiceQuestions
        self.practiceListenPhrases = practiceListenPhrases
        self.practiceListenPhrasesMasc = practiceListenPhrasesMasc
    }
}

final class FrenchWordService {
    static let shared = FrenchWordService()
    private init() {}

    private let synthesizer = AVSpeechSynthesizer()

    var currentWord: FrenchWord {
        let week = Calendar.current.component(.weekOfYear, from: Date())
        return words[week % words.count]
    }

    var todayPracticeQuestion: String {
        let day = Calendar.current.component(.weekday, from: Date()) - 1  // 0 = Sun
        let qs  = currentWord.practiceQuestions
        return qs[min(day, qs.count - 1)]
    }

    var allWords: [FrenchWord] { words }

    var todayListenPhrase: String? { resolvedListenPhrase() }

    func resolvedListenPhrase() -> String? {
        let day = Calendar.current.component(.weekday, from: Date()) - 1
        return listenPhrase(for: currentWord, practiceIndex: day)
    }

    func listenPhrase(for word: FrenchWord, practiceIndex: Int) -> String? {
        guard practiceIndex < word.practiceListenPhrases.count else { return nil }
        if WorkspaceConfig.shared.userGender == .masculine,
           practiceIndex < word.practiceListenPhrasesMasc.count,
           let mascPhrase = word.practiceListenPhrasesMasc[practiceIndex] {
            return mascPhrase
        }
        return word.practiceListenPhrases[practiceIndex]
    }

    func resolvedExample(for word: FrenchWord) -> String {
        if WorkspaceConfig.shared.userGender == .masculine, let masc = word.exampleMasc {
            return masc
        }
        return word.example
    }

    func speak() {
        speak(text: currentWord.word)
    }

    func speak(text: String, slow: Bool = false) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice           = AVSpeechSynthesisVoice(language: "fr-CA")
                                 ?? AVSpeechSynthesisVoice(language: "fr-FR")
        utterance.rate            = slow ? 0.1 : 0.38
        utterance.pitchMultiplier = 1.05
        synthesizer.speak(utterance)
    }

    // MARK: – Word list (rotates by ISO week number)

    private let words: [FrenchWord] = [
        FrenchWord(
            word: "flâner",
            type: "verbe",
            gender: nil,
            forms: [
                WordForm(label: "je",        value: "flâne"),
                WordForm(label: "tu",        value: "flânes"),
                WordForm(label: "il/elle",   value: "flâne"),
                WordForm(label: "nous",      value: "flânons"),
                WordForm(label: "vous",      value: "flânez"),
                WordForm(label: "ils/elles", value: "flânent"),
                WordForm(label: "p. passé",  value: "flâné"),
            ],
            definition: "To stroll leisurely with no particular destination",
            example: "J'aime flâner dans le Vieux-Montréal le dimanche.",
            exampleTranslation: "I love strolling through Old Montréal on Sundays.",
            practiceQuestions: [
                "Say 'flâner' out loud (flah-NAY). Picture yourself on a slow Sunday walk with nowhere to be — that's flâner. Hit the speaker button and repeat it!",
                "Try saying this: 'J'aime flâner.' It means 'I love to stroll.' Say it out loud — that's a full French sentence right there!",
                "Fill in the blank out loud: 'On Sunday I like to ________ in the park.' In French: 'J'aime ________ dans le parc le dimanche.'",
                "Next time you take a casual walk today with no rush, say to yourself: 'Je flâne.' Try it — you're already speaking French!",
                "Try sharing this with someone today: 'On flâne ce week-end?' It means 'Want to go for a stroll this weekend?' See if they're in!",
                "Use 'flâner' in one sentence — even mix it into English if you need to: 'I totally want to flâner through the market tomorrow.'",
                "Can you say 'She's strolling in the park' in French? Try: 'Elle flâne dans le parc.' Say it once slowly, then faster!"
            ],
            practiceListenPhrases: [
                "flâner",
                "J'aime flâner.",
                nil,
                "Je flâne.",
                "On flâne ce week-end?",
                nil,
                "Elle flâne dans le parc."
            ]
        ),
        FrenchWord(
            word: "le dépaysement",
            type: "nom masculin",
            gender: .masculine,
            forms: [
                WordForm(label: "singulier", value: "le dépaysement"),
                WordForm(label: "pluriel",   value: "les dépaysements"),
            ],
            definition: "The feeling of being in a foreign or unfamiliar place; a refreshing change of scene",
            example: "Ce voyage au Québec lui a procuré un dépaysement total.",
            exampleTranslation: "This trip to Québec gave him a complete change of scene.",
            practiceQuestions: [
                "Say 'dépaysement' (day-pay-EEZ-mahn). It's that specific feeling when you're somewhere totally unfamiliar and new. English has no single word for it — French does!",
                "Try saying: 'J'adore le dépaysement.' It means 'I love that feeling of being somewhere new.' Say it out loud!",
                "Fill in the blank: 'Travelling gives me a sense of ________.' In French: 'Le voyage me donne un sentiment de ________.'",
                "Think of the last time you felt dépaysement — a new city, a trip, even a new neighbourhood. Describe that moment to yourself, then drop the word in.",
                "Try this phrase today: 'J'ai besoin de dépaysement.' It means 'I need a change of scenery.' Say it when you're feeling restless!",
                "Tell a friend about a place that gave you dépaysement. Use the word when you describe how it felt.",
                "Try translating this: 'The trip gave me a real change of scene.' → 'Le voyage m'a donné un vrai dépaysement.' Say it once out loud!"
            ],
            practiceListenPhrases: [
                "le dépaysement",
                "J'adore le dépaysement.",
                nil,
                nil,
                "J'ai besoin de dépaysement.",
                nil,
                "Le voyage m'a donné un vrai dépaysement."
            ]
        ),
        FrenchWord(
            word: "chuchoter",
            type: "verbe",
            gender: nil,
            forms: [
                WordForm(label: "je",        value: "chuchote"),
                WordForm(label: "tu",        value: "chuchotes"),
                WordForm(label: "il/elle",   value: "chuchote"),
                WordForm(label: "nous",      value: "chuchotons"),
                WordForm(label: "vous",      value: "chuchotez"),
                WordForm(label: "ils/elles", value: "chuchotent"),
                WordForm(label: "p. passé",  value: "chuchoté"),
            ],
            definition: "To whisper",
            example: "Il a chuchoté quelque chose à son oreille et elle a souri.",
            exampleTranslation: "He whispered something in her ear and she smiled.",
            practiceQuestions: [
                "Say 'chuchoter' softly (shoo-sho-TAY) — it literally sounds like whispering. Say it in a whisper and notice how it fits! Hit the speaker button too.",
                "Try this: 'il a chuchoté' means 'he whispered.' Say it out loud. That's already a full past-tense sentence!",
                "Fill in the blank: 'Don't wake the baby — ________!' In French: 'Ne réveille pas le bébé — chuchote!'",
                "Next time you lower your voice today, think: 'Je chuchote.' You can even whisper it to yourself.",
                "Whisper something in French to yourself or someone nearby today. Even just: 'Je te chuchote quelque chose.' ('I'm whispering something to you.')",
                "Try: 'Why are you whispering?' → 'Pourquoi est-ce que tu chuchotes?' Say it out loud a couple of times.",
                "Can you say 'She whispered his name'? Try: 'Elle a chuchoté son prénom.' Say it slowly, then once more faster!"
            ],
            practiceListenPhrases: [
                "chuchoter",
                "Il a chuchoté.",
                "Ne réveille pas le bébé — chuchote!",
                "Je chuchote.",
                "Je te chuchote quelque chose.",
                "Pourquoi est-ce que tu chuchotes?",
                "Elle a chuchoté son prénom."
            ]
        ),
        FrenchWord(
            word: "épanoui(e)",
            type: "adjectif",
            gender: nil,
            forms: [
                WordForm(label: "masc. sg.", value: "épanoui"),
                WordForm(label: "fém. sg.",  value: "épanouie"),
                WordForm(label: "masc. pl.", value: "épanouis"),
                WordForm(label: "fém. pl.",  value: "épanouies"),
            ],
            definition: "Fulfilled, radiant, blossoming — used for people thriving in life",
            example: "Elle semble vraiment épanouie depuis qu'elle a changé de carrière.",
            exampleTranslation: "She seems truly fulfilled since she changed careers.",
            practiceQuestions: [
                "Say 'épanoui' (ay-pah-NWEE) — picture someone glowing because they've found exactly what they're meant to do. That radiant, fulfilled energy. Say it out loud!",
                "Try: 'Elle a l'air épanouie.' It means 'She looks so fulfilled.' Practice saying it — think of someone in your life it applies to.",
                "Fill in the blank: 'He seems really ________ since he started his new hobby.' In French: 'Il semble vraiment ________ depuis qu'il a commencé son passe-temps.'",
                "Think of one person in your life who is épanoui(e) right now. How would you describe them using this word? Say it out loud.",
                "Say this to yourself today: 'Je me sens épanouie.' It means 'I feel fulfilled.' How does it feel to say it?",
                "Try: 'She's really thriving lately.' → 'Elle est vraiment épanouie ces derniers temps.' Say it once — you've got this!",
                "Use 'épanoui(e)' today in a real sentence — compliment someone or describe a person who's doing really well in life."
            ],
            practiceListenPhrases: [
                "épanoui",
                "Elle a l'air épanouie.",
                nil,
                nil,
                "Je me sens épanouie.",
                "Elle est vraiment épanouie ces derniers temps.",
                nil
            ],
            practiceListenPhrasesMasc: [
                nil, nil, nil, nil,
                "Je me sens épanoui.",
                nil, nil
            ]
        ),
        FrenchWord(
            word: "se régaler",
            type: "verbe pronominal",
            gender: nil,
            forms: [
                WordForm(label: "je",        value: "me régale"),
                WordForm(label: "tu",        value: "te régales"),
                WordForm(label: "il/elle",   value: "se régale"),
                WordForm(label: "nous",      value: "nous régalons"),
                WordForm(label: "vous",      value: "vous régalez"),
                WordForm(label: "ils/elles", value: "se régalent"),
                WordForm(label: "p. passé",  value: "régalé(e)"),
            ],
            definition: "To treat oneself to something delicious; to thoroughly enjoy a meal or experience",
            example: "On s'est régalés au souper hier soir — c'était incroyable!",
            exampleTranslation: "We had a wonderful feast last night — it was incredible!",
            practiceQuestions: [
                "Say 'se régaler' (se ray-gah-LAY). It's what you say when you absolutely love a meal — more than 'it's good,' it's pure delight. Say it out loud!",
                "Try: 'Je me régale!' — say it the next time you eat something you love. It means 'I'm loving this!' Perfect at any meal.",
                "Fill in the blank at your next meal: 'On s'est ________!' It means 'We really enjoyed that feast!' Try saying it after dinner tonight.",
                "Next time you eat something great today, say it out loud: 'Je me régale!' Even alone — say it with feeling!",
                "Tell a friend about a recent great meal using this word: 'Je me suis régalé(e) when we ate at...' They'll love it.",
                "Try: 'We had an amazing dinner last night!' → 'On s'est régalés hier soir!' Say it once, then say it like you actually enjoyed it.",
                "Use 'se régaler' today — it doesn't have to be food. If you love a movie, a song, or a moment, 'Je me régale' works perfectly!"
            ],
            practiceListenPhrases: [
                "se régaler",
                "Je me régale!",
                "On s'est régalés!",
                "Je me régale!",
                nil,
                "On s'est régalés hier soir!",
                nil
            ]
        ),
        FrenchWord(
            word: "farfelu(e)",
            type: "adjectif",
            gender: nil,
            forms: [
                WordForm(label: "masc. sg.", value: "farfelu"),
                WordForm(label: "fém. sg.",  value: "farfelue"),
                WordForm(label: "masc. pl.", value: "farfelus"),
                WordForm(label: "fém. pl.",  value: "farfelues"),
            ],
            definition: "Wacky, eccentric, zany — describes ideas, plans, or people that are charmingly absurd",
            example: "Son idée était farfelue, mais ça a fonctionné!",
            exampleTranslation: "His idea was wacky, but it worked!",
            practiceQuestions: [
                "Say 'farfelu' (far-fe-LU) — it means charmingly wacky or eccentric. Think of someone who always has the most out-there ideas. Say it out loud!",
                "Try: 'C'est une idée farfelue!' — 'That's a wacky idea!' Say it — it's actually a fun compliment in French.",
                "Fill in the blank: 'His plan was ________, but it worked!' → 'Son plan était ________, mais ça a marché!'",
                "Think of something farfelu you or someone you know has done lately. Describe it using the word — even in English with 'farfelu' dropped in.",
                "Call someone's quirky idea 'farfelue' today — with a smile! It's a playful, affectionate word.",
                "Try: 'She's a bit eccentric.' → 'Elle est un peu farfelue.' Say it — sounds great, right?",
                "Use 'farfelu(e)' in a real sentence today. Describe a plan, a person, or even a dream you had!"
            ],
            practiceListenPhrases: [
                "farfelu",
                "C'est une idée farfelue!",
                nil,
                nil,
                "C'est une idée farfelue!",
                "Elle est un peu farfelue.",
                nil
            ]
        ),
        FrenchWord(
            word: "une aubaine",
            type: "nom féminin",
            gender: .feminine,
            forms: [
                WordForm(label: "singulier", value: "une aubaine"),
                WordForm(label: "pluriel",   value: "des aubaines"),
            ],
            definition: "A windfall, a stroke of luck, a great bargain or godsend",
            example: "Trouver cet appartement pas cher était une vraie aubaine.",
            exampleTranslation: "Finding that affordable apartment was a real windfall.",
            practiceQuestions: [
                "Say 'une aubaine' (oon oh-BEN) — that feeling when something amazing falls into your lap unexpectedly. A deal, a lucky break, a gift from the universe. Say it!",
                "Try exclaiming: 'Quelle aubaine!' — 'What a bargain! / What a stroke of luck!' Say it with energy — this is a phrase you can use all the time!",
                "Fill in the blank: 'Finding that apartment was a real ________.' → 'Trouver cet appartement était une vraie ________.'",
                "Think of your last lucky break — a sale, free tickets, an unexpected opportunity. Say: 'C'était une vraie aubaine!' about it.",
                "Next time something lucky happens today — even small — say out loud: 'Quelle aubaine!' Make it your go-to expression.",
                "Try: 'Getting those free tickets was such a stroke of luck.' → 'Avoir ces billets gratuits, c'était une vraie aubaine.' Say it!",
                "Use 'une aubaine' in a real sentence today about something good that happened this week — big or small."
            ],
            practiceListenPhrases: [
                "une aubaine",
                "Quelle aubaine!",
                nil,
                "C'était une vraie aubaine!",
                "Quelle aubaine!",
                "Avoir ces billets gratuits, c'était une vraie aubaine.",
                nil
            ]
        ),
        FrenchWord(
            word: "gourmand(e)",
            type: "adjectif / nom",
            gender: nil,
            forms: [
                WordForm(label: "masc. sg.", value: "gourmand"),
                WordForm(label: "fém. sg.",  value: "gourmande"),
                WordForm(label: "masc. pl.", value: "gourmands"),
                WordForm(label: "fém. pl.",  value: "gourmandes"),
            ],
            definition: "A food-lover who eats with great pleasure; someone who has a hearty appetite",
            example: "Je suis très gourmande — j'adore les desserts et les fromages!",
            exampleTranslation: "I really love food — I adore desserts and cheeses!",
            exampleMasc: "Je suis très gourmand — j'adore les desserts et les fromages!",
            practiceQuestions: [
                "Say 'gourmand' (goor-MAHN) — it means someone who truly loves eating. No shame, just joy. Are you a gourmand? Say it out loud!",
                "Try: 'Je suis gourmand(e).' — 'I'm a foodie / I love eating.' Say it like you mean it. It's a great thing to be in French culture!",
                "Fill in the blank: 'He ate the whole cake — he's so ________!' → 'Il a mangé tout le gâteau — il est tellement ________!'",
                "Think of your absolute favourite food. Say: 'Je suis gourmand(e) — j'adore...' and add your favourite food in French if you know it!",
                "Ask a friend today: 'Est-ce que tu es gourmand(e)?' — 'Are you a foodie?' See what they say!",
                "Try: 'Don't be greedy — save some for me!' → 'Ne sois pas gourmand(e) — laisse-m'en un peu!' Fun one to use at the dinner table.",
                "Use 'gourmand(e)' in a sentence today — describe yourself, someone you know, or a character from a show you watch."
            ],
            practiceListenPhrases: [
                "gourmand",
                "Je suis gourmande.",
                nil,
                nil,
                "Est-ce que tu es gourmand?",
                "Ne sois pas gourmand — laisse-m'en un peu!",
                nil
            ],
            practiceListenPhrasesMasc: [
                nil,
                "Je suis gourmand.",
                nil, nil, nil, nil, nil
            ]
        ),
        FrenchWord(
            word: "le coup de foudre",
            type: "nom masculin",
            gender: .masculine,
            forms: [
                WordForm(label: "singulier", value: "un coup de foudre"),
                WordForm(label: "pluriel",   value: "des coups de foudre"),
            ],
            definition: "Love at first sight (literally: a lightning bolt strike)",
            example: "Ce fut un vrai coup de foudre — ils ne se sont plus quittés.",
            exampleTranslation: "It was true love at first sight — they never left each other's side.",
            practiceQuestions: [
                "Say 'coup de foudre' (koo de FOOD-ruh) — literally 'lightning strike.' It's love at first sight. Say it out loud — it's one of the most beautiful phrases in French!",
                "Try: 'C'était un coup de foudre.' — 'It was love at first sight.' Can you think of a person or moment you fell for instantly?",
                "Fill in the blank: 'When he first saw her, it was ________ ________ ________.' Say it — 'ce fut un coup de foudre.'",
                "Think of something you fell in love with instantly — a city, a song, a dish. Tell the story and use 'coup de foudre' to describe that moment.",
                "Tell someone the story of a coup de foudre — yours or someone else's. Use the phrase when you describe that first moment!",
                "Try: 'They fell in love at first sight.' → 'Ce fut un coup de foudre entre eux.' Say it slowly, then say it like you're telling a story.",
                "Use 'coup de foudre' today in a sentence — romantic or not. Fell in love with a new restaurant? A new song? 'C'était un vrai coup de foudre!'"
            ],
            practiceListenPhrases: [
                "un coup de foudre",
                "C'était un coup de foudre.",
                "Ce fut un coup de foudre.",
                nil,
                nil,
                "Ce fut un coup de foudre entre eux.",
                nil
            ]
        ),
        FrenchWord(
            word: "se débrouiller",
            type: "verbe pronominal",
            gender: nil,
            forms: [
                WordForm(label: "je",        value: "me débrouille"),
                WordForm(label: "tu",        value: "te débrouilles"),
                WordForm(label: "il/elle",   value: "se débrouille"),
                WordForm(label: "nous",      value: "nous débrouillons"),
                WordForm(label: "vous",      value: "vous débrouillez"),
                WordForm(label: "ils/elles", value: "se débrouillent"),
                WordForm(label: "p. passé",  value: "débrouillé(e)"),
            ],
            definition: "To manage, to get by, to figure things out on one's own; to be resourceful",
            example: "Ne t'inquiète pas — je me débrouille toujours.",
            exampleTranslation: "Don't worry — I always find a way.",
            practiceQuestions: [
                "Say 'se débrouiller' (se day-broo-YAY) — it means figuring things out on your own, being resourceful. Very admired in French culture. Say it!",
                "Try: 'Je me débrouille.' — 'I manage / I get by.' Say it with confidence. It's one of the most useful phrases you can have!",
                "Fill in the blank: 'She doesn't speak much French but she ________.' → 'Elle parle peu français mais elle se débrouille très bien.'",
                "Next time you solve a problem on your own today, say to yourself: 'Je me débrouille!' It'll feel great.",
                "Say this out loud: 'Je me débrouille en français!' — 'I'm figuring out French!' Because you are!",
                "Try: 'He always finds a way.' → 'Il se débrouille toujours.' Say it once slowly, once at normal speed.",
                "Use 'se débrouiller' in a real sentence today — about yourself or anyone you know who's good at figuring things out."
            ],
            practiceListenPhrases: [
                "se débrouiller",
                "Je me débrouille.",
                "Elle se débrouille très bien.",
                "Je me débrouille!",
                "Je me débrouille en français!",
                "Il se débrouille toujours.",
                nil
            ]
        ),
        FrenchWord(
            word: "lumineux / lumineuse",
            type: "adjectif",
            gender: nil,
            forms: [
                WordForm(label: "masc. sg.", value: "lumineux"),
                WordForm(label: "fém. sg.",  value: "lumineuse"),
                WordForm(label: "masc. pl.", value: "lumineux"),
                WordForm(label: "fém. pl.",  value: "lumineuses"),
            ],
            definition: "Luminous, bright, radiant — used for light, spaces, ideas, and people",
            example: "Elle a un sourire lumineux qui illumine toute la pièce.",
            exampleTranslation: "She has a radiant smile that lights up the whole room.",
            practiceQuestions: [
                "Say 'lumineux' (loo-mee-NOE) / 'lumineuse' (loo-mee-NOEZ). It means radiant, glowing, bright — sunlight, a smile, a great idea. Say both forms out loud!",
                "Try: 'Elle a un sourire lumineux.' — 'She has a radiant smile.' Think of someone this applies to and say it out loud.",
                "Fill in the blank: 'That apartment is so ________ — so many windows!' → 'Cet appartement est tellement ________ — il y a plein de fenêtres!'",
                "Look around you right now — what's lumineux? The sun? A lamp? Someone's face? Say: 'C'est lumineux!' Point at something and say it.",
                "Compliment someone today using lumineux: 'Ton sourire est lumineux!' — 'Your smile is radiant.' Say it and mean it!",
                "Try: 'It was a bright and sunny day.' → 'C'était une journée lumineuse.' Say it — imagine that perfect sunny day.",
                "Use 'lumineux/lumineuse' in a real sentence today. It works for people, places, ideas, and weather — very versatile!"
            ],
            practiceListenPhrases: [
                "lumineux, lumineuse",
                "Elle a un sourire lumineux.",
                nil,
                "C'est lumineux!",
                "Ton sourire est lumineux!",
                "C'était une journée lumineuse.",
                nil
            ]
        ),
        FrenchWord(
            word: "bienveillant(e)",
            type: "adjectif",
            gender: nil,
            forms: [
                WordForm(label: "masc. sg.", value: "bienveillant"),
                WordForm(label: "fém. sg.",  value: "bienveillante"),
                WordForm(label: "masc. pl.", value: "bienveillants"),
                WordForm(label: "fém. pl.",  value: "bienveillantes"),
            ],
            definition: "Benevolent, kind-hearted, well-meaning — a deep, caring goodness",
            example: "Elle est bienveillante avec tout le monde, sans exception.",
            exampleTranslation: "She is genuinely kind to everyone, without exception.",
            practiceQuestions: [
                "Say 'bienveillant' (byan-vay-YAHN) — it literally comes from 'wishing someone well.' It's deeper than 'nice' — it's a warm, genuine kindness. Say it!",
                "Try: 'Elle est tellement bienveillante.' — 'She's so kind-hearted.' Think of someone this perfectly describes and say it out loud.",
                "Fill in the blank: 'A ________ teacher makes every student feel seen.' → 'Un professeur ________ fait sentir chaque élève important.'",
                "Think of the most bienveillant(e) person you know. How would you describe them using this word? Say it out loud.",
                "Say 'Tu es tellement bienveillant(e)' to someone today — it's one of the most beautiful compliments in French. They'll appreciate it!",
                "Try: 'The world needs more kindness.' → 'Le monde a besoin de plus de bienveillance.' Say it — it's a powerful sentence.",
                "Use 'bienveillant(e)' in a sentence today. Describe someone whose kindness you've noticed — a friend, a coworker, a stranger."
            ],
            practiceListenPhrases: [
                "bienveillant",
                "Elle est tellement bienveillante.",
                nil,
                nil,
                "Tu es tellement bienveillante.",
                "Le monde a besoin de plus de bienveillance.",
                nil
            ]
        ),
        FrenchWord(
            word: "frissonner",
            type: "verbe",
            gender: nil,
            forms: [
                WordForm(label: "je",        value: "frissonne"),
                WordForm(label: "tu",        value: "frissonnes"),
                WordForm(label: "il/elle",   value: "frissonne"),
                WordForm(label: "nous",      value: "frissonnons"),
                WordForm(label: "vous",      value: "frissonnez"),
                WordForm(label: "ils/elles", value: "frissonnent"),
                WordForm(label: "p. passé",  value: "frissonné"),
            ],
            definition: "To shiver, to shudder, to get goosebumps — from cold, fear, or excitement",
            example: "Cette musique me fait frissonner à chaque fois.",
            exampleTranslation: "This music gives me goosebumps every single time.",
            practiceQuestions: [
                "Say 'frissonner' (free-so-NAY) — that full-body shiver or tingle from cold, a great song, or a scary movie. Say it while imagining that feeling!",
                "Try: 'Je frissonne!' — 'I'm shivering / I've got goosebumps!' Say it. Now think of a song that does this to you.",
                "Fill in the blank: 'She shivered when she stepped outside.' → 'Elle a ________ en sortant dehors.'",
                "What made you frissonner recently — a song, cold air, a great scene in a show? Say: 'Ça me fait frissonner!' about it.",
                "Try: 'This song gives me goosebumps every time.' → 'Cette chanson me fait frissonner à chaque fois.' Say it about a song you love right now.",
                "Try: 'He shivered in the cold.' → 'Il a frissonné dans le froid.' Simple and satisfying to say!",
                "Use 'frissonner' or 'un frisson' in a real sentence today — about a song, a moment, or the weather. Share it with a friend!"
            ],
            practiceListenPhrases: [
                "frissonner",
                "Je frissonne!",
                "Elle a frissonné en sortant dehors.",
                "Ça me fait frissonner!",
                "Cette chanson me fait frissonner à chaque fois.",
                "Il a frissonné dans le froid.",
                nil
            ]
        ),
        FrenchWord(
            word: "quotidien / quotidienne",
            type: "adjectif",
            gender: nil,
            forms: [
                WordForm(label: "masc. sg.", value: "quotidien"),
                WordForm(label: "fém. sg.",  value: "quotidienne"),
                WordForm(label: "masc. pl.", value: "quotidiens"),
                WordForm(label: "fém. pl.",  value: "quotidiennes"),
            ],
            definition: "Daily, everyday — as a noun, 'le quotidien' means the fabric of daily life",
            example: "Les petits plaisirs du quotidien rendent la vie vraiment belle.",
            exampleTranslation: "The small pleasures of everyday life truly make life beautiful.",
            practiceQuestions: [
                "Say 'quotidien' (ko-tee-DYAN) — it means 'daily' or 'everyday.' Your coffee, your commute, your routine — le quotidien. Say it out loud!",
                "Try: 'Mon quotidien.' — 'My daily life.' Simple, and you can build on it. Say it and picture your typical morning.",
                "Fill in the blank: 'Coffee is part of my ________ routine.' → 'Le café fait partie de ma routine ________.'",
                "Describe one small thing you do every single day. Say: 'Dans mon quotidien, je...' and finish the sentence however you like!",
                "Try: 'Small joys make everyday life beautiful.' → 'Les petits bonheurs rendent le quotidien beau.' Say it — it's a great phrase.",
                "Describe your morning to someone using this word: 'Dans mon quotidien, je commence par...' Share your routine in French!",
                "Use 'quotidien/quotidienne' in a sentence today about your day. What's your favourite part of your quotidien?"
            ],
            practiceListenPhrases: [
                "quotidien",
                "Mon quotidien.",
                nil,
                nil,
                "Les petits bonheurs rendent le quotidien beau.",
                nil,
                nil
            ]
        ),
        FrenchWord(
            word: "le bricolage",
            type: "nom masculin",
            gender: .masculine,
            forms: [
                WordForm(label: "singulier", value: "le bricolage"),
                WordForm(label: "pluriel",   value: "les bricolages"),
            ],
            definition: "DIY, tinkering, making or fixing things with your hands",
            example: "Il adore le bricolage — il a rénové toute la cuisine lui-même.",
            exampleTranslation: "He loves DIY — he renovated the whole kitchen himself.",
            practiceQuestions: [
                "Say 'le bricolage' (le bree-ko-LAZH) — it means DIY, fixing things, tinkering. Any time you build or repair something, c'est du bricolage. Say it!",
                "Try: 'J'adore le bricolage.' — 'I love doing DIY.' Do you? Say it! Even if you don't, it's a great sentence to practice.",
                "Fill in the blank: 'He spent the whole weekend doing ________.' → 'Il a passé tout le week-end à faire du ________.'",
                "Think of something you've fixed, built, or tinkered with. Say: 'J'ai fait du bricolage!' about it — no matter how small the project!",
                "Ask a friend: 'Est-ce que tu aimes le bricolage?' — 'Do you like DIY?' See what they say — and use the word when they answer!",
                "Try: 'He fixed the shelf himself — so handy!' → 'Il a réparé l'étagère lui-même — il est tellement bricoleur!' Say it!",
                "Use 'le bricolage' or 'bricoler' in a real sentence today. Did you fix something this week? Thinking about a home project? Say it in French!"
            ],
            practiceListenPhrases: [
                "le bricolage",
                "J'adore le bricolage.",
                nil,
                "J'ai fait du bricolage!",
                "Est-ce que tu aimes le bricolage?",
                "Il a réparé l'étagère lui-même — il est tellement bricoleur!",
                nil
            ]
        ),
        FrenchWord(
            word: "savourer",
            type: "verbe",
            forms: [
                WordForm(label: "je",        value: "savoure"),
                WordForm(label: "tu",        value: "savoures"),
                WordForm(label: "il/elle",   value: "savoure"),
                WordForm(label: "nous",      value: "savourons"),
                WordForm(label: "vous",      value: "savourez"),
                WordForm(label: "ils/elles", value: "savourent"),
                WordForm(label: "p. passé",  value: "savouré"),
            ],
            definition: "To savour, to relish — taking one's time fully enjoying something",
            example: "Elle savoure son café du matin en regardant le lever du soleil.",
            exampleTranslation: "She savours her morning coffee while watching the sunrise.",
            practiceQuestions: [
                "Say 'savourer' (sah-voo-RAY) — to truly savour something, slowly, intentionally. Not just taste — fully enjoy. Say it out loud!",
                "Try: 'Je savoure ce moment.' — 'I'm savouring this moment.' Say it and actually pause to enjoy right now.",
                "Fill in the blank: 'She ________ every bite of the chocolate.' → 'Elle ________ chaque bouchée du chocolat.'",
                "Find one moment today to slow down and say: 'Je savoure ce moment.' Your coffee, a sunset, a good song.",
                "Tell someone: 'Savourons ce moment ensemble!' — 'Let's savour this moment together!' Use it today.",
                "Try: 'He savoured every last drop.' → 'Il a savouré chaque dernière goutte.' Say it once slowly, then naturally.",
                "Use 'savourer' in a sentence today — what's something you want to truly savour this week?"
            ],
            practiceListenPhrases: [
                "savourer",
                "Je savoure ce moment.",
                "Elle savoure chaque bouchée du chocolat.",
                "Je savoure ce moment.",
                "Savourons ce moment ensemble!",
                "Il a savouré chaque dernière goutte.",
                nil
            ]
        ),
        FrenchWord(
            word: "rayonner",
            type: "verbe",
            forms: [
                WordForm(label: "je",        value: "rayonne"),
                WordForm(label: "tu",        value: "rayonnes"),
                WordForm(label: "il/elle",   value: "rayonne"),
                WordForm(label: "nous",      value: "rayonnons"),
                WordForm(label: "vous",      value: "rayonnez"),
                WordForm(label: "ils/elles", value: "rayonnent"),
                WordForm(label: "p. passé",  value: "rayonné"),
            ],
            definition: "To radiate, to beam, to shine with happiness or inner light",
            example: "Elle rayonnait de bonheur le jour de son mariage.",
            exampleTranslation: "She was radiant with happiness on her wedding day.",
            practiceQuestions: [
                "Say 'rayonner' (ray-o-NAY) — to radiate, to beam with light or happiness. Like someone glowing from the inside. Say it!",
                "Try: 'Elle rayonnait de joie!' — 'She was beaming with joy!' Think of someone who radiates like that. Say it!",
                "Fill in the blank: 'She was absolutely ________ at the wedding.' → 'Elle ________ absolument au mariage.'",
                "Try to be the one who rayonne today. Then say to yourself: 'Je rayonne!' even just for a second.",
                "Tell someone: 'Tu rayonnes!' — 'You're glowing / You look radiant!' It's a beautiful compliment to give.",
                "Try: 'He radiates confidence.' → 'Il rayonne de confiance.' Say it like you really mean it.",
                "Use 'rayonner' in a sentence — about a person, a place, or even the sun on a beautiful day."
            ],
            practiceListenPhrases: [
                "rayonner",
                "Elle rayonnait de joie!",
                "Elle rayonnait au mariage.",
                "Je rayonne!",
                "Tu rayonnes!",
                "Il rayonne de confiance.",
                nil
            ]
        ),
        FrenchWord(
            word: "bavarder",
            type: "verbe",
            forms: [
                WordForm(label: "je",        value: "bavarde"),
                WordForm(label: "tu",        value: "bavardes"),
                WordForm(label: "il/elle",   value: "bavarde"),
                WordForm(label: "nous",      value: "bavardons"),
                WordForm(label: "vous",      value: "bavardez"),
                WordForm(label: "ils/elles", value: "bavardent"),
                WordForm(label: "p. passé",  value: "bavardé"),
            ],
            definition: "To chat, to have a lively conversation — the kind that goes on for hours",
            example: "Elles ont bavardé pendant des heures autour d'un café.",
            exampleTranslation: "They chatted for hours over coffee.",
            practiceQuestions: [
                "Say 'bavarder' (bah-var-DAY) — a warm, lively chat with friends, the kind that goes on for hours. Say it out loud!",
                "Try: 'On a bavardé toute la soirée.' — 'We chatted all evening.' Say it — sounds just like time with good friends!",
                "Fill in the blank: 'We chatted for ages over a cup of tea.' → 'On a ________ pendant des heures autour d'un thé.'",
                "Find someone to bavarder with today — even five minutes. Then say: 'J'ai bien bavardé!' after.",
                "Say to a friend: 'Ca fait longtemps qu'on n'a pas bavardé!' — 'It's been a while since we had a good chat!'",
                "Try: 'She could chat all day long.' → 'Elle pourrait bavarder toute la journée.' Say it!",
                "Use 'bavarder' in a sentence today. Who's someone you love to bavarder with?"
            ],
            practiceListenPhrases: [
                "bavarder",
                "On a bavardé toute la soirée.",
                "On a bavardé pendant des heures autour d'un thé.",
                "J'ai bien bavardé!",
                "Ca fait longtemps qu'on n'a pas bavardé!",
                "Elle pourrait bavarder toute la journée.",
                nil
            ]
        ),
        FrenchWord(
            word: "chérir",
            type: "verbe",
            forms: [
                WordForm(label: "je",        value: "chéris"),
                WordForm(label: "tu",        value: "chéris"),
                WordForm(label: "il/elle",   value: "chérit"),
                WordForm(label: "nous",      value: "chérissons"),
                WordForm(label: "vous",      value: "chérissez"),
                WordForm(label: "ils/elles", value: "chérissent"),
                WordForm(label: "p. passé",  value: "chéri(e)"),
            ],
            definition: "To cherish, to hold dear — a deep, tender affection for someone or something",
            example: "Elle chérit chaque moment passé avec sa famille.",
            exampleTranslation: "She cherishes every moment spent with her family.",
            practiceQuestions: [
                "Say 'chérir' (shay-REER) — to cherish something deeply, hold it close to your heart. A word full of warmth. Say it!",
                "Try: 'Je chéris ces souvenirs.' — 'I cherish these memories.' Say it and think of a memory you hold dear.",
                "Fill in the blank: 'She ________ every letter her grandmother wrote her.' → 'Elle ________ chaque lettre que sa grand-mère lui a écrite.'",
                "What do you chérir in your life? Say: 'Je chéris...' and complete the sentence with something you truly value.",
                "Tell someone: 'Je te chéris.' — 'I hold you dear.' It's deeper than 'I love you' in some ways.",
                "Try: 'He truly cherished their friendship.' → 'Il chérissait vraiment leur amitié.' Say it warmly.",
                "Use 'chérir' in a sentence today — who or what do you chérir? Say it out loud."
            ],
            practiceListenPhrases: [
                "chérir",
                "Je chéris ces souvenirs.",
                "Elle chérit chaque lettre que sa grand-mère lui a écrite.",
                "Je chéris ces moments.",
                "Je te chéris.",
                "Il chérissait vraiment leur amitié.",
                nil
            ]
        ),
        FrenchWord(
            word: "mijoter",
            type: "verbe",
            forms: [
                WordForm(label: "je",        value: "mijote"),
                WordForm(label: "tu",        value: "mijotes"),
                WordForm(label: "il/elle",   value: "mijote"),
                WordForm(label: "nous",      value: "mijotons"),
                WordForm(label: "vous",      value: "mijotez"),
                WordForm(label: "ils/elles", value: "mijotent"),
                WordForm(label: "p. passé",  value: "mijoté"),
            ],
            definition: "To simmer (cooking); figuratively, to brew or develop slowly",
            example: "Le ragoût mijote depuis deux heures — la maison sent divinement bon!",
            exampleTranslation: "The stew has been simmering for two hours — the house smells divine!",
            practiceQuestions: [
                "Say 'mijoter' (mee-zho-TAY) — to let something simmer slowly. Also used for plans brewing quietly. Say it!",
                "Try: 'Ca mijote!' — 'It's simmering!' A great thing to say when cooking. Say it like you've got something on the stove.",
                "Fill in the blank: 'The soup has been ________ all afternoon.' → 'La soupe ________ depuis tout l'après-midi.'",
                "If you cook anything today, say 'Ca mijote!' or 'Je laisse mijoter.' Bring French into the kitchen!",
                "Tell someone about what you're cooking or planning: 'J'ai quelque chose qui mijote!' — great for food or a fun surprise.",
                "Try: 'She let the sauce simmer for an hour.' → 'Elle a laissé la sauce mijoter pendant une heure.'",
                "Use 'mijoter' in a sentence — cooking something? Planning something? Both work!"
            ],
            practiceListenPhrases: [
                "mijoter",
                "Ca mijote!",
                "La soupe mijote depuis tout l'après-midi.",
                "Je laisse mijoter.",
                "J'ai quelque chose qui mijote!",
                "Elle a laissé la sauce mijoter pendant une heure.",
                nil
            ]
        ),
        FrenchWord(
            word: "papillonner",
            type: "verbe",
            forms: [
                WordForm(label: "je",        value: "papillonne"),
                WordForm(label: "tu",        value: "papillonnes"),
                WordForm(label: "il/elle",   value: "papillonne"),
                WordForm(label: "nous",      value: "papillonnons"),
                WordForm(label: "vous",      value: "papillonnez"),
                WordForm(label: "ils/elles", value: "papillonnent"),
                WordForm(label: "p. passé",  value: "papillonné"),
            ],
            definition: "To flit from thing to thing, like a butterfly — scattered, hard to pin down",
            example: "Elle papillonne d'un projet à l'autre sans jamais en terminer un.",
            exampleTranslation: "She flits from one project to another without ever finishing one.",
            practiceQuestions: [
                "Say 'papillonner' (pah-pee-yo-NAY) — to flit around like a butterfly, jumping from thing to thing. Know anyone like that? Say it!",
                "Try: 'J'ai tendance à papillonner.' — 'I tend to flit around.' Honest and relatable! Say it.",
                "Fill in the blank: 'He ________ from project to project.' → 'Il ________ d'un projet à l'autre.'",
                "Notice if you papillonnez today — lots of tabs open? Say 'Je papillonne!' and maybe focus for five minutes.",
                "Ask someone: 'Est-ce que tu papillonnes beaucoup?' — 'Do you tend to flit around a lot?'",
                "Try: 'She can't stop jumping from one task to another.' → 'Elle n'arrête pas de papillonner d'une tâche à l'autre.'",
                "Use 'papillonner' in a sentence — do you papillonnez? Do you know someone who does?"
            ],
            practiceListenPhrases: [
                "papillonner",
                "J'ai tendance à papillonner.",
                "Il papillonne d'un projet à l'autre.",
                "Je papillonne!",
                "Est-ce que tu papillonnes beaucoup?",
                "Elle n'arrête pas de papillonner d'une tâche à l'autre.",
                nil
            ]
        ),
        FrenchWord(
            word: "se souvenir",
            type: "verbe pronominal",
            forms: [
                WordForm(label: "je",        value: "me souviens"),
                WordForm(label: "tu",        value: "te souviens"),
                WordForm(label: "il/elle",   value: "se souvient"),
                WordForm(label: "nous",      value: "nous souvenons"),
                WordForm(label: "vous",      value: "vous souvenez"),
                WordForm(label: "ils/elles", value: "se souviennent"),
                WordForm(label: "p. passé",  value: "souvenu(e)"),
            ],
            definition: "To remember, to recall — one of the most poetic and essential verbs in French",
            example: "Je me souviens encore de ce bel été passé à Paris.",
            exampleTranslation: "I still remember that beautiful summer spent in Paris.",
            practiceQuestions: [
                "Say 'se souvenir' (se soo-ve-NEER) — to remember, to recall. Beautiful-sounding and essential. Say it out loud!",
                "Try: 'Je me souviens.' — 'I remember.' It's also Quebec's motto! Say it and think of something you remember fondly.",
                "Fill in the blank: 'I still ________ our first meeting.' → 'Je me ________ encore de notre première rencontre.'",
                "Think of a happy memory today and say: 'Je me souviens de...' and describe it — even in English with the French phrase.",
                "Share a memory with someone: 'Tu te souviens quand...?' — 'Do you remember when...?' Start a great conversation.",
                "Try: 'She remembered every detail.' → 'Elle se souvenait de chaque détail.' Say it thoughtfully.",
                "Use 'se souvenir' in a sentence today. What's a memory you cherish? Start with 'Je me souviens...'"
            ],
            practiceListenPhrases: [
                "se souvenir",
                "Je me souviens.",
                "Je me souviens encore de notre première rencontre.",
                "Je me souviens de ce moment.",
                "Tu te souviens quand...?",
                "Elle se souvenait de chaque détail.",
                nil
            ]
        ),
        FrenchWord(
            word: "s'épanouir",
            type: "verbe pronominal",
            forms: [
                WordForm(label: "je",        value: "m'épanouis"),
                WordForm(label: "tu",        value: "t'épanouis"),
                WordForm(label: "il/elle",   value: "s'épanouit"),
                WordForm(label: "nous",      value: "nous épanouissons"),
                WordForm(label: "vous",      value: "vous épanouissez"),
                WordForm(label: "ils/elles", value: "s'épanouissent"),
                WordForm(label: "p. passé",  value: "épanoui(e)"),
            ],
            definition: "To blossom, to flourish, to thrive — growing into the best version of yourself",
            example: "Elle s'épanouit vraiment depuis qu'elle a rejoint cette équipe.",
            exampleTranslation: "She's really flourishing since she joined that team.",
            practiceQuestions: [
                "Say 's'épanouir' (say-pah-NWEER) — to blossom, to flourish, to thrive. A flower opening. A person becoming who they're meant to be. Say it!",
                "Try: 'Je m'épanouis.' — 'I'm flourishing.' Say it. Does it feel true right now?",
                "Fill in the blank: 'She has really ________ in her new role.' → 'Elle s'est vraiment ________ dans son nouveau poste.'",
                "Think of one area where you're épanouissant. Say: 'Je m'épanouis quand je...' — 'I flourish when I...'",
                "Tell someone: 'Tu t'épanouis tellement!' — 'You're really flourishing!' One of the nicest things you can say.",
                "Try: 'He blossomed when he started painting.' → 'Il s'est épanoui quand il a commencé à peindre.'",
                "Use 's'épanouir' in a sentence — where in your life are you currently blossoming?"
            ],
            practiceListenPhrases: [
                "s'épanouir",
                "Je m'épanouis.",
                "Elle s'est vraiment épanouie dans son nouveau poste.",
                "Je m'épanouis quand je crée.",
                "Tu t'épanouis tellement!",
                "Il s'est épanoui quand il a commencé à peindre.",
                nil
            ]
        ),
        FrenchWord(
            word: "apprivoiser",
            type: "verbe",
            forms: [
                WordForm(label: "je",        value: "apprivoise"),
                WordForm(label: "tu",        value: "apprivoises"),
                WordForm(label: "il/elle",   value: "apprivoise"),
                WordForm(label: "nous",      value: "apprivoisons"),
                WordForm(label: "vous",      value: "apprivoisez"),
                WordForm(label: "ils/elles", value: "apprivoisent"),
                WordForm(label: "p. passé",  value: "apprivoisé(e)"),
            ],
            definition: "To tame, to win over gently — as the fox says in Le Petit Prince",
            example: "Il faut du temps pour apprivoiser la confiance des autres.",
            exampleTranslation: "It takes time to earn people's trust.",
            practiceQuestions: [
                "Say 'apprivoiser' (ah-pree-vwah-ZAY) — to tame, to gently win something over. The fox in Le Petit Prince talks about this. Say it!",
                "Try: 'Tu m'as apprivoisé(e).' — 'You've won me over.' Say it — think of someone who slowly won your heart.",
                "Fill in the blank: 'It takes time to ________ a shy cat.' → 'Il faut du temps pour ________ un chat timide.'",
                "Think of something you're slowly getting comfortable with. Say: 'J'apprivoise...' about it.",
                "Share this phrase: 'On n'apprivoise pas en un jour.' — 'You can't tame something in a day.' Use it when someone's impatient!",
                "Try: 'She gradually won over the shy puppy.' → 'Elle a apprivoisé doucement le chiot timide.'",
                "Use 'apprivoiser' in a sentence — what are you in the process of taming or befriending right now?"
            ],
            practiceListenPhrases: [
                "apprivoiser",
                "Tu m'as apprivoisée.",
                "Il faut du temps pour apprivoiser un chat timide.",
                "J'apprivoise doucement.",
                "On n'apprivoise pas en un jour.",
                "Elle a apprivoisé doucement le chiot timide.",
                nil
            ]
        ),
        FrenchWord(
            word: "le savoir-faire",
            type: "nom masculin",
            gender: .masculine,
            forms: [
                WordForm(label: "singulier", value: "le savoir-faire"),
                WordForm(label: "pluriel",   value: "les savoir-faire"),
            ],
            definition: "Know-how, expertise — the skill and finesse to get things done with elegance",
            example: "Son savoir-faire en cuisine impressionne toujours ses invités.",
            exampleTranslation: "Her culinary know-how always impresses her guests.",
            practiceQuestions: [
                "Say 'le savoir-faire' (le sah-vwahr-FAIR) — know-how, expertise, the ability to do something with skill and finesse. Say it!",
                "Try: 'Elle a un vrai savoir-faire.' — 'She has real expertise.' Think of someone with incredible skill and say it about them.",
                "Fill in the blank: 'His ________ as a carpenter is well known.' → 'Son ________ de charpentier est bien connu.'",
                "Think of a skill you've developed. Say: 'J'ai le savoir-faire pour...' — 'I have the know-how for...' Own it!",
                "Compliment someone's skill today: 'Ton savoir-faire est impressionnant!' — 'Your know-how is impressive!'",
                "Try: 'It takes years of practice to develop that expertise.' → 'Il faut des années de pratique pour développer ce savoir-faire.'",
                "Use 'le savoir-faire' in a sentence — about yourself or someone whose mastery you admire."
            ],
            practiceListenPhrases: [
                "le savoir-faire",
                "Elle a un vrai savoir-faire.",
                nil,
                "J'ai le savoir-faire pour ça.",
                "Ton savoir-faire est impressionnant!",
                "Il faut des années de pratique pour développer ce savoir-faire.",
                nil
            ]
        ),
        FrenchWord(
            word: "le bonheur",
            type: "nom masculin",
            gender: .masculine,
            forms: [
                WordForm(label: "singulier", value: "le bonheur"),
                WordForm(label: "pluriel",   value: "les bonheurs"),
            ],
            definition: "Happiness, bliss, joy — a state of deep contentment and well-being",
            example: "Le bonheur, c'est souvent dans les petites choses.",
            exampleTranslation: "Happiness is often found in the little things.",
            practiceQuestions: [
                "Say 'le bonheur' (le bo-NEUR) — happiness, joy, bliss. One of the most beautiful words in French. Say it slowly and let it sink in.",
                "Try: 'C'est mon bonheur.' — 'It's my joy / It makes me happy.' Say it about something you truly love.",
                "Fill in the blank: 'For her, ________ is a cup of tea and a good book.' → 'Pour elle, le ________ c'est une tasse de thé et un bon livre.'",
                "Find something small today that brings you bonheur. Say: 'Ca, c'est mon bonheur.' Point at it, feel it.",
                "Ask someone: 'C'est quoi ton bonheur?' — 'What makes you happy?' Have the conversation.",
                "Try: 'Happiness is in the simple moments.' → 'Le bonheur est dans les moments simples.' Say it — mean it.",
                "Use 'le bonheur' in a sentence today. What is your bonheur?"
            ],
            practiceListenPhrases: [
                "le bonheur",
                "C'est mon bonheur.",
                nil,
                "Ca, c'est mon bonheur.",
                "C'est quoi ton bonheur?",
                "Le bonheur est dans les moments simples.",
                nil
            ]
        ),
        FrenchWord(
            word: "le hasard",
            type: "nom masculin",
            gender: .masculine,
            forms: [
                WordForm(label: "singulier", value: "le hasard"),
                WordForm(label: "pluriel",   value: "les hasards"),
            ],
            definition: "Chance, coincidence, fate — the unpredictable force of life",
            example: "Par quel hasard se sont-ils rencontrés dans ce café?",
            exampleTranslation: "By what coincidence did they meet in that café?",
            practiceQuestions: [
                "Say 'le hasard' (le ah-ZAR) — chance, luck, coincidence. 'Par hasard' = by chance. One of those essential French words. Say it!",
                "Try: 'Par hasard, je l'ai rencontré.' — 'By chance, I ran into him.' Say it — it's a great story-starter.",
                "Fill in the blank: 'We met completely by ________.' → 'On s'est rencontré complètement par ________.' (hasard)",
                "Think of something that happened by chance recently. Say: 'C'était le hasard qui a tout changé.' and tell that story.",
                "Tell someone: 'C'est le hasard qui nous a réunis!' — 'It was chance that brought us together!' Use it about your friendship.",
                "Try: 'Life is full of happy coincidences.' → 'La vie est pleine de hasards heureux.' Say it.",
                "Use 'le hasard' in a sentence — about a lucky coincidence, a twist of fate, or something unexpected."
            ],
            practiceListenPhrases: [
                "le hasard",
                "Par hasard, je l'ai rencontré.",
                "On s'est rencontré par hasard.",
                "C'était le hasard!",
                "C'est le hasard qui nous a réunis!",
                "La vie est pleine de hasards heureux.",
                nil
            ]
        ),
        FrenchWord(
            word: "le boulot",
            type: "nom masculin",
            gender: .masculine,
            forms: [
                WordForm(label: "singulier", value: "le boulot"),
                WordForm(label: "usage",     value: "du boulot"),
            ],
            definition: "Work, job — the everyday informal word, more casual than 'le travail'",
            example: "J'ai tellement de boulot cette semaine — je suis épuisée!",
            exampleTranslation: "I have so much work this week — I'm exhausted!",
            practiceQuestions: [
                "Say 'le boulot' (le boo-LO) — the informal, everyday word for work or job. 'Travail' is formal; 'boulot' is what friends say. Say it!",
                "Try: 'C'est quoi ton boulot?' — 'What's your job?' It's casual and very common. How would you answer?",
                "Fill in the blank: 'I have so much ________ this week.' → 'J'ai tellement de ________ cette semaine.'",
                "Next time you think about work today, say to yourself: 'Mon boulot, c'est...' Describe it simply in French.",
                "Ask a friend: 'Ca se passe bien, le boulot?' — 'How's work going?' The natural casual way to ask.",
                "Try: 'He found a great new job.' → 'Il a trouvé un super nouveau boulot.' Say it — casual and modern!",
                "Use 'le boulot' in a sentence today. Talk about your work, someone else's, or your weekend off!"
            ],
            practiceListenPhrases: [
                "le boulot",
                "C'est quoi ton boulot?",
                "J'ai tellement de boulot cette semaine.",
                "Mon boulot, c'est...",
                "Ca se passe bien, le boulot?",
                "Il a trouvé un super nouveau boulot.",
                nil
            ]
        ),
        FrenchWord(
            word: "le cocooning",
            type: "nom masculin",
            gender: .masculine,
            forms: [
                WordForm(label: "usage",  value: "faire du cocooning"),
                WordForm(label: "soirée", value: "c'est cocooning"),
            ],
            definition: "Staying home cozily to relax and recharge — the French borrowed this one!",
            example: "Ce week-end, c'est cocooning — couverture, film et chocolat chaud.",
            exampleTranslation: "This weekend it's all about staying in — blanket, movie, and hot chocolate.",
            practiceQuestions: [
                "Say 'le cocooning' (le ko-KOO-ning) — yes, it's borrowed from English! It means staying home cozily. The French use it all the time. Say it!",
                "Try: 'Ce soir, c'est cocooning!' — 'Tonight it's staying in!' Say it like you're looking forward to a cozy evening.",
                "Fill in the blank: 'After a long week, all I want is ________.' → 'Après une longue semaine, tout ce que je veux c'est du ________.'",
                "Plan your next cocooning evening: 'Mon cocooning idéal, c'est...' — blankets, movies, tea — whatever it is, say it!",
                "Invite someone: 'On fait du cocooning ce soir?' — 'Want to stay in tonight?' It sounds very French!",
                "Try: 'She spent the whole rainy Sunday cocooning.' → 'Elle a passé tout le dimanche pluvieux à faire du cocooning.'",
                "Use 'le cocooning' in a sentence — plan your perfect cozy evening at home in French!"
            ],
            practiceListenPhrases: [
                "le cocooning",
                "Ce soir, c'est cocooning!",
                "J'ai besoin de cocooning.",
                "Mon cocooning idéal, c'est...",
                "On fait du cocooning ce soir?",
                "Elle a passé le dimanche à faire du cocooning.",
                nil
            ]
        ),
        FrenchWord(
            word: "le terroir",
            type: "nom masculin",
            gender: .masculine,
            forms: [
                WordForm(label: "singulier", value: "le terroir"),
                WordForm(label: "pluriel",   value: "les terroirs"),
            ],
            definition: "The characteristic identity of a place baked into its food and wine — geography, climate, and tradition",
            example: "Ce vin exprime parfaitement le terroir de Bordeaux.",
            exampleTranslation: "This wine perfectly expresses the character of the Bordeaux region.",
            practiceQuestions: [
                "Say 'le terroir' (le teh-RWAHR) — the essence of a place expressed through its food and wine. Very French concept. Say it!",
                "Try: 'Ce vin a un terroir magnifique.' — 'This wine has a magnificent sense of place.' Say it like a connoisseur.",
                "Fill in the blank: 'The cheese gets its flavour from the ________ of the region.' → 'Le fromage doit son goût au ________ de la région.'",
                "Think of a food, wine, or place with a strong local identity. Say: 'Ca, c'est le terroir de...' and name the place.",
                "Tell someone about a regional food or drink you love: 'Le terroir de cette région est incroyable.' Use it!",
                "Try: 'Every great wine reflects its land.' → 'Chaque grand vin reflète son terroir.' Say it like you know wine.",
                "Use 'le terroir' in a sentence — about food, wine, culture, or the character of a place you love."
            ],
            practiceListenPhrases: [
                "le terroir",
                "Ce vin a un terroir magnifique.",
                nil,
                "Ca, c'est le terroir de cette région.",
                "Le terroir de cette région est incroyable.",
                "Chaque grand vin reflète son terroir.",
                nil
            ]
        ),
        FrenchWord(
            word: "le dépanneur",
            type: "nom masculin",
            gender: .masculine,
            forms: [
                WordForm(label: "singulier", value: "le dépanneur"),
                WordForm(label: "pluriel",   value: "les dépanneurs"),
            ],
            definition: "(Québec) The corner store or convenience store — a cultural institution in Quebec",
            example: "Je passe au dépanneur chercher du lait et un Coke.",
            exampleTranslation: "I'm stopping at the corner store to grab milk and a Coke.",
            practiceQuestions: [
                "Say 'le dépanneur' (le day-pah-NEUR) — this is the Quebec word for corner store. Every neighbourhood has one. Very local! Say it!",
                "Try: 'Je vais au dépanneur.' — 'I'm heading to the corner store.' A quintessentially Quebec phrase. Say it!",
                "Fill in the blank: 'I'll grab some snacks at the ________.' → 'Je vais chercher des collations au ________.'",
                "If you're near a corner store today, say 'Je passe au dépanneur!' before going. If not, say it anyway — practice!",
                "Tell a non-Quebecois friend: 'Un dépanneur, c'est notre mot québécois pour corner store!' Share a bit of culture.",
                "Try: 'We stopped at the corner store for ice cream.' → 'On s'est arrêtés au dépanneur pour de la crème glacée.'",
                "Use 'le dépanneur' in a sentence today — about a quick stop, a snack run, or a neighbourhood detail."
            ],
            practiceListenPhrases: [
                "le dépanneur",
                "Je vais au dépanneur.",
                "Je cherche des collations au dépanneur.",
                "Je passe au dépanneur!",
                "Un dépanneur, c'est notre mot québécois pour corner store.",
                "On s'est arrêtés au dépanneur pour de la crème glacée.",
                nil
            ]
        ),
        FrenchWord(
            word: "le flambeau",
            type: "nom masculin",
            gender: .masculine,
            forms: [
                WordForm(label: "singulier", value: "le flambeau"),
                WordForm(label: "pluriel",   value: "les flambeaux"),
            ],
            definition: "A torch; figuratively, the legacy or responsibility passed from one generation to the next",
            example: "Elle a repris le flambeau de l'entreprise familiale avec beaucoup de courage.",
            exampleTranslation: "She picked up the torch of the family business with great courage.",
            practiceQuestions: [
                "Say 'le flambeau' (le flahn-BO) — a torch. Figuratively: passing something important across generations. Say it!",
                "Try: 'Elle a repris le flambeau.' — 'She picked up the torch.' A phrase you'll hear when someone continues a legacy.",
                "Fill in the blank: 'He passed the ________ to the next generation.' → 'Il a passé le ________ à la génération suivante.'",
                "Think of someone who passed the flambeau to you — a mentor, a parent. Say: 'Ils m'ont passé le flambeau.'",
                "Tell someone about a responsibility you've taken on: 'J'ai repris le flambeau de...' Use it with pride.",
                "Try: 'It's our turn to carry the torch.' → 'C'est notre tour de porter le flambeau.' Say it with conviction!",
                "Use 'le flambeau' in a sentence — about legacy, leadership, or something you've inherited to continue."
            ],
            practiceListenPhrases: [
                "le flambeau",
                "Elle a repris le flambeau.",
                "Il a passé le flambeau à la génération suivante.",
                "Ils m'ont passé le flambeau.",
                "J'ai repris le flambeau.",
                "C'est notre tour de porter le flambeau.",
                nil
            ]
        ),
        FrenchWord(
            word: "le penchant",
            type: "nom masculin",
            gender: .masculine,
            forms: [
                WordForm(label: "singulier", value: "le penchant"),
                WordForm(label: "pluriel",   value: "les penchants"),
            ],
            definition: "A fondness, a soft spot, an inclination toward something you can't quite resist",
            example: "Elle a un penchant pour le chocolat noir et les livres anciens.",
            exampleTranslation: "She has a weakness for dark chocolate and old books.",
            practiceQuestions: [
                "Say 'le penchant' (le pahn-SHAHN) — a soft spot, a fondness, an inclination toward something. Say it and think of yours!",
                "Try: 'J'ai un penchant pour...' — 'I have a soft spot for...' Finish the sentence! What's yours?",
                "Fill in the blank: 'He has a weakness for antique shops and coffee.' → 'Il a un ________ pour les antiquaires et le café.'",
                "Admit your penchant today. Say: 'Mon vrai penchant, c'est...' — no judgment, we all have one!",
                "Share with someone: 'Tu veux savoir mon vrai penchant?' — 'Want to know my real soft spot?' Then tell them in French!",
                "Try: 'She's always had a fondness for adventure.' → 'Elle a toujours eu un penchant pour l'aventure.'",
                "Use 'le penchant' in a sentence — what is your penchant? What can't you resist?"
            ],
            practiceListenPhrases: [
                "le penchant",
                "J'ai un penchant pour quelque chose.",
                "Il a un penchant pour les antiquaires et le café.",
                "Mon vrai penchant, c'est...",
                "Tu veux savoir mon vrai penchant?",
                "Elle a toujours eu un penchant pour l'aventure.",
                nil
            ]
        ),
        FrenchWord(
            word: "la convivialité",
            type: "nom féminin",
            gender: .feminine,
            forms: [
                WordForm(label: "singulier", value: "la convivialité"),
            ],
            definition: "Conviviality — the warm spirit of togetherness, friendliness, and shared pleasure",
            example: "Ce restaurant est connu pour sa convivialité autant que pour sa cuisine.",
            exampleTranslation: "This restaurant is known for its warm atmosphere as much as for its food.",
            practiceQuestions: [
                "Say 'la convivialité' (la kon-vee-vee-ah-lee-TAY) — the warmth and friendliness of being together. A big word for a beautiful feeling. Say it!",
                "Try: 'J'adore la convivialité des repas en famille.' — 'I love the warmth of family meals.' Say it, think of your last great gathering.",
                "Fill in the blank: 'This place has such great ________ — everyone feels welcome.' → 'Cet endroit a une telle ________.'",
                "Notice la convivialité around you today — at lunch, over coffee, in a conversation. Say: 'Quelle convivialité!'",
                "Bring some convivialité today — invite someone for coffee. Use the word: 'Viens, un peu de convivialité!'",
                "Try: 'French culture values warmth and togetherness.' → 'La culture française valorise la convivialité.'",
                "Use 'la convivialité' in a sentence — about a meal, a place, or a person who embodies warmth."
            ],
            practiceListenPhrases: [
                "la convivialité",
                "J'adore la convivialité des repas en famille.",
                nil,
                "Quelle convivialité!",
                "Viens, un peu de convivialité!",
                "La culture française valorise la convivialité.",
                nil
            ]
        ),
        FrenchWord(
            word: "la nostalgie",
            type: "nom féminin",
            gender: .feminine,
            forms: [
                WordForm(label: "singulier", value: "la nostalgie"),
                WordForm(label: "adjectif",  value: "nostalgique"),
            ],
            definition: "Nostalgia — a bittersweet longing for the past",
            example: "Ce vieux film me plonge dans une douce nostalgie.",
            exampleTranslation: "That old film fills me with a gentle nostalgia.",
            practiceQuestions: [
                "Say 'la nostalgie' (la nos-tal-ZHEE) — that warm, bittersweet ache for something from the past. Beautiful word. Say it slowly!",
                "Try: 'J'ai la nostalgie de...' — 'I feel nostalgic about...' What comes to mind? Finish the sentence.",
                "Fill in the blank: 'That song fills me with ________.' → 'Cette chanson m'envahit de ________.'",
                "Pick a photo, song, or memory today and say: 'Quelle nostalgie!' Feel that beautiful ache for a moment.",
                "Share a nostalgic memory with someone: 'Ca me donne de la nostalgie...' — 'This makes me nostalgic...'",
                "Try: 'There's something nostalgic about old music.' → 'La vieille musique a quelque chose de nostalgique.'",
                "Use 'la nostalgie' in a sentence — what makes you feel nostalgic? Describe that feeling."
            ],
            practiceListenPhrases: [
                "la nostalgie",
                "J'ai la nostalgie de ce temps-là.",
                "Cette chanson m'envahit de nostalgie.",
                "Quelle nostalgie!",
                "Ca me donne de la nostalgie.",
                "La vieille musique a quelque chose de nostalgique.",
                nil
            ]
        ),
        FrenchWord(
            word: "la tendresse",
            type: "nom féminin",
            gender: .feminine,
            forms: [
                WordForm(label: "singulier", value: "la tendresse"),
                WordForm(label: "adjectif",  value: "tendre"),
            ],
            definition: "Tenderness, affection, gentleness — a soft and warm feeling of care and love",
            example: "Elle lui parlait avec une infinie tendresse.",
            exampleTranslation: "She spoke to him with infinite tenderness.",
            practiceQuestions: [
                "Say 'la tendresse' (la tahn-DRES) — tenderness, warmth, gentle love. Softer than passion, just as deep. Say it!",
                "Try: 'Avec tendresse.' — 'With tenderness.' A short, beautiful phrase. Say it slowly and feel it.",
                "Fill in the blank: 'She looked at her baby with so much ________.' → 'Elle regardait son bébé avec tellement de ________.'",
                "Show some tendresse today — a kind word, a gentle gesture. Then say quietly: 'C'est de la tendresse.'",
                "Say to someone you love: 'Je te parle avec tendresse.' — 'I speak to you with tenderness.'",
                "Try: 'The scene was filled with genuine warmth.' → 'La scène était remplie d'une vraie tendresse.' Say it!",
                "Use 'la tendresse' in a sentence today. Describe a tender moment you've shared or witnessed."
            ],
            practiceListenPhrases: [
                "la tendresse",
                "Avec tendresse.",
                "Elle regardait son bébé avec tellement de tendresse.",
                "C'est de la tendresse.",
                "Je te parle avec tendresse.",
                "La scène était remplie d'une vraie tendresse.",
                nil
            ]
        ),
        FrenchWord(
            word: "la fougue",
            type: "nom féminin",
            gender: .feminine,
            forms: [
                WordForm(label: "singulier", value: "la fougue"),
                WordForm(label: "adjectif",  value: "fougueux/fougueuse"),
            ],
            definition: "Fiery passion, ardor, fierce enthusiasm — burning intensity brought to everything",
            example: "Elle aborde chaque projet avec une fougue impressionnante.",
            exampleTranslation: "She tackles every project with impressive passion and intensity.",
            practiceQuestions: [
                "Say 'la fougue' (la FOOG) — burning passion and fierce enthusiasm. Fire in the heart. Say it with energy!",
                "Try: 'Elle fait tout avec fougue!' — 'She does everything with passionate intensity!' Say it — feel the fougue!",
                "Fill in the blank: 'He played the violin with such ________.' → 'Il jouait du violon avec une telle ________.'",
                "Think of something you do with fougue. Say: 'Je fais ca avec fougue!' — is it dancing? Cooking? A sport?",
                "Admire someone's passion today: 'Tu fais ca avec une vraie fougue!' — 'You do this with real passion!'",
                "Try: 'Youth is full of fire and passion.' → 'La jeunesse est pleine de fougue.'",
                "Use 'la fougue' in a sentence — about yourself, someone you admire, or a moment you were truly fired up."
            ],
            practiceListenPhrases: [
                "la fougue",
                "Elle fait tout avec fougue!",
                "Il jouait du violon avec une telle fougue.",
                "Je fais ca avec fougue!",
                "Tu fais ca avec une vraie fougue!",
                "La jeunesse est pleine de fougue.",
                nil
            ]
        ),
        FrenchWord(
            word: "la sieste",
            type: "nom féminin",
            gender: .feminine,
            forms: [
                WordForm(label: "singulier", value: "la sieste"),
                WordForm(label: "pluriel",   value: "les siestes"),
            ],
            definition: "A nap, especially the midday rest — a valued ritual in French-speaking cultures",
            example: "Après le déjeuner, je me sens toujours comme neuve après une petite sieste.",
            exampleTranslation: "After lunch, I always feel brand new after a little nap.",
            exampleMasc: "Après le déjeuner, je me sens toujours comme neuf après une petite sieste.",
            practiceQuestions: [
                "Say 'la sieste' (la SYEST) — the sacred midday nap. The French take it seriously. Even 20 minutes counts! Say it!",
                "Try: 'Je fais la sieste.' — 'I'm taking a nap.' Say it like it's the most natural and justified thing in the world. Because it is!",
                "Fill in the blank: 'After lunch I need a little ________.' → 'Après le déjeuner j'ai besoin d'une petite ________.'",
                "If you have a moment to rest today, call it a sieste. Say: 'Je vais faire une petite sieste.' Permission granted.",
                "Suggest a nap to someone: 'On fait la sieste?' — 'Want to take a nap?' In French it sounds completely civilized.",
                "Try: 'A little nap can change everything.' → 'Une petite sieste peut tout changer.'",
                "Use 'la sieste' in a sentence — when's the last time you had a great sieste? Plan your next one in French!"
            ],
            practiceListenPhrases: [
                "la sieste",
                "Je fais la sieste.",
                "Après le déjeuner j'ai besoin d'une petite sieste.",
                "Je vais faire une petite sieste.",
                "On fait la sieste?",
                "Une petite sieste peut tout changer.",
                nil
            ]
        ),
        FrenchWord(
            word: "la franchise",
            type: "nom féminin",
            gender: .feminine,
            forms: [
                WordForm(label: "singulier", value: "la franchise"),
                WordForm(label: "adjectif",  value: "franc/franche"),
            ],
            definition: "Frankness, candor — the courage to speak honestly and openly",
            example: "Elle répond toujours avec franchise, même quand ce n'est pas facile.",
            exampleTranslation: "She always answers honestly, even when it's not easy.",
            practiceQuestions: [
                "Say 'la franchise' (la frahn-SHEEZ) — frankness, candor, the courage to be open and honest. Say it!",
                "Try: 'Je te dis ca en toute franchise.' — 'I'm telling you this in all honesty.' A great opener when you need to be real.",
                "Fill in the blank: 'What I love about her is her ________ — you always know where you stand.' → 'Ce que j'aime chez elle, c'est sa ________.'",
                "Be franc with yourself today. Say: 'En toute franchise...' and finish the sentence honestly.",
                "Tell someone: 'J'apprécie ta franchise.' — 'I appreciate your honesty.' One of the most meaningful compliments.",
                "Try: 'He spoke with complete frankness.' → 'Il a parlé avec une franchise totale.' Say it clearly.",
                "Use 'la franchise' in a sentence — about someone you trust for their honesty, or a moment you were frank yourself."
            ],
            practiceListenPhrases: [
                "la franchise",
                "Je te dis ca en toute franchise.",
                nil,
                "En toute franchise...",
                "J'apprécie ta franchise.",
                "Il a parlé avec une franchise totale.",
                nil
            ]
        ),
        FrenchWord(
            word: "se languir",
            type: "verbe pronominal",
            forms: [
                WordForm(label: "je",        value: "me languis"),
                WordForm(label: "tu",        value: "te languis"),
                WordForm(label: "il/elle",   value: "se languit"),
                WordForm(label: "nous",      value: "nous languissons"),
                WordForm(label: "vous",      value: "vous languissez"),
                WordForm(label: "ils/elles", value: "se languissent"),
                WordForm(label: "p. passé",  value: "langui"),
            ],
            definition: "To long for, to pine for someone or something — a bittersweet ache of absence",
            example: "Je me languis de toi quand tu es loin.",
            exampleTranslation: "I long for you when you're far away.",
            practiceQuestions: [
                "Say 'se languir' (se lahn-GHEER) — to pine for someone, to long for something you miss deeply. Bittersweet and beautiful. Say it!",
                "Try: 'Je me languis de toi.' — 'I long for you / I miss you deeply.' More poetic and deep than just 'tu me manques.'",
                "Fill in the blank: 'She ________ for the sea when she's in the city.' → 'Elle se ________ de la mer quand elle est en ville.'",
                "Think of someone or somewhere you're missing right now. Say: 'Je me languis de...' and name them.",
                "Send this to someone you miss: 'Je me languis de toi!' — They'll feel so special receiving it.",
                "Try: 'He pined for her for years.' → 'Il s'est langui d'elle pendant des années.' A love story in one sentence.",
                "Use 'se languir' in a sentence — who or what are you languishing for? Say it with feeling."
            ],
            practiceListenPhrases: [
                "se languir",
                "Je me languis de toi.",
                "Elle se languit de la mer quand elle est en ville.",
                "Je me languis de toi.",
                "Je me languis de toi!",
                "Il s'est langui d'elle pendant des années.",
                nil
            ]
        ),
        FrenchWord(
            word: "le patrimoine",
            type: "nom masculin",
            gender: .masculine,
            forms: [
                WordForm(label: "singulier", value: "le patrimoine"),
                WordForm(label: "pluriel",   value: "les patrimoines"),
            ],
            definition: "Heritage, legacy — what is passed down through generations, culturally or personally",
            example: "Le Vieux-Québec est classé au patrimoine mondial de l'UNESCO.",
            exampleTranslation: "Old Québec City is listed as a UNESCO World Heritage site.",
            practiceQuestions: [
                "Say 'le patrimoine' (le pah-tree-MWAHN) — heritage, what we inherit and pass on. Culture, history, family legacy. Say it!",
                "Try: 'Le patrimoine québécois est riche et unique.' — 'Quebec's heritage is rich and unique.' Say it with pride!",
                "Fill in the blank: 'This building is part of our cultural ________.' → 'Ce bâtiment fait partie de notre ________ culturel.'",
                "Think of something in your life or culture that is patrimoine — a tradition, a recipe, a language. Say: 'C'est notre patrimoine.'",
                "Tell someone about a piece of cultural heritage you care about: 'C'est une partie de notre patrimoine.' Use it today.",
                "Try: 'We must protect our heritage.' → 'Il faut protéger notre patrimoine.' Say it firmly.",
                "Use 'le patrimoine' in a sentence — what heritage matters to you personally or culturally?"
            ],
            practiceListenPhrases: [
                "le patrimoine",
                "Le patrimoine québécois est riche et unique.",
                nil,
                "C'est notre patrimoine.",
                "C'est une partie de notre patrimoine.",
                "Il faut protéger notre patrimoine.",
                nil
            ]
        ),
        FrenchWord(
            word: "la flânerie",
            type: "nom féminin",
            gender: .feminine,
            forms: [
                WordForm(label: "singulier", value: "la flânerie"),
                WordForm(label: "pluriel",   value: "les flâneries"),
            ],
            definition: "The art and culture of leisurely wandering — the noun form of flâner",
            example: "La flânerie dominicale dans le marché est mon rituel préféré.",
            exampleTranslation: "My favourite ritual is a Sunday stroll through the market.",
            practiceQuestions: [
                "Say 'la flânerie' (la flah-neh-REE) — the culture and art of leisurely wandering. You know 'flâner' — now meet the noun! Say it!",
                "Try: 'J'adore la flânerie.' — 'I love strolling with no agenda.' Say it — this is a whole lifestyle philosophy!",
                "Fill in the blank: 'Sunday in Paris is made for ________.' → 'Le dimanche à Paris est fait pour la ________.'",
                "Plan a flânerie for today or this week — even 10 minutes of wandering with no destination. Say: 'Je pars en flânerie!'",
                "Invite someone: 'On part en flânerie ce week-end?' — 'Shall we go for a wander this weekend?'",
                "Try: 'There's an art to wandering without purpose.' → 'La flânerie est un véritable art de vivre.'",
                "Use 'la flânerie' in a sentence — plan your next slow wander and describe it in French!"
            ],
            practiceListenPhrases: [
                "la flânerie",
                "J'adore la flânerie.",
                nil,
                "Je pars en flânerie!",
                "On part en flânerie ce week-end?",
                "La flânerie est un véritable art de vivre.",
                nil
            ]
        ),
        FrenchWord(
            word: "la résilience",
            type: "nom féminin",
            gender: .feminine,
            forms: [
                WordForm(label: "singulier", value: "la résilience"),
                WordForm(label: "adjectif",  value: "résilient(e)"),
            ],
            definition: "Resilience — the ability to bend without breaking, to rise after falling",
            example: "Sa résilience face aux épreuves force vraiment l'admiration.",
            exampleTranslation: "Her resilience in the face of challenges is truly admirable.",
            practiceQuestions: [
                "Say 'la résilience' (la ray-zee-LYANS) — resilience, the ability to bounce back, to grow through difficulty. Say it!",
                "Try: 'C'est une vraie résilience.' — 'That's true resilience.' Think of someone whose strength inspires you. Say it about them.",
                "Fill in the blank: 'After everything she's been through, her ________ is remarkable.' → 'Après tout ce qu'elle a vécu, sa ________ est remarquable.'",
                "Think of a challenge you've bounced back from. Say: 'J'ai trouvé ma résilience.' — 'I found my resilience.'",
                "Acknowledge someone's strength today: 'Ta résilience est vraiment inspirante.' — 'Your resilience is truly inspiring.'",
                "Try: 'Resilience is built through hardship.' → 'La résilience se forge dans l'épreuve.' Powerful sentence.",
                "Use 'la résilience' in a sentence — about yourself, someone you know, or a community that has shown strength."
            ],
            practiceListenPhrases: [
                "la résilience",
                "C'est une vraie résilience.",
                "Sa résilience est remarquable.",
                "J'ai trouvé ma résilience.",
                "Ta résilience est vraiment inspirante.",
                "La résilience se forge dans l'épreuve.",
                nil
            ]
        ),
        FrenchWord(
            word: "une épiphanie",
            type: "nom féminin",
            gender: .feminine,
            forms: [
                WordForm(label: "singulier", value: "une épiphanie"),
                WordForm(label: "pluriel",   value: "des épiphanies"),
            ],
            definition: "An epiphany — a sudden revelatory realization that changes how you see things",
            example: "En lisant ce livre, j'ai eu une véritable épiphanie sur ma vie.",
            exampleTranslation: "Reading that book gave me a true epiphany about my life.",
            practiceQuestions: [
                "Say 'une épiphanie' (oon ay-pee-fah-NEE) — that lightbulb moment when something clicks and everything makes sense. Say it!",
                "Try: 'J'ai eu une épiphanie!' — 'I had an epiphany!' Say it with the excitement of a real breakthrough moment.",
                "Fill in the blank: 'That conversation was a real ________ for me.' → 'Cette conversation a été une vraie ________ pour moi.'",
                "Think of a moment when something suddenly clicked for you. Say: 'C'était mon épiphanie.' Describe it to yourself.",
                "Share a revelation: 'J'ai eu une sorte d'épiphanie...' — 'I had a kind of epiphany...' See where the conversation goes!",
                "Try: 'She had a sudden realization that changed everything.' → 'Elle a eu une épiphanie qui a tout changé.'",
                "Use 'une épiphanie' in a sentence — about a moment of sudden clarity in your life or someone else's."
            ],
            practiceListenPhrases: [
                "une épiphanie",
                "J'ai eu une épiphanie!",
                "J'ai eu une vraie épiphanie.",
                "C'était mon épiphanie.",
                "J'ai eu une sorte d'épiphanie...",
                "Elle a eu une épiphanie qui a tout changé.",
                nil
            ]
        ),
        FrenchWord(
            word: "chouette",
            type: "adjectif",
            forms: [
                WordForm(label: "masc./fém.", value: "chouette"),
                WordForm(label: "aussi",      value: "une chouette (owl)"),
            ],
            definition: "Great, cool, wonderful — very common informal French. Also means 'owl'!",
            example: "C'est une idée vraiment chouette — on devrait le faire!",
            exampleTranslation: "That's a really great idea — we should do it!",
            practiceQuestions: [
                "Say 'chouette' (shoo-ET) — it means 'great' or 'cool' in informal French. Also the word for owl! Very commonly used. Say it!",
                "Try: 'C'est super chouette!' — 'That's really cool!' Say it about something you genuinely think is great right now.",
                "Fill in the blank: 'What a ________ day!' → 'Quelle journée ________!'",
                "Use 'chouette' for something good that happens today — even small. Say: 'C'est chouette, ca!' and mean it.",
                "Compliment someone today: 'C'est vraiment chouette ce que tu fais!' — 'What you're doing is really cool!'",
                "Try: 'She's such a wonderful person.' → 'Elle est vraiment chouette.' Sounds perfectly natural and warm.",
                "Use 'chouette' in a real sentence today. Find three things that are chouette in your life right now!"
            ],
            practiceListenPhrases: [
                "chouette",
                "C'est super chouette!",
                "Quelle journée chouette!",
                "C'est chouette, ca!",
                "C'est vraiment chouette ce que tu fais!",
                "Elle est vraiment chouette.",
                nil
            ]
        ),
        FrenchWord(
            word: "pétillant(e)",
            type: "adjectif",
            forms: [
                WordForm(label: "masc. sg.", value: "pétillant"),
                WordForm(label: "fém. sg.",  value: "pétillante"),
                WordForm(label: "masc. pl.", value: "pétillants"),
                WordForm(label: "fém. pl.",  value: "pétillantes"),
            ],
            definition: "Sparkling, bubbly — like champagne, or a personality full of life and wit",
            example: "Elle a une personnalité pétillante qui illumine toutes les pièces.",
            exampleTranslation: "She has a sparkling personality that lights up every room.",
            practiceQuestions: [
                "Say 'pétillant' (pay-tee-YAHN) — sparkling! Like champagne, like eyes that light up. It even sounds bubbly! Say it!",
                "Try: 'Elle est vraiment pétillante!' — 'She's so bubbly and sparkling!' Think of someone like that and say it about them.",
                "Fill in the blank: 'His wit is absolutely ________.' → 'Son esprit est absolument ________.'",
                "Try to be pétillant(e) today — bring energy, humour, spark. Then say: 'Je suis pétillant(e) aujourd'hui!'",
                "Compliment someone: 'Tu es tellement pétillant(e)!' — 'You're so full of sparkle and life!' Make their day.",
                "Try: 'Her enthusiasm is contagious.' → 'Son enthousiasme pétillant est contagieux.'",
                "Use 'pétillant(e)' in a sentence today — who is the most pétillant(e) person you know?"
            ],
            practiceListenPhrases: [
                "pétillant",
                "Elle est vraiment pétillante!",
                nil,
                "Je suis pétillante aujourd'hui!",
                "Tu es tellement pétillante!",
                "Son enthousiasme pétillant est contagieux.",
                nil
            ],
            practiceListenPhrasesMasc: [
                nil, nil, nil,
                "Je suis pétillant aujourd'hui!",
                "Tu es tellement pétillant!",
                nil, nil
            ]
        ),
        FrenchWord(
            word: "doux / douce",
            type: "adjectif",
            forms: [
                WordForm(label: "masc. sg.", value: "doux"),
                WordForm(label: "fém. sg.",  value: "douce"),
                WordForm(label: "masc. pl.", value: "doux"),
                WordForm(label: "fém. pl.",  value: "douces"),
            ],
            definition: "Soft, gentle, mild, sweet — for temperature, voice, personality, or texture",
            example: "Sa voix est tellement douce — elle apaise tout de suite.",
            exampleTranslation: "Her voice is so gentle — it immediately soothes you.",
            practiceQuestions: [
                "Say 'doux' (DOO) / 'douce' (DOOS) — soft, gentle, mild, sweet. Used for temperature, voice, personality, fabric. Say both forms!",
                "Try: 'C'est doux.' — 'It's soft / gentle.' Say it about something around you right now — is the light doux? Your blanket?",
                "Fill in the blank: 'The breeze was so ________ and warm.' → 'La brise était tellement ________ et chaude.'",
                "Find something doux around you today — a sound, a sensation, a person. Say: 'C'est tellement doux!' about it.",
                "Compliment someone's gentle energy: 'Tu as quelque chose de tellement doux.' — 'You have something so gentle about you.'",
                "Try: 'She has a very gentle nature.' → 'Elle a un caractère très doux.'",
                "Use 'doux/douce' in a sentence today. What is something doux in your life right now?"
            ],
            practiceListenPhrases: [
                "doux, douce",
                "C'est doux.",
                "La brise était tellement douce et chaude.",
                "C'est tellement doux!",
                "Tu as quelque chose de tellement doux.",
                "Elle a un caractère très doux.",
                nil
            ]
        ),
        FrenchWord(
            word: "fier / fière",
            type: "adjectif",
            forms: [
                WordForm(label: "masc. sg.", value: "fier"),
                WordForm(label: "fém. sg.",  value: "fière"),
                WordForm(label: "masc. pl.", value: "fiers"),
                WordForm(label: "fém. pl.",  value: "fières"),
            ],
            definition: "Proud — warm, earned pride, not arrogance",
            example: "Je suis tellement fière de tout ce que tu as accompli.",
            exampleTranslation: "I am so proud of everything you have accomplished.",
            exampleMasc: "Je suis tellement fier de tout ce que tu as accompli.",
            practiceQuestions: [
                "Say 'fier' (FYAIR) / 'fière' (FYAIR) — proud. Both sound the same out loud! Warm, earned pride. Say it!",
                "Try: 'Je suis fier/fière de toi.' — 'I'm proud of you.' Say it — who comes to mind when you say these words?",
                "Fill in the blank: 'She's so ________ of her daughter.' → 'Elle est tellement ________ de sa fille.'",
                "Think of something you've done recently. Say: 'Je suis fier/fière de ca.' — Own that accomplishment!",
                "Tell someone today: 'Je suis tellement fier/fière de toi!' — 'I'm so proud of you.' Pick someone who deserves to hear it.",
                "Try: 'He was proud of his work.' → 'Il était fier de son travail.' Simple, strong, true.",
                "Use 'fier/fière' in a sentence — what or who are you proud of right now? Say it out loud!"
            ],
            practiceListenPhrases: [
                "fier, fière",
                "Je suis fière de toi.",
                "Elle est tellement fière de sa fille.",
                "Je suis fière de ca.",
                "Je suis tellement fière de toi!",
                "Il était fier de son travail.",
                nil
            ],
            practiceListenPhrasesMasc: [
                nil,
                "Je suis fier de toi.",
                nil,
                "Je suis fier de ca.",
                "Je suis tellement fier de toi!",
                nil, nil
            ]
        ),
        FrenchWord(
            word: "bavard(e)",
            type: "adjectif",
            forms: [
                WordForm(label: "masc. sg.", value: "bavard"),
                WordForm(label: "fém. sg.",  value: "bavarde"),
                WordForm(label: "masc. pl.", value: "bavards"),
                WordForm(label: "fém. pl.",  value: "bavardes"),
            ],
            definition: "Talkative, chatty — someone who loves to talk, usually said with affection",
            example: "Elle est si bavarde — on pourrait parler pendant des heures!",
            exampleTranslation: "She's so chatty — we could talk for hours!",
            practiceQuestions: [
                "Say 'bavard' (bah-VAR) / 'bavarde' (bah-VARD) — chatty, talkative. Said with affection! Say both forms out loud.",
                "Try: 'Je suis assez bavard(e).' — 'I'm quite chatty.' Are you? Say it and see if it fits!",
                "Fill in the blank: 'He's the most ________ person at the table.' → 'Il est la personne la plus ________ à table.'",
                "Next time you have a long conversation today, say to yourself: 'Je suis vraiment bavard(e)!' with a smile.",
                "Tease a talkative friend lovingly: 'Tu es tellement bavard(e)!' — 'You're so chatty!' Use it with warmth.",
                "Try: 'She loves to chat — she could talk all day.' → 'Elle est bavarde — elle pourrait parler toute la journée.'",
                "Use 'bavard(e)' in a sentence — about yourself or someone in your life. Is it a compliment? Usually yes!"
            ],
            practiceListenPhrases: [
                "bavard",
                "Je suis assez bavarde.",
                "Il est la personne la plus bavarde à table.",
                "Je suis vraiment bavarde!",
                "Tu es tellement bavarde!",
                "Elle est bavarde — elle pourrait parler toute la journée.",
                nil
            ],
            practiceListenPhrasesMasc: [
                nil,
                "Je suis assez bavard.",
                nil,
                "Je suis vraiment bavard!",
                "Tu es tellement bavard!",
                nil, nil
            ]
        ),
        FrenchWord(
            word: "câlin(e)",
            type: "adjectif / nom",
            forms: [
                WordForm(label: "masc. sg.", value: "câlin"),
                WordForm(label: "fém. sg.",  value: "câline"),
                WordForm(label: "un câlin",  value: "a hug"),
                WordForm(label: "des câlins", value: "hugs"),
            ],
            definition: "Cuddly, snuggly, affectionate. Also: 'un câlin' = a hug",
            example: "Mon chat est tellement câlin — il s'installe sur moi dès que je m'assieds.",
            exampleTranslation: "My cat is so cuddly — he settles on me the moment I sit down.",
            practiceQuestions: [
                "Say 'câlin' (kah-LAN) / 'câline' (kah-LEEN) — cuddly, snuggly, affectionate. Also 'un câlin' = a hug! Say it with warmth!",
                "Try: 'Je suis très câlin(e).' — 'I'm very cuddly.' Say it and notice how sweet it sounds in French.",
                "Fill in the blank: 'She's so ________ — she hugs everyone she loves.' → 'Elle est tellement ________ — elle serre tout le monde dans ses bras.'",
                "Give someone a câlin today — or just say: 'J'ai besoin d'un câlin.' Everyone understands that.",
                "Ask for or offer: 'Tu veux un câlin?' — 'Do you want a hug?' The sweetest question in French.",
                "Try: 'He's a very affectionate person.' → 'Il est très câlin.' Short, sweet, and true.",
                "Use 'câlin/câline' in a sentence today — about yourself, a pet, a child, or someone you love."
            ],
            practiceListenPhrases: [
                "câlin",
                "Je suis très câline.",
                "Elle est tellement câline.",
                "J'ai besoin d'un câlin.",
                "Tu veux un câlin?",
                "Il est très câlin.",
                nil
            ],
            practiceListenPhrasesMasc: [
                nil,
                "Je suis très câlin.",
                nil, nil, nil, nil, nil
            ]
        ),
        FrenchWord(
            word: "malicieux / malicieuse",
            type: "adjectif",
            forms: [
                WordForm(label: "masc. sg.", value: "malicieux"),
                WordForm(label: "fém. sg.",  value: "malicieuse"),
                WordForm(label: "masc. pl.", value: "malicieux"),
                WordForm(label: "fém. pl.",  value: "malicieuses"),
            ],
            definition: "Mischievous, impish, playfully sly — that twinkle in the eye",
            example: "Elle avait un sourire malicieux — elle savait quelque chose que nous ignorions.",
            exampleTranslation: "She had a mischievous smile — she knew something we didn't.",
            practiceQuestions: [
                "Say 'malicieux' (mah-lee-SYOE) / 'malicieuse' (mah-lee-SYOEZ) — mischievous, impish, playfully sly. Think twinkle-in-the-eye. Say it!",
                "Try: 'Il avait l'air malicieux.' — 'He had a mischievous look.' Think of someone who always has that spark. Say it!",
                "Fill in the blank: 'She gave me a ________ wink before revealing the surprise.' → 'Elle m'a fait un clin d'oeil ________ avant de révéler la surprise.'",
                "Do something playful today and say: 'Je suis malicieux/malicieuse!' Say it with a smirk.",
                "Catch someone being playfully sneaky and say: 'Ah, tu es malicieux/malicieuse!' with a smile.",
                "Try: 'The child had a twinkle in his eye.' → 'L'enfant avait un regard malicieux.'",
                "Use 'malicieux/malicieuse' in a sentence today. Who is the most malicieux/malicieuse person you know?"
            ],
            practiceListenPhrases: [
                "malicieux",
                "Il avait l'air malicieux.",
                "Elle m'a fait un clin d'oeil malicieux.",
                "Je suis malicieuse!",
                "Ah, tu es malicieuse!",
                "L'enfant avait un regard malicieux.",
                nil
            ]
        ),
        FrenchWord(
            word: "coquet(te)",
            type: "adjectif",
            forms: [
                WordForm(label: "masc. sg.", value: "coquet"),
                WordForm(label: "fém. sg.",  value: "coquette"),
                WordForm(label: "masc. pl.", value: "coquets"),
                WordForm(label: "fém. pl.",  value: "coquettes"),
            ],
            definition: "Stylish, fashion-conscious, put-together — someone who loves looking their best",
            example: "Elle est toujours coquette — jamais sans son rouge à lèvres!",
            exampleTranslation: "She's always put-together — never without her lipstick!",
            exampleMasc: "Il est toujours coquet — jamais sans son style impeccable!",
            practiceQuestions: [
                "Say 'coquet' (ko-KAY) / 'coquette' (ko-KET) — stylish, fashion-conscious, put-together. Someone who loves looking their best. Say both!",
                "Try: 'Je suis un peu coquette.' — 'I'm a little particular about my look.' Say it — it's charming in French!",
                "Fill in the blank: 'She's always so ________ — perfectly dressed for every occasion.' → 'Elle est toujours tellement ________.'",
                "Notice your look today. If you put effort into it, say: 'Je suis coquet(te) aujourd'hui!' Own it.",
                "Compliment someone: 'Tu es très coquet(te)!' — 'You're very put-together!' A light, pleasant compliment.",
                "Try: 'He always takes care of how he dresses.' → 'Il est toujours très coquet dans sa façon de s'habiller.'",
                "Use 'coquet/coquette' in a sentence today — about yourself or someone whose style you admire."
            ],
            practiceListenPhrases: [
                "coquet",
                "Je suis un peu coquette.",
                "Elle est toujours tellement coquette.",
                "Je suis coquette aujourd'hui!",
                "Tu es très coquette!",
                "Il est toujours très coquet dans sa façon de s'habiller.",
                nil
            ],
            practiceListenPhrasesMasc: [
                nil,
                "Je suis un peu coquet.",
                nil,
                "Je suis coquet aujourd'hui!",
                "Tu es très coquet!",
                nil, nil
            ]
        ),
        FrenchWord(
            word: "saisissant(e)",
            type: "adjectif",
            forms: [
                WordForm(label: "masc. sg.", value: "saisissant"),
                WordForm(label: "fém. sg.",  value: "saisissante"),
                WordForm(label: "masc. pl.", value: "saisissants"),
                WordForm(label: "fém. pl.",  value: "saisissantes"),
            ],
            definition: "Striking, gripping, breathtaking — something that literally seizes your attention",
            example: "Le coucher de soleil était d'une beauté saisissante.",
            exampleTranslation: "The sunset was of striking, breathtaking beauty.",
            practiceQuestions: [
                "Say 'saisissant' (say-zee-SAHN) / 'saisissante' (say-zee-SAHNT) — striking, gripping, breathtaking. It literally means 'seizing.' Say it!",
                "Try: 'C'est saisissant!' — 'It's stunning / It takes your breath away!' Say it about something that truly moves you.",
                "Fill in the blank: 'The resemblance between them is quite ________.' → 'La ressemblance entre eux est assez ________.'",
                "Find something saisissant today — a view, a piece of music, a coincidence. Say: 'C'est saisissant!' and feel it.",
                "Describe something stunning: 'Le tableau était d'une beauté saisissante.' — 'The painting was of stunning beauty.'",
                "Try: 'The documentary was gripping from start to finish.' → 'Le documentaire était saisissant de bout en bout.'",
                "Use 'saisissant(e)' in a sentence — what has seized your attention or breath recently?"
            ],
            practiceListenPhrases: [
                "saisissant",
                "C'est saisissant!",
                "La ressemblance entre eux est assez saisissante.",
                "C'est saisissant!",
                "Le tableau était d'une beauté saisissante.",
                "Le documentaire était saisissant de bout en bout.",
                nil
            ]
        ),
        FrenchWord(
            word: "attendrissant(e)",
            type: "adjectif",
            forms: [
                WordForm(label: "masc. sg.", value: "attendrissant"),
                WordForm(label: "fém. sg.",  value: "attendrissante"),
                WordForm(label: "masc. pl.", value: "attendrissants"),
                WordForm(label: "fém. pl.",  value: "attendrissantes"),
            ],
            definition: "Heartwarming, touching, endearing — makes your heart soft with tenderness",
            example: "La scène de retrouvailles était tellement attendrissante — j'avais les larmes aux yeux.",
            exampleTranslation: "The reunion scene was so heartwarming — I had tears in my eyes.",
            practiceQuestions: [
                "Say 'attendrissant' (ah-tahn-dree-SAHN) — heartwarming, touching. From 'attendrir' = to soften. It's what makes your heart melt. Say it!",
                "Try: 'C'est tellement attendrissant!' — 'It's so heartwarming!' Say it about something that gave you the warm fuzzies.",
                "Fill in the blank: 'The video of the dog reuniting with its owner was so ________.' → 'La vidéo du chien qui retrouve son maître était tellement ________.'",
                "Think of something attendrissant you've seen this week — a kind gesture, a reunion. Say: 'C'était attendrissant!'",
                "Share something heartwarming: 'Regarde ca — c'est trop attendrissant!' — 'Look at this — it's too sweet!' Use it today.",
                "Try: 'The grandmother's reaction was the most heartwarming thing.' → 'La réaction de la grand-mère était ce qu'il y avait de plus attendrissant.'",
                "Use 'attendrissant(e)' in a sentence — what was the most attendrissant thing you've seen recently?"
            ],
            practiceListenPhrases: [
                "attendrissant",
                "C'est tellement attendrissant!",
                "La vidéo du chien était tellement attendrissante.",
                "C'était attendrissant!",
                "Regarde ca — c'est trop attendrissant!",
                "La réaction de la grand-mère était tellement attendrissante.",
                nil
            ]
        ),
        FrenchWord(
            word: "dépaysé(e)",
            type: "adjectif",
            forms: [
                WordForm(label: "masc. sg.", value: "dépaysé"),
                WordForm(label: "fém. sg.",  value: "dépaysée"),
                WordForm(label: "masc. pl.", value: "dépaysés"),
                WordForm(label: "fém. pl.",  value: "dépaysées"),
            ],
            definition: "Pleasantly out of one's element — disoriented by a new environment in a refreshing way",
            example: "Je me sens un peu dépaysée dans cette nouvelle ville, mais c'est excitant!",
            exampleTranslation: "I feel a bit out of my element in this new city, but it's exciting!",
            exampleMasc: "Je me sens un peu dépaysé dans cette nouvelle ville, mais c'est excitant!",
            practiceQuestions: [
                "Say 'dépaysé(e)' (day-pay-ZAY) — pleasantly out of your element. You know 'dépaysement' — here's the adjective! Say it!",
                "Try: 'Je me sens dépaysée.' — 'I feel out of my element (in a good way).' Say it — think of a time you felt this.",
                "Fill in the blank: 'I always feel wonderfully ________ when I travel.' → 'Je me sens toujours agréablement ________ quand je voyage.'",
                "Think of a time you were somewhere unfamiliar and loved it. Say: 'J'étais dépaysé(e) et c'était parfait.'",
                "Tell someone about a trip: 'Je me suis senti(e) tellement dépaysé(e) — c'était incroyable!' Use it!",
                "Try: 'She felt wonderfully out of her element in Japan.' → 'Elle s'est sentie tellement dépaysée au Japon.'",
                "Use 'dépaysé(e)' in a sentence — about travel, a new experience, or any moment of wonderful disorientation."
            ],
            practiceListenPhrases: [
                "dépaysé",
                "Je me sens dépaysée.",
                "Je me sens agréablement dépaysée quand je voyage.",
                "J'étais dépaysée et c'était parfait.",
                "Je me suis sentie tellement dépaysée — c'était incroyable!",
                "Elle s'est sentie tellement dépaysée au Japon.",
                nil
            ],
            practiceListenPhrasesMasc: [
                nil,
                "Je me sens dépaysé.",
                "Je me sens agréablement dépaysé quand je voyage.",
                "J'étais dépaysé et c'était parfait.",
                "Je me suis senti tellement dépaysé — c'était incroyable!",
                nil, nil
            ]
        ),
        FrenchWord(
            word: "apaisé(e)",
            type: "adjectif",
            forms: [
                WordForm(label: "masc. sg.", value: "apaisé"),
                WordForm(label: "fém. sg.",  value: "apaisée"),
                WordForm(label: "masc. pl.", value: "apaisés"),
                WordForm(label: "fém. pl.",  value: "apaisées"),
            ],
            definition: "Calm, at peace, soothed — having found inner quiet or relief from tension",
            example: "Après cette promenade, je me sens complètement apaisée.",
            exampleTranslation: "After that walk, I feel completely at peace.",
            exampleMasc: "Après cette promenade, je me sens complètement apaisé.",
            practiceQuestions: [
                "Say 'apaisé(e)' (ah-pay-ZAY) — calm, soothed, at peace. The quiet feeling after a long exhale. Say it softly — feel it.",
                "Try: 'Je me sens apaisée.' — 'I feel calm / at peace.' Say it — when's the last time you felt truly apaisé(e)?",
                "Fill in the blank: 'She felt so ________ after her meditation.' → 'Elle se sentait tellement ________ après sa méditation.'",
                "Do something calming today — walk, breathe, make tea. Then say: 'Je me sens apaisé(e).' Really feel it.",
                "Tell someone: 'Tu m'apaises.' — 'You calm me / You bring me peace.' A deeply meaningful thing to say.",
                "Try: 'The music left him feeling completely calm.' → 'La musique l'a laissé complètement apaisé.'",
                "Use 'apaisé(e)' in a sentence — what or who makes you feel apaisé(e)? Describe that feeling."
            ],
            practiceListenPhrases: [
                "apaisé",
                "Je me sens apaisée.",
                "Elle se sentait tellement apaisée après sa méditation.",
                "Je me sens apaisée.",
                "Tu m'apaises.",
                "La musique l'a laissé complètement apaisé.",
                nil
            ],
            practiceListenPhrasesMasc: [
                nil,
                "Je me sens apaisé.",
                "Il se sentait tellement apaisé après sa méditation.",
                "Je me sens apaisé.",
                nil, nil, nil
            ]
        ),
        FrenchWord(
            word: "comblé(e)",
            type: "adjectif",
            forms: [
                WordForm(label: "masc. sg.", value: "comblé"),
                WordForm(label: "fém. sg.",  value: "comblée"),
                WordForm(label: "masc. pl.", value: "comblés"),
                WordForm(label: "fém. pl.",  value: "comblées"),
            ],
            definition: "Completely fulfilled, content — having everything one could wish for; cup overflowing",
            example: "Je me sens comblée — j'ai tout ce qu'il me faut pour être heureuse.",
            exampleTranslation: "I feel completely fulfilled — I have everything I need to be happy.",
            exampleMasc: "Je me sens comblé — j'ai tout ce qu'il me faut pour être heureux.",
            practiceQuestions: [
                "Say 'comblé(e)' (kohm-BLAY) — completely fulfilled, content, overflowing with joy. Your cup is not just full — it's overflowing. Say it!",
                "Try: 'Je me sens comblée.' — 'I feel completely fulfilled.' Say it — does it feel true? Even partly?",
                "Fill in the blank: 'After that perfect weekend, she felt completely ________.' → 'Après ce week-end parfait, elle se sentait complètement ________.'",
                "Think of a moment when you felt truly comblé(e). Say: 'Je me suis senti(e) comblé(e) quand...' and describe it.",
                "Tell someone: 'Tu me combles.' — 'You make me feel so fulfilled / you mean the world to me.'",
                "Try: 'He was overflowing with happiness.' → 'Il était comblé de bonheur.' Feel that fullness.",
                "Use 'comblé(e)' in a sentence today — what makes you feel comblé(e)? Describe that state."
            ],
            practiceListenPhrases: [
                "comblé",
                "Je me sens comblée.",
                "Après ce week-end, elle se sentait complètement comblée.",
                "Je me suis sentie comblée.",
                "Tu me combles.",
                "Il était comblé de bonheur.",
                nil
            ],
            practiceListenPhrasesMasc: [
                nil,
                "Je me sens comblé.",
                nil,
                "Je me suis senti comblé.",
                nil, nil, nil
            ]
        ),
        FrenchWord(
            word: "espiègle",
            type: "adjectif",
            forms: [
                WordForm(label: "masc./fém.", value: "espiègle"),
                WordForm(label: "pluriel",    value: "espièges"),
            ],
            definition: "Impish, playfully mischievous — with a twinkle in the eye and light-hearted trickery",
            example: "Avec son regard espiègle, il cachait toujours quelque chose de drôle dans sa manche.",
            exampleTranslation: "With his impish look, he always had something funny up his sleeve.",
            practiceQuestions: [
                "Say 'espiègle' (es-PYEGL) — impish, mischievously playful. Same form for masc/fem! Think of a pixie or a plotting child. Say it!",
                "Try: 'Il a un regard espiègle.' — 'He has an impish look.' Think of someone who always has that glint. Say it!",
                "Fill in the blank: 'She has an ________ sense of humour.' → 'Elle a un sens de l'humour ________.'",
                "Do something playful today, then say: 'Je suis espiègle!' Own your mischief with a grin.",
                "Catch someone being cheeky and say: 'Tu es tellement espiègle!' — 'You're so impish!' Great word to say with a laugh.",
                "Try: 'The child's impish smile gave him away.' → 'Le sourire espiègle de l'enfant l'a trahi.'",
                "Use 'espiègle' in a sentence today — who's the most espiègle person in your life?"
            ],
            practiceListenPhrases: [
                "espiègle",
                "Il a un regard espiègle.",
                "Elle a un sens de l'humour espiègle.",
                "Je suis espiègle!",
                "Tu es tellement espiègle!",
                "Le sourire espiègle de l'enfant l'a trahi.",
                nil
            ]
        ),
        FrenchWord(
            word: "douillet / douillette",
            type: "adjectif",
            forms: [
                WordForm(label: "masc. sg.", value: "douillet"),
                WordForm(label: "fém. sg.",  value: "douillette"),
                WordForm(label: "masc. pl.", value: "douillet"),
                WordForm(label: "fém. pl.",  value: "douillettes"),
            ],
            definition: "Cozy, snug, soft — warm and padded comfort; the ultimate word for a cozy feeling",
            example: "Ce canapé est tellement douillet — je ne veux plus me lever.",
            exampleTranslation: "This sofa is so cozy — I don't want to get up.",
            practiceQuestions: [
                "Say 'douillet' (dwee-YAY) / 'douillette' (dwee-YET) — cozy, snuggly, warm and padded. The ultimate comfort word. Say it!",
                "Try: 'C'est tellement douillet ici.' — 'It's so cozy here.' Say it — picture the coziest spot you know.",
                "Fill in the blank: 'She wrapped herself in the ________ blanket.' → 'Elle s'est enveloppée dans la couverture ________.'",
                "Find something douillet around you today. Say: 'C'est tellement douillet!' and sink into it.",
                "Invite someone into your cozy space: 'C'est douillet ici, non?' — 'It's cozy here, right?'",
                "Try: 'The little café was warm and snug.' → 'Le petit café était chaud et douillet.'",
                "Use 'douillet/douillette' in a sentence today — describe your coziest spot at home."
            ],
            practiceListenPhrases: [
                "douillet",
                "C'est tellement douillet ici.",
                "Elle s'est enveloppée dans la couverture douillette.",
                "C'est tellement douillet!",
                "C'est douillet ici, non?",
                "Le petit café était chaud et douillet.",
                nil
            ]
        ),
        FrenchWord(
            word: "vif / vive",
            type: "adjectif",
            forms: [
                WordForm(label: "masc. sg.", value: "vif"),
                WordForm(label: "fém. sg.",  value: "vive"),
                WordForm(label: "masc. pl.", value: "vifs"),
                WordForm(label: "fém. pl.",  value: "vives"),
            ],
            definition: "Lively, sharp, quick, vivid — used for a quick mind, vivid colours, a brisk pace, or intense emotion",
            example: "Elle a l'esprit vif et une répartie toujours prête.",
            exampleTranslation: "She has a quick mind and a ready comeback.",
            practiceQuestions: [
                "Say 'vif' (VEEF) / 'vive' (VEEV) — lively, sharp, vivid. A vif pace, vivid colours, a quick wit. Very versatile! Say both forms!",
                "Try: 'Elle a l'esprit vif.' — 'She has a sharp / quick mind.' Say it — think of someone this describes perfectly.",
                "Fill in the blank: 'The colours in that painting are so ________.' → 'Les couleurs dans ce tableau sont tellement ________.' (vives)",
                "Describe something with intensity today — a colour, a sound, a speed. Say: 'C'est vif!' or 'Elle est vive!'",
                "Compliment someone quick-witted: 'Tu as vraiment l'esprit vif!' — 'You really have a sharp mind!'",
                "Try: 'He walked at a quick, lively pace.' → 'Il marchait d'un pas vif.'",
                "Use 'vif/vive' in a sentence today — about a person's mind, a colour, a pace, or anything full of sharp energy."
            ],
            practiceListenPhrases: [
                "vif, vive",
                "Elle a l'esprit vif.",
                "Les couleurs dans ce tableau sont tellement vives.",
                "C'est vif!",
                "Tu as vraiment l'esprit vif!",
                "Il marchait d'un pas vif.",
                nil
            ]
        ),
        FrenchWord(
            word: "avoir le cafard",
            type: "expression",
            forms: [
                WordForm(label: "j'ai",        value: "le cafard"),
                WordForm(label: "tu as",        value: "le cafard"),
                WordForm(label: "il/elle a",    value: "le cafard"),
                WordForm(label: "nous avons",   value: "le cafard"),
                WordForm(label: "vous avez",    value: "le cafard"),
                WordForm(label: "ils/elles ont", value: "le cafard"),
                WordForm(label: "littéralement", value: "to have the cockroach"),
            ],
            definition: "To feel blue, down, melancholy — literally 'to have the cockroach' (quirky but very common!)",
            example: "Je ne sais pas pourquoi, mais j'ai le cafard aujourd'hui.",
            exampleTranslation: "I don't know why, but I'm feeling down today.",
            practiceQuestions: [
                "Say 'avoir le cafard' (ah-vwahr le kah-FAR) — to feel blue or melancholy. Literally 'to have the cockroach.' Weird but beautiful! Say it!",
                "Try: 'J'ai un peu le cafard.' — 'I'm feeling a little blue.' Very natural to say — and in French it feels less heavy somehow.",
                "Fill in the blank: 'On gray winter days I sometimes have ________.' → 'Les jours gris d'hiver, j'ai parfois ________ (le cafard).'",
                "Next time you feel a bit low today, say: 'J'ai le cafard.' Just naming it in French can help — try it.",
                "Check in with a friend: 'Tu as l'air d'avoir le cafard — ca va?' — 'You seem down — are you okay?'",
                "Try: 'She was feeling down after the news.' → 'Elle avait le cafard après les nouvelles.'",
                "Use 'avoir le cafard' in a sentence today — give yourself permission to name that feeling."
            ],
            practiceListenPhrases: [
                "avoir le cafard",
                "J'ai un peu le cafard.",
                "J'ai parfois le cafard les jours gris.",
                "J'ai le cafard.",
                "Tu as l'air d'avoir le cafard — ca va?",
                "Elle avait le cafard après les nouvelles.",
                nil
            ]
        ),
        FrenchWord(
            word: "tant pis",
            type: "expression",
            forms: [
                WordForm(label: "expression", value: "tant pis"),
                WordForm(label: "contraire",  value: "tant mieux"),
            ],
            definition: "Too bad, oh well, never mind — a very French shrug of acceptance",
            example: "Je n'ai pas eu le poste? Tant pis — une autre occasion viendra.",
            exampleTranslation: "I didn't get the job? Oh well — another opportunity will come.",
            practiceQuestions: [
                "Say 'tant pis' (tahn PEE) — 'too bad / oh well.' The French shrug in word form. You'll use this constantly. Say it!",
                "Try: 'Tant pis!' as a standalone. Say it with a shrug — like you're releasing something. It's freeing.",
                "Fill in the blank: 'We missed the bus. ________ — we'll walk.' → 'On a raté le bus. ________ — on va marcher.'",
                "Use 'tant pis' today when something small goes wrong. Missed a deadline? Forgot your umbrella? 'Tant pis!' and move on.",
                "Pair it with 'tant mieux': 'Tant pis si ca ne marche pas — tant mieux si ca marche!' — 'Too bad if it doesn't, great if it does!'",
                "Try: 'We didn't win, but oh well — we tried.' → 'On n'a pas gagné, mais tant pis — on a essayé.'",
                "Use 'tant pis' in a sentence today — practice letting go of something small with a very French shrug."
            ],
            practiceListenPhrases: [
                "tant pis",
                "Tant pis!",
                "On a raté le bus — tant pis!",
                "Tant pis!",
                "Tant pis si ca ne marche pas — tant mieux si ca marche!",
                "On n'a pas gagné, mais tant pis — on a essayé.",
                nil
            ]
        ),
        FrenchWord(
            word: "à tout à l'heure",
            type: "expression",
            forms: [
                WordForm(label: "expression", value: "à tout à l'heure"),
                WordForm(label: "abréviation", value: "à toute!"),
            ],
            definition: "See you in a bit, see you later — used when you'll see someone again soon",
            example: "Je pars chercher le café — à tout à l'heure!",
            exampleTranslation: "I'm going to grab coffee — see you in a bit!",
            practiceQuestions: [
                "Say 'à tout à l'heure' (ah too tah LEUR) — 'see you in a bit / see you later.' One of the most used French phrases. Practice the flow!",
                "Try: 'À tout à l'heure!' as a complete goodbye. Say it to someone — it works when parting for a few hours.",
                "Fill in the blank: 'I'll be back in an hour — ________!' → 'Je reviens dans une heure — ________!'",
                "Next time you leave a room or end a call today, say: 'À tout à l'heure!' instead of 'bye.' Start the habit!",
                "Use it in a message to a French-speaking friend: 'À tout à l'heure!' They'll be impressed — and it's completely natural.",
                "Try: 'She left saying she'd be back soon.' → 'Elle est partie en disant: à tout à l'heure.'",
                "Use 'à tout à l'heure' in a real goodbye today — say it until it flows naturally!"
            ],
            practiceListenPhrases: [
                "à tout à l'heure",
                "À tout à l'heure!",
                "Je reviens dans une heure — à tout à l'heure!",
                "À tout à l'heure!",
                "À tout à l'heure!",
                "Elle est partie en disant: à tout à l'heure.",
                nil
            ]
        ),
        FrenchWord(
            word: "avoir le coup de main",
            type: "expression",
            forms: [
                WordForm(label: "j'ai",        value: "le coup de main"),
                WordForm(label: "tu as",        value: "le coup de main"),
                WordForm(label: "il/elle a",    value: "le coup de main"),
                WordForm(label: "nous avons",   value: "le coup de main"),
                WordForm(label: "vous avez",    value: "le coup de main"),
                WordForm(label: "ils/elles ont", value: "le coup de main"),
                WordForm(label: "littéralement", value: "to have the hand stroke"),
            ],
            definition: "To have the knack, to have the touch — a natural skill that makes something easy",
            example: "Elle a vraiment le coup de main pour faire les crêpes — elles sont toujours parfaites.",
            exampleTranslation: "She really has the knack for making crêpes — they're always perfect.",
            practiceQuestions: [
                "Say 'avoir le coup de main' (ah-vwahr le koo de MAN) — to have the knack, the touch. Literal: 'have the hand stroke.' Say it!",
                "Try: 'J'ai le coup de main maintenant!' — 'I've got the knack now!' Say it when you finally figure something out.",
                "Fill in the blank: 'Once you ________ for it, parallel parking is easy.' → 'Une fois que tu as ________ pour ca, se garer en créneau c'est facile.'",
                "Think of something you've mastered. Say: 'J'ai le coup de main pour...' and name it proudly.",
                "Teach someone something and say: 'Je vais te montrer le coup de main!' — 'I'll show you the trick!' Use it next time you help.",
                "Try: 'It takes a few tries, but then you get the hang of it.' → 'Ca prend quelques essais, mais après tu as le coup de main.'",
                "Use 'avoir le coup de main' in a sentence — what's something you have le coup de main for?"
            ],
            practiceListenPhrases: [
                "avoir le coup de main",
                "J'ai le coup de main maintenant!",
                "Une fois que tu as le coup de main, c'est facile.",
                "J'ai le coup de main pour ca.",
                "Je vais te montrer le coup de main!",
                "Ca prend quelques essais, mais après tu as le coup de main.",
                nil
            ]
        ),
        FrenchWord(
            word: "se faire du souci",
            type: "expression",
            forms: [
                WordForm(label: "je",        value: "me fais du souci"),
                WordForm(label: "tu",        value: "te fais du souci"),
                WordForm(label: "il/elle",   value: "se fait du souci"),
                WordForm(label: "nous",      value: "nous faisons du souci"),
                WordForm(label: "vous",      value: "vous faites du souci"),
                WordForm(label: "ils/elles", value: "se font du souci"),
                WordForm(label: "négatif",   value: "ne te fais pas de souci"),
            ],
            definition: "To worry, to be anxious — the common French expression for feeling worried",
            example: "Ne te fais pas de souci — tout va bien se passer!",
            exampleTranslation: "Don't worry — everything is going to be just fine!",
            practiceQuestions: [
                "Say 'se faire du souci' (se FAIR doo soo-SEE) — to worry. 'Ne te fais pas de souci' = don't worry. You'll use this all the time. Say it!",
                "Try: 'Je me fais du souci.' — 'I'm worried.' Then: 'Ne te fais pas de souci!' — 'Don't worry!' Practice both back to back.",
                "Fill in the blank: 'She always ________ about everything.' → 'Elle se ________ pour tout.' (fait du souci)",
                "If you're worried about something today, say: 'Je me fais du souci pour...' — naming it out loud can help release it.",
                "Comfort a friend: 'Ne te fais pas de souci — ca va aller.' — 'Don't worry — it'll be okay.' Use it today.",
                "Try: 'His parents worried a lot about his trip.' → 'Ses parents se sont beaucoup fait de souci pour son voyage.'",
                "Use 'se faire du souci' in a sentence — either express a worry or reassure someone else in French."
            ],
            practiceListenPhrases: [
                "se faire du souci",
                "Je me fais du souci.",
                "Elle se fait du souci pour tout.",
                "Je me fais du souci pour ca.",
                "Ne te fais pas de souci — ca va aller.",
                "Ses parents se sont beaucoup fait de souci pour son voyage.",
                nil
            ]
        )
    ]
}
