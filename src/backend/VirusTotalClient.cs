using System.Net.Http;
using System.Threading.Tasks;
using Microsoft.Extensions.Caching.Memory;
using Newtonsoft.Json.Linq;
using backend.Models;
using System;

namespace backend
{
    public class VirusTotalClient
    {
        private const int _minutesAbsoluteExpiration = 1;
        private const string _endpointGetAnIpAddressReport = "https://www.virustotal.com/api/v3/ip_addresses/{0}";
        private readonly HttpClient _httpClient;
        private readonly IMemoryCache _memoryCache;

        public VirusTotalClient(string apiKey, HttpClient httpClient = null, IMemoryCache memoryCache = null)
        {
            _httpClient = httpClient ?? new HttpClient();
            _memoryCache = memoryCache;

            _httpClient.DefaultRequestHeaders.Add("x-apikey", apiKey);
        }

        public void Dispose()
        {
            _httpClient?.Dispose();
        }

        public async Task<JObject> GetIPReportAsync(string ip)
        {
            if (_memoryCache is not null)
            {
                if (_memoryCache.TryGetValue(ip, out object value) && value is VirusTotal virusTotal)
                {
                    return virusTotal.data;
                }
            }

            var response = await _httpClient.GetAsync(string.Format(_endpointGetAnIpAddressReport, ip));
            response.EnsureSuccessStatusCode();

            JObject ipReport = await response.Content.ReadAsAsync<JObject>();

            MemoryCacheEntryOptions options = new()
            {
                AbsoluteExpirationRelativeToNow =
                    TimeSpan.FromMinutes(_minutesAbsoluteExpiration)
            };

            _ = options.RegisterPostEvictionCallback(OnPostEviction);

            return _memoryCache.Set(ip, new VirusTotal(ip, ipReport), options).data;
        }

        static void OnPostEviction(
            object key, object value, EvictionReason reason, object state)
        {
            if (value is not null and VirusTotal virusTotal)
            {
                Console.WriteLine($"{virusTotal.id} was evicted for {reason}.");
            }
        }
    }
}