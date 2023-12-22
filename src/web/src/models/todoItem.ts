export enum TodoItemState {
    Todo = "todo",
    InProgress = "inprogress",
    Done = "done",
    Overdue = "overdue"
}

export interface TodoItem {
    id?: string
    listId: string
    name: string
    state: TodoItemState
    description?: string
    dueDate?: Date
    completedDate?:Date
    createdDate?: Date
    updatedDate?: Date
}