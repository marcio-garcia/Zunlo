#!/usr/bin/env swift

// xcrun swift generate_intents.swift \
//   --train zunlo_intents.csv \
//   --test zunlo_intents_test.csv \
//   --per-label 60 

import Foundation

struct Row { let text: String; let label: String }

// === CHANGED: merged reschedule_* into update_*, added cancel_* ===
enum Label: String, CaseIterable {
    case create_event, create_task
    case update_event, update_task
    case cancel_event, cancel_task
    case plan_week, plan_day, show_agenda, unknown
}

func rnd<T>(_ arr: [T]) -> T { arr[Int.random(in: 0..<arr.count)] }
func num() -> String { [
    "4","5","6","7","8","9","10","11","12","13","14","15","16","17","18","19"
    ].randomElement()! }
func monthEn() -> String { [
    "january","february","march","april","may","june","july","august","september","october","november","december","jan","feb","mar","apr","jun","jul","aug","sep","oct","nov","dec"
    ].randomElement()! }
func monthPt() -> String { [
    "janeiro","fevereiro","março","abril","maio","junho","julho","agosto","setembro","outubro","novembro","dezembro","jan","fev","mar","abr","mai","jun","jul","ago","set","out","nov","dez"
    ].randomElement()! }
func time12En() -> String { ["7am","8am","9:30am","10am","11am","noon","1pm","2:30pm","4pm","5pm","8pm"].randomElement()! }
func time24En() -> String { ["07:00","08:00","09:30","10:00","11:00","12:00","14:00","14:30","16:00","17:00","20:00"].randomElement()! }
func time12Pt() -> String { ["7h","8h","9:30","10hs","11hs","meio-dia","1h","2:30","4h","5","8"].randomElement()! }
func time24Pt() -> String { ["07:00","08:00","09:30","10h","11:00","12:00","14hs","14:30","16:00","17:00","20h"].randomElement()! }
func dayEn() -> String { [
    "Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday","Mon","Tue","Wed","Thu","Fri","Sat","Sun"
    ].randomElement()! }
func dayPt() -> String { [
    "segunda","terça","quarta","quinta","sexta","sábado","domingo","seg","ter","qua","qui","sex","sáb","dom","15 de julho","mais tarde",
    "amanhã","dia 10","neste fim de semana","hoje à noite","domingo de manhã","próxima semana","próxima terça","essa quarta","daqui a um mês"
    ].randomElement()! }
func nextDayPhraseEn() -> String { [
    "next \(dayEn())","tomorrow","this \(dayEn())","next week","next week \(dayEn())","\(monthEn()) \(num())th","on the \(num())th",
    "this weekend","tonight","on \(dayEn()) morning","a month from now"
    ].randomElement()! }
func nextDayPhrasePt() -> String { [
    "\(dayPt()) que vem","amanhã","próxima semana","na próxima \(dayPt())","\(monthPt()) \(num())","no dia \(num())","essa semana",
    "de noite","\(dayPt()) de manhã","mes que vem"
    ].randomElement()! }

let objsEn = [
    "coffee with Ana","demo session","team lunch","project review call","standup","office hours","yoga class","see mom",
    "meeting with John","doctor appointment","lunch with Sarah","dinner reservation","call with the team","dentist appointment","birthday party",
    "conference call","team standup meeting","wedding anniversary","graduation ceremony","haircut appointment","project review",
    "meeting about budget planning","interview with candidate",
    "today's standup","sprint planning","client meeting","coffee with Ana","board review","team lunch","1:1",
    "my 3pm meeting","doctor appointment","dentist visit","team meeting","dinner with parents","conference call","birthday party",
    "presentation meeting","lunch meeting","interview","wedding planning meeting","vet appointment","oil change","client meeting","yoga class"]
let objsPt = [
    "café com Ana","reunião de produto","almoço com o time","call de revisão de projeto","daily","plantão de dúvidas","aula de yoga","visitar mãe",
    "reunião com John","consulta médica","almoço com Sarah","reserva para jantar","ligação com a equipe","consulta com o dentista", "festa de aniversário",
    "teleconferência", "reunião da equipe", "aniversário de casamento", "cerimônia de formatura", "consulta para corte de cabelo", "revisão de projeto",
    "reunião sobre planejamento orçamentário", "entrevista com o candidato",
    "reunião de hoje","daily","revisão do projeto","café com Ana","almoço do time","1:1",
    "minha reunião das 15h", "consulta médica", "consulta ao dentista", "reunião de equipe", "jantar com os pais", "conferência telefônica", "festa de aniversário",
    "apresentação do projeto", "reunião para almoço", "entrevista", "reunião de planejamento do casamento", "consulta ao veterinário", "troca de óleo", "reunião com cliente", "aula de ioga"]

