using System;
using Newtonsoft.Json;

namespace backend.Models;

public class TodoItem
{
    public TodoItem(string listId, string name)
    {
        ListId = listId;
        Name = name;
    }

    [JsonProperty("id")]
    public string Id { get; set; }

    [JsonProperty("listId")]
    public string ListId { get; set; }

    [JsonProperty("name")]
    public string Name { get; set; }

    [JsonProperty("description")]
    public string Description { get; set; }

    [JsonProperty("state")]
    public string State { get; set; } = "todo";

    [JsonProperty("dueDate")]
    public DateTimeOffset? DueDate { get; set; }

    [JsonProperty("completedDate")]
    public DateTimeOffset? CompletedDate { get; set; }

    [JsonProperty("createdDate")]
    public DateTimeOffset? CreatedDate { get; set; } = DateTimeOffset.UtcNow;

    [JsonProperty("updatedDate")]
    public DateTimeOffset? UpdatedDate { get; set; }

    public bool IsOverdue()
    {
        return DueDate < DateTimeOffset.UtcNow;
    }

    public bool IsTimerRequired()
    {
        return State != "done" && State != "overdue" && DueDate is not null;
    }
}