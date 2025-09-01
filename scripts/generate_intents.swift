#!/usr/bin/env swift

import Foundation

struct Row { let text: String; let label: String }

enum Label: String, CaseIterable {
    case create_event, create_task, reschedule_event, reschedule_task
    case update_event, update_task, plan_week, plan_day, show_agenda, unknown
}

func rnd<T>(_ arr: [T]) -> T { arr[Int.random(in: 0..<arr.count)] }
func time12() -> String { ["7am","8am","9:30am","10am","11am","noon","1pm","2:30pm","4pm","5pm","8pm"].randomElement()! }
func time24() -> String { ["07:00","08:00","09:30","10:00","11:00","12:00","14:00","14:30","16:00","17:00","20:00"].randomElement()! }
func dayEn() -> String { ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"].randomElement()! }
func dayPt() -> String { ["segunda","terça","quarta","quinta","sexta","sábado","domingo"].randomElement()! }
func nextDayPhraseEn() -> String { ["next \(dayEn())","tomorrow","this \(dayEn())","next week \(dayEn())"].randomElement()! }
func nextDayPhrasePt() -> String { ["\(dayPt()) que vem","amanhã","na próxima \(dayPt())"].randomElement()! }

func genCreateEvent() -> [Row] {
    let en = [
        "schedule {obj} {when} at {time}",
        "create event {obj} {when} {time}",
        "book {obj} on {when} at {time}",
        "add event {obj} {when} {time}",
        "create calendar entry {obj} {when} {time}",
        "schedule {obj} on {when} at {time}",
        "set up {obj} {when} at {time}"
    ]
    let pt = [
        "criar evento {obj} {when} às {time}",
        "agendar {obj} {when} às {time}",
        "marcar {obj} {when} às {time}",
        "novo evento {obj} {when} às {time}",
        "adicionar evento {obj} {when} às {time}"
    ]
    let objsEn = ["coffee with Ana","demo","team lunch","review","standup","office hours","yoga class"]
    let objsPt = ["café com Ana","reunião de produto","almoço com o time","revisão","daily","plantão de dúvidas","aula de yoga"]

    var out: [Row] = []
    for _ in 0..<500 {
        if Bool.random() {
            let t = rnd(en)
                .replacingOccurrences(of: "{obj}", with: rnd(objsEn))
                .replacingOccurrences(of: "{when}", with: rnd(["\(nextDayPhraseEn())","on \(dayEn())","next Friday","tomorrow"]))
                .replacingOccurrences(of: "{time}", with: Bool.random() ? time12() : time24())
            out.append(.init(text: t, label: Label.create_event.rawValue))
        } else {
            let t = rnd(pt)
                .replacingOccurrences(of: "{obj}", with: rnd(objsPt))
                .replacingOccurrences(of: "{when}", with: rnd([nextDayPhrasePt(),"na \(dayPt())","sexta que vem","amanhã"]))
                .replacingOccurrences(of: "{time}", with: rnd(["09:00","10h","11h","12h","14h","16h","19h","20h"]))
            out.append(.init(text: t, label: Label.create_event.rawValue))
        }
    }
    return out
}

func genCreateTask() -> [Row] {
    let en = [
        "create task {task} {when}",
        "add task {task} {when}",
        "new task {task} {when}",
        "record task {task} {when}",
        "remind me to {task} {when}",
        "log task {task} {when}",
        "create a task {task} {when}"
    ]
    let pt = [
        "criar tarefa {task} {when}",
        "adicionar tarefa {task} {when}",
        "tarefa: {task} {when}",
        "lembre-me de {task} {when}"
    ]
    let tasksEn = ["buy cat food","pay rent","submit report","call mom","update resume","clean kitchen","water the plants"]
    let tasksPt = ["comprar ração","pagar contas","enviar relatório","ligar para o João","atualizar currículo","limpar a cozinha","regar as plantas"]

    var out: [Row] = []
    for _ in 0..<500 {
        if Bool.random() {
            let t = rnd(en)
                .replacingOccurrences(of: "{task}", with: rnd(tasksEn))
                .replacingOccurrences(of: "{when}", with: rnd(["tomorrow","on the 5th","this weekend","tonight","on Sunday morning"]))
            out.append(.init(text: t, label: Label.create_task.rawValue))
        } else {
            let t = rnd(pt)
                .replacingOccurrences(of: "{task}", with: rnd(tasksPt))
                .replacingOccurrences(of: "{when}", with: rnd(["amanhã","dia 10","neste fim de semana","hoje à noite","no domingo de manhã"]))
            out.append(.init(text: t, label: Label.create_task.rawValue))
        }
    }
    return out
}

func genRescheduleEvent() -> [Row] {
    let en = [
        "reschedule {obj} to {when} {time}",
        "move {obj} to {when} {time}",
        "shift {obj} from {when1} {time1} to {when} {time}",
        "shift {obj} to {when} {time}",
        "postpone {obj} by one hour",
        "postpone {obj} to {when} {time}",
        "rebook {obj} for {when} {time}",
        "push {obj} to {time}",
        "push {obj} to {when} {time}",
        "change {obj} to {when} {time}"
    ]
    let pt = [
        "remarcar {obj} para {when} {time}",
        "mover {obj} para {when} {time}",
        "adiar {obj} para {when} {time}",
        "remarcar {obj} de {when1} {time1} para {when} {time}",
        "reagendar {obj} para {when} {time}",
        "mudar {obj} para {when} {time}"
    ]
    let objsEn = ["today's standup","sprint planning","client meeting","coffee with Ana","board review","team lunch","1:1"]
    let objsPt = ["reunião de hoje","daily","revisão do projeto","café com Ana","almoço do time","1:1"]

    var out: [Row] = []
    for _ in 0..<500 {
        if Bool.random() {
            let t = rnd(en)
                .replacingOccurrences(of: "{obj}", with: rnd(objsEn))
                .replacingOccurrences(of: "{when}", with: rnd(["tomorrow","next \(dayEn())","Friday","today"]))
                .replacingOccurrences(of: "{time}", with: Bool.random() ? time12() : time24())
                .replacingOccurrences(of: "{when1}", with: rnd(["Tue","Wed","Thu"]))
                .replacingOccurrences(of: "{time1}", with: rnd(["9am","10:00","14:00"]))
            out.append(.init(text: t, label: Label.reschedule_event.rawValue))
        } else {
            let t = rnd(pt)
                .replacingOccurrences(of: "{obj}", with: rnd(objsPt))
                .replacingOccurrences(of: "{when}", with: rnd(["amanhã","\(dayPt()) que vem","sexta","hoje"]))
                .replacingOccurrences(of: "{time}", with: rnd(["9h","10h","14h","16h","20h"]))
                .replacingOccurrences(of: "{when1}", with: rnd(["ter","qua","qui"]))
                .replacingOccurrences(of: "{time1}", with: rnd(["9h","10h","14h"]))
            out.append(.init(text: t, label: Label.reschedule_event.rawValue))
        }
    }
    return out
}

func genRescheduleTask() -> [Row] {
    let en = [
        "reschedule the {task} task to {when}",
        "move {task} task to {when}",
        "push the {task} task to {time}",
        "delay the {task} task by two hours",
        "delay the {task} task to {when}",
        "change the {task} task to {when} {time}",
        "change the {task} task to {when}",
        "reschedule {task} to {when}",
        "shift {task} to {when}"
    ]
    let pt = [
        "remarcar a tarefa {task} para {when}",
        "mover a tarefa {task} para {when}",
        "adiar a tarefa {task} para {time}",
        "adiar a tarefa {task} para {when}",
        "mudar a tarefa {task} para {when} {time}"
    ]
    let tasksEn = ["pay rent","grocery shopping","write report","clean kitchen","call mom","homework","water plants"]
    let tasksPt = ["pagar contas","comprar ração","escrever relatório","limpar a cozinha","ligar para a mãe","lição de casa","regar plantas"]

    var out: [Row] = []
    for _ in 0..<500 {
        if Bool.random() {
            let t = rnd(en)
                .replacingOccurrences(of: "{task}", with: rnd(tasksEn))
                .replacingOccurrences(of: "{when}", with: rnd(["next Friday","tomorrow afternoon","Saturday morning","tonight"]))
                .replacingOccurrences(of: "{time}", with: Bool.random() ? time12() : time24())
            out.append(.init(text: t, label: Label.reschedule_task.rawValue))
        } else {
            let t = rnd(pt)
                .replacingOccurrences(of: "{task}", with: rnd(tasksPt))
                .replacingOccurrences(of: "{when}", with: rnd(["sexta","amanhã de manhã","sábado de manhã","hoje à noite","domingo"]))
                .replacingOccurrences(of: "{time}", with: rnd(["17h","18h","20h","21h"]))
            out.append(.init(text: t, label: Label.reschedule_task.rawValue))
        }
    }
    return out
}

func genUpdateEvent() -> [Row] {
    let en = [
        "rename the event to {title}",
        "update event title to {title}",
        "change event title to {title}",
        "set event title to {title}",
        "set event location to {loc}",
        "add tag {tag} to the event",
        "remove tag {tag} from the event",
        "update event notes: {notes}",
        "change event color to {color}",
        "call this event {title}",
        "rename event as {title}"
    ]
    let pt = [
        "renomear o evento para {title}",
        "atualizar título do evento para {title}",
        "mudar título do evento para {title}",
        "definir título do evento como {title}",
        "definir local do evento para {loc}",
        "adicionar tag {tag} ao evento",
        "remover tag {tag} do evento",
        "atualizar notas do evento: {notes}",
        "mudar cor do evento para {color}"
    ]
    let titles = ["Product Sync","Team All-Hands","Quarterly Review","Design Review"]
    let locs = ["HQ cafeteria","Zoom A","Sala 12","escritório Paulista","auditório"]
    let tags = ["urgent","finance","q3","prioridade","pessoal"]
    let notes = ["bring printed copies","confirm attendance","verificar métricas","incluir pauta"]
    let colors = ["blue","green","purple","azul","verde","roxo"]

    var out: [Row] = []
    for _ in 0..<500 {
        if Bool.random() {
            var t = rnd(en)
            t = t.replacingOccurrences(of: "{title}", with: rnd(titles))
                .replacingOccurrences(of: "{loc}", with: rnd(locs))
                .replacingOccurrences(of: "{tag}", with: rnd(tags))
                .replacingOccurrences(of: "{notes}", with: rnd(notes))
                .replacingOccurrences(of: "{color}", with: rnd(colors))
            out.append(.init(text: t, label: Label.update_event.rawValue))
        } else {
            var t = rnd(pt)
            t = t.replacingOccurrences(of: "{title}", with: rnd(titles))
                .replacingOccurrences(of: "{loc}", with: rnd(locs))
                .replacingOccurrences(of: "{tag}", with: rnd(tags))
                .replacingOccurrences(of: "{notes}", with: rnd(notes))
                .replacingOccurrences(of: "{color}", with: rnd(colors))
            out.append(.init(text: t, label: Label.update_event.rawValue))
        }
    }
    return out
}

func genUpdateTask() -> [Row] {
    let en = [
        "rename task {old} to {new}",
        "update task title to {new}",
        "add tag {tag} to the {task} task",
        "set task priority to {prio}",
        "update task notes: {notes}",
        "remove tag {tag} from the {task} task",
        "change task color to {color}",
        "call this task {new}",
        "rename the task from {old} to {new}"
    ]
    let pt = [
        "renomear tarefa {old} para {new}",
        "atualizar título da tarefa para {new}",
        "mudar título da tarefa para {new}",
        "definir título da tarefa como {new}",
        "adicionar tag {tag} à tarefa {task}",
        "definir prioridade da tarefa como {prioPt}",
        "atualizar notas da tarefa: {notes}",
        "remover tag {tag} da tarefa {task}",
        "mudar cor da tarefa para {colorPt}"
    ]
    let oldNew = [("buy cat food","buy dog food"),("pay bill","pay electricity bill"),("read book","read 20 pages")]
    let tasks = ["clean kitchen","write report","call mom","pay rent","read book"]
    let tags = ["home","work","pessoal","finance","health"]
    let prio = ["low","medium","high"]; let prioPt = ["baixa","média","alta"]
    let notes = ["check coupon code","verificar prazos","include address"]
    let colors = ["orange","purple","gray"]; let colorsPt = ["laranja","roxo","cinza"]

    var out: [Row] = []
    for _ in 0..<500 {
        if Bool.random() {
            let pair = rnd(oldNew)
            var t = rnd(en)
            t = t.replacingOccurrences(of: "{old}", with: pair.0)
                .replacingOccurrences(of: "{new}", with: pair.1)
                .replacingOccurrences(of: "{task}", with: rnd(tasks))
                .replacingOccurrences(of: "{tag}", with: rnd(tags))
                .replacingOccurrences(of: "{prio}", with: rnd(prio))
                .replacingOccurrences(of: "{notes}", with: rnd(notes))
                .replacingOccurrences(of: "{color}", with: rnd(colors))
            out.append(.init(text: t, label: Label.update_task.rawValue))
        } else {
            let pair = rnd(oldNew)
            var t = rnd(pt)
            t = t.replacingOccurrences(of: "{old}", with: pair.0)
                .replacingOccurrences(of: "{new}", with: pair.1)
                .replacingOccurrences(of: "{task}", with: rnd(tasks))
                .replacingOccurrences(of: "{tag}", with: rnd(tags))
                .replacingOccurrences(of: "{prioPt}", with: rnd(prioPt))
                .replacingOccurrences(of: "{notes}", with: rnd(notes))
                .replacingOccurrences(of: "{colorPt}", with: rnd(colorsPt))
            out.append(.init(text: t, label: Label.update_task.rawValue))
        }
    }
    return out
}

func genPlanWeek() -> [Row] {
    let en = [
        "help me plan my week",
        "what should my week look like",
        "plan my week with focus blocks",
        "organize my week around mornings",
        "make a weekly plan including workouts",
        "organize my week",
        "how should I structure my week",
        "plan next week",
        "prepare week schedule"
    ]
    let pt = [
        "me ajude a planejar minha semana",
        "organizar minha semana com blocos de foco",
        "como planejar a semana com estudos",
        "planejar semana priorizando manhãs",
        "faça um plano semanal com exercícios",
        "me ajude a montar minha semana",
        "planeje minha semana",
        "organizar minha semana",
        "planejar semana de trabalho",
        "ajudar a planejar minha semana"
    ]
    return (en+pt).map { Row(text: $0, label: Label.plan_week.rawValue) }
}

func genPlanDay() -> [Row] {
    let en = [
        "help me plan my day",
        "what should my day look like",
        "plan my day with focus blocks",
        "organize my day around mornings",
        "organize my day",
        "how should I structure my day",
        "plan tomorrow",
        "prepare day schedule"
    ]
    let pt = [
        "me ajude a planejar meu dia",
        "organizar meu dia com blocos de foco",
        "como planejar meu dia com estudos",
        "planejar dia priorizando manhãs",
        "faça um plano diário com exercícios",
        "me ajude a montar meu dia",
        "planeje meu dia",
        "organizar meu dia",
        "planejar dia de trabalho",
        "ajudar a planejar meu dia"
    ]
    return (en+pt).map { Row(text: $0, label: Label.plan_day.rawValue) }
}

func genShowAgenda() -> [Row] {
    let en = [
        "show agenda for tomorrow",
        "agenda for next Friday",
        "what's my agenda this afternoon",
        "show agenda for next Thursday morning",
        "agenda for the weekend",
        "display my schedule for Monday",
        "appointments on Tuesday",
        "what do I have scheduled on Saturday",
        "schedule on the 5th",
        "calendar for the 24th",
        "agenda for today afternoon",
        "what’s planned for next Thursday morning",
        "my schedule for next weekend",
        "meeting list for Tuesday",
        "events on Wednesday night"
    ]
    let pt = [
        "mostrar agenda de amanhã",
        "agenda de sexta que vem",
        "qual é minha agenda à tarde",
        "agenda de quinta à tarde",
        "mostrar agenda de quinta de manhã",
        "agenda do fim de semana",
        "exibir minha agenda de segunda",
        "agenda do fim de semana",
    ]
    return (en+pt).map { Row(text: $0, label: Label.show_agenda.rawValue) }
}

func genUnknown() -> [Row] {
    let en = ["hi","hello there","thanks","okay","cool","good morning",
              "okay",
                "thanks",
                "thank you",
                "cool",
                "great",
                "nice",
                "lol",
                "kk",
                "👍",
                "👎",
                "🙏",
                "👏",
                "…",
                "??",
                "¯\\_(ツ)_/¯",
              "just checking",
              "are you there",
              "help",
              "how does this work",
              "nevermind",
              "forget it"
    ]
    let pt = ["olá","valeu","boa tarde","beleza","oi","tudo bem",
              "e aí",
                "beleza",
                "valeu",
                "obrigado",
                "boa noite",
                "bom dia",
                "boa tarde",]
    return (en+pt).map { Row(text: $0, label: Label.unknown.rawValue) }
}

// ----- Main

struct Args { var train: String?; var test: String?; var perLabel = 150; var seed: UInt64 = 42 }
var args = Args()
var it = CommandLine.arguments.makeIterator(); _ = it.next()
while let a = it.next() {
    switch a {
    case "--train": args.train = it.next()
    case "--test": args.test = it.next()
    case "--per-label": args.perLabel = Int(it.next() ?? "150") ?? 150
    case "--seed": args.seed = UInt64(it.next() ?? "42") ?? 42
    default: break
    }
}
var rng = SystemRandomNumberGenerator() // basic; set seed if you prefer deterministic by using a custom RNG

let banks: [Label: [Row]] = [
    .create_event: genCreateEvent(),
    .create_task: genCreateTask(),
    .reschedule_event: genRescheduleEvent(),
    .reschedule_task: genRescheduleTask(),
    .update_event: genUpdateEvent(),
    .update_task: genUpdateTask(),
    .plan_week: genPlanWeek(),
    .plan_day: genPlanDay(),
    .show_agenda: genShowAgenda(),
    .unknown: genUnknown()
]

func sample(_ bank: [Row], n: Int) -> [Row] {
    if n >= bank.count { return bank.shuffled() }
    return Array(bank.shuffled().prefix(n))
}

let per = args.perLabel
var trainRows: [Row] = []
var testRows: [Row] = []

for label in Label.allCases {
    let b = banks[label] ?? []
    // 80/20 split from the sampled subset to avoid near-duplicate leakage
    let picked = sample(b, n: per)
    let cut = Int(Double(picked.count) * 0.8)
    trainRows += picked.prefix(cut)
    testRows  += picked.suffix(from: cut)
}

// Write CSVs
let header = "text,label\n"
func escape(_ s: String) -> String { "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\"" }

if let trainPath = args.train {
    let text = header + trainRows.map { "\(escape($0.text)),\($0.label)" }.joined(separator: "\n") + "\n"
    try text.write(to: URL(fileURLWithPath: trainPath), atomically: true, encoding: .utf8)
    print("Wrote training CSV to \(trainPath) (\(trainRows.count) rows)")
}
if let testPath = args.test {
    let text = header + testRows.map { "\(escape($0.text)),\($0.label)" }.joined(separator: "\n") + "\n"
    try text.write(to: URL(fileURLWithPath: testPath), atomically: true, encoding: .utf8)
    print("Wrote testing CSV to \(testPath) (\(testRows.count) rows)")
}