let tasksEn = [
    "buy cat food","pay rent","submit report","call mom","update resume","clean kitchen","water the plants","grocery",
    "buy groceries","finish the report","call mom later","pick up dry cleaning","review quarterly numbers","pay bills","submit timesheet",
    "booking vacation","update website content","water the plants","prepare presentation","renew passport","clean garage","annual physical","organize photo albums",
    "pay rent","grocery shopping","write report","clean kitchen","call mom","homework","water plants",
    "grocery shopping","report","cleaning","bill payment","workout","car maintenance","laundry","home repairs",
    "tax preparation","garden work","website update","dentist call","deep cleaning","passport renewal","presentation prep"]
let tasksPt = [
    "comprar ração","pagar contas","enviar relatório","ligar para o João","atualizar currículo","limpar a cozinha","regar as plantas","mercado",
    "comprar mantimentos", "terminar o relatório", "ligar para a mãe mais tarde", "pegar a roupa na lavanderia", "revisar os números trimestrais", "pagar contas", "enviar o quadro de horários",
    "reservar férias", "atualizar o conteúdo do site", "regar as plantas", "preparar a apresentação", "renovar o passaporte", "limpar a garagem", "exame físico anual", "organizar álbuns de fotos",
    "pagar contas","comprar ração","escrever relatório","limpar a cozinha","ligar para a mãe","lição de casa","regar plantas",
    "compras de supermercado", "relatório", "limpeza", "pagamento de contas", "treino", "manutenção do carro", "lavanderia", "consertos domésticos",
    "preparação de impostos", "trabalho de jardim", "atualização de site", "visita ao dentista", "limpeza profunda", "renovação de passaporte", "preparação para apresentação"]

// === existing generators unchanged ===
func genCreateEvent() -> [Row] {
    let en = [
        "schedule {obj} {when} at {time}",
        "create event {obj} {when} {time}",
        "book {obj} on {when} at {time}",
        "book {obj} {when} {time}",
        "add event {obj} {when} {time}",
        "add event {obj} {when} at {time}",
        "create calendar entry {obj} {when} {time}",
        "schedule {obj} on {when} at {time}",
        "set up {obj} {when} at {time}",
        "{obj} {when} at {time}",
        "{obj} {when} {time}",
        "{obj} {when} from {time} to {time}",
        "{obj} {when} {time} at {time}",
        "event {obj} {when} {time}",
        "add {obj} for {when}",
        "create a new event for {obj}",
        "book {obj} for {when}",
        "set up a {obj} {when}",
        "i have a {obj} on {when}",
        "add {obj} to my calendar",
        "schedule {obj} for {time} {when}",
        "create event: {obj}",
        "put {obj} on my calendar",
        "add {obj} {when}",
        "schedule {obj} for {when}",
        "create new calendar event for {obj}",
        "i need to add a {obj}",
        "set up {obj} {when}",
    ]
    let pt = [
        "criar evento {obj} {when} às {time}",
        "criar evento {obj} {when} as {time}",
        "agendar {obj} {when} às {time}",
        "agendar {obj} {when} as {time}",
        "marcar {obj} {when} às {time}",
        "marcar {obj} {when} {time}",
        "novo evento {obj} {when} às {time}",
        "novo evento {obj} {when} {time}",
        "adicionar evento {obj} {when} às {time}",
        "add {obj} {when} às {time}",
        "{obj} {when} às {time}",
        "{obj} {when} de {time} às {time}",
        "evento {obj} {when} {time}",
        "adicionar {obj} para {when}",
        "criar um novo evento para {obj}",
        "Reservar {obj} para {when}",
        "marcar um {obj} {when}",
        "tenho um {obj} para {when}",
        "adicionar {obj} ao meu calendário",
        "agendar {obj} para {time} {when}",
        "criar evento: {obj}",
        "colocar {obj} no meu calendário",
        "adicionar {obj} {when}",
        "agendar {obj} para {when}",
        "criar um novo evento no calendário para {obj}",
        "preciso adicionar um {obj}",
        "configurar {obj} {when}",
    ]


    var out: [Row] = []
    for _ in 0..<500 {
        if Bool.random() {
            let t = rnd(en)
                .replacingOccurrences(of: "{obj}", with: rnd(objsEn))
                .replacingOccurrences(of: "{when}", with: rnd(["\(nextDayPhraseEn())","on \(dayEn())"]))
                .replacingOccurrences(of: "{time}", with: Bool.random() ? time12En() : time24En())
                .replacingOccurrences(of: "{task}", with: rnd(tasksEn))
            out.append(.init(text: t, label: Label.create_event.rawValue))
        } else {
            let t = rnd(pt)
                .replacingOccurrences(of: "{obj}", with: rnd(objsPt))
                .replacingOccurrences(of: "{when}", with: rnd([nextDayPhrasePt(),"na \(dayPt())"]))
                .replacingOccurrences(of: "{time}", with: Bool.random() ? time12Pt() : time24Pt())
                .replacingOccurrences(of: "{task}", with: rnd(tasksPt))
            out.append(.init(text: t, label: Label.create_event.rawValue))
        }
    }
    return out
}

