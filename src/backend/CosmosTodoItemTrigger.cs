using System;
using System.Collections.Generic;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using backend.Entities;
using backend.Models;
using System.Threading.Tasks;
using Microsoft.Azure.WebJobs.Extensions.DurableTask;
namespace backend
{
    public class CosmosTodoItemTrigger
    {
        [FunctionName("CosmosTodoItemTrigger")]
        public async Task Run(
            [CosmosDBTrigger(
                databaseName: "%CosmosDatabaseName%",
                containerName: "TodoItem",
                Connection = "CosmosConnectionOptions",
                LeaseContainerName  = "Leases",
                StartFromBeginning = true,
                CreateLeaseContainerIfNotExists = false)] IReadOnlyList<TodoItem> input,
            [CosmosDB(
                databaseName: "%CosmosDatabaseName%",
                containerName: "TodoItem",
                Connection = "CosmosConnectionOptions")]
                IAsyncCollector<TodoItem> output,
            [DurableClient] IDurableEntityClient durableEntityClient)
        {
            if (input != null && input.Count > 0)
            {
                foreach (var item in input)
                {
                    bool updated = await UpdateDbState(output, item);

                    if (!updated)
                    {
                        await UpdateEntityState(durableEntityClient, item);
                    }
                }
            }
        }

        private async Task<bool> UpdateDbState(IAsyncCollector<TodoItem> output, TodoItem item)
        {
            if (item.State != TodoItemState.Overdue && item.IsOverdue())
            {
                item.State = TodoItemState.Overdue;
                item.UpdatedDate = DateTimeOffset.UtcNow.DateTime;
                await output.AddAsync(item);

                return true;
            }

            return false;
        }

        private async Task UpdateEntityState(IDurableEntityClient durableEntityClient, TodoItem item)
        {
            if (item.DueDate is null || item.IsOverdue())
            {
                await durableEntityClient.SignalEntityAsync<ITodoItemEntity>(item.Id, proxy => proxy.Delete());
                return;
            }

            await durableEntityClient.SignalEntityAsync<ITodoItemEntity>(item.Id, proxy => proxy.Create(item));
        }
    }
}
