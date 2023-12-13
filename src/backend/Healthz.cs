using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace backend
{
    public class Healthz
    {
        private readonly ILogger<Healthz> _log;

        private readonly HealthCheckService _healthCheck;

        public Healthz(ILogger<Healthz> log, HealthCheckService healthCheck)
        {
            _log = log;
            _healthCheck = healthCheck;
        }

        [FunctionName("Healthz")]
        public async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Anonymous, "get", "post", Route = null)] HttpRequest req)
        {
            _log.LogInformation("Received healthz request");

            var status = await _healthCheck.CheckHealthAsync();

            return new OkObjectResult(Enum.GetName(typeof(HealthStatus), status.Status));
        }
    }
}