func genCreateTask() -> [Row] {
    let en = [
        "create task {task} {when}",
        "add task {task} {when}",
        "add task to {task} {when}",
        "new task {task} {when}",
        "record task {task} {when}",
        "remind me to {task} {when}",
        "log task {task} {when}",
        "create a task {task} {when}",
        "add task {task} {when}",
        "task {task} {when}",
        "add buy groceries to my todo list",
        "create task to {task}",
        "remind me to {task} {when}",
        "i need to remember to {task}",
        "add task: {task}",
        "create reminder to {task}",
        "put {task} on my task list",
        "add todo item for {task}",
        "create task to {task}",
        "i need to remember to {task}",
        "add {task} to my tasks",
        "create reminder: {task}",
        "put {task} on my todo list",
        "add task to {task}",
        "create todo: {task}",
    ]
    let pt = [
        "criar tarefa {task} {when}",
        "adicionar tarefa {task} {when}",
        "tarefa: {task} {when}",
        "lembre-me de {task} {when}",
        "{task} {when}",
        "tarefa {task} {when}",
        "criar tarefa para {task}",
        "lembrar-me de {task} {when}",
        "preciso lembrar de {task}",
        "adicionar tarefa: {task}",
        "criar lembrete para {task}",
        "colocar {task} na minha lista de tarefas",
        "adicionar item de tarefa para {task}",
        "criar tarefa para {task}",
        "preciso lembrar de {task}",
        "adicionar {task} às minhas tarefas",
        "criar lembrete: {task}",
        "colocar {task} na minha lista de tarefas",
        "adicionar tarefa a {task}",
        "criar tarefa: {task}",
    ]

    var out: [Row] = []
    for _ in 0..<500 {
        if Bool.random() {
            let t = rnd(en)
                .replacingOccurrences(of: "{task}", with: rnd(tasksEn))
                .replacingOccurrences(of: "{when}", with: rnd(["\(nextDayPhraseEn())","on \(dayEn())"]))
                .replacingOccurrences(of: "{obj}", with: rnd(objsEn))
            out.append(.init(text: t, label: Label.create_task.rawValue))
        } else {
            let t = rnd(pt)
                .replacingOccurrences(of: "{task}", with: rnd(tasksPt))
                .replacingOccurrences(of: "{when}", with: rnd(["\(nextDayPhrasePt())","on \(dayPt())"]))
                .replacingOccurrences(of: "{obj}", with: rnd(objsPt))
            out.append(.init(text: t, label: Label.create_task.rawValue))
        }
    }
    return out
}

