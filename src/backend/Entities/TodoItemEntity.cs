using System;
using System.Threading.Tasks;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.DurableTask;
using backend.Models;

namespace backend.Entities;

public class TodoItemEntity : ITodoItemEntity
{
    [JsonIgnore]
    private ILogger _logger;

    [JsonIgnore]
    private CosmosClient _cosmosClient;

    [JsonProperty("id")]
    public string Id { get; set; }

    [JsonProperty("todoItem")]
    public TodoItem TodoItem { get; set; }

    public TodoItemEntity(ILogger<TodoItemEntity> logger, CosmosClient cosmosClient)
    {
        _logger = logger;
        _cosmosClient = cosmosClient;
    }

    public Task Create(TodoItem todoItem)
    {
        if (todoItem.DueDate is null || todoItem.IsOverdue())
        {
            Entity.Current.SignalEntity<ITodoItemEntity>(todoItem.Id, e => e.Delete());
            return Task.CompletedTask;
        }

        Id = todoItem.Id;
        TodoItem = todoItem;

        SetTimer();

        return Task.CompletedTask;
    }

    public async Task Sync()
    {
        var container = _cosmosClient.GetContainer("Todo", "TodoItem");

        try
        {
            ItemResponse<TodoItem> readResponse = await container.ReadItemAsync<TodoItem>(
            id: TodoItem.Id,
            partitionKey: new PartitionKey(TodoItem.Id));

            if (readResponse.StatusCode != System.Net.HttpStatusCode.OK)
            {
                return;
            }

            TodoItem todoItem = readResponse.Resource;

            // Update entity state
            TodoItem = todoItem;

            if (!todoItem.IsTimerRequired())
            {
                Entity.Current.SignalEntity<ITodoItemEntity>(Id, e => e.Delete());
                return;
            }

            if (todoItem.IsOverdue())
            {
                todoItem.State = "overdue";
                todoItem.UpdatedDate = DateTimeOffset.UtcNow.DateTime;
                await container.UpsertItemAsync(todoItem);

                Entity.Current.SignalEntity<ITodoItemEntity>(Id, e => e.Delete());
                return;
            }

            SetTimer();
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            _logger.LogWarning($"Missing ToDo item in db, id: {TodoItem.Id}.");
        }
    }

    public Task Delete()
    {
        _logger.LogInformation($"Deleting entity, id=[{Id}]");

        Entity.Current.DeleteState();

        return Task.CompletedTask;
    }

    private void SetTimer()
    {
        DateTime alarm = TodoItem.DueDate.GetValueOrDefault().DateTime;
        Entity.Current.SignalEntity<ITodoItemEntity>(TodoItem.Id, alarm, e => e.Sync());
    }

    [FunctionName(nameof(TodoItemEntity))]
    public static Task Run(
        [EntityTrigger] IDurableEntityContext context)
    {
        return context.DispatchAsync<TodoItemEntity>();
    }
}