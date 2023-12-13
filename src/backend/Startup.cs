using System;
using System.Net.Http;
using System.Threading.Tasks;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using Microsoft.Azure.Functions.Extensions.DependencyInjection;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.DependencyInjection;

[assembly: FunctionsStartup(typeof(backend.Startup))]

namespace backend
{
    public class Startup : FunctionsStartup
    {
        public override void Configure(IFunctionsHostBuilder builder)
        {
            builder.Services
                .AddHttpClient()
                .AddMemoryCache()
                .AddSingleton<DefaultAzureCredential>(_ => new DefaultAzureCredential(includeInteractiveCredentials: true))
                .AddSingleton<VirusTotalClient>(serviceProvider =>
                {
                    var keyVaultUri = new Uri(Environment.GetEnvironmentVariable("KeyVaultEndpoint"));
                    var httpClient = serviceProvider.GetService<HttpClient>();
                    var defaultAzureCredentials = serviceProvider.GetService<DefaultAzureCredential>();

                    // Retrieve apiKey from KeyVault
                    var secretClient = new SecretClient(keyVaultUri, defaultAzureCredentials);
                    var azureResponseKeyVaultSecret = new Lazy<Task<Azure.Response<KeyVaultSecret>>>(async () => await secretClient.GetSecretAsync("VIRUSTOTAL-API-KEY"));
                    var virusTotalApiKey = azureResponseKeyVaultSecret.Value.Result.Value.Value;

                    IMemoryCache memoryCache = serviceProvider.GetRequiredService<IMemoryCache>();

                    return new VirusTotalClient(virusTotalApiKey, httpClient, memoryCache);
                })
                .AddSingleton<Healthz>();
                .AddHealthChecks();
        }
    }
}