// === CHANGED: reschedule generators now emit update_* labels ===
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
        "change {obj} to {when} {time}",
        "Push back the team meeting by an hour",
    ]
    let pt = [
        "remarcar {obj} para {when} {time}",
        "mover {obj} para {when} {time}",
        "adiar {obj} para {when} {time}",
        "remarcar {obj} de {when1} {time1} para {when} {time}",
        "reagendar {obj} para {when} {time}",
        "mudar {obj} para {when} {time}",
        "Adie a reunião da equipe em uma hora",
    ]

    var out: [Row] = []
    for _ in 0..<500 {
        if Bool.random() {
            let t = rnd(en)
                .replacingOccurrences(of: "{obj}", with: rnd(objsEn))
                .replacingOccurrences(of: "{when}", with: rnd(["\(nextDayPhraseEn())","on \(dayEn())"]))
                .replacingOccurrences(of: "{time}", with: Bool.random() ? time12En() : time24En())
                .replacingOccurrences(of: "{when1}", with: rnd(["\(nextDayPhraseEn())","on \(dayEn())"]))
                .replacingOccurrences(of: "{time1}", with: Bool.random() ? time12En() : time24En())
                .replacingOccurrences(of: "{task}", with: rnd(tasksEn))
            // merged label:
            if !out.contains(where: { $0.text == t }) {
                out.append(.init(text: t, label: Label.update_event.rawValue))
            }
        } else {
            let t = rnd(pt)
                .replacingOccurrences(of: "{obj}", with: rnd(objsPt))
                .replacingOccurrences(of: "{when}", with: rnd(["\(nextDayPhrasePt())","on \(dayPt())"]))
                .replacingOccurrences(of: "{time}", with: Bool.random() ? time12Pt() : time24Pt())
                .replacingOccurrences(of: "{when1}", with: rnd(["\(nextDayPhrasePt())","on \(dayPt())"]))
                .replacingOccurrences(of: "{time1}", with: Bool.random() ? time12Pt() : time24Pt())
                .replacingOccurrences(of: "{task}", with: rnd(tasksPt))
            // merged label:
            if !out.contains(where: { $0.text == t }) {
                out.append(.init(text: t, label: Label.update_event.rawValue))
            }
        }
    }
    return out
}

