import Foundation

struct StorySlide {
    let imageName: String
    let textEN: String
    let textZH: String

    var localizedText: String { L(textEN, textZH) }
}

enum StoryContent {
    static let slides: [StorySlide] = [
        StorySlide(
            imageName: "Story_01",
            textEN: "2187. You board the shuttle Elysium, bound for Mars on a routine six-month voyage. Among your fellow passengers, six carry secrets they would kill to keep.",
            textZH: "2187年。你登上了极乐号穿梭机，例行的六个月火星航程。与你同行的乘客之中，有六个人携带着不惜一切也要守住的秘密。"
        ),
        StorySlide(
            imageName: "Story_02",
            textEN: "A doctor obsessed with cybernetic modification. A captain who cannot command. A teenager the world wants erased. A silent fitness fanatic hiding his face. A flight attendant who asks too many questions. And an AI that knows everything — but can say nothing.",
            textZH: "一个痴迷义体改造的医生。一个不会指挥的舰长。一个被全世界追杀的偷渡少年。一个沉默寡言、遮掩面容的健身男。一个问题太多的女乘务员。以及一个什么都知道、却什么都不能说的AI。"
        ),
        StorySlide(
            imageName: "Story_03",
            textEN: "You possess a rare gift — Neural Connect. You can connect to anyone's mind, see their memories, feel what they hide. This power can be an angel's — or a devil's.",
            textZH: "你拥有一种罕见的天赋——神经连接。你能连入任何人的思维，看见他们的记忆，感受他们隐藏的一切。这种力量，可以是天使的，也可以是魔鬼的。"
        ),
        StorySlide(
            imageName: "Story_04",
            textEN: "Six months. Six passengers. Six truths.\nEvery memory is a clue — if you dare to look deep enough.",
            textZH: "六个月。六个人。六个真相。\n每一段记忆都是线索——如果你敢看得够深。"
        ),
    ]
}
