import Foundation

struct FrenchVerb {
    let verb: String
    let verbType: String
    let meaning: String
    let conjugation: [WordForm]          // exactly 6: je, tu, il/elle, nous, vous, ils/elles
    let example: String
    let exampleTranslation: String
    let practiceQuestions: [String]      // exactly 7 (Sun–Sat)
    let practiceListenPhrases: [String?] // exactly 7
}

final class FrenchVerbService {
    static let shared = FrenchVerbService()
    private init() {}

    var currentVerb: FrenchVerb {
        let week = Calendar.current.component(.weekOfYear, from: Date())
        return verbs[week % verbs.count]
    }

    var allVerbs: [FrenchVerb] { verbs }

    func listenPhrase(for verb: FrenchVerb, practiceIndex: Int) -> String? {
        guard practiceIndex < verb.practiceListenPhrases.count else { return nil }
        return verb.practiceListenPhrases[practiceIndex]
    }

    func speak(text: String, slow: Bool = false) {
        FrenchWordService.shared.speak(text: text, slow: slow)
    }

    // MARK: – Verb list (rotates by ISO week number)

    private let verbs: [FrenchVerb] = [
        FrenchVerb(
            verb: "être",
            verbType: "verbe irrégulier",
            meaning: "to be",
            conjugation: [
                WordForm(label: "je",         value: "suis"),
                WordForm(label: "tu",         value: "es"),
                WordForm(label: "il / elle",  value: "est"),
                WordForm(label: "nous",       value: "sommes"),
                WordForm(label: "vous",       value: "êtes"),
                WordForm(label: "ils / elles", value: "sont"),
            ],
            example: "Je suis tellement contente d'être ici avec vous.",
            exampleTranslation: "I am so happy to be here with you.",
            practiceQuestions: [
                "Say 'être' (EH-truh) — to be. The most important verb in French. Press the speaker for each form and repeat: je suis, tu es, il est, nous sommes, vous êtes, ils sont. Say them all out loud!",
                "Try: 'Je suis...' — fill in your mood, location, or how you're feeling right now. Say the full sentence out loud!",
                "Fill in the blank: 'We are so happy.' → 'Nous _______ tellement heureux.' And: 'You (formal) are very kind.' → 'Vous _______ très gentil.'",
                "Use 'je suis' in a real sentence today. Describe something about yourself: where you are, how you feel, what you are. Say it out loud!",
                "Challenge: conjugate 'être' for all 6 persons from memory — je, tu, il, nous, vous, ils. No peeking! How many do you get?",
                "Translate: 'They are really good friends.' → 'Ils sont vraiment de bons amis.' Say it!",
                "Make up a sentence using 'être' and share it — or say it to yourself. Any tense, any subject, any mood!"
            ],
            practiceListenPhrases: [
                "être. Je suis, tu es, il est, nous sommes, vous êtes, ils sont.",
                "Je suis contente d'être ici.",
                "Nous sommes tellement heureux.",
                "Je suis vraiment bien aujourd'hui.",
                "Je suis, tu es, il est, nous sommes, vous êtes, ils sont.",
                "Ils sont vraiment de bons amis.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "avoir",
            verbType: "verbe irrégulier",
            meaning: "to have",
            conjugation: [
                WordForm(label: "je",         value: "ai"),
                WordForm(label: "tu",         value: "as"),
                WordForm(label: "il / elle",  value: "a"),
                WordForm(label: "nous",       value: "avons"),
                WordForm(label: "vous",       value: "avez"),
                WordForm(label: "ils / elles", value: "ont"),
            ],
            example: "Nous avons tellement de chance de vivre dans cette ville.",
            exampleTranslation: "We are so lucky to live in this city.",
            practiceQuestions: [
                "Say 'avoir' (ah-VWAHR) — to have. Essential for past tense too! Repeat each form: j'ai, tu as, il a, nous avons, vous avez, ils ont. Say them all!",
                "Try: 'J'ai...' and finish with something you have right now — a coffee, an idea, a feeling. Full sentence out loud!",
                "Fill in the blank: 'She has a beautiful voice.' → 'Elle _______ une belle voix.' And: 'Do you have a minute?' → 'Vous _______ une minute?'",
                "Use 'j'ai' in a real sentence today — 'J'ai faim' (I'm hungry), 'J'ai envie de...' (I feel like...), 'J'ai de la chance' (I'm lucky). Say it!",
                "Challenge: conjugate 'avoir' from memory for all 6 — j'ai, tu as, il a, nous avons, vous avez, ils ont. Say it fast then slow.",
                "Translate: 'We have so much to learn.' → 'Nous avons tellement à apprendre.' Say it with conviction.",
                "Make up a sentence using 'avoir' — about something you have, want, or feel. Say it out loud!"
            ],
            practiceListenPhrases: [
                "avoir. J'ai, tu as, il a, nous avons, vous avez, ils ont.",
                "J'ai tellement de chance.",
                "Elle a une belle voix.",
                "J'ai envie de faire quelque chose de beau aujourd'hui.",
                "J'ai, tu as, il a, nous avons, vous avez, ils ont.",
                "Nous avons tellement à apprendre.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "aller",
            verbType: "verbe irrégulier",
            meaning: "to go",
            conjugation: [
                WordForm(label: "je",         value: "vais"),
                WordForm(label: "tu",         value: "vas"),
                WordForm(label: "il / elle",  value: "va"),
                WordForm(label: "nous",       value: "allons"),
                WordForm(label: "vous",       value: "allez"),
                WordForm(label: "ils / elles", value: "vont"),
            ],
            example: "On va au marché ce matin — tu viens?",
            exampleTranslation: "We're going to the market this morning — are you coming?",
            practiceQuestions: [
                "Say 'aller' (ah-LAY) — to go. Repeat each form: je vais, tu vas, il va, nous allons, vous allez, ils vont. Say them all out loud!",
                "Try: 'Je vais...' and add where you're going or what you're about to do. 'Je vais au café' / 'Je vais travailler.' Say it!",
                "Fill in the blank: 'Where are you going?' → 'Où est-ce que tu _______?' And: 'We're going to Montréal!' → 'Nous _______ à Montréal!'",
                "Use 'je vais' today in a real context — tell yourself where you're going. 'Je vais à la cuisine.' Even small counts!",
                "Challenge: conjugate 'aller' from memory — je vais, tu vas, il va, nous allons, vous allez, ils vont. No peeking!",
                "Translate: 'They go for a walk every evening.' → 'Ils vont se promener chaque soir.' Say it!",
                "Make a sentence with 'aller' about a plan you have today or this week. Say it out loud!"
            ],
            practiceListenPhrases: [
                "aller. Je vais, tu vas, il va, nous allons, vous allez, ils vont.",
                "Je vais au marché ce matin.",
                "Nous allons à Montréal!",
                "Je vais me promener tout à l'heure.",
                "Je vais, tu vas, il va, nous allons, vous allez, ils vont.",
                "Ils vont se promener chaque soir.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "faire",
            verbType: "verbe irrégulier",
            meaning: "to do / to make",
            conjugation: [
                WordForm(label: "je",         value: "fais"),
                WordForm(label: "tu",         value: "fais"),
                WordForm(label: "il / elle",  value: "fait"),
                WordForm(label: "nous",       value: "faisons"),
                WordForm(label: "vous",       value: "faites"),
                WordForm(label: "ils / elles", value: "font"),
            ],
            example: "Elle fait du yoga tous les matins avant de commencer sa journée.",
            exampleTranslation: "She does yoga every morning before starting her day.",
            practiceQuestions: [
                "Say 'faire' (FAIR) — to do or make. Very irregular! Repeat: je fais, tu fais, il fait, nous faisons, vous faites, ils font. Say them all!",
                "Try: 'Je fais...' — what are you doing today? 'Je fais du café' / 'Je fais mon lit.' Add something real and say it!",
                "Fill in the blank: 'What are you doing?' → 'Qu'est-ce que tu _______?' And: 'We're making dinner.' → 'Nous _______ le dîner.'",
                "Use 'je fais' in a real sentence today — about something you're actually doing. Say it naturally.",
                "Challenge: conjugate 'faire' — je fais, tu fais, il fait, nous faisons, vous faites, ils font. Note the irregular 'faites'!",
                "Translate: 'He makes the best crêpes.' → 'Il fait les meilleures crêpes.' Say it like you've tasted them.",
                "Use 'faire' in a sentence about something you love doing — or something you need to do today. Say it out loud!"
            ],
            practiceListenPhrases: [
                "faire. Je fais, tu fais, il fait, nous faisons, vous faites, ils font.",
                "Je fais du café.",
                "Nous faisons le dîner.",
                "Je fais quelque chose de bien aujourd'hui.",
                "Je fais, tu fais, il fait, nous faisons, vous faites, ils font.",
                "Il fait les meilleures crêpes.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "venir",
            verbType: "verbe irrégulier",
            meaning: "to come",
            conjugation: [
                WordForm(label: "je",         value: "viens"),
                WordForm(label: "tu",         value: "viens"),
                WordForm(label: "il / elle",  value: "vient"),
                WordForm(label: "nous",       value: "venons"),
                WordForm(label: "vous",       value: "venez"),
                WordForm(label: "ils / elles", value: "viennent"),
            ],
            example: "Il vient dîner chez nous ce soir — j'ai hâte!",
            exampleTranslation: "He's coming for dinner at our place tonight — I can't wait!",
            practiceQuestions: [
                "Say 'venir' (ve-NEER) — to come. Repeat: je viens, tu viens, il vient, nous venons, vous venez, ils viennent. Say them all!",
                "Try: 'Je viens de...' — 'I just...' or 'I come from...' 'Je viens de Montréal' / 'Je viens de finir.' Say it!",
                "Fill in the blank: 'Are you coming?' → 'Est-ce que tu _______?' And: 'They're coming tomorrow.' → 'Ils _______ demain.'",
                "Use 'je viens' today — 'Je viens!' (I'm coming!) or 'Je viens de...' (I just...). Drop it into a real moment.",
                "Challenge: conjugate 'venir' — je viens, tu viens, il vient, nous venons, vous venez, ils viennent. The 'viennent' is tricky!",
                "Translate: 'She comes from Québec and speaks beautiful French.' → 'Elle vient du Québec et parle un français magnifique.'",
                "Use 'venir' in a sentence — where do you come from? What did you just do? Say it out loud!"
            ],
            practiceListenPhrases: [
                "venir. Je viens, tu viens, il vient, nous venons, vous venez, ils viennent.",
                "Je viens de Montréal.",
                "Ils viennent demain.",
                "Je viens!",
                "Je viens, tu viens, il vient, nous venons, vous venez, ils viennent.",
                "Elle vient du Québec et parle un français magnifique.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "pouvoir",
            verbType: "verbe irrégulier",
            meaning: "to be able to / can",
            conjugation: [
                WordForm(label: "je",         value: "peux"),
                WordForm(label: "tu",         value: "peux"),
                WordForm(label: "il / elle",  value: "peut"),
                WordForm(label: "nous",       value: "pouvons"),
                WordForm(label: "vous",       value: "pouvez"),
                WordForm(label: "ils / elles", value: "peuvent"),
            ],
            example: "Tu peux m'appeler quand tu veux — je suis toujours disponible.",
            exampleTranslation: "You can call me whenever you want — I'm always available.",
            practiceQuestions: [
                "Say 'pouvoir' (poo-VWAHR) — can, to be able to. Repeat: je peux, tu peux, il peut, nous pouvons, vous pouvez, ils peuvent.",
                "Try: 'Je peux...' and add something you're able to do. 'Je peux le faire!' / 'Je peux t'aider?' Say it!",
                "Fill in the blank: 'Can you help me?' → 'Est-ce que tu _______ m'aider?' And: 'We can do this!' → 'Nous _______ le faire!'",
                "Use 'je peux' today — offer help to someone: 'Je peux t'aider?' or affirm something: 'Je peux le faire!' Say it with confidence.",
                "Challenge: conjugate 'pouvoir' — je peux, tu peux, il peut, nous pouvons, vous pouvez, ils peuvent. Say it twice through!",
                "Translate: 'She can speak three languages.' → 'Elle peut parler trois langues.' Say it impressively.",
                "Make a sentence with 'pouvoir' about something you can do or offer to do for someone. Say it out loud!"
            ],
            practiceListenPhrases: [
                "pouvoir. Je peux, tu peux, il peut, nous pouvons, vous pouvez, ils peuvent.",
                "Je peux le faire!",
                "Nous pouvons le faire!",
                "Je peux t'aider?",
                "Je peux, tu peux, il peut, nous pouvons, vous pouvez, ils peuvent.",
                "Elle peut parler trois langues.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "vouloir",
            verbType: "verbe irrégulier",
            meaning: "to want",
            conjugation: [
                WordForm(label: "je",         value: "veux"),
                WordForm(label: "tu",         value: "veux"),
                WordForm(label: "il / elle",  value: "veut"),
                WordForm(label: "nous",       value: "voulons"),
                WordForm(label: "vous",       value: "voulez"),
                WordForm(label: "ils / elles", value: "veulent"),
            ],
            example: "Je veux apprendre à cuisiner la ratatouille cet été.",
            exampleTranslation: "I want to learn how to cook ratatouille this summer.",
            practiceQuestions: [
                "Say 'vouloir' (voo-LWAHR) — to want. Repeat: je veux, tu veux, il veut, nous voulons, vous voulez, ils veulent. Say them all!",
                "Try: 'Je veux...' — what do you want right now? A coffee? A vacation? To speak French? Say it out loud!",
                "Fill in the blank: 'Do you want some?' → 'Est-ce que tu _______ en avoir?' And: 'They want to travel.' → 'Ils _______ voyager.'",
                "Use 'je veux' today to express something you genuinely want. Say it to yourself or out loud — in French!",
                "Challenge: conjugate 'vouloir' — je veux, tu veux, il veut, nous voulons, vous voulez, ils veulent. Note the irregular 'veulent'!",
                "Translate: 'He wants to learn French and it shows.' → 'Il veut apprendre le français et ca se voit.' Say it!",
                "Make a sentence with 'vouloir' about something you truly want to do or learn. Say it with real intention!"
            ],
            practiceListenPhrases: [
                "vouloir. Je veux, tu veux, il veut, nous voulons, vous voulez, ils veulent.",
                "Je veux apprendre le français!",
                "Ils veulent voyager.",
                "Je veux quelque chose de beau aujourd'hui.",
                "Je veux, tu veux, il veut, nous voulons, vous voulez, ils veulent.",
                "Il veut apprendre le français et ca se voit.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "savoir",
            verbType: "verbe irrégulier",
            meaning: "to know (a fact / how to do something)",
            conjugation: [
                WordForm(label: "je",         value: "sais"),
                WordForm(label: "tu",         value: "sais"),
                WordForm(label: "il / elle",  value: "sait"),
                WordForm(label: "nous",       value: "savons"),
                WordForm(label: "vous",       value: "savez"),
                WordForm(label: "ils / elles", value: "savent"),
            ],
            example: "Tu sais jouer du piano? C'est tellement impressionnant!",
            exampleTranslation: "You know how to play piano? That's so impressive!",
            practiceQuestions: [
                "Say 'savoir' (sah-VWAHR) — to know a fact or know how to do something. Repeat: je sais, tu sais, il sait, nous savons, vous savez, ils savent.",
                "Try: 'Je sais...' or 'Je ne sais pas.' — 'I know' or 'I don't know.' Use it in a real thought right now. Say it!",
                "Fill in the blank: 'I know how to cook.' → 'Je _______ cuisiner.' And: 'Do you know the answer?' → 'Est-ce que tu _______ la réponse?'",
                "Use 'je sais' today — 'Je sais!' when you figure something out, or 'Je ne sais pas...' when you're unsure. Real usage!",
                "Challenge: conjugate 'savoir' — je sais, tu sais, il sait, nous savons, vous savez, ils savent. Say it twice through!",
                "Translate: 'She knows exactly what she wants.' → 'Elle sait exactement ce qu'elle veut.' Say it with confidence.",
                "Make a sentence with 'savoir' about something you know how to do. Say it proudly out loud!"
            ],
            practiceListenPhrases: [
                "savoir. Je sais, tu sais, il sait, nous savons, vous savez, ils savent.",
                "Je sais!",
                "Je sais cuisiner.",
                "Je sais, et j'en suis fière.",
                "Je sais, tu sais, il sait, nous savons, vous savez, ils savent.",
                "Elle sait exactement ce qu'elle veut.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "voir",
            verbType: "verbe irrégulier",
            meaning: "to see",
            conjugation: [
                WordForm(label: "je",         value: "vois"),
                WordForm(label: "tu",         value: "vois"),
                WordForm(label: "il / elle",  value: "voit"),
                WordForm(label: "nous",       value: "voyons"),
                WordForm(label: "vous",       value: "voyez"),
                WordForm(label: "ils / elles", value: "voient"),
            ],
            example: "On voit les étoiles tellement bien ici — c'est magnifique!",
            exampleTranslation: "You can see the stars so clearly here — it's magnificent!",
            practiceQuestions: [
                "Say 'voir' (VWAHR) — to see. Repeat: je vois, tu vois, il voit, nous voyons, vous voyez, ils voient. Say them all out loud!",
                "Try: 'Je vois...' — what do you see right now? Describe it in French using 'je vois.' Even one word is a win.",
                "Fill in the blank: 'I see what you mean.' → 'Je _______ ce que tu veux dire.' And: 'We'll see!' → 'On _______!'",
                "Use 'je vois' today — 'Je vois!' to mean 'I see/I get it!' or literally describe what you're looking at. Natural usage!",
                "Challenge: conjugate 'voir' — je vois, tu vois, il voit, nous voyons, vous voyez, ils voient. Note 'voyons' and 'voient'!",
                "Translate: 'She sees the beauty in everything.' → 'Elle voit la beauté partout.' Say it — what a sentence.",
                "Use 'voir' in a sentence about something you see or want to see. Say it out loud!"
            ],
            practiceListenPhrases: [
                "voir. Je vois, tu vois, il voit, nous voyons, vous voyez, ils voient.",
                "Je vois ce que tu veux dire.",
                "On verra!",
                "Je vois quelque chose de beau ici.",
                "Je vois, tu vois, il voit, nous voyons, vous voyez, ils voient.",
                "Elle voit la beauté partout.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "prendre",
            verbType: "verbe irrégulier",
            meaning: "to take",
            conjugation: [
                WordForm(label: "je",         value: "prends"),
                WordForm(label: "tu",         value: "prends"),
                WordForm(label: "il / elle",  value: "prend"),
                WordForm(label: "nous",       value: "prenons"),
                WordForm(label: "vous",       value: "prenez"),
                WordForm(label: "ils / elles", value: "prennent"),
            ],
            example: "Je prends toujours un café le matin — c'est mon rituel.",
            exampleTranslation: "I always have a coffee in the morning — it's my ritual.",
            practiceQuestions: [
                "Say 'prendre' (PRAHN-druh) — to take. Repeat: je prends, tu prends, il prend, nous prenons, vous prenez, ils prennent. Say them all!",
                "Try: 'Je prends...' — 'Je prends le temps.' / 'Je prends un café.' Add something you're taking or doing. Say it!",
                "Fill in the blank: 'Take your time!' → 'Prends ton _______!' And: 'They take the bus every day.' → 'Ils _______ le bus chaque jour.'",
                "Use 'je prends' today — 'Je prends le temps.' or 'Je prends soin de moi.' Small or big. Say it!",
                "Challenge: conjugate 'prendre' — je prends, tu prends, il prend, nous prenons, vous prenez, ils prennent. Note 'prennent'!",
                "Translate: 'She takes her time with everything she does.' → 'Elle prend son temps pour tout ce qu'elle fait.'",
                "Make a sentence with 'prendre' — about taking something, taking time, or taking the bus. Say it!"
            ],
            practiceListenPhrases: [
                "prendre. Je prends, tu prends, il prend, nous prenons, vous prenez, ils prennent.",
                "Je prends un café le matin.",
                "Ils prennent le bus chaque jour.",
                "Je prends le temps aujourd'hui.",
                "Je prends, tu prends, il prend, nous prenons, vous prenez, ils prennent.",
                "Elle prend son temps pour tout ce qu'elle fait.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "partir",
            verbType: "verbe irrégulier",
            meaning: "to leave / to go away",
            conjugation: [
                WordForm(label: "je",         value: "pars"),
                WordForm(label: "tu",         value: "pars"),
                WordForm(label: "il / elle",  value: "part"),
                WordForm(label: "nous",       value: "partons"),
                WordForm(label: "vous",       value: "partez"),
                WordForm(label: "ils / elles", value: "partent"),
            ],
            example: "Le train part dans dix minutes — dépêche-toi!",
            exampleTranslation: "The train leaves in ten minutes — hurry up!",
            practiceQuestions: [
                "Say 'partir' (par-TEER) — to leave, to go away. Repeat: je pars, tu pars, il part, nous partons, vous partez, ils partent. Say them!",
                "Try: 'Je pars...' — where are you leaving to? 'Je pars en voyage!' / 'Je pars dans une heure.' Say it out loud!",
                "Fill in the blank: 'When are you leaving?' → 'Quand est-ce que tu _______?' And: 'We're leaving tomorrow!' → 'Nous _______ demain!'",
                "Use 'je pars' today — even if you're just stepping out: 'Je pars au marché.' or planning a trip. Say it with excitement!",
                "Challenge: conjugate 'partir' — je pars, tu pars, il part, nous partons, vous partez, ils partent. Twice through!",
                "Translate: 'She's leaving for Paris next week.' → 'Elle part pour Paris la semaine prochaine.' Say it dreamily.",
                "Use 'partir' in a sentence about a trip you want to take or a departure today. Say it out loud!"
            ],
            practiceListenPhrases: [
                "partir. Je pars, tu pars, il part, nous partons, vous partez, ils partent.",
                "Je pars en voyage!",
                "Nous partons demain!",
                "Je pars dans un moment.",
                "Je pars, tu pars, il part, nous partons, vous partez, ils partent.",
                "Elle part pour Paris la semaine prochaine.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "mettre",
            verbType: "verbe irrégulier",
            meaning: "to put / to place / to wear",
            conjugation: [
                WordForm(label: "je",         value: "mets"),
                WordForm(label: "tu",         value: "mets"),
                WordForm(label: "il / elle",  value: "met"),
                WordForm(label: "nous",       value: "mettons"),
                WordForm(label: "vous",       value: "mettez"),
                WordForm(label: "ils / elles", value: "mettent"),
            ],
            example: "Elle met toujours de la musique quand elle cuisine — ca change tout.",
            exampleTranslation: "She always puts on music when she cooks — it changes everything.",
            practiceQuestions: [
                "Say 'mettre' (MEH-truh) — to put, place, or wear. Repeat: je mets, tu mets, il met, nous mettons, vous mettez, ils mettent. Say them!",
                "Try: 'Je mets...' — 'Je mets de la musique.' / 'Je mets mon manteau.' What are you putting or wearing? Say it!",
                "Fill in the blank: 'Put it here.' → 'Mets-le _______.' And: 'We put everything on the table.' → 'Nous _______ tout sur la table.'",
                "Use 'je mets' today — put on a song, put something away, wear something. Say it in French as you do it!",
                "Challenge: conjugate 'mettre' — je mets, tu mets, il met, nous mettons, vous mettez, ils mettent. Note the double 'tt' in plural!",
                "Translate: 'He puts his heart into everything he does.' → 'Il met tout son coeur dans ce qu'il fait.' Beautiful sentence.",
                "Make a sentence with 'mettre' — about music, clothes, or placing something. Say it out loud!"
            ],
            practiceListenPhrases: [
                "mettre. Je mets, tu mets, il met, nous mettons, vous mettez, ils mettent.",
                "Je mets de la musique.",
                "Nous mettons tout sur la table.",
                "Je mets du soin dans ce que je fais.",
                "Je mets, tu mets, il met, nous mettons, vous mettez, ils mettent.",
                "Il met tout son coeur dans ce qu'il fait.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "dire",
            verbType: "verbe irrégulier",
            meaning: "to say / to tell",
            conjugation: [
                WordForm(label: "je",         value: "dis"),
                WordForm(label: "tu",         value: "dis"),
                WordForm(label: "il / elle",  value: "dit"),
                WordForm(label: "nous",       value: "disons"),
                WordForm(label: "vous",       value: "dites"),
                WordForm(label: "ils / elles", value: "disent"),
            ],
            example: "Je dis toujours ce que je pense — avec bienveillance, bien sûr.",
            exampleTranslation: "I always say what I think — with kindness, of course.",
            practiceQuestions: [
                "Say 'dire' (DEER) — to say or tell. Repeat: je dis, tu dis, il dit, nous disons, vous dites, ils disent. Note the irregular 'dites'!",
                "Try: 'Je dis que...' — 'Je dis que tu es super!' or 'Je dis merci.' Say something kind in French right now.",
                "Fill in the blank: 'What did you say?' → 'Qu'est-ce que tu _______?' And: 'They say it's going to rain.' → 'Ils _______ qu'il va pleuvoir.'",
                "Use 'je dis' today — say something positive to yourself or someone: 'Je te dis que tu y arrives!' Try it!",
                "Challenge: conjugate 'dire' — je dis, tu dis, il dit, nous disons, vous dites, ils disent. 'Dites' is unique — remember it!",
                "Translate: 'She always says exactly the right thing.' → 'Elle dit toujours exactement ce qu'il faut.' Say it.",
                "Make a sentence with 'dire' — something you want to say, or something people say. Say it out loud!"
            ],
            practiceListenPhrases: [
                "dire. Je dis, tu dis, il dit, nous disons, vous dites, ils disent.",
                "Je dis que tu es super!",
                "Ils disent qu'il va pleuvoir.",
                "Je dis merci, sincèrement.",
                "Je dis, tu dis, il dit, nous disons, vous dites, ils disent.",
                "Elle dit toujours exactement ce qu'il faut.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "lire",
            verbType: "verbe irrégulier",
            meaning: "to read",
            conjugation: [
                WordForm(label: "je",         value: "lis"),
                WordForm(label: "tu",         value: "lis"),
                WordForm(label: "il / elle",  value: "lit"),
                WordForm(label: "nous",       value: "lisons"),
                WordForm(label: "vous",       value: "lisez"),
                WordForm(label: "ils / elles", value: "lisent"),
            ],
            example: "Il lit un roman chaque semaine — il adore se perdre dans les histoires.",
            exampleTranslation: "He reads a novel every week — he loves losing himself in stories.",
            practiceQuestions: [
                "Say 'lire' (LEER) — to read. Repeat: je lis, tu lis, il lit, nous lisons, vous lisez, ils lisent. Say them all out loud!",
                "Try: 'Je lis...' — what are you reading right now? A novel, articles, subtitles? Say it in French!",
                "Fill in the blank: 'Do you like reading?' → 'Est-ce que tu aimes _______?' And: 'We read every day.' → 'Nous _______ chaque jour.'",
                "Use 'je lis' today — even if you're just reading a recipe or a sign. 'Je lis' works everywhere. Say it!",
                "Challenge: conjugate 'lire' — je lis, tu lis, il lit, nous lisons, vous lisez, ils lisent. Twice through!",
                "Translate: 'She reads French beautifully — she's been learning for a year.' → 'Elle lit le français très bien — ca fait un an qu'elle apprend.'",
                "Make a sentence with 'lire' — about what you like to read or what you're currently reading. Say it!"
            ],
            practiceListenPhrases: [
                "lire. Je lis, tu lis, il lit, nous lisons, vous lisez, ils lisent.",
                "Je lis un roman en ce moment.",
                "Nous lisons chaque jour.",
                "Je lis en français maintenant!",
                "Je lis, tu lis, il lit, nous lisons, vous lisez, ils lisent.",
                "Elle lit le français très bien.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "écrire",
            verbType: "verbe irrégulier",
            meaning: "to write",
            conjugation: [
                WordForm(label: "je",         value: "écris"),
                WordForm(label: "tu",         value: "écris"),
                WordForm(label: "il / elle",  value: "écrit"),
                WordForm(label: "nous",       value: "écrivons"),
                WordForm(label: "vous",       value: "écrivez"),
                WordForm(label: "ils / elles", value: "écrivent"),
            ],
            example: "J'écris dans mon journal tous les soirs — ca m'aide à me recentrer.",
            exampleTranslation: "I write in my journal every evening — it helps me recenter.",
            practiceQuestions: [
                "Say 'écrire' (ay-KREER) — to write. Repeat: j'écris, tu écris, il écrit, nous écrivons, vous écrivez, ils écrivent. Say them all!",
                "Try: 'J'écris...' — what do you write? A journal, texts, emails? 'J'écris un message.' Say it out loud!",
                "Fill in the blank: 'She writes very well.' → 'Elle _______ très bien.' And: 'We write every day.' → 'Nous _______ chaque jour.'",
                "Use 'j'écris' today — even writing a note or a text counts! Say 'J'écris' as you do it. Make French part of the action.",
                "Challenge: conjugate 'écrire' — j'écris, tu écris, il écrit, nous écrivons, vous écrivez, ils écrivent. Say it twice!",
                "Translate: 'He writes with so much passion.' → 'Il écrit avec tellement de passion.' Say it with feeling.",
                "Use 'écrire' in a sentence about something you write or want to write. Say it out loud!"
            ],
            practiceListenPhrases: [
                "écrire. J'écris, tu écris, il écrit, nous écrivons, vous écrivez, ils écrivent.",
                "J'écris dans mon journal.",
                "Elle écrit très bien.",
                "J'écris quelque chose pour moi aujourd'hui.",
                "J'écris, tu écris, il écrit, nous écrivons, vous écrivez, ils écrivent.",
                "Il écrit avec tellement de passion.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "parler",
            verbType: "1er groupe (-er)",
            meaning: "to speak / to talk",
            conjugation: [
                WordForm(label: "je",         value: "parle"),
                WordForm(label: "tu",         value: "parles"),
                WordForm(label: "il / elle",  value: "parle"),
                WordForm(label: "nous",       value: "parlons"),
                WordForm(label: "vous",       value: "parlez"),
                WordForm(label: "ils / elles", value: "parlent"),
            ],
            example: "Tu parles déjà mieux qu'hier — le français s'apprend!",
            exampleTranslation: "You already speak better than yesterday — French can be learned!",
            practiceQuestions: [
                "Say 'parler' (par-LAY) — to speak. The classic -er verb! Repeat: je parle, tu parles, il parle, nous parlons, vous parlez, ils parlent.",
                "Try: 'Je parle français!' — say it and believe it. Even a little counts. Say it with confidence!",
                "Fill in the blank: 'She speaks very slowly.' → 'Elle _______ très lentement.' And: 'We speak French together.' → 'Nous _______ français ensemble.'",
                "Use 'je parle' today — 'Je parle français!' or 'Je parle avec quelqu'un.' Drop it into a real moment.",
                "Challenge: conjugate 'parler' — je parle, tu parles, il parle, nous parlons, vous parlez, ils parlent. This is the template for all -er verbs!",
                "Translate: 'They all speak French at home.' → 'Ils parlent tous français à la maison.' Say it!",
                "Make a sentence with 'parler' — about a language you speak or one you want to speak. Say it proudly!"
            ],
            practiceListenPhrases: [
                "parler. Je parle, tu parles, il parle, nous parlons, vous parlez, ils parlent.",
                "Je parle français!",
                "Nous parlons français ensemble.",
                "Je parle avec quelqu'un de bien aujourd'hui.",
                "Je parle, tu parles, il parle, nous parlons, vous parlez, ils parlent.",
                "Ils parlent tous français à la maison.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "aimer",
            verbType: "1er groupe (-er)",
            meaning: "to love / to like",
            conjugation: [
                WordForm(label: "je",         value: "aime"),
                WordForm(label: "tu",         value: "aimes"),
                WordForm(label: "il / elle",  value: "aime"),
                WordForm(label: "nous",       value: "aimons"),
                WordForm(label: "vous",       value: "aimez"),
                WordForm(label: "ils / elles", value: "aiment"),
            ],
            example: "J'aime vraiment apprendre des choses nouvelles chaque jour.",
            exampleTranslation: "I really love learning new things every day.",
            practiceQuestions: [
                "Say 'aimer' (ay-MAY) — to love or like. Repeat: j'aime, tu aimes, il aime, nous aimons, vous aimez, ils aiment. Say them all!",
                "Try: 'J'aime...' — finish with something you genuinely love. A food, a place, an activity. Say it with feeling!",
                "Fill in the blank: 'Do you like music?' → 'Est-ce que tu _______ la musique?' And: 'We love each other.' → 'Nous nous _______.'",
                "Use 'j'aime' today — say something you love in French. 'J'aime le français!' counts. Say it right now.",
                "Challenge: conjugate 'aimer' — j'aime, tu aimes, il aime, nous aimons, vous aimez, ils aiment. The classic -er verb ending!",
                "Translate: 'She loves cooking for the people she cares about.' → 'Elle aime cuisiner pour les gens qu'elle aime.' Say it!",
                "Use 'aimer' to express something you truly love — food, music, a person, an activity. Say it in French!"
            ],
            practiceListenPhrases: [
                "aimer. J'aime, tu aimes, il aime, nous aimons, vous aimez, ils aiment.",
                "J'aime apprendre le français!",
                "Nous nous aimons.",
                "J'aime tellement ce moment.",
                "J'aime, tu aimes, il aime, nous aimons, vous aimez, ils aiment.",
                "Elle aime cuisiner pour les gens qu'elle aime.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "trouver",
            verbType: "1er groupe (-er)",
            meaning: "to find / to think (opinion)",
            conjugation: [
                WordForm(label: "je",         value: "trouve"),
                WordForm(label: "tu",         value: "trouves"),
                WordForm(label: "il / elle",  value: "trouve"),
                WordForm(label: "nous",       value: "trouvons"),
                WordForm(label: "vous",       value: "trouvez"),
                WordForm(label: "ils / elles", value: "trouvent"),
            ],
            example: "Je trouve que le français devient de plus en plus naturel pour moi.",
            exampleTranslation: "I find that French is becoming more and more natural for me.",
            practiceQuestions: [
                "Say 'trouver' (troo-VAY) — to find or to think (opinion). Repeat: je trouve, tu trouves, il trouve, nous trouvons, vous trouvez, ils trouvent.",
                "Try: 'Je trouve que...' — give an opinion! 'Je trouve que c'est magnifique.' What do you think about something? Say it!",
                "Fill in the blank: 'I think it's beautiful.' → 'Je _______ que c'est beau.' And: 'Have you found your keys?' → 'Tu as _______ tes clés?'",
                "Use 'je trouve' today to express an opinion in French. 'Je trouve que c'est une belle journée.' One sentence, out loud!",
                "Challenge: conjugate 'trouver' — je trouve, tu trouves, il trouve, nous trouvons, vous trouvez, ils trouvent. Twice through!",
                "Translate: 'She finds beauty everywhere she goes.' → 'Elle trouve de la beauté partout où elle va.' Say it beautifully.",
                "Make a sentence with 'trouver' — give an opinion about something or say what you found. Say it out loud!"
            ],
            practiceListenPhrases: [
                "trouver. Je trouve, tu trouves, il trouve, nous trouvons, vous trouvez, ils trouvent.",
                "Je trouve que c'est magnifique.",
                "Je trouve que c'est beau.",
                "Je trouve ca vraiment bien.",
                "Je trouve, tu trouves, il trouve, nous trouvons, vous trouvez, ils trouvent.",
                "Elle trouve de la beauté partout où elle va.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "donner",
            verbType: "1er groupe (-er)",
            meaning: "to give",
            conjugation: [
                WordForm(label: "je",         value: "donne"),
                WordForm(label: "tu",         value: "donnes"),
                WordForm(label: "il / elle",  value: "donne"),
                WordForm(label: "nous",       value: "donnons"),
                WordForm(label: "vous",       value: "donnez"),
                WordForm(label: "ils / elles", value: "donnent"),
            ],
            example: "Il donne toujours le meilleur de lui-même — c'est admirable.",
            exampleTranslation: "He always gives his very best — it's admirable.",
            practiceQuestions: [
                "Say 'donner' (do-NAY) — to give. Repeat: je donne, tu donnes, il donne, nous donnons, vous donnez, ils donnent. Say them all!",
                "Try: 'Je donne...' — give something today! A compliment, a hand, your attention. Say 'Je donne...' before you do it!",
                "Fill in the blank: 'I'll give you a call.' → 'Je te _______ un coup de téléphone.' And: 'They give to charity.' → 'Ils _______ aux oeuvres.'",
                "Use 'je donne' today — give a compliment: 'Je te donne un compliment!' and mean it. Say it in French!",
                "Challenge: conjugate 'donner' — je donne, tu donnes, il donne, nous donnons, vous donnez, ils donnent. Classic -er ending!",
                "Translate: 'She gives so much of herself to others.' → 'Elle se donne tellement aux autres.' What a thing to say.",
                "Use 'donner' in a sentence — give something real or figurative. Say it out loud and mean it!"
            ],
            practiceListenPhrases: [
                "donner. Je donne, tu donnes, il donne, nous donnons, vous donnez, ils donnent.",
                "Je te donne un compliment!",
                "Ils donnent aux oeuvres.",
                "Je donne le meilleur de moi-même aujourd'hui.",
                "Je donne, tu donnes, il donne, nous donnons, vous donnez, ils donnent.",
                "Elle se donne tellement aux autres.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "penser",
            verbType: "1er groupe (-er)",
            meaning: "to think",
            conjugation: [
                WordForm(label: "je",         value: "pense"),
                WordForm(label: "tu",         value: "penses"),
                WordForm(label: "il / elle",  value: "pense"),
                WordForm(label: "nous",       value: "pensons"),
                WordForm(label: "vous",       value: "pensez"),
                WordForm(label: "ils / elles", value: "pensent"),
            ],
            example: "Je pense à toi tout le temps — tu me manques.",
            exampleTranslation: "I think about you all the time — I miss you.",
            practiceQuestions: [
                "Say 'penser' (pahn-SAY) — to think. Repeat: je pense, tu penses, il pense, nous pensons, vous pensez, ils pensent. Say them all!",
                "Try: 'Je pense à...' — think of someone or something. 'Je pense à toi.' or 'Je pense à mon avenir.' Say it with feeling!",
                "Fill in the blank: 'What do you think?' → 'Qu'est-ce que tu _______?' And: 'We think it's a great idea.' → 'Nous _______ que c'est une super idée.'",
                "Use 'je pense' today — say something you're thinking about in French. One real thought. Say it out loud!",
                "Challenge: conjugate 'penser' — je pense, tu penses, il pense, nous pensons, vous pensez, ils pensent. Say it twice!",
                "Translate: 'She thinks about others before herself.' → 'Elle pense aux autres avant de penser à elle.' Say it.",
                "Use 'penser' in a sentence about something or someone you're thinking about. Say it out loud!"
            ],
            practiceListenPhrases: [
                "penser. Je pense, tu penses, il pense, nous pensons, vous pensez, ils pensent.",
                "Je pense à toi.",
                "Nous pensons que c'est une super idée.",
                "Je pense à quelque chose de beau aujourd'hui.",
                "Je pense, tu penses, il pense, nous pensons, vous pensez, ils pensent.",
                "Elle pense aux autres avant de penser à elle.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "regarder",
            verbType: "1er groupe (-er)",
            meaning: "to watch / to look at",
            conjugation: [
                WordForm(label: "je",         value: "regarde"),
                WordForm(label: "tu",         value: "regardes"),
                WordForm(label: "il / elle",  value: "regarde"),
                WordForm(label: "nous",       value: "regardons"),
                WordForm(label: "vous",       value: "regardez"),
                WordForm(label: "ils / elles", value: "regardent"),
            ],
            example: "On regarde un film ce soir? J'ai envie de se détendre.",
            exampleTranslation: "Shall we watch a movie tonight? I feel like relaxing.",
            practiceQuestions: [
                "Say 'regarder' (re-gar-DAY) — to watch or look at. Repeat: je regarde, tu regardes, il regarde, nous regardons, vous regardez, ils regardent.",
                "Try: 'Je regarde...' — what are you looking at right now? 'Je regarde par la fenêtre.' or 'Je regarde une série.' Say it!",
                "Fill in the blank: 'Look at the sunset!' → '_______ le coucher de soleil!' And: 'We're watching a movie.' → 'Nous _______ un film.'",
                "Use 'je regarde' today — notice something beautiful and say 'Je regarde...' in French. Make it poetic!",
                "Challenge: conjugate 'regarder' — je regarde, tu regardes, il regarde, nous regardons, vous regardez, ils regardent.",
                "Translate: 'She looks at the world with wonder.' → 'Elle regarde le monde avec émerveillement.' Beautiful, right?",
                "Use 'regarder' in a sentence about something you love to watch or look at. Say it out loud!"
            ],
            practiceListenPhrases: [
                "regarder. Je regarde, tu regardes, il regarde, nous regardons, vous regardez, ils regardent.",
                "Je regarde par la fenêtre.",
                "Nous regardons un film.",
                "Je regarde quelque chose de beau.",
                "Je regarde, tu regardes, il regarde, nous regardons, vous regardez, ils regardent.",
                "Elle regarde le monde avec émerveillement.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "écouter",
            verbType: "1er groupe (-er)",
            meaning: "to listen (to)",
            conjugation: [
                WordForm(label: "je",         value: "écoute"),
                WordForm(label: "tu",         value: "écoutes"),
                WordForm(label: "il / elle",  value: "écoute"),
                WordForm(label: "nous",       value: "écoutons"),
                WordForm(label: "vous",       value: "écoutez"),
                WordForm(label: "ils / elles", value: "écoutent"),
            ],
            example: "Elle écoute de la musique en faisant la vaisselle — ca la met de bonne humeur.",
            exampleTranslation: "She listens to music while doing the dishes — it puts her in a good mood.",
            practiceQuestions: [
                "Say 'écouter' (ay-koo-TAY) — to listen. Repeat: j'écoute, tu écoutes, il écoute, nous écoutons, vous écoutez, ils écoutent. Say them!",
                "Try: 'J'écoute...' — what are you listening to right now? Music? A podcast? The rain? Say it in French!",
                "Fill in the blank: 'Listen to this song!' → '_______ cette chanson!' And: 'We listen to podcasts.' → 'Nous _______ des podcasts.'",
                "Use 'j'écoute' today — put something on and say 'J'écoute...' before pressing play. French in action!",
                "Challenge: conjugate 'écouter' — j'écoute, tu écoutes, il écoute, nous écoutons, vous écoutez, ils écoutent. Twice through!",
                "Translate: 'He listens more than he speaks — and that's a gift.' → 'Il écoute plus qu'il ne parle — et c'est un don.'",
                "Use 'écouter' in a sentence about something you love listening to. Say it out loud!"
            ],
            practiceListenPhrases: [
                "écouter. J'écoute, tu écoutes, il écoute, nous écoutons, vous écoutez, ils écoutent.",
                "J'écoute de la musique en ce moment.",
                "Nous écoutons des podcasts.",
                "J'écoute quelque chose de beau aujourd'hui.",
                "J'écoute, tu écoutes, il écoute, nous écoutons, vous écoutez, ils écoutent.",
                "Il écoute plus qu'il ne parle — et c'est un don.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "manger",
            verbType: "1er groupe (-er, variante)",
            meaning: "to eat",
            conjugation: [
                WordForm(label: "je",         value: "mange"),
                WordForm(label: "tu",         value: "manges"),
                WordForm(label: "il / elle",  value: "mange"),
                WordForm(label: "nous",       value: "mangeons"),
                WordForm(label: "vous",       value: "mangez"),
                WordForm(label: "ils / elles", value: "mangent"),
            ],
            example: "On mange ensemble ce midi? J'ai préparé quelque chose de bon!",
            exampleTranslation: "Shall we eat together at noon? I've made something delicious!",
            practiceQuestions: [
                "Say 'manger' (mahn-ZHAY) — to eat. Repeat: je mange, tu manges, il mange, nous mangeons, vous mangez, ils mangent. Note: 'mangeons' keeps the 'e'!",
                "Try: 'Je mange...' — what are you eating today? 'Je mange bien.' / 'Je mange des pâtes.' Say it at your next meal!",
                "Fill in the blank: 'What are you eating?' → 'Qu'est-ce que tu _______?' And: 'We eat together every Sunday.' → 'Nous _______ ensemble chaque dimanche.'",
                "Use 'je mange' today at a meal — say it as you eat! 'Je mange quelque chose de délicieux.' Make it part of the moment.",
                "Challenge: conjugate 'manger' — je mange, tu manges, il mange, nous mangeons, vous mangez, ils mangent. Note 'mangeons'!",
                "Translate: 'They eat slowly to fully enjoy the meal.' → 'Ils mangent lentement pour vraiment savourer le repas.'",
                "Use 'manger' in a sentence about a food you love. Say it like you're hungry!"
            ],
            practiceListenPhrases: [
                "manger. Je mange, tu manges, il mange, nous mangeons, vous mangez, ils mangent.",
                "Je mange quelque chose de délicieux.",
                "Nous mangeons ensemble chaque dimanche.",
                "Je mange bien aujourd'hui.",
                "Je mange, tu manges, il mange, nous mangeons, vous mangez, ils mangent.",
                "Ils mangent lentement pour vraiment savourer le repas.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "travailler",
            verbType: "1er groupe (-er)",
            meaning: "to work",
            conjugation: [
                WordForm(label: "je",         value: "travaille"),
                WordForm(label: "tu",         value: "travailles"),
                WordForm(label: "il / elle",  value: "travaille"),
                WordForm(label: "nous",       value: "travaillons"),
                WordForm(label: "vous",       value: "travaillez"),
                WordForm(label: "ils / elles", value: "travaillent"),
            ],
            example: "Elle travaille de chez elle depuis deux ans et ca lui réussit à merveille.",
            exampleTranslation: "She's worked from home for two years and it suits her wonderfully.",
            practiceQuestions: [
                "Say 'travailler' (trah-vah-YAY) — to work. Repeat: je travaille, tu travailles, il travaille, nous travaillons, vous travaillez, ils travaillent.",
                "Try: 'Je travaille...' — what do you do? 'Je travaille de chez moi.' / 'Je travaille sur un projet.' Say it!",
                "Fill in the blank: 'Where do you work?' → 'Où est-ce que tu _______?' And: 'We work together.' → 'Nous _______ ensemble.'",
                "Use 'je travaille' today in a real sentence about your work. Say it in French — you're already doing it!",
                "Challenge: conjugate 'travailler' — je travaille, tu travailles, il travaille, nous travaillons, vous travaillez, ils travaillent.",
                "Translate: 'He works with passion every single day.' → 'Il travaille avec passion chaque jour.' Say it with respect.",
                "Make a sentence with 'travailler' about your own work. Say it out loud proudly!"
            ],
            practiceListenPhrases: [
                "travailler. Je travaille, tu travailles, il travaille, nous travaillons, vous travaillez, ils travaillent.",
                "Je travaille de chez moi.",
                "Nous travaillons ensemble.",
                "Je travaille avec passion aujourd'hui.",
                "Je travaille, tu travailles, il travaille, nous travaillons, vous travaillez, ils travaillent.",
                "Il travaille avec passion chaque jour.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "finir",
            verbType: "2e groupe (-ir)",
            meaning: "to finish",
            conjugation: [
                WordForm(label: "je",         value: "finis"),
                WordForm(label: "tu",         value: "finis"),
                WordForm(label: "il / elle",  value: "finit"),
                WordForm(label: "nous",       value: "finissons"),
                WordForm(label: "vous",       value: "finissez"),
                WordForm(label: "ils / elles", value: "finissent"),
            ],
            example: "Je finis toujours ce que je commence — c'est une question de fierté.",
            exampleTranslation: "I always finish what I start — it's a matter of pride.",
            practiceQuestions: [
                "Say 'finir' (fee-NEER) — to finish. This is the model for all 2nd group -ir verbs! Repeat: je finis, tu finis, il finit, nous finissons, vous finissez, ils finissent.",
                "Try: 'Je finis...' — 'Je finis mon café.' / 'Je finis ce projet.' What are you finishing right now? Say it!",
                "Fill in the blank: 'I finish work at 6.' → 'Je _______ le travail à 18h.' And: 'We're almost done.' → 'Nous _______ bientôt.'",
                "Use 'je finis' today when you finish something — even small. 'Je finis mon café!' Say it as it happens.",
                "Challenge: conjugate 'finir' — je finis, tu finis, il finit, nous finissons, vous finissez, ils finissent. Note the '-iss-' in plural!",
                "Translate: 'She finishes everything she starts with commitment.' → 'Elle finit tout ce qu'elle commence avec détermination.'",
                "Make a sentence about something you want to finish. Say it out loud like a commitment!"
            ],
            practiceListenPhrases: [
                "finir. Je finis, tu finis, il finit, nous finissons, vous finissez, ils finissent.",
                "Je finis mon café.",
                "Nous finissons bientôt.",
                "Je finis ce que je commence.",
                "Je finis, tu finis, il finit, nous finissons, vous finissez, ils finissent.",
                "Elle finit tout ce qu'elle commence avec détermination.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "choisir",
            verbType: "2e groupe (-ir)",
            meaning: "to choose",
            conjugation: [
                WordForm(label: "je",         value: "choisis"),
                WordForm(label: "tu",         value: "choisis"),
                WordForm(label: "il / elle",  value: "choisit"),
                WordForm(label: "nous",       value: "choisissons"),
                WordForm(label: "vous",       value: "choisissez"),
                WordForm(label: "ils / elles", value: "choisissent"),
            ],
            example: "Elle choisit toujours le restaurant — elle a un don pour ca!",
            exampleTranslation: "She always chooses the restaurant — she has a gift for it!",
            practiceQuestions: [
                "Say 'choisir' (shwah-ZEER) — to choose. Repeat: je choisis, tu choisis, il choisit, nous choisissons, vous choisissez, ils choisissent.",
                "Try: 'Je choisis...' — what choice are you making today? Big or small. 'Je choisis d'être heureux(se).' Say it!",
                "Fill in the blank: 'Choose what makes you happy.' → '_______ ce qui te rend heureux.' And: 'We choose together.' → 'Nous _______ ensemble.'",
                "Use 'je choisis' today — make a conscious choice and announce it in French. 'Je choisis...' Feel the power of it.",
                "Challenge: conjugate 'choisir' — je choisis, tu choisis, il choisit, nous choisissons, vous choisissez, ils choisissent.",
                "Translate: 'She chooses kindness every single day.' → 'Elle choisit la bienveillance chaque jour.' Say it beautifully.",
                "Make a sentence with 'choisir' about a choice you're making in life. Say it out loud!"
            ],
            practiceListenPhrases: [
                "choisir. Je choisis, tu choisis, il choisit, nous choisissons, vous choisissez, ils choisissent.",
                "Je choisis d'être heureuse aujourd'hui.",
                "Nous choisissons ensemble.",
                "Je choisis ce qui me rend heureux.",
                "Je choisis, tu choisis, il choisit, nous choisissons, vous choisissez, ils choisissent.",
                "Elle choisit la bienveillance chaque jour.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "connaître",
            verbType: "verbe irrégulier",
            meaning: "to know (a person or place)",
            conjugation: [
                WordForm(label: "je",         value: "connais"),
                WordForm(label: "tu",         value: "connais"),
                WordForm(label: "il / elle",  value: "connaît"),
                WordForm(label: "nous",       value: "connaissons"),
                WordForm(label: "vous",       value: "connaissez"),
                WordForm(label: "ils / elles", value: "connaissent"),
            ],
            example: "Tu connais bien Montréal? C'est une ville tellement vivante!",
            exampleTranslation: "Do you know Montréal well? It's such a vibrant city!",
            practiceQuestions: [
                "Say 'connaître' (ko-NAY-truh) — to know a person or place. Different from 'savoir'! Repeat: je connais, tu connais, il connaît, nous connaissons, vous connaissez, ils connaissent.",
                "Try: 'Je connais...' — a person or a city you know well. 'Je connais bien ce quartier.' Say it with familiarity!",
                "Fill in the blank: 'Do you know her?' → 'Est-ce que tu la _______?' And: 'We know this city well.' → 'Nous _______ bien cette ville.'",
                "Use 'je connais' today — mention someone or a place you know well. Say: 'Je connais...' and finish it!",
                "Challenge: 'savoir' vs 'connaître' — 'je sais parler français' (I know how to) vs 'je connais quelqu'un' (I know a person). Practice both!",
                "Translate: 'She knows every little street in Paris.' → 'Elle connaît chaque petite rue de Paris.' Say it dreamily.",
                "Make a sentence with 'connaître' about a place or person you know well. Say it out loud!"
            ],
            practiceListenPhrases: [
                "connaître. Je connais, tu connais, il connaît, nous connaissons, vous connaissez, ils connaissent.",
                "Je connais bien ce quartier.",
                "Nous connaissons bien cette ville.",
                "Je connais quelqu'un de formidable.",
                "Je connais, tu connais, il connaît, nous connaissons, vous connaissez, ils connaissent.",
                "Elle connaît chaque petite rue de Paris.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "comprendre",
            verbType: "verbe irrégulier",
            meaning: "to understand",
            conjugation: [
                WordForm(label: "je",         value: "comprends"),
                WordForm(label: "tu",         value: "comprends"),
                WordForm(label: "il / elle",  value: "comprend"),
                WordForm(label: "nous",       value: "comprenons"),
                WordForm(label: "vous",       value: "comprenez"),
                WordForm(label: "ils / elles", value: "comprennent"),
            ],
            example: "Je comprends de mieux en mieux le français — ca me rend tellement fière.",
            exampleTranslation: "I understand French better and better — it makes me so proud.",
            practiceQuestions: [
                "Say 'comprendre' (kohm-PRAHN-druh) — to understand. Repeat: je comprends, tu comprends, il comprend, nous comprenons, vous comprenez, ils comprennent.",
                "Try: 'Je comprends!' — say it when something clicks! Or 'Je ne comprends pas encore, mais j'apprends.' Say it!",
                "Fill in the blank: 'Do you understand?' → 'Est-ce que tu _______?' And: 'We understand the situation.' → 'Nous _______ la situation.'",
                "Use 'je comprends' today — when something makes sense, say it in French. 'Je comprends!' It's satisfying!",
                "Challenge: conjugate 'comprendre' — je comprends, tu comprends, il comprend, nous comprenons, vous comprenez, ils comprennent. Like 'prendre'!",
                "Translate: 'She understands people intuitively — that's her superpower.' → 'Elle comprend les gens intuitivement — c'est son super pouvoir.'",
                "Use 'comprendre' in a sentence about understanding — French, people, or life. Say it out loud!"
            ],
            practiceListenPhrases: [
                "comprendre. Je comprends, tu comprends, il comprend, nous comprenons, vous comprenez, ils comprennent.",
                "Je comprends de mieux en mieux!",
                "Nous comprenons la situation.",
                "Je comprends — ca fait tellement de bien.",
                "Je comprends, tu comprends, il comprend, nous comprenons, vous comprenez, ils comprennent.",
                "Elle comprend les gens intuitivement.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "dormir",
            verbType: "verbe irrégulier",
            meaning: "to sleep",
            conjugation: [
                WordForm(label: "je",         value: "dors"),
                WordForm(label: "tu",         value: "dors"),
                WordForm(label: "il / elle",  value: "dort"),
                WordForm(label: "nous",       value: "dormons"),
                WordForm(label: "vous",       value: "dormez"),
                WordForm(label: "ils / elles", value: "dorment"),
            ],
            example: "Elle dort huit heures chaque nuit — elle dit que c'est son secret de beauté.",
            exampleTranslation: "She sleeps eight hours every night — she says it's her beauty secret.",
            practiceQuestions: [
                "Say 'dormir' (dor-MEER) — to sleep. Repeat: je dors, tu dors, il dort, nous dormons, vous dormez, ils dorment. Say them all!",
                "Try: 'Je dors bien.' — 'I sleep well.' Do you? Say it! Or 'Je n'ai pas assez dormi.' Be honest with yourself in French!",
                "Fill in the blank: 'Are you sleeping?' → 'Est-ce que tu _______?' And: 'We sleep better when we read.' → 'Nous _______ mieux quand on lit.'",
                "Use 'je dors' or 'j'ai bien dormi' today — check in with your sleep in French. How did you sleep last night?",
                "Challenge: conjugate 'dormir' — je dors, tu dors, il dort, nous dormons, vous dormez, ils dorment. Twice through!",
                "Translate: 'He sleeps like a log every night.' → 'Il dort comme une souche chaque nuit.' Say it — 'souche' means log!",
                "Make a sentence with 'dormir' about your sleep habits — honest or aspirational. Say it out loud!"
            ],
            practiceListenPhrases: [
                "dormir. Je dors, tu dors, il dort, nous dormons, vous dormez, ils dorment.",
                "Je dors bien cette nuit.",
                "Nous dormons mieux quand on lit.",
                "Je dors suffisamment pour me sentir bien.",
                "Je dors, tu dors, il dort, nous dormons, vous dormez, ils dorment.",
                "Il dort comme une souche chaque nuit.",
                nil
            ]
        ),
        FrenchVerb(
            verb: "vivre",
            verbType: "verbe irrégulier",
            meaning: "to live",
            conjugation: [
                WordForm(label: "je",         value: "vis"),
                WordForm(label: "tu",         value: "vis"),
                WordForm(label: "il / elle",  value: "vit"),
                WordForm(label: "nous",       value: "vivons"),
                WordForm(label: "vous",       value: "vivez"),
                WordForm(label: "ils / elles", value: "vivent"),
            ],
            example: "Je vis chaque journée comme si c'était un cadeau — parce que c'en est un.",
            exampleTranslation: "I live each day as if it were a gift — because it is one.",
            practiceQuestions: [
                "Say 'vivre' (VEE-vruh) — to live. Repeat: je vis, tu vis, il vit, nous vivons, vous vivez, ils vivent. Say them all out loud!",
                "Try: 'Je vis...' — where do you live? How do you live? 'Je vis à Montréal.' / 'Je vis pleinement.' Say it with intention!",
                "Fill in the blank: 'Where do you live?' → 'Où est-ce que tu _______?' And: 'We live simply.' → 'Nous _______ simplement.'",
                "Use 'je vis' today to describe your life or where you live. Say: 'Je vis ici, et j'en suis heureuse.' Own it!",
                "Challenge: conjugate 'vivre' — je vis, tu vis, il vit, nous vivons, vous vivez, ils vivent. Twice through!",
                "Translate: 'She lives fully and without regret.' → 'Elle vit pleinement et sans regrets.' What a life goal.",
                "Make a sentence with 'vivre' about how or where you live — or how you want to live. Say it!"
            ],
            practiceListenPhrases: [
                "vivre. Je vis, tu vis, il vit, nous vivons, vous vivez, ils vivent.",
                "Je vis à Montréal.",
                "Nous vivons simplement.",
                "Je vis pleinement chaque journée.",
                "Je vis, tu vis, il vit, nous vivons, vous vivez, ils vivent.",
                "Elle vit pleinement et sans regrets.",
                nil
            ]
        )
    ]
}
