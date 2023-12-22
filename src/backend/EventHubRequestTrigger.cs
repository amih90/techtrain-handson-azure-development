using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Azure.Messaging.EventHubs;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json.Linq;
using backend.Models;

namespace backend
{
    public class EventHubRequestTrigger
    {
        private readonly VirusTotalClient _virusTotalClient;

        public EventHubRequestTrigger(VirusTotalClient virusTotalClient)
        {
            _virusTotalClient = virusTotalClient;
        }

        [FunctionName("EventHubRequestTrigger")]
        public async Task Run([
            EventHubTrigger("%EventHubRequestsName%",
                Connection = "EventHubRequestsConnectionOptions",
                ConsumerGroup = "%EventHubRequestsConsumerGroup%")] EventData[] events,
            [CosmosDB(
                databaseName: "%CosmosDatabaseName%",
                containerName: "VirusTotal",
                Connection = "CosmosConnectionOptions")]
                IAsyncCollector<VirusTotal> virusTotalEvents,
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
                    JObject ipReport = await _virusTotalClient.GetIPReportAsync(ip);
                    bool isMalicious =  IsMaliciousIp(ipReport);

                    log.LogInformation($"IP=[{ip}], isMalicious=[{isMalicious}]");

                    if (isMalicious)
                    {
                        await virusTotalEvents.AddAsync(new VirusTotal(ip, ipReport));
                    }
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

        private static bool IsMaliciousIp(JObject ipReport)
        {
            return ipReport["data"]["attributes"]["last_analysis_stats"]
                .ToObject<Dictionary<string, int>>()
                .Where(kvp => kvp.Key != "undetected")
                .Sum(kvp => kvp.Value) > 0;
        }
    }
}
