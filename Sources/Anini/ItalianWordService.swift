import Foundation
import AVFoundation

struct ItalianWord {
    let word: String
    let type: String
    let gender: WordGender?
    let forms: [WordForm]
    let definition: String
    let example: String
    let exampleTranslation: String
    let exampleMasc: String?
    let practiceQuestions: [String]
    let practiceListenPhrases: [String?]
    let practiceListenPhrasesMasc: [String?]

    init(
        word: String,
        type: String,
        gender: WordGender? = nil,
        forms: [WordForm] = [],
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

final class ItalianWordService {
    static let shared = ItalianWordService()
    private init() {}

    private let synthesizer = AVSpeechSynthesizer()

    var currentWord: ItalianWord {
        let week = Calendar.current.component(.weekOfYear, from: Date())
        return words[week % words.count]
    }

    var todayPracticeQuestion: String {
        let day = Calendar.current.component(.weekday, from: Date()) - 1
        let qs  = currentWord.practiceQuestions
        return qs[min(day, qs.count - 1)]
    }

    var allWords: [ItalianWord] { words }

    var todayListenPhrase: String? { resolvedListenPhrase() }

    func resolvedListenPhrase() -> String? {
        let day = Calendar.current.component(.weekday, from: Date()) - 1
        return listenPhrase(for: currentWord, practiceIndex: day)
    }

    func listenPhrase(for word: ItalianWord, practiceIndex: Int) -> String? {
        guard practiceIndex < word.practiceListenPhrases.count else { return nil }
        if WorkspaceConfig.shared.userGender == .masculine,
           practiceIndex < word.practiceListenPhrasesMasc.count,
           let mascPhrase = word.practiceListenPhrasesMasc[practiceIndex] {
            return mascPhrase
        }
        return word.practiceListenPhrases[practiceIndex]
    }

    func resolvedExample(for word: ItalianWord) -> String {
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
        utterance.voice           = AVSpeechSynthesisVoice(language: "it-IT")
        utterance.rate            = slow ? 0.1 : 0.38
        utterance.pitchMultiplier = 1.05
        synthesizer.speak(utterance)
    }

    // MARK: – Word list (rotates by ISO week number)

    private let words: [ItalianWord] = [
        ItalianWord(
            word: "passeggiata",
            type: "nome",
            gender: .feminine,
            forms: [
                WordForm(label: "singolare",  value: "la passeggiata"),
                WordForm(label: "plurale",    value: "le passeggiate"),
            ],
            definition: "A leisurely stroll, often taken in the evening as a social ritual.",
            example: "Sono andata a fare una passeggiata nel parco.",
            exampleTranslation: "I went for a stroll in the park.",
            exampleMasc: "Sono andato a fare una passeggiata nel parco.",
            practiceQuestions: [
                "Say 'passeggiata' (pass-ed-JAH-tah). It's the beautiful Italian tradition of an evening stroll — not for exercise, just for life. Say it out loud!",
                "Try: 'Vado a fare una passeggiata.' — 'I'm going for a stroll.' Say it like you're heading out into a sunny Italian piazza.",
                "Fill in the blank: 'After dinner we always ________.' In Italian: 'Dopo cena facciamo sempre una ________.'",
                "Say 'Ho bisogno di una passeggiata.' — 'I need a stroll.' That's a full sentence. Say it whenever you feel restless today!",
                "Challenge: can you say where you'd take your passeggiata? Try: 'Voglio fare una passeggiata...' and add a place — al parco, in centro, sul lungomare.",
                "Translate: 'Let's go for a nice stroll.' → 'Facciamo una bella passeggiata.' Say it with enthusiasm!",
                "Use passeggiata in a real sentence about your day. Did you go for a walk? Want to? Say it in Italian!"
            ],
            practiceListenPhrases: [
                "passeggiata. Vado a fare una passeggiata.",
                "Vado a fare una passeggiata.",
                "Dopo cena facciamo sempre una passeggiata.",
                "Ho bisogno di una passeggiata.",
                "Voglio fare una passeggiata al parco.",
                "Facciamo una bella passeggiata.",
                nil
            ],
            practiceListenPhrasesMasc: []
        ),

        ItalianWord(
            word: "speranza",
            type: "nome",
            gender: .feminine,
            forms: [
                WordForm(label: "singolare",  value: "la speranza"),
                WordForm(label: "plurale",    value: "le speranze"),
            ],
            definition: "Hope; the feeling that something desired is possible.",
            example: "Ho ancora speranza che le cose migliorano.",
            exampleTranslation: "I still have hope that things will get better.",
            practiceQuestions: [
                "Say 'speranza' (spe-RAN-tsah). It means hope — one of the most beautiful Italian nouns. Say it slowly, feel it.",
                "Try: 'Ho speranza.' — 'I have hope.' Simple and powerful. Say it out loud.",
                "Fill in the blank: 'There is always ________.' In Italian: 'C'è sempre ________.'",
                "Say 'Non perdere la speranza.' — 'Don't lose hope.' That's a full encouraging phrase. Say it to yourself today!",
                "Challenge: What do you have hope for? Try: 'Ho speranza che...' and finish the sentence in English or Italian.",
                "Translate: 'Hope is beautiful.' → 'La speranza è bella.' Say it!",
                "Use speranza today — either say it to yourself or use it in a sentence. You've got this!"
            ],
            practiceListenPhrases: [
                "speranza. Ho speranza.",
                "Ho speranza.",
                "C'è sempre speranza.",
                "Non perdere la speranza.",
                "Ho speranza che le cose migliorano.",
                "La speranza è bella.",
                nil
            ]
        ),

        ItalianWord(
            word: "magari",
            type: "avverbio / esclamazione",
            gender: nil,
            forms: [],
            definition: "Maybe; if only; I wish — a uniquely Italian expression of desire, hope, or possibility.",
            example: "Magari potessi stare qui per sempre.",
            exampleTranslation: "If only I could stay here forever.",
            practiceQuestions: [
                "Say 'magari' (mah-GAH-ree). It's one of the most Italian words there is — it means 'maybe', 'if only', or 'I wish', all in one. Say it with longing!",
                "Try: 'Magari!' on its own — it means 'I wish!' or 'That would be amazing!' Say it like you mean it.",
                "Fill in the blank: '________, un giorno andrò in Italia.' → 'Magari, un giorno andrò in Italia.' — 'Maybe one day I'll go to Italy.'",
                "Use 'magari' as a response today. Someone asks you to do something fun — answer 'Magari!' Say it out loud.",
                "Challenge: say 'Magari potessi...' — 'If only I could...' and finish with your wish. In Italian or English, it counts!",
                "Translate: 'Maybe tomorrow.' → 'Magari domani.' Short, sweet, Italian. Say it!",
                "Use magari in a real sentence today. What's something you wish for? 'Magari...'"
            ],
            practiceListenPhrases: [
                "magari! Magari!",
                "Magari!",
                "Magari, un giorno andrò in Italia.",
                "Magari!",
                "Magari potessi restare.",
                "Magari domani.",
                nil
            ]
        ),

        ItalianWord(
            word: "meraviglioso",
            type: "aggettivo",
            gender: nil,
            forms: [
                WordForm(label: "masc. sing.",  value: "meraviglioso"),
                WordForm(label: "femm. sing.",   value: "meravigliosa"),
                WordForm(label: "masc. plur.",   value: "meravigliosi"),
                WordForm(label: "femm. plur.",   value: "meravigliose"),
            ],
            definition: "Wonderful, marvelous, magnificent — a word full of awe and delight.",
            example: "Questa giornata è stata meravigliosa.",
            exampleTranslation: "This day has been wonderful.",
            practiceQuestions: [
                "Say 'meraviglioso' (meh-rah-veel-YOH-zoh). It rolls off the tongue beautifully. It means wonderful, marvelous. Say it with joy!",
                "Try: 'È meraviglioso!' — 'It's wonderful!' Say it with genuine excitement about something in your day.",
                "Fill in the blank: 'The view is ________.' In Italian: 'Il panorama è ________.' (use the right ending!)",
                "Say 'Che giornata meravigliosa!' — 'What a wonderful day!' Say it even if the day isn't perfect — practice makes perfect!",
                "Challenge: use the feminine form. Say 'La vita è meravigliosa.' — 'Life is wonderful.' Then try the masculine: 'Il mondo è meraviglioso.'",
                "Translate: 'You are wonderful.' → 'Sei meraviglioso/a.' Say both forms!",
                "Use meraviglioso today — describe something in your life as meraviglioso/a. Say it out loud!"
            ],
            practiceListenPhrases: [
                "meraviglioso. È meraviglioso!",
                "È meraviglioso!",
                "Il panorama è meraviglioso.",
                "Che giornata meravigliosa!",
                "La vita è meravigliosa. Il mondo è meraviglioso.",
                "Sei meravigliosa.",
                nil
            ],
            practiceListenPhrasesMasc: [
                nil,
                nil,
                nil,
                nil,
                nil,
                "Sei meraviglioso.",
                nil
            ]
        ),

        ItalianWord(
            word: "abbraccio",
            type: "nome",
            gender: .masculine,
            forms: [
                WordForm(label: "singolare",  value: "l'abbraccio"),
                WordForm(label: "plurale",    value: "gli abbracci"),
            ],
            definition: "A hug, an embrace — warmth and closeness in one beautiful word.",
            example: "Ho bisogno di un grande abbraccio.",
            exampleTranslation: "I need a big hug.",
            practiceQuestions: [
                "Say 'abbraccio' (ab-BRAT-choh). It means hug. It even sounds warm! Say it with a smile.",
                "Try: 'Ti mando un abbraccio.' — 'I'm sending you a hug.' That's a full sentence — say it to someone you love today.",
                "Fill in the blank: 'After a hard day, I need a ________.' In Italian: 'Dopo una giornata difficile, ho bisogno di un ________.'",
                "Say 'Un grande abbraccio!' — often how Italians close messages to loved ones, like 'Big hugs!' Say it out loud.",
                "Challenge: Can you say 'She gave me the warmest hug'? Try: 'Mi ha dato il più bel abbraccio.'",
                "Translate: 'Hugs from Italy!' → 'Abbracci dall'Italia!' Say it!",
                "Use abbraccio today — say it, send it in a message, or just hold the word in mind. Un abbraccio!"
            ],
            practiceListenPhrases: [
                "abbraccio. Ti mando un abbraccio.",
                "Ti mando un abbraccio.",
                "Ho bisogno di un grande abbraccio.",
                "Un grande abbraccio!",
                "Mi ha dato il più bel abbraccio.",
                "Abbracci dall'Italia!",
                nil
            ]
        ),

        ItalianWord(
            word: "dolce",
            type: "aggettivo / avverbio",
            gender: nil,
            forms: [
                WordForm(label: "sing. m/f",    value: "dolce"),
                WordForm(label: "plurale m/f",   value: "dolci"),
            ],
            definition: "Sweet; gentle; soft — also the name for dessert in Italian.",
            example: "Ha una voce dolce e una risata contagiosa.",
            exampleTranslation: "She has a sweet voice and a contagious laugh.",
            practiceQuestions: [
                "Say 'dolce' (DOL-cheh). It means sweet — the taste, a feeling, a sound. It's also 'dessert' in Italian! Say it gently.",
                "Try: 'Dolce vita!' — 'Sweet life!' the iconic phrase. Say it like you're living your best life.",
                "Fill in the blank: 'The music sounds ________.' In Italian: 'La musica suona ________.'",
                "Say 'Che dolce sorpresa!' — 'What a sweet surprise!' Practice the full phrase.",
                "Challenge: use dolce to describe two things — a taste and a feeling. 'Questo caffè è dolce. Che momento dolce.'",
                "Translate: 'Life is sweet.' → 'La vita è dolce.' Say it like the Italians do!",
                "Use dolce today in a real context — taste something sweet and say 'È dolce!' out loud."
            ],
            practiceListenPhrases: [
                "dolce. Dolce vita!",
                "Dolce vita!",
                "La musica suona dolce.",
                "Che dolce sorpresa!",
                "Questo caffè è dolce. Che momento dolce.",
                "La vita è dolce.",
                nil
            ]
        ),

        ItalianWord(
            word: "tranquillo",
            type: "aggettivo",
            gender: nil,
            forms: [
                WordForm(label: "masc. sing.",  value: "tranquillo"),
                WordForm(label: "femm. sing.",   value: "tranquilla"),
                WordForm(label: "masc. plur.",   value: "tranquilli"),
                WordForm(label: "femm. plur.",   value: "tranquille"),
            ],
            definition: "Calm, peaceful, relaxed — a reassuring word Italians use constantly.",
            example: "Stai tranquilla, penso a tutto io.",
            exampleTranslation: "Relax, I'll take care of everything.",
            exampleMasc: "Stai tranquillo, penso a tutto io.",
            practiceQuestions: [
                "Say 'tranquillo' (tran-KWEEL-loh). It means calm, peaceful, don't worry. Italians say it all the time to reassure each other. Say it!",
                "Try: 'Tranquillo!' or 'Tranquilla!' on its own — it means 'Don't worry!' or 'It's all good!' Say it in your gender.",
                "Fill in the blank: 'It's a ________ neighborhood.' In Italian: 'È un quartiere ________.'",
                "Say 'Tutto tranquillo.' — 'Everything is fine / all quiet.' A great reassuring phrase. Say it calmly.",
                "Challenge: say 'I feel calm today.' → 'Mi sento tranquillo/a oggi.' Use your own gender ending!",
                "Translate: 'Stay calm, everything is okay.' → 'Stai tranquillo/a, va tutto bene.' Say it soothingly!",
                "Use tranquillo/a today — say it to yourself as a mantra, or picture a tranquil Italian village. Tranquillo."
            ],
            practiceListenPhrases: [
                "tranquillo. Tranquilla!",
                "Tranquilla!",
                "È un quartiere tranquillo.",
                "Tutto tranquillo.",
                "Mi sento tranquilla oggi.",
                "Stai tranquilla, va tutto bene.",
                nil
            ],
            practiceListenPhrasesMasc: [
                "tranquillo. Tranquillo!",
                "Tranquillo!",
                nil,
                nil,
                "Mi sento tranquillo oggi.",
                "Stai tranquillo, va tutto bene.",
                nil
            ]
        ),

        ItalianWord(
            word: "forza",
            type: "nome / esclamazione",
            gender: .feminine,
            forms: [
                WordForm(label: "singolare",  value: "la forza"),
                WordForm(label: "plurale",    value: "le forze"),
            ],
            definition: "Strength, force — and as an exclamation: 'Come on!', 'You can do it!'",
            example: "Hai tutta la forza di cui hai bisogno.",
            exampleTranslation: "You have all the strength you need.",
            practiceQuestions: [
                "Say 'forza' (FOR-tsah). As a noun it means strength. As a cheer, 'Forza!' means 'Come on!' or 'Go for it!' Say it loud!",
                "Try: 'Forza!' on its own — it's the most Italian encouragement. Shout it when you need a push today.",
                "Fill in the blank: 'You have the ________ to do this.' In Italian: 'Hai la ________ per farcela.'",
                "Say 'Ce la fai, forza!' — 'You can do it, come on!' The ultimate Italian pep talk. Say it with energy!",
                "Challenge: say 'I find strength in music.' → 'Trovo forza nella musica.' Substitute your own source of strength.",
                "Translate: 'Come on, let's go!' → 'Forza, andiamo!' Say it like you're at a football match!",
                "Use forza today — say it to yourself when you need encouragement. Or shout 'Forza!' at the right moment!"
            ],
            practiceListenPhrases: [
                "forza! Forza!",
                "Forza!",
                "Hai la forza per farcela.",
                "Ce la fai, forza!",
                "Trovo forza nella musica.",
                "Forza, andiamo!",
                nil
            ]
        ),

        ItalianWord(
            word: "incantevole",
            type: "aggettivo",
            gender: nil,
            forms: [
                WordForm(label: "sing. m/f",    value: "incantevole"),
                WordForm(label: "plurale m/f",   value: "incantevoli"),
            ],
            definition: "Enchanting, charming, delightful — something that casts a spell on you.",
            example: "Questo posto è assolutamente incantevole.",
            exampleTranslation: "This place is absolutely enchanting.",
            practiceQuestions: [
                "Say 'incantevole' (in-can-TEH-voh-leh). It means enchanting. It comes from 'incanto' — a spell or charm. Say it with wonder!",
                "Try: 'È incantevole!' — 'It's enchanting!' Think of something beautiful and say it with conviction.",
                "Fill in the blank: 'The village is absolutely ________.' In Italian: 'Il paese è assolutamente ________.'",
                "Say 'Sei incantevole.' — 'You are enchanting.' The ultimate Italian compliment. Practice saying it warmly.",
                "Challenge: use incantevole to describe nature. 'Il tramonto è incantevole.' — 'The sunset is enchanting.' Say it!",
                "Translate: 'What an enchanting evening!' → 'Che serata incantevole!' Say it like you're watching Italian stars.",
                "Use incantevole today — look at something beautiful and say 'È incantevole!' out loud."
            ],
            practiceListenPhrases: [
                "incantevole. È incantevole!",
                "È incantevole!",
                "Il paese è assolutamente incantevole.",
                "Sei incantevole.",
                "Il tramonto è incantevole.",
                "Che serata incantevole!",
                nil
            ]
        ),

        ItalianWord(
            word: "assaporare",
            type: "verbo",
            gender: nil,
            forms: [
                WordForm(label: "io",          value: "assaporo"),
                WordForm(label: "tu",          value: "assapori"),
                WordForm(label: "lui / lei",   value: "assapora"),
                WordForm(label: "noi",         value: "assaporiamo"),
                WordForm(label: "voi",         value: "assaporate"),
                WordForm(label: "loro",        value: "assaporano"),
            ],
            definition: "To savour, to taste slowly, to relish — to enjoy something fully and without rushing.",
            example: "Devi assaporare ogni momento.",
            exampleTranslation: "You must savour every moment.",
            practiceQuestions: [
                "Say 'assaporare' (as-sah-poh-RAH-reh). It means to savour — to taste slowly, to relish. It's the opposite of rushing. Say it slowly!",
                "Try: 'Assaporo il caffè.' — 'I'm savouring the coffee.' Say it the next time you have a drink you love.",
                "Fill in the blank: 'Take your time to ________ this meal.' In Italian: 'Prenditi il tempo di ________ questo pasto.'",
                "Say 'Voglio assaporare ogni momento.' — 'I want to savour every moment.' Say it like a life philosophy.",
                "Challenge: use assaporare with something you love — a song, a view, a meal. 'Assaporo...' and add it.",
                "Translate: 'She savours every small joy.' → 'Lei assapora ogni piccola gioia.' Say it!",
                "Use assaporare today — when you eat, drink, or enjoy something, say 'Sto assaporando.' Try it!"
            ],
            practiceListenPhrases: [
                "assaporare. Assaporo il caffè.",
                "Assaporo il caffè.",
                "Prenditi il tempo di assaporare questo pasto.",
                "Voglio assaporare ogni momento.",
                "Assaporo la musica.",
                "Lei assapora ogni piccola gioia.",
                nil
            ]
        ),

        ItalianWord(
            word: "bello",
            type: "aggettivo",
            gender: nil,
            forms: [
                WordForm(label: "masc. sing.",  value: "bello / bel"),
                WordForm(label: "femm. sing.",   value: "bella"),
                WordForm(label: "masc. plur.",   value: "belli / bei"),
                WordForm(label: "femm. plur.",   value: "belle"),
            ],
            definition: "Beautiful, handsome, lovely — one of the most used Italian adjectives, full of warmth.",
            example: "Che bella giornata!",
            exampleTranslation: "What a beautiful day!",
            practiceQuestions: [
                "Say 'bello' (BEL-loh). It means beautiful, handsome, lovely — Italians use it constantly. Say it out loud!",
                "Try: 'Che bello!' — 'How wonderful!' or 'Che bella!' for something feminine. Say it with genuine delight.",
                "Fill in the blank: 'What a beautiful city!' In Italian: 'Che ________ città!'",
                "Say 'Sei bellissima!' or 'Sei bellissimo!' — 'You are so beautiful!' Try both forms, for any person you admire.",
                "Challenge: bella vs bello. Say 'bella donna' (beautiful woman), 'bel ragazzo' (handsome guy), 'belle scarpe' (beautiful shoes). Notice the forms!",
                "Translate: 'It's a beautiful life.' → 'È una bella vita.' Say it with Italian feeling!",
                "Use bello/bella today — say 'Che bello!' when something nice happens. Notice how often it fits!"
            ],
            practiceListenPhrases: [
                "bello. Che bello!",
                "Che bello!",
                "Che bella città!",
                "Sei bellissima!",
                "Bella donna, bel ragazzo, belle scarpe.",
                "È una bella vita.",
                nil
            ],
            practiceListenPhrasesMasc: [
                nil,
                nil,
                nil,
                "Sei bellissimo!",
                nil,
                nil,
                nil
            ]
        ),

        ItalianWord(
            word: "capire",
            type: "verbo",
            gender: nil,
            forms: [
                WordForm(label: "io",          value: "capisco"),
                WordForm(label: "tu",          value: "capisci"),
                WordForm(label: "lui / lei",   value: "capisce"),
                WordForm(label: "noi",         value: "capiamo"),
                WordForm(label: "voi",         value: "capite"),
                WordForm(label: "loro",        value: "capiscono"),
            ],
            definition: "To understand — one of the most useful verbs when learning Italian.",
            example: "Non capisco tutto, ma ci provo.",
            exampleTranslation: "I don't understand everything, but I'm trying.",
            practiceQuestions: [
                "Say 'capire' (kah-PEE-reh) — to understand. Also great as a phrase: 'Capisci?' — 'Do you understand?' Say both!",
                "Try: 'Capisco!' — 'I understand!' or 'Non capisco.' — 'I don't understand.' Both are essential. Practice them!",
                "Fill in the blank: 'Do you understand Italian?' In Italian: 'Capisci l'italiano?'",
                "Say 'Piano piano si capisce tutto.' — 'Little by little, you understand everything.' A great Italian encouragement. Say it!",
                "Challenge: use capire in two sentences — one positive, one negative. 'Capisco.' then 'Non capisco ancora, ma ci provo.'",
                "Translate: 'She understands perfectly.' → 'Lei capisce perfettamente.' Say it!",
                "Use capire today — next time something clicks for you, say 'Capisco!' out loud. You're speaking Italian!"
            ],
            practiceListenPhrases: [
                "capire. Capisco!",
                "Capisco! Non capisco.",
                "Capisci l'italiano?",
                "Piano piano si capisce tutto.",
                "Capisco. Non capisco ancora, ma ci provo.",
                "Lei capisce perfettamente.",
                nil
            ]
        ),
    ]
}
