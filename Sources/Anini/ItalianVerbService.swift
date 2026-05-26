import Foundation

struct ItalianVerb {
    let verb: String
    let verbType: String
    let meaning: String
    let conjugation: [WordForm]          // exactly 6: io, tu, lui/lei, noi, voi, loro
    let example: String
    let exampleTranslation: String
    let practiceQuestions: [String]      // exactly 7 (Sun–Sat)
    let practiceListenPhrases: [String?] // exactly 7
}

final class ItalianVerbService {
    static let shared = ItalianVerbService()
    private init() {}

    var currentVerb: ItalianVerb {
        let week = Calendar.current.component(.weekOfYear, from: Date())
        return verbs[week % verbs.count]
    }

    var allVerbs: [ItalianVerb] { verbs }

    func listenPhrase(for verb: ItalianVerb, practiceIndex: Int) -> String? {
        guard practiceIndex < verb.practiceListenPhrases.count else { return nil }
        return verb.practiceListenPhrases[practiceIndex]
    }

    func speak(text: String, slow: Bool = false) {
        ItalianWordService.shared.speak(text: text, slow: slow)
    }

    // MARK: – Verb list (rotates by ISO week number)

    private let verbs: [ItalianVerb] = [
        ItalianVerb(
            verb: "essere",
            verbType: "verbo irregolare",
            meaning: "to be",
            conjugation: [
                WordForm(label: "io",           value: "sono"),
                WordForm(label: "tu",           value: "sei"),
                WordForm(label: "lui / lei",    value: "è"),
                WordForm(label: "noi",          value: "siamo"),
                WordForm(label: "voi",          value: "siete"),
                WordForm(label: "loro",         value: "sono"),
            ],
            example: "Sono felicissima di essere qui con voi.",
            exampleTranslation: "I am so happy to be here with you all.",
            practiceQuestions: [
                "Say 'essere' (ES-seh-reh) — to be. The most essential verb in Italian. Say all forms out loud: io sono, tu sei, lui è, noi siamo, voi siete, loro sono.",
                "Try: 'Io sono...' — finish with your mood, where you are, or how you feel right now. Say the full sentence!",
                "Fill in the blank: 'We are so happy.' → 'Noi _______ così felici.' And: 'You are very kind.' → 'Sei molto gentile.'",
                "Use 'sono' in a real sentence today. 'Sono stanca/o.' 'Sono a casa.' 'Sono contenta/o.' Say one out loud!",
                "Challenge: conjugate 'essere' for all 6 persons from memory. No peeking! How many do you get right?",
                "Translate: 'They are really good friends.' → 'Sono davvero buoni amici.' Say it!",
                "Make up your own sentence using essere. Any subject, any mood. Just say it out loud — you're speaking Italian!"
            ],
            practiceListenPhrases: [
                "essere. Io sono, tu sei, lui è, noi siamo, voi siete, loro sono.",
                "Sono contenta di essere qui.",
                "Noi siamo così felici.",
                "Sono davvero bene oggi.",
                "Io sono, tu sei, lui è, noi siamo, voi siete, loro sono.",
                "Sono davvero buoni amici.",
                nil
            ]
        ),

        ItalianVerb(
            verb: "avere",
            verbType: "verbo irregolare",
            meaning: "to have",
            conjugation: [
                WordForm(label: "io",           value: "ho"),
                WordForm(label: "tu",           value: "hai"),
                WordForm(label: "lui / lei",    value: "ha"),
                WordForm(label: "noi",          value: "abbiamo"),
                WordForm(label: "voi",          value: "avete"),
                WordForm(label: "loro",         value: "hanno"),
            ],
            example: "Ho voglia di una tazza di caffè.",
            exampleTranslation: "I feel like having a cup of coffee.",
            practiceQuestions: [
                "Say 'avere' (ah-VEH-reh) — to have. It's also used for emotions and sensations in Italian: 'ho fame' = I'm hungry, 'ho paura' = I'm afraid. Say all forms!",
                "Try: 'Ho voglia di...' — 'I feel like...' a delicious Italian idiom. 'Ho voglia di un gelato.' Say it!",
                "Fill in the blank: 'She has a lot of patience.' → 'Lei _______ molta pazienza.'",
                "Use avere for a feeling: 'Ho fame.' 'Ho sonno.' 'Ho freddo.' — 'I'm hungry / sleepy / cold.' Which one fits right now?",
                "Challenge: conjugate avere for all 6 — io ho, tu hai... from memory. These forms are used constantly!",
                "Translate: 'Do you have time?' → 'Hai tempo?' Short, useful, real Italian. Say it!",
                "Use avere in a real sentence today. What do you have or feel like having? 'Ho...'"
            ],
            practiceListenPhrases: [
                "avere. Io ho, tu hai, lui ha, noi abbiamo, voi avete, loro hanno.",
                "Ho voglia di un gelato.",
                "Lei ha molta pazienza.",
                "Ho fame. Ho sonno. Ho freddo.",
                "Io ho, tu hai, lui ha, noi abbiamo, voi avete, loro hanno.",
                "Hai tempo?",
                nil
            ]
        ),

        ItalianVerb(
            verb: "fare",
            verbType: "verbo irregolare",
            meaning: "to do / to make",
            conjugation: [
                WordForm(label: "io",           value: "faccio"),
                WordForm(label: "tu",           value: "fai"),
                WordForm(label: "lui / lei",    value: "fa"),
                WordForm(label: "noi",          value: "facciamo"),
                WordForm(label: "voi",          value: "fate"),
                WordForm(label: "loro",         value: "fanno"),
            ],
            example: "Cosa fai di bello oggi?",
            exampleTranslation: "What are you up to today? (literally: what beautiful thing are you doing?)",
            practiceQuestions: [
                "Say 'fare' (FAH-reh) — to do, to make. In Italian, fare is incredibly versatile: 'fare una passeggiata' (go for a walk), 'fare la spesa' (go grocery shopping). Say all forms!",
                "Try: 'Cosa fai?' — 'What are you doing?' The most casual, everyday Italian question. Practice it!",
                "Fill in the blank: 'We are making dinner.' → 'Noi _______ la cena.'",
                "Use fare in an Italian idiom: 'Faccio una passeggiata.' — 'I'm going for a walk.' Say it and picture yourself strolling!",
                "Challenge: can you conjugate fare from memory? It's irregular — faccio, fai, fa, facciamo, fate, fanno. Try it!",
                "Translate: 'What shall we do tonight?' → 'Cosa facciamo stasera?' Say it with an Italian shrug!",
                "Use fare in a real sentence today — what are you doing? 'Faccio...' and finish it in Italian or English!"
            ],
            practiceListenPhrases: [
                "fare. Io faccio, tu fai, lui fa, noi facciamo, voi fate, loro fanno.",
                "Cosa fai?",
                "Noi facciamo la cena.",
                "Faccio una passeggiata.",
                "Faccio, fai, fa, facciamo, fate, fanno.",
                "Cosa facciamo stasera?",
                nil
            ]
        ),

        ItalianVerb(
            verb: "andare",
            verbType: "verbo irregolare",
            meaning: "to go",
            conjugation: [
                WordForm(label: "io",           value: "vado"),
                WordForm(label: "tu",           value: "vai"),
                WordForm(label: "lui / lei",    value: "va"),
                WordForm(label: "noi",          value: "andiamo"),
                WordForm(label: "voi",          value: "andate"),
                WordForm(label: "loro",         value: "vanno"),
            ],
            example: "Andiamo al mare questo weekend!",
            exampleTranslation: "Let's go to the sea this weekend!",
            practiceQuestions: [
                "Say 'andare' (an-DAH-reh) — to go. Italians use it everywhere: 'Come va?' — 'How's it going?' Say all forms: vado, vai, va, andiamo, andate, vanno!",
                "Try: 'Come va?' — 'How are you going?' / 'How's it going?' And reply: 'Va bene!' — 'Going well!' Practice both!",
                "Fill in the blank: 'I'm going to the market.' → 'Vado al ________.'",
                "Use the most Italian phrase: 'Andiamo!' — 'Let's go!' Say it with energy, like you're heading somewhere wonderful.",
                "Challenge: conjugate andare — vado, vai, va... from memory. These come up in every Italian conversation!",
                "Translate: 'Where are you going?' → 'Dove vai?' So simple and so useful. Say it!",
                "Use andare today — where are you going? 'Vado...' and finish the sentence!"
            ],
            practiceListenPhrases: [
                "andare. Vado, vai, va, andiamo, andate, vanno.",
                "Come va? Va bene!",
                "Vado al mercato.",
                "Andiamo!",
                "Vado, vai, va, andiamo, andate, vanno.",
                "Dove vai?",
                nil
            ]
        ),

        ItalianVerb(
            verb: "mangiare",
            verbType: "verbo regolare (-are)",
            meaning: "to eat",
            conjugation: [
                WordForm(label: "io",           value: "mangio"),
                WordForm(label: "tu",           value: "mangi"),
                WordForm(label: "lui / lei",    value: "mangia"),
                WordForm(label: "noi",          value: "mangiamo"),
                WordForm(label: "voi",          value: "mangiate"),
                WordForm(label: "loro",         value: "mangiano"),
            ],
            example: "Mangiamo qualcosa di buono stasera!",
            exampleTranslation: "Let's eat something good tonight!",
            practiceQuestions: [
                "Say 'mangiare' (man-JAH-reh) — to eat. One of the most important verbs in Italian culture! Say all forms with enthusiasm.",
                "Try: 'Cosa mangi?' — 'What are you eating?' / 'Che mangi di solito?' — 'What do you usually eat?' Practice!",
                "Fill in the blank: 'We eat together every Sunday.' → 'Mangiamo insieme ogni ________.'",
                "Say 'Mangiamo!' — 'Let's eat!' The best invitation. Say it like you're sitting down to a beautiful meal.",
                "Challenge: use mangiare in two sentences — one with what you're eating now, one with what you love to eat.",
                "Translate: 'I eat a lot of pasta.' → 'Mangio molta pasta.' Buonissimo! Say it!",
                "Use mangiare today — next time you sit down to eat, say 'Mangio...' and name your food in Italian if you can!"
            ],
            practiceListenPhrases: [
                "mangiare. Mangio, mangi, mangia, mangiamo, mangiate, mangiano.",
                "Cosa mangi?",
                "Mangiamo insieme ogni domenica.",
                "Mangiamo!",
                "Mangio la pizza. Mangio molta frutta.",
                "Mangio molta pasta.",
                nil
            ]
        ),

        ItalianVerb(
            verb: "parlare",
            verbType: "verbo regolare (-are)",
            meaning: "to speak / to talk",
            conjugation: [
                WordForm(label: "io",           value: "parlo"),
                WordForm(label: "tu",           value: "parli"),
                WordForm(label: "lui / lei",    value: "parla"),
                WordForm(label: "noi",          value: "parliamo"),
                WordForm(label: "voi",          value: "parlate"),
                WordForm(label: "loro",         value: "parlano"),
            ],
            example: "Parlo italiano un po', ma mi sto migliorando!",
            exampleTranslation: "I speak a little Italian, but I'm improving!",
            practiceQuestions: [
                "Say 'parlare' (par-LAH-reh) — to speak. This is the verb that describes what you're doing right now by learning Italian! Say all forms.",
                "Try the most important sentence: 'Parlo italiano un po'.' — 'I speak a little Italian.' Say it with pride — it's true!",
                "Fill in the blank: 'She speaks French and Italian.' → 'Parla francese e ________.'",
                "Say 'Parliamo in italiano!' — 'Let's speak in Italian!' Use it as a challenge to yourself today.",
                "Challenge: conjugate parlare — parlo, parli... It's a regular -are verb, so once you know the pattern, you know hundreds!",
                "Translate: 'Do you speak English?' → 'Parli inglese?' The first question every Italian learner needs!",
                "Use parlare today — say 'Parlo italiano!' out loud. Because you do — a little bit more every day!"
            ],
            practiceListenPhrases: [
                "parlare. Parlo, parli, parla, parliamo, parlate, parlano.",
                "Parlo italiano un po'.",
                "Parla francese e italiano.",
                "Parliamo in italiano!",
                "Parlo, parli, parla, parliamo, parlate, parlano.",
                "Parli inglese?",
                nil
            ]
        ),

        ItalianVerb(
            verb: "volere",
            verbType: "verbo irregolare",
            meaning: "to want",
            conjugation: [
                WordForm(label: "io",           value: "voglio"),
                WordForm(label: "tu",           value: "vuoi"),
                WordForm(label: "lui / lei",    value: "vuole"),
                WordForm(label: "noi",          value: "vogliamo"),
                WordForm(label: "voi",          value: "volete"),
                WordForm(label: "loro",         value: "vogliono"),
            ],
            example: "Voglio imparare l'italiano davvero bene.",
            exampleTranslation: "I want to learn Italian really well.",
            practiceQuestions: [
                "Say 'volere' (voh-LEH-reh) — to want. It's irregular but super important. Say: voglio, vuoi, vuole, vogliamo, volete, vogliono.",
                "Try: 'Voglio...' — 'I want...' What do you want right now? Say it in Italian: 'Voglio un caffè / andare in Italia / imparare l'italiano.'",
                "Fill in the blank: 'Do you want some water?' → '_______ dell'acqua?'",
                "Say 'Voglio imparare l'italiano!' — 'I want to learn Italian!' Say it with conviction — it's your goal!",
                "Challenge: use voglio, vuoi, and vuole in three separate sentences. Can you come up with real ones?",
                "Translate: 'We want to go to Rome.' → 'Vogliamo andare a Roma.' Say it and picture the Colosseum!",
                "Use volere today — say 'Voglio...' and name something you genuinely want. Declare it in Italian!"
            ],
            practiceListenPhrases: [
                "volere. Voglio, vuoi, vuole, vogliamo, volete, vogliono.",
                "Voglio un caffè.",
                "Vuoi dell'acqua?",
                "Voglio imparare l'italiano!",
                "Voglio studiare. Tu vuoi mangiare. Lei vuole dormire.",
                "Vogliamo andare a Roma.",
                nil
            ]
        ),

        ItalianVerb(
            verb: "potere",
            verbType: "verbo irregolare",
            meaning: "to be able to / can",
            conjugation: [
                WordForm(label: "io",           value: "posso"),
                WordForm(label: "tu",           value: "puoi"),
                WordForm(label: "lui / lei",    value: "può"),
                WordForm(label: "noi",          value: "possiamo"),
                WordForm(label: "voi",          value: "potete"),
                WordForm(label: "loro",         value: "possono"),
            ],
            example: "Posso farcela, so che posso.",
            exampleTranslation: "I can do it, I know I can.",
            practiceQuestions: [
                "Say 'potere' (poh-TEH-reh) — can / to be able to. Say all forms: posso, puoi, può, possiamo, potete, possono. The first one — 'posso' — is the most useful!",
                "Try: 'Posso aiutarti?' — 'Can I help you?' or 'Posso avere...?' — 'Can I have...?' Practice the question form!",
                "Fill in the blank: 'Can you come tomorrow?' → '_______ venire domani?'",
                "Say 'Posso farcela!' — 'I can do it!' Your Italian motivational phrase of the week. Say it with belief!",
                "Challenge: use posso, puoi, and può in three sentences. Think of real situations where you'd need each one.",
                "Translate: 'We can try.' → 'Possiamo provare.' Short, hopeful, real Italian. Say it!",
                "Use potere today — when you're about to do something, say 'Posso!' out loud. You can!"
            ],
            practiceListenPhrases: [
                "potere. Posso, puoi, può, possiamo, potete, possono.",
                "Posso aiutarti?",
                "Puoi venire domani?",
                "Posso farcela!",
                "Posso studiare. Puoi venire. Lei può aspettare.",
                "Possiamo provare.",
                nil
            ]
        ),

        ItalianVerb(
            verb: "sapere",
            verbType: "verbo irregolare",
            meaning: "to know (a fact / how to do something)",
            conjugation: [
                WordForm(label: "io",           value: "so"),
                WordForm(label: "tu",           value: "sai"),
                WordForm(label: "lui / lei",    value: "sa"),
                WordForm(label: "noi",          value: "sappiamo"),
                WordForm(label: "voi",          value: "sapete"),
                WordForm(label: "loro",         value: "sanno"),
            ],
            example: "Sai che l'italiano è la lingua della musica?",
            exampleTranslation: "Did you know that Italian is the language of music?",
            practiceQuestions: [
                "Say 'sapere' (sah-PEH-reh) — to know a fact or to know how to do something. Say the forms: so, sai, sa, sappiamo, sapete, sanno.",
                "Try: 'Lo so!' — 'I know!' and 'Non lo so.' — 'I don't know.' Two of the most used Italian phrases. Practice both!",
                "Fill in the blank: 'Do you know what time it is?' → '_______ che ore sono?'",
                "Say 'So parlare italiano un po'!' — 'I know how to speak a little Italian!' Say it proudly — it's true!",
                "Challenge: what's the difference between 'so' (I know) and 'conosco' (I know/am familiar with)? 'So cantare.' vs 'Conosco Roma.' Think about it!",
                "Translate: 'They know the answer.' → 'Sanno la risposta.' Say it!",
                "Use sapere today — say 'Lo so!' when something makes sense to you. Small victories in Italian count!"
            ],
            practiceListenPhrases: [
                "sapere. So, sai, sa, sappiamo, sapete, sanno.",
                "Lo so! Non lo so.",
                "Sai che ore sono?",
                "So parlare italiano un po'!",
                "So cantare. Conosco Roma.",
                "Sanno la risposta.",
                nil
            ]
        ),

        ItalianVerb(
            verb: "amare",
            verbType: "verbo regolare (-are)",
            meaning: "to love",
            conjugation: [
                WordForm(label: "io",           value: "amo"),
                WordForm(label: "tu",           value: "ami"),
                WordForm(label: "lui / lei",    value: "ama"),
                WordForm(label: "noi",          value: "amiamo"),
                WordForm(label: "voi",          value: "amate"),
                WordForm(label: "loro",         value: "amano"),
            ],
            example: "Amo l'italiano — la sua musicalità, la sua cultura, tutto.",
            exampleTranslation: "I love Italian — its musicality, its culture, everything.",
            practiceQuestions: [
                "Say 'amare' (ah-MAH-reh) — to love. The most romantic Italian verb! Say all forms: amo, ami, ama, amiamo, amate, amano.",
                "Try: 'Amo...' — what do you love? 'Amo la musica.' 'Amo il caffè.' 'Amo l'italiano.' Say it out loud!",
                "Fill in the blank: 'She loves her family very much.' → 'Ama molto la sua ________.'",
                "Say 'Ti amo.' — 'I love you.' The most powerful two-word phrase in Italian. Say it to someone or something you love.",
                "Challenge: use amare for three things you love. 'Amo...' three times, three different loves in Italian!",
                "Translate: 'We love this city.' → 'Amiamo questa città.' Say it like you're truly in love with a place.",
                "Use amare today — say 'Amo...' and name something you genuinely love. In Italian, love is always worth saying aloud!"
            ],
            practiceListenPhrases: [
                "amare. Amo, ami, ama, amiamo, amate, amano.",
                "Amo la musica. Amo il caffè.",
                "Ama molto la sua famiglia.",
                "Ti amo.",
                "Amo la musica. Amo il caffè. Amo l'italiano.",
                "Amiamo questa città.",
                nil
            ]
        ),
    ]
}
