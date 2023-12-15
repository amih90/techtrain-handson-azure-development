using System;
using Newtonsoft.Json.Linq;

namespace backend.Models;

public record VirusTotal(string id, JObject data);
