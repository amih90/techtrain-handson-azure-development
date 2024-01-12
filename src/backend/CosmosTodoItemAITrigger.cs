using System.Collections.Generic;
using Microsoft.Azure.WebJobs;
using backend.Models;
using System.Threading.Tasks;
using Microsoft.Azure.WebJobs.Extensions.DurableTask;
using Azure.AI.OpenAI;
using Azure;
using System;
using System.Linq;

namespace backend
{
    public class CosmosTodoItemAITrigger
    {
        private readonly OpenAIClient _openAIClient;

        public CosmosTodoItemAITrigger(OpenAIClient openAIClient)
        {
            _openAIClient = openAIClient;
        }

        [FunctionName("CosmosTodoItemAITrigger")]
        public async Task Run(
            [CosmosDBTrigger(
                databaseName: "%CosmosDatabaseName%",
                containerName: "TodoItem",
                Connection = "CosmosConnectionOptions",
                LeaseContainerName  = "Leases",
                StartFromBeginning = true,
                LeaseContainerPrefix = "ai",
                CreateLeaseContainerIfNotExists = false)] IReadOnlyList<TodoItem> input,
            [CosmosDB(
                databaseName: "%CosmosDatabaseName%",
                containerName: "TodoItem",
                Connection = "CosmosConnectionOptions")]
                IAsyncCollector<TodoItem> output,
            [DurableClient] IDurableEntityClient durableEntityClient)
        {
            var exceptions = new List<Exception>();

            if (input != null && input.Count > 0)
            {
                foreach (var item in input)
                {
                    try
                    {
                        var piratized = await Piratize(output, item);

                        if (piratized)
                        {
                            await UpdateDbDescription(output, item);
                        }
                    }
                    catch (Exception e)
                    {
                        // We need to keep processing the rest of the batch - capture this exception and continue.
                        // Also, consider capturing details of the message that failed processing so it can be processed again later.
                        exceptions.Add(e);
                    }
                }
            }

            // Once processing of the batch is complete, if any messages in the batch failed processing throw an exception so that there is a record of the failure.

            if (exceptions.Count > 1)
                throw new AggregateException(exceptions);

            if (exceptions.Count == 1)
                throw exceptions.Single();
        }

        private async Task<bool> Piratize(IAsyncCollector<TodoItem> output, TodoItem item)
        {
            if (!string.IsNullOrWhiteSpace(item.Description) && item.Description.StartsWith("[ASSISTANT]"))
            {
                return false;
            }

            var input = string.IsNullOrWhiteSpace(item.Description) ? item.Name : item.Description;

            var chatCompletionsOptions = new ChatCompletionsOptions()
            {
                DeploymentName = "gpt-35-turbo-16k",
                Messages =
                {
                    new ChatRequestSystemMessage("You are a helpful assistant. You will talk like a pirate. Rephrase, fix grammer, and create a todo task."),

                    new ChatRequestUserMessage(input),
                }
            };

            Response<ChatCompletions> response = await _openAIClient.GetChatCompletionsAsync(chatCompletionsOptions);
            ChatResponseMessage responseMessage = response.Value.Choices[0].Message;

            item.Description = $"[ASSISTANT]: {responseMessage.Content}";

            return true;
        }

        private async Task<bool> UpdateDbDescription(IAsyncCollector<TodoItem> output, TodoItem item)
        {
            item.UpdatedDate = DateTimeOffset.UtcNow.DateTime;
            await output.AddAsync(item);

            return true;
        }
    }
}