func genRescheduleTask() -> [Row] {
    let en = [
        "reschedule the {task} task to {when}",
        "move {task} task to {when}",
        "push the {task} task to {when}",
        "delay the {task} task by two hours",
        "delay the {task} task to {when}",
        "change the {task} task to {when}",
        "change the {task} task to {when}",
        "reschedule {task} to {when}",
        "shift {task} to {when}",
        "change deadline for report to next {when}",
        "push back cleaning task to weekend",
    ]
    let pt = [
        "remarcar a tarefa {task} para {when}",
        "mover a tarefa {task} para {when}",
        "adiar a tarefa {task} para {when}",
        "adiar a tarefa {task} para {when}",
        "mudar a tarefa {task} para {when}",
        "alterar prazo para entrega do relatório para o próximo {when}",
    ]

    var out: [Row] = []
    for _ in 0..<500 {
        if Bool.random() {
            let t = rnd(en)
                .replacingOccurrences(of: "{task}", with: rnd(tasksEn))
                .replacingOccurrences(of: "{when}", with: rnd(["\(nextDayPhraseEn())","on \(dayEn())"]))
                .replacingOccurrences(of: "{obj}", with: rnd(objsEn))
            // merged label:
            if !out.contains(where: { $0.text == t }) {
                out.append(.init(text: t, label: Label.update_task.rawValue))
            }
        } else {
            let t = rnd(pt)
                .replacingOccurrences(of: "{task}", with: rnd(tasksPt))
                .replacingOccurrences(of: "{when}", with: rnd(["\(nextDayPhrasePt())","on \(dayPt())"]))
                .replacingOccurrences(of: "{obj}", with: rnd(objsPt))
            // merged label:
            if !out.contains(where: { $0.text == t }) {
                out.append(.init(text: t, label: Label.update_task.rawValue))
            }
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
        "rename event as {title}",
        "add location to my meeting with Sarah",
        "change the meeting duration to \(num()) hours",
        "add attendees to the project review",
        "update doctor appointment with new address",
        "add notes to the conference call event",
        "change meeting title to quarterly planning",
        "add video call link to team standup",
        "update dinner reservation for \(num()) people instead of \(num())",
        "add reminder to bring documents to meeting",
        "change event description to include agenda",
        "update birthday party with gift ideas",
        "add driving directions to the appointment",
        "change meeting room for the presentation",
        "update event with new phone number",
        "add preparation notes to the interview",
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
        "mudar cor do evento para {color}",
        "alterar a duração da reunião para \(num()) horas",
        "adicionar participantes à revisão do projeto",
        "atualizar a consulta médica com o novo endereço",
        "adicionar notas ao evento da teleconferência",
        "alterar o título da reunião para planejamento trimestral",
        "adicionar link da videochamada para a reunião em equipe",
        "atualizar a reserva do jantar para \(num()) pessoas em vez de \(num())",
        "adicionar lembrete para levar documentos para a reunião",
        "alterar a descrição do evento para incluir a pauta",
        "atualizar a festa de aniversário com ideias para presentes",
        "adicionar instruções de direção ao compromisso",
        "alterar a sala de reunião para a apresentação",
        "atualizar o evento com o novo número de telefone",
        "adicionar notas de preparação para a entrevista",
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
            if !out.contains(where: { $0.text == t }) {
                out.append(.init(text: t, label: Label.update_event.rawValue))
            }
        } else {
            var t = rnd(pt)
            t = t.replacingOccurrences(of: "{title}", with: rnd(titles))
                .replacingOccurrences(of: "{loc}", with: rnd(locs))
                .replacingOccurrences(of: "{tag}", with: rnd(tags))
                .replacingOccurrences(of: "{notes}", with: rnd(notes))
                .replacingOccurrences(of: "{color}", with: rnd(colors))
            if !out.contains(where: { $0.text == t }) {
                out.append(.init(text: t, label: Label.update_event.rawValue))
            }
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
        "rename the task from {old} to {new}",
        "mark grocery shopping as high priority",
        "add milk and bread to shopping list",
        "change task deadline to end of week",
        "update report task with new requirements",
        "add subtasks to home renovation project",
        "mark bill payment as completed",
        "update task description with more details",
        "change task category to work projects",
        "add time estimate to presentation prep",
        "update cleaning task with specific rooms",
        "mark task as in progress",
        "add resources needed to research task",
        "update task priority to urgent",
        "change task assignee to team member",
        "add checklist items to packing task",
        "mark the {task} task as high priority",
        "change the deadline of the {task} task to end of week",
        "update the {task} task notes: {notes}",
        "set the {task} task priority to {prio}",
        "rename the {old} task to {new}",
        "mark the {task} task as done",
        "mark {task} complete",
        "reopen the {task} task",
        "set the {task} task due date to {when}",
        "change the {task} task due date to {when}",
        "set priority of the {task} task to {prio}",
        "add checklist item to {task}: {notes}",
        "remove the {tag} tag from the {task} task",
        "assign the {task} task to a team member",
        "rename {old} task to {new}",
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
        "mudar cor da tarefa para {colorPt}",
        "marcar compras de supermercado como alta prioridade",
        "adicionar leite e pão à lista de compras",
        "alterar o prazo da tarefa para o final da semana",
        "atualizar a tarefa do relatório com novos requisitos",
        "adicionar subtarefas ao projeto de reforma da casa",
        "marcar o pagamento da conta como concluído",
        "atualizar a descrição da tarefa com mais detalhes",
        "alterar a categoria da tarefa para projetos de trabalho",
        "adicionar estimativa de tempo à preparação da apresentação",
        "atualizar a tarefa de limpeza com cômodos específicos",
        "marcar a tarefa como em andamento",
        "adicionar recursos necessários à tarefa de pesquisa",
        "atualizar a prioridade da tarefa para urgente",
        "alterar o responsável pela tarefa para membro da equipe",
        "adicionar itens da lista de verificação à tarefa de embalagem",
        "marcar a tarefa {task} como alta prioridade",
        "alterar o prazo da tarefa {task} para o final da semana",
        "atualizar as notas da tarefa {task}: {notes}",
        "definir a prioridade da tarefa {task} como {prioPt}",
        "renomear a tarefa {old} para {new}",
        "marcar a tarefa {task} como concluída"
        "reabrir a tarefa {task}",
        "definir data de entrega da tarefa {task} para {when}",
        "alterar a data de entrega da tarefa {task} para {when}",
        "definir prioridade da tarefa {task} como {prioPt}",
        "adicionar item de checklist à tarefa {task}: {notes}",
        "remover a tag {tag} da tarefa {task}",
        "atribuir a tarefa {task} a um membro da equipe",
        "renomear a tarefa {old} para {new}",
    ]
    let tasks = ["clean kitchen","write report","call mom","pay rent","read book"]
    let tags = ["home","work","pessoal","finance","health"]
    let prio = ["low","medium","high"]; let prioPt = ["baixa","média","alta"]
    let notes = ["check coupon code","verificar prazos","include address"]
    let colors = ["orange","purple","gray"]; let colorsPt = ["laranja","roxo","cinza"]

    var out: [Row] = []
    for _ in 0..<500 {
        if Bool.random() {
            var t = rnd(en)
            t = t.replacingOccurrences(of: "{old}", with: rnd(tasksEn))
                .replacingOccurrences(of: "{new}", with: rnd(tasksEn))
                .replacingOccurrences(of: "{task}", with: rnd(tasks))
                .replacingOccurrences(of: "{tag}", with: rnd(tags))
                .replacingOccurrences(of: "{prio}", with: rnd(prio))
                .replacingOccurrences(of: "{notes}", with: rnd(notes))
                .replacingOccurrences(of: "{color}", with: rnd(colors))
            if !out.contains(where: { $0.text == t }) {
                out.append(.init(text: t, label: Label.update_task.rawValue))
            }
        } else {
            var t = rnd(pt)
            t = t.replacingOccurrences(of: "{old}", with: rnd(tasksPt))
                .replacingOccurrences(of: "{new}", with: rnd(tasksPt))
                .replacingOccurrences(of: "{task}", with: rnd(tasks))
                .replacingOccurrences(of: "{tag}", with: rnd(tags))
                .replacingOccurrences(of: "{prioPt}", with: rnd(prioPt))
                .replacingOccurrences(of: "{notes}", with: rnd(notes))
                .replacingOccurrences(of: "{colorPt}", with: rnd(colorsPt))
            if !out.contains(where: { $0.text == t }) {
                out.append(.init(text: t, label: Label.update_task.rawValue))
            }
        }
    }
    return out
}

// === NEW: cancel generators ===
func genCancelEvent() -> [Row] {
    let en = [
        "cancel {obj} for {when}",
        "cancel the {obj}",
        "delete {obj} {when}",
        "remove {obj} from {when}",
        "don't schedule {obj} {when}",
        "i don't want {obj} {when}"
    ]
    let pt = [
        "cancelar {obj} para {when}",
        "cancelar {obj}",
        "excluir {obj} {when}",
        "remover {obj} de {when}",
        "não agendar {obj} {when}",
        "não marcar {obj} {when}",
        "não quero {obj} {when}"
    ]
    var out: [Row] = []
    for _ in 0..<500 {
        if Bool.random() {
            let t = rnd(en)
                .replacingOccurrences(of: "{obj}", with: rnd(objsEn))
                .replacingOccurrences(of: "{when}", with: rnd(["next Friday","tomorrow afternoon","Saturday morning","tonight","on \(dayEn())","\(nextDayPhraseEn())"]))
            out.append(.init(text: t, label: Label.cancel_event.rawValue))
        } else {
            let t = rnd(pt)
                .replacingOccurrences(of: "{obj}", with: rnd(objsPt))
                .replacingOccurrences(of: "{when}", with: rnd(["sexta","amanhã de manhã","sábado de manhã","hoje à noite","domingo","\(nextDayPhrasePt())"]))
            out.append(.init(text: t, label: Label.cancel_event.rawValue))
        }
    }
    return out
}

func genCancelTask() -> [Row] {
    let en = [
        "remove {task} from my list",
        "delete {task} task",
        "cancel the {task} task",
        "don't add {task}",
        "i don't want the {task} task anymore"
    ]
    let pt = [
        "remover {task} da minha lista",
        "excluir tarefa {task}",
        "cancelar tarefa {task}",
        "não adicionar {task}",
        "não quero mais a tarefa {task}"
    ]
    var out: [Row] = []
    for _ in 0..<500 {
        if Bool.random() {
            let t = rnd(en).replacingOccurrences(of: "{task}", with: rnd(tasksEn))
            out.append(.init(text: t, label: Label.cancel_task.rawValue))
        } else {
            let t = rnd(pt).replacingOccurrences(of: "{task}", with: rnd(tasksPt))
            out.append(.init(text: t, label: Label.cancel_task.rawValue))
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
        "how should i structure my week",
        "plan next week",
        "prepare week schedule",
        "what should i focus on this week?",
        "plan my upcoming week schedule",
        "i need to organize my week ahead",
        "show me how to structure next week",
        "help me map out my weekly priorities",
        "plan my work week schedule",
        "i want to organize the coming week",
        "help me layout my week efficiently",
        "plan my weekly schedule and tasks",
        "i need to structure my upcoming week",
        "help me organize my week's activities",
        "plan out my schedule for next week",
        "i want to map my week ahead",
        "help me plan my weekly routine"
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
        "ajudar a planejar minha semana",
        "ajude-me a planejar a próxima semana",
        "em que devo me concentrar esta semana?",
        "planeje minha agenda para a próxima semana",
        "preciso organizar minha semana com antecedência",
        "mostre-me como estruturar a próxima semana",
        "ajude-me a mapear minhas prioridades semanais",
        "planeje minha agenda para a semana de trabalho",
        "quero organizar a próxima semana",
        "ajude-me a planejar minha semana com eficiência",
        "planeje minha agenda e tarefas semanais",
        "preciso estruturar minha próxima semana",
        "ajude-me a organizar as atividades da minha semana",
        "planeje minha agenda para a próxima semana",
        "quero mapear minha semana com antecedência",
        "ajude-me a planejar minha rotina semanal"
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
        "how should i structure my day",
        "plan tomorrow",
        "prepare day schedule",
        "plan my day tomorrow",
        "help me organize today's schedule",
        "what should i do today?",
        "plan my day efficiently",
        "help me structure today's tasks",
        "i need to organize my day ahead",
        "plan my daily schedule",
        "help me layout today's priorities",
        "i want to plan my day better",
        "show me how to organize today",
        "plan my day around important meetings",
        "help me structure my daily routine",
        "i need to plan my day off",
        "plan today's work schedule",
        "help me organize my day effectively",
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
        "ajudar a planejar meu dia",
        "planeje meu dia amanhã",
        "ajude-me a organizar a agenda de hoje",
        "o que devo fazer hoje?",
        "planeje meu dia com eficiência",
        "ajude-me a estruturar as tarefas de hoje",
        "preciso organizar meu dia com antecedência",
        "planeje minha agenda diária",
        "ajude-me a definir as prioridades de hoje",
        "quero planejar meu dia melhor",
        "mostre-me como organizar o dia de hoje",
        "planeje meu dia com base em reuniões importantes",
        "ajude-me a estruturar minha rotina diária",
        "preciso planejar meu dia de folga",
        "planeje a agenda de trabalho de hoje",
        "ajude-me a organizar meu dia com eficiência",
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
        "what do i have scheduled on Saturday",
        "show schedule on the 5th",
        "display calendar for the 24th",
        "agenda for today afternoon",
        "what’s planned for next Thursday morning",
        "my schedule for next weekend",
        "meeting list for Tuesday",
        "events on Wednesday night",
        "what's on my schedule today?",
        "show me my calendar for tomorrow",
        "what meetings do i have this week?",
        "display my agenda for Monday",
        "what's coming up in my calendar?",
        "show me my schedule for next week",
        "what appointments do i have today?",
        "display my upcoming events",
        "what's on my calendar this afternoon?",
        "show me my daily agenda",
        "what meetings are scheduled for Friday?",
        "display my calendar overview",
        "what's on my schedule for the weekend?",
        "show me my tasks and appointments",
        "what do i have planned for today?",

        // ---- Added ----
        "do i have anything on Sunday?",
        "do i have anything scheduled for tomorrow morning?",
        "list my meetings for Thursday",
        "view my schedule for this weekend",
        "see my agenda for next Monday",
        "any appointments on Friday?",
        "show today's meetings",
        "display tomorrow's appointments",
        "show all events on the 10th",
        "show events for next Wednesday morning",
        "what's next on my calendar?",
        "what's on my agenda tonight?",
        "show upcoming meetings this week",
        "view calendar for next month",
        "see my schedule for the afternoon",
        "what's on my calendar this evening?",
        "show my meetings for today",
        "list appointments for next Tuesday",
        "show me what i have on Friday",
        "see what's on my calendar on Saturday",
        "display agenda for Sunday morning",
        "show agenda for this week",
        "do i have meetings tomorrow afternoon?",
    ]

    let pt = [
        "mostrar agenda de amanhã",
        "agenda de sexta que vem",
        "qual é minha agenda à tarde",
        "mostre agenda de quinta à tarde",
        "mostrar agenda de quinta de manhã",
        "qual é a minha agenda do fim de semana",
        "exibir minha agenda de segunda",
        "mostre agenda do fim de semana",
        "o que está na minha agenda para hoje?",
        "mostrar minha agenda para amanhã",
        "quais reuniões tenho esta semana?",
        "mostrar minha agenda para segunda-feira",
        "o que está por vir na minha agenda?",
        "mostrar minha agenda para a próxima semana",
        "quais compromissos tenho hoje?",
        "mostrar meus próximos eventos",
        "o que está na minha agenda para esta tarde?",
        "mostrar minha agenda diária",
        "quais reuniões estão agendadas para sexta-feira?",
        "mostrar a visão geral da minha agenda",
        "o que está na minha agenda para o fim de semana?",
        "mostrar minhas tarefas e compromissos",
        "o que planejei para hoje?",

        // ---- Adicionados ----
        "tenho algo marcado no domingo?",
        "tenho algo na agenda amanhã de manhã?",
        "listar minhas reuniões de quinta",
        "ver minha agenda para este fim de semana",
        "ver minha agenda para a próxima segunda",
        "há compromissos na sexta?",
        "mostrar reuniões de hoje",
        "exibir compromissos de amanhã",
        "mostrar todos os eventos do dia 10",
        "mostrar eventos para a próxima quarta de manhã",
        "o que vem a seguir no meu calendário?",
        "o que está na minha agenda hoje à noite?",
        "mostrar reuniões desta semana",
        "exibir calendário do próximo mês",
        "ver minha agenda para a tarde",
        "o que está no meu calendário esta noite?",
        "mostrar minhas reuniões de hoje",
        "listar compromissos para a próxima terça",
        "mostrar o que tenho na sexta",
        "ver o que está no meu calendário no sábado",
        "exibir agenda de domingo de manhã",
        "mostrar agenda desta semana",
        "tenho reuniões amanhã à tarde?",
    ]

    return (en+pt).map { Row(text: $0, label: Label.show_agenda.rawValue) }
}

// === CHANGED: removed cancel-like phrases from unknown ===
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
              "forget it",
              "what's the weather like?",
              "how do i cook pasta?",
              "what's the capital of France?",
              "tell me a joke",
              "how are you doing today?",
              "what's the latest news?",
              "how do i fix my car?",
              "what movies are playing nearby?",
              "convert dollars to euros",
              "what's the traffic like on i-95?",
              "how do i lose weight?",
              "what's the best restaurant in town?",
              "how do i learn Spanish?",
              "what's the stock price of Apple?",
              "how do i meditate?"
    ]
    let pt = ["olá","valeu","boa tarde","beleza","oi","tudo bem",
              "e aí",
              "beleza",
              "valeu",
              "obrigado",
              "boa noite",
              "bom dia",
              "boa tarde",
              "como está o tempo?",
              "como faço macarrão?",
              "qual é a capital da França?",
              "conte-me uma piada",
              "como você está hoje?",
              "quais são as últimas notícias?",
              "vomo conserto meu carro?",
              "quais filmes estão passando por aqui?",
              "contar dólares para euros",
              "como está o trânsito na I-95?",
              "como faço para perder peso?",
              "qual é o melhor restaurante da cidade?",
              "como aprendo espanhol?",
              "qual é o preço das ações da Apple?",
              "como medito?"
    ]
    
    var out: [Row] = []
    for _ in 0..<500 {
        if Bool.random() {
            let t = rnd(en)
            out.append(.init(text: t, label: Label.unknown.rawValue))
        } else {
            let t = rnd(pt)
            out.append(.init(text: t, label: Label.unknown.rawValue))
        }
    }
    return out
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

// === CHANGED: banks use merged reschedule->update and add cancels ===
let banks: [Label: [Row]] = [
    .create_event: genCreateEvent(),
    .create_task: genCreateTask(),
    .update_event: genUpdateEvent(), + genRescheduleEvent(), // merged
    .update_task: genUpdateTask(), + genRescheduleTask(),     // merged
    .cancel_event: genCancelEvent(),
    .cancel_task: genCancelTask(),
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
