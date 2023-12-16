using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Azure.Messaging.EventHubs;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;

namespace backend
{
    public static class EventHubRequestTrigger
    {
        [FunctionName("EventHubRequestTrigger")]
        public static async Task Run([
            EventHubTrigger("%EventHubRequestsName%",
                Connection = "EventHubRequestsConnectionOptions",
                ConsumerGroup = "%EventHubRequestsConsumerGroup%")] EventData[] events,
            ILogger log)
        {
            var exceptions = new List<Exception>();

            foreach (EventData eventData in events)
            {
                try
                {
                    var request = JObject.Parse(eventData.EventBody.ToString());

                    if (!request.TryGetValue("RequestIp", out JToken requestIp))
                    {
                        throw new Exception("Failed to get an IP");
                    }

                    string ip = requestIp.ToString();
                    log.LogInformation($"RequestIp=[{ip}]");

                    // Implement your logic here
                }
                catch (Exception e)
                {
                    // We need to keep processing the rest of the batch - capture this exception and continue.
                    // Also, consider capturing details of the message that failed processing so it can be processed again later.
                    exceptions.Add(e);
                }
            }

            // Once processing of the batch is complete, if any messages in the batch failed processing throw an exception so that there is a record of the failure.

            if (exceptions.Count > 1)
                throw new AggregateException(exceptions);

            if (exceptions.Count == 1)
                throw exceptions.Single();
        }
    }
}